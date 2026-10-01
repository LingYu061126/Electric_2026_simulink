%% Validate the R2024a single-phase passive-load SPWM inverter
% Runs the saved switching model, checks gate interlock, measures the
% fundamental and harmonics, and writes the requested evidence artifacts.

mdl = 'single_phase_passive_inverter_r2024a';
projectRoot = fileparts(fileparts(mfilename('fullpath')));
modelFile = fullfile(projectRoot, 'models', [mdl '.slx']);
resultsDir = fullfile(projectRoot, 'results');
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end
% A live scratch copy is used for the gate-only precheck before the power run.
if ~bdIsLoaded(mdl) && bdIsLoaded('single_phase_passive_inverter_gate_precheck')
    mdl = 'single_phase_passive_inverter_gate_precheck';
end
if ~bdIsLoaded(mdl)
    open_system(modelFile);
end

fprintf('Running %s for 0.20 s in MATLAB %s...\n', mdl, version('-release'));
simOut = sim(mdl, 'StopTime', '0.2', 'ReturnWorkspaceOutputs', 'on');

signalNames = {'Vdc','vA','vB','vAB','iLoad','iDC', ...
    'vrefA','vrefB','carrier','g1','g2','g3','g4','pwmA','pwmB'};
signals = struct();
for k = 1:numel(signalNames)
    signals.(signalNames{k}) = simOut.get(signalNames{k});
end

% The gates are sampled at 1 us. Check the actual simulated gate traces.
tg = signals.g1.Time(:);
g1 = logical(squeeze(signals.g1.Data)); g1 = g1(:);
g2 = logical(squeeze(signals.g2.Data)); g2 = g2(:);
g3 = logical(squeeze(signals.g3.Data)); g3 = g3(:);
g4 = logical(squeeze(signals.g4.Data)); g4 = g4(:);
assert(isequal(tg, signals.g2.Time(:)) && isequal(tg, signals.g3.Time(:)) && ...
    isequal(tg, signals.g4.Time(:)), 'Gate logs do not share the same time base.');
shootA = nnz(g1 & g2);
shootB = nnz(g3 & g4);
assert(shootA == 0 && shootB == 0, ...
    'Shoot-through detected; stopping analysis. Leg A=%d, Leg B=%d.', shootA, shootB);

% Save the model only after a real switching simulation completed.
save_system(mdl, modelFile);

% Use an exact 1 MHz, coherent 0.10 s analysis record (five 50 Hz cycles).
f1 = 50;
fsw = 10000;
Fs = 1e6;
tAnalysis = (0.10:1/Fs:0.20-1/Fs)';
analysis = struct();
analysis.time_s = tAnalysis;
for k = 1:numel(signalNames)
    nm = signalNames{k};
    ts = signals.(nm);
    tt = double(ts.Time(:));
    xx = double(squeeze(ts.Data));
    xx = xx(:);
    [tt, uniqueIndex] = unique(tt, 'stable');
    xx = xx(uniqueIndex);
    analysis.(nm) = interp1(tt, xx, tAnalysis, 'linear');
end

% Verify that the directly measured differential voltage is vA - vB.
vA = analysis.vA;
vB = analysis.vB;
vAB = analysis.vAB;
iLoad = analysis.iLoad;
diffPolarityResidual = max(abs(vAB - (vA - vB)));

[aV, bV] = sineProjection(vAB, tAnalysis, f1);
[aI, bI] = sineProjection(iLoad, tAnalysis, f1);
V1_peak = hypot(aV, bV);
I1_peak = hypot(aI, bI);

% Find the output fundamental frequency from the measured voltage trace.
fMeasured = fminbnd(@(f) projectionResidual(vAB, tAnalysis, f), ...
    45, 55, optimset('TolX', 1e-8, 'Display', 'off'));
[aVfit, bVfit] = sineProjection(vAB, tAnalysis, fMeasured);
[aIfit, bIfit] = sineProjection(iLoad, tAnalysis, fMeasured);
phaseVfit = atan2d(aVfit, bVfit);
phaseIfit = atan2d(aIfit, bIfit);
phaseLagMeasured = mod(phaseVfit - phaseIfit + 180, 360) - 180;

