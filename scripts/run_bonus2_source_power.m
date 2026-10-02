% Bonus-2: fixed-topology 50 Hz / 32 V / 2 A source-power test.
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
si=si.setVariable('RegenCurrentRef_RMS_A',2.0,'Workspace',mdl);
si=si.setVariable('RegenEnable',1,'Workspace',mdl);
si=si.setModelParameter('StopTime','1.0');
si=si.setModelParameter('SignalLogging','off');
so=sim(si);
required={'tp_conv2_ia','tp_conv2_ib','tp_conv2_ic', ...
    'tp_v1a_dcneg','tp_v1b_dcneg','tp_v1c_dcneg', ...
    'tp_v2a_dcneg','tp_v2b_dcneg','tp_v2c_dcneg', ...
    'tp_id_source','tp_conv2_dc_return_current','acac_vdc', ...
    'acac_uab','acac_ubc','acac_uca', ...
    'tp_c2_id','tp_c2_id_ref','tp_c2_iq', ...
    'tp_c2_gate_ah','tp_c2_gate_al','tp_c2_gate_bh','tp_c2_gate_bl', ...
    'tp_c2_gate_ch','tp_c2_gate_cl', ...
    'acac_qah','acac_qal','acac_qbh','acac_qbl','acac_qch','acac_qcl'};
sig=struct();
for k=1:numel(required)
    sig.(required{k})=so.get(required{k});
    assert(~isempty(sig.(required{k})),'Missing Bonus-2 TP: %s',required{k});
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
metrics.stage='Bonus-2';metrics.model=mdl;metrics.window_s=[0.8 1.0];
metrics.regen_reference_rms_A=2.0;
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
baseline=jsondecode(fileread(fullfile(projectDir,'results','basic_req1_metrics.json')));
metrics.P_source_resistive_baseline_W=baseline.source_power_mean_W;
metrics.source_power_reduction_percent=100*(baseline.source_power_mean_W-Psource)/baseline.source_power_mean_W;
metrics.P_ac_theory_W=sqrt(3)*32*2;
metrics.pass=all(abs(metrics.Converter1_output_Iline_rms_A-2.0)<0.1) ...
    && all(metrics.Converter1_Uline_rms_V>=31.75 & metrics.Converter1_Uline_rms_V<=32.25) ...
    && all(abs(freq-50)<0.5) ...
    && P1>0 && P2>0 && Preturn>0 && Psource>=0 && P1>Preturn ...
    && metrics.source_power_reduction_percent>0 ...
    && metrics.connection_balance_residual_percent<1.0 ...
    && all(overlap==0);
resultsDir=fullfile(projectDir,'results');
fid=fopen(fullfile(resultsDir,'bonus_req2_source_power.json'),'w');
assert(fid>=0);fwrite(fid,jsonencode(metrics,'PrettyPrint',true),'char');fclose(fid);
bonus2_metrics=metrics; bonus2_t=t; bonus2_u=u; bonus2_i=iu;
flow=struct();
flow.time_s=(0.31:0.02:0.99)';
flow.P_converter1_AC_W=zeros(numel(flow.time_s),1);
flow.P_converter2_AC_W=flow.P_converter1_AC_W;
flow.P_return_DC_W=flow.P_converter1_AC_W;
flow.P_source_W=flow.P_converter1_AC_W;
flow.Vdc_V=flow.P_converter1_AC_W;
p1Instant=sum(v1.*i,2);p2Instant=sum(v2.*i,2);
for k=1:numel(flow.time_s)
    m=tn>=flow.time_s(k)-0.01 & tn<=flow.time_s(k)+0.01;
    tk=tn(m);dk=tk(end)-tk(1);
    flow.P_converter1_AC_W(k)=trapz(tk,p1Instant(m))/dk;
    flow.P_converter2_AC_W(k)=trapz(tk,p2Instant(m))/dk;
    flow.P_return_DC_W(k)=trapz(tk,ud(m).*idret(m))/dk;
    flow.P_source_W(k)=trapz(tk,ud(m).*ids(m))/dk;
    flow.Vdc_V(k)=trapz(tk,ud(m))/dk;
