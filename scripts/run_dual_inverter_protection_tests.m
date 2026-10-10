%% Physical switching fault-injection tests for the protection supervisors
projectRoot = fileparts(fileparts(mfilename('fullpath')));
modelName = 'dual_single_phase_parallel_inverter_r2024a';
modelFile = fullfile(projectRoot,'models',[modelName '.slx']);
resultsDir = fullfile(projectRoot,'results');
if ~exist(resultsDir,'dir')
    mkdir(resultsDir);
end
assert(isfile(modelFile),'Dual-inverter model is missing: %s',modelFile);
assert(bdIsLoaded(modelName),'Open the saved dual-inverter model first.');

cases = struct( ...
    'name',{'dc_undervoltage','overcurrent_trip','reference_limit', ...
    'grid_voltage_out_of_range','grid_frequency_out_of_range'}, ...
    'stopTime',{0.05,0.12,0.08,0.12,0.12}, ...
    'inv1Enable',{1,1,1,1,1},'inv2Enable',{0,0,1,1,1}, ...
    's1',{1,1,0,0,0},'sLoad',{1,1,0,0,0},'s2',{0,0,1,1,1}, ...
    'gridMode',{0,0,1,1,1},'loadR',{12,4,12,12,12}, ...
    'vdc1',{32,48,48,48,48},'gridAmp',{'','','','110*sqrt(2)',''}, ...
    'gridFrequency',{'','','','','55'},'currentSet',{2,2,4.5,2,2}, ...
    'ratioSet',{1,1,2,1,1});

progressFile = fullfile(resultsDir,'protection_fault_tests_progress.mat');
if isfile(progressFile)
    saved = load(progressFile,'records','nextIndex','caseNames');
    caseNames = {cases.name};
    assert(isequal(saved.caseNames,caseNames), ...
        'Protection-test checkpoint belongs to a different test matrix.');
    records = saved.records;
    nextIndex = saved.nextIndex;
else
    caseNames = {cases.name};
    records = repmat(struct('name','','metrics',[],'trace',[]),1,numel(cases));
    nextIndex = 1;
end

