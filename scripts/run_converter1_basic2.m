% Basic-2: independent switching run at the unchanged Basic-1 operating point.
projectDir = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectDir,'subsystems'));
mdl = 'converter1_basic_test_r2024a';
load_system(fullfile(projectDir,'models',[mdl '.slx']));
assignin(get_param(mdl,'ModelWorkspace'),'Fout_Hz',50);
si = Simulink.SimulationInput(mdl);
si = si.setModelParameter('StopTime','1.0');
so = sim(si);
t0 = 0.8; t1 = 1.0; fs = 200e3;
t = (t0:1/fs:t1-1/fs)'; N = numel(t);
uNames = {'acac_uab','acac_ubc','acac_uca'};
u = zeros(N,3);
for k=1:3
    s=so.get(uNames{k});
    assert(~isempty(s) && all(isfinite(double(s.Data(:)))),'Missing/nonfinite %s',uNames{k});
    u(:,k)=interp1(s.Time(:),double(s.Data(:)),t);
end
kFund = round(50*(t1-t0));
assert(abs(kFund/(t1-t0)-50)<1e-9 && abs(N/fs-(t1-t0))<1e-12,'Window is not coherent');
thd = zeros(1,3); broadband = thd; spectrum = zeros(N/2,3);
for k=1:3
    y=fft(u(:,k)-mean(u(:,k)));
    harmonicBins=(2:50)*kFund+1;
    thd(k)=100*sqrt(sum(abs(y(harmonicBins)).^2))/abs(y(kFund+1));
    positiveBins=2:(N/2+1);
    total=sum(abs(y(positiveBins)).^2);
    broadband(k)=100*sqrt(max(total-abs(y(kFund+1))^2,0))/abs(y(kFund+1));
    spectrum(:,k)=2*abs(y(2:N/2+1))/N;
end
metrics=struct('stage','Basic-2','model',mdl,'steady_window_s',[t0 t1], ...
    'cycles',10,'harmonics_included',[2 50], ...
    'THD_2_to_50_percent',thd,'broadband_residual_percent',broadband, ...
    'pass',all(thd<=2));
resultsDir=fullfile(projectDir,'results');
fid=fopen(fullfile(resultsDir,'basic_req2_thd.json'),'w');
assert(fid>=0); fwrite(fid,jsonencode(metrics,'PrettyPrint',true),'char'); fclose(fid);
f=(1:N/2)'*fs/N;
fig=figure('Visible','off');
plot(f,spectrum); xlim([0 3000]); grid on;
xlabel('Frequency (Hz)'); ylabel('Peak amplitude (V)');
legend('Uab','Ubc','Uca'); title('Basic-2 line-voltage spectrum (0.8–1.0 s)');
exportgraphics(fig,fullfile(resultsDir,'basic2_voltage_spectrum.png')); close(fig);
fprintf('BASIC2 THD=[%.5f %.5f %.5f]%% broadband=[%.5f %.5f %.5f]%% pass=%d\n', ...
    thd,broadband,metrics.pass);
