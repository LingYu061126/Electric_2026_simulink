%% Bonus-2: digital total grid-current sweep on the physical switching model
projectRoot = fileparts(fileparts(mfilename('fullpath')));
modelName = 'dual_single_phase_parallel_inverter_r2024a';
modelFile = fullfile(projectRoot,'models',[modelName '.slx']);
resultsDir = fullfile(projectRoot,'results');
if ~exist(resultsDir,'dir')
    mkdir(resultsDir);
end
assert(isfile(modelFile),'Dual-inverter model is missing: %s',modelFile);
assert(bdIsLoaded(modelName),'Open the saved model before running Bonus-2.');

setpoints = [2.0 2.5 3.0 3.5 4.0];
modelInfo = dir(modelFile);
modelStamp = [modelInfo.bytes modelInfo.datenum];
progressFile = fullfile(resultsDir,'bonus2_grid_current_progress.mat');
if isfile(progressFile)
    saved = load(progressFile,'records','nextIndex','modelStamp');
    assert(isequal(saved.modelStamp,modelStamp), ...
        'Bonus-2 checkpoint belongs to a different saved model.');
    records = saved.records;
    nextIndex = saved.nextIndex;
else
    records = repmat(struct('setpoint_A',NaN,'metrics',[],'trace',[]), ...
        1,numel(setpoints));
    nextIndex = 1;
end

blockPath = @(sid) Simulink.ID.getFullName([modelName ':' sid]);
logBlocks = find_system(modelName,'BlockType','ToWorkspace');

runIdsBefore = Simulink.sdi.getAllRunIDs;
for pointIndex = nextIndex:numel(setpoints)
    Iset = setpoints(pointIndex);
    in = Simulink.SimulationInput(modelName);
    in = in.setBlockParameter(blockPath('254'),'Value','1');
    in = in.setBlockParameter(blockPath('259'),'Value','1');
    in = in.setBlockParameter(blockPath('270'),'Value','0'); % S1 open
    in = in.setBlockParameter(blockPath('271'),'Value','0'); % load disconnect open
    in = in.setBlockParameter(blockPath('272'),'Value','1'); % S2 closed
    in = in.setBlockParameter(blockPath('269'),'r','12');
    in = in.setBlockParameter(blockPath('424'),'Value','1'); % grid mode
    in = in.setBlockParameter(blockPath('425'),'Value',num2str(Iset,16));
    in = in.setBlockParameter(blockPath('426'),'Value','1'); % equal split
    in = in.setModelParameter('StopTime','0.45');
    for logIndex = 1:numel(logBlocks)
        variableName = get_param(logBlocks{logIndex},'VariableName');
        if startsWith(variableName,{'Inv1_gate','Inv2_gate'})
            decimation = '1';
        elseif startsWith(variableName,{'TP_grid_voltage_LV','TP_Io', ...
                'TP_grid_secondary_current','TP_grid_voltage_220V','PLL1_', ...
                'PLL2_'})
            decimation = '1';
        else
            decimation = '20';
        end
        in = in.setBlockParameter(logBlocks{logIndex},'Decimation',decimation);
    end

    fprintf('BONUS2_POINT_START index=%d Io_set=%.2f A; physical switching simulation...\n', ...
        pointIndex,Iset);
    out = sim(in);
    window = [0.25 0.45];
    [pointMetrics,trace] = analyze_dual_inverter_grid_point(out,window);
    pointMetrics.Io_total_set_A = Iset;
    pointMetrics.current_error_abs_A = abs(pointMetrics.Io_total_rms_A-Iset);
    pointMetrics.current_error_percent = ...
        pointMetrics.current_error_abs_A/Iset*100;
    pointMetrics.current_accuracy_pass = pointMetrics.current_error_percent<6;
    pointMetrics.pass = pointMetrics.current_accuracy_pass && ...
        pointMetrics.both_plls_locked && pointMetrics.currents_bounded && ...
        pointMetrics.gates_nonoverlap && pointMetrics.all_measured_signals_finite;
    records(pointIndex) = struct('setpoint_A',Iset, ...
        'metrics',pointMetrics,'trace',trace);
    fprintf(['BONUS2_POINT_RESULT Io_set=%.2f A, Io_measured=%.5f A, ' ...
        'error=%.3f%%, PLL locks=%.3f/%.3f, gate-safe=%d, PASS=%d\n'], ...
        Iset,pointMetrics.Io_total_rms_A,pointMetrics.current_error_percent, ...
        pointMetrics.PLL1_lock_fraction,pointMetrics.PLL2_lock_fraction, ...
        pointMetrics.gates_nonoverlap,pointMetrics.pass);
    nextIndex = pointIndex+1;
    save(progressFile,'records','nextIndex','modelStamp','-v7.3');
    clear out in
