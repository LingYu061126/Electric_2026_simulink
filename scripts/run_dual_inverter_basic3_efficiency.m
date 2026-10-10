%% Basic-3: efficiency and auxiliary-power sensitivity at the rated point
projectRoot = fileparts(fileparts(mfilename('fullpath')));
modelName = 'dual_single_phase_parallel_inverter_r2024a';
modelFile = fullfile(projectRoot,'models',[modelName '.slx']);
resultsDir = fullfile(projectRoot,'results');
basic1File = fullfile(resultsDir,'basic1_single_inverter.mat');
assert(isfile(modelFile),'Dual-inverter model is missing: %s',modelFile);
assert(isfile(basic1File),'Run Basic-1 before Basic-3.');
assert(bdIsLoaded(modelName),'Open the saved model before running this stage.');

basic1 = load(basic1File,'metrics');
assert(basic1.metrics.pass,'Basic-1 did not pass; stop before Basic-3.');
pauxAssumed = [0,0.5,1,2];
progressFile = fullfile(resultsDir,'basic3_efficiency_progress.mat');
modelInfo = dir(modelFile);
modelStamp = modelInfo.datenum;
completed = false(size(pauxAssumed));
if isfile(progressFile)
    progress = load(progressFile);
    if isequal(progress.pauxAssumed,pauxAssumed) && ...
            progress.modelStamp == modelStamp
        Pout1 = progress.Pout1;
        Pdc1 = progress.Pdc1;
        etaPercent = progress.etaPercent;
        completed = progress.completed;
    else
        Pout1 = nan(size(pauxAssumed));
        Pdc1 = nan(size(pauxAssumed));
        etaPercent = nan(size(pauxAssumed));
    end
else
    Pout1 = nan(size(pauxAssumed));
    Pdc1 = nan(size(pauxAssumed));
    etaPercent = nan(size(pauxAssumed));
end

% The rated 1 W point reuses the just-validated switching run. The other
% three sensitivity points are simulated with a physical auxiliary resistor.
for k = 1:numel(pauxAssumed)
    if completed(k)
        continue;
    end
    if pauxAssumed(k) == 1
        Pout1(k) = basic1.metrics.Pout1_W;
        Pdc1(k) = basic1.metrics.Pdc1_W;
    else
        in = Simulink.SimulationInput(modelName);
        blockPath = @(sid) Simulink.ID.getFullName([modelName ':' sid]);
        in = in.setVariable('Paux1_W',pauxAssumed(k),'Workspace',modelName);
        in = in.setBlockParameter(blockPath('254'),'Value','1');
        in = in.setBlockParameter(blockPath('259'),'Value','0');
        in = in.setBlockParameter(blockPath('270'),'Value','1');
        in = in.setBlockParameter(blockPath('271'),'Value','1');
        in = in.setBlockParameter(blockPath('272'),'Value','0');
        in = in.setBlockParameter(blockPath('269'),'r','12');
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
        fprintf('Running Basic-3 physical switching simulation with Paux1=%.1f W...\n',pauxAssumed(k));
        out = sim(in);
        [Pout1(k),Pdc1(k)] = measurePowers(out);
        runIdsAfter = Simulink.sdi.getAllRunIDs;
        newRunIds = setdiff(runIdsAfter,runIdsBefore);
        for j = 1:numel(newRunIds)
            run = Simulink.sdi.getRun(newRunIds(j));
            if strcmp(run.Model,modelName)
                Simulink.sdi.deleteRun(newRunIds(j));
            end
        end
        clear out
    end
    etaPercent(k) = 100*Pout1(k)/Pdc1(k);
    completed(k) = true;
    save(progressFile,'pauxAssumed','Pout1','Pdc1','etaPercent', ...
        'completed','modelStamp');
    fprintf('BASIC3_POINT_COMPLETE Paux1=%.1f W, Pout1=%.6f W, Pdc1=%.6f W, eta=%.6f%%\n', ...
        pauxAssumed(k),Pout1(k),Pdc1(k),etaPercent(k));
end

passByPoint = isfinite(etaPercent) & etaPercent >= 88;
cases = struct('Paux1_assumed_W',num2cell(pauxAssumed), ...
    'Pout1_W',num2cell(Pout1),'Pdc1_W',num2cell(Pdc1), ...
    'efficiency_percent',num2cell(etaPercent),'pass',num2cell(passByPoint));
