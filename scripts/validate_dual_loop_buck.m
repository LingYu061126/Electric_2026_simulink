% Reproduce the independent current-loop test and full physical Buck run.
root = fileparts(fileparts(mfilename('fullpath')));
modelFile = fullfile(root, 'models', 'buck_dual_loop_r2024a.slx');
resultsDir = fullfile(root, 'results');
open_system(modelFile);
modePath = Simulink.ID.getFullName('buck_dual_loop_r2024a:50');
currentPiPath = Simulink.ID.getFullName('buck_dual_loop_r2024a:46');
voltagePiPath = Simulink.ID.getFullName('buck_dual_loop_r2024a:27');

% Current-loop-only: select the real 0 -> 1.2 A test reference at 10 ms.
in = Simulink.SimulationInput('buck_dual_loop_r2024a');
in = in.setModelParameter('StopTime', '0.08');
in = in.setBlockParameter(modePath, 'Value', '0');
currentTestOut = sim(in);
% Full dual loop: the saved model selects the voltage PI current reference.
assert(strcmp(get_param(modePath, 'Value'), '1'), ...
    'Saved model is not in dual-loop mode.');
out = sim('buck_dual_loop_r2024a');

testNames = {'iLref_ts','iL_ts','iLavg_ts','Duty_ts','Vout_ts'};
fullNames = {'Vin_ts','Vref_ts','Vout_ts','Error_ts','iLref_ts', ...
    'iL_ts','iLavg_ts','CurrentError_ts','Duty_ts','PWM_ts','Iload_ts'};
for k = 1:numel(testNames)
    x = currentTestOut.get(testNames{k});
    assert(~isempty(x.Time) && all(isfinite(x.Time)) && ...
        all(isfinite(x.Data(:))), 'Current test has empty/nonfinite data.');
end
for k = 1:numel(fullNames)
    x = out.get(fullNames{k});
    assert(~isempty(x.Time) && all(isfinite(x.Time)) && ...
        all(isfinite(x.Data(:))), 'Full run has empty/nonfinite data.');
end

t = out.Vout_ts.Time;
v = squeeze(out.Vout_ts.Data);
vref = squeeze(out.Vref_ts.Data);
vin = squeeze(out.Vin_ts.Data);
il = squeeze(out.iL_ts.Data);
tavg = out.iLavg_ts.Time;
ilavg = squeeze(out.iLavg_ts.Data);
ir = squeeze(out.iLref_ts.Data);
iload = squeeze(out.Iload_ts.Data);
pwm = squeeze(out.PWM_ts.Data);
td = out.Duty_ts.Time;
duty = squeeze(out.Duty_ts.Data);
nominal = t >= 0.08 & t < 0.10;
loadTransient = t >= 0.10 & t < 0.15;
loadSteady = t >= 0.13 & t < 0.15;
lineTransient = t >= 0.15 & t <= 0.25;
lineSteady = t >= 0.23 & t <= 0.25;
startup = t < 0.10;
assert(nnz(nominal) > 100 && nnz(loadSteady) > 100 && ...
    nnz(lineSteady) > 100, 'Insufficient measurement samples.');

metrics = struct();
metrics.MATLAB = version;
metrics.model = modelFile;
metrics.Kp_i = str2double(get_param(currentPiPath, 'P'));
metrics.Ki_i = str2double(get_param(currentPiPath, 'I'));
metrics.Kp_v = str2double(get_param(voltagePiPath, 'P'));
metrics.Ki_v = str2double(get_param(voltagePiPath, 'I'));
metrics.current_reference_limit_A = ...
    str2double(get_param(voltagePiPath, 'UpperSaturationLimit'));
metrics.duty_min_limit = str2double(get_param(currentPiPath, 'LowerSaturationLimit'));
metrics.duty_max_limit = str2double(get_param(currentPiPath, 'UpperSaturationLimit'));
metrics.current_anti_windup = get_param(currentPiPath, 'AntiWindupMode');
metrics.voltage_anti_windup = get_param(voltagePiPath, 'AntiWindupMode');
metrics.control_sample_time_s = str2double(get_param(currentPiPath, 'SampleTime'));
metrics.feedback_cycle_average_samples = 20;
metrics.feedback_cycle_average_sample_time_s = 5e-6;
metrics.feedback_unit_delay_s = 1e-4;

