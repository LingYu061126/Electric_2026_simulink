%% Bonus-1: independent voltage controllers with local-current virtual resistance
projectRoot = fileparts(fileparts(mfilename('fullpath')));
modelName = 'dual_single_phase_parallel_inverter_r2024a';
modelFile = fullfile(projectRoot,'models',[modelName '.slx']);
resultsDir = fullfile(projectRoot,'results');
assert(isfile(modelFile),'Dual-inverter model is missing: %s',modelFile);
assert(bdIsLoaded(modelName),'Open the dual-inverter model before running Bonus-1.');

in = Simulink.SimulationInput(modelName);
blockPath = @(sid) Simulink.ID.getFullName([modelName ':' sid]);
in = in.setBlockParameter(blockPath('254'),'Value','1'); % Inverter 1 enabled
in = in.setBlockParameter(blockPath('259'),'Value','1'); % Inverter 2 enabled
in = in.setBlockParameter(blockPath('270'),'Value','1'); % S1 closed
in = in.setBlockParameter(blockPath('271'),'Value','1'); % Load disconnect closed
in = in.setBlockParameter(blockPath('272'),'Value','0'); % S2 open
in = in.setBlockParameter(blockPath('269'),'r','6');
in = in.setBlockParameter(blockPath('414'),'Value','1'); % Controller 1 local droop
in = in.setBlockParameter(blockPath('419'),'Value','1'); % Controller 2 local droop
in = in.setModelParameter('StopTime','0.30');

logBlocks = find_system(modelName,'BlockType','ToWorkspace');
for k = 1:numel(logBlocks)
    variableName = get_param(logBlocks{k},'VariableName');
    if startsWith(variableName,{'Inv1_gate','Inv2_gate'})
        decimation = '1';
    else
        decimation = '4';
    end
    in = in.setBlockParameter(logBlocks{k},'Decimation',decimation);
end

runIdsBefore = Simulink.sdi.getAllRunIDs;
fprintf(['Running Bonus-1 switching simulation: both inverters enabled, ' ...
    'S1 closed, S2 open, Rload=6 Ohm, local virtual resistance=0.02 Ohm...\n']);
out = sim(in);

signals = {'TP_Uo','TP_Io','TP_Io1','TP_Io2','TP_load_current'};
raw = cell(size(signals));
signalTime = cell(size(signals));
for k = 1:numel(signals)
    s = out.get(signals{k});
    signalTime{k} = double(s.Time(:));
    raw{k} = double(squeeze(s.Data));
    raw{k} = raw{k}(:);
end
tEnd = floor(min(cellfun(@(x)x(end),signalTime))*1e6)/1e6;
t = (0.10:1e-6:tEnd)';
u = interp1(signalTime{1},raw{1},t,'linear');
io = interp1(signalTime{2},raw{2},t,'linear');
io1 = interp1(signalTime{3},raw{3},t,'linear');
io2 = interp1(signalTime{4},raw{4},t,'linear');
iload = interp1(signalTime{5},raw{5},t,'linear');
assert(all(isfinite([u;io;io1;io2;iload])), ...
    'Bonus-1 output/current logs contain nonfinite values.');

UoRms = sqrt(mean(u.^2));
IoTotalRms = sqrt(mean(io.^2));
Io1Rms = sqrt(mean(io1.^2));
Io2Rms = sqrt(mean(io2.^2));
ILoadRms = sqrt(mean(iload.^2));
iCirc = (io1-io2)/2;
iCircRms = sqrt(mean(iCirc.^2));
frequencyHz = fminbnd(@(f)sinFitResidual(u,t,f),49,51);

gateTime = double(out.get('Inv1_gate1').Time(:));
gates = false(numel(gateTime),8);
for k = 1:4
    sig1 = out.get(sprintf('Inv1_gate%d',k));
    sig2 = out.get(sprintf('Inv2_gate%d',k));
    gates(:,k) = interp1(double(sig1.Time(:)),double(squeeze(sig1.Data)), ...
        gateTime,'previous','extrap') > 0.5;
    gates(:,k+4) = interp1(double(sig2.Time(:)),double(squeeze(sig2.Data)), ...
        gateTime,'previous','extrap') > 0.5;
end
overlap = [nnz(gates(:,1)&gates(:,2)),nnz(gates(:,3)&gates(:,4)), ...
    nnz(gates(:,5)&gates(:,6)),nnz(gates(:,7)&gates(:,8))];
inv2GateHighSamples = nnz(any(gates(:,5:8),2));

