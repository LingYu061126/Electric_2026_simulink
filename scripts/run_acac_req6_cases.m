% Complete physical switching runs for Requirement 6 load points below 2 A.
projectDir = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectDir,'models'));
addpath(fullfile(projectDir,'scripts'));
mdl = 'acac_30hz_r2024a';
load_system(fullfile(projectDir,'models',[mdl '.slx']));
currents = [0.2 0.5 1.0 1.5];
tags = {'0p2','0p5','1p0','1p5'};
for k = 1:numel(currents)
    [m,w,o] = acac_run_case(mdl,36,currents(k),30,1.0,[0.8 1.0]);
    path = fullfile(projectDir,'results',sprintf('acac_req6_%sA_results.mat',tags{k}));
    if k == 1
        save(path,'m','w','o','-v7.3'); % Preserve the light-load endpoint.
    else
        save(path,'m','w','-v7.3');
    end
    fprintf('SAVED_REQ6_POINT=%s\n',path);
    clear m w o
end
