function apply_robust_controller_source(modelName,sourcePath)
% Apply one inspected MATLAB Function source to the derived optimization model.
arguments
    modelName (1,:) char
    sourcePath (1,:) char
end
assert(strcmp(modelName,'acac_robust_optimized_r2024a'), ...
    'Only the derived robustness model may be edited by this helper.');
rt=sfroot;
chart=rt.find('-isa','Stateflow.EMChart', ...
    'Path',[modelName '/Control/PFC_and_Inverter_Control']);
assert(numel(chart)==1,'Expected one PFC/VSI MATLAB Function chart.');
chart.Script=fileread(sourcePath);
% Reassign the existing model-workspace parameter after Script replacement.
fout=chart.find('-isa','Stateflow.Data','Name','Fout_Hz');
if isempty(fout)
    fout=Stateflow.Data(chart);
    fout.Name='Fout_Hz';
end
fout.Scope='Parameter';
diag=chart.find('-isa','Stateflow.Data','Name','pfcDiagnostics');
assert(numel(diag)==1 && strcmp(diag.Scope,'Output'), ...
    'PFC diagnostic output did not survive the Script replacement.');
end