end
trackT=(0.3:1/10e3:1.0-1/10e3)';
trackSample=@(s) interp1(s.Time(:),double(s.Data(:)),trackT);
tracking=struct('time_s',trackT,'id_A_peak',trackSample(sig.tp_c2_id), ...
    'id_ref_A_peak',trackSample(sig.tp_c2_id_ref), ...
    'iq_A_peak',trackSample(sig.tp_c2_iq));
save(fullfile(resultsDir,'regen_testbench_results.mat'), ...
    'bonus2_metrics','bonus2_t','bonus2_u','bonus2_i','flow','tracking','-append');

fig=figure('Visible','off');
plot(flow.time_s,flow.P_source_W,flow.time_s,flow.P_converter1_AC_W, ...
    flow.time_s,flow.P_converter2_AC_W,flow.time_s,flow.P_return_DC_W,'LineWidth',1.2);
grid on;xlabel('Time (s)');ylabel('One-cycle mean power (W)');
legend('DC source','Converter 1 AC export','Converter 2 AC absorbed','DC return','Location','best');
title('Energy flow in the fixed recovery topology');
exportgraphics(fig,fullfile(resultsDir,'regen_energy_flow.png'));close(fig);

fig=figure('Visible','off');
subplot(2,1,1);plot(t,u(:,1));grid on;ylabel('Uab (V)');
title('Regenerative 50 Hz / 32 V / 2 A operating point');
subplot(2,1,2);plot(t,iu(:,1));grid on;xlabel('Time (s)');ylabel('Ia to Converter 2 (A)');
exportgraphics(fig,fullfile(resultsDir,'regen_ac_voltage_current.png'));close(fig);

fig=figure('Visible','off');
plot(trackT,tracking.id_ref_A_peak,trackT,tracking.id_A_peak,trackT,tracking.iq_A_peak);
grid on;xlabel('Time (s)');ylabel('dq current (A peak)');
legend('id reference','id measured','iq measured','Location','best');
title('Converter 2 dq current tracking');
exportgraphics(fig,fullfile(resultsDir,'regen_converter2_current_tracking.png'));close(fig);

fig=figure('Visible','off');
subplot(2,1,1);plot(flow.time_s,flow.Vdc_V);grid on;ylabel('DC bus (V)');
title('Shared DC bus and power');
subplot(2,1,2);plot(flow.time_s,flow.P_source_W,flow.time_s,flow.P_return_DC_W);
grid on;xlabel('Time (s)');ylabel('Power (W)');legend('Source','Return','Location','best');
exportgraphics(fig,fullfile(resultsDir,'regen_dc_bus_power.png'));close(fig);

fig=figure('Visible','off');
bar([metrics.P_source_resistive_baseline_W,metrics.P_source_W]);
set(gca,'XTickLabel',{'2 A resistive load','2 A energy recovery'});
ylabel('Measured DC source power (W)');grid on;
title(sprintf('Source power reduction: %.3f%%',metrics.source_power_reduction_percent));
exportgraphics(fig,fullfile(resultsDir,'source_power_comparison.png'));close(fig);
fprintf('BONUS2 I=[%.3f %.3f %.3f] U=[%.3f %.3f %.3f] P1=%.3f P2=%.3f Preturn=%.3f Psource=%.3f reduction=%.3f%% eta=%.3f%% residual=%.3f%% pass=%d\n', ...
    metrics.Converter1_output_Iline_rms_A,metrics.Converter1_Uline_rms_V, ...
    P1,P2,Preturn,Psource,metrics.source_power_reduction_percent,metrics.recovery_ratio_percent, ...
    metrics.connection_balance_residual_percent,metrics.pass);
