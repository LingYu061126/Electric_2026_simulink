%% Basic-4: physical load sweep and load regulation
projectRoot = fileparts(fileparts(mfilename('fullpath')));
modelName = 'dual_single_phase_parallel_inverter_r2024a';
modelFile = fullfile(projectRoot,'models',[modelName '.slx']);
resultsDir = fullfile(projectRoot,'results');
basic1File = fullfile(resultsDir,'basic1_single_inverter.mat');
assert(isfile(modelFile),'Dual-inverter model is missing: %s',modelFile);
assert(isfile(basic1File),'Run Basic-1 before Basic-4.');
assert(bdIsLoaded(modelName),'Open the saved model before running this stage.');

basic1 = load(basic1File,'metrics');
assert(basic1.metrics.pass,'Basic-1 did not pass; stop before Basic-4.');
IloadTarget = [0,0.2,0.5,1,1.5,2];
Rload = [12,24./IloadTarget(2:end)];
progressFile = fullfile(resultsDir,'basic4_load_regulation_progress.mat');
modelInfo = dir(modelFile);
modelStamp = modelInfo.datenum;
completed = false(size(IloadTarget));

if isfile(progressFile)
    savedProgress = load(progressFile);
    if isequal(savedProgress.IloadTarget,IloadTarget) && savedProgress.modelStamp == modelStamp
        UoRms = savedProgress.UoRms;
        IloadRms = savedProgress.IloadRms;
        frequencyHz = savedProgress.frequencyHz;
        gateOverlap = savedProgress.gateOverlap;
        completed = savedProgress.completed;
    else
        UoRms = nan(size(IloadTarget));
        IloadRms = nan(size(IloadTarget));
        frequencyHz = nan(size(IloadTarget));
        gateOverlap = zeros(numel(IloadTarget),4);
    end
else
    UoRms = nan(size(IloadTarget));
    IloadRms = nan(size(IloadTarget));
    frequencyHz = nan(size(IloadTarget));
    gateOverlap = zeros(numel(IloadTarget),4);
end

% Reuse the Basic-1 rated point, which uses the same switch states, resistor,
% auxiliary-power assumption, controller, and saved model version.
if ~completed(end)
    UoRms(end) = basic1.metrics.Uo_rms_V;
    IloadRms(end) = basic1.metrics.I_load_rms_A;
    frequencyHz(end) = basic1.metrics.output_frequency_Hz;
    gateOverlap(end,:) = [basic1.metrics.gate_overlap_inv1_legA_samples, ...
        basic1.metrics.gate_overlap_inv1_legB_samples, ...
        basic1.metrics.gate_overlap_inv2_legA_samples, ...
        basic1.metrics.gate_overlap_inv2_legB_samples];
    completed(end) = true;
end
save(progressFile,'IloadTarget','Rload','UoRms','IloadRms','frequencyHz', ...
    'gateOverlap','completed','modelStamp');

for k = 1:numel(IloadTarget)-1
    if completed(k)
        continue;
    end
    in = Simulink.SimulationInput(modelName);
    blockPath = @(sid) Simulink.ID.getFullName([modelName ':' sid]);
    in = in.setBlockParameter(blockPath('254'),'Value','1');
    in = in.setBlockParameter(blockPath('259'),'Value','0');
    in = in.setBlockParameter(blockPath('270'),'Value','1');
    in = in.setBlockParameter(blockPath('271'),'Value','0'); % physical open circuit at 0 A
    in = in.setBlockParameter(blockPath('272'),'Value','0');
    in = in.setBlockParameter(blockPath('269'),'r',num2str(Rload(k),16));
    loadState = 'open';
    if IloadTarget(k) > 0
        in = in.setBlockParameter(blockPath('271'),'Value','1');
        loadState = 'closed';
    end
    in = in.setModelParameter('StopTime','0.30');

    logBlocks = find_system(modelName,'BlockType','ToWorkspace');
    for j = 1:numel(logBlocks)
        variableName = get_param(logBlocks{j},'VariableName');
        if startsWith(variableName,{'Inv1_gate','Inv2_gate'})
            decimation = '1';
        else
            decimation = '4';
        end
        in = in.setBlockParameter(logBlocks{j},'Decimation',decimation);
    end

    runIdsBefore = Simulink.sdi.getAllRunIDs;
    fprintf('Running Basic-4 switching simulation: Iload target=%.1f A, S_Load=%s, R=%.6g Ohm...\n', ...
        IloadTarget(k),loadState,Rload(k));
    out = sim(in);
    [UoRms(k),IloadRms(k),frequencyHz(k),gateOverlap(k,:)] = measurePoint(out);
    runIdsAfter = Simulink.sdi.getAllRunIDs;
    newRunIds = setdiff(runIdsAfter,runIdsBefore);
    for j = 1:numel(newRunIds)
        run = Simulink.sdi.getRun(newRunIds(j));
        if strcmp(run.Model,modelName)
            Simulink.sdi.deleteRun(newRunIds(j));
        end
    end
    clear out
    completed(k) = true;
    save(progressFile,'IloadTarget','Rload','UoRms','IloadRms','frequencyHz', ...
        'gateOverlap','completed','modelStamp');
    fprintf('BASIC4_POINT_COMPLETE target=%.1f A, measured=%.6f Arms, Uo=%.6f Vrms\n', ...
        IloadTarget(k),IloadRms(k),UoRms(k));
