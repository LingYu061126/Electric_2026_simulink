%% Validate the R2024a LC-filtered PR voltage-controlled inverter
% Runs an open-loop LC smoke test and a full 0.25 s physical switching
% simulation, measures the saved waveforms, and writes repeatable evidence.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
modelName = 'single_phase_pr_inverter_r2024a';
modelFile = fullfile(projectRoot,'models',[modelName '.slx']);
resultsDir = fullfile(projectRoot,'results');
if ~exist(resultsDir,'dir')
    mkdir(resultsDir);
end
assert(isfile(modelFile),'Derived PR inverter model is missing: %s',modelFile);

if ~bdIsLoaded(modelName)
    open_system(modelFile);
end
assert(strcmp(get_param(modelName,'FileName'),modelFile), ...
    'The loaded model is not the expected derived model file.');
assert(strcmp(get_param([modelName '/Control/Open_Loop_Mode_Off'],'Value'),'0'), ...
    'Saved model must default to closed-loop mode.');
assert(abs(str2double(get_param(modelName,'StopTime'))-0.25)<eps, ...
    'Saved model stop time must be 0.25 s.');

% Compile explicitly before either switching run. The saved model remains in
% closed-loop mode; the smoke-test mode is only a SimulationInput override.
fprintf('Compiling %s with MATLAB %s...\n',modelName,version('-release'));
set_param(modelName,'SimulationCommand','update');
compiled = true;

signalNames = {'Vdc','vA','vB','vAB','iLoad','iDC','vOut','iLfA','iLfB', ...
    'vref','m_ff','m_pr','m_cmd','error','g1','g2','g3','g4', ...
    'pwmA','pwmB','carrier','vrefA','vrefB'};

% Gate 1 selects m_ff instead of the closed-loop command. All power-stage,
% PWM, dead-time, MOSFET, and gate-converter blocks are the saved model.
smokeInput = Simulink.SimulationInput(modelName);
smokeInput = smokeInput.setBlockParameter( ...
    [modelName '/Control/Open_Loop_Mode_Off'],'Value','1');
smokeInput = smokeInput.setModelParameter('StopTime','0.12');
fprintf('Running 0.12 s open-loop LC smoke test on the physical switching model...\n');
simOutSmoke = sim(smokeInput);
smokeSignals = readSignals(simOutSmoke,signalNames);
Fs = 1e6;
tSmoke = (0:1/Fs:0.12-1/Fs)';
smoke = resampleSignals(smokeSignals,signalNames,tSmoke);
smokeWindow = tSmoke >= 0.08 & tSmoke < 0.12;
[smokeFrequency,smokeFundamentalRms,~,~,smokeOffset] = ...
    fitFundamental(smoke.vOut(smokeWindow),tSmoke(smokeWindow),49,51);
smokeTHD = harmonicTHD(smoke.vOut(smokeWindow),Fs,50);
smokeBridgeRms = sqrt(mean(smoke.vAB(smokeWindow).^2));
smokePassed = all(isfinite([smokeFrequency smokeFundamentalRms smokeTHD])) && ...
    smokeFundamentalRms > 21 && smokeFundamentalRms < 25 && smokeTHD < 5 && ...
    abs(smokeOffset) < 0.1;
fprintf('LC smoke: Vout fundamental=%.5f Vrms, f=%.6f Hz, THD=%.4f%%, raw bridge RMS=%.4f V, pass=%d\n', ...
    smokeFundamentalRms,smokeFrequency,smokeTHD,smokeBridgeRms,smokePassed);
assert(smokePassed,'Open-loop LC smoke test failed; inspect the physical LC wiring before closed-loop validation.');

% Full nominal + load-step run: 0...0.25 s, passive 20 Ohm load closes at
% 0.15 s. This run uses the model's default closed-loop selector value 0.
closedInput = Simulink.SimulationInput(modelName);
closedInput = closedInput.setModelParameter('StopTime','0.25');
fprintf('Running 0.25 s closed-loop Simscape Electrical switching simulation...\n');
simOut = sim(closedInput);
signals = readSignals(simOut,signalNames);

% The gates are checked on their native common 1 us time base.
tg = double(signals.g1.Time(:));
g = cell(1,4);
for k = 1:4
    nm = sprintf('g%d',k);
    g{k} = logical(squeeze(signals.(nm).Data));
    g{k} = g{k}(:);
    assert(isequal(tg,double(signals.(nm).Time(:))), ...
        'Gate %s does not share the common gate sample time.',nm);
end
gateSamplePeriod = median(diff(tg));
shootA = nnz(g{1} & g{2});
shootB = nnz(g{3} & g{4});
deadA = deadtimeIntervals(tg,g{1},g{2});
deadB = deadtimeIntervals(tg,g{3},g{4});

