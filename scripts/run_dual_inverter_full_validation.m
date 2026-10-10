%% Sequential end-to-end validation for the dual single-phase inverter model
projectRoot = fileparts(fileparts(mfilename('fullpath')));
modelName = 'dual_single_phase_parallel_inverter_r2024a';
modelFile = fullfile(projectRoot,'models',[modelName '.slx']);
scriptsDir = fullfile(projectRoot,'scripts');
resultsDir = fullfile(projectRoot,'results');
reportFile = fullfile(projectRoot,'docs','dual_inverter_final_validation.md');
if ~exist(resultsDir,'dir')
    mkdir(resultsDir);
end
assert(isfile(modelFile),'Dual-inverter model is missing: %s',modelFile);
assert(bdIsLoaded(modelName),'Open the saved model before final validation.');
assert(strcmp(get_param(modelName,'Dirty'),'off'), ...
    'Save the model before running final validation.');

stageNames = {'Basic-1','Basic-2','Basic-3','Basic-4','Bonus-1', ...
    'Bonus-2','Bonus-3','Protection'};
stageScripts = {'run_dual_inverter_basic1_smoke.m', ...
    'run_dual_inverter_basic2_thd.m', ...
    'run_dual_inverter_basic3_efficiency.m', ...
    'run_dual_inverter_basic4_load_regulation.m', ...
    'run_dual_inverter_bonus1_parallel_load.m', ...
    'run_dual_inverter_bonus2_grid_current.m', ...
    'run_dual_inverter_bonus3_current_sharing.m', ...
    'run_dual_inverter_protection_tests.m'};
resultFiles = {'basic1_metrics.json','basic2_thd.json', ...
    'basic3_efficiency.json','basic4_load_regulation.json', ...
    'bonus1_metrics.json','bonus2_current_accuracy.json', ...
    'bonus3_ratio_accuracy.json','protection_fault_tests.json'};
passFields = {'pass','pass','pass','pass','pass','all_points_pass', ...
    'all_points_pass','all_cases_pass'};
modelInfo = dir(modelFile);
modelStamp = [modelInfo.bytes modelInfo.datenum];
progressFile = fullfile(resultsDir,'dual_inverter_full_validation_progress.mat');
if isfile(progressFile)
    saved = load(progressFile,'records','nextIndex','modelStamp','stageNames');
    assert(isequal(saved.modelStamp,modelStamp) && ...
        isequal(saved.stageNames,stageNames), ...
        'Final-validation checkpoint belongs to a different model or stage order.');
    records = saved.records;
    nextIndex = saved.nextIndex;
else
    records = repmat(struct('name','','result_file','','passed',false), ...
        1,numel(stageNames));
    nextIndex = 1;
end

for stageIndex = nextIndex:numel(stageNames)
    stagePath = fullfile(scriptsDir,stageScripts{stageIndex});
    resultPath = fullfile(resultsDir,resultFiles{stageIndex});
    assert(isfile(stagePath),'Missing stage script: %s',stagePath);
    fprintf('\n========== FINAL VALIDATION %d/%d: %s ==========\n', ...
        stageIndex,numel(stageNames),stageNames{stageIndex});
    runStageScript(stagePath);
    assert(isfile(resultPath),'Stage did not create its result JSON: %s',resultPath);
    stageResult = jsondecode(fileread(resultPath));
    assert(isfield(stageResult,passFields{stageIndex}), ...
        'Stage result %s does not contain pass field %s.', ...
        resultFiles{stageIndex},passFields{stageIndex});
    passed = logical(stageResult.(passFields{stageIndex}));
    assert(isscalar(passed) && passed, ...
        'Stage %s did not pass; later stages are not started.',stageNames{stageIndex});
    records(stageIndex) = struct('name',stageNames{stageIndex}, ...
        'result_file',resultFiles{stageIndex},'passed',passed);
    nextIndex = stageIndex+1;
    save(progressFile,'records','nextIndex','modelStamp','stageNames');
end

metrics = collectAllMetrics(resultsDir,modelName);
metrics.stages = records;
metrics.all_stages_pass = all([records.passed]);
metrics.model = modelName;
metrics.matlab_release = version('-release');
metrics.solver = struct('name','ode23t','type','variable-step', ...
    'maximum_step_s',5e-6,'relative_tolerance',1e-4, ...
    'absolute_tolerance','auto');
metrics.design_assumptions = struct('dc_source_voltage_V',48, ...
    'dc_source_voltage_is_assumed',true,'nominal_ac_grid_voltage_V_rms',220, ...
    'nominal_grid_frequency_Hz',50,'rated_single_inverter_load_Ohm',12, ...
    'inverter_output_filter_inductance_H',1e-3, ...
    'filter_capacitance_F',20e-6,'capacitor_damping_resistance_Ohm',10, ...
    'overcurrent_threshold_A_peak',4,'dc_undervoltage_threshold_V',40, ...
    'per_inverter_rms_current_reference_limit_A',[0 2]);
