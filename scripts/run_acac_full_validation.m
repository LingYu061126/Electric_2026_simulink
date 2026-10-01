% Full real-switching AC-AC converter run and first-four-requirement checks.
projectDir = fileparts(fileparts(mfilename('fullpath')));
mdl = 'acac_single_to_three_phase_r2024a';
load_system(fullfile(projectDir,'models',[mdl '.slx']));
simIn = Simulink.SimulationInput(mdl);
simIn = simIn.setModelParameter('StopTime','1.00');
simOut = sim(simIn);

signalNames = {'acac_vin','acac_iin','acac_vdc','acac_idc_pfc','acac_idc_inverter','acac_pfc_duty', ...
    'acac_inverter_modulation','acac_va','acac_vb','acac_vc', ...
    'acac_uab','acac_ubc','acac_uca','acac_ia','acac_ib','acac_ic', ...
    'acac_qfh','acac_qfl','acac_qsh','acac_qsl', ...
    'acac_qah','acac_qal','acac_qbh','acac_qbl','acac_qch','acac_qcl', ...
    'acac_precharge_bypass','acac_final_precharge_bypass'};
sig = struct();
for k = 1:numel(signalNames)
    sig.(signalNames{k}) = simOut.get(signalNames{k});
    assert(all(isfinite(double(sig.(signalNames{k}).Data(:)))), ...
        'Nonfinite samples in %s.',signalNames{k});
end

% The 0.80 to 1.00 s window contains ten 50 Hz input cycles and twelve
% 60 Hz output cycles. Use time integration for variable-step Simscape data.
t0 = 0.80;
t1 = 1.00;
T = t1-t0;
metrics = struct();
metrics.stop_time_s = simOut.tout(end);
metrics.steady_window_s = [t0 t1];
metrics.input_voltage_rms_V = seriesRMS(sig.acac_vin,t0,t1);
metrics.input_current_rms_A = seriesRMS(sig.acac_iin,t0,t1);
metrics.input_real_power_W = averageProduct(sig.acac_vin,sig.acac_iin,t0,t1);
metrics.input_power_factor = metrics.input_real_power_W / ...
    (metrics.input_voltage_rms_V*metrics.input_current_rms_A);
metrics.line_voltage_rms_V = [seriesRMS(sig.acac_uab,t0,t1), ...
    seriesRMS(sig.acac_ubc,t0,t1),seriesRMS(sig.acac_uca,t0,t1)];
metrics.phase_voltage_rms_V = [seriesRMS(sig.acac_va,t0,t1), ...
    seriesRMS(sig.acac_vb,t0,t1),seriesRMS(sig.acac_vc,t0,t1)];
metrics.phase_current_rms_A = [seriesRMS(sig.acac_ia,t0,t1), ...
    seriesRMS(sig.acac_ib,t0,t1),seriesRMS(sig.acac_ic,t0,t1)];
metrics.output_real_power_W = averageProduct(sig.acac_va,sig.acac_ia,t0,t1) + ...
    averageProduct(sig.acac_vb,sig.acac_ib,t0,t1) + ...
    averageProduct(sig.acac_vc,sig.acac_ic,t0,t1);