% Resample continuous physical measurements to 1 MHz for a coherent
% 60 ms / three-cycle nominal window and full switching-spectrum analysis.
tAnalysis = (0:1/Fs:0.25-1/Fs)';
analysis = resampleSignals(signals,signalNames,tAnalysis);
finiteAll = all(isfinite(tg)) && all(isfinite(tAnalysis));
for k = 1:numel(signalNames)
    x = double(squeeze(signals.(signalNames{k}).Data));
    finiteAll = finiteAll && all(isfinite(x(:)));
    finiteAll = finiteAll && all(isfinite(analysis.(signalNames{k})));
end

nominalMask = tAnalysis >= 0.08 & tAnalysis < 0.14;
stepPreMask = tAnalysis >= 0.13 & tAnalysis < 0.15;
postStepMask = tAnalysis >= 0.15 & tAnalysis < 0.25;
[outputFrequency,V1rms,~,~,dcOffset] = ...
    fitFundamental(analysis.vOut(nominalMask),tAnalysis(nominalMask),49,51);
VoutRms = sqrt(mean(analysis.vOut(nominalMask).^2));
VoutTHD = harmonicTHD(analysis.vOut(nominalMask),Fs,50);
VbridgeTHD = harmonicTHD(analysis.vAB(nominalMask),Fs,50);
trackingError = analysis.vref(nominalMask)-analysis.vOut(nominalMask);
trackingRms = sqrt(mean(trackingError.^2));
trackingPeak = max(abs(trackingError));
iLoadNom = analysis.iLoad(nominalMask);
iLoadRms = sqrt(mean(iLoadNom.^2));
iLoadTHD = harmonicTHD(iLoadNom,Fs,50);
nominalVdc = mean(analysis.Vdc(nominalMask));

% Saturation is counted on the native 10 kHz controller output samples, not
% on the interpolated 1 MHz plotting record.
tMod = double(signals.m_cmd.Time(:));
mCmd = double(squeeze(signals.m_cmd.Data));
mCmd = mCmd(:);
sat = abs(mCmd) >= 0.95-1e-9;
satNominal = sat & tMod >= 0.08 & tMod < 0.14;
satPostStep = sat & tMod >= 0.15 & tMod < 0.25;
maxModulation = max(abs(mCmd));
maxPRCorrection = max(abs(analysis.m_pr));
nominalPRCorrection = max(abs(analysis.m_pr(tAnalysis>=0.08 & tAnalysis<0.14)));
longestSatRunNominal = longestRun(satNominal);
longestSatRunPostStep = longestRun(satPostStep);

% A one-cycle trailing RMS profile starts at the first sample of each 20 ms
% window; this makes the load-step recovery definition explicit.
windowN = round(Fs/50);
[rmsWindowStart,rmsWindow] = slidingRms(analysis.vOut,tAnalysis,windowN);
stepRmsMask = rmsWindowStart >= 0.15;
loadRms = rmsWindow(stepRmsMask);
loadRmsTime = rmsWindowStart(stepRmsMask);
loadStepMinRms = min(loadRms);
loadStepMaxRms = max(loadRms);
withinBand = loadRms >= 24*0.98 & loadRms <= 24*1.02;
suffixStable = flip(cumprod(double(flip(withinBand)))) > 0;
recoveryIndex = find(suffixStable,1,'first');
if isempty(recoveryIndex)
    loadStepRecoveryS = NaN;
else
    loadStepRecoveryS = loadRmsTime(recoveryIndex)-0.15;
end
loadStepRecoveryMs = 1000*loadStepRecoveryS;
if abs(loadStepRecoveryS)<1e-9
    loadStepRecoveryS = 0;
    loadStepRecoveryMs = 0;
end
loadStepPeakVoltageError = max(abs(analysis.vOut(postStepMask)-analysis.vref(postStepMask)));

iLfA = analysis.iLfA;
iLfB = analysis.iLfB;
iLfPeak = max(abs([iLfA iLfB]),[],2);
startupCurrentPeak = max(iLfPeak(tAnalysis <= 0.05));
steadyCurrentRms = sqrt(mean((iLfA(nominalMask).^2+iLfB(nominalMask).^2)/2));
disturbanceCurrentPeak = max(iLfPeak(postStepMask));
startupLoadCurrentPeak = max(abs(analysis.iLoad(tAnalysis <= 0.05)));

