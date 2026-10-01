% Fixed 60 V DC source -> six-switch VSI -> LC filter -> balanced Y load.
projectDir = fileparts(fileparts(mfilename('fullpath')));
mdl = 'acac_inverter_fixed_dc_r2024a';
load_system(fullfile(projectDir,'models',[mdl '.slx']));
si = Simulink.SimulationInput(mdl);
si = si.setModelParameter('StopTime','1.00');
so = sim(si);
names = {'acac_vdc','acac_uab','acac_ubc','acac_uca', ...
    'acac_ia','acac_ib','acac_ic','acac_qah','acac_qal', ...
    'acac_qbh','acac_qbl','acac_qch','acac_qcl'};
sig = struct();
for k = 1:numel(names)
    sig.(names{k}) = so.get(names{k});
    assert(all(isfinite(double(sig.(names{k}).Data(:)))),'Nonfinite signal: %s',names{k});
end
t0 = 0.8; t1 = 1.0; fs = 200e3;
t = (t0:1/fs:t1-1/fs)';
u = zeros(numel(t),3); i = u;
uNames = {'acac_uab','acac_ubc','acac_uca'};
iNames = {'acac_ia','acac_ib','acac_ic'};
for k = 1:3
    u(:,k) = interp1(sig.(uNames{k}).Time(:),double(sig.(uNames{k}).Data(:)),t);
    i(:,k) = interp1(sig.(iNames{k}).Time(:),double(sig.(iNames{k}).Data(:)),t);
end
vdc = interp1(sig.acac_vdc.Time(:),double(sig.acac_vdc.Data(:)),t);
metrics = struct();
metrics.stage = 'Fixed 60 V physical DC source, six-switch VSI, LC filter, floating Y load';
metrics.stop_time_s = so.tout(end);
metrics.steady_window_s = [t0 t1];
metrics.dc_bus_mean_V = mean(vdc);
metrics.line_voltage_rms_V = sqrt(mean(u.^2,1));
metrics.phase_current_rms_A = sqrt(mean(i.^2,1));
N = numel(t); k0 = round(60*(t1-t0));
metrics.line_voltage_thd_percent = zeros(1,3);
metrics.line_voltage_broadband_thd_percent = zeros(1,3);
for k = 1:3
    y = fft(u(:,k)-mean(u(:,k)));
    metrics.line_voltage_thd_percent(k) = 100*sqrt(sum(abs(y((2:50)*k0+1)).^2))/abs(y(k0+1));
    e1 = 2*abs(y(k0+1))^2;
    et = 2*sum(abs(y(2:floor(N/2)+1)).^2);
    metrics.line_voltage_broadband_thd_percent(k) = 100*sqrt(max(0,et-e1)/e1);
end
ix = find(u(1:end-1,1)<=0 & u(2:end,1)>0);
tz = t(ix)-u(ix,1).*(t(ix+1)-t(ix))./(u(ix+1,1)-u(ix,1));
metrics.output_frequency_Hz = 1/mean(diff(tz));
metrics.shootthrough_A = nnz(double(sig.acac_qah.Data(:))+double(sig.acac_qal.Data(:))>1);
metrics.shootthrough_B = nnz(double(sig.acac_qbh.Data(:))+double(sig.acac_qbl.Data(:))>1);
metrics.shootthrough_C = nnz(double(sig.acac_qch.Data(:))+double(sig.acac_qcl.Data(:))>1);
metrics.pass = all(abs(metrics.line_voltage_rms_V-32)<=0.1) ...
    && metrics.output_frequency_Hz>=59.8 && metrics.output_frequency_Hz<=60.2 ...
    && all(metrics.phase_current_rms_A>=1.9 & metrics.phase_current_rms_A<=2.1) ...
    && all(metrics.line_voltage_thd_percent<=2) && all(metrics.line_voltage_broadband_thd_percent<=2) ...
    && metrics.shootthrough_A==0 && metrics.shootthrough_B==0 && metrics.shootthrough_C==0;
fprintf('FIXED_DC_STAGE Vdc=%.3f V U=[%.3f %.3f %.3f] V I=[%.3f %.3f %.3f] A f=%.4f Hz THD=[%.3f %.3f %.3f]%% pass=%d\n', ...
    metrics.dc_bus_mean_V,metrics.line_voltage_rms_V,metrics.phase_current_rms_A, ...
    metrics.output_frequency_Hz,metrics.line_voltage_thd_percent,metrics.pass);
resultsDir = fullfile(projectDir,'results');
save(fullfile(resultsDir,'acac_inverter_fixed_dc_results.mat'),'so','metrics','-v7.3');
fid = fopen(fullfile(resultsDir,'acac_inverter_fixed_dc_metrics.json'),'w');
assert(fid>=0);
fwrite(fid,jsonencode(metrics,'PrettyPrint',true),'char');
fclose(fid);