% CCM averaged plants and a stated approximate sensor/computation delay.
s = tf('s');
Vin0 = 24; L = 1e-3; C = 470e-6; R = 10;
Gid = Vin0 * (C*s + 1/R) / (L*C*s^2 + (L/R)*s + 1);
Gvi = 1 / (C*s + 1/R);
Ci = metrics.Kp_i + metrics.Ki_i/s;
Cv = metrics.Kp_v + metrics.Ki_v/s;
delaySeconds = 150e-6; % 100 us digital delay + ~50 us FIR group delay.
Li = Ci * Gid * exp(-s*delaySeconds);
[gmi, pmi, ~, wci] = margin(Li);
Ti = feedback(Li, 1);
[gmv, pmv, ~, wcv] = margin(Cv * Gvi * Ti);
metrics.analysis_delay_assumption_s = delaySeconds;
metrics.fci_hz = wci/(2*pi);
metrics.phase_margin_i_deg = pmi;
metrics.gain_margin_i_db = 20*log10(gmi);
metrics.fcv_hz = wcv/(2*pi);
metrics.phase_margin_v_deg = pmv;
metrics.gain_margin_v_db = 20*log10(gmv);
metrics.bandwidth_ratio = metrics.fci_hz / metrics.fcv_hz;

tc = currentTestOut.iLavg_ts.Time;
ic = squeeze(currentTestOut.iLavg_ts.Data);
traw = currentTestOut.iL_ts.Time;
iraw = squeeze(currentTestOut.iL_ts.Data);
trefc = currentTestOut.iLref_ts.Time;
irefc = squeeze(currentTestOut.iLref_ts.Data);
tdc = currentTestOut.Duty_ts.Time;
dc = squeeze(currentTestOut.Duty_ts.Data);
afterStep = tc >= 0.01;
finalCurrent = tc >= 0.06 & tc <= 0.08;
finalRawCurrent = traw >= 0.06 & traw <= 0.08;
targetCurrent = mean(irefc(trefc >= 0.06));
stepTimes = tc(afterStep); stepCurrent = ic(afterStep);
i10 = find(stepCurrent >= 0.1*targetCurrent, 1, 'first');
i90 = find(stepCurrent >= 0.9*targetCurrent, 1, 'first');
metrics.current_test.reference_A = targetCurrent;
metrics.current_test.average_current_mean_A = mean(ic(finalCurrent));
metrics.current_test.raw_current_mean_A = mean(iraw(finalRawCurrent));
metrics.current_test.average_current_peak_A = max(ic(afterStep));
metrics.current_test.raw_current_peak_A = max(iraw(traw >= 0.01));
metrics.current_test.average_overshoot_percent = ...
    max(0, metrics.current_test.average_current_peak_A - targetCurrent) ...
    / targetCurrent * 100;
metrics.current_test.steady_error_A = ...
    abs(metrics.current_test.average_current_mean_A - targetCurrent);
metrics.current_test.rise_time_s = stepTimes(i90) - stepTimes(i10);
currentIdx = find(tc >= 0.01 & tc <= 0.08);
lastOutside = find(abs(ic(currentIdx)-targetCurrent) > 0.05*targetCurrent, ...
    1, 'last');
if isempty(lastOutside)
    metrics.current_test.settling_time_s = 0;
elseif lastOutside < numel(currentIdx)
    metrics.current_test.settling_time_s = tc(currentIdx(lastOutside+1)) - 0.01;
else
    metrics.current_test.settling_time_s = NaN;
end
metrics.current_test.duty_min = min(dc);
metrics.current_test.duty_max = max(dc);
metrics.current_test.passed = metrics.current_test.steady_error_A < 0.05 ...
    && abs(metrics.current_test.raw_current_mean_A - targetCurrent) < 0.05;

