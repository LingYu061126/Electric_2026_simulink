% Additional engineering feature test: over-reference current limiter.
projectDir=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectDir,'subsystems'));
mdl='energy_recovery_testbench_r2024a';
load_system(fullfile(projectDir,'models',[mdl '.slx']));
sdiDir=fullfile(getenv('HOME'),'.cache','matlab-sdi-converter1');
if ~isfolder(sdiDir),mkdir(sdiDir);end
Simulink.sdi.setStorageLocation(sdiDir);
si=Simulink.SimulationInput(mdl);
si=si.setVariable('Fout_Hz',50,'Workspace',mdl);
si=si.setVariable('LoadEnable',0,'Workspace',mdl);
si=si.setVariable('RegenCurrentRef_RMS_A',3.0,'Workspace',mdl);
si=si.setVariable('RegenEnable',1,'Workspace',mdl);
si=si.setModelParameter('StopTime','0.65');
si=si.setModelParameter('SignalLogging','off');
so=sim(si);
names={'tp_c2_current_limited','tp_c2_id_ref','tp_c2_id','acac_vdc', ...
    'tp_conv2_ia','tp_conv2_ib','tp_conv2_ic', ...
    'tp_c2_gate_ah','tp_c2_gate_al','tp_c2_gate_bh','tp_c2_gate_bl', ...
    'tp_c2_gate_ch','tp_c2_gate_cl'};
sig=struct();
for k=1:numel(names)
    sig.(names{k})=so.get(names{k});
    assert(~isempty(sig.(names{k})),'Missing protection TP: %s',names{k});
    assert(all(isfinite(double(sig.(names{k}).Data(:)))),'Nonfinite: %s',names{k});
end
t=(0.5:1/100e3:0.65-1/100e3)';
sample=@(s) interp1(s.Time(:),double(s.Data(:)),t);
limit=sample(sig.tp_c2_current_limited);
idref=sample(sig.tp_c2_id_ref);
id=sample(sig.tp_c2_id);
ud=sample(sig.acac_vdc);
i=[sample(sig.tp_conv2_ia),sample(sig.tp_conv2_ib),sample(sig.tp_conv2_ic)];
gatePairs={{'tp_c2_gate_ah','tp_c2_gate_al'}, ...
    {'tp_c2_gate_bh','tp_c2_gate_bl'}, {'tp_c2_gate_ch','tp_c2_gate_cl'}};
overlap=zeros(1,3);
for k=1:3
    a=double(sig.(gatePairs{k}{1}).Data(:));
    b=double(sig.(gatePairs{k}{2}).Data(:));
    overlap(k)=nnz(a+b>1);
end
metrics=struct();
metrics.feature='Additional Engineering Feature: Protection + Test Dashboard';
metrics.test='3.0 A RMS commanded current exceeds 2.2 A RMS safe limiter';
metrics.current_limit_rms_A=2.2;
metrics.commanded_current_rms_A=3.0;
metrics.window_s=[0.5 0.65];
metrics.limiter_active_fraction=mean(limit>0.5);
metrics.id_reference_peak_max_A=max(idref);
metrics.id_measured_peak_mean_A=mean(id);
metrics.iline_rms_A=sqrt(mean(i.^2,1));
metrics.vdc_min_V=min(ud);metrics.vdc_max_V=max(ud);
metrics.gate_overlap_count=overlap;
metrics.pass=metrics.limiter_active_fraction>0.99 ...
    && metrics.id_reference_peak_max_A<=sqrt(2)*2.2+1e-6 ...
    && all(isfinite(metrics.iline_rms_A)) ...
    && metrics.vdc_min_V>=50 && metrics.vdc_max_V<=70 ...
    && all(overlap==0);
fid=fopen(fullfile(projectDir,'results','bonus3_protection_test.json'),'w');
assert(fid>=0);fwrite(fid,jsonencode(metrics,'PrettyPrint',true),'char');fclose(fid);
fprintf('BONUS3 limiter=%.3f refPeak=%.3f I=[%.3f %.3f %.3f] Vdc=[%.3f %.3f] pass=%d\n', ...
    metrics.limiter_active_fraction,metrics.id_reference_peak_max_A, ...
    metrics.iline_rms_A,metrics.vdc_min_V,metrics.vdc_max_V,metrics.pass);
