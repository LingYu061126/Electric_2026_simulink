function [metrics,trace] = analyze_dual_inverter_grid_point(out,window)
% Analyze one real-switching grid-connected simulation run.
% The current reference error uses the measured common-bus sensor TP_Io.

dt = 1e-5;
t = (window(1):dt:(window(2)-dt))';
names = {'TP_grid_voltage_LV','TP_Io','TP_Io1','TP_Io2', ...
    'TP_grid_voltage_220V','TP_grid_secondary_current'};
x = cell(size(names));
for k = 1:numel(names)
    x{k} = getWindow(out,names{k},t);
end
assert(all(isfinite(vertcat(x{:}))), ...
    'Grid voltage/current logs contain NaN or Inf.');

vPrimary = x{1};
iPrimary = x{2};
i1 = x{3};
i2 = x{4};
vSecondary = x{5};
iSecondary = x{6};
vPrimaryRms = rmsValue(vPrimary);
iTotalRms = rmsValue(iPrimary);
i1Rms = rmsValue(i1);
i2Rms = rmsValue(i2);
vSecondaryRms = rmsValue(vSecondary);
iSecondaryRms = rmsValue(iSecondary);

[Pprimary,Qprimary,pfPrimary] = powerPQ(vPrimary,iPrimary,t,50);
[Psecondary,Qsecondary,pfSecondary] = powerPQ(vSecondary,iSecondary,t,50);
lock1 = getWindow(out,'PLL1_lock',t);
lock2 = getWindow(out,'PLL2_lock',t);
freq1 = getWindow(out,'PLL1_frequency_Hz',t);
freq2 = getWindow(out,'PLL2_frequency_Hz',t);
phase1 = getWindow(out,'PLL1_phase_error',t);
phase2 = getWindow(out,'PLL2_phase_error',t);
[gateOverlap,gateHigh] = gateChecks(out);

icirc = (i1-i2)/2;
half = floor(numel(t)/2);
icircFirst = rmsValue(icirc(1:half));
icircLast = rmsValue(icirc(half+1:end));

metrics = struct();
metrics.measurement_window_s = window;
metrics.grid_primary_voltage_rms_V = vPrimaryRms;
metrics.Io_total_rms_A = iTotalRms;
metrics.Io1_rms_A = i1Rms;
metrics.Io2_rms_A = i2Rms;
metrics.Io1_to_Io2_ratio = i1Rms/max(i2Rms,eps);
metrics.current_sharing_imbalance_percent = ...
    abs(i1Rms-i2Rms)/max(i1Rms+i2Rms,eps)*100;
metrics.circulating_current_rms_A = rmsValue(icirc);
metrics.circulating_current_first_half_rms_A = icircFirst;
metrics.circulating_current_last_half_rms_A = icircLast;
metrics.grid_secondary_voltage_rms_V = vSecondaryRms;
metrics.grid_secondary_current_rms_A = iSecondaryRms;
metrics.grid_primary_active_power_W = Pprimary;
metrics.grid_primary_reactive_power_var = Qprimary;
metrics.grid_primary_power_factor = pfPrimary;
metrics.grid_secondary_active_power_W = Psecondary;
metrics.grid_secondary_reactive_power_var = Qsecondary;
metrics.grid_secondary_power_factor = pfSecondary;
metrics.grid_secondary_current_thd_2_to_50_percent = harmonicThd(iSecondary,dt,50,50);
metrics.PLL1_frequency_mean_Hz = mean(freq1);
metrics.PLL2_frequency_mean_Hz = mean(freq2);
metrics.PLL1_lock_fraction = mean(lock1>0.5);
metrics.PLL2_lock_fraction = mean(lock2>0.5);
metrics.PLL1_phase_error_rms_pu = rmsValue(phase1);
metrics.PLL2_phase_error_rms_pu = rmsValue(phase2);
metrics.gate_overlap_samples = gateOverlap;
metrics.gates_nonoverlap = all(gateOverlap==0);
metrics.inverter1_gate_high_samples = gateHigh(1);
metrics.inverter2_gate_high_samples = gateHigh(2);
metrics.both_plls_locked = metrics.PLL1_lock_fraction>0.99 && ...
    metrics.PLL2_lock_fraction>0.99;