metrics = struct();
metrics.stage = 'Bonus-1';
metrics.inverter1_enabled = true;
metrics.inverter2_enabled = true;
metrics.controller1_uses_Io1 = true;
metrics.controller2_uses_Io2 = true;
metrics.local_virtual_resistance_ohm = 0.02;
metrics.droop_enabled_in_both_controllers = true;
metrics.S1_closed = true;
metrics.S2_open = true;
metrics.R_load_Ohm = 6;
metrics.Uo_rms_V = UoRms;
metrics.frequency_Hz = frequencyHz;
metrics.Io_total_rms_A = IoTotalRms;
metrics.Io1_rms_A = Io1Rms;
metrics.Io2_rms_A = Io2Rms;
metrics.I_load_rms_A = ILoadRms;
metrics.current_sharing_imbalance_percent = ...
    abs(Io1Rms-Io2Rms)/max(Io1Rms+Io2Rms,eps)*100;
metrics.circulating_current_definition = '(i1-i2)/2';
metrics.circulating_current_rms_A = iCircRms;
metrics.gate_overlap_samples = overlap;
metrics.inverter2_gate_high_samples = inv2GateHighSamples;
metrics.measurement_window_s = [t(1),t(end)];
metrics.all_signals_finite = true;
metrics.all_gates_nonoverlap = all(overlap==0);
metrics.pass = UoRms>=23.8 && UoRms<=24.2 && ...
    frequencyHz>=49.8 && frequencyHz<=50.2 && IoTotalRms>=3.8 && ...
    all(overlap==0) && inv2GateHighSamples>0;

runIdsAfter = Simulink.sdi.getAllRunIDs;
newRunIds = setdiff(runIdsAfter,runIdsBefore);
for k = 1:numel(newRunIds)
    run = Simulink.sdi.getRun(newRunIds(k));
    if strcmp(run.Model,modelName)
        Simulink.sdi.deleteRun(newRunIds(k));
    end
end

save(fullfile(resultsDir,'bonus1_parallel_load.mat'), ...
    'out','metrics','t','u','io','io1','io2','iload','iCirc');
jsonFile = fullfile(resultsDir,'bonus1_metrics.json');
fid = fopen(jsonFile,'w');
assert(fid>=0,'Could not create Bonus-1 JSON result.');
fwrite(fid,jsonencode(metrics,'PrettyPrint',true),'char');
fclose(fid);

plotMask = t>=0.22;
fig = figure('Visible','off','Color','w');
plot(t(plotMask),io1(plotMask),'LineWidth',1.0); hold on;
plot(t(plotMask),io2(plotMask),'LineWidth',1.0);
plot(t(plotMask),io(plotMask),'LineWidth',1.0);
grid on; xlabel('Time (s)'); ylabel('Current (A)');
legend('I_{o1}','I_{o2}','I_o total','Location','best');
title('Bonus-1 parallel inverter currents');
exportgraphics(fig,fullfile(resultsDir,'bonus1_parallel_currents.png'),'Resolution',200);
close(fig);

fig = figure('Visible','off','Color','w');
plot(t(plotMask),u(plotMask),'LineWidth',1.0); hold on;
vref = out.get('vref');
plot(double(vref.Time(:)),double(squeeze(vref.Data)),'--','LineWidth',0.9);
xlim([t(find(plotMask,1)),t(end)]); grid on;
xlabel('Time (s)'); ylabel('Voltage (V)');
legend('U_o measured','Voltage reference','Location','best');
title('Bonus-1 common-bus output voltage');
exportgraphics(fig,fullfile(resultsDir,'bonus1_output_voltage.png'),'Resolution',200);
close(fig);

fig = figure('Visible','off','Color','w');
circulatingPlotCurrent = iCirc(plotMask);
circulatingAxisLimit = max(1e-3,1.2*max(abs(circulatingPlotCurrent)));
plot(t(plotMask),circulatingPlotCurrent,'LineWidth',1.0);
yline(0,':k');
ylim([-circulatingAxisLimit,circulatingAxisLimit]);
grid on; xlabel('Time (s)'); ylabel('i_{circ} (A)');
title(sprintf('Bonus-1 circulating current: %.4f A RMS',iCircRms));
exportgraphics(fig,fullfile(resultsDir,'bonus1_circulating_current.png'),'Resolution',200);
close(fig);

fprintf(['BONUS1_RESULT Uo=%.6f Vrms, f=%.6f Hz, Io=%.6f Arms, ' ...
    'Io1=%.6f Arms, Io2=%.6f Arms, Icirculating=%.6f Arms, PASS=%d\n'], ...
    UoRms,frequencyHz,IoTotalRms,Io1Rms,Io2Rms,iCircRms,metrics.pass);
assert(metrics.pass,'Bonus-1 failed; stop the sequential validation here.');

function e = sinFitResidual(x,t,f)
x = double(x(:));
t = double(t(:));
X = [ones(size(t)),cos(2*pi*f*t),sin(2*pi*f*t)];
c = X\x;
r = x-X*c;
e = mean(r.^2);
end
