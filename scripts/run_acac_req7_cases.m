% Complete physical switching runs for the nonnominal Requirement 7 line points.
projectDir = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectDir,'models'));
addpath(fullfile(projectDir,'scripts'));
mdl = 'acac_30hz_r2024a';
load_system(fullfile(projectDir,'models',[mdl '.slx']));
inputVoltages = [31 33 39 41];
for k = 1:numel(inputVoltages)
    [m,w,o] = acac_run_case(mdl,inputVoltages(k),2,30,1.0,[0.8 1.0]);
    path = fullfile(projectDir,'results',sprintf('acac_req7_%dV_results.mat',inputVoltages(k)));
    if k == 1 || k == numel(inputVoltages)
        save(path,'m','w','o','-v7.3'); % Preserve both line endpoints.
    else
        save(path,'m','w','-v7.3');
    end
    fprintf('SAVED_REQ7_POINT=%s\n',path);
    clear m w o
end
