% Basic-3: six-point physical-switching load sweep with true three-phase disconnect.
projectDir=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectDir,'subsystems'));
mdl='converter1_basic_test_r2024a';
load_system(fullfile(projectDir,'models',[mdl '.slx']));
targets=[0 0.2 0.5 1.0 1.5 2.0];
t0=0.8; t1=1.0; fs=200e3; t=(t0:1/fs:t1-1/fs)'; N=numel(t);
uNames={'acac_uab','acac_ubc','acac_uca'};
iNames={'acac_ia','acac_ib','acac_ic'};
point=repmat(struct('I_target_A',0,'Rphase_ohm',0,'load_enable',0, ...
    'Uline_rms_V',zeros(1,3),'Uline_mean_V',0,'Iline_rms_A',zeros(1,3), ...
    'frequency_Hz',zeros(1,3),'THD_percent',zeros(1,3), ...
    'modulation_peak',0,'source_power_W',0),1,numel(targets));
for j=1:numel(targets)
    target=targets(j);
    if target==0
        Rphase=32/sqrt(3)/2; loadEnable=0; % real switches open, R stays finite
    else
        Rphase=(32/sqrt(3))/target; loadEnable=1;
    end
    si=Simulink.SimulationInput(mdl);
    si=si.setVariable('Fout_Hz',50,'Workspace',mdl);
    si=si.setVariable('Rphase',Rphase,'Workspace',mdl);
    si=si.setVariable('LoadEnable',loadEnable,'Workspace',mdl);
    si=si.setModelParameter('StopTime','1.0');
    so=sim(si);
    u=zeros(N,3); i=u; f=zeros(1,3); thd=f;
    for k=1:3
        su=so.get(uNames{k}); sc=so.get(iNames{k});
        assert(~isempty(su)&&~isempty(sc),'Missing sweep test point');
        u(:,k)=interp1(su.Time(:),double(su.Data(:)),t);
        i(:,k)=interp1(sc.Time(:),double(sc.Data(:)),t);
        assert(all(isfinite(u(:,k)))&&all(isfinite(i(:,k))),'Nonfinite sweep signal');
        uf=movmean(u(:,k),round(fs/1000));
        ix=find(uf(1:end-1)<=0 & uf(2:end)>0);
        z=t(ix)-uf(ix).*(t(ix+1)-t(ix))./(uf(ix+1)-uf(ix));
        assert(numel(z)>=5,'Unstable/invalid frequency at I=%g',target);
        f(k)=1/mean(diff(z));
        y=fft(u(:,k)-mean(u(:,k)));
        thd(k)=100*sqrt(sum(abs(y((2:50)*10+1)).^2))/abs(y(11));
    end
    sm=so.get('acac_inverter_modulation');
    sv=so.get('acac_vdc'); sid=so.get('tp_id_source');
    mask=sm.Time>=t0 & sm.Time<t1;
    p=point(j);
    p.I_target_A=target; p.Rphase_ohm=Rphase; p.load_enable=loadEnable;
    p.Uline_rms_V=sqrt(mean(u.^2,1)); p.Uline_mean_V=mean(p.Uline_rms_V);
    p.Iline_rms_A=sqrt(mean(i.^2,1)); p.frequency_Hz=f;
    p.THD_percent=thd; p.modulation_peak=max(double(sm.Data(mask)));
    vd=interp1(sv.Time(:),double(sv.Data(:)),t);
    ids=interp1(sid.Time(:),double(sid.Data(:)),t);
    p.source_power_W=mean(vd.*ids);
    point(j)=p;
    fprintf('BASIC3_POINT I=%.1f U=%.5f Imeas=%.6f Psrc=%.3f\n', ...
        target,p.Uline_mean_V,mean(p.Iline_rms_A),p.source_power_W);
end
U11=point(1).Uline_mean_V; U12=point(end).Uline_mean_V;
SU=abs((U12-U11)/32)*100;
allU=vertcat(point.Uline_rms_V);
metrics=struct();
metrics.stage='Basic-3'; metrics.model=mdl;
metrics.load_regulation_formula='abs((U12-U11)/32)*100%';
metrics.formula_source='User clarification; U11 at 0 A, U12 at 2 A';
metrics.U11_no_load_V=U11; metrics.U12_2A_V=U12;
metrics.SU_percent=SU; metrics.points=point;
metrics.sweep_min_Uline_V=min(allU(:)); metrics.sweep_max_Uline_V=max(allU(:));
metrics.pass=SU<0.3 && all(allU(:)>=31.75 & allU(:)<=32.25) ...
    && max(point(1).Iline_rms_A)<1e-6 ...
    && all(abs(point(end).Iline_rms_A-2)<0.1);
resultsDir=fullfile(projectDir,'results');
fid=fopen(fullfile(resultsDir,'basic_req3_load_regulation.json'),'w');
assert(fid>=0); fwrite(fid,jsonencode(metrics,'PrettyPrint',true),'char'); fclose(fid);
fig=figure('Visible','off');
plot(targets,allU,'o-','LineWidth',1.2); grid on;
xlabel('Target line current (A)'); ylabel('Line voltage RMS (V)');
legend('Uab','Ubc','Uca','Location','best');
title(sprintf('Basic-3: load regulation SU = %.4f%%',SU));
exportgraphics(fig,fullfile(resultsDir,'basic3_load_regulation.png')); close(fig);
fprintf('BASIC3 SU=%.6f%% U11=%.5f U12=%.5f pass=%d\n',SU,U11,U12,metrics.pass);
