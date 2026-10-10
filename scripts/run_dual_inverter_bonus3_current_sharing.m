%% Bonus-3: digital total-current and current-ratio sweep
projectRoot = fileparts(fileparts(mfilename('fullpath')));
modelName = 'dual_single_phase_parallel_inverter_r2024a';
modelFile = fullfile(projectRoot,'models',[modelName '.slx']);
resultsDir = fullfile(projectRoot,'results');
if ~exist(resultsDir,'dir')
    mkdir(resultsDir);
end
assert(isfile(modelFile),'Dual-inverter model is missing: %s',modelFile);
assert(bdIsLoaded(modelName),'Open the saved model before running Bonus-3.');

totalSetpoints = [1 2 3];
ratioSetpoints = [0.5 0.75 1.0 1.5 2.0];
cases = zeros(numel(totalSetpoints)*numel(ratioSetpoints),2);
caseIndex = 0;
for totalIndex = 1:numel(totalSetpoints)
    for ratioIndex = 1:numel(ratioSetpoints)
        caseIndex = caseIndex+1;
        cases(caseIndex,:) = [totalSetpoints(totalIndex),ratioSetpoints(ratioIndex)];
    end
end

modelInfo = dir(modelFile);
modelStamp = [modelInfo.bytes modelInfo.datenum];
progressFile = fullfile(resultsDir,'bonus3_current_sharing_progress.mat');
if isfile(progressFile)
    saved = load(progressFile,'records','nextIndex','modelStamp','cases');
    assert(isequal(saved.modelStamp,modelStamp) && isequal(saved.cases,cases), ...
        'Bonus-3 checkpoint belongs to a different model or case matrix.');
    records = saved.records;
    nextIndex = saved.nextIndex;
else
    records = repmat(struct('Io_total_set_A',NaN,'K_set',NaN, ...
        'metrics',[],'trace',[]),1,size(cases,1));
    nextIndex = 1;
end

blockPath = @(sid) Simulink.ID.getFullName([modelName ':' sid]);
logBlocks = find_system(modelName,'BlockType','ToWorkspace');
runIdsBefore = Simulink.sdi.getAllRunIDs;
for pointIndex = nextIndex:size(cases,1)
    Iset = cases(pointIndex,1);
    Kset = cases(pointIndex,2);
    in = Simulink.SimulationInput(modelName);
    in = in.setBlockParameter(blockPath('254'),'Value','1');
    in = in.setBlockParameter(blockPath('259'),'Value','1');
    in = in.setBlockParameter(blockPath('270'),'Value','0'); % S1 open
    in = in.setBlockParameter(blockPath('271'),'Value','0'); % load disconnect open
    in = in.setBlockParameter(blockPath('272'),'Value','1'); % S2 closed
    in = in.setBlockParameter(blockPath('269'),'r','12');
    in = in.setBlockParameter(blockPath('424'),'Value','1'); % grid mode
    in = in.setBlockParameter(blockPath('425'),'Value',num2str(Iset,16));
    in = in.setBlockParameter(blockPath('426'),'Value',num2str(Kset,16));
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

    fprintf(['BONUS3_POINT_START index=%d/%d Io_total_set=%.2f A, ' ...
        'K_set=%.2f; physical switching simulation...\n'], ...
        pointIndex,size(cases,1),Iset,Kset);
    out = sim(in);
    [pointMetrics,trace] = analyze_dual_inverter_grid_point(out,[0.25 0.45]);
    pointMetrics.Io_total_set_A = Iset;
    pointMetrics.K_set = Kset;
    pointMetrics.total_current_error_abs_A = abs(pointMetrics.Io_total_rms_A-Iset);
    pointMetrics.total_current_error_percent = ...
        pointMetrics.total_current_error_abs_A/Iset*100;
    pointMetrics.total_current_accuracy_pass = ...
        pointMetrics.total_current_error_percent<6;
    pointMetrics.ratio_error_percent = ...
        abs(Kset-pointMetrics.Io1_to_Io2_ratio)/Kset*100;
    pointMetrics.ratio_accuracy_pass = pointMetrics.ratio_error_percent<=5;
    pointMetrics.circulating_current_not_growing = ...
        pointMetrics.circulating_current_last_half_rms_A <= ...
        max(1.25*pointMetrics.circulating_current_first_half_rms_A,0.02);
    pointMetrics.pass = pointMetrics.ratio_accuracy_pass && ...
        pointMetrics.total_current_accuracy_pass && ...
        pointMetrics.both_plls_locked && pointMetrics.currents_bounded && ...
        pointMetrics.circulating_current_not_growing && ...
        pointMetrics.gates_nonoverlap && pointMetrics.all_measured_signals_finite;
    records(pointIndex) = struct('Io_total_set_A',Iset,'K_set',Kset, ...
        'metrics',pointMetrics,'trace',trace);
    fprintf(['BONUS3_POINT_RESULT Io_set=%.2f A, K_set=%.2f, Io1=%.5f A, ' ...
        'Io2=%.5f A, K_measured=%.4f, ratio_error=%.3f%%, ' ...
        'Io_error=%.3f%%, PASS=%d\n'],Iset,Kset, ...
        pointMetrics.Io1_rms_A,pointMetrics.Io2_rms_A, ...
        pointMetrics.Io1_to_Io2_ratio,pointMetrics.ratio_error_percent, ...
        pointMetrics.total_current_error_percent,pointMetrics.pass);
    nextIndex = pointIndex+1;
    save(progressFile,'records','nextIndex','modelStamp','cases','-v7.3');
    clear out in