metrics.efficiency = metrics.output_real_power_W / metrics.input_real_power_W;
metrics.dc_link_power_W = averageProduct(sig.acac_vdc,sig.acac_idc_inverter,t0,t1);
metrics.dc_link_current_mean_A = seriesMean(sig.acac_idc_inverter,t0,t1);
metrics.pfc_output_current_mean_A = seriesMean(sig.acac_idc_pfc,t0,t1);
metrics.pfc_output_power_W = averageProduct(sig.acac_vdc,sig.acac_idc_pfc,t0,t1);
metrics.loss_power_W = metrics.input_real_power_W-metrics.output_real_power_W;
metrics.pfc_loss_power_W = metrics.input_real_power_W-metrics.dc_link_power_W;
metrics.inverter_filter_loss_power_W = metrics.dc_link_power_W-metrics.output_real_power_W;
metrics.dc_bus_mean_V = seriesMean(sig.acac_vdc,t0,t1);
metrics.dc_bus_range_V = seriesRange(sig.acac_vdc,t0,t1);
metrics.dc_bus_reference_V = 60;
metrics.dc_bus_pp_ripple_V = metrics.dc_bus_range_V;
metrics.dc_bus_regulation_error_percent = 100*abs(metrics.dc_bus_mean_V-60)/60;
metrics.dc_bus_mean_before_inverter_V = seriesMean(sig.acac_vdc,0.14,0.18);
metrics.dc_bus_mean_after_load_V = seriesMean(sig.acac_vdc,0.24,0.28);
startupBus = double(sig.acac_vdc.Data(sig.acac_vdc.Time <= 0.30));
metrics.dc_bus_startup_peak_V = max(startupBus);
metrics.dc_bus_startup_overshoot_V = max(0,metrics.dc_bus_startup_peak_V-60);
metrics.pfc_duty_mean = seriesMean(sig.acac_pfc_duty,t0,t1);
metrics.inverter_modulation_mean = seriesMean(sig.acac_inverter_modulation,t0,t1);
metrics.input_current_peak_A = max(abs(double(sig.acac_iin.Data(:))));
metrics.precharge_bypass_time_s = firstHighTime(sig.acac_precharge_bypass);
metrics.final_precharge_bypass_time_s = firstHighTime(sig.acac_final_precharge_bypass);
metrics.output_frequency_Hz = positiveCrossingFrequency(sig.acac_uab,t0,t1,200e3);
metrics.line_voltage_thd_percent = [harmonicTHD(sig.acac_uab,t0,t1,200e3,60), ...
    harmonicTHD(sig.acac_ubc,t0,t1,200e3,60), ...
    harmonicTHD(sig.acac_uca,t0,t1,200e3,60)];
metrics.line_voltage_broadband_thd_percent = [broadbandTHD(sig.acac_uab,t0,t1,200e3,60), ...
    broadbandTHD(sig.acac_ubc,t0,t1,200e3,60), ...
    broadbandTHD(sig.acac_uca,t0,t1,200e3,60)];
metrics.input_current_thd_percent = harmonicTHD(sig.acac_iin,t0,t1,200e3,50);
vin1 = fundamentalPhasor(sig.acac_vin,t0,t1,200e3,50);
iin1 = fundamentalPhasor(sig.acac_iin,t0,t1,200e3,50);
metrics.input_displacement_factor = cos(angle(vin1)-angle(iin1));
phasePhasors = [fundamentalPhasor(sig.acac_va,t0,t1,200e3,60), ...
    fundamentalPhasor(sig.acac_vb,t0,t1,200e3,60), ...
    fundamentalPhasor(sig.acac_vc,t0,t1,200e3,60)];
metrics.phase_angle_ab_deg = mod(rad2deg(angle(phasePhasors(1)/phasePhasors(2)))+180,360)-180;
metrics.phase_angle_bc_deg = mod(rad2deg(angle(phasePhasors(2)/phasePhasors(3)))+180,360)-180;
metrics.phase_angle_ca_deg = mod(rad2deg(angle(phasePhasors(3)/phasePhasors(1)))+180,360)-180;
metrics.max_line_voltage_imbalance_percent = 100*max(abs(metrics.line_voltage_rms_V-mean(metrics.line_voltage_rms_V)))/mean(metrics.line_voltage_rms_V);
metrics.shootthrough_A = nnz(double(sig.acac_qah.Data(:))+double(sig.acac_qal.Data(:))>1);
metrics.shootthrough_B = nnz(double(sig.acac_qbh.Data(:))+double(sig.acac_qbl.Data(:))>1);
metrics.shootthrough_C = nnz(double(sig.acac_qch.Data(:))+double(sig.acac_qcl.Data(:))>1);
metrics.max_gate_pair_sum = max([ ...
    max(double(sig.acac_qfh.Data(:))+double(sig.acac_qfl.Data(:))), ...
    max(double(sig.acac_qsh.Data(:))+double(sig.acac_qsl.Data(:))), ...
    max(double(sig.acac_qah.Data(:))+double(sig.acac_qal.Data(:))), ...
    max(double(sig.acac_qbh.Data(:))+double(sig.acac_qbl.Data(:))), ...
    max(double(sig.acac_qch.Data(:))+double(sig.acac_qcl.Data(:)))]);

metrics.pass = struct();
metrics.pass.line_voltage = all(abs(metrics.line_voltage_rms_V-32.0) <= 0.1);
metrics.pass.output_frequency = metrics.output_frequency_Hz >= 59.8 && ...
    metrics.output_frequency_Hz <= 60.2;
