% Re-run and measure the saved R2024a physical switching Buck model.
root = fileparts(fileparts(mfilename('fullpath')));
modelFile = fullfile(root, 'models', 'buck_closed_loop_r2024a.slx');
resultsDir = fullfile(root, 'results');
open_system(modelFile);
set_param('buck_closed_loop_r2024a', 'SimulationCommand', 'update');
out = sim('buck_closed_loop_r2024a');
metrics = struct();

names = {'Vin_ts','Vref_ts','Vout_ts','Error_ts','Duty_ts', ...
    'PWM_ts','iL_ts','Iload_ts','Istep_ts'};
for k = 1:numel(names)
    sig = out.get(names{k});
    assert(~isempty(sig.Time) && all(isfinite(sig.Time)) && ...
        all(isfinite(sig.Data(:))), 'A logged signal is empty or nonfinite.');
end

t = out.Vout_ts.Time;
v = squeeze(out.Vout_ts.Data);
vref = squeeze(out.Vref_ts.Data);
vin = squeeze(out.Vin_ts.Data);
il = squeeze(out.iL_ts.Data);
iload = squeeze(out.Iload_ts.Data);
pwm = squeeze(out.PWM_ts.Data);
td = out.Duty_ts.Time;
duty = squeeze(out.Duty_ts.Data);

nominal = t >= 0.08 & t < 0.10;
loadSteady = t >= 0.13 & t < 0.15;
lineSteady = t >= 0.23 & t <= 0.25;
startup = t < 0.10;
loadTransient = t >= 0.10 & t < 0.15;
lineTransient = t >= 0.15 & t <= 0.25;
assert(nnz(nominal) > 100 && nnz(loadSteady) > 100 && ...
    nnz(lineSteady) > 100, 'Measurement windows have too few samples.');

piPath = Simulink.ID.getFullName('buck_closed_loop_r2024a:27');
rampPath = Simulink.ID.getFullName('buck_closed_loop_r2024a:24');
metrics.environment.MATLAB = version;
metrics.model = modelFile;
metrics.controller.Kp = str2double(get_param(piPath, 'P'));
metrics.controller.Ki = str2double(get_param(piPath, 'I'));
metrics.controller.duty_min_limit = ...
    str2double(get_param(piPath, 'LowerSaturationLimit'));
metrics.controller.duty_max_limit = ...
    str2double(get_param(piPath, 'UpperSaturationLimit'));
metrics.controller.anti_windup = get_param(piPath, 'AntiWindupMode');
metrics.controller.soft_start_seconds = 12 / ...
    str2double(get_param(rampPath, 'slope'));
metrics.controller.duty_min_measured = min(duty);
metrics.controller.duty_max_measured = max(duty);

metrics.nominal.Vin_mean = mean(vin(nominal));
metrics.nominal.Vout_mean = mean(v(nominal));
metrics.nominal.steady_state_error_V = abs(metrics.nominal.Vout_mean - 12);
metrics.nominal.Vout_pp = max(v(nominal)) - min(v(nominal));
metrics.nominal.iL_mean = mean(il(nominal));
metrics.nominal.iL_pp = max(il(nominal)) - min(il(nominal));
metrics.nominal.iL_min = min(il(nominal));
metrics.nominal.Iload_mean = mean(iload(nominal));
metrics.nominal.duty_mean = mean(duty(td >= 0.08 & td < 0.10));

metrics.startup.Vout_peak = max(v(startup));
metrics.startup.overshoot_percent = max(0, metrics.startup.Vout_peak - 12) / 12 * 100;
metrics.startup.iL_peak = max(il(startup));
i10 = find(v(startup) >= 1.2, 1, 'first');
i90 = find(v(startup) >= 10.8, 1, 'first');
startupTimes = t(startup);
metrics.startup.rise_time_seconds = startupTimes(i90) - startupTimes(i10);
startupSettleIdx = find(t >= 0.05 & t < 0.10);
lastOutside = find(abs(v(startupSettleIdx) - 12) > 0.12, 1, 'last');
if isempty(lastOutside)
    metrics.startup.settling_time_seconds = 0.05;
elseif lastOutside < numel(startupSettleIdx)
    metrics.startup.settling_time_seconds = t(startupSettleIdx(lastOutside + 1));
else
    metrics.startup.settling_time_seconds = NaN;