sensitivity = struct();
sensitivity.stage = 'Basic-3 auxiliary-power sensitivity';
sensitivity.auxiliary_power_values_W = pauxAssumed;
sensitivity.cases = cases;
sensitivity.all_points_eta_at_least_88_percent = all(passByPoint);
sensitivity.power_definition = 'Pout1=mean(Uo*Io1); Pdc1=mean(Vdc1*Idc1)';
sensitivity.measurement_window_s = [0.10,0.299998];
sensitivity.switching_model = true;

jsonFile = fullfile(resultsDir,'basic3_efficiency_sensitivity.json');
fid = fopen(jsonFile,'w');
assert(fid >= 0,'Could not create Basic-3 sensitivity JSON result.');
fwrite(fid,jsonencode(sensitivity,'PrettyPrint',true),'char');
fclose(fid);

idx1W = find(pauxAssumed == 1,1);
metrics = struct();
metrics.stage = 'Basic-3';
metrics.Pout1_W = Pout1(idx1W);
metrics.Pdc1_W = Pdc1(idx1W);
metrics.Paux1_assumed_W = 1.0;
metrics.efficiency_percent = etaPercent(idx1W);
metrics.definition = 'eta=mean(Uo*Io1)/mean(Vdc1*Idc1)*100';
metrics.auxiliary_power_included_in_dc_measurement = true;
metrics.auxiliary_power_is_hardware_assumption = true;
metrics.loss_model = 'MOSFET Rds, inductor winding resistance, capacitor ESR, output isolation switch resistance, and physical auxiliary resistor';
metrics.switching_transition_losses_modeled = false;
metrics.sensitivity_results_file = 'basic3_efficiency_sensitivity.json';
metrics.pass = passByPoint(idx1W);
fid = fopen(fullfile(resultsDir,'basic3_efficiency.json'),'w');
assert(fid >= 0,'Could not create Basic-3 JSON result.');
fwrite(fid,jsonencode(metrics,'PrettyPrint',true),'char');
fclose(fid);

fig = figure('Visible','off','Color','w');
plot(pauxAssumed,etaPercent,'o-','LineWidth',1.5,'MarkerSize',7);
hold on;
yline(88,'--r','88% requirement');
grid on;
xlabel('Assumed Inverter 1 auxiliary power (W)');
ylabel('Inverter 1 efficiency (%)');
title('Basic-3 efficiency and auxiliary-power sensitivity');
exportgraphics(fig,fullfile(resultsDir,'basic3_power_efficiency.png'),'Resolution',200);
close(fig);
if isfile(progressFile)
    delete(progressFile);
end

fprintf('BASIC3_RESULT Pout1=%.5f W, Pdc1=%.5f W, Paux1 assumption=1.0 W, eta=%.4f%%, sensitivity all pass=%d, PASS=%d\n', ...
    metrics.Pout1_W,metrics.Pdc1_W,metrics.efficiency_percent, ...
    sensitivity.all_points_eta_at_least_88_percent,metrics.pass);
assert(metrics.pass,'Basic-3 failed; stop the sequential validation here.');

function [Pout1,Pdc1] = measurePowers(out)
vOut = out.get('vOut');
Io1 = out.get('TP_Io1');
Vdc1 = out.get('Vdc');
Idc1 = out.get('iDC');
tV = double(vOut.Time(:));
v = double(squeeze(vOut.Data));
v = v(:);
tIo = double(Io1.Time(:));
io = double(squeeze(Io1.Data));
io = io(:);
tDcV = double(Vdc1.Time(:));
vdc = double(squeeze(Vdc1.Data));
tDcI = double(Idc1.Time(:));
idc = double(squeeze(Idc1.Data));
tEnd = min([tV(end),tIo(end),tDcV(end),tDcI(end)]);
tEnd = floor(tEnd*1e6)/1e6;
t = (0.10:1e-6:tEnd)';
vGrid = interp1(tV,v,t,'linear');
iGrid = interp1(tIo,io,t,'linear');
vdcGrid = interp1(tDcV,vdc(:),t,'linear');
idcGrid = interp1(tDcI,idc(:),t,'linear');
assert(all(isfinite([vGrid;iGrid;vdcGrid;idcGrid])), ...
    'Basic-3 signals contain nonfinite or out-of-range samples.');
Pout1 = mean(vGrid.*iGrid);
Pdc1 = mean(vdcGrid.*idcGrid);
assert(Pout1 > 0 && Pdc1 > 0,'Basic-3 power polarity or measurement is invalid.');
end
