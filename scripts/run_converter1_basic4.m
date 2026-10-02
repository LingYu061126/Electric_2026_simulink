% Basic-4: every integer frequency 20:100, each as a real switching simulation.
projectDir=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectDir,'subsystems'));
mdl='converter1_basic_test_r2024a';
load_system(fullfile(projectDir,'models',[mdl '.slx']));
frequencies=20:100; fullChecks=20:10:100;
point=repmat(struct('Fcommand_Hz',0,'Fmeasured_Hz',zeros(1,3), ...
    'Uline_rms_V',zeros(1,3),'Iline_rms_A',zeros(1,3), ...
    'modulation_peak',0,'window_s',zeros(1,2),'stop_time_s',0, ...
    'full_independent_verification',false,'stable',false),1,numel(frequencies));
resultsDir=fullfile(projectDir,'results');
% SDI's default /tmp repository is a small tmpfs on this machine.
sdiDir=fullfile(getenv('HOME'),'.cache','matlab-sdi-converter1');
if ~isfolder(sdiDir), mkdir(sdiDir); end
Simulink.sdi.setStorageLocation(sdiDir);
fs=100e3;
progressFile=fullfile(resultsDir,'basic_req4_frequency_sweep_progress.json');
startIdx=1;
if isfile(progressFile)
    saved=jsondecode(fileread(progressFile));
    n=saved.completed_points;
    assert(n>=0 && n<=numel(frequencies) && numel(saved.points)==n, ...
        'Invalid Basic-4 checkpoint');
    for k=1:n
        assert(saved.points(k).Fcommand_Hz==frequencies(k) && saved.points(k).stable, ...
            'Basic-4 checkpoint contains a failed/misordered frequency');
    end
    point(1:n)=saved.points;
    startIdx=n+1;
end
if ~exist('maxPoints','var'), maxPoints=inf; end
endIdx=min(numel(frequencies),startIdx+maxPoints-1);
fprintf('BASIC4 RESUME at index=%d frequency=%d, stop index=%d\n', ...
    startIdx,frequencies(min(startIdx,numel(frequencies))),endIdx);
for j=startIdx:endIdx
    f=frequencies(j);
    isFull=ismember(f,fullChecks);
    if isFull, stopTime=1.0; else, stopTime=0.7; end
    cycles=floor((stopTime-0.4)*f);
    t0=stopTime-cycles/f;
    t=(t0:1/fs:stopTime-1/fs)';
    si=Simulink.SimulationInput(mdl);
    si=si.setVariable('Fout_Hz',f,'Workspace',mdl);
    si=si.setVariable('Rphase',32/sqrt(3)/2,'Workspace',mdl);
    si=si.setVariable('LoadEnable',1,'Workspace',mdl);
    si=si.setModelParameter('StopTime',num2str(stopTime,'%.2f'));
    % ToWorkspace test points remain available; disable duplicate SDI signal logging.
    si=si.setModelParameter('SignalLogging','off');
    runsBefore=Simulink.sdi.getAllRunIDs;
    so=sim(si);
    assert(so.tout(end)>=stopTime-1e-9,'Simulation ended early at %d Hz',f);
    u=zeros(numel(t),3); i=u; measured=zeros(1,3);
    uNames={'acac_uab','acac_ubc','acac_uca'};
    iNames={'acac_ia','acac_ib','acac_ic'};
    for k=1:3
        su=so.get(uNames{k}); sc=so.get(iNames{k});
        assert(~isempty(su)&&~isempty(sc),'Missing test point at %d Hz',f);
        u(:,k)=interp1(su.Time(:),double(su.Data(:)),t);
        i(:,k)=interp1(sc.Time(:),double(sc.Data(:)),t);
        assert(all(isfinite(u(:,k)))&&all(isfinite(i(:,k))),'Nonfinite waveform at %d Hz',f);
        uf=movmean(u(:,k),round(fs/1000));
        ix=find(uf(1:end-1)<=0 & uf(2:end)>0);
        z=t(ix)-uf(ix).*(t(ix+1)-t(ix))./(uf(ix+1)-uf(ix));
        assert(numel(z)>=4,'Too few fundamental cycles at %d Hz',f);
        measured(k)=1/mean(diff(z));
    end
    sm=so.get('acac_inverter_modulation');
    mask=sm.Time>=t0 & sm.Time<stopTime;
    p=point(j); p.Fcommand_Hz=f; p.Fmeasured_Hz=measured;
    p.Uline_rms_V=sqrt(mean(u.^2,1));
    p.Iline_rms_A=sqrt(mean(i.^2,1));
    p.modulation_peak=max(double(sm.Data(mask)));
    p.window_s=[t0 stopTime]; p.stop_time_s=stopTime;
    p.full_independent_verification=isFull;
    p.stable=all(abs(measured-f)<0.5) ...
        && all(p.Uline_rms_V>=31.75 & p.Uline_rms_V<=32.25) ...
        && all(p.Iline_rms_A>1.8 & p.Iline_rms_A<2.2) ...
        && p.modulation_peak<0.95;
    point(j)=p;
    checkpoint=struct('completed_points',j,'points',point(1:j));
    fid=fopen(progressFile,'w');
    assert(fid>=0); fwrite(fid,jsonencode(checkpoint),'char'); fclose(fid);
    fprintf('BASIC4 F=%d measured=%.4f U=%.4f I=%.4f full=%d stable=%d\n', ...
        f,mean(measured),mean(p.Uline_rms_V),mean(p.Iline_rms_A),isFull,p.stable);
    assert(p.stable,'Basic-4 gate failed at %d Hz',f);
    % Only remove runs created by this iteration; the checkpoint keeps measured data.
    newRuns=setdiff(Simulink.sdi.getAllRunIDs,runsBefore);
    for runID=newRuns(:)'
        Simulink.sdi.deleteRun(runID);
    end
    clear so su sc sm si u i