metrics.startup_Vout_peak_V = max(v(startup));
metrics.startup_iL_peak_A = max(il(startup));
metrics.startup_iL_ref_peak_A = max(ir(startup));
metrics.startup_duty_peak = max(duty(td < 0.10));
startupTimes = t(startup);
i10 = find(v(startup) >= 1.2, 1, 'first');
i90 = find(v(startup) >= 10.8, 1, 'first');
metrics.startup_rise_time_s = startupTimes(i90) - startupTimes(i10);
idx = find(t >= 0.05 & t < 0.10);
lastOutside = find(abs(v(idx)-12) > 0.12, 1, 'last');
if isempty(lastOutside)
    metrics.startup_settling_time_s = 0.05;
elseif lastOutside < numel(idx)
    metrics.startup_settling_time_s = t(idx(lastOutside+1));
else
    metrics.startup_settling_time_s = NaN;
end

metrics.nominal_Vout_V = mean(v(nominal));
metrics.nominal_error_percent = abs(metrics.nominal_Vout_V-12)/12*100;
metrics.nominal_Vout_pp_V = max(v(nominal))-min(v(nominal));
metrics.nominal_iL_mean_A = mean(il(nominal));
metrics.nominal_iL_pp_A = max(il(nominal))-min(il(nominal));
metrics.nominal_iL_min_A = min(il(nominal));
metrics.nominal_duty_mean = mean(duty(td >= 0.08 & td < 0.10));

metrics.load_step_Vout_min_V = min(v(loadTransient));
metrics.load_step_Vout_max_V = max(v(loadTransient));
metrics.load_step_deviation_percent = max(abs(v(loadTransient)-12))/12*100;
metrics.load_step_iL_ref_peak_A = max(ir(loadTransient));
metrics.load_step_iL_peak_A = max(il(loadTransient));
metrics.load_step_new_steady_Vout_V = mean(v(loadSteady));
metrics.load_step_new_steady_iL_min_A = min(il(loadSteady));
idx = find(loadTransient);
lastOutside = find(abs(v(idx)-12) > 0.12, 1, 'last');
if isempty(lastOutside)
    metrics.load_step_recovery_ms = 0;
elseif lastOutside < numel(idx)
    metrics.load_step_recovery_ms = (t(idx(lastOutside+1))-0.10)*1e3;
else
    metrics.load_step_recovery_ms = NaN;
end

metrics.line_step_Vin_before_V = mean(vin(nominal));
metrics.line_step_Vin_after_V = mean(vin(lineSteady));
metrics.line_step_Vout_min_V = min(v(lineTransient));
metrics.line_step_Vout_max_V = max(v(lineTransient));
metrics.line_step_deviation_percent = max(abs(v(lineTransient)-12))/12*100;
metrics.line_step_iL_ref_peak_A = max(ir(lineTransient));
metrics.line_step_iL_peak_A = max(il(lineTransient));
metrics.line_step_final_Vout_V = mean(v(lineSteady));
metrics.line_step_final_duty = mean(duty(td >= 0.23 & td <= 0.25));
idx = find(lineTransient);
lastOutside = find(abs(v(idx)-12) > 0.12, 1, 'last');
if isempty(lastOutside)
    metrics.line_step_recovery_ms = 0;
elseif lastOutside < numel(idx)
    metrics.line_step_recovery_ms = (t(idx(lastOutside+1))-0.15)*1e3;
else
    metrics.line_step_recovery_ms = NaN;
end

metrics.duty_min_measured = min(duty);
metrics.duty_max_measured = max(duty);
metrics.iL_ref_max_measured_A = max(ir);
metrics.iL_max_measured_A = max(il);
riseTimes = t(find(diff(pwm > 5) == 1) + 1);
riseTimes = riseTimes(riseTimes >= 0.18 & riseTimes <= 0.25);
assert(numel(riseTimes) > 100, 'Insufficient PWM cycles.');
metrics.PWM_frequency_measured_Hz = 1/median(diff(riseTimes));

base = jsondecode(fileread(fullfile(resultsDir, ...
    'closed_loop_buck_metrics.json')));
metrics.single_loop.startup_Vout_peak_V = base.startup.Vout_peak;
metrics.single_loop.startup_iL_peak_A = base.startup.iL_peak;
metrics.single_loop.nominal_error_percent = ...
    base.nominal.steady_state_error_V / 12 * 100;
metrics.single_loop.load_step_deviation_percent = ...
    base.load_step.max_deviation_percent;
metrics.single_loop.load_step_recovery_ms = ...
    base.load_step.recovery_time_seconds*1e3;