end

loadRegulationPercent = abs(UoRms(end)-UoRms(1))/UoRms(1)*100;
allFinite = all(isfinite([UoRms,IloadRms,frequencyHz]),'all');
gateSafe = all(gateOverlap(:)==0);
metrics = struct();
metrics.stage = 'Basic-4';
metrics.inverter1_only = true;
metrics.S1_closed = true;
metrics.S2_open = true;
metrics.physical_load_disconnect_at_0A = true;
metrics.current_targets_A = IloadTarget;
metrics.load_resistances_Ohm = Rload;
metrics.Uo_rms_V = UoRms;
metrics.measured_load_current_rms_A = IloadRms;
metrics.frequency_Hz = frequencyHz;
metrics.no_load_voltage_V = UoRms(1);
metrics.Uo_2A_V = UoRms(end);
metrics.load_regulation_percent = loadRegulationPercent;
metrics.load_regulation_limit_percent = 0.2;
metrics.gate_overlap_samples = gateOverlap;
metrics.measurement_window_s = [0.10,0.299998];
metrics.all_points_finite = allFinite;
metrics.all_points_gate_safe = gateSafe;
metrics.full_load_current_gate_A = 1.8;
metrics.pass = allFinite && gateSafe && IloadRms(end)>=1.8 && ...
    loadRegulationPercent <= metrics.load_regulation_limit_percent;
metrics.regulation_definition = 'abs(Uo_2A-Uo_no_load)/Uo_no_load*100';

save(fullfile(resultsDir,'basic4_load_regulation.mat'),'metrics','IloadTarget', ...
    'Rload','UoRms','IloadRms','frequencyHz','gateOverlap');

jsonFile = fullfile(resultsDir,'basic4_load_regulation.json');
fid = fopen(jsonFile,'w');
assert(fid >= 0,'Could not create Basic-4 JSON result.');
fwrite(fid,jsonencode(metrics,'PrettyPrint',true),'char');
fclose(fid);

fig = figure('Visible','off','Color','w');
plot(IloadRms,UoRms,'o-','LineWidth',1.5,'MarkerSize',7);
grid on;
xlabel('Measured load current (A RMS)');
ylabel('Output voltage (V RMS)');
title(sprintf('Basic-4 load regulation: %.4f%%',loadRegulationPercent));
exportgraphics(fig,fullfile(resultsDir,'basic4_load_regulation.png'),'Resolution',200);
close(fig);
if isfile(progressFile)
    delete(progressFile);
end

fprintf('BASIC4_RESULT Uo_no_load=%.6f Vrms, Uo_2A=%.6f Vrms, Io_2A=%.6f Arms, regulation=%.6f%%, PASS=%d\n', ...
    UoRms(1),UoRms(end),IloadRms(end),loadRegulationPercent,metrics.pass);
assert(metrics.pass,'Basic-4 failed; stop the sequential validation here.');

function [UoRms,IloadRms,frequencyHz,overlap] = measurePoint(out)
U = out.get('TP_Uo');
I = out.get('TP_load_current');
tU = double(U.Time(:));
u = double(squeeze(U.Data));
u = u(:);
tI = double(I.Time(:));
i = double(squeeze(I.Data));
i = i(:);
tEnd = floor(min(tU(end),tI(end))*1e6)/1e6;
t = (0.10:1e-6:tEnd)';
uGrid = interp1(tU,u,t,'linear');
iGrid = interp1(tI,i,t,'linear');
assert(all(isfinite([uGrid;iGrid])),'Basic-4 output/load-current log is incomplete.');
UoRms = sqrt(mean(uGrid.^2));
IloadRms = sqrt(mean(iGrid.^2));
frequencyHz = fminbnd(@(f) sinFitResidual(uGrid,t,f),49,51);

gateTime = double(out.get('Inv1_gate1').Time(:));
inv1Gates = false(numel(gateTime),4);
inv2Gates = false(numel(gateTime),4);
for k = 1:4
    sig1 = out.get(sprintf('Inv1_gate%d',k));
    sig2 = out.get(sprintf('Inv2_gate%d',k));
    inv1Gates(:,k) = interp1(double(sig1.Time(:)),double(squeeze(sig1.Data)),gateTime,'previous','extrap') > 0.5;
    inv2Gates(:,k) = interp1(double(sig2.Time(:)),double(squeeze(sig2.Data)),gateTime,'previous','extrap') > 0.5;
end
overlap = [nnz(inv1Gates(:,1)&inv1Gates(:,2)),nnz(inv1Gates(:,3)&inv1Gates(:,4)), ...
    nnz(inv2Gates(:,1)&inv2Gates(:,2)),nnz(inv2Gates(:,3)&inv2Gates(:,4))];
end

function e = sinFitResidual(x,t,f)
x = double(x(:));
t = double(t(:));
X = [ones(size(t)),cos(2*pi*f*t),sin(2*pi*f*t)];
c = X\x;
r = x-X*c;
e = mean(r.^2);
end