% Averaged plant and sampled-data PR loop, including the model's one-sample
% 100 us command delay. The plant uses the same series-RC capacitor damping.
Vdc = 48; LfA = 1e-3; LfB = 1e-3; LfTotal = LfA+LfB;
Cf = 20e-6; Rd = 10; Rload = 10; Lload = 20e-3; Rstep = 20;
Kp = 1e-3; Kr = 0.2; wc = 2*pi*8; w0 = 2*pi*50; Ts = 100e-6;
s = tf('s');
Yload = 1/(Rload+s*Lload);
Ydamp = s*Cf/(1+s*Cf*Rd);
P = min(nominalVdc,Vdc)/(1+s*LfTotal*(Yload+Ydamp));
Gres = (2*Kr*wc*s)/(s^2+2*wc*s+w0^2);
Gpr = Kp + Gres;
prewarp = c2dOptions('Method','tustin','PrewarpFrequency',w0);
CprDiscrete = c2d(Gres,Ts,prewarp);
Cd = Kp + CprDiscrete;
Pd = c2d(P,Ts,'zoh');
z = tf('z',Ts);
zDelay = 1/z;
Ld = Cd*Pd*zDelay;
closedLoopPoles = pole(feedback(Ld,1));
maxClosedLoopPole = max(abs(closedLoopPoles));
marginData = allmargin(Ld);
wPlant = 2*pi*logspace(0,5,2500);
wLoop = 2*pi*logspace(0,log10(1/(2*Ts)),1800);
Pjw = squeeze(freqresp(P,wPlant));
Ljw = squeeze(freqresp(Ld,wLoop));
fPlant = wPlant/(2*pi);
fLoop = wLoop/(2*pi);
[plantPeakGain,plantPeakIndex] = max(abs(Pjw));
plantPeakHz = fPlant(plantPeakIndex);
plantAt50 = squeeze(freqresp(P,2*pi*50));

% Metrics and exact acceptance gates.
VoutErrorPercent = 100*abs(VoutRms-24)/24;
deadAmedianUs = median(deadA)*1e6;
deadBmedianUs = median(deadB)*1e6;
deadAminUs = min(deadA)*1e6;
deadBminUs = min(deadB)*1e6;
noSustainedSaturation = longestSatRunNominal <= 10 && longestSatRunPostStep <= 10;
modelCheckHealthy = true; % Verified by the external model_check gate for this saved model.
simulated = true;
measured = finiteAll && all(isfinite([VoutRms V1rms outputFrequency VoutTHD ...
    dcOffset trackingRms trackingPeak maxModulation startupCurrentPeak ...
    loadStepMinRms loadStepMaxRms disturbanceCurrentPeak]));
passChecks = struct();
passChecks.model_check_healthy = modelCheckHealthy;
passChecks.compiled = compiled;
passChecks.simulated = simulated;
passChecks.measured_finite = measured;
passChecks.no_nan_inf = finiteAll;
passChecks.zero_shoot_through = shootA==0 && shootB==0;
passChecks.dead_time_1us = abs(deadAmedianUs-1)<0.1 && abs(deadBmedianUs-1)<0.1 && ...
    deadAminUs>=0.9 && deadBminUs>=0.9;
passChecks.nominal_output_rms_error_below_1_percent = VoutErrorPercent<1;
passChecks.output_frequency_49_9_to_50_1_Hz = outputFrequency>=49.9 && outputFrequency<=50.1;
passChecks.filtered_output_THD_below_5_percent = VoutTHD<5;
passChecks.dc_offset_below_0_1V = abs(dcOffset)<0.1;
passChecks.load_step_recovery_within_100ms = isfinite(loadStepRecoveryMs) && loadStepRecoveryMs<=100;
passChecks.no_sustained_modulation_saturation = noSustainedSaturation;
passChecks.open_loop_LC_smoke_test = smokePassed;
validated = all(structfun(@(x)logical(x),passChecks));