metrics.single_loop.line_step_deviation_percent = ...
    base.line_step.max_deviation_percent;
metrics.single_loop.line_step_recovery_ms = ...
    base.line_step.recovery_time_seconds*1e3;

metrics.validation.created = isfile(modelFile);
metrics.validation.opened = true;
metrics.validation.compiled = true;
metrics.validation.simulated = true;
metrics.validation.measured = true;
metrics.validation.no_nan_or_inf = true;
metrics.validation.current_test_pass = metrics.current_test.passed;
metrics.validation.nominal_pass = metrics.nominal_error_percent < 1;
metrics.validation.startup_reasonable = ...
    metrics.startup_Vout_peak_V < 13 && metrics.startup_iL_peak_A < 2;
metrics.validation.load_step_pass = metrics.load_step_deviation_percent < 10 ...
    && isfinite(metrics.load_step_recovery_ms) ...
    && abs(metrics.load_step_new_steady_Vout_V-12) < 0.12;
metrics.validation.line_recovery_pass = ...
    isfinite(metrics.line_step_recovery_ms) ...
    && abs(metrics.line_step_final_Vout_V-12) < 0.12;
metrics.validation.current_limit_respected = ...
    metrics.iL_ref_max_measured_A <= metrics.current_reference_limit_A+1e-9 ...
    && metrics.iL_max_measured_A < 4;
metrics.validation.PWM_pass = ...
    abs(metrics.PWM_frequency_measured_Hz-1e4) < 1 ...
    && all(duty >= 0.05-1e-9) && all(duty <= 0.95+1e-9);
metrics.validation.CCM_nominal = metrics.nominal_iL_min_A > 0;
metrics.validation.CCM_post_load = metrics.load_step_new_steady_iL_min_A > 0;
metrics.dual_loop_passed = metrics.validation.current_test_pass ...
    && metrics.validation.nominal_pass ...
    && metrics.validation.startup_reasonable ...
    && metrics.validation.load_step_pass ...
    && metrics.validation.line_recovery_pass ...
    && metrics.validation.current_limit_respected ...
    && metrics.validation.PWM_pass;

save(fullfile(resultsDir,'dual_loop_current_test.mat'), ...
    'currentTestOut','-v7.3');
save(fullfile(resultsDir,'dual_loop_buck_results.mat'), ...
    'out','currentTestOut','metrics','-v7.3');
fid = fopen(fullfile(resultsDir,'dual_loop_buck_metrics.json'),'w');
assert(fid > 0, 'Cannot write metrics JSON.');
fprintf(fid,'%s\n',jsonencode(metrics,'PrettyPrint',true));
fclose(fid);

fig = figure('Visible','off','Color','w');
tiledlayout(3,1,'TileSpacing','compact');
nexttile; plot(traw,iraw,'Color',[.8 .8 .8]); hold on;
plot(tc,ic,'b','LineWidth',1.1); plot(trefc,irefc,'k--','LineWidth',1.1);
xline(0.01,'--'); grid on; ylabel('Current (A)');
legend('raw iL','cycle average','iL ref','Location','southeast');
nexttile; plot(tc,ic); xline(0.01,'--'); grid on; ylabel('Avg iL (A)');
nexttile; stairs(tdc,dc); xline(0.01,'--'); grid on;
ylabel('Duty'); xlabel('Time (s)');
exportgraphics(fig,fullfile(resultsDir,'dual_loop_current_loop_test.png'),'Resolution',160);
close(fig);

fig = figure('Visible','off','Color','w');
tiledlayout(3,1,'TileSpacing','compact');
idx = t < 0.10; id = td < 0.10;
nexttile; plot(t(idx),vref(idx),'--',t(idx),v(idx));
yline(12,':'); grid on; ylabel('V (V)'); legend('Vref','Vout','12 V');
nexttile; plot(t(idx),ir(idx),'--',t(idx),il(idx)); grid on;
ylabel('Current (A)'); legend('iL ref','iL');
nexttile; stairs(td(id),duty(id)); grid on; ylabel('Duty'); xlabel('Time (s)');
exportgraphics(fig,fullfile(resultsDir,'dual_loop_startup.png'),'Resolution',160);
close(fig);

