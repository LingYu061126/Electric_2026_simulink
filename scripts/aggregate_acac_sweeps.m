% Aggregate genuine full-switching load and input sweeps; generate regulation figures.
projectDir = fileparts(fileparts(mfilename('fullpath')));
resultsDir = fullfile(projectDir,'results');
s5 = load(fullfile(resultsDir,'acac_req5_30hz_results.mat'),'req5');
nominal = s5.req5;
loadCurrent = [0.2 0.5 1.0 1.5 2.0];
loadTags = {'0p2','0p5','1p0','1p5'};
loadCases = cell(1,5);
for k = 1:4
    s = load(fullfile(resultsDir,sprintf('acac_req6_%sA_results.mat',loadTags{k})),'m');
    loadCases{k} = s.m;
end
loadCases{5} = nominal;
req6 = struct();
req6.current_points_A = loadCurrent;
req6.Rphase_points_Ohm = 32./(sqrt(3)*loadCurrent);
req6.Uline_average_points_V = cellfun(@(m)m.Uline_average_V,loadCases);
req6.Iline_average_points_A = cellfun(@(m)m.Iline_average_A,loadCases);
req6.Uab_points_V = cellfun(@(m)m.Uline_rms_V(1),loadCases);
req6.Ubc_points_V = cellfun(@(m)m.Uline_rms_V(2),loadCases);
req6.Uca_points_V = cellfun(@(m)m.Uline_rms_V(3),loadCases);
req6.PF_points = cellfun(@(m)m.input_PF,loadCases);
req6.efficiency_points_percent = cellfun(@(m)m.efficiency_percent,loadCases);
req6.output_THD_max_points_percent = cellfun(@(m)max(m.output_broadband_residual_percent),loadCases);
req6.dc_bus_points_V = cellfun(@(m)m.dc_bus_mean_V,loadCases);
req6.dc_bus_ripple_points_V = cellfun(@(m)m.dc_bus_pp_V,loadCases);
req6.frequency_points_Hz = cellfun(@(m)mean(m.output_frequency_measured_Hz),loadCases);
req6.max_voltage_imbalance_percent = max(cellfun(@(m)m.max_voltage_imbalance_percent,loadCases));
req6.SI_span_percent = 100*(max(req6.Uline_average_points_V)-min(req6.Uline_average_points_V))/32;
req6.SI_deviation_percent = 100*max(abs(req6.Uline_average_points_V-32))/32;
req6.requirement_6_pass = req6.SI_span_percent<=0.3 && req6.SI_deviation_percent<=0.3 ...
    && all(cellfun(@(m)m.all_finite,loadCases));
writeJson(fullfile(resultsDir,'acac_req6_load_regulation.json'),req6);
fprintf('REQ6 SI_span=%.5f%% SI_dev=%.5f%% PASS=%d\n', ...
    req6.SI_span_percent,req6.SI_deviation_percent,req6.requirement_6_pass);

fig = figure('Visible','off','Color','w');
plot(loadCurrent,req6.Uline_average_points_V,'o-','LineWidth',1.5); hold on;
yline(32,'k-','Target'); yline(32*(1+0.003),'r--','+0.3%');
yline(32*(1-0.003),'r--','-0.3%');
xlabel('Load current target (A)'); ylabel('Mean line RMS voltage (V)');
title('Requirement 6: load regulation'); grid on;
saveFigure(fig,resultsDir,'req6_load_regulation_curve.png');
fig = figure('Visible','off','Color','w');
plot(loadCurrent,req6.Iline_average_points_A,'o-','LineWidth',1.5); hold on;
plot(loadCurrent,loadCurrent,'k--');
xlabel('Target load current (A)'); ylabel('Measured line current (A)');
title('Requirement 6: actual load current sweep'); legend('Measured','Target','Location','best'); grid on;
saveFigure(fig,resultsDir,'req6_load_current_sweep.png');

inputVoltage = [31 33 36 39 41];
lineCases = cell(1,5);
for k = [1 2 4 5]
    s = load(fullfile(resultsDir,sprintf('acac_req7_%dV_results.mat',inputVoltage(k))),'m');
    lineCases{k} = s.m;