metrics.pass.phase_current = all(metrics.phase_current_rms_A >= 1.9 & ...
    metrics.phase_current_rms_A <= 2.1);
metrics.pass.input_power_factor = metrics.input_power_factor >= 0.98;
metrics.pass.efficiency = metrics.efficiency >= 0.95;
metrics.pass.line_voltage_thd = all(metrics.line_voltage_thd_percent <= 2.0) && ...
    all(metrics.line_voltage_broadband_thd_percent <= 2.0);
metrics.pass.no_shoot_through = metrics.max_gate_pair_sum <= 1.0;
metrics.overall_pass = all(struct2array(metrics.pass));
metrics.input_frequency_Hz = positiveCrossingFrequency(sig.acac_vin,t0,t1,200e3);
metrics.pfc_topology = 'Bridgeless totem-pole boost PFC';
metrics.pfc_switching_frequency_Hz = 20000;
metrics.pfc_inductor_H = 0.001;
metrics.dc_link_capacitor_F = 0.0047;
metrics.inverter_switching_frequency_Hz = 12600;
metrics.Uab_rms_V = metrics.line_voltage_rms_V(1);
metrics.Ubc_rms_V = metrics.line_voltage_rms_V(2);
metrics.Uca_rms_V = metrics.line_voltage_rms_V(3);
metrics.Ia_rms_A = metrics.phase_current_rms_A(1);
metrics.Ib_rms_A = metrics.phase_current_rms_A(2);
metrics.Ic_rms_A = metrics.phase_current_rms_A(3);
metrics.Iline_avg_A = mean(metrics.phase_current_rms_A);
metrics.THD_Uab_percent = metrics.line_voltage_thd_percent(1);
metrics.THD_Ubc_percent = metrics.line_voltage_thd_percent(2);
metrics.THD_Uca_percent = metrics.line_voltage_thd_percent(3);
metrics.efficiency_percent = 100*metrics.efficiency;
metrics.input_PF = metrics.input_power_factor;
metrics.input_current_THD_percent = metrics.input_current_thd_percent;
metrics.input_power_W = metrics.input_real_power_W;
metrics.output_power_W = metrics.output_real_power_W;
metrics.requirement_1_pass = metrics.pass.line_voltage && metrics.pass.output_frequency && metrics.pass.phase_current;
metrics.requirement_2_pass = metrics.pass.input_power_factor;
metrics.requirement_3_pass = metrics.pass.efficiency;
metrics.requirement_4_pass = metrics.pass.line_voltage_thd;
metrics.first_four_requirements_passed = metrics.requirement_1_pass && metrics.requirement_2_pass && ...
    metrics.requirement_3_pass && metrics.requirement_4_pass;
assert(metrics.dc_link_power_W > metrics.output_real_power_W && ...
    metrics.input_real_power_W > metrics.dc_link_power_W, ...
    'DC-link power balance is inconsistent with positive modeled losses.');

fprintf('ACAC_FULL stop=%.3f s window=[%.3f, %.3f] s\n',metrics.stop_time_s,t0,t1);
fprintf('Line Vrms=[%.3f %.3f %.3f] V; phase Irms=[%.3f %.3f %.3f] A; f=%.4f Hz\n', ...
    metrics.line_voltage_rms_V,metrics.phase_current_rms_A,metrics.output_frequency_Hz);
fprintf('Vdc mean=%.3f V range=%.3f V; Pin=%.3f W Pout=%.3f W PF=%.5f eta=%.5f\n', ...
    metrics.dc_bus_mean_V,metrics.dc_bus_range_V,metrics.input_real_power_W, ...
    metrics.output_real_power_W,metrics.input_power_factor,metrics.efficiency);
fprintf('Line THD=[%.3f %.3f %.3f]%%; input-current THD=%.3f%%; gate-pair max=%.1f\n', ...
    metrics.line_voltage_thd_percent,metrics.input_current_thd_percent,metrics.max_gate_pair_sum);
fprintf('Precharge bypasses at %.6f s and %.6f s; overall gate result: %d\n', ...
    metrics.precharge_bypass_time_s,metrics.final_precharge_bypass_time_s,metrics.overall_pass);
