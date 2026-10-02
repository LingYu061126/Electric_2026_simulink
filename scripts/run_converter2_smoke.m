% Bonus pre-gate: 0.5 A RMS reference with fixed physical recovery topology.
projectDir=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectDir,'subsystems'));
mdl='energy_recovery_testbench_r2024a';
load_system(fullfile(projectDir,'models',[mdl '.slx']));
sdiDir=fullfile(getenv('HOME'),'.cache','matlab-sdi-converter1');
if ~isfolder(sdiDir), mkdir(sdiDir); end
Simulink.sdi.setStorageLocation(sdiDir);
si=Simulink.SimulationInput(mdl);
si=si.setVariable('Fout_Hz',50,'Workspace',mdl);
si=si.setVariable('LoadEnable',0,'Workspace',mdl);
si=si.setVariable('RegenCurrentRef_RMS_A',0.5,'Workspace',mdl);
si=si.setVariable('RegenEnable',1,'Workspace',mdl);
si=si.setModelParameter('StopTime','1.0');
si=si.setModelParameter('SignalLogging','off');
so=sim(si);
names={'acac_vdc','tp_id_source','acac_va','acac_vb','acac_vc', ...
    'tp_conv2_ia','tp_conv2_ib','tp_conv2_ic', ...
    'tp_conv2_dc_return_current','tp_vneutral_dcneg', ...
    'tp_v1a_dcneg','tp_v1b_dcneg','tp_v1c_dcneg', ...
    'tp_v2a_dcneg','tp_v2b_dcneg','tp_v2c_dcneg', ...
    'tp_lconn_va','tp_lconn_vb','tp_lconn_vc', ...
    'tp_c2_id','tp_c2_iq','tp_c2_id_ref', ...
    'tp_c2_gate_ah','tp_c2_gate_al','tp_c2_gate_bh','tp_c2_gate_bl', ...
    'tp_c2_gate_ch','tp_c2_gate_cl'};
sig=struct();
for k=1:numel(names)
    sig.(names{k})=so.get(names{k});
    assert(~isempty(sig.(names{k})),'Missing smoke test point: %s',names{k});
    assert(all(isfinite(double(sig.(names{k}).Data(:)))),'Nonfinite: %s',names{k});
end
t=(0.8:1/100e3:1.0-1/100e3)';
sample=@(s) interp1(s.Time(:),double(s.Data(:)),t);
v=zeros(numel(t),3); i=v;
for k=1:3
    v(:,k)=sample(sig.(names{2+k}));
    i(:,k)=sample(sig.(names{5+k}));
end
ud=sample(sig.acac_vdc);
ids=sample(sig.tp_id_source);
idret=sample(sig.tp_conv2_dc_return_current);
vn=sample(sig.tp_vneutral_dcneg);
v2=[sample(sig.tp_v2a_dcneg),sample(sig.tp_v2b_dcneg),sample(sig.tp_v2c_dcneg)];
% All physical sensors share one native solver time vector. Integrate power
% on that grid so switching-edge correlation is retained.
tn=sig.tp_conv2_ia.Time(:);
native=@(s) interp1(s.Time(:),double(s.Data(:)),tn);
ii=[native(sig.tp_conv2_ia),native(sig.tp_conv2_ib),native(sig.tp_conv2_ic)];
vv=[native(sig.acac_va),native(sig.acac_vb),native(sig.acac_vc)];
vnn=native(sig.tp_vneutral_dcneg);
v11=[native(sig.tp_v1a_dcneg),native(sig.tp_v1b_dcneg),native(sig.tp_v1c_dcneg)];
v22=[native(sig.tp_v2a_dcneg),native(sig.tp_v2b_dcneg),native(sig.tp_v2c_dcneg)];
vL=[native(sig.tp_lconn_va),native(sig.tp_lconn_vb),native(sig.tp_lconn_vc)];
udn=native(sig.acac_vdc); idsn=native(sig.tp_id_source);
iretn=native(sig.tp_conv2_dc_return_current);
mask=tn>=0.8 & tn<=1.0;
tm=tn(mask); duration=tm(end)-tm(1);
avg=@(x) trapz(tm,x(mask))/duration;
metrics=struct();
metrics.stage='Converter2 0.5 A current-loop smoke';
metrics.window_s=[0.8 1.0];
metrics.Iline_rms_A=sqrt(mean(i.^2,1));
metrics.v1_reconstruction_rms_error_V=sqrt(mean((v11(mask,:)-(vv(mask,:)+vnn(mask))).^2,1));
metrics.P_converter1_AC_export_W=avg(sum(v11.*ii,2));
metrics.P_converter2_AC_absorbed_W=avg(sum(v22.*ii,2));
metrics.P_connection_unit_loss_W=metrics.P_converter1_AC_export_W-metrics.P_converter2_AC_absorbed_W;
metrics.P_connection_direct_inductor_W=avg(sum(vL.*ii,2));
metrics.vconn_sensor_mismatch_rms_V=sqrt(mean((vL(mask,:)-(v11(mask,:)-v22(mask,:))).^2,1));
metrics.P_connection_winding_loss_W=avg(0.05*sum(ii.^2,2));
Econn=0.5*0.003*sum(ii.^2,2);
metrics.P_connection_energy_change_W=(Econn(find(mask,1,'last'))-Econn(find(mask,1)))/duration;
metrics.P_connection_balance_residual_W=metrics.P_connection_unit_loss_W ...
    -metrics.P_connection_winding_loss_W-metrics.P_connection_energy_change_W;