blockPath = @(sid) Simulink.ID.getFullName([modelName ':' sid]);
logBlocks = find_system(modelName,'BlockType','ToWorkspace');
for caseIndex = nextIndex:numel(cases)
    c = cases(caseIndex);
    in = Simulink.SimulationInput(modelName);
    in = in.setBlockParameter(blockPath('254'),'Value',num2str(c.inv1Enable));
    in = in.setBlockParameter(blockPath('259'),'Value',num2str(c.inv2Enable));
    in = in.setBlockParameter(blockPath('270'),'Value',num2str(c.s1));
    in = in.setBlockParameter(blockPath('271'),'Value',num2str(c.sLoad));
    in = in.setBlockParameter(blockPath('272'),'Value',num2str(c.s2));
    in = in.setBlockParameter(blockPath('269'),'r',num2str(c.loadR,16));
    in = in.setBlockParameter(blockPath('424'),'Value',num2str(c.gridMode));
    in = in.setBlockParameter(blockPath('425'),'Value',num2str(c.currentSet,16));
    in = in.setBlockParameter(blockPath('426'),'Value',num2str(c.ratioSet,16));
    if c.vdc1~=48
        in = in.setBlockParameter(blockPath('46'),'v0',num2str(c.vdc1,16));
    end
    if ~isempty(c.gridAmp)
        in = in.setBlockParameter(blockPath('293'),'amp',c.gridAmp);
    end
    if ~isempty(c.gridFrequency)
        in = in.setBlockParameter(blockPath('293'),'frequency',c.gridFrequency);
    end
    in = in.setModelParameter('StopTime',num2str(c.stopTime,16));
    for logIndex = 1:numel(logBlocks)
        variableName = get_param(logBlocks{logIndex},'VariableName');
        if startsWith(variableName,{'Inv1_gate','Inv2_gate', ...
                'Protect1_','Protect2_','PLL1_lock','PLL2_lock', ...
                'PLL1_i_ref_A','PLL2_i_ref_A','TP_Io1','TP_Io2'})
            decimation = '1';
        else
            decimation = '20';
        end
        in = in.setBlockParameter(logBlocks{logIndex},'Decimation',decimation);
    end

    fprintf('PROTECTION_TEST_START %d/%d %s\n',caseIndex,numel(cases),c.name);
    out = sim(in);
    metrics = analyzeProtectionCase(out,c);
    fprintf(['PROTECTION_TEST_RESULT %s Vdc1=%.3f V I1_peak=%.3f A, ' ...
        'permit1=%.0f trip1=%.0f pllLock=%.3f/%.3f limitedRefs=%.3f/%.3f PASS=%d\n'], ...
        c.name,metrics.Vdc1_mean_V,metrics.Io1_peak_abs_A, ...
        metrics.Protect1_GatePermit_final,metrics.Protect1_OC_Trip_final, ...
        metrics.PLL1_lock_fraction,metrics.PLL2_lock_fraction, ...
        metrics.Protect1_Iref_Limited_A,metrics.Protect2_Iref_Limited_A,metrics.pass);
    traceNames = {'Vdc','TP_Io1','TP_Io2','Protect1_GatePermit', ...
        'Protect2_GatePermit','Protect1_Vdc_OK','Protect2_Vdc_OK', ...
        'Protect1_OC_Trip','Protect2_OC_Trip','Protect1_Iref_Limited', ...
        'Protect2_Iref_Limited','PLL1_lock','PLL2_lock','PLL1_i_ref_A', ...
        'PLL2_i_ref_A','Inv1_gate1','Inv1_gate2','Inv1_gate3','Inv1_gate4', ...
        'Inv2_gate1','Inv2_gate2','Inv2_gate3','Inv2_gate4'};
    trace = struct();
    for signalIndex = 1:numel(traceNames)
        trace.(traceNames{signalIndex}) = getTrace(out,traceNames{signalIndex});
    end
    records(caseIndex) = struct('name',c.name,'metrics',metrics,'trace',trace);
    nextIndex = caseIndex+1;
    save(progressFile,'records','nextIndex','caseNames','-v7.3');
    clear out in
end

allPass = all(arrayfun(@(r)r.metrics.pass,records));
summary = struct('case_names',{caseNames},'all_cases_pass',allPass, ...
    'dc_undervoltage_blocks_gate',records(1).metrics.pass, ...
    'overcurrent_trip_latches',records(2).metrics.pass, ...
    'reference_limits_to_2A_per_inverter',records(3).metrics.pass, ...
    'grid_voltage_out_of_range_suppresses_current',records(4).metrics.pass, ...
    'grid_frequency_out_of_range_suppresses_current',records(5).metrics.pass, ...
    'undervoltage_threshold_V',40,'overcurrent_threshold_A',4, ...
    'current_reference_limits_A',[0 2]);
save(fullfile(resultsDir,'protection_fault_tests.mat'),'records','summary','-v7.3');
fid = fopen(fullfile(resultsDir,'protection_fault_tests.json'),'w');
assert(fid>=0,'Could not create protection-test JSON.');
fwrite(fid,jsonencode(summary,'PrettyPrint',true),'char');
fclose(fid);
if isfile(progressFile)
    delete(progressFile);
end
assert(allPass,'One or more physical protection fault-injection tests failed.');

