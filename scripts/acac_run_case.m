function [metrics,wave,out] = acac_run_case(modelName,inputVrms,targetCurrentA,outputFrequencyHz,stopTime,window)
% Configure one complete physical AC-AC switching simulation non-destructively.
arguments
    modelName (1,:) char
    inputVrms (1,1) double {mustBePositive}
    targetCurrentA (1,1) double {mustBePositive}
    outputFrequencyHz (1,1) double {mustBePositive}
    stopTime (1,1) double {mustBePositive}
    window (1,2) double
end
loadPaths = arrayfun(@(sid)Simulink.ID.getFullName(sprintf('%s:%d',modelName,sid)), ...
    [51 61 71],'UniformOutput',false);
sourcePath = Simulink.ID.getFullName(sprintf('%s:4',modelName));
Rphase = 32/(sqrt(3)*targetCurrentA);
in = Simulink.SimulationInput(modelName);
in = in.setVariable('Fout_Hz',outputFrequencyHz,'Workspace',modelName);
in = in.setModelParameter('StopTime',sprintf('%.8g',stopTime));
in = in.setBlockParameter(sourcePath,'ac_voltage',sprintf('%.15g',sqrt(2)*inputVrms));
for k = 1:numel(loadPaths)
    in = in.setBlockParameter(loadPaths{k},'R',sprintf('%.15g',Rphase));
end
out = sim(in);
[metrics,wave] = acac_measure_run(out,outputFrequencyHz,50,window);
metrics.input_voltage_target_V = inputVrms;
metrics.target_current_A = targetCurrentA;
metrics.Rphase_Ohm = Rphase;
fprintf('CASE Ui=%.1f Iref=%.3f R=%.9f Uavg=%.5f Iavg=%.5f f=%.5f Vdc=%.3f PF=%.5f duty=[%.4f %.4f] eta=%.3f%%\n', ...
    inputVrms,targetCurrentA,Rphase,metrics.Uline_average_V,metrics.Iline_average_A, ...
    mean(metrics.output_frequency_measured_Hz),metrics.dc_bus_mean_V,metrics.input_PF, ...
    metrics.PFC_duty_min,metrics.PFC_duty_max,metrics.efficiency_percent);
end