assert(metrics.all_stages_pass,'Final validation contains a failing stage.');

jsonPath = fullfile(resultsDir,'dual_inverter_all_metrics.json');
fid = fopen(jsonPath,'w');
assert(fid>=0,'Could not create aggregate metrics JSON.');
fwrite(fid,jsonencode(metrics,'PrettyPrint',true),'char');
fclose(fid);
writeFinalReport(reportFile,metrics);
if isfile(progressFile)
    delete(progressFile);
end
fprintf('\nDUAL_INVERTER_FINAL_VALIDATION PASS stages=%d; metrics=%s; report=%s\n', ...
    numel(stageNames),jsonPath,reportFile);

function runStageScript(stagePath)
run(stagePath);
end

function allMetrics = collectAllMetrics(resultsDir,modelName)
allMetrics = struct();
allMetrics.basic1 = readJson(resultsDir,'basic1_metrics.json');
allMetrics.basic2 = readJson(resultsDir,'basic2_thd.json');
allMetrics.basic3 = readJson(resultsDir,'basic3_efficiency.json');
allMetrics.basic3_sensitivity = readJson(resultsDir,'basic3_efficiency_sensitivity.json');
allMetrics.basic4 = readJson(resultsDir,'basic4_load_regulation.json');
allMetrics.bonus1 = readJson(resultsDir,'bonus1_metrics.json');
allMetrics.bonus2 = readJson(resultsDir,'bonus2_current_accuracy.json');
allMetrics.bonus3 = readJson(resultsDir,'bonus3_ratio_accuracy.json');
allMetrics.protection = readJson(resultsDir,'protection_fault_tests.json');

bonus2Mat = load(fullfile(resultsDir,'bonus2_grid_current_sweep.mat'),'records');
allMetrics.bonus2_points = [bonus2Mat.records.metrics];
bonus3Mat = load(fullfile(resultsDir,'bonus3_current_sharing.mat'),'R');
allMetrics.bonus3_points = [bonus3Mat.R.metrics];
protectionMat = load(fullfile(resultsDir,'protection_fault_tests.mat'),'records');
allMetrics.protection_cases = [protectionMat.records.metrics];

allMetrics.protection_model = struct('independent_supervisors',true, ...
    'uses_each_inverter_local_dc_voltage_and_current',true, ...
    'latched_overcurrent_trip',true,'gate_and_output_isolator_interlock',true, ...
    'current_reference_saturation_per_inverter_A',[0 2]);
allMetrics.simulation = struct('model',modelName, ...
    'evidence_type','Simscape Electrical physical switching simulations', ...
    'grid_measurement_window_s',[0.25 0.45], ...
    'grid_current_sensor','TP_Io at the transformer low-voltage primary');
end

function value = readJson(resultsDir,fileName)
path = fullfile(resultsDir,fileName);
assert(isfile(path),'Missing final result JSON: %s',path);
value = jsondecode(fileread(path));
end

function writeFinalReport(path,m)
fid = fopen(path,'w');
assert(fid>=0,'Could not create final validation report.');
closer = onCleanup(@()fclose(fid));
fprintf(fid,'# Dual Single-Phase Parallel Inverter — Final Validation\n\n');
fprintf(fid,['All listed results come from R2024a Simscape Electrical physical ' ...
    'switching simulations of the saved model. The final stage order was ' ...
    'Basic-1 through Basic-4, Bonus-1 through Bonus-3, then protection.\n\n']);
fprintf(fid,'Overall result: **%s**\n\n',passText(m.all_stages_pass));
fprintf(fid,'## Model and protection configuration\n\n');
fprintf(fid,'- Two independent full-bridge inverters, separate 48 V DC sources and separate controllers.\n');
fprintf(fid,'- 220 V RMS, 50 Hz grid through the 24:220 V transformer model.\n');
fprintf(fid,'- Each inverter filter: 1 mH series inductance, 20 µF capacitor, 10 Ω damping resistance.\n');
fprintf(fid,'- Solver: %s (%s), max step %.1g s, RelTol %.1g, AbsTol %s.\n', ...
    m.solver.name,m.solver.type,m.solver.maximum_step_s, ...
    m.solver.relative_tolerance,m.solver.absolute_tolerance);
fprintf(fid,['- Protection: 0–2 A RMS branch-reference clamp, 4 A instantaneous ' ...
    'overcurrent latch, and 40 V DC undervoltage interlock. Both gate drive ' ...
    'and the inverter output isolator follow the local permit.\n\n']);