metrics.currents_bounded = max(abs([iPrimary;i1;i2;iSecondary]))<10;
numericValues = [vPrimaryRms,iTotalRms,i1Rms,i2Rms,vSecondaryRms, ...
    iSecondaryRms,Pprimary,Qprimary,pfPrimary,Psecondary,Qsecondary, ...
    pfSecondary,metrics.grid_secondary_current_thd_2_to_50_percent, ...
    mean(freq1),mean(freq2),metrics.PLL1_lock_fraction, ...
    metrics.PLL2_lock_fraction,metrics.PLL1_phase_error_rms_pu, ...
    metrics.PLL2_phase_error_rms_pu,metrics.circulating_current_rms_A];
metrics.all_measured_signals_finite = all(isfinite(numericValues)) && ...
    all(isfinite([vPrimary;iPrimary;i1;i2;vSecondary;iSecondary; ...
    lock1;lock2;freq1;freq2;phase1;phase2]));

trace = struct();
trace.time_s = t;
trace.grid_primary_voltage_V = vPrimary;
trace.Io_primary_A = iPrimary;
trace.Io1_A = i1;
trace.Io2_A = i2;
trace.circulating_current_A = icirc;
trace.grid_220V_voltage_V = vSecondary;
trace.grid_secondary_current_A = iSecondary;
trace.PLL1_frequency = getSeries(out,'PLL1_frequency_Hz');
trace.PLL2_frequency = getSeries(out,'PLL2_frequency_Hz');
trace.PLL1_lock = getSeries(out,'PLL1_lock');
trace.PLL2_lock = getSeries(out,'PLL2_lock');
trace.PLL1_phase_error = getSeries(out,'PLL1_phase_error');
trace.PLL2_phase_error = getSeries(out,'PLL2_phase_error');
trace.PLL1_theta = getSeries(out,'PLL1_theta');
trace.PLL2_theta = getSeries(out,'PLL2_theta');
end

function y = getWindow(out,name,t)
s = out.get(name);
ts = double(s.Time(:));
data = double(squeeze(s.Data));
y = interp1(ts,data(:),t,'linear');
end

function s = getSeries(out,name)
v = out.get(name);
s = struct('time_s',double(v.Time(:)),'data',double(squeeze(v.Data)));
s.data = s.data(:);
end

function [P,Q,pf] = powerPQ(v,i,t,f0)
X = [ones(size(t)),cos(2*pi*f0*t),sin(2*pi*f0*t)];
cv = X\v;
ci = X\i;
P = mean(v.*i);
Q = 0.5*(cv(2)*ci(3)-cv(3)*ci(2));
S = rmsValue(v)*rmsValue(i);
pf = P/max(S,eps);
end

function value = rmsValue(x)
value = sqrt(mean(x(:).^2));
end

function thd = harmonicThd(x,dt,f0,maxHarmonic)
x = x(:)-mean(x);
N = numel(x);
X = fft(x);
amplitude = 2*abs(X(1:floor(N/2)+1))/N;
binHz = 1/(N*dt);
fundamentalBin = round(f0/binHz);
bins = (1:maxHarmonic)*fundamentalBin+1;
assert(max(bins)<=numel(amplitude),'Sampling rate is too low for the requested THD range.');
fundamental = amplitude(bins(1));
thd = sqrt(sum(amplitude(bins(2:end)).^2))/max(fundamental,eps)*100;
end

function [overlap,gateHigh] = gateChecks(out)
gateTime = double(out.get('Inv1_gate1').Time(:));
g = false(numel(gateTime),8);
for k = 1:4
    s1 = out.get(sprintf('Inv1_gate%d',k));
    s2 = out.get(sprintf('Inv2_gate%d',k));
    g(:,k) = interp1(double(s1.Time(:)),double(squeeze(s1.Data)), ...
        gateTime,'previous','extrap')>0.5;
    g(:,k+4) = interp1(double(s2.Time(:)),double(squeeze(s2.Data)), ...
        gateTime,'previous','extrap')>0.5;
end
overlap = [nnz(g(:,1)&g(:,2)),nnz(g(:,3)&g(:,4)), ...
    nnz(g(:,5)&g(:,6)),nnz(g(:,7)&g(:,8))];
gateHigh = [nnz(any(g(:,1:4),2)),nnz(any(g(:,5:8),2))];
end
