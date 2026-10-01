% Figures generated only after the final scorecard has all measured cases.
projectDir = fileparts(fileparts(mfilename('fullpath')));
resultsDir = fullfile(projectDir,'results');
baseline = jsondecode(fileread(fullfile(resultsDir,'robust_baseline_metrics.json')));
final = jsondecode(fileread(fullfile(resultsDir,'robustness_scorecard.json')));

figureHandle = figure('Visible','off','Color','w','Position',[100 100 900 560]);
currents = [final.load_sweep.Iout_A];
plot(currents,[baseline.load_sweep.PF],'o-','LineWidth',1.5); hold on;
plot(currents,[final.load_sweep.PF],'s--','LineWidth',1.5);
yline(0.98,'k:','PF = 0.98');
grid on; xlabel('Output line current target (A)'); ylabel('Input total PF');
legend('Baseline','Final retained','Location','southeast');
title('30 Hz / 36 V: input PF versus load');
exportgraphics(figureHandle,fullfile(resultsDir,'robust_pf_vs_load.png'),'Resolution',180);
close(figureHandle);

figureHandle = figure('Visible','off','Color','w','Position',[100 100 900 560]);
voltages = [final.input_sweep.Ui_V];
plot(voltages,[baseline.input_sweep.efficiency_percent],'o-','LineWidth',1.5); hold on;
plot(voltages,[final.input_sweep.efficiency_percent],'s--','LineWidth',1.5);
yline(95,'k:','Efficiency = 95%');
grid on; xlabel('Input voltage RMS (V)'); ylabel('Model efficiency (%)');
legend('Baseline','Final retained','Location','southeast');
title('30 Hz / 2 A: model efficiency versus input voltage');
exportgraphics(figureHandle,fullfile(resultsDir,'robust_efficiency_vs_input.png'),'Resolution',180);
close(figureHandle);

figureHandle = figure('Visible','off','Color','w','Position',[100 100 1120 740]);
tiledlayout(2,2,'TileSpacing','compact');
allPoints = final.combined_corner_cases;
v = [allPoints.Ui_V];
i = [allPoints.Iout_A];
plotMetric(v,i,[allPoints.PF],0.98,'PF',1);
plotMetric(v,i,[allPoints.efficiency_percent],95,'Efficiency (%)',2);
plotMetric(v,i,[allPoints.THD_max_percent],2,'Line residual (%)',3);
plotMetric(v,i,[allPoints.Uline_V],32,'Line voltage (V)',4);
sgtitle('Six physical switching corner cases, 0.8-1.0 s');
exportgraphics(figureHandle,fullfile(resultsDir,'robust_operating_map.png'),'Resolution',180);
close(figureHandle);

function plotMetric(v,i,value,threshold,label,tile)
nexttile(tile);
scatter(v,i,130,value,'filled'); colorbar; grid on;
xlim([29.5 42.5]); ylim([0 2.2]);
xticks([31 36 41]); yticks([0.2 2]);
xlabel('Input voltage RMS (V)'); ylabel('Output current target (A)');
title(sprintf('%s; reference %.3g',label,threshold));
for index=1:numel(value)
    text(v(index)+0.25,i(index),sprintf('%.3f',value(index)), ...
        'FontSize',8,'VerticalAlignment','middle');
end
end
