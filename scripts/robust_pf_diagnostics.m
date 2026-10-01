% Diagnose total PF from the original full-switching 0.8-1.0 s waveforms.
projectDir = fileparts(fileparts(mfilename('fullpath')));
resultsDir = fullfile(projectDir,'results');
tags = {'0p2','0p5','1p0'};
currents = [0.2 0.5 1.0 2.0];
records = cell(1,4);
waves = cell(1,4);
for k=1:3
    s=load(fullfile(resultsDir,sprintf('acac_req6_%sA_results.mat',tags{k})),'m','w');
    waves{k}=s.w;
    records{k}=decompose(s.w,currents(k));
end
s=load(fullfile(resultsDir,'acac_req5_30hz_results.mat'),'req5','wave5');
waves{4}=s.wave5;
records{4}=decompose(s.wave5,currents(4));

report=struct();
report.model='models/acac_30hz_r2024a.slx';
report.window_s=[0.8 1.0];
report.resample_Hz=200e3;
report.points=[records{:}];
report.definition='PF_total=P/(Vin_rms*Iin_rms); DPF=cos(angle(V1)-angle(I1)); distortion factor=I1_rms/Iin_rms';
fid=fopen(fullfile(resultsDir,'robust_pf_decomposition.json'),'w');
assert(fid>=0); fwrite(fid,jsonencode(report,'PrettyPrint',true),'char'); fclose(fid);

for idx=[1 2 4]
    w=waves{idx}; r=records{idx};
    t=w.t(:); v=w.vin(:); i=w.iin(:);
    phaseWindow=t>=0.8 & t<=0.84;
    crossings=find(v(1:end-1)<=0 & v(2:end)>0);
    [~,near]=min(abs(t(crossings)-0.82));
    tCross=t(crossings(near));
    zeroWindow=abs(t-tCross)<=0.002;
    fig=figure('Visible','off','Color','w');
    subplot(2,1,1);
    plot(t(phaseWindow),v(phaseWindow)/max(abs(v)),'LineWidth',1.1); hold on;
    plot(t(phaseWindow),i(phaseWindow)/(sqrt(2)*r.I1_rms_A),'LineWidth',1.1);
    grid on; ylabel('Normalized to peak');
    title(sprintf('Input at %.1f A load: PF=%.4f, DPF=%.4f',currents(idx),r.PF_total,r.displacement_factor));
    legend('Vin / Vin,peak','Iin / I1,peak','Location','best');
    subplot(2,1,2);
    plot(1e3*(t(zeroWindow)-tCross),v(zeroWindow)/max(abs(v)),'LineWidth',1.1); hold on;
    plot(1e3*(t(zeroWindow)-tCross),i(zeroWindow)/(sqrt(2)*r.I1_rms_A),'LineWidth',1.1);
    xline(0,'k:'); grid on;
    xlabel('Time from positive zero crossing (ms)'); ylabel('Normalized to peak');
    if idx==1
        name='robust_pf_02A_waveform.png';
    elseif idx==2
        name='robust_pf_05A_waveform.png';
    else
        name='robust_pf_20A_waveform.png';
    end
    exportgraphics(fig,fullfile(resultsDir,name),'Resolution',180); close(fig);
end

fig=figure('Visible','off','Color','w');
for j=1:3
    idx=[1 2 4]; r=records{idx(j)};
    subplot(3,1,j);
    stem(2:50,r.harmonics_2to50_percent,'Marker','none');
    ylabel('% of I1'); xlim([2 50]); grid on;
    title(sprintf('Input-current harmonics at %.1f A, THD 2-50 = %.2f%%',...
        currents(idx(j)),r.harmonic_THD_2to50_percent));
end
xlabel('Harmonic order of 50 Hz');
exportgraphics(fig,fullfile(resultsDir,'robust_pf_harmonics.png'),'Resolution',180);
close(fig);
fprintf('PF_DECOMPOSITION_SAVED\n');
for k=1:numel(records)
    r=records{k};
    fprintf('Iout=%.1f PF=%.5f DPF=%.5f I1=%.5f Irms=%.5f distortion=%.5f THD2-50=%.2f%% broadband=%.2f%% P=%.3f W\n',...
        r.Iout_target_A,r.PF_total,r.displacement_factor,r.I1_rms_A,...
        r.Iin_rms_A,r.distortion_factor,r.harmonic_THD_2to50_percent,...
        r.broadband_nonfundamental_percent,r.Pin_W);
end

function r=decompose(w,targetA)
t=w.t(:); v=w.vin(:); i=w.iin(:);
N=numel(t); fs=1/mean(diff(t)); T=N/fs;
k1=round(50*T);
V=fft(v-mean(v)); I=fft(i-mean(i));
V1=2*V(k1+1)/N; I1=2*I(k1+1)/N;
vrms=sqrt(mean(v.^2)); irms=sqrt(mean(i.^2));
v1rms=abs(V1)/sqrt(2); i1rms=abs(I1)/sqrt(2);
phi=angle(V1)-angle(I1);
pin=mean(v.*i); S=vrms*irms;
h=100*abs(I((2:50)*k1+1))/abs(I(k1+1));
[sorted,order]=sort(h,'descend');
nonfund=sqrt(max(0,irms^2-i1rms^2));
positiveFrequency=(0:floor(N/2))*fs/N;
hfBins=find(positiveFrequency>2500 & positiveFrequency<fs/2);
hfRms=sqrt(2*sum(abs(I(hfBins)).^2))/N;
carrierBins=find(positiveFrequency>=19000 & positiveFrequency<=21000);
carrierRms=sqrt(2*sum(abs(I(carrierBins)).^2))/N;
r=struct();
r.Iout_target_A=targetA;
r.Vin_rms_V=vrms;
r.Iin_rms_A=irms;
r.I1_rms_A=i1rms;
r.input_current_dc_A=mean(i);
r.nonfundamental_current_rms_A=nonfund;
r.current_above_2p5kHz_rms_A=hfRms;
r.current_around_20kHz_rms_A=carrierRms;
r.Pin_W=pin;
r.apparent_power_VA=S;
r.PF_total=pin/S;
r.displacement_factor=cos(phi);
r.distortion_factor=i1rms/irms;
r.PF_from_DPF_times_distortion=r.displacement_factor*r.distortion_factor*v1rms/vrms;
r.PF_factorization_error=r.PF_total-r.PF_from_DPF_times_distortion;
r.fundamental_reactive_power_var=v1rms*i1rms*sin(phi);
r.nonfundamental_distortion_VA=vrms*nonfund;
r.harmonic_THD_2to50_percent=sqrt(sum(h.^2));
r.broadband_nonfundamental_percent=100*nonfund/i1rms;
r.harmonics_2to50_percent=h;
r.top_harmonic_orders=order(1:5)+1;
r.top_harmonic_percent=sorted(1:5);
r.duty_min=min(w.pfc_duty(:));
r.duty_max=max(w.pfc_duty(:));
r.duty_floor_samples=nnz(w.pfc_duty(:)<=0.020001);
r.duty_ceiling_samples=nnz(w.pfc_duty(:)>=0.949999);
end