end
if endIdx<numel(frequencies)
    fprintf('BASIC4 CHUNK COMPLETE through %d Hz; %d points remain\n', ...
        frequencies(endIdx),numel(frequencies)-endIdx);
    return
end
allF=zeros(numel(point),3); allU=allF;
for k=1:numel(point)
    allF(k,:)=point(k).Fmeasured_Hz(:).';
    allU(k,:)=point(k).Uline_rms_V(:).';
end
metrics=struct('stage','Basic-4','model',mdl,'range_Hz',[20 100], ...
    'step_Hz',1,'point_count',numel(point),'full_verification_Hz',fullChecks, ...
    'max_frequency_error_Hz',max(abs(allF-frequencies(:)),[],'all'), ...
    'min_Uline_V',min(allU(:)),'max_Uline_V',max(allU(:)), ...
    'all_stable',all([point.stable]),'points',point,'pass',all([point.stable]));
fid=fopen(fullfile(resultsDir,'basic_req4_frequency_sweep.json'),'w');
assert(fid>=0); fwrite(fid,jsonencode(metrics,'PrettyPrint',true),'char'); fclose(fid);
fig=figure('Visible','off');
subplot(2,1,1); plot(frequencies,allF,'LineWidth',1); hold on;
plot(frequencies,frequencies,'k--'); grid on; ylabel('Measured frequency (Hz)');
legend('Uab','Ubc','Uca','Command','Location','best');
subplot(2,1,2); plot(frequencies,allU,'LineWidth',1); hold on;
yline(31.75,'k--'); yline(32.25,'k--'); grid on;
xlabel('Command frequency (Hz)'); ylabel('Line RMS (V)');
legend('Uab','Ubc','Uca','Limits','Location','best');
exportgraphics(fig,fullfile(resultsDir,'basic4_frequency_sweep.png')); close(fig);
fprintf('BASIC4 COMPLETE count=%d maxFErr=%.5f minU=%.4f maxU=%.4f pass=%d\n', ...
    metrics.point_count,metrics.max_frequency_error_Hz,metrics.min_Uline_V,metrics.max_Uline_V,metrics.pass);