fprintf('Pdc=%.3f W; losses PFC=%.3f W, inverter/filter=%.3f W, total=%.3f W; DPF=%.5f\n', ...
    metrics.dc_link_power_W,metrics.pfc_loss_power_W,metrics.inverter_filter_loss_power_W, ...
    metrics.loss_power_W,metrics.input_displacement_factor);

resultsDir = fullfile(projectDir,'results');
figuresDir = resultsDir;
if ~exist(resultsDir,'dir'), mkdir(resultsDir); end
if ~exist(figuresDir,'dir'), mkdir(figuresDir); end
save(fullfile(resultsDir,'acac_full_results.mat'),'simOut','metrics','-v7.3');
jsonText = jsonencode(metrics,'PrettyPrint',true);
fid = fopen(fullfile(resultsDir,'acac_full_metrics.json'),'w');
assert(fid >= 0,'Could not create metrics JSON.');
fwrite(fid,jsonText,'char');
fclose(fid);

% Reusable uniformly sampled windows for plots and spectra.
plotFs = 200e3;
[tPlot,vIn] = uniformWindow(sig.acac_vin,0.90,0.94,plotFs);
[~,iIn] = uniformWindow(sig.acac_iin,0.90,0.94,plotFs);
[tPhase,vA] = uniformWindow(sig.acac_va,0.90,0.95,plotFs);
[~,vB] = uniformWindow(sig.acac_vb,0.90,0.95,plotFs);
[~,vC] = uniformWindow(sig.acac_vc,0.90,0.95,plotFs);
[tLine,uAB] = uniformWindow(sig.acac_uab,0.90,0.95,plotFs);
[~,uBC] = uniformWindow(sig.acac_ubc,0.90,0.95,plotFs);
[~,uCA] = uniformWindow(sig.acac_uca,0.90,0.95,plotFs);
[tCurrent,iA] = uniformWindow(sig.acac_ia,0.90,0.95,plotFs);
[~,iB] = uniformWindow(sig.acac_ib,0.90,0.95,plotFs);
[~,iC] = uniformWindow(sig.acac_ic,0.90,0.95,plotFs);

% System overview.
fig = figure('Visible','off','Color','w','Position',[100 100 1200 520]);
ax = axes(fig,'Position',[0 0 1 1]); axis(ax,[0 1 0 1]); axis(ax,'off'); hold(ax,'on');
labels = {'36 V AC source',sprintf('Totem-pole\nPFC'),'60 V DC link', ...
    '3-phase VSI',sprintf('LC output\nfilter'),'Balanced Y load'};
xs = [0.025 0.185 0.345 0.505 0.665 0.825];
for k = 1:numel(labels)
    rectangle(ax,'Position',[xs(k) 0.60 0.135 0.17],'Curvature',0.04, ...
        'FaceColor',[0.88 0.93 0.98],'EdgeColor',[0.18 0.32 0.48],'LineWidth',1.5);
    text(ax,xs(k)+0.0675,0.685,labels{k},'HorizontalAlignment','center', ...
        'VerticalAlignment','middle','FontSize',11,'FontWeight','bold');
    if k < numel(labels)
        annotation(fig,'arrow',[xs(k)+0.137 xs(k+1)-0.004],[0.685 0.685], ...
            'LineWidth',1.5,'Color',[0.18 0.32 0.48]);
    end
end
rectangle(ax,'Position',[0.30 0.19 0.40 0.20],'Curvature',0.04, ...
    'FaceColor',[0.97 0.92 0.84],'EdgeColor',[0.55 0.34 0.12],'LineWidth',1.5);
text(ax,0.50,0.29,'PFC bus PI + current PI  |  60 Hz SPWM + output RMS PI', ...
    'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',11);
annotation(fig,'arrow',[0.50 0.50],[0.59 0.40],'LineWidth',1.4);
annotation(fig,'arrow',[0.87 0.70],[0.58 0.40],'LineWidth',1.4);
text(ax,0.50,0.09,'Real Simscape switching devices; 20 kHz PFC; 12.6 kHz VSI', ...
    'HorizontalAlignment','center','FontSize',10,'Color',[0.25 0.25 0.25]);
saveFig(fig,figuresDir,'acac_system_overview.png');

