% Inspect PFC control states directly logged from the full switching model.
projectDir=fileparts(fileparts(mfilename('fullpath')));
resultsDir=fullfile(projectDir,'results');
s=load(fullfile(resultsDir,'robust_diagnostic_02A_results.mat'),'m','w','d');
d=s.d; values=squeeze(double(d.Data));
assert(size(values,1)==9,'Unexpected diagnostic vector length.');
t=double(d.Time(:));
ix=t>=0.8 & t<=s.w.t(end);
t=t(ix); values=values(:,ix);
g=values(1,:)'; iref=values(2,:)'; ierr=values(3,:)';
piout=values(4,:)'; ff=values(5,:)'; raw=values(6,:)';
duty=values(7,:)'; gunclamped=values(8,:)'; buserr=values(9,:)';
iin=interp1(s.w.t,s.w.iin,t,'linear');
vin=interp1(s.w.t,s.w.vin,t,'linear');
assert(all(isfinite([g;iref;ierr;piout;ff;raw;duty;gunclamped;buserr;iin;vin])));

metric=struct();
metric.load_current_target_A=0.2;
metric.steady_window_s=[0.8 1.0];
metric.logged_decimation=10;
metric.total_samples=numel(t);
metric.g_mean_S=mean(g);
metric.g_min_S=min(g);
metric.g_max_S=max(g);
metric.g_std_S=std(g);
metric.g_zero_samples=nnz(g<=1e-9);
metric.g_ceiling_samples=nnz(g>=0.139999);
metric.iref_rms_A=sqrt(mean(iref.^2));
metric.iin_rms_A=sqrt(mean(iin.^2));
metric.current_error_rms_A=sqrt(mean(ierr.^2));
metric.current_error_mean_A=mean(ierr);
metric.current_PI_output_min=min(piout);
metric.current_PI_output_max=max(piout);
metric.current_PI_output_rms=sqrt(mean(piout.^2));
metric.duty_feedforward_min=min(ff);
metric.duty_feedforward_max=max(ff);
metric.raw_duty_min=min(raw);
metric.raw_duty_max=max(raw);
metric.limited_duty_min=min(duty);
metric.limited_duty_max=max(duty);
metric.duty_floor_samples=nnz(duty<=0.020001);
metric.duty_ceiling_samples=nnz(duty>=0.949999);
metric.raw_duty_below_floor_samples=nnz(raw<0.02);
metric.raw_duty_above_ceiling_samples=nnz(raw>0.95);
metric.bus_error_min_V=min(buserr);
metric.bus_error_max_V=max(buserr);
metric.PF_total=s.m.input_PF;
metric.all_finite=true;
fid=fopen(fullfile(resultsDir,'robust_pfc_internal_02A.json'),'w');
assert(fid>=0); fwrite(fid,jsonencode(metric,'PrettyPrint',true),'char'); fclose(fid);

ixplot=t>=0.818 & t<=0.822;
fig=figure('Visible','off','Color','w');
subplot(3,1,1);
plot(1e3*(t(ixplot)-0.82),vin(ixplot)/max(abs(vin)),'LineWidth',1); hold on;
plot(1e3*(t(ixplot)-0.82),iref(ixplot),'LineWidth',1);
plot(1e3*(t(ixplot)-0.82),iin(ixplot),'LineWidth',1);
grid on; ylabel('Vin norm / current A');
title('PFC internal control near 50 Hz zero crossing, 0.2 A load');
legend('Vin normalized','Iref A','Iin A','Location','best');
subplot(3,1,2);
plot(1e3*(t(ixplot)-0.82),ff(ixplot),'LineWidth',1); hold on;
plot(1e3*(t(ixplot)-0.82),raw(ixplot),'LineWidth',1);
plot(1e3*(t(ixplot)-0.82),duty(ixplot),'LineWidth',1);
grid on; ylabel('PFC duty'); legend('Feedforward','Raw','Limited','Location','best');
subplot(3,1,3);
plot(1e3*(t(ixplot)-0.82),g(ixplot),'LineWidth',1); hold on;
plot(1e3*(t(ixplot)-0.82),piout(ixplot),'LineWidth',1);
grid on; xlabel('Time from zero crossing (ms)'); ylabel('g S / PI output');
legend('Conductance g','Current PI output','Location','best');
exportgraphics(fig,fullfile(resultsDir,'robust_pfc_internal_02A.png'),'Resolution',180);
close(fig);
fprintf('PFC_INTERNAL g=[%.5f %.5f %.5f] floor=%d ceiling=%d errorRMS=%.4f rawDuty=[%.4f %.4f] duty=[%.4f %.4f]\n',...
    metric.g_min_S,metric.g_mean_S,metric.g_max_S,...
    metric.duty_floor_samples,metric.duty_ceiling_samples,...
    metric.current_error_rms_A,metric.raw_duty_min,metric.raw_duty_max,...
    metric.limited_duty_min,metric.limited_duty_max);
