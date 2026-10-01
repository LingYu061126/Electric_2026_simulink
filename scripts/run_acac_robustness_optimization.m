function metrics = run_acac_robustness_optimization(candidate)
% Reproduce one screened control candidate on the full switching model.
% Candidate changes are transient; the saved final model is never tuned here.
arguments
    candidate (1,:) char {mustBeMember(candidate, ...
        {'A_02A','A_05A','B_02A','D_02A','E_56V','E_58V','E_59p5V'})}
end
projectDir = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectDir,'models'),fullfile(projectDir,'scripts'));
modelName = 'acac_robust_optimized_r2024a';
load_system(fullfile(projectDir,'models',[modelName '.slx']));
cleaner = onCleanup(@()restoreController(modelName,projectDir));

switch candidate
    case {'A_02A','A_05A'}
        source = 'acac_robust_candidate_A_gain_schedule.txt';
        inputVrms = 36;
        targetCurrentA = 0.2;
        if strcmp(candidate,'A_05A'), targetCurrentA = 0.5; end
    case 'B_02A'
        source = 'acac_robust_candidate_B_zero_cross.txt';
        inputVrms = 36; targetCurrentA = 0.2;
    case 'D_02A'
        source = 'acac_robust_candidate_D_50kHz.txt';
        inputVrms = 36; targetCurrentA = 0.2;
    case 'E_56V'
        source = 'acac_robust_candidate_E_56V_screen.txt';
        inputVrms = 31; targetCurrentA = 2;
    case 'E_58V'
        source = 'acac_robust_candidate_E_58V_screen.txt';
        inputVrms = 31; targetCurrentA = 2;
    otherwise
        source = 'acac_robust_candidate_E_59p5V_screen.txt';
        inputVrms = 31; targetCurrentA = 2;
end
apply_robust_controller_source(modelName,fullfile(projectDir,'scripts',source));
set_param(modelName,'SimulationCommand','update');
[metrics,wave,out] = acac_run_case(modelName,inputVrms,targetCurrentA,30,1.0,[0.8 1.0]);
diagnostics = out.get('acac_pfc_internal');
resultFile = fullfile(projectDir,'results',['robust_reproduce_' candidate '.mat']);
save(resultFile,'metrics','wave','diagnostics','-v7.3');
clear cleaner
end

function restoreController(modelName,projectDir)
apply_robust_controller_source(modelName, ...
    fullfile(projectDir,'scripts','acac_robust_control_law.txt'));
end
