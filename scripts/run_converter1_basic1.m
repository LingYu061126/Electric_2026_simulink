% Basic-1: independent physical 60 V DC -> VSI -> LC -> floating Y load.
projectDir = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectDir,'subsystems'));
mdl = 'converter1_basic_test_r2024a';
load_system(fullfile(projectDir,'models',[mdl '.slx']));
mw = get_param(mdl,'ModelWorkspace');
assignin(mw,'Fout_Hz',50);
si = Simulink.SimulationInput(mdl);
si = si.setModelParameter('StopTime','1.0');
so = sim(si);

names = {'acac_uab','acac_ubc','acac_uca','acac_ia','acac_ib','acac_ic', ...
    'acac_va','acac_vb','acac_vc','acac_vdc','tp_id_source', ...
    'acac_qah','acac_qal','acac_qbh','acac_qbl','acac_qch','acac_qcl'};
sig = struct();
for k = 1:numel(names)
    sig.(names{k}) = so.get(names{k});
    assert(~isempty(sig.(names{k})),'Missing test point: %s',names{k});
    assert(all(isfinite(double(sig.(names{k}).Data(:)))),'Nonfinite: %s',names{k});
end
t0 = 0.8; t1 = 1.0; fs = 200e3;
t = (t0:1/fs:t1-1/fs)';
u = zeros(numel(t),3); i = u; v = u;
uNames = {'acac_uab','acac_ubc','acac_uca'};
iNames = {'acac_ia','acac_ib','acac_ic'};
vNames = {'acac_va','acac_vb','acac_vc'};
for k = 1:3
    u(:,k) = interp1(sig.(uNames{k}).Time(:),double(sig.(uNames{k}).Data(:)),t);
    i(:,k) = interp1(sig.(iNames{k}).Time(:),double(sig.(iNames{k}).Data(:)),t);
    v(:,k) = interp1(sig.(vNames{k}).Time(:),double(sig.(vNames{k}).Data(:)),t);
end
vdc = interp1(sig.acac_vdc.Time(:),double(sig.acac_vdc.Data(:)),t);
idSource = interp1(sig.tp_id_source.Time(:),double(sig.tp_id_source.Data(:)),t);
N = numel(t); fundamentalBin = round(50*(t1-t0));
phasor = @(x) (2/N)*sum(x.*exp(-1i*2*pi*50*t),1);
up = phasor(u); ip = phasor(i); vp = phasor(v);
phaseStep = mod(diff([angle(vp) angle(vp(1))])*180/pi+180,360)-180;
freq = zeros(1,3);
for k = 1:3
    y = movmean(u(:,k),round(fs/1000));
    crossings = find(y(1:end-1)<=0 & y(2:end)>0);
    zt = t(crossings)-y(crossings).*(t(crossings+1)-t(crossings))./(y(crossings+1)-y(crossings));
    assert(numel(zt)>=5,'Too few zero crossings on phase %d',k);
    freq(k) = 1/mean(diff(zt));
end
metrics = struct();
metrics.stage = 'Basic-1';
metrics.model = mdl;
metrics.dc_source_voltage_design_choice_V = 60;
metrics.required_spwm_modulation_index_ideal = 2*sqrt(2)*(32/sqrt(3))/60;
metrics.rated_phase_resistance_ohm = (32/sqrt(3))/2;
metrics.steady_window_s = [t0 t1];
metrics.Uline_rms_V = sqrt(mean(u.^2,1));
metrics.Iline_rms_A = sqrt(mean(i.^2,1));
metrics.frequency_measured_Hz = freq;
metrics.phase_voltage_fundamental_angle_deg = mod(angle(vp)*180/pi,360);
metrics.phase_step_deg = phaseStep;
metrics.line_voltage_dc_offset_V = mean(u,1);
metrics.source_voltage_mean_V = mean(vdc);
metrics.source_current_mean_A = mean(idSource);
metrics.source_power_mean_W = mean(vdc.*idSource);
metrics.ac_output_power_mean_W = mean(sum(v.*i,2));
metrics.sine_residual_percent = zeros(1,3);
for k = 1:3
    fit = real(up(k)*exp(1i*2*pi*50*t));
    metrics.sine_residual_percent(k) = 100*sqrt(mean((u(:,k)-fit-mean(u(:,k))).^2))/sqrt(mean(fit.^2));
end
metrics.gate_overlap_count = [ ...
    nnz(double(sig.acac_qah.Data(:))+double(sig.acac_qal.Data(:))>1), ...
    nnz(double(sig.acac_qbh.Data(:))+double(sig.acac_qbl.Data(:))>1), ...
    nnz(double(sig.acac_qch.Data(:))+double(sig.acac_qcl.Data(:))>1)];
metrics.pass = all(abs(metrics.Uline_rms_V-32)<=0.25) ...
    && all(abs(metrics.Iline_rms_A-2)<=0.1) ...
    && all(abs(metrics.frequency_measured_Hz-50)<=0.2) ...
    && all(abs(abs(metrics.phase_step_deg)-120)<=3) ...
    && all(abs(metrics.line_voltage_dc_offset_V)<=0.1) ...
    && all(metrics.sine_residual_percent<2) ...
    && all(metrics.gate_overlap_count==0);
resultsDir = fullfile(projectDir,'results');
save(fullfile(resultsDir,'converter1_basic_results.mat'),'so','metrics','-v7.3');
fid = fopen(fullfile(resultsDir,'basic_req1_metrics.json'),'w');
assert(fid>=0); fwrite(fid,jsonencode(metrics,'PrettyPrint',true),'char'); fclose(fid);
fig = figure('Visible','off'); plot(t,u); grid on; xlabel('Time (s)'); ylabel('Line voltage (V)');
legend('Uab','Ubc','Uca'); title('Basic-1: three-phase line voltage');
exportgraphics(fig,fullfile(resultsDir,'basic1_three_phase_voltage.png')); close(fig);
fig = figure('Visible','off'); plot(t,i); grid on; xlabel('Time (s)'); ylabel('Line current (A)');
legend('Ia','Ib','Ic'); title('Basic-1: three-phase line current');
exportgraphics(fig,fullfile(resultsDir,'basic1_three_phase_current.png')); close(fig);
fprintf('BASIC1 U=[%.4f %.4f %.4f] I=[%.4f %.4f %.4f] F=[%.4f %.4f %.4f] phase=[%.2f %.2f %.2f] pass=%d\n', ...
    metrics.Uline_rms_V,metrics.Iline_rms_A,metrics.frequency_measured_Hz,metrics.phase_step_deg,metrics.pass);
