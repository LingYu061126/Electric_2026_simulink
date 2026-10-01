function [metrics, wave] = acac_measure_run(out, outputFrequencyHz, inputFrequencyHz, window)
% Measure one complete Simscape switching run in a coherent steady window.
arguments
    out Simulink.SimulationOutput
    outputFrequencyHz (1,1) double {mustBePositive}
    inputFrequencyHz (1,1) double {mustBePositive}
    window (1,2) double
end
t0 = window(1); t1 = window(2); fs = 200e3;
assert(t1 > t0 && t1 <= out.tout(end),'Window outside completed simulation.');
assert(abs((t1-t0)*outputFrequencyHz-round((t1-t0)*outputFrequencyHz))<1e-9);
assert(abs((t1-t0)*inputFrequencyHz-round((t1-t0)*inputFrequencyHz))<1e-9);
wave.t = (t0:1/fs:t1-1/fs)';
names = {'vin','iin','vdc','va','vb','vc','uab','ubc','uca','ia','ib','ic', ...
    'pfc_duty','inverter_modulation','idc_pfc','idc_inverter'};
for k = 1:numel(names)
    ts = out.get(['acac_' names{k}]);
    assert(~isempty(ts),'Missing logged signal: %s',names{k});
    assert(all(isfinite(double(ts.Data(:)))),'Nonfinite signal: %s',names{k});
    [tu,ix] = unique(ts.Time(:),'stable');
    x = double(ts.Data(:));
    wave.(names{k}) = interp1(tu,x(ix),wave.t,'linear');
    assert(all(isfinite(wave.(names{k}))), ...
        'Logged %s does not cover the %.6f-%.6f s measurement window (logged %.6f-%.6f s).', ...
        names{k},t0,t1,tu(1),tu(end));
end
metrics = struct();
metrics.stop_time_s = out.tout(end);
metrics.steady_window_s = window;
metrics.input_frequency_Hz = inputFrequencyHz;
metrics.output_frequency_reference_Hz = outputFrequencyHz;
metrics.input_voltage_rms_V = vectorRMS(wave.vin);
metrics.input_current_rms_A = vectorRMS(wave.iin);
metrics.input_power_W = mean(wave.vin.*wave.iin);
metrics.input_PF = metrics.input_power_W/(metrics.input_voltage_rms_V*metrics.input_current_rms_A);
metrics.Uline_rms_V = [vectorRMS(wave.uab),vectorRMS(wave.ubc),vectorRMS(wave.uca)];
metrics.Uline_average_V = mean(metrics.Uline_rms_V);
metrics.Iline_rms_A = [vectorRMS(wave.ia),vectorRMS(wave.ib),vectorRMS(wave.ic)];
metrics.Iline_average_A = mean(metrics.Iline_rms_A);
metrics.output_frequency_measured_Hz = [crossingFrequency(wave.t,wave.uab), ...
    crossingFrequency(wave.t,wave.ubc),crossingFrequency(wave.t,wave.uca)];
metrics.max_voltage_imbalance_percent = 100*max(abs(metrics.Uline_rms_V-metrics.Uline_average_V))/metrics.Uline_average_V;
pa = fundamental(wave.va,outputFrequencyHz,t1-t0,fs);
pb = fundamental(wave.vb,outputFrequencyHz,t1-t0,fs);
pc = fundamental(wave.vc,outputFrequencyHz,t1-t0,fs);
metrics.phase_separation_deg = mod(rad2deg(angle([pa/pb pb/pc pc/pa]))+180,360)-180;
metrics.output_THD_2to50_percent = [harmonicTHD(wave.uab,outputFrequencyHz,t1-t0,fs), ...
    harmonicTHD(wave.ubc,outputFrequencyHz,t1-t0,fs), ...
    harmonicTHD(wave.uca,outputFrequencyHz,t1-t0,fs)];
metrics.output_broadband_residual_percent = [broadbandResidual(wave.uab,outputFrequencyHz,t1-t0,fs), ...
    broadbandResidual(wave.ubc,outputFrequencyHz,t1-t0,fs), ...
    broadbandResidual(wave.uca,outputFrequencyHz,t1-t0,fs)];
metrics.input_current_THD_percent = harmonicTHD(wave.iin,inputFrequencyHz,t1-t0,fs);
metrics.input_displacement_factor = cos(angle(fundamental(wave.vin,inputFrequencyHz,t1-t0,fs)) ...
    -angle(fundamental(wave.iin,inputFrequencyHz,t1-t0,fs)));
metrics.dc_bus_mean_V = mean(wave.vdc);
metrics.dc_bus_pp_V = max(wave.vdc)-min(wave.vdc);
metrics.PFC_dc_output_current_mean_A = mean(wave.idc_pfc);
metrics.PFC_dc_output_power_W = mean(wave.vdc.*wave.idc_pfc);
metrics.inverter_dc_input_power_W = mean(wave.vdc.*wave.idc_inverter);
metrics.output_power_W = mean(wave.va.*wave.ia+wave.vb.*wave.ib+wave.vc.*wave.ic);
metrics.efficiency_percent = 100*metrics.output_power_W/metrics.input_power_W;
metrics.PFC_duty_min = min(wave.pfc_duty);
metrics.PFC_duty_max = max(wave.pfc_duty);
metrics.PFC_duty_saturation_samples = nnz(wave.pfc_duty<=0.020001 | wave.pfc_duty>=0.949999);
metrics.PFC_duty_floor_samples = nnz(wave.pfc_duty<=0.020001);
metrics.PFC_duty_ceiling_samples = nnz(wave.pfc_duty>=0.949999);
metrics.inverter_modulation_min = min(wave.inverter_modulation);
metrics.inverter_modulation_max = max(wave.inverter_modulation);
legNames = {'a','b','c'};
metrics.inverter_shootthrough_samples = zeros(1,3);
for k = 1:3
    upper = out.get(['acac_q' legNames{k} 'h']);
    lower = out.get(['acac_q' legNames{k} 'l']);
    metrics.inverter_shootthrough_samples(k) = nnz(double(upper.Data(:))+double(lower.Data(:))>1);
end
metrics.no_shootthrough = all(metrics.inverter_shootthrough_samples==0);
metrics.all_finite = all(structfun(@(x)all(isfinite(x(:))),wave));
end

function f = crossingFrequency(t,x)
ix = find(x(1:end-1)<=0 & x(2:end)>0);
assert(numel(ix)>=2,'Too few output voltage crossings.');
tc = t(ix)-x(ix).*(t(ix+1)-t(ix))./(x(ix+1)-x(ix));
f = 1/mean(diff(tc));
end

function ph = fundamental(x,f0,T,fs)
N = round(T*fs); k0 = round(f0*T);
y = fft(x(1:N)-mean(x(1:N)));
ph = 2*y(k0+1)/N;
end

function thd = harmonicTHD(x,f0,T,fs)
N = round(T*fs); k0 = round(f0*T);
y = fft(x(1:N)-mean(x(1:N)));
thd = 100*sqrt(sum(abs(y((2:50)*k0+1)).^2))/abs(y(k0+1));
end

function value = broadbandResidual(x,f0,T,fs)
N = round(T*fs); k0 = round(f0*T);
y = fft(x(1:N)-mean(x(1:N)));
e1 = 2*abs(y(k0+1))^2;
et = 2*sum(abs(y(2:floor(N/2)+1)).^2);
value = 100*sqrt(max(0,et-e1)/e1);
end

function value = vectorRMS(x)
value = sqrt(mean(x.^2));
end