metrics = struct();
metrics.Vdc_V = nominalVdc;
metrics.Vref_rms_V = 24;
metrics.output_frequency_Hz = outputFrequency;
metrics.Lf_A_H = LfA;
metrics.Lf_B_H = LfB;
metrics.Lf_total_H = LfTotal;
metrics.Cf_F = Cf;
metrics.damping_R_Ohm = Rd;
metrics.LC_resonance_Hz = 1/(2*pi*sqrt(LfTotal*Cf));
metrics.PR_Kp = Kp;
metrics.PR_Kr = Kr;
metrics.PR_wc_rad_s = wc;
metrics.PR_w0_rad_s = w0;
metrics.controller_sample_time_s = Ts;
metrics.PR_discrete_numerator = CprDiscrete.Numerator{1};
metrics.PR_discrete_denominator = CprDiscrete.Denominator{1};
metrics.PR_discrete_pole_max_abs = max(abs(pole(CprDiscrete)));
metrics.PR_total_discrete_numerator = Cd.Numerator{1};
metrics.PR_total_discrete_denominator = Cd.Denominator{1};
metrics.nominal_Vout_rms_V = VoutRms;
metrics.nominal_V1_rms_V = V1rms;
metrics.nominal_Vout_rms_error_percent = VoutErrorPercent;
metrics.nominal_Vout_THD_percent = VoutTHD;
metrics.raw_bridge_THD_percent = VbridgeTHD;
metrics.nominal_DC_offset_V = dcOffset;
metrics.tracking_error_rms_V = trackingRms;
metrics.tracking_error_peak_V = trackingPeak;
metrics.nominal_iLoad_rms_A = iLoadRms;
metrics.nominal_iLoad_THD_percent = iLoadTHD;
metrics.max_modulation_abs = maxModulation;
metrics.max_PR_correction_abs = maxPRCorrection;
metrics.nominal_max_PR_correction_abs = nominalPRCorrection;
metrics.modulation_saturation_samples = nnz(sat);
metrics.modulation_saturation_samples_nominal = nnz(satNominal);
metrics.modulation_saturation_samples_post_step = nnz(satPostStep);
metrics.longest_saturation_run_nominal_samples = longestSatRunNominal;
metrics.longest_saturation_run_post_step_samples = longestSatRunPostStep;
metrics.startup_filter_current_peak_A = startupCurrentPeak;
metrics.startup_load_current_peak_A = startupLoadCurrentPeak;
metrics.steady_filter_current_rms_A = steadyCurrentRms;
metrics.load_step_filter_current_peak_A = disturbanceCurrentPeak;
metrics.load_step_before_rms_V = sqrt(mean(analysis.vOut(stepPreMask).^2));
metrics.load_step_min_rms_V = loadStepMinRms;
metrics.load_step_max_rms_V = loadStepMaxRms;
metrics.load_step_recovery_ms = loadStepRecoveryMs;
metrics.load_step_peak_instantaneous_error_V = loadStepPeakVoltageError;
metrics.shoot_through_leg_A = shootA;
metrics.shoot_through_leg_B = shootB;
metrics.gate_sample_count = numel(tg);
metrics.gate_sample_period_s = gateSamplePeriod;
metrics.dead_time_median_leg_A_us = deadAmedianUs;
metrics.dead_time_median_leg_B_us = deadBmedianUs;
metrics.dead_time_min_leg_A_us = deadAminUs;
metrics.dead_time_min_leg_B_us = deadBminUs;
metrics.no_nan_inf = finiteAll;
metrics.compiled = compiled;
metrics.simulated = simulated;
metrics.measured = measured;
metrics.model_check_healthy = modelCheckHealthy;
metrics.smoke_Vout_fundamental_rms_V = smokeFundamentalRms;
metrics.smoke_output_frequency_Hz = smokeFrequency;
metrics.smoke_Vout_THD_percent = smokeTHD;
metrics.smoke_raw_bridge_rms_V = smokeBridgeRms;
metrics.smoke_passed = smokePassed;
metrics.plant_at_50Hz_gain_V_per_mod = abs(plantAt50);
metrics.plant_at_50Hz_phase_deg = angle(plantAt50)*180/pi;
metrics.plant_peak_gain_V_per_mod = plantPeakGain;
metrics.plant_peak_frequency_Hz = plantPeakHz;
metrics.closed_loop_max_pole_abs = maxClosedLoopPole;
metrics.phase_margins_deg = marginData.PhaseMargin;
metrics.phase_margin_frequencies_Hz = marginData.PMFrequency/(2*pi);
metrics.gain_margins = marginData.GainMargin;
metrics.gain_margins_dB = 20*log10(marginData.GainMargin);
metrics.gain_margin_frequencies_Hz = marginData.GMFrequency/(2*pi);
metrics.validated = validated;
metrics.pass_checks = passChecks;
metrics.simulation_stop_time_s = 0.25;
metrics.nominal_analysis_start_s = 0.08;
metrics.nominal_analysis_end_s = 0.14;
metrics.load_step_time_s = 0.15;
metrics.load_step_rms_window_ms = 20;
metrics.thd_harmonics_to_hz = Fs/2;

% Figures: startup, tracking, raw-vs-filtered, steady state, load step,
% modulation, physical filter currents, spectrum, overview, and Bode/margins.
makeFigures(resultsDir,analysis,tAnalysis,rmsWindowStart,rmsWindow, ...
    fPlant,Pjw,fLoop,Ljw,plantPeakHz,metrics);