metrics.P_connection_direct_balance_residual_W=metrics.P_connection_direct_inductor_W ...
    -metrics.P_connection_winding_loss_W-metrics.P_connection_energy_change_W;
metrics.connection_balance_residual_percent_of_transfer= ...
    100*abs(metrics.P_connection_balance_residual_W)/metrics.P_converter1_AC_export_W;
metrics.P_returned_DC_W=avg(udn.*iretn);
metrics.P_source_W=avg(udn.*idsn);
metrics.P_converter2_modelled_loss_W=metrics.P_converter2_AC_absorbed_W-metrics.P_returned_DC_W;
metrics.dc_bus_mean_V=mean(ud);
metrics.id_measured_mean_peak_A=mean(sample(sig.tp_c2_id));
metrics.iq_measured_mean_peak_A=mean(sample(sig.tp_c2_iq));
metrics.id_reference_mean_peak_A=mean(sample(sig.tp_c2_id_ref));
gatePairs={{'tp_c2_gate_ah','tp_c2_gate_al'}, ...
           {'tp_c2_gate_bh','tp_c2_gate_bl'}, ...
           {'tp_c2_gate_ch','tp_c2_gate_cl'}};
metrics.gate_overlap_count=zeros(1,3);
for k=1:3
    a=double(sig.(gatePairs{k}{1}).Data(:));
    b=double(sig.(gatePairs{k}{2}).Data(:));
    metrics.gate_overlap_count(k)=nnz(a+b>1);
end
metrics.pass=all(metrics.Iline_rms_A>0.35 & metrics.Iline_rms_A<0.65) ...
    && metrics.P_converter1_AC_export_W>0 ...
    && metrics.P_converter2_AC_absorbed_W>0 ...
    && metrics.P_returned_DC_W>0 ...
    && metrics.P_source_W>=0 ...
    && metrics.P_converter1_AC_export_W>metrics.P_returned_DC_W ...
    && metrics.P_converter2_modelled_loss_W>=-0.1 ...
    && metrics.connection_balance_residual_percent_of_transfer<1.0 ...
    && all(metrics.gate_overlap_count==0) ...
    && abs(metrics.id_measured_mean_peak_A-metrics.id_reference_mean_peak_A)<0.25;
fid=fopen(fullfile(projectDir,'results','converter2_smoke_metrics.json'),'w');
assert(fid>=0);fwrite(fid,jsonencode(metrics,'PrettyPrint',true),'char');fclose(fid);
fprintf('CONV2_SMOKE I=[%.3f %.3f %.3f] P1=%.3f P2=%.3f Preturn=%.3f Psource=%.3f residual=%.4f directResidual=%.4f id=%.3f idref=%.3f iq=%.3f pass=%d\n', ...
    metrics.Iline_rms_A,metrics.P_converter1_AC_export_W,metrics.P_converter2_AC_absorbed_W, ...
    metrics.P_returned_DC_W,metrics.P_source_W,metrics.P_connection_balance_residual_W, ...
    metrics.P_connection_direct_balance_residual_W, ...
    metrics.id_measured_mean_peak_A,metrics.id_reference_mean_peak_A, ...
    metrics.iq_measured_mean_peak_A,metrics.pass);
