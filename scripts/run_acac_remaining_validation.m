% Complete switching validation of Requirements 5-7. The original model is untouched.
projectDir = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectDir,'models'));
addpath(fullfile(projectDir,'scripts'));
resultsDir = fullfile(projectDir,'results');
mdl = 'acac_30hz_r2024a';

% Recheck Requirements 1-4 on the same retained design at 60 Hz.
run(fullfile(projectDir,'scripts','run_acac_baseline60.m'));

% Requirement 5: 36 Vrms / 50 Hz in, 32 V line-line / 30 Hz / 2 A out.
in = Simulink.SimulationInput(mdl);
in = in.setVariable('Fout_Hz',30,'Workspace',mdl);
in = in.setModelParameter('StopTime','1.0');
out = sim(in);
[req5,wave5] = acac_measure_run(out,30,50,[0.8 1.0]);
req5.input_Vrms = req5.input_voltage_rms_V;
req5.output_frequency_Hz = mean(req5.output_frequency_measured_Hz);
req5.Uab_rms_V = req5.Uline_rms_V(1);
req5.Ubc_rms_V = req5.Uline_rms_V(2);
req5.Uca_rms_V = req5.Uline_rms_V(3);
req5.Ia_rms_A = req5.Iline_rms_A(1);
req5.Ib_rms_A = req5.Iline_rms_A(2);
req5.Ic_rms_A = req5.Iline_rms_A(3);
req5.requirement_5_pass = all(abs(req5.Uline_rms_V-32)<=0.1) ...
    && all(abs(req5.output_frequency_measured_Hz-30)<=0.2) ...
    && all(abs(req5.Iline_rms_A-2)<=0.02) ...
    && req5.all_finite;
fprintf('REQ5 U=[%.4f %.4f %.4f] V f=[%.4f %.4f %.4f] Hz I=[%.4f %.4f %.4f] A PF=%.5f eta=%.3f%% PASS=%d\n', ...
    req5.Uline_rms_V,req5.output_frequency_measured_Hz,req5.Iline_rms_A, ...
    req5.input_PF,req5.efficiency_percent,req5.requirement_5_pass);
save(fullfile(resultsDir,'acac_req5_30hz_results.mat'),'out','req5','wave5','-v7.3');
writeJson(fullfile(resultsDir,'acac_req5_30hz_metrics.json'),req5);
writeJson(fullfile(resultsDir,'acac_req5_metrics.json'),req5);

% Four Requirement 5 figures.
ix = wave5.t < 0.8+4/30;
fig = figure('Visible','off','Color','w');
plot(wave5.t(ix),[wave5.va(ix),wave5.vb(ix),wave5.vc(ix)]);
xlabel('Time (s)'); ylabel('Phase voltage (V)'); title('30 Hz three-phase voltages');
legend('Va','Vb','Vc','Location','best'); grid on;
saveFigure(fig,resultsDir,'req5_three_phase_30hz.png');
fig = figure('Visible','off','Color','w');
plot(wave5.t(ix),[wave5.uab(ix),wave5.ubc(ix),wave5.uca(ix)]);
xlabel('Time (s)'); ylabel('Line voltage (V)'); title('30 Hz line voltages');
legend('Uab','Ubc','Uca','Location','best'); grid on;
saveFigure(fig,resultsDir,'req5_line_voltage_30hz.png');
fig = figure('Visible','off','Color','w');
plot(wave5.t(ix),[wave5.ia(ix),wave5.ib(ix),wave5.ic(ix)]);
xlabel('Time (s)'); ylabel('Load current (A)'); title('30 Hz load currents');
legend('Ia','Ib','Ic','Location','best'); grid on;
saveFigure(fig,resultsDir,'req5_current_30hz.png');
ts = out.get('acac_vdc');
fig = figure('Visible','off','Color','w'); plot(ts.Time(:),double(ts.Data(:)));
xlabel('Time (s)'); ylabel('DC bus (V)'); title('DC bus at 30 Hz output'); grid on;
saveFigure(fig,resultsDir,'req5_dc_bus.png');
clear out wave5 in

% Complete physical switching sweeps, then derive the two regulation metrics,
% figures, combined JSON and final report from the saved measured results.
run(fullfile(projectDir,'scripts','run_acac_req6_cases.m'));
run(fullfile(projectDir,'scripts','run_acac_req7_cases.m'));
run(fullfile(projectDir,'scripts','aggregate_acac_sweeps.m'));
run(fullfile(projectDir,'scripts','run_acac_req6_dynamic.m'));
reportCommand = sprintf('python3 "%s"',fullfile(projectDir,'scripts','build_acac_final_report.py'));
[reportStatus,reportOutput] = system(reportCommand);
assert(reportStatus==0,'Final report generation failed: %s',reportOutput);
disp(reportOutput);

function writeJson(path,value)
fid = fopen(path,'w'); assert(fid>=0,'Cannot open JSON output.');
fwrite(fid,jsonencode(value,'PrettyPrint',true),'char'); fclose(fid);
end

function saveFigure(fig,folder,name)
exportgraphics(fig,fullfile(folder,name),'Resolution',180); close(fig);
end
