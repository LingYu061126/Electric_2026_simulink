% Component-level i^2 R estimates from original full-switching saved waves.
projectDir=fileparts(fileparts(mfilename('fullpath')));
resultsDir=fullfile(projectDir,'results');
lineV=[31 36 41];
cases=cell(1,3);
s=load(fullfile(resultsDir,'acac_req7_31V_results.mat'),'m','w'); cases{1}=calcLoss(s.m,s.w,31);
s=load(fullfile(resultsDir,'acac_req5_30hz_results.mat'),'req5','wave5'); cases{2}=calcLoss(s.req5,s.wave5,36);
s=load(fullfile(resultsDir,'acac_req7_41V_results.mat'),'m','w'); cases{3}=calcLoss(s.m,s.w,41);
records=[cases{:}];
report=struct();
report.window_s=[0.8 1.0];
report.model='models/acac_30hz_r2024a.slx';
report.method='Measured waveform i^2R for input winding and DC-link ESR; topology-based active-device resistance proxy; RC-reconstructed output branch currents.';
report.note='Switch-path current proxies and reconstructed capacitor current are estimates. Residual is unresolved modeled loss, not assigned to a fabricated branch.';
report.points=records;
fid=fopen(fullfile(resultsDir,'robust_loss_decomposition.json'),'w');
assert(fid>=0); fwrite(fid,jsonencode(report,'PrettyPrint',true),'char'); fclose(fid);

labels={'PFC switch proxy','Boost winding','DC ESR','VSI switch proxy','Filter winding','Output damping','Unresolved'};
parts=zeros(3,numel(labels));
for k=1:3
    r=records(k);
    parts(k,:)=[r.PFC_MOSFET_external_R_est_W,r.boost_inductor_copper_W,...
        r.DC_link_ESR_W,r.inverter_MOSFET_external_R_est_W,...
        r.output_inductor_copper_est_W,r.output_capacitor_damping_est_W,...
        r.unresolved_aggregate_W];
end
fig=figure('Visible','off','Color','w');
bar(lineV,parts,'stacked'); grid on;
xlabel('Input voltage RMS (V)'); ylabel('Modeled loss (W)');
title('Component loss estimates from switching waveforms (residual unresolved)');
legend(labels,'Location','eastoutside');
exportgraphics(fig,fullfile(resultsDir,'robust_loss_breakdown.png'),'Resolution',180);
close(fig);
for k=1:3
    r=records(k);
    fprintf('Ui=%.0f Pin=%.4f Pout=%.4f loss=%.4f boost=%.4f PFCsw~%.4f Cdc=%.4f inv~%.4f Lout~%.4f Rd~%.4f unresolved=%.4f eta=%.4f%%\n',...
        r.Ui_target_V,r.Pin_W,r.Pout_W,r.total_loss_W,r.boost_inductor_copper_W,...
        r.PFC_MOSFET_external_R_est_W,r.DC_link_ESR_W,...
        r.inverter_MOSFET_external_R_est_W,r.output_inductor_copper_est_W,...
        r.output_capacitor_damping_est_W,r.unresolved_aggregate_W,r.efficiency_percent);
end

function r=calcLoss(m,w,ui)
i=w.iin(:); vdc=w.vdc(:); idcPfc=w.idc_pfc(:); idcInv=w.idc_inverter(:);
v=[w.va(:) w.vb(:) w.vc(:)]; iLoad=[w.ia(:) w.ib(:) w.ic(:)];
dt=mean(diff(w.t(:))); C=25.33029591e-6; Rd=1;
alpha=exp(-dt/(C*Rd));
vC=zeros(size(v)); vC(1,:)=v(1,:);
for n=2:size(v,1)
    vC(n,:)=alpha*vC(n-1,:)+(1-alpha)*v(n,:);
end
iCap=(v-vC)/Rd;
iFilter=iLoad+iCap;
pin=mean(w.vin(:).*i);
pout=mean(sum(v.*iLoad,2));
loss=pin-pout;
r=struct();
r.Ui_target_V=ui;
r.Pin_W=pin;
r.Pout_W=pout;
r.total_loss_W=loss;
r.efficiency_percent=100*pout/pin;
r.Iin_rms_A=sqrt(mean(i.^2));
r.Icap_dc_rms_A=sqrt(mean((idcPfc-idcInv).^2));
r.Iout_filter_rms_A=sqrt(mean(iFilter.^2,1));
r.Iout_capacitor_rms_A=sqrt(mean(iCap.^2,1));
r.boost_inductor_copper_W=0.08*mean(i.^2);
% An ideal synchronous path contains one fast and one slow 50 mOhm branch.
% Branch currents were not logged; this is a topology-based path estimate.
r.PFC_fast_MOSFET_external_R_est_W=0.05*mean(i.^2);
r.PFC_slow_MOSFET_external_R_est_W=0.05*mean(i.^2);
r.PFC_MOSFET_external_R_est_W=r.PFC_fast_MOSFET_external_R_est_W+...
    r.PFC_slow_MOSFET_external_R_est_W;
r.DC_link_ESR_W=0.04*mean((idcPfc-idcInv).^2);
% Each VSI leg has one main conducting 50 mOhm external branch at a time.
r.inverter_MOSFET_external_R_est_W=0.05*sum(mean(iFilter.^2,1));
r.output_inductor_copper_est_W=0.08*sum(mean(iFilter.^2,1));
r.output_capacitor_damping_est_W=Rd*sum(mean(iCap.^2,1));
known=r.boost_inductor_copper_W+r.PFC_MOSFET_external_R_est_W+...
    r.DC_link_ESR_W+r.inverter_MOSFET_external_R_est_W+...
    r.output_inductor_copper_est_W+r.output_capacitor_damping_est_W;
r.unresolved_aggregate_W=loss-known;
r.PFC_DC_output_power_W=mean(vdc.*idcPfc);
r.inverter_DC_input_power_W=mean(vdc.*idcInv);
r.full_switching_waveforms=true;
r.sensor_or_reconstruction_notes={...
    'Boost current: source current sensor in series after precharge bypass.',...
    'DC ESR current: PFC DC current minus inverter DC current, from bus KCL.',...
    'Output capacitor current: reconstructed first-order series RC branch using measured phase voltage.',...
    'PFC/VSI switch branch current: ideal synchronous conduction path proxy, not directly measured.'};
assert(abs(pin-m.input_power_W)<0.02 && abs(pout-m.output_power_W)<0.02,...
    'Loss diagnostic power does not match original coherent-window metric.');
end