function metrics = analyzeProtectionCase(out,c)
metrics = struct();
metrics.name = c.name;
metrics.stop_event = out.SimulationMetadata.ExecutionInfo.StopEvent;
metrics.stop_time_reached = strcmp(metrics.stop_event,'ReachedStopTime');
metrics.Vdc1_mean_V = mean(double(out.get('Vdc').Data(:)));
metrics.Io1_peak_abs_A = max(abs(double(out.get('TP_Io1').Data(:))));
metrics.Io2_peak_abs_A = max(abs(double(out.get('TP_Io2').Data(:))));
metrics.Protect1_GatePermit_final = double(out.get('Protect1_GatePermit').Data(end));
metrics.Protect2_GatePermit_final = double(out.get('Protect2_GatePermit').Data(end));
metrics.Protect1_Vdc_OK_final = double(out.get('Protect1_Vdc_OK').Data(end));
metrics.Protect2_Vdc_OK_final = double(out.get('Protect2_Vdc_OK').Data(end));
metrics.Protect1_OC_Trip_final = double(out.get('Protect1_OC_Trip').Data(end));
metrics.Protect2_OC_Trip_final = double(out.get('Protect2_OC_Trip').Data(end));
metrics.Protect1_Iref_Limited_A = double(out.get('Protect1_Iref_Limited').Data(end));
metrics.Protect2_Iref_Limited_A = double(out.get('Protect2_Iref_Limited').Data(end));
metrics.PLL1_lock_fraction = mean(double(out.get('PLL1_lock').Data(:))>0.5);
metrics.PLL2_lock_fraction = mean(double(out.get('PLL2_lock').Data(:))>0.5);
metrics.PLL1_reference_peak_A = max(abs(double(out.get('PLL1_i_ref_A').Data(:))));
metrics.PLL2_reference_peak_A = max(abs(double(out.get('PLL2_i_ref_A').Data(:))));
metrics.all_signals_finite = all(isfinite([metrics.Vdc1_mean_V, ...
    metrics.Io1_peak_abs_A,metrics.Io2_peak_abs_A, ...
    metrics.Protect1_GatePermit_final,metrics.Protect2_GatePermit_final, ...
    metrics.Protect1_Vdc_OK_final,metrics.Protect2_Vdc_OK_final, ...
    metrics.Protect1_OC_Trip_final,metrics.Protect2_OC_Trip_final, ...
    metrics.Protect1_Iref_Limited_A,metrics.Protect2_Iref_Limited_A, ...
    metrics.PLL1_lock_fraction,metrics.PLL2_lock_fraction, ...
    metrics.PLL1_reference_peak_A,metrics.PLL2_reference_peak_A]));

switch c.name
    case 'dc_undervoltage'
        metrics.pass = metrics.stop_time_reached && metrics.all_signals_finite && ...
            abs(metrics.Vdc1_mean_V-32)<0.5 && ...
            metrics.Protect1_Vdc_OK_final<0.5 && ...
            metrics.Protect1_GatePermit_final<0.5 && ...
            metrics.Protect1_OC_Trip_final<0.5;
    case 'overcurrent_trip'
        metrics.pass = metrics.stop_time_reached && metrics.all_signals_finite && ...
            metrics.Io1_peak_abs_A>4 && ...
            metrics.Protect1_OC_Trip_final>0.5 && ...
            metrics.Protect1_GatePermit_final<0.5;
    case 'reference_limit'
        metrics.pass = metrics.stop_time_reached && metrics.all_signals_finite && ...
            abs(metrics.Protect1_Iref_Limited_A-2)<1e-9 && ...
            abs(metrics.Protect2_Iref_Limited_A-1.5)<1e-9 && ...
            metrics.Protect1_Vdc_OK_final>0.5 && ...
            metrics.Protect2_Vdc_OK_final>0.5;
    case 'grid_voltage_out_of_range'
        metrics.pass = metrics.stop_time_reached && metrics.all_signals_finite && ...
            metrics.PLL1_lock_fraction<0.99 && metrics.PLL2_lock_fraction<0.99 && ...
            metrics.PLL1_reference_peak_A<0.05 && metrics.PLL2_reference_peak_A<0.05;
    case 'grid_frequency_out_of_range'
        metrics.pass = metrics.stop_time_reached && metrics.all_signals_finite && ...
            metrics.PLL1_lock_fraction<0.99 && metrics.PLL2_lock_fraction<0.99 && ...
            metrics.PLL1_reference_peak_A<0.05 && metrics.PLL2_reference_peak_A<0.05;
    otherwise
        error('Unknown protection-test case: %s',c.name);
end
end

function trace = getTrace(out,name)
signal = out.get(name);
trace = struct('time_s',double(signal.Time(:)), ...
    'data',double(squeeze(signal.Data)));
trace.data = trace.data(:);
end