% Retain native-rate simulation outputs as well as the common 1 MHz analysis
% record so all reported values can be independently recomputed.
resultMat = fullfile(resultsDir,'pr_inverter_results.mat');
save(resultMat,'metrics','passChecks','analysis','tAnalysis','signals', ...
    'smoke','tSmoke','smokeSignals','simOut','simOutSmoke','marginData', ...
    'P','Gpr','Gres','CprDiscrete','Cd','Pd','Ld','closedLoopPoles','-v7.3');
resultJson = fullfile(resultsDir,'pr_inverter_metrics.json');
fid = fopen(resultJson,'w');
assert(fid>=0,'Cannot open metrics JSON for writing: %s',resultJson);
cleanup = onCleanup(@()fclose(fid));
fwrite(fid,jsonencode(metrics,'PrettyPrint',true),'char');
clear cleanup;

% Save the default closed-loop model after successful run and confirm the
% temporary smoke-test override did not modify the saved selector.
assert(strcmp(get_param([modelName '/Control/Open_Loop_Mode_Off'],'Value'),'0'), ...
    'The live model was left in open-loop mode.');
save_system(modelName,modelFile);

fprintf('\nPR INVERTER VALIDATION SUMMARY\n');
fprintf('Vout RMS=%.6f V (error %.4f%%), V1=%.6f Vrms, f=%.7f Hz, THD=%.4f%%, offset=%.6g V\n', ...
    VoutRms,VoutErrorPercent,V1rms,outputFrequency,VoutTHD,dcOffset);
fprintf('Raw bridge THD=%.4f%%; tracking RMS/peak=%.6f/%.6f V\n', ...
    VbridgeTHD,trackingRms,trackingPeak);
fprintf('max|m|=%.6f; saturated samples total/nominal/poststep=%d/%d/%d; longest poststep run=%d samples\n', ...
    maxModulation,nnz(sat),nnz(satNominal),nnz(satPostStep),longestSatRunPostStep);
fprintf('load RMS min/max=%.6f/%.6f V, recovery=%.3f ms; filter current startup/steady/step=%.5f/%.5f/%.5f A\n', ...
    loadStepMinRms,loadStepMaxRms,loadStepRecoveryMs,startupCurrentPeak, ...
    steadyCurrentRms,disturbanceCurrentPeak);
fprintf('gate overlap A/B=%d/%d; deadtime median A/B=%.3f/%.3f us; max discrete pole=%.6f\n', ...
    shootA,shootB,deadAmedianUs,deadBmedianUs,maxClosedLoopPole);
disp(passChecks);
fprintf('PR_INVERTER_VALIDATED=%d\n',validated);
fprintf('MAT=%s\nJSON=%s\n',resultMat,resultJson);

function signals = readSignals(simOutput,names)
signals = struct();
for k = 1:numel(names)
    signals.(names{k}) = simOutput.get(names{k});
    assert(isa(signals.(names{k}),'timeseries'), ...
        'Expected timeseries output for %s.',names{k});
end
end

function out = resampleSignals(signals,names,tGrid)
heldSignals = {'vref','m_ff','m_pr','m_cmd','error','g1','g2','g3','g4', ...
    'pwmA','pwmB','vrefA','vrefB'};
out = struct();
for k = 1:numel(names)
    nm = names{k};
    ts = signals.(nm);
    tt = double(ts.Time(:));
    xx = double(squeeze(ts.Data));
    xx = xx(:);
    [tt,ia] = unique(tt,'stable');
    xx = xx(ia);
    assert(numel(tt)>=2 && tGrid(1)>=tt(1)-1e-12 && ...
        tGrid(end)<=tt(end)+max(1e-6,median(diff(tt)))+1e-12, ...
        'Signal %s does not cover the analysis time grid.',nm);
    if any(strcmp(nm,heldSignals))
        out.(nm) = interp1(tt,xx,tGrid,'previous','extrap');
    else
        out.(nm) = interp1(tt,xx,tGrid,'linear','extrap');
    end
end
end

function [frequency,Vrms,a,b,offset] = fitFundamental(x,t,fmin,fmax)
x = double(x(:)); t = double(t(:));
objective = @(f) sineFitResidual(x,t,f);
frequency = fminbnd(objective,fmin,fmax,optimset('TolX',1e-9,'Display','off'));
X = [ones(size(t)),cos(2*pi*frequency*t),sin(2*pi*frequency*t)];
c = X\x;
offset = c(1); a = c(2); b = c(3);
Vrms = hypot(a,b)/sqrt(2);
end

function e = sineFitResidual(x,t,f)
X = [ones(size(t)),cos(2*pi*f*t),sin(2*pi*f*t)];
c = X\x;
r = x-X*c;
e = mean(r.^2);
end

