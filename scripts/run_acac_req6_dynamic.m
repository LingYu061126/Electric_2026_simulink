% Genuine full-switching 2 A -> 0.2 A -> 2 A dynamic-load validation.
projectDir = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectDir,'models'));
mdl = 'acac_req6_dynamic_r2024a';
load_system(fullfile(projectDir,'models',[mdl '.slx']));
in = Simulink.SimulationInput(mdl);
in = in.setVariable('Fout_Hz',30,'Workspace',mdl);
in = in.setModelParameter('StopTime','1.4');
out = sim(in);

fs = 100e3;
t = (0.60:1/fs:1.4-1/fs)';
uab = logged(out,'acac_uab',t);
ubc = logged(out,'acac_ubc',t);
uca = logged(out,'acac_uca',t);
ia = logged(out,'acac_ia',t);
ib = logged(out,'acac_ib',t);
ic = logged(out,'acac_ic',t);
vdc = logged(out,'acac_vdc',t);
N = round(fs/30);
urms = sqrt(movmean([uab.^2 ubc.^2 uca.^2],[N-1 0],1));
irms = sqrt(movmean([ia.^2 ib.^2 ic.^2],[N-1 0],1));
uavg = mean(urms,2);
iavg = mean(irms,2);
windows = [0.70 0.76;0.98 1.03;1.30 1.36];
uSteady = zeros(1,3); iSteady = zeros(1,3); vdcSteady = zeros(1,3);
for k = 1:3
    ix = t >= windows(k,1) & t <= windows(k,2);
    uSteady(k) = mean(uavg(ix));
    iSteady(k) = mean(iavg(ix));
    vdcSteady(k) = mean(vdc(ix));
end
stepWindows = [0.8 1.00;1.05 1.30];
peakDeviation = zeros(1,2); busMin = zeros(1,2); busMax = zeros(1,2);
settlingS = nan(1,2);
for k = 1:2
    ix = t >= stepWindows(k,1) & t <= stepWindows(k,2);
    peakDeviation(k) = max(abs(uavg(ix)-32));
    busMin(k) = min(vdc(ix));
    busMax(k) = max(vdc(ix));
    % First time the line RMS stays inside +/-0.3% for at least 20 ms.
    idx = find(ix);
    good = abs(uavg(idx)-32) <= 0.003*32;
    holdN = round(0.02*fs);
    stable = conv(double(good),ones(holdN,1),'valid') >= holdN;
    first = find(stable,1,'first');
    if ~isempty(first)
        settlingS(k) = t(idx(first)) - stepWindows(k,1);
    end
end
dynamic = struct();
dynamic.load_change_times_s = [0.8 1.05];
dynamic.target_current_sequence_A = [2 0.2 2];
dynamic.measured_current_steady_A = iSteady;
dynamic.line_voltage_steady_V = uSteady;
dynamic.dc_bus_steady_V = vdcSteady;
dynamic.max_abs_line_voltage_deviation_after_step_V = peakDeviation;
dynamic.settling_to_0p3_percent_s = settlingS;
dynamic.dc_bus_min_after_step_V = busMin;
dynamic.dc_bus_max_after_step_V = busMax;
dynamic.all_finite_waveforms = all(isfinite([uavg;iavg;vdc]));
dynamic.dynamic_current_sequence_confirmed = abs(iSteady(1)-2)<0.03 ...
    && abs(iSteady(2)-0.2)<0.03 && abs(iSteady(3)-2)<0.03;
save(fullfile(projectDir,'results','acac_req6_dynamic_results.mat'), ...
    'out','dynamic','t','uavg','iavg','vdc','-v7.3');
fid=fopen(fullfile(projectDir,'results','acac_req6_dynamic_metrics.json'),'w');
assert(fid>=0); fwrite(fid,jsonencode(dynamic,'PrettyPrint',true),'char'); fclose(fid);

fig=figure('Visible','off','Color','w');
subplot(3,1,1); plot(t,uavg,'LineWidth',1); hold on;
yline(32,'k--'); yline(32*(1+0.003),'r:'); yline(32*(1-0.003),'r:');
xline(0.8,'k:'); xline(1.05,'k:'); xlim([0.67 1.4]); grid on;
ylabel('Line RMS (V)'); title('Physical switching load step: 2 A -> 0.2 A -> 2 A');
subplot(3,1,2); plot(t,iavg,'LineWidth',1); hold on;
xline(0.8,'k:'); xline(1.05,'k:'); xlim([0.67 1.4]); grid on; ylabel('Line RMS (A)');
subplot(3,1,3); plot(t,vdc,'LineWidth',1); hold on;
xline(0.8,'k:'); xline(1.05,'k:'); xlim([0.67 1.4]); grid on;
ylabel('DC bus (V)'); xlabel('Time (s)');
exportgraphics(fig,fullfile(projectDir,'results','req6_load_dynamic.png'),'Resolution',180);
close(fig);
fprintf('DYNAMIC I=[%.4f %.4f %.4f] A U=[%.4f %.4f %.4f] V peakdev=[%.4f %.4f] V valid=%d\n', ...
    iSteady,uSteady,peakDeviation,dynamic.dynamic_current_sequence_confirmed);

function y = logged(out,name,t)
ts=out.get(name);
assert(~isempty(ts),'Missing %s',name);
[tu,ix]=unique(ts.Time(:),'stable');
data=double(ts.Data(:));
assert(all(isfinite(data)),'Nonfinite %s',name);
y=interp1(tu,data(ix),t,'linear');
assert(all(isfinite(y)),'Incomplete time coverage: %s',name);
end