VdcMeasured = mean(analysis.Vdc);
V1rmsTheory = 0.8 * 48 / sqrt(2);
V1rmsSim = V1_peak / sqrt(2);
Zmag = hypot(10, 2*pi*f1*20e-3);
I1rmsTheory = V1rmsTheory / Zmag;
I1rmsSim = I1_peak / sqrt(2);
phaseTheory = atan2d(2*pi*f1*20e-3, 10);

N = numel(tAnalysis);
Yv = fft(vAB) / N;
Yi = fft(iLoad) / N;
fundamentalBin = round(f1 / (Fs/N)) + 1;
harmonicOrder = 2:floor((Fs/2)/f1);
harmonicBins = 1 + harmonicOrder * round(f1 / (Fs/N));
voltageTHD = 100 * sqrt(sum(abs(Yv(harmonicBins)).^2) / abs(Yv(fundamentalBin))^2);
currentTHD = 100 * sqrt(sum(abs(Yi(harmonicBins)).^2) / abs(Yi(fundamentalBin))^2);

VrmsTotal = sqrt(mean(vAB.^2));
IrmsTotal = sqrt(mean(iLoad.^2));
Pload = mean(vAB .* iLoad);
Sload = VrmsTotal * IrmsTotal;
PFoverall = Pload / Sload;
PFdisplacement = cosd(phaseLagMeasured);
Pdc = mean(analysis.Vdc .* analysis.iDC);
meanVab = mean(vAB);

% Check the commanded switching rate from the simulated comparator output.
pwmA = logical(analysis.pwmA);
risingEdges = find(diff(pwmA) > 0) + 1;
if numel(risingEdges) >= 3
    fswMeasured = 1 / median(diff(tAnalysis(risingEdges)));
else
    fswMeasured = NaN;
end

deadA = deadtimeIntervals(tg, g1, g2);
deadB = deadtimeIntervals(tg, g3, g4);
blankSamplesA = nnz(~g1 & ~g2);
blankSamplesB = nnz(~g3 & ~g4);
freewheelSamples = nnz((~analysis.g1 & ~analysis.g2 | ...
    ~analysis.g3 & ~analysis.g4) & abs(iLoad) > 0.5);

finiteAll = true;
for k = 1:numel(signalNames)
    data = double(squeeze(signals.(signalNames{k}).Data));
    finiteAll = finiteAll && all(isfinite(data(:)));
end
finiteAll = finiteAll && all(isfinite(tg));

metrics = struct();
metrics.Vdc_V = VdcMeasured;
metrics.f1_Hz = f1;
metrics.fsw_Hz = fsw;
metrics.fsw_measured_Hz = fswMeasured;
metrics.modulation_index = 0.8;
metrics.load_R_Ohm = 10;
metrics.load_L_H = 20e-3;
metrics.V1_peak_theory_V = 0.8 * 48;
metrics.V1_rms_theory_V = V1rmsTheory;
metrics.V1_rms_sim_V = V1rmsSim;
metrics.V1_rms_error_percent = 100 * abs(V1rmsSim - V1rmsTheory) / V1rmsTheory;
metrics.I1_rms_theory_A = I1rmsTheory;
metrics.I1_rms_sim_A = I1rmsSim;
metrics.I1_rms_error_percent = 100 * abs(I1rmsSim - I1rmsTheory) / I1rmsTheory;
metrics.phase_theory_deg = phaseTheory;
metrics.phase_sim_deg = phaseLagMeasured;
metrics.phase_error_deg = abs(phaseLagMeasured - phaseTheory);
metrics.voltage_THD_percent = voltageTHD;
metrics.current_THD_percent = currentTHD;
metrics.mean_vAB_V = meanVab;
metrics.output_frequency_Hz = fMeasured;
metrics.shoot_through_count_leg_A = shootA;
metrics.shoot_through_count_leg_B = shootB;
metrics.gate_sample_count = numel(tg);
metrics.gate_sample_period_s = median(diff(tg));
metrics.dead_time_command_us = 1;
metrics.dead_time_measured_leg_A_us = median(deadA) * 1e6;
metrics.dead_time_measured_leg_B_us = median(deadB) * 1e6;
metrics.dead_time_min_leg_A_us = min(deadA) * 1e6;
metrics.dead_time_min_leg_B_us = min(deadB) * 1e6;
metrics.blank_samples_leg_A = blankSamplesA;
metrics.blank_samples_leg_B = blankSamplesB;
metrics.freewheeling_current_samples = freewheelSamples;
metrics.freewheeling_path = 'Internal integral protection diode, diode with no dynamics';
metrics.mean_vAB_direct_sensor_residual_V = diffPolarityResidual;
metrics.Vrms_total_V = VrmsTotal;
metrics.Irms_total_A = IrmsTotal;
metrics.Pload_W = Pload;
metrics.Sload_VA = Sload;
metrics.power_factor_overall = PFoverall;
metrics.fundamental_displacement_factor = PFdisplacement;
metrics.Pdc_W = Pdc;
metrics.mean_iDC_A = mean(analysis.iDC);
metrics.analysis_start_s = 0.10;
metrics.analysis_end_s = 0.20;
metrics.simulation_stop_s = 0.20;
metrics.no_nan_inf = finiteAll;