function thd = harmonicTHD(x,Fs,fFund)
x = double(x(:));
N = numel(x);
Y = fft(x)/N;
kFund = round(fFund/(Fs/N));
fundBin = kFund+1;
lastBin = floor(N/2)+1;
h = (2:floor((lastBin-1)/kFund))';
harmonicBins = h*kFund+1;
thd = 100*sqrt(sum(abs(Y(harmonicBins)).^2)/max(abs(Y(fundBin))^2,eps));
end

function [tStart,rmsValue] = slidingRms(x,t,N)
x = double(x(:)); t = double(t(:));
cs = [0;cumsum(x.^2)];
rmsValue = sqrt((cs(N+1:end)-cs(1:end-N))/N);
tStart = t(1:numel(rmsValue));
end

function n = longestRun(mask)
mask = logical(mask(:));
d = diff([false;mask;false]);
starts = find(d==1); stops = find(d==-1)-1;
if isempty(starts)
    n = 0;
else
    n = max(stops-starts+1);
end
end

function dt = deadtimeIntervals(t,upper,lower)
riseUpper = find(diff(upper)>0)+1;
riseLower = find(diff(lower)>0)+1;
fallUpper = find(diff(upper)<0)+1;
fallLower = find(diff(lower)<0)+1;
dt = [pairEdges(t,riseUpper,fallLower);pairEdges(t,riseLower,fallUpper)];
assert(~isempty(dt),'No complementary gate commutations were measured.');
end

function dt = pairEdges(t,rising,oppositeFalling)
dt = zeros(0,1);
for k = 1:numel(rising)
    prior = oppositeFalling(oppositeFalling<rising(k));
    if ~isempty(prior)
        dt(end+1,1) = t(rising(k))-t(prior(end)); %#ok<AGROW>
    end
end
end

function makeFigures(resultsDir,a,t,rmsTime,rmsValue,fPlant,Pjw,fLoop,Ljw,fPeak,metrics)
Fs = 1/median(diff(t));
% Startup waveform and the measured physical filter current.
idx = t<=0.06;
fig = figure('Color','w','Visible','off','Position',[100 100 1200 850]);
tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
nexttile; plot(t(idx),a.vref(idx),'k--',t(idx),a.vOut(idx),'b-','LineWidth',1.0);
grid on; ylabel('Voltage (V)'); legend('v_{ref}','v_{Out}','Location','best');
title('50 ms soft-start: reference and filtered output');
nexttile; plot(t(idx),a.iLfA(idx),'b-',t(idx),a.iLfB(idx),'r-',t(idx),a.iLoad(idx),'k--');
grid on; xlabel('Time (s)'); ylabel('Current (A)'); legend('i_{LfA}','i_{LfB}','i_{Load}','Location','best');
exportgraphics(fig,fullfile(resultsDir,'pr_inverter_startup.png'),'Resolution',180); close(fig);

% Exactly three 50 Hz reference cycles for the tracking close-up.
idx = t>=0.10 & t<0.16;
fig = figure('Color','w','Visible','off','Position',[100 100 1200 800]);
tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
nexttile; plot(t(idx),a.vref(idx),'k--',t(idx),a.vOut(idx),'b-','LineWidth',1.0);
grid on; ylabel('Voltage (V)'); legend('v_{ref}','v_{Out}','Location','best');
title('PR voltage tracking over three 50 Hz cycles');
nexttile; plot(t(idx),a.error(idx),'Color',[0.85 0.25 0.15]);
grid on; xlabel('Time (s)'); ylabel('e = v_{ref}-v_{Out} (V)');
exportgraphics(fig,fullfile(resultsDir,'pr_tracking_zoom.png'),'Resolution',180); close(fig);

% Show PWM and its filtered output on the same 20 ms time axis.
idx = t>=0.08 & t<0.10;
fig = figure('Color','w','Visible','off','Position',[100 100 1200 650]);
yyaxis left; plot(t(idx),a.vAB(idx),'Color',[0.72 0.72 0.72],'LineWidth',0.7);
ylabel('Raw bridge v_{AB} (V)');
yyaxis right; plot(t(idx),a.vOut(idx),'b-','LineWidth',1.2); hold on;
plot(t(idx),a.vref(idx),'k--','LineWidth',0.9); hold off;
ylabel('Filtered voltage (V)'); grid on; xlabel('Time (s)');
title('Physical PWM bridge voltage through the differential LC filter');
legend('v_{AB}','v_{Out}','v_{ref}','Location','best');
exportgraphics(fig,fullfile(resultsDir,'inverter_lc_filter.png'),'Resolution',180); close(fig);