% Input voltage and current, normalized to compare phase and distortion.
fig = figure('Visible','off','Color','w');
plot(tPlot,vIn/max(abs(vIn)),'LineWidth',1.1); hold on;
plot(tPlot,iIn/max(abs(iIn)),'LineWidth',1.0);
xlabel('Time (s)'); ylabel('Normalized amplitude');
title('PFC input voltage and current'); legend('v_{in}','i_{in}','Location','best'); grid on;
saveFig(fig,figuresDir,'pfc_input_voltage_current.png');

% DC bus and duty.
[tBus,vBus] = uniformWindow(sig.acac_vdc,0,1,5e3);
fig = figure('Visible','off','Color','w'); plot(tBus,vBus,'LineWidth',1.1);
xlabel('Time (s)'); ylabel('DC link voltage (V)'); title('PFC DC link'); grid on;
saveFig(fig,figuresDir,'pfc_dc_bus.png');
[tDuty,duty] = uniformWindow(sig.acac_pfc_duty,0.8,1.0,50e3);
fig = figure('Visible','off','Color','w'); plot(tDuty,duty,'LineWidth',1.0);
xlabel('Time (s)'); ylabel('Duty ratio'); title('PFC duty command'); ylim([0 1]); grid on;
saveFig(fig,figuresDir,'pfc_duty.png');

% Three phase output voltages and currents.
fig = figure('Visible','off','Color','w');
plot(tPhase,vA,tPhase,vB,tPhase,vC,'LineWidth',1.0);
xlabel('Time (s)'); ylabel('Phase voltage (V)'); title('Three-phase phase voltages');
legend('V_a','V_b','V_c','Location','best'); grid on;
saveFig(fig,figuresDir,'three_phase_phase_voltages.png');
fig = figure('Visible','off','Color','w');
plot(tLine,uAB,tLine,uBC,tLine,uCA,'LineWidth',1.0);
xlabel('Time (s)'); ylabel('Line voltage (V)'); title('Three-phase line voltages');
legend('U_{ab}','U_{bc}','U_{ca}','Location','best'); grid on;
saveFig(fig,figuresDir,'three_phase_line_voltages.png');
fig = figure('Visible','off','Color','w');
plot(tCurrent,iA,tCurrent,iB,tCurrent,iC,'LineWidth',1.0);
xlabel('Time (s)'); ylabel('Phase current (A)'); title('Three-phase load currents');
legend('I_a','I_b','I_c','Location','best'); grid on;
saveFig(fig,figuresDir,'three_phase_currents.png');

% Three inverter upper-gate commands over ten carrier cycles.
[tPwm,qA] = uniformWindow(sig.acac_qah,0.900,0.9008,1e6);
[~,qB] = uniformWindow(sig.acac_qbh,0.900,0.9008,1e6);
[~,qC] = uniformWindow(sig.acac_qch,0.900,0.9008,1e6);
fig = figure('Visible','off','Color','w');
stairs(tPwm,qA,'LineWidth',1.0); hold on; stairs(tPwm,qB+1.2,'LineWidth',1.0);
stairs(tPwm,qC+2.4,'LineWidth',1.0); ylim([-0.2 3.6]);
yticks([0.5 1.7 2.9]); yticklabels({'Q_{AH}','Q_{BH}','Q_{CH}'});
xlabel('Time (s)'); ylabel('Gate state (offset)'); title('Three-phase inverter PWM gates'); grid on;
saveFig(fig,figuresDir,'three_phase_pwm.png');

% Output: low-frequency harmonics and the inverter switching region.
[fOut,ampOut] = harmonicSpectrum(sig.acac_uab,0.80,1.00,200e3,60,50);
fig = figure('Visible','off','Color','w','Position',[100 100 1100 430]);
subplot(1,2,1); stem(fOut,ampOut,'Marker','none'); xline(60,'r--','60 Hz'); xlim([0 3000]);
xlabel('Frequency (Hz)'); ylabel('Amplitude (V)'); title('60 Hz and harmonics'); grid on;
[fWide,aWide] = broadbandSpectrum(sig.acac_uab,0.80,1.00,200e3);
subplot(1,2,2); plot(fWide,aWide,'LineWidth',0.8); xlim([10000 16000]);
xline(12600,'r--','12.6 kHz PWM'); xlabel('Frequency (Hz)'); ylabel('Amplitude (V)');
title(sprintf('Switching region; THD %.2f%%',metrics.line_voltage_thd_percent(1))); grid on;
saveFig(fig,figuresDir,'output_voltage_spectrum.png');
[fIn,ampIn] = harmonicSpectrum(sig.acac_iin,0.80,1.00,200e3,50,50);
fig = figure('Visible','off','Color','w'); stem(fIn,ampIn,'Marker','none');
xlim([0 2500]); xlabel('Frequency (Hz)'); ylabel('Input-current amplitude (A)');
title(sprintf('Input-current spectrum, THD %.2f%%',metrics.input_current_thd_percent)); grid on;
saveFig(fig,figuresDir,'input_current_spectrum.png');

