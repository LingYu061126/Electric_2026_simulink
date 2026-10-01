function metrics = run_acac_robustness_validation(caseId)
% Fixed-design validation: no gain changes, no parameter search, 0.8-1.0 s.
% With no caseId, run all cases. Individual IDs support crash-safe progress.
arguments
    caseId (1,:) char = 'all'
end
projectDir = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectDir,'models'),fullfile(projectDir,'scripts'));
modelName = 'acac_robust_optimized_r2024a';
load_system(fullfile(projectDir,'models',[modelName '.slx']));
caseNames = {'nominal_60Hz','load_02A','load_05A','load_10A', ...
    'load_15A','load_20A','line_31V','line_33V','line_39V', ...
    'line_41V','corner_31V_02A','corner_41V_02A'};
inputVrms = [36 36 36 36 36 36 31 33 39 41 31 41];
currentA = [2 0.2 0.5 1 1.5 2 2 2 2 2 0.2 0.2];
frequencyHz = [60 30 30 30 30 30 30 30 30 30 30 30];
if strcmp(caseId,'all')
    selected = 1:numel(caseNames);
else
    selected = find(strcmp(caseNames,caseId));
    assert(isscalar(selected),'Unknown validation case: %s',caseId);
end
metrics = cell(1,numel(selected));
for index = 1:numel(selected)
    k = selected(index);
    [m,w] = acac_run_case(modelName,inputVrms(k),currentA(k), ...
        frequencyHz(k),1.0,[0.8 1.0]);
    m.validation_case = caseNames{k};
    m.validation_model = modelName;
    m.measurement_window_s = [0.8 1.0];
    metrics{index} = m;
    matPath = fullfile(projectDir,'results',['robust_final_' caseNames{k} '.mat']);
    jsonPath = fullfile(projectDir,'results',['robust_final_' caseNames{k} '.json']);
    save(matPath,'m','w','-v7.3');
    fid = fopen(jsonPath,'w');
    assert(fid>=0,'Could not write %s',jsonPath);
    fprintf(fid,'%s',jsonencode(m,'PrettyPrint',true));
    fclose(fid);
    % Saved measurements are independent of SDI; release switching traces
    % before the next case to bound memory and temporary-disk growth.
    Simulink.sdi.clear;
end
if isscalar(selected), metrics = metrics{1}; end
end
