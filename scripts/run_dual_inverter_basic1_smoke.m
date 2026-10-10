%% Basic-1: single inverter, physical 12-ohm load, grid disconnected
projectRoot = fileparts(fileparts(mfilename('fullpath')));
modelName = 'dual_single_phase_parallel_inverter_r2024a';
modelFile = fullfile(projectRoot,'models',[modelName '.slx']);
resultsDir = fullfile(projectRoot,'results');
if ~exist(resultsDir,'dir')
    mkdir(resultsDir);
end
assert(isfile(modelFile),'Dual-inverter model is missing: %s',modelFile);
assert(bdIsLoaded(modelName),'Open the saved model before running this stage.');

in = Simulink.SimulationInput(modelName);
blockPath = @(sid) Simulink.ID.getFullName([modelName ':' sid]);
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
in = in.setBlockParameter(blockPath('254'),'Value','1');
in = in.setBlockParameter(blockPath('259'),'Value','0');
in = in.setBlockParameter(blockPath('270'),'Value','1');
in = in.setBlockParameter(blockPath('271'),'Value','1');
in = in.setBlockParameter(blockPath('272'),'Value','0');
in = in.setBlockParameter(blockPath('269'),'r','12');
in = in.setModelParameter('StopTime','0.30');

fprintf('Running Basic-1 switching simulation: Inv1 on, Inv2 off, S1 closed, S_Load closed, S2 open, R=12 Ohm...\n');
out = sim(in);
metrics = analyze_dual_inverter_basic1_output(out,resultsDir);
save(fullfile(resultsDir,'basic1_single_inverter.mat'),'out','metrics');
assert(metrics.pass,'Basic-1 failed; stop the sequential validation here.');
