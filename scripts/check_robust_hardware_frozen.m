function audit = check_robust_hardware_frozen()
% Compare every Simscape physical block in the baseline and derived model.
projectDir = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectDir,'models'));
baseline = 'acac_30hz_r2024a';
derived = 'acac_robust_optimized_r2024a';
load_system(fullfile(projectDir,'models',[baseline '.slx']));
load_system(fullfile(projectDir,'models',[derived '.slx']));
paths = find_system(baseline,'LookUnderMasks','all', ...
    'FollowLinks','on','Type','Block');
count = 0;
mismatches = {};
for index = 1:numel(paths)
    oldBlock = paths{index};
    if ~strcmp(get_param(oldBlock,'BlockType'),'SimscapeBlock')
        continue
    end
    count = count + 1;
    newBlock = [derived oldBlock(numel(baseline)+1:end)];
    try
        equal = strcmp(get_param(oldBlock,'ReferenceBlock'), ...
            get_param(newBlock,'ReferenceBlock')) ...
            && isequal(get_param(oldBlock,'MaskNames'), ...
                get_param(newBlock,'MaskNames')) ...
            && isequal(get_param(oldBlock,'MaskValues'), ...
                get_param(newBlock,'MaskValues'));
        if ~equal, mismatches{end+1} = oldBlock; end %#ok<AGROW>
    catch
        mismatches{end+1} = oldBlock; %#ok<AGROW>
    end
end
solverNames = {'Solver','SolverType','MaxStep','RelTol','AbsTol','FixedStep'};
solverEqual = true;
for index = 1:numel(solverNames)
    solverEqual = solverEqual && strcmp( ...
        get_param(baseline,solverNames{index}), ...
        get_param(derived,solverNames{index}));
end
audit = struct('baseline_model',baseline,'derived_model',derived, ...
    'physical_block_count',count,'mismatched_block_count',numel(mismatches), ...
    'mismatched_blocks',{mismatches},'all_physical_masks_equal',isempty(mismatches), ...
    'solver_configuration_equal',solverEqual,'solver',get_param(derived,'Solver'), ...
    'max_step_s',get_param(derived,'MaxStep'), ...
    'comparison','ReferenceBlock, MaskNames and MaskValues for every SimscapeBlock');
assert(audit.all_physical_masks_equal,'Physical parameter mismatch detected.');
assert(audit.solver_configuration_equal,'Solver configuration mismatch detected.');
outputPath = fullfile(projectDir,'results','robust_hardware_frozen_audit.json');
fid = fopen(outputPath,'w'); assert(fid>=0);
fprintf(fid,'%s',jsonencode(audit,'PrettyPrint',true)); fclose(fid);
fprintf('PHYSICAL_BLOCKS=%d MISMATCHES=%d\n',count,numel(mismatches));
end
