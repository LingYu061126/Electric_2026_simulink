% Run and measure the physical R2024a Buck converter.
root = fileparts(fileparts(mfilename('fullpath')));
modelFile = fullfile(root, 'models', 'buck_r2024a.slx');
resultsDir = fullfile(root, 'results');
if ~isfolder(resultsDir)
    mkdir(resultsDir);
end
open_system(modelFile);
set_param('buck_r2024a', 'SimulationCommand', 'update');
out = sim('buck_r2024a');
metrics = struct();

Vin = out.get('Vin_ts');
Vout = out.get('Vout_ts');
iL = out.get('iL_ts');
Iload = out.get('Iload_ts');
PWM = out.get('PWM_ts');
signals = {Vin, Vout, iL, Iload, PWM};
for k = 1:numel(signals)
    assert(~isempty(signals{k}.Time), 'A measurement has no time samples.');
    assert(all(isfinite(signals{k}.Time)) && all(isfinite(signals{k}.Data(:))), ...
        'A measurement contains NaN or Inf.');
end

t = Vout.Time;
steady = t >= 0.08 & t <= 0.1;
assert(nnz(steady) >= 100, 'Insufficient steady-state samples.');
v = squeeze(Vout.Data);
vin = squeeze(Vin.Data);
i = squeeze(iL.Data);
iload = squeeze(Iload.Data);
pwm = squeeze(PWM.Data);
assert(numel(v) == numel(vin) && numel(v) == numel(i) && ...
    numel(v) == numel(iload) && numel(v) == numel(pwm), ...
    'Logged signals do not have matching sample counts.');

metrics.Vin = mean(vin(steady));
metrics.duty = 0.5;
metrics.switching_frequency = 1e4;
metrics.Vout_mean = mean(v(steady));
metrics.Vout_pp = max(v(steady)) - min(v(steady));
metrics.iL_mean = mean(i(steady));
metrics.iL_pp = max(i(steady)) - min(i(steady));
metrics.iL_min = min(i(steady));
metrics.Iload_mean = mean(iload(steady));
metrics.Vout_theory = metrics.duty * metrics.Vin;
metrics.Vout_error_percent = abs(metrics.Vout_mean - metrics.Vout_theory) ...
    / metrics.Vout_theory * 100;
metrics.iL_pp_theory = (metrics.Vin - metrics.Vout_mean) ...
    * metrics.duty / (1e-3 * metrics.switching_frequency);
metrics.iL_pp_error_percent = abs(metrics.iL_pp - metrics.iL_pp_theory) ...
    / metrics.iL_pp_theory * 100;
metrics.duty_measured = trapz(t(steady), double(pwm(steady) > 5)) ...
    / (t(find(steady, 1, 'last')) - t(find(steady, 1, 'first')));
riseTimes = t(find(diff(pwm > 5) == 1) + 1);
riseTimes = riseTimes(riseTimes >= 0.08 & riseTimes <= 0.1);
assert(numel(riseTimes) >= 100, 'Insufficient PWM periods measured.');
metrics.switching_frequency_measured = 1 / median(diff(riseTimes));
if metrics.iL_min > 0
    metrics.conduction_mode = 'CCM';
else
    metrics.conduction_mode = 'DCM / boundary conduction';
end
metrics.compiled = true;
metrics.simulated = true;
metrics.measured = true;
metrics.no_nan_or_inf = true;
metrics.validated = metrics.Vout_mean > 8 && metrics.Vout_mean < 16 ...
    && metrics.iL_min > 0 && abs(metrics.duty_measured - 0.5) < 0.01 ...
    && abs(metrics.switching_frequency_measured - 1e4) < 1;
assert(metrics.validated, 'Buck validation criteria failed.');

save(fullfile(resultsDir, 'buck_results.mat'), 'out', 'Vin', 'Vout', ...
    'iL', 'Iload', 'PWM', 'metrics', '-v7.3');
fid = fopen(fullfile(resultsDir, 'buck_metrics.json'), 'w');
assert(fid > 0, 'Unable to create metrics JSON.');
fprintf(fid, '%s\n', jsonencode(metrics, 'PrettyPrint', true));
fclose(fid);

f = figure('Visible', 'off', 'Color', 'w');
plot(t, v, 'LineWidth', 1.1); grid on;
xlabel('Time (s)'); ylabel('Vout (V)'); title('Buck output voltage: startup to steady state');
exportgraphics(f, fullfile(resultsDir, 'buck_vout.png'), 'Resolution', 160);
close(f);

f = figure('Visible', 'off', 'Color', 'w');
idx = t >= 0.098 & t <= 0.1;
plot(t(idx), i(idx), 'LineWidth', 1.1); grid on;
xlabel('Time (s)'); ylabel('Inductor current (A)'); title('Steady-state inductor current');
exportgraphics(f, fullfile(resultsDir, 'buck_inductor_current.png'), 'Resolution', 160);
close(f);

f = figure('Visible', 'off', 'Color', 'w');
idx = t >= 0.0995 & t <= 0.1;
stairs(t(idx), pwm(idx), 'LineWidth', 1.1); grid on;
xlabel('Time (s)'); ylabel('PWM gate voltage (V)'); title('Five PWM switching periods');
exportgraphics(f, fullfile(resultsDir, 'buck_pwm.png'), 'Resolution', 160);
close(f);

f = figure('Visible', 'off', 'Color', 'w');
tiledlayout(4, 1, 'TileSpacing', 'compact');
nexttile; plot(t, vin); grid on; ylabel('Vin (V)');
nexttile; plot(t, v); grid on; ylabel('Vout (V)');
nexttile; plot(t, i); grid on; ylabel('iL (A)');
nexttile; stairs(t, pwm); grid on; ylabel('PWM (V)'); xlabel('Time (s)');
exportgraphics(f, fullfile(resultsDir, 'buck_overview.png'), 'Resolution', 160);
close(f);

disp(metrics);