% Average input/output power and efficiency.
fig = figure('Visible','off','Color','w'); yyaxis left;
bar([metrics.input_real_power_W metrics.output_real_power_W]);
set(gca,'XTickLabel',{'P_{in}','P_{out}'}); ylabel('Power (W)');
yyaxis right; yline(100*metrics.efficiency,'r--','LineWidth',1.4);
ylabel('Efficiency (%)'); ylim([0 100]); title('Power and efficiency'); grid on;
saveFig(fig,figuresDir,'power_efficiency.png');

% Compact Markdown validation record.
reportPath = fullfile(projectDir,'docs','acac_first_four_validation.md');
if ~exist(fileparts(reportPath),'dir'), mkdir(fileparts(reportPath)); end
fid = fopen(reportPath,'w');
assert(fid >= 0,'Could not create validation report.');
fprintf(fid,'# AC-AC Converter: First Four Requirements\n\n');
fprintf(fid,'Full integrated Simscape switching run, MATLAB/Simulink R2024a.\n\n');
fprintf(fid,'| Metric | Result | Gate | Status |\n|---|---:|---:|---|\n');
fprintf(fid,'| Uab/Ubc/Uca RMS | %.3f / %.3f / %.3f V | 32.0 ± 0.1 V | %s |\n', ...
    metrics.line_voltage_rms_V,passText(metrics.pass.line_voltage));
fprintf(fid,'| Output frequency | %.4f Hz | 59.8–60.2 Hz | %s |\n', ...
    metrics.output_frequency_Hz,passText(metrics.pass.output_frequency));
fprintf(fid,'| Ia/Ib/Ic RMS | %.3f / %.3f / %.3f A | 1.9–2.1 A | %s |\n', ...
    metrics.phase_current_rms_A,passText(metrics.pass.phase_current));
fprintf(fid,'| Input PF | %.5f | ≥ 0.98 | %s |\n', ...
    metrics.input_power_factor,passText(metrics.pass.input_power_factor));
fprintf(fid,'| Efficiency | %.3f%% | ≥ 95%% | %s |\n', ...
    100*metrics.efficiency,passText(metrics.pass.efficiency));
fprintf(fid,'| Uab/Ubc/Uca THD | %.3f / %.3f / %.3f%% | ≤ 2%% | %s |\n', ...
    metrics.line_voltage_thd_percent,passText(metrics.pass.line_voltage_thd));
fprintf(fid,'| Gate-pair simultaneous maximum | %.0f | ≤ 1 | %s |\n', ...
    metrics.max_gate_pair_sum,passText(metrics.pass.no_shoot_through));
fprintf(fid,'| DC bus mean / range | %.3f / %.3f V | nominal 60 V | measured |\n', ...
    metrics.dc_bus_mean_V,metrics.dc_bus_range_V);
fprintf(fid,'| Input-current THD | %.3f%% | informational | measured |\n', ...
    metrics.input_current_thd_percent);
fprintf(fid,'| Precharge bypass times | %.6f / %.6f s | two-stage latch | measured |\n\n', ...
    metrics.precharge_bypass_time_s,metrics.final_precharge_bypass_time_s);
fprintf(fid,'Overall result: **%s**.\n\n',passText(metrics.overall_pass));
fprintf(fid,'Metrics: `../results/acac_full_metrics.json`; raw simulation: `../results/acac_full_results.mat`.\n');
fclose(fid);