fprintf(fid,'## Basic requirements\n\n');
fprintf(fid,'| Stage | Measured result | Requirement | Result |\n|---|---:|---:|---|\n');
fprintf(fid,'| Basic-1 | %.4f V RMS; %.4f Hz; %.4f A RMS | 24 V ±0.2 V; 50 Hz ±0.2 Hz; ≈2 A (below 1.8 A fails) | %s |\n', ...
    m.basic1.Uo_rms_V,m.basic1.output_frequency_Hz,m.basic1.I_load_rms_A,passText(m.basic1.pass));
fprintf(fid,'| Basic-2 | THD %.4f%% (harmonics 2–50) | ≤2%% | %s |\n', ...
    m.basic2.THD_harmonics_2_to_50_percent,passText(m.basic2.pass));
fprintf(fid,'| Basic-3 | %.4f%% efficiency; Pout %.3f W / Pdc %.3f W | ≥88%% | %s |\n', ...
    m.basic3.efficiency_percent,m.basic3.Pout1_W,m.basic3.Pdc1_W,passText(m.basic3.pass));
fprintf(fid,'| Basic-4 | %.4f%% load regulation, 0–2 A | ≤0.2%% | %s |\n\n', ...
    m.basic4.load_regulation_percent,passText(m.basic4.pass));
fprintf(fid,'Efficiency includes the physical 1 W auxiliary-load assumption. Switching-transition losses are not modeled.\n\n');

fprintf(fid,'## Bonus-1: parallel load operation\n\n');
fprintf(fid,'| Uo | Frequency | Io total | Io1 | Io2 | Sharing imbalance | Result |\n|---:|---:|---:|---:|---:|---:|---|\n');
fprintf(fid,'| %.4f V RMS | %.4f Hz | %.4f A RMS | %.4f A RMS | %.4f A RMS | %.4f%% | %s |\n\n', ...
    m.bonus1.Uo_rms_V,m.bonus1.frequency_Hz,m.bonus1.Io_total_rms_A, ...
    m.bonus1.Io1_rms_A,m.bonus1.Io2_rms_A, ...
    m.bonus1.current_sharing_imbalance_percent,passText(m.bonus1.pass));

fprintf(fid,'## Bonus-2: grid-connected total-current command\n\n');
fprintf(fid,'| Io set | Io measured | Error | PLLs locked | Gates safe | Result |\n|---:|---:|---:|---|---|---|\n');
for k = 1:numel(m.bonus2_points)
    p = m.bonus2_points(k);
    fprintf(fid,'| %.2f A | %.4f A | %.3f%% | %s | %s | %s |\n', ...
        p.Io_total_set_A,p.Io_total_rms_A,p.current_error_percent, ...
        passText(p.both_plls_locked),passText(p.gates_nonoverlap),passText(p.pass));
end
fprintf(fid,'\n');

fprintf(fid,'## Bonus-3: current-ratio command\n\n');
fprintf(fid,'| Io set | K set | Io1 | Io2 | K measured | Ratio error | Circulating current stable | Result |\n|---:|---:|---:|---:|---:|---:|---|---|\n');
for k = 1:numel(m.bonus3_points)
    p = m.bonus3_points(k);
    fprintf(fid,'| %.1f A | %.2f | %.4f A | %.4f A | %.4f | %.3f%% | %s | %s |\n', ...
        p.Io_total_set_A,p.K_set,p.Io1_rms_A,p.Io2_rms_A, ...
        p.Io1_to_Io2_ratio,p.ratio_error_percent, ...
        passText(p.circulating_current_not_growing),passText(p.pass));
end
fprintf(fid,'\n');

fprintf(fid,'## Protection fault injection\n\n');
fprintf(fid,'| Test | Vdc1 | Io1 peak | Vdc OK | Trip | Permit | PLL lock fractions | Limited refs | Result |\n|---|---:|---:|---:|---:|---:|---:|---:|---|\n');
for k = 1:numel(m.protection_cases)
    p = m.protection_cases(k);
    fprintf(fid,'| %s | %.2f V | %.3f A | %.0f / %.0f | %.0f | %.0f | %.3f / %.3f | %.2f / %.2f A | %s |\n', ...
        p.name,p.Vdc1_mean_V,p.Io1_peak_abs_A, ...
        p.Protect1_Vdc_OK_final,p.Protect2_Vdc_OK_final, ...
        p.Protect1_OC_Trip_final,p.Protect1_GatePermit_final, ...
        p.PLL1_lock_fraction,p.PLL2_lock_fraction, ...
        p.Protect1_Iref_Limited_A,p.Protect2_Iref_Limited_A,passText(p.pass));
end
fprintf(fid,'\n');

fprintf(fid,'## Artifacts\n\n');
fprintf(fid,'- Aggregate machine-readable results: `results/dual_inverter_all_metrics.json`.\n');
fprintf(fid,'- Stage results and plots: `results/` (Basic-1 through Protection).\n');
fprintf(fid,'- System design notes: `docs/dual_inverter_system_design.md`.\n');
end

function value = passText(flag)
if flag
    value = 'PASS';
else
    value = 'FAIL';
end
end