metrics.passive_inverter_passed = finiteAll && shootA == 0 && shootB == 0 && ...
    abs(fMeasured - f1) < 0.1 && metrics.V1_rms_error_percent < 5 && ...
    metrics.I1_rms_error_percent < 8 && metrics.phase_error_deg < 3 && ...
    abs(meanVab) < 0.25 && diffPolarityResidual < 1e-6 && Pload > 0 && Pdc > 0 && ...
    voltageTHD > currentTHD && isfinite(fswMeasured) && abs(fswMeasured-fsw) < 10;

% Required waveform artifacts.
plotPwm = tAnalysis >= 0.1050 & tAnalysis <= 0.1053;
fig = figure('Color','w','Visible','off','Position',[100 100 1200 850]);
tiledlayout(fig,3,1,'TileSpacing','compact','Padding','compact');
nexttile; plot(tAnalysis(plotPwm)*1e3, analysis.carrier(plotPwm), 'k-', ...
    tAnalysis(plotPwm)*1e3, analysis.vrefA(plotPwm), 'b-', ...
    tAnalysis(plotPwm)*1e3, analysis.vrefB(plotPwm), 'r-','LineWidth',1.1);
grid on; ylabel('Normalized signal'); legend('Triangle carrier','vrefA','vrefB','Location','best');
title('Unipolar SPWM and 1 MHz sampled dead-time gate logic');
nexttile; stairs(tAnalysis(plotPwm)*1e3,double(analysis.g1(plotPwm)),'b-','LineWidth',1.1);
hold on; stairs(tAnalysis(plotPwm)*1e3,double(analysis.g2(plotPwm)),'r-','LineWidth',1.1); hold off;
grid on; ylim([-0.1 1.1]); ylabel('Leg A gate'); legend('g1 / S1','g2 / S2','Location','best');
nexttile; stairs(tAnalysis(plotPwm)*1e3,double(analysis.g3(plotPwm)),'b-','LineWidth',1.1);
hold on; stairs(tAnalysis(plotPwm)*1e3,double(analysis.g4(plotPwm)),'r-','LineWidth',1.1); hold off;
grid on; ylim([-0.1 1.1]); ylabel('Leg B gate'); xlabel('Time (ms)');
legend('g3 / S3','g4 / S4','Location','best');
exportgraphics(fig,fullfile(resultsDir,'inverter_pwm.png'),'Resolution',180); close(fig);

plotWindow = tAnalysis >= 0.10 & tAnalysis <= 0.16;
fig = figure('Color','w','Visible','off','Position',[100 100 1200 800]);
tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
nexttile; plot(tAnalysis(plotWindow),analysis.vA(plotWindow),'b-', ...
    tAnalysis(plotWindow),analysis.vB(plotWindow),'r-','LineWidth',0.7);