function [t,x] = windowSeries(ts,a,b)
tAll = ts.Time(:);
xAll = double(ts.Data(:));
[tAll,iu] = unique(tAll,'stable');
xAll = xAll(iu);
ix = tAll >= a & tAll <= b;
t = [a; tAll(ix); b];
x = [interp1(tAll,xAll,a,'linear'); xAll(ix); interp1(tAll,xAll,b,'linear')];
[t,iu] = unique(t,'stable');
x = x(iu);
end

function v = seriesRMS(ts,a,b)
[t,x] = windowSeries(ts,a,b);
v = sqrt(trapz(t,x.^2)/(b-a));
end

function v = seriesMean(ts,a,b)
[t,x] = windowSeries(ts,a,b);
v = trapz(t,x)/(b-a);
end

function v = seriesRange(ts,a,b)
[~,x] = windowSeries(ts,a,b);
v = max(x)-min(x);
end

function p = averageProduct(tsA,tsB,a,b)
[tA,xA] = windowSeries(tsA,a,b);
[tB,xB] = windowSeries(tsB,a,b);
p = trapz(tA,xA.*interp1(tB,xB,tA,'linear'))/(b-a);
end

function tFirst = firstHighTime(ts)
ix = find(double(ts.Data(:)) > 0.5,1,'first');
if isempty(ix), tFirst = NaN; else, tFirst = ts.Time(ix); end
end

function f = positiveCrossingFrequency(ts,a,b,fs)
[~,x] = uniformWindow(ts,a,b,fs);
tu = a+(0:numel(x)-1)'/fs;
ix = find(x(1:end-1) <= 0 & x(2:end) > 0);
tz = tu(ix) - x(ix).*(tu(ix+1)-tu(ix))./(x(ix+1)-x(ix));
f = 1/mean(diff(tz));
end

function thd = harmonicTHD(ts,a,b,fs,f0)
N = round((b-a)*fs);
[~,x] = uniformWindow(ts,a,b,fs);
x = x(1:N)-mean(x(1:N));
Y = fft(x);
k0 = round(f0*(b-a));
h = (2:50)';
ratios = abs(Y(h*k0+1))/abs(Y(k0+1));
thd = 100*sqrt(sum(ratios.^2));
end

function thd = broadbandTHD(ts,a,b,fs,f0)
N = round((b-a)*fs);
[~,x] = uniformWindow(ts,a,b,fs);
x = x(1:N)-mean(x(1:N));
Y = fft(x);
k0 = round(f0*(b-a));
fundamentalEnergy = 2*abs(Y(k0+1))^2;
totalAcEnergy = 2*sum(abs(Y(2:floor(N/2)+1)).^2);
thd = 100*sqrt(max(0,totalAcEnergy-fundamentalEnergy)/fundamentalEnergy);
end

function [t,x] = uniformWindow(ts,a,b,fs)
N = round((b-a)*fs);
t = a+(0:N-1)'/fs;
tAll = ts.Time(:);
xAll = double(ts.Data(:));
[tAll,iu] = unique(tAll,'stable');
xAll = xAll(iu);
x = interp1(tAll,xAll,t,'linear');
end

function [f,amp] = harmonicSpectrum(ts,a,b,fs,f0,maxHarmonic)
N = round((b-a)*fs);
[~,x] = uniformWindow(ts,a,b,fs);
x = x(1:N)-mean(x(1:N));
Y = fft(x);
h = (1:maxHarmonic)';
k0 = round(f0*(b-a));
bins = h*k0+1;
f = h*f0;
amp = 2*abs(Y(bins))/N;
end

function ph = fundamentalPhasor(ts,a,b,fs,f0)
N = round((b-a)*fs);
[~,x] = uniformWindow(ts,a,b,fs);
x = x(1:N)-mean(x(1:N));
Y = fft(x);
k0 = round(f0*(b-a));
ph = 2*Y(k0+1)/N;
end

function [f,amp] = broadbandSpectrum(ts,a,b,fs)
N = round((b-a)*fs);
[~,x] = uniformWindow(ts,a,b,fs);
Y = fft(x(1:N)-mean(x(1:N)));
k = (0:floor(N/2))';
f = k*fs/N;
amp = 2*abs(Y(k+1))/N;
end

function saveFig(fig,folder,fileName)
exportgraphics(fig,fullfile(folder,fileName),'Resolution',180);
close(fig);
end

function s = passText(tf)
if tf, s = 'PASS'; else, s = 'FAIL'; end
end