end

assert(all(arrayfun(@(r)~isempty(r.metrics),records)), ...
    'Bonus-3 checkpoint is missing one or more operating points.');
R = records;
ratioErrors = arrayfun(@(r)r.metrics.ratio_error_percent,R);
currentErrors = arrayfun(@(r)r.metrics.total_current_error_percent,R);
ratioPass = arrayfun(@(r)r.metrics.ratio_accuracy_pass,R);
pointPass = arrayfun(@(r)r.metrics.pass,R);
summary = struct();
summary.total_current_setpoints_A = [R.Io_total_set_A];
summary.K_set = [R.K_set];
summary.Io1_measured_A = arrayfun(@(r)r.metrics.Io1_rms_A,R);
summary.Io2_measured_A = arrayfun(@(r)r.metrics.Io2_rms_A,R);
summary.Io_total_measured_A = arrayfun(@(r)r.metrics.Io_total_rms_A,R);
summary.K_measured = arrayfun(@(r)r.metrics.Io1_to_Io2_ratio,R);
summary.ratio_error_percent = ratioErrors;
summary.total_current_error_percent = currentErrors;
summary.all_ratio_points_le_5_percent = all(ratioErrors<=5);
summary.all_points_PLL_locked = all(arrayfun(@(r)r.metrics.both_plls_locked,R));
summary.all_points_gate_safe = all(arrayfun(@(r)r.metrics.gates_nonoverlap,R));
summary.all_ratio_points_pass = all(ratioPass);
summary.all_points_pass = all(pointPass);
summary.all_total_current_errors_lt_6_percent = all(currentErrors<6);
summary.measurement_window_s = [0.25 0.45];
summary.current_definition = 'TP_Io low-voltage transformer-primary common-bus RMS';
summary.ratio_definition = 'K_measured = Io1_rms / Io2_rms';

save(fullfile(resultsDir,'bonus3_current_sharing.mat'),'R','summary','-v7.3');
fid = fopen(fullfile(resultsDir,'bonus3_ratio_accuracy.json'),'w');
assert(fid>=0,'Could not create Bonus-3 JSON.');
fwrite(fid,jsonencode(summary,'PrettyPrint',true),'char');
fclose(fid);

f = figure('Visible','off'); hold on;
for totalIndex = 1:numel(totalSetpoints)
    selected = [R.Io_total_set_A]==totalSetpoints(totalIndex);
    Ks = [R(selected).K_set];
    Kms = arrayfun(@(r)r.metrics.Io1_to_Io2_ratio,R(selected));
    plot(Ks,Kms,'o-','LineWidth',1.3,'MarkerSize',6, ...
        'DisplayName',sprintf('I_{o,set}=%.0f A',totalSetpoints(totalIndex)));
end
plot(ratioSetpoints,ratioSetpoints,'--k','DisplayName','Ideal ratio');
grid on; xlabel('K_{set}'); ylabel('K_{measured}=I_{o1}/I_{o2}');
title('Bonus-3: Current-Ratio Tracking'); legend('Location','best');
exportgraphics(f,fullfile(resultsDir,'bonus3_ratio_tracking.png'),'Resolution',160);
close(f);

selected = [R.Io_total_set_A]==2;
R2 = R(selected);
f = figure('Visible','off');
plot([R2.K_set],arrayfun(@(r)r.metrics.Io1_rms_A,R2),'o-','LineWidth',1.3); hold on;
plot([R2.K_set],arrayfun(@(r)r.metrics.Io2_rms_A,R2),'s-','LineWidth',1.3);
plot([R2.K_set],arrayfun(@(r)r.Io_total_set_A*r.K_set/(1+r.K_set),R2),'--');
plot([R2.K_set],arrayfun(@(r)r.Io_total_set_A/(1+r.K_set),R2),':');
grid on; xlabel('K_{set}'); ylabel('RMS current (A)');
title('Bonus-3: Reference Allocation and Measured Branch Currents');
legend('Measured I_{o1}','Measured I_{o2}','I_{ref1}','I_{ref2}','Location','best');
exportgraphics(f,fullfile(resultsDir,'bonus3_current_allocation.png'),'Resolution',160);
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
assert(summary.all_ratio_points_le_5_percent, ...
    'Bonus-3 failed: one or more measured current ratios exceed 5%% error.');
fprintf(['BONUS3_SWEEP_RESULT cases=%d, all_ratio_errors_le_5_percent=%d, ' ...
    'all_total_current_errors_lt_6_percent=%d, PASS=%d\n'], ...
    numel(R),summary.all_ratio_points_le_5_percent, ...
    summary.all_total_current_errors_lt_6_percent,summary.all_points_pass);