grid on; ylabel('Pole voltage (V)');
legend('vA to DC return','vB to DC return','Location','best');
title('Full-bridge pole voltages');
nexttile; plot(tAnalysis(plotWindow),analysis.vAB(plotWindow),'k-','LineWidth',0.7);
grid on; xlabel('Time (s)'); ylabel('vAB (V)');
title('Differential voltage vAB = vA - vB: three-level PWM, three 50 Hz cycles');
exportgraphics(fig,fullfile(resultsDir,'inverter_bridge_voltage.png'),'Resolution',180); close(fig);

plotWindow = tAnalysis >= 0.14 & tAnalysis <= 0.20;
fig = figure('Color','w','Visible','off','Position',[100 100 1200 650]);
yyaxis left; plot(tAnalysis(plotWindow),analysis.vAB(plotWindow),'b-','LineWidth',0.8);
ylabel('vAB (V)');
yyaxis right; plot(tAnalysis(plotWindow),analysis.iLoad(plotWindow),'r-','LineWidth',1.0);
ylabel('iLoad (A)');
grid on; xlabel('Time (s)'); title('Differential PWM voltage and passive RL load current');
exportgraphics(fig,fullfile(resultsDir,'inverter_load.png'),'Resolution',180); close(fig);

resultMat = fullfile(resultsDir,'passive_inverter_results.mat');
save(resultMat,'metrics','analysis','simOut','-v7.3');
resultJson = fullfile(resultsDir,'passive_inverter_metrics.json');
fid = fopen(resultJson,'w');
assert(fid >= 0,'Could not open metrics JSON for writing.');
cleanup = onCleanup(@() fclose(fid));
fwrite(fid,jsonencode(metrics),'char');
clear cleanup;

fprintf('Vdc=%.6f V, V1rms=%.6f/%.6f V, I1rms=%.6f/%.6f A\n', ...
    metrics.Vdc_V,metrics.V1_rms_sim_V,metrics.V1_rms_theory_V, ...
    metrics.I1_rms_sim_A,metrics.I1_rms_theory_A);
fprintf('fout=%.8f Hz, phase lag=%.5f/%.5f deg, THD(V/I)=%.3f%%/%.3f%%\n', ...
    metrics.output_frequency_Hz,metrics.phase_sim_deg,metrics.phase_theory_deg, ...
    metrics.voltage_THD_percent,metrics.current_THD_percent);
fprintf('Pload=%.6f W, PF=%.6f, gates overlap A/B=%d/%d, deadtime median A/B=%.3f/%.3f us\n', ...
    metrics.Pload_W,metrics.power_factor_overall,shootA,shootB, ...
    metrics.dead_time_measured_leg_A_us,metrics.dead_time_measured_leg_B_us);
fprintf('PASSIVE_INVERTER_PASSED=%d\n',metrics.passive_inverter_passed);

function [a,b] = sineProjection(x,t,f)
x = x(:) - mean(x);
t = t(:);
a = 2/numel(t) * sum(x .* cos(2*pi*f*t));
b = 2/numel(t) * sum(x .* sin(2*pi*f*t));
end

function err = projectionResidual(x,t,f)
[a,b] = sineProjection(x,t,f);
x = x(:) - mean(x);
fit = a*cos(2*pi*f*t(:)) + b*sin(2*pi*f*t(:));
err = mean((x-fit).^2);
end

function dt = deadtimeIntervals(t,upper,lower)
riseUpper = find(diff(upper) > 0) + 1;
riseLower = find(diff(lower) > 0) + 1;
fallUpper = find(diff(upper) < 0) + 1;
fallLower = find(diff(lower) < 0) + 1;
dt = [pairEdges(t,riseUpper,fallLower); pairEdges(t,riseLower,fallUpper)];
assert(~isempty(dt),'No complementary gate commutations were measured.');
end

function dt = pairEdges(t,rising,oppositeFalling)
dt = zeros(0,1);
for k = 1:numel(rising)
    prior = oppositeFalling(oppositeFalling < rising(k));
    if ~isempty(prior)
        dt(end+1,1) = t(rising(k)) - t(prior(end)); %#ok<AGROW>
    end
end
end