end
base = load(fullfile(resultsDir, 'buck_results.mat'), 'Vout', 'iL');
metrics.startup.open_loop_Vout_peak = max(base.Vout.Data);
metrics.startup.open_loop_iL_peak = max(base.iL.Data);
metrics.startup.Vout_peak_reduction_percent = ...
    (metrics.startup.open_loop_Vout_peak - metrics.startup.Vout_peak) ...
    / metrics.startup.open_loop_Vout_peak * 100;
metrics.startup.iL_peak_reduction_percent = ...
    (metrics.startup.open_loop_iL_peak - metrics.startup.iL_peak) ...
    / metrics.startup.open_loop_iL_peak * 100;

metrics.load_step.before_ohm = 10;
metrics.load_step.after_ohm = 5;
metrics.load_step.time_seconds = 0.10;
metrics.load_step.Vout_min = min(v(loadTransient));
metrics.load_step.Vout_max = max(v(loadTransient));
metrics.load_step.max_deviation_percent = ...
    max(abs(v(loadTransient) - 12)) / 12 * 100;
metrics.load_step.new_steady_Vout_mean = mean(v(loadSteady));
metrics.load_step.new_steady_Iload_mean = mean(iload(loadSteady));
metrics.load_step.iL_min = min(il(loadSteady));
metrics.load_step.duty_mean = mean(duty(td >= 0.13 & td < 0.15));
loadIdx = find(loadTransient);
lastOutside = find(abs(v(loadIdx) - 12) > 0.12, 1, 'last');
if isempty(lastOutside)
    metrics.load_step.recovery_time_seconds = 0;
elseif lastOutside < numel(loadIdx)
    metrics.load_step.recovery_time_seconds = t(loadIdx(lastOutside + 1)) - 0.10;
else
    metrics.load_step.recovery_time_seconds = NaN;
end

metrics.line_step.before_V = mean(vin(nominal));
metrics.line_step.after_V = mean(vin(lineSteady));
metrics.line_step.time_seconds = 0.15;
metrics.line_step.Vout_min = min(v(lineTransient));
metrics.line_step.Vout_max = max(v(lineTransient));
metrics.line_step.max_deviation_percent = ...
    max(abs(v(lineTransient) - 12)) / 12 * 100;
metrics.line_step.new_steady_Vout_mean = mean(v(lineSteady));
metrics.line_step.new_steady_Iload_mean = mean(iload(lineSteady));
metrics.line_step.iL_min = min(il(lineSteady));
metrics.line_step.iL_min_transient = min(il(lineTransient));
metrics.line_step.duty_mean = mean(duty(td >= 0.23 & td <= 0.25));
lineIdx = find(lineTransient);
lastOutside = find(abs(v(lineIdx) - 12) > 0.12, 1, 'last');
if isempty(lastOutside)
    metrics.line_step.recovery_time_seconds = 0;
elseif lastOutside < numel(lineIdx)
    metrics.line_step.recovery_time_seconds = t(lineIdx(lastOutside + 1)) - 0.15;
else
    metrics.line_step.recovery_time_seconds = NaN;
end

riseTimes = t(find(diff(pwm > 5) == 1) + 1);
riseTimes = riseTimes(riseTimes >= 0.18 & riseTimes <= 0.25);
assert(numel(riseTimes) > 100, 'Too few PWM cycles measured.');
metrics.PWM.frequency_measured_Hz = 1 / median(diff(riseTimes));
metrics.PWM.gate_low_V = min(pwm);
metrics.PWM.gate_high_V = max(pwm);
metrics.PWM.duty_changes = max(duty) - min(duty) > 0.1;

metrics.validation.created = isfile(modelFile);
metrics.validation.opened = true;
metrics.validation.compiled = true;
metrics.validation.simulated = true;
metrics.validation.measured = true;
metrics.validation.no_nan_or_inf = true;
metrics.validation.nominal_error_pass = metrics.nominal.steady_state_error_V < 0.12;
metrics.validation.startup_pass = metrics.startup.Vout_peak < 15 && ...
    metrics.startup.iL_peak < metrics.startup.open_loop_iL_peak;
metrics.validation.load_deviation_pass = ...
    metrics.load_step.max_deviation_percent < 10;
metrics.validation.load_recovery_pass = ...
    isfinite(metrics.load_step.recovery_time_seconds) && ...
    abs(metrics.load_step.new_steady_Vout_mean - 12) < 0.12;
metrics.validation.line_recovery_pass = ...
    isfinite(metrics.line_step.recovery_time_seconds) && ...
    abs(metrics.line_step.new_steady_Vout_mean - 12) < 0.12;