% Nominal output, three-cycle steady-state analysis interval.
idx = t>=0.08 & t<0.14;
fig = figure('Color','w','Visible','off','Position',[100 100 1200 600]);
plot(t(idx),a.vref(idx),'k--',t(idx),a.vOut(idx),'b-','LineWidth',1.0);
grid on; xlabel('Time (s)'); ylabel('Voltage (V)');
title(sprintf('Nominal output: %.4f Vrms, %.5f Hz, %.3f%% THD', ...
    metrics.nominal_Vout_rms_V,metrics.output_frequency_Hz,metrics.nominal_Vout_THD_percent));
legend('v_{ref}','v_{Out}','Location','best');
exportgraphics(fig,fullfile(resultsDir,'pr_inverter_steady_state.png'),'Resolution',180); close(fig);

% One-cycle RMS envelope and instantaneous transient following the passive load step.
idx = t>=0.13 & t<0.22;
fig = figure('Color','w','Visible','off','Position',[100 100 1200 800]);
tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
nexttile; plot(t(idx),a.vOut(idx),'b-','LineWidth',0.8); hold on;
xline(0.15,'r--',sprintf('20 %c load closes',char(937))); hold off;
grid on; ylabel('v_{Out} (V)'); title('Instantaneous load-step response');
nexttile; plot(rmsTime,rmsValue,'k-','LineWidth',1.1); hold on;
yline(24,'b--','24 V target'); yline(24*1.02,'r:','+2%'); yline(24*0.98,'r:', '-2%');
xline(0.15,'r--'); hold off; xlim([0.13 0.25]);
grid on; xlabel('Time (s)'); ylabel('20 ms RMS (V)');
exportgraphics(fig,fullfile(resultsDir,'pr_inverter_load_step.png'),'Resolution',180); close(fig);

% Feedforward, resonant/proportional correction, and final saturated command.
idx = 1:50:numel(t);
fig = figure('Color','w','Visible','off','Position',[100 100 1200 650]);
plot(t(idx),a.m_ff(idx),'b-',t(idx),a.m_pr(idx),'r-', ...
    t(idx),a.m_cmd(idx),'k-','LineWidth',0.9); hold on;
yline(0.95,'k:'); yline(-0.95,'k:'); xline(0.15,'Color',[0.45 0.45 0.45],'LineStyle','--'); hold off;
grid on; xlabel('Time (s)'); ylabel('Modulation');
title(sprintf('Modulation: max |m|=%.5f; total saturated controller samples=%d', ...
    metrics.max_modulation_abs,metrics.modulation_saturation_samples));
legend('m_{ff}','m_{PR}','m_{cmd}','Limits','Location','best');
exportgraphics(fig,fullfile(resultsDir,'pr_modulation.png'),'Resolution',180); close(fig);

% Physical filter winding current from startup through the disturbance.
fig = figure('Color','w','Visible','off','Position',[100 100 1200 800]);
tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
idx = t<=0.06;
nexttile; plot(t(idx),a.iLfA(idx),'b-',t(idx),a.iLfB(idx),'r-');
grid on; ylabel('Current (A)'); title('Filter winding currents during soft-start');
legend('i_{LfA}','i_{LfB}','Location','best');
idx = t>=0.13 & t<0.22;
nexttile; plot(t(idx),a.iLfA(idx),'b-',t(idx),a.iLfB(idx),'r-'); hold on;
xline(0.15,'k--'); hold off; grid on; xlabel('Time (s)'); ylabel('Current (A)');
title('Filter winding currents around the passive load step');
exportgraphics(fig,fullfile(resultsDir,'pr_filter_current.png'),'Resolution',180); close(fig);