end

assert(all(arrayfun(@(r)~isempty(r.metrics),records)), ...
    'Bonus-2 sweep checkpoint is missing one or more setpoints.');
measured = arrayfun(@(r)r.metrics.Io_total_rms_A,records);
errors = arrayfun(@(r)r.metrics.current_error_percent,records);
pointPass = arrayfun(@(r)r.metrics.pass,records);
summary = struct();
summary.setpoints_A = setpoints;
summary.measured_total_current_A = measured;
summary.error_percent = errors;
summary.all_points_lt_6_percent = all(errors<6);
summary.all_points_PLL_locked = all(arrayfun(@(r)r.metrics.both_plls_locked,records));
summary.all_points_gate_safe = all(arrayfun(@(r)r.metrics.gates_nonoverlap,records));
summary.all_points_pass = all(pointPass);
summary.measurement_window_s = [0.25 0.45];
summary.mode = 'two independent PLLs and current PR controllers';
summary.current_definition = 'TP_Io low-voltage transformer-primary common-bus RMS';

save(fullfile(resultsDir,'bonus2_grid_current_sweep.mat'), ...
    'records','summary','-v7.3');
fid = fopen(fullfile(resultsDir,'bonus2_current_accuracy.json'),'w');
assert(fid>=0,'Could not create Bonus-2 JSON.');
fwrite(fid,jsonencode(summary,'PrettyPrint',true),'char');
fclose(fid);

f = figure('Visible','off');
plot(setpoints,measured,'o-','LineWidth',1.5,'MarkerSize',7); hold on;
plot(setpoints,setpoints,'--k','LineWidth',1.0);
grid on; xlabel('I_{o,set} (A RMS)'); ylabel('I_{o,measured} (A RMS)');
title('Bonus-2: Grid Current Setpoint Tracking');
legend('Switching simulation','Ideal tracking','Location','best');
exportgraphics(f,fullfile(resultsDir,'bonus2_current_setpoint_tracking.png'),'Resolution',160);
close(f);

lastTrace = records(end).trace;
f = figure('Visible','off');
yyaxis left; plot(lastTrace.time_s,lastTrace.grid_primary_voltage_V,'LineWidth',1.0);
ylabel('LV primary voltage (V)');
yyaxis right; plot(lastTrace.time_s,lastTrace.Io_primary_A,'LineWidth',1.0);
ylabel('I_o primary current (A)');
grid on; xlabel('Time (s)'); title('Bonus-2: 4 A Setpoint Grid Waveforms');
exportgraphics(f,fullfile(resultsDir,'bonus2_grid_voltage_current.png'),'Resolution',160);
close(f);

f = figure('Visible','off');
subplot(2,1,1);
stairs(records(end).trace.PLL1_lock.time_s,records(end).trace.PLL1_lock.data,'LineWidth',1.0);
hold on; stairs(records(end).trace.PLL2_lock.time_s,records(end).trace.PLL2_lock.data,'LineWidth',1.0);
ylim([-0.1 1.1]); grid on; ylabel('Lock'); legend('PLL 1','PLL 2','Location','best');
title('Bonus-2: Independent PLL Lock Flags');
subplot(2,1,2);
plot(records(end).trace.PLL1_frequency.time_s,records(end).trace.PLL1_frequency.data,'LineWidth',1.0);
hold on; plot(records(end).trace.PLL2_frequency.time_s,records(end).trace.PLL2_frequency.data,'LineWidth',1.0);
yline(50,'--k'); grid on; xlabel('Time (s)'); ylabel('Frequency (Hz)');
legend('PLL 1','PLL 2','50 Hz reference','Location','best');
exportgraphics(f,fullfile(resultsDir,'bonus2_pll_lock.png'),'Resolution',160);
close(f);

runIdsAfter = Simulink.sdi.getAllRunIDs;
newRunIds = setdiff(runIdsAfter,runIdsBefore);
for k = 1:numel(newRunIds)
    run = Simulink.sdi.getRun(newRunIds(k));
    if strcmp(run.Model,modelName)
        Simulink.sdi.deleteRun(newRunIds(k));
    end
end
if isfile(progressFile)
    delete(progressFile);
end
assert(summary.all_points_lt_6_percent, ...
    'Bonus-2 failed: one or more measured current errors are >= 6%%.');
assert(summary.all_points_PLL_locked && summary.all_points_gate_safe, ...
    'Bonus-2 failed a PLL-lock or gate-safety check.');
fprintf('BONUS2_SWEEP_RESULT points=%d, all_current_errors_lt_6_percent=%d, PASS=%d\n', ...
    numel(setpoints),summary.all_points_lt_6_percent,summary.all_points_pass);
