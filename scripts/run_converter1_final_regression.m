% Final Converter 1 regression after the Bonus testbench is complete.
projectDir=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectDir,'subsystems'));
sdiDir=fullfile(getenv('HOME'),'.cache','matlab-sdi-converter1');
if ~isfolder(sdiDir),mkdir(sdiDir);end
Simulink.sdi.setStorageLocation(sdiDir);
run(fullfile(projectDir,'scripts','run_converter1_basic1.m'));
run(fullfile(projectDir,'scripts','run_converter1_basic2.m'));
b1=jsondecode(fileread(fullfile(projectDir,'results','basic_req1_metrics.json')));
b2=jsondecode(fileread(fullfile(projectDir,'results','basic_req2_thd.json')));
assert(b1.pass && b2.pass,'Final Basic-1/2 regression failed');

mdl='converter1_basic_test_r2024a';
load_system(fullfile(projectDir,'models',[mdl '.slx']));
cases=struct('label',{'NoLoad_50Hz','FullLoad_50Hz','Rated_20Hz','Rated_50Hz','Rated_100Hz'}, ...
    'f',{50,50,20,50,100},'loadEnable',{0,1,1,1,1});
point=repmat(struct('label','','Fcommand_Hz',0,'load_enable',0, ...
    'Uline_rms_V',zeros(1,3),'Iline_rms_A',zeros(1,3), ...
    'Fmeasured_Hz',zeros(1,3),'gate_overlap_count',zeros(1,3)),1,numel(cases));
fs=100e3;t=(0.8:1/fs:1.0-1/fs)';
uNames={'acac_uab','acac_ubc','acac_uca'};
iNames={'acac_ia','acac_ib','acac_ic'};
gatePairs={{'acac_qah','acac_qal'}, ...
    {'acac_qbh','acac_qbl'}, {'acac_qch','acac_qcl'}};
for j=1:numel(cases)
    f=cases(j).f;
    si=Simulink.SimulationInput(mdl);
    si=si.setVariable('Fout_Hz',f,'Workspace',mdl);
    si=si.setVariable('Rphase',32/sqrt(3)/2,'Workspace',mdl);
    si=si.setVariable('LoadEnable',cases(j).loadEnable,'Workspace',mdl);
    si=si.setModelParameter('StopTime','1.0');
    si=si.setModelParameter('SignalLogging','off');
    so=sim(si);
    u=zeros(numel(t),3);i=u;fm=zeros(1,3);
    for k=1:3
        su=so.get(uNames{k});sc=so.get(iNames{k});
        u(:,k)=interp1(su.Time(:),double(su.Data(:)),t);
        i(:,k)=interp1(sc.Time(:),double(sc.Data(:)),t);
        assert(all(isfinite(u(:,k)))&&all(isfinite(i(:,k))),'Nonfinite final regression');
        yf=movmean(u(:,k),round(fs/1000));
        ix=find(yf(1:end-1)<=0&yf(2:end)>0);
        z=t(ix)-yf(ix).*(t(ix+1)-t(ix))./(yf(ix+1)-yf(ix));
        assert(numel(z)>=3,'Insufficient cycles in final regression');
        fm(k)=1/mean(diff(z));
    end
    overlap=zeros(1,3);
    for k=1:3
        a=so.get(gatePairs{k}{1});b=so.get(gatePairs{k}{2});
        overlap(k)=nnz(double(a.Data(:))+double(b.Data(:))>1);
    end
    p=point(j);p.label=cases(j).label;p.Fcommand_Hz=f;
    p.load_enable=cases(j).loadEnable;
    p.Uline_rms_V=sqrt(mean(u.^2,1));
    p.Iline_rms_A=sqrt(mean(i.^2,1));
    p.Fmeasured_Hz=fm;p.gate_overlap_count=overlap;
    point(j)=p;
    fprintf('FINAL_REGRESSION %s U=[%.4f %.4f %.4f] I=[%.4f %.4f %.4f] F=[%.4f %.4f %.4f]\n', ...
        p.label,p.Uline_rms_V,p.Iline_rms_A,p.Fmeasured_Hz);
end
U11=mean(point(1).Uline_rms_V);U12=mean(point(2).Uline_rms_V);
SU=abs((U12-U11)/32)*100;
reg=struct('stage','Final Converter 1 regression','model',mdl, ...
    'basic1_pass',b1.pass,'basic2_pass',b2.pass, ...
    'U11_no_load_V',U11,'U12_2A_V',U12, ...
    'SU_formula','abs((U12-U11)/32)*100%', 'SU_percent',SU,'points',point);
reg.pass=b1.pass&&b2.pass&&SU<0.3 ...
    && all(point(1).Iline_rms_A<1e-6) ...
    && all(abs(point(2).Iline_rms_A-2)<0.1) ...
    && all(arrayfun(@(p)all(p.Uline_rms_V>=31.75&p.Uline_rms_V<=32.25) ...
        && all(abs(p.Fmeasured_Hz-p.Fcommand_Hz)<0.5) ...
        && all(p.gate_overlap_count==0),point));
fid=fopen(fullfile(projectDir,'results','final_regression.json'),'w');
assert(fid>=0);fwrite(fid,jsonencode(reg,'PrettyPrint',true),'char');fclose(fid);
fprintf('FINAL_REGRESSION SU=%.6f%% pass=%d\n',SU,reg.pass);
