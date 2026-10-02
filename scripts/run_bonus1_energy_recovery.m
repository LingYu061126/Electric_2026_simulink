% Bonus-1: fixed-topology energy feedback at 1.2 A RMS command.
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
si=si.setVariable('RegenCurrentRef_RMS_A',1.2,'Workspace',mdl);
si=si.setVariable('RegenEnable',1,'Workspace',mdl);
si=si.setModelParameter('StopTime','1.0');
si=si.setModelParameter('SignalLogging','off');
so=sim(si);
required={'tp_conv2_ia','tp_conv2_ib','tp_conv2_ic', ...
    'tp_v1a_dcneg','tp_v1b_dcneg','tp_v1c_dcneg', ...
    'tp_v2a_dcneg','tp_v2b_dcneg','tp_v2c_dcneg', ...
    'tp_id_source','tp_conv2_dc_return_current','acac_vdc', ...
    'acac_uab','acac_ubc','acac_uca', ...
    'tp_c2_gate_ah','tp_c2_gate_al','tp_c2_gate_bh','tp_c2_gate_bl', ...
    'tp_c2_gate_ch','tp_c2_gate_cl', ...
    'acac_qah','acac_qal','acac_qbh','acac_qbl','acac_qch','acac_qcl'};
sig=struct();
for k=1:numel(required)
    sig.(required{k})=so.get(required{k});
    assert(~isempty(sig.(required{k})),'Missing Bonus-1 TP: %s',required{k});
    assert(all(isfinite(double(sig.(required{k}).Data(:)))),'Nonfinite TP: %s',required{k});
end
tn=sig.tp_conv2_ia.Time(:); mask=tn>=0.8&tn<=1.0;
tm=tn(mask);duration=tm(end)-tm(1);
native=@(s) interp1(s.Time(:),double(s.Data(:)),tn);
avg=@(x) trapz(tm,x(mask))/duration;
i=[native(sig.tp_conv2_ia),native(sig.tp_conv2_ib),native(sig.tp_conv2_ic)];
v1=[native(sig.tp_v1a_dcneg),native(sig.tp_v1b_dcneg),native(sig.tp_v1c_dcneg)];
v2=[native(sig.tp_v2a_dcneg),native(sig.tp_v2b_dcneg),native(sig.tp_v2c_dcneg)];
ud=native(sig.acac_vdc); ids=native(sig.tp_id_source);
idret=native(sig.tp_conv2_dc_return_current);
P1=avg(sum(v1.*i,2)); P2=avg(sum(v2.*i,2));
Preturn=avg(ud.*idret); Psource=avg(ud.*ids);
Rloss=avg(0.05*sum(i.^2,2));
E=0.5*0.003*sum(i.^2,2);
dE=(E(find(mask,1,'last'))-E(find(mask,1)))/duration;
residual=(P1-P2)-Rloss-dE;

fs=100e3;t=(0.8:1/fs:1.0-1/fs)';
sample=@(s) interp1(s.Time(:),double(s.Data(:)),t);
u=[sample(sig.acac_uab),sample(sig.acac_ubc),sample(sig.acac_uca)];
iu=[sample(sig.tp_conv2_ia),sample(sig.tp_conv2_ib),sample(sig.tp_conv2_ic)];
freq=zeros(1,3);
for k=1:3
    yf=movmean(u(:,k),round(fs/1000));
    ix=find(yf(1:end-1)<=0&yf(2:end)>0);
    z=t(ix)-yf(ix).*(t(ix+1)-t(ix))./(yf(ix+1)-yf(ix));
    assert(numel(z)>=5,'Unstable line frequency');
    freq(k)=1/mean(diff(z));
end
gatePairs={{'tp_c2_gate_ah','tp_c2_gate_al'}, ...
    {'tp_c2_gate_bh','tp_c2_gate_bl'}, {'tp_c2_gate_ch','tp_c2_gate_cl'}, ...
    {'acac_qah','acac_qal'}, {'acac_qbh','acac_qbl'}, {'acac_qch','acac_qcl'}};
overlap=zeros(1,6);
for k=1:6
    a=double(sig.(gatePairs{k}{1}).Data(:));
    b=double(sig.(gatePairs{k}{2}).Data(:));
    overlap(k)=nnz(a+b>1);
end
metrics=struct();
metrics.stage='Bonus-1';metrics.model=mdl;metrics.window_s=[0.8 1.0];
metrics.regen_reference_rms_A=1.2;
metrics.Converter1_output_Iline_rms_A=sqrt(mean(iu.^2,1));
metrics.Converter1_Uline_rms_V=sqrt(mean(u.^2,1));
metrics.Converter1_frequency_Hz=freq;
metrics.P_converter1_AC_export_W=P1;
metrics.P_converter2_AC_absorbed_W=P2;
metrics.P_converter2_DC_return_W=Preturn;
metrics.P_source_W=Psource;
metrics.P_connection_winding_loss_W=Rloss;
metrics.P_connection_energy_change_W=dE;
metrics.P_connection_balance_residual_W=residual;
metrics.connection_balance_residual_percent=100*abs(residual)/P1;
metrics.recovery_ratio_percent=100*Preturn/P1;
metrics.source_voltage_mean_V=avg(ud);
metrics.source_current_mean_A=avg(ids);
metrics.gate_overlap_count=overlap;
metrics.pass=all(metrics.Converter1_output_Iline_rms_A>=1.0) ...
    && all(metrics.Converter1_Uline_rms_V>=31.75 & metrics.Converter1_Uline_rms_V<=32.25) ...
    && all(abs(freq-50)<0.5) ...
    && P1>0 && P2>0 && Preturn>0 && Psource>=0 && P1>Preturn ...
    && metrics.connection_balance_residual_percent<1.0 ...
    && all(overlap==0);
resultsDir=fullfile(projectDir,'results');
fid=fopen(fullfile(resultsDir,'bonus_req1_energy_recovery.json'),'w');
assert(fid>=0);fwrite(fid,jsonencode(metrics,'PrettyPrint',true),'char');fclose(fid);
bonus1_metrics=metrics;
save(fullfile(resultsDir,'regen_testbench_results.mat'),'bonus1_metrics','t','u','iu','-v7.3');
fprintf('BONUS1 I=[%.3f %.3f %.3f] U=[%.3f %.3f %.3f] P1=%.3f P2=%.3f Preturn=%.3f Psource=%.3f eta=%.3f%% residual=%.3f%% pass=%d\n', ...
    metrics.Converter1_output_Iline_rms_A,metrics.Converter1_Uline_rms_V, ...
    P1,P2,Preturn,Psource,metrics.recovery_ratio_percent, ...
    metrics.connection_balance_residual_percent,metrics.pass);
