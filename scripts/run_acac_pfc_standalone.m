% Isolated PFC operating test: inverter gates disabled, 30.5 ohm DC load.
projectDir = fileparts(fileparts(mfilename('fullpath')));
mdl = 'acac_pfc_standalone_r2024a';
load_system(fullfile(projectDir,'models',[mdl '.slx']));
si = Simulink.SimulationInput(mdl);
si = si.setModelParameter('StopTime','1.00');
so = sim(si);
names = {'acac_vin','acac_iin','acac_vdc','acac_pfc_duty', ...
    'acac_qah','acac_qal','acac_qbh','acac_qbl','acac_qch','acac_qcl'};
sig = struct();
for k = 1:numel(names)
    sig.(names{k}) = so.get(names{k});
    assert(all(isfinite(double(sig.(names{k}).Data(:)))),'Nonfinite signal: %s',names{k});
end
fs = 200e3;
t = (0.8:1/fs:1-1/fs)';
vin = interp1(sig.acac_vin.Time(:),double(sig.acac_vin.Data(:)),t);
iin = interp1(sig.acac_iin.Time(:),double(sig.acac_iin.Data(:)),t);
vdc = interp1(sig.acac_vdc.Time(:),double(sig.acac_vdc.Data(:)),t);
idc_load = vdc/30.5; % Physical resistor law for the equivalent DC load.
metrics = struct();
metrics.stage = 'PFC with 30.5 ohm equivalent DC load; inverter gate commands disabled';
metrics.stop_time_s = so.tout(end);
metrics.steady_window_s = [0.8 1.0];
metrics.equivalent_load_ohm = 30.5;
metrics.input_voltage_rms_V = sqrt(mean(vin.^2));
metrics.input_current_rms_A = sqrt(mean(iin.^2));
metrics.input_real_power_W = mean(vin.*iin);
metrics.input_power_factor = metrics.input_real_power_W/(metrics.input_voltage_rms_V*metrics.input_current_rms_A);
Yv = fft(vin-mean(vin)); Yi = fft(iin-mean(iin));
k0 = round(50*(t(end)-t(1)+1/fs));
metrics.input_displacement_factor = cos(angle(Yv(k0+1))-angle(Yi(k0+1)));
metrics.input_current_thd_percent = 100*sqrt(sum(abs(Yi((2:50)*k0+1)).^2))/abs(Yi(k0+1));
metrics.dc_bus_mean_V = mean(vdc);
metrics.dc_bus_pp_ripple_V = max(vdc)-min(vdc);
metrics.dc_bus_error_percent = 100*abs(metrics.dc_bus_mean_V-60)/60;
metrics.dc_load_power_W = mean(vdc.^2)/30.5;
metrics.dc_load_current_mean_A = mean(idc_load);
metrics.pfc_duty_mean = mean(double(sig.acac_pfc_duty.Data(:)));
metrics.max_inverter_gate_command = max([max(double(sig.acac_qah.Data(:))), ...
    max(double(sig.acac_qal.Data(:))),max(double(sig.acac_qbh.Data(:))), ...
    max(double(sig.acac_qbl.Data(:))),max(double(sig.acac_qch.Data(:))), ...
    max(double(sig.acac_qcl.Data(:)))]);
metrics.pass = metrics.dc_bus_error_percent < 1 && metrics.input_power_factor >= 0.99 ...
    && metrics.max_inverter_gate_command == 0 && metrics.input_real_power_W > metrics.dc_load_power_W;
fprintf('PFC_STAGE Vdc=%.3f V ripple=%.3f V regulation=%.3f%% PF=%.5f Pin=%.3f W Pload=%.3f W pass=%d\n', ...
    metrics.dc_bus_mean_V,metrics.dc_bus_pp_ripple_V,metrics.dc_bus_error_percent, ...
    metrics.input_power_factor,metrics.input_real_power_W,metrics.dc_load_power_W,metrics.pass);
resultsDir = fullfile(projectDir,'results');
save(fullfile(resultsDir,'acac_pfc_standalone_results.mat'),'so','metrics','t','idc_load','-v7.3');
fid = fopen(fullfile(resultsDir,'acac_pfc_standalone_metrics.json'),'w');
assert(fid >= 0);
fwrite(fid,jsonencode(metrics,'PrettyPrint',true),'char');
fclose(fid);
