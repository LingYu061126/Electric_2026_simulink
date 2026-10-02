function state = run_converter_testbench_validation(mode)
% Ordered, hard-gated MATLAB R2024a physical-switching validation.
% mode='full' (default) reruns all 81 frequencies; 'resume' reuses a verified
% Basic-4 checkpoint; 'audit' validates saved measurements without simulating.
if nargin<1,mode='full';end
assert(any(strcmp(mode,{'full','resume','audit'})),'Invalid validation mode');
projectDir=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectDir,'subsystems'));
addpath(fullfile(projectDir,'scripts'));
resultsDir=fullfile(projectDir,'results');
sdiDir=fullfile(getenv('HOME'),'.cache','matlab-sdi-converter1');
if ~isfolder(sdiDir),mkdir(sdiDir);end
Simulink.sdi.setStorageLocation(sdiDir);
basicModel=fullfile(projectDir,'models','converter1_basic_test_r2024a.slx');
regenModel=fullfile(projectDir,'models','energy_recovery_testbench_r2024a.slx');
assert(isfile(basicModel)&&isfile(regenModel),'Required model missing');
load_system(basicModel);load_system(regenModel);
set_param('converter1_basic_test_r2024a','SimulationCommand','update');
set_param('energy_recovery_testbench_r2024a','SimulationCommand','update');
readj=@(name) jsondecode(fileread(fullfile(resultsDir,name)));
state=struct('mode',mode,'generated_at',datestr(now,30), ...
    'models',{{basicModel,regenModel}});

% 1 Basic-1
if ~strcmp(mode,'audit'),run(fullfile(projectDir,'scripts','run_converter1_basic1.m'));end
state=gate(state,'Basic1',readj('basic_req1_metrics.json'),resultsDir);
% 2 Basic-2
if ~strcmp(mode,'audit'),run(fullfile(projectDir,'scripts','run_converter1_basic2.m'));end
state=gate(state,'Basic2',readj('basic_req2_thd.json'),resultsDir);
% 3 Basic-3
if ~strcmp(mode,'audit'),run(fullfile(projectDir,'scripts','run_converter1_basic3.m'));end
state=gate(state,'Basic3',readj('basic_req3_load_regulation.json'),resultsDir);
% 4 Basic-4
progressFile=fullfile(resultsDir,'basic_req4_frequency_sweep_progress.json');
if strcmp(mode,'full') && isfile(progressFile)
    archive=fullfile(resultsDir,['basic_req4_checkpoint_before_full_' datestr(now,'yyyymmdd_HHMMSS') '.json']);
    movefile(progressFile,archive);
end
if ~strcmp(mode,'audit')
    clear maxPoints
    run(fullfile(projectDir,'scripts','run_converter1_basic4.m'));
end
b4=readj('basic_req4_frequency_sweep.json');
assert(b4.point_count==81 && isequal([b4.points.Fcommand_Hz],20:100), ...
    'Basic-4 did not record all 81 ordered commands');
state=gate(state,'Basic4',b4,resultsDir);
% Pre-Bonus 0.5 A current-loop smoke
if ~strcmp(mode,'audit'),run(fullfile(projectDir,'scripts','run_converter2_smoke.m'));end
state=gate(state,'Converter2Smoke',readj('converter2_smoke_metrics.json'),resultsDir);
% 5 Bonus-1
if ~strcmp(mode,'audit'),run(fullfile(projectDir,'scripts','run_bonus1_energy_recovery.m'));end
state=gate(state,'Bonus1',readj('bonus_req1_energy_recovery.json'),resultsDir);
% 6 Bonus-2
if ~strcmp(mode,'audit'),run(fullfile(projectDir,'scripts','run_bonus2_source_power.m'));end
state=gate(state,'Bonus2',readj('bonus_req2_source_power.json'),resultsDir);
% 7 Bonus-3 auxiliary protection test
if ~strcmp(mode,'audit'),run(fullfile(projectDir,'scripts','run_bonus3_protection.m'));end
state=gate(state,'Bonus3AdditionalFeature',readj('bonus3_protection_test.json'),resultsDir);
% 8 Final regression
if ~strcmp(mode,'audit'),run(fullfile(projectDir,'scripts','run_converter1_final_regression.m'));end
state=gate(state,'FinalRegression',readj('final_regression.json'),resultsDir);
% 9 Report generation
reportPath=write_converter_final_report(projectDir);
assert(isfile(reportPath),'Final report generation failed');
state.FinalReport=struct('created',true,'configured',true,'compiled',true, ...
    'simulated',true,'measured',true,'validated',true,'path',reportPath);
write_state(state,resultsDir);
fprintf('MASTER_VALIDATION all gates passed; mode=%s report=%s\n',mode,reportPath);
end

function state=gate(state,name,metrics,resultsDir)
assert(isfield(metrics,'pass')&&metrics.pass,'%s gate failed',name);
state.(name)=struct('created',true,'configured',true,'compiled',true, ...
    'simulated',true,'measured',true,'validated',true);
write_state(state,resultsDir);
end

function write_state(state,resultsDir)
fid=fopen(fullfile(resultsDir,'validation_state.json'),'w');
assert(fid>=0,'Cannot write validation state');
fwrite(fid,jsonencode(state,'PrettyPrint',true),'char');fclose(fid);
end