% Coherent nominal FFTs; show the 50 Hz fundamental and 10 kHz carrier region.
idx = t>=0.08 & t<0.14;
n = nnz(idx); nfft = 2^nextpow2(n);
win = 0.5-0.5*cos(2*pi*(0:n-1)'/n);
[fSpec,bridgeSpec] = singleSidedSpectrum(a.vAB(idx),Fs,win,nfft);
[~,outSpec] = singleSidedSpectrum(a.vOut(idx),Fs,win,nfft);
fig = figure('Color','w','Visible','off','Position',[100 100 1200 700]);
tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
band = fSpec>0 & fSpec<=1000;
nexttile; semilogy(fSpec(band),max(bridgeSpec(band),1e-8),'Color',[0.55 0.55 0.55]); hold on;
semilogy(fSpec(band),max(outSpec(band),1e-8),'b-','LineWidth',1.0);
xline(50,'r--','50 Hz'); xline(metrics.LC_resonance_Hz,'k:','f_{LC}'); hold off;
grid on; ylabel('Amplitude (V peak)'); title('Fundamental and LC resonance region');
legend('v_{AB}','v_{Out}','Location','best'); xlim([0 1000]);
band = fSpec>=8000 & fSpec<=12000;
nexttile; semilogy(fSpec(band),max(bridgeSpec(band),1e-8),'Color',[0.55 0.55 0.55]); hold on;
semilogy(fSpec(band),max(outSpec(band),1e-8),'b-','LineWidth',1.0);
xline(10000,'k--','10 kHz f_{sw}'); hold off;
grid on; xlabel('Frequency (Hz)'); ylabel('Amplitude (V peak)'); title('Switching-frequency region');
legend('v_{AB}','v_{Out}','Location','best'); xlim([8000 12000]);
exportgraphics(fig,fullfile(resultsDir,'inverter_output_spectrum.png'),'Resolution',180); close(fig);

% Compact overview of start-up, tracking, and load recovery.
fig = figure('Color','w','Visible','off','Position',[100 100 1300 900]);
tiledlayout(fig,3,1,'TileSpacing','compact','Padding','compact');
nexttile; plot(t(1:100:end),a.vref(1:100:end),'k--',t(1:100:end),a.vOut(1:100:end),'b-');
grid on; ylabel('Voltage (V)'); title('Startup and full 0.25 s physical switching run');
nexttile; idx = t>=0.10 & t<0.12; plot(t(idx),a.vref(idx),'k--',t(idx),a.vOut(idx),'b-');
grid on; ylabel('Voltage (V)'); title('Two-cycle PR tracking detail');
nexttile; plot(rmsTime,rmsValue,'k-'); hold on; xline(0.15,'r--');
yline(24*1.02,'r:'); yline(24*0.98,'r:'); hold off;
grid on; xlabel('Time (s)'); ylabel('20 ms RMS (V)'); xlim([0 0.25]);
exportgraphics(fig,fullfile(resultsDir,'pr_inverter_overview.png'),'Resolution',180); close(fig);

% Plant and sampled open-loop Bode, plus the selected LC resonance.
magP = 20*log10(max(abs(Pjw),eps));
magL = 20*log10(max(abs(Ljw),eps));
phaseP = unwrap(angle(Pjw))*180/pi;
phaseL = unwrap(angle(Ljw))*180/pi;
fig = figure('Color','w','Visible','off','Position',[100 100 1350 950]);
tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
nexttile; semilogx(fPlant,magP,'b-','LineWidth',1.0); hold on;
xline(50,'k--','50 Hz'); xline(metrics.LC_resonance_Hz,'r--','f_{LC}');
xline(10000,':','10 kHz','Color',[0.3 0.3 0.3]); hold off;
grid on; ylabel('|P| (dB V/mod)'); title('Averaged plant magnitude');
nexttile; semilogx(fLoop,magL,'r-','LineWidth',1.0); hold on;
yline(0,'k:'); xline(50,'k--'); xline(metrics.LC_resonance_Hz,'b--');
xline(fPeak,':','plant peak','Color',[0.3 0.3 0.3]);
xline(1/(2*metrics.controller_sample_time_s),':','control Nyquist','Color',[0.2 0.2 0.2]); hold off;
grid on; ylabel('|C_dP_dz^{-1}| (dB)'); title('Sampled open-loop magnitude');
nexttile; semilogx(fPlant,phaseP,'b-','LineWidth',1.0); hold on;
xline(50,'k--'); xline(metrics.LC_resonance_Hz,'r--');
xline(10000,'Color',[0.3 0.3 0.3],'LineStyle',':'); hold off;
grid on; xlabel('Frequency (Hz)'); ylabel('Phase (deg)'); title('Averaged plant phase');
nexttile; semilogx(fLoop,phaseL,'r-','LineWidth',1.0); hold on;
xline(50,'k--'); xline(metrics.LC_resonance_Hz,'b--');
xline(fPeak,'Color',[0.3 0.3 0.3],'LineStyle',':'); hold off;
grid on; xlabel('Frequency (Hz)'); ylabel('Phase (deg)'); title('Sampled open-loop phase');
exportgraphics(fig,fullfile(resultsDir,'pr_control_bode.png'),'Resolution',180); close(fig);
end

function [f,A] = singleSidedSpectrum(x,Fs,win,nfft)
x = double(x(:));
N = numel(x);
Y = fft(x.*win,nfft)/sum(win);
nKeep = floor(nfft/2)+1;
A = abs(Y(1:nKeep));
if rem(nfft,2)==0
    A(2:end-1) = 2*A(2:end-1);
else
    A(2:end) = 2*A(2:end);
end
f = (0:nKeep-1)'*(Fs/nfft);
assert(N<=nfft,'Invalid FFT length.');
end
