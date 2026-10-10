%% Basic-2: harmonic THD from the Basic-1 physical switching result
projectRoot = fileparts(fileparts(mfilename('fullpath')));
resultsDir = fullfile(projectRoot,'results');
inputFile = fullfile(resultsDir,'basic1_single_inverter.mat');
assert(isfile(inputFile),'Run Basic-1 before Basic-2.');
saved = load(inputFile,'out','metrics');
assert(saved.metrics.pass,'Basic-1 did not pass; stop before Basic-2.');

vOut = saved.out.get('vOut');
FsNominal = 1e6;
fFund = saved.metrics.output_frequency_Hz;
windowStart = 0.10;
windowCycles = 10;
windowDuration = windowCycles/fFund;
nSamples = floor(windowDuration*FsNominal);
Fs = nSamples/windowDuration;
tGrid = windowStart + (0:nSamples-1)'/Fs;
v = interp1(double(vOut.Time(:)),double(squeeze(vOut.Data(:))),tGrid,'linear');
v = v(:);

% Fit every integer harmonic directly, avoiding leakage from an FFT bin that
% is slightly offset from the measured fundamental frequency.
maxHarmonic = 50;
harmonicRms = zeros(maxHarmonic,1);
fundamentalFit = zeros(size(v));
dcOffset = NaN;
for h = 1:maxHarmonic
    phase = 2*pi*fFund*h*tGrid;
    X = [cos(phase),sin(phase),ones(size(tGrid))];
    coeff = X\v;
    harmonicRms(h) = hypot(coeff(1),coeff(2))/sqrt(2);
    if h == 1
        fundamentalFit = X*coeff;
        dcOffset = coeff(3);
    end
end

fundamentalRms = harmonicRms(1);
thdH2To50 = 100*sqrt(sum(harmonicRms(2:50).^2))/max(fundamentalRms,eps);
thdH2To40 = 100*sqrt(sum(harmonicRms(2:40).^2))/max(fundamentalRms,eps);
broadbandNonfund = 100*sqrt(mean((v-fundamentalFit).^2))/max(fundamentalRms,eps);

metrics = struct();
metrics.stage = 'Basic-2';
metrics.operating_point = 'Basic-1 rated single-inverter point';
metrics.window_start_s = windowStart;
metrics.window_end_s = windowStart + windowDuration;
metrics.window_cycles = windowCycles;
metrics.fundamental_frequency_Hz = fFund;
metrics.measurement_sample_rate_Hz = Fs;
metrics.THD_harmonics_2_to_50_percent = thdH2To50;
metrics.THD_through_40th_harmonic_percent = thdH2To40;
metrics.THD_broadband_nonfundamental_percent = broadbandNonfund;
metrics.THD_fullband_percent = broadbandNonfund; % retained for previous result consumers
metrics.fundamental_rms_V = fundamentalRms;
metrics.dc_offset_V = dcOffset;
metrics.harmonic_orders = (2:50)';
metrics.harmonic_rms_V = harmonicRms(2:50);
metrics.harmonic_percent_of_fundamental = 100*harmonicRms(2:50)/max(fundamentalRms,eps);
metrics.THD_limit_percent = 2;
metrics.pass = isfinite(thdH2To50) && thdH2To50 <= metrics.THD_limit_percent;

jsonFile = fullfile(resultsDir,'basic2_thd.json');
fid = fopen(jsonFile,'w');
assert(fid >= 0,'Could not create Basic-2 JSON result.');
fwrite(fid,jsonencode(metrics,'PrettyPrint',true),'char');
fclose(fid);

fig = figure('Visible','off','Color','w');
stem(2:50,metrics.harmonic_percent_of_fundamental,'filled','LineWidth',1);
grid on;
xlim([1 51]);
xlabel('Harmonic order');
ylabel('RMS amplitude (% of fundamental)');
title(sprintf('Basic-2 harmonics 2–50: THD %.3f%%',thdH2To50));
exportgraphics(fig,fullfile(resultsDir,'basic2_output_spectrum.png'),'Resolution',200);
close(fig);

fprintf(['BASIC2_RESULT THD(harmonics 2-50)=%.6f%%, THD(through 40th)=%.6f%%, ' ...
    'broadband nonfundamental=%.6f%%, PASS=%d\n'], ...
    thdH2To50,thdH2To40,broadbandNonfund,metrics.pass);
assert(metrics.pass,'Basic-2 THD gate failed; stop the sequential validation here.');