end
lineCases{3} = nominal;
req7 = struct();
req7.input_voltage_points_V = inputVoltage;
req7.input_voltage_measured_points_V = cellfun(@(m)m.input_voltage_rms_V,lineCases);
req7.dc_bus_points_V = cellfun(@(m)m.dc_bus_mean_V,lineCases);
req7.dc_bus_ripple_points_V = cellfun(@(m)m.dc_bus_pp_V,lineCases);
req7.output_voltage_points_V = cellfun(@(m)m.Uline_average_V,lineCases);
req7.Uab_points_V = cellfun(@(m)m.Uline_rms_V(1),lineCases);
req7.Ubc_points_V = cellfun(@(m)m.Uline_rms_V(2),lineCases);
req7.Uca_points_V = cellfun(@(m)m.Uline_rms_V(3),lineCases);
req7.Iline_average_points_A = cellfun(@(m)m.Iline_average_A,lineCases);
req7.output_frequency_points_Hz = cellfun(@(m)mean(m.output_frequency_measured_Hz),lineCases);
req7.PF_points = cellfun(@(m)m.input_PF,lineCases);
req7.input_current_THD_points_percent = cellfun(@(m)m.input_current_THD_percent,lineCases);
req7.THD_points_percent = cellfun(@(m)max(m.output_broadband_residual_percent),lineCases);
req7.efficiency_points_percent = cellfun(@(m)m.efficiency_percent,lineCases);
req7.PFC_duty_min_points = cellfun(@(m)m.PFC_duty_min,lineCases);
req7.PFC_duty_max_points = cellfun(@(m)m.PFC_duty_max,lineCases);
req7.PFC_saturation_count_points = cellfun(@(m)m.PFC_duty_saturation_samples,lineCases);
req7.PFC_duty_floor_count_points = cellfun(@(m)m.PFC_duty_floor_samples,lineCases);
req7.PFC_duty_ceiling_count_points = cellfun(@(m)m.PFC_duty_ceiling_samples,lineCases);
req7.input_power_points_W = cellfun(@(m)m.input_power_W,lineCases);
req7.output_power_points_W = cellfun(@(m)m.output_power_W,lineCases);
req7.SU_span_percent = 100*(max(req7.output_voltage_points_V)-min(req7.output_voltage_points_V))/32;
req7.SU_deviation_percent = 100*max(abs(req7.output_voltage_points_V-32))/32;
req7.bus_reference_changed = false;
req7.final_bus_reference_V = 60;
req7.high_line_PFC_stable = abs(req7.dc_bus_points_V(end)-60)/60<0.01 ...
    && req7.PFC_duty_min_points(end)>0.02 && req7.PF_points(end)>=0.98;
req7.requirement_7_pass = req7.SU_span_percent<=0.3 && req7.SU_deviation_percent<=0.3 ...
    && all(cellfun(@(m)m.all_finite,lineCases));
req7.Req7_and_original_quality_metrics_pass = req7.requirement_7_pass ...
    && all(req7.PF_points>=0.98) && all(req7.THD_points_percent<=2) ...
    && all(abs(req7.dc_bus_points_V-60)/60<0.01);
writeJson(fullfile(resultsDir,'acac_req7_line_regulation.json'),req7);
fprintf('REQ7 SU_span=%.5f%% SU_dev=%.5f%% highline=%d quality=%d PASS=%d\n', ...
    req7.SU_span_percent,req7.SU_deviation_percent,req7.high_line_PFC_stable, ...
    req7.Req7_and_original_quality_metrics_pass,req7.requirement_7_pass);

fig = figure('Visible','off','Color','w');
plot(inputVoltage,req7.output_voltage_points_V,'o-','LineWidth',1.5); hold on;
yline(32,'k-','Target'); yline(32*(1+0.003),'r--','+0.3%');
yline(32*(1-0.003),'r--','-0.3%');
xlabel('Input voltage RMS (V)'); ylabel('Mean line RMS voltage (V)');
title('Requirement 7: line regulation'); grid on;
saveFigure(fig,resultsDir,'req7_line_regulation_curve.png');
fig = figure('Visible','off','Color','w');
plot(inputVoltage,req7.dc_bus_points_V,'o-','LineWidth',1.5); hold on;
yline(60,'k--','Reference'); xlabel('Input voltage RMS (V)'); ylabel('DC bus mean (V)');
title('DC bus across input sweep'); grid on;
saveFigure(fig,resultsDir,'req7_dc_bus_vs_input.png');
fig = figure('Visible','off','Color','w');
plot(inputVoltage,req7.PF_points,'o-','LineWidth',1.5); hold on;
yline(0.98,'r--','Original PF gate'); xlabel('Input voltage RMS (V)'); ylabel('Total input PF');
title('Input power factor across input sweep'); grid on;
saveFigure(fig,resultsDir,'req7_pf_vs_input.png');
fig = figure('Visible','off','Color','w');
plot(inputVoltage,req7.efficiency_points_percent,'o-','LineWidth',1.5); hold on;
yline(95,'r--','Original efficiency gate');
xlabel('Input voltage RMS (V)'); ylabel('Modeled efficiency (%)');
title('Efficiency across input sweep'); grid on;
saveFigure(fig,resultsDir,'req7_efficiency_vs_input.png');
s31 = load(fullfile(resultsDir,'acac_req7_31V_results.mat'),'w');
s41 = load(fullfile(resultsDir,'acac_req7_41V_results.mat'),'w');
fig = figure('Visible','off','Color','w');
for k = 1:2
    subplot(2,1,k);
    if k==1, ww=s31.w; vlabel='31 V'; else, ww=s41.w; vlabel='41 V'; end
    ix=ww.t<0.84;
    plot(ww.t(ix),ww.vin(ix)/max(abs(ww.vin(ix))),'LineWidth',1.1); hold on;
    plot(ww.t(ix),ww.iin(ix)/max(abs(ww.iin(ix))),'LineWidth',1.0);
    ylabel('Normalized'); title(['Input voltage and current at ' vlabel]); grid on;
    if k==2, xlabel('Time (s)'); end
    legend('Vin','Iin','Location','best');
end
saveFigure(fig,resultsDir,'req7_input_current_extremes.png');

function writeJson(path,value)
fid=fopen(path,'w'); assert(fid>=0);
fwrite(fid,jsonencode(value,'PrettyPrint',true),'char'); fclose(fid);
end

function saveFigure(fig,folder,name)
exportgraphics(fig,fullfile(folder,name),'Resolution',180); close(fig);
end