fig = figure('Visible','off','Color','w');
tiledlayout(3,1,'TileSpacing','compact');
idx=t>=.095&t<.10; id=td>=.095&td<.10;
nexttile; plot(t(idx),v(idx)); grid on; ylabel('Vout (V)');
idxAvg=tavg>=.095&tavg<.10;
nexttile; plot(t(idx),ir(idx),'--',tavg(idxAvg),ilavg(idxAvg),t(idx),il(idx));
grid on; ylabel('Current (A)'); legend('iL ref','cycle avg','raw iL');
nexttile; stairs(td(id),duty(id)); grid on; ylabel('Duty'); xlabel('Time (s)');
exportgraphics(fig,fullfile(resultsDir,'dual_loop_steady_state.png'),'Resolution',160);
close(fig);

fig = figure('Visible','off','Color','w');
tiledlayout(4,1,'TileSpacing','compact');
idx=t>=.095&t<.15; id=td>=.095&td<.15;
nexttile; plot(t(idx),v(idx)); xline(.10,'--'); grid on; ylabel('Vout (V)');
idxAvg=tavg>=.095&tavg<.15;
nexttile; plot(t(idx),il(idx),'Color',[.8 .8 .8]); hold on;
plot(tavg(idxAvg),ilavg(idxAvg),'b','LineWidth',1.1);
plot(t(idx),ir(idx),'k--','LineWidth',1.1);
xline(.10,'--'); grid on; ylabel('Current (A)');
legend('raw iL','cycle average','iL ref');
nexttile; stairs(td(id),duty(id)); xline(.10,'--'); grid on; ylabel('Duty');
nexttile; plot(t(idx),iload(idx)); xline(.10,'--'); grid on;
ylabel('Iload (A)'); xlabel('Time (s)');
exportgraphics(fig,fullfile(resultsDir,'dual_loop_load_step.png'),'Resolution',160);
close(fig);

fig = figure('Visible','off','Color','w');
tiledlayout(4,1,'TileSpacing','compact');
idx=t>=.145&t<=.25; id=td>=.145&td<=.25;
nexttile; plot(t(idx),vin(idx)); xline(.15,'--'); grid on; ylabel('Vin (V)');
nexttile; plot(t(idx),v(idx)); xline(.15,'--'); grid on; ylabel('Vout (V)');
nexttile; plot(t(idx),ir(idx),'--',t(idx),il(idx)); xline(.15,'--');
grid on; ylabel('Current (A)'); legend('iL ref','raw iL');
nexttile; stairs(td(id),duty(id)); xline(.15,'--'); grid on;
ylabel('Duty'); xlabel('Time (s)');
exportgraphics(fig,fullfile(resultsDir,'dual_loop_line_step.png'),'Resolution',160);
close(fig);

fig = figure('Visible','off','Color','w');
plot(t,ir,'--',tavg,ilavg,t,il); xline(.10,'--'); xline(.15,'--');
grid on; xlabel('Time (s)'); ylabel('Current (A)');
legend('iL ref','cycle average','raw iL');
exportgraphics(fig,fullfile(resultsDir,'dual_loop_current_tracking.png'),'Resolution',160);
close(fig);

fig = figure('Visible','off','Color','w');
stairs(td,duty); xline(.10,'--'); xline(.15,'--'); grid on;
xlabel('Time (s)'); ylabel('Duty');
exportgraphics(fig,fullfile(resultsDir,'dual_loop_duty.png'),'Resolution',160);
close(fig);

fig = figure('Visible','off','Color','w');
tiledlayout(5,1,'TileSpacing','compact');
nexttile; plot(t,vin); grid on; ylabel('Vin (V)');
nexttile; plot(t,vref,'--',t,v); grid on; ylabel('V (V)');
legend('Vref','Vout');
nexttile; plot(t,iload); grid on; ylabel('Iload (A)');
nexttile; plot(t,ir,'--',t,il); grid on; ylabel('iL (A)');
legend('reference','actual');
nexttile; stairs(td,duty); grid on; ylabel('Duty'); xlabel('Time (s)');
exportgraphics(fig,fullfile(resultsDir,'dual_loop_overview.png'),'Resolution',160);
close(fig);

disp(metrics);
