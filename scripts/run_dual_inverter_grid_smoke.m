%% Grid-current smoke run: switching model, independent SOGI-PLLs and PR loops
projectRoot = fileparts(fileparts(mfilename('fullpath')));
modelName = 'dual_single_phase_parallel_inverter_r2024a';
resultsDir = fullfile(projectRoot,'results');
if ~exist(resultsDir,'dir')
    mkdir(resultsDir);
end
assert(bdIsLoaded(modelName),'Open the dual-inverter model before this run.');

in = Simulink.SimulationInput(modelName);
blockPath = @(sid) Simulink.ID.getFullName([modelName ':' sid]);
in = in.setBlockParameter(blockPath('254'),'Value','1'); % inverter 1 enabled
in = in.setBlockParameter(blockPath('259'),'Value','1'); % inverter 2 enabled
in = in.setBlockParameter(blockPath('270'),'Value','0'); % S1 open
in = in.setBlockParameter(blockPath('271'),'Value','0'); % load disconnected
in = in.setBlockParameter(blockPath('272'),'Value','1'); % S2 closed
in = in.setBlockParameter(blockPath('269'),'r','12');
in = in.setBlockParameter(blockPath('424'),'Value','1'); % grid-current mode
in = in.setBlockParameter(blockPath('425'),'Value','2'); % total RMS reference
in = in.setBlockParameter(blockPath('426'),'Value','1'); % equal current allocation
in = in.setModelParameter('StopTime','0.45');

logBlocks = find_system(modelName,'BlockType','ToWorkspace');
for k = 1:numel(logBlocks)
    variableName = get_param(logBlocks{k},'VariableName');
    if startsWith(variableName,{'Inv1_gate','Inv2_gate'})
        decimation = '1';
    else
        decimation = '4';
    end
    in = in.setBlockParameter(logBlocks{k},'Decimation',decimation);
end

fprintf(['Running switching grid smoke test: S1 open, S2 closed, ' ...
    'both independent current loops enabled, Io_total_ref=2 A...\n']);
out = sim(in);

names = {'TP_grid_voltage_LV','TP_Io','TP_Io1','TP_Io2', ...
    'PLL1_frequency_Hz','PLL2_frequency_Hz','PLL1_lock','PLL2_lock', ...
    'PLL1_phase_error','PLL2_phase_error','Protect1_GatePermit', ...
    'Protect2_GatePermit','Protect1_Vdc_OK','Protect2_Vdc_OK', ...
    'Protect1_OC_Trip','Protect2_OC_Trip'};
signals = cell(size(names));
for k = 1:numel(names)
    signals{k} = out.get(names{k});
end
tEnd = min(cellfun(@(s)double(s.Time(end)),signals));
window = [max(0.25,tEnd-0.10),tEnd];
assert(window(2)-window(1)>=0.08,'Grid smoke run did not cover four steady-state cycles.');
t = (window(1):1e-5:window(2))';
x = cell(size(signals));
for k = 1:numel(signals)
    tk = double(signals{k}.Time(:));
    xk = double(squeeze(signals{k}.Data));
    x{k} = interp1(tk,xk(:),t,'linear');
end
assert(all(isfinite(vertcat(x{:}))), 'Grid smoke logs contain NaN or Inf.');

uGrid = x{1};
iTotal = x{2};
i1 = x{3};
i2 = x{4};
f1 = x{5};
f2 = x{6};
lock1 = x{7};
lock2 = x{8};
phase1 = x{9};
phase2 = x{10};
permit1 = x{11};
permit2 = x{12};
vdcOk1 = x{13};
vdcOk2 = x{14};
trip1 = x{15};
trip2 = x{16};
iref1 = double(out.get('Protect1_Iref_Limited').Data(:));
iref2 = double(out.get('Protect2_Iref_Limited').Data(:));
metrics = struct();
metrics.mode = 'grid_current';
metrics.S1_closed = false;
metrics.S2_closed = true;
metrics.inverter1_enabled = true;
metrics.inverter2_enabled = true;
metrics.Io_total_set_A = 2;
metrics.measurement_window_s = window;
metrics.grid_primary_voltage_rms_V = sqrt(mean(uGrid.^2));
metrics.Io_total_rms_A = sqrt(mean(iTotal.^2));
metrics.Io1_rms_A = sqrt(mean(i1.^2));
metrics.Io2_rms_A = sqrt(mean(i2.^2));
metrics.PLL1_frequency_mean_Hz = mean(f1);
metrics.PLL2_frequency_mean_Hz = mean(f2);
metrics.PLL1_lock_fraction = mean(lock1>0.5);
metrics.PLL2_lock_fraction = mean(lock2>0.5);
metrics.PLL1_phase_error_rms_pu = sqrt(mean(phase1.^2));
metrics.PLL2_phase_error_rms_pu = sqrt(mean(phase2.^2));
metrics.current_error_percent = abs(metrics.Io_total_rms_A-2)/2*100;
metrics.all_signals_finite = all(isfinite(vertcat(x{:})));
metrics.both_plls_locked = metrics.PLL1_lock_fraction>0.99 && ...
    metrics.PLL2_lock_fraction>0.99;
metrics.protection_vdc_ok_both = all(vdcOk1>0.5) && all(vdcOk2>0.5);
metrics.protection_permitted_both = all(permit1>0.5) && all(permit2>0.5);
metrics.protection_no_overcurrent_trip = ~any(trip1>0.5) && ~any(trip2>0.5);
metrics.protection_current_reference_bounded = ...
    max([iref1;iref2])<=2+eps && min([iref1;iref2])>=0-eps;
metrics.currents_bounded = max(abs([iTotal;i1;i2])) < 10;
metrics.current_tracking_pass = metrics.current_error_percent<6;
metrics.pass = metrics.both_plls_locked && metrics.currents_bounded && ...
    metrics.protection_vdc_ok_both && metrics.protection_permitted_both && ...
    metrics.protection_no_overcurrent_trip && ...
    metrics.protection_current_reference_bounded && ...
    metrics.all_signals_finite && metrics.current_tracking_pass && ...
    metrics.grid_primary_voltage_rms_V>20 && ...
    metrics.grid_primary_voltage_rms_V<28;

fprintf(['GRID_SMOKE voltage=%.4f Vrms, Io=%.5f Arms, Io1=%.5f A, ' ...
    'Io2=%.5f A, PLL lock fractions=%.3f/%.3f, PASS=%d\n'], ...
    metrics.grid_primary_voltage_rms_V,metrics.Io_total_rms_A, ...
    metrics.Io1_rms_A,metrics.Io2_rms_A,metrics.PLL1_lock_fraction, ...
    metrics.PLL2_lock_fraction,metrics.pass);
save(fullfile(resultsDir,'dual_inverter_grid_smoke.mat'), ...
    'out','metrics','t','uGrid','iTotal','i1','i2');
fid = fopen(fullfile(resultsDir,'dual_inverter_grid_smoke.json'),'w');
assert(fid>=0,'Could not create grid smoke JSON.');
fwrite(fid,jsonencode(metrics,'PrettyPrint',true),'char');
fclose(fid);
assert(metrics.pass,'Grid smoke test failed; do not start Bonus-2 sweep yet.');