metrics.validation.PWM_pass = abs(metrics.PWM.frequency_measured_Hz - 1e4) < 1 ...
    && all(duty >= 0.05 - 1e-9) && all(duty <= 0.95 + 1e-9) ...
    && metrics.PWM.duty_changes;
metrics.validation.CCM_pre = metrics.nominal.iL_min > 0;
metrics.validation.CCM_post_load = metrics.load_step.iL_min > 0;
metrics.validation.validated = metrics.validation.nominal_error_pass && ...
    metrics.validation.startup_pass && metrics.validation.load_deviation_pass && ...
    metrics.validation.load_recovery_pass && ...
    metrics.validation.line_recovery_pass && metrics.validation.PWM_pass;

save(fullfile(resultsDir, 'closed_loop_buck_results.mat'), ...
    'out', 'metrics', '-v7.3');
fid = fopen(fullfile(resultsDir, 'closed_loop_buck_metrics.json'), 'w');
assert(fid > 0, 'Unable to write JSON metrics.');
fprintf(fid, '%s\n', jsonencode(metrics, 'PrettyPrint', true));
fclose(fid);

fig = figure('Visible', 'off', 'Color', 'w');
idx = t <= 0.10;
plot(t(idx), vref(idx), '--', t(idx), v(idx), 'LineWidth', 1.1); hold on;
yline(12, ':');
[peak, loc] = max(v(idx)); startupTime = t(idx);
scatter(startupTime(loc), peak, 32, 'filled');
grid on; xlabel('Time (s)'); ylabel('Voltage (V)');
legend('Vref','Vout','12 V target','Vout peak', 'Location','southeast');
title('Closed-loop soft start');
exportgraphics(fig, fullfile(resultsDir,'closed_loop_startup.png'), 'Resolution',160);
close(fig);

fig = figure('Visible', 'off', 'Color', 'w');
tiledlayout(3,1,'TileSpacing','compact');
idx = t >= 0.095 & t < 0.10; id = td >= 0.095 & td < 0.10;
nexttile; plot(t(idx),v(idx)); grid on; ylabel('Vout (V)');
nexttile; plot(t(idx),il(idx)); grid on; ylabel('iL (A)');
nexttile; stairs(td(id),duty(id)); grid on; ylabel('Duty'); xlabel('Time (s)');
exportgraphics(fig,fullfile(resultsDir,'closed_loop_steady_state.png'),'Resolution',160);
close(fig);

fig = figure('Visible','off','Color','w');
tiledlayout(4,1,'TileSpacing','compact');
idx = t >= 0.095 & t <= 0.15; id = td >= 0.095 & td <= 0.15;
nexttile; plot(t(idx),v(idx)); xline(0.10,'--'); grid on; ylabel('Vout (V)');
nexttile; plot(t(idx),iload(idx)); xline(0.10,'--'); grid on; ylabel('Iload (A)');
nexttile; plot(t(idx),il(idx)); xline(0.10,'--'); grid on; ylabel('iL (A)');
nexttile; stairs(td(id),duty(id)); xline(0.10,'--'); grid on;
ylabel('Duty'); xlabel('Time (s)');
exportgraphics(fig,fullfile(resultsDir,'closed_loop_load_step.png'),'Resolution',160);
close(fig);

fig = figure('Visible','off','Color','w');
stairs(td,duty); xline(0.10,'--'); xline(0.15,'--'); grid on;
xlabel('Time (s)'); ylabel('Duty'); title('Duty response to load and line steps');
exportgraphics(fig,fullfile(resultsDir,'closed_loop_duty.png'),'Resolution',160);
close(fig);

fig = figure('Visible','off','Color','w');
plot(t,il); xline(0.10,'--'); xline(0.15,'--'); grid on;
xlabel('Time (s)'); ylabel('iL (A)'); title('Inductor current');
exportgraphics(fig,fullfile(resultsDir,'closed_loop_inductor_current.png'),'Resolution',160);
close(fig);

fig = figure('Visible','off','Color','w');
tiledlayout(5,1,'TileSpacing','compact');
nexttile; plot(t,vin); grid on; ylabel('Vin (V)');
nexttile; plot(t,vref,'--',t,v); grid on; ylabel('V (V)'); legend('Vref','Vout');
nexttile; plot(t,iload); grid on; ylabel('Iload (A)');
nexttile; plot(t,il); grid on; ylabel('iL (A)');
nexttile; stairs(td,duty); grid on; ylabel('Duty'); xlabel('Time (s)');
exportgraphics(fig,fullfile(resultsDir,'closed_loop_overview.png'),'Resolution',160);
close(fig);

disp(metrics);
