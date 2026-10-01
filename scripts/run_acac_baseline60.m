% Regression of Requirements 1-4 on the retained frequency-parameterized model.
projectDir = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectDir,'models'));
addpath(fullfile(projectDir,'scripts'));
mdl = 'acac_30hz_r2024a';
load_system(fullfile(projectDir,'models',[mdl '.slx']));
[m,w,o] = acac_run_case(mdl,36,2,60,1.0,[0.8 1.0]);
m.requirement_1_pass = all(abs(m.Uline_rms_V-32)<=0.1) ...
    && all(abs(m.output_frequency_measured_Hz-60)<=0.2) ...
    && all(abs(m.Iline_rms_A-2)<=0.02);
m.requirement_2_pass = m.input_PF>=0.98;
m.requirement_3_pass = m.efficiency_percent>=95;
m.requirement_4_pass = all(m.output_THD_2to50_percent<=2) ...
    && all(m.output_broadband_residual_percent<=2);
m.baseline_pass = m.requirement_1_pass && m.requirement_2_pass ...
    && m.requirement_3_pass && m.requirement_4_pass && m.no_shootthrough;
fprintf('BASELINE_60 U=[%.4f %.4f %.4f] f=[%.4f %.4f %.4f] PF=%.5f eta=%.3f%% THDmax=%.3f%% PASS=%d\n', ...
    m.Uline_rms_V,m.output_frequency_measured_Hz,m.input_PF,m.efficiency_percent, ...
    max(m.output_broadband_residual_percent),m.baseline_pass);
save(fullfile(projectDir,'results','acac_baseline_60hz_results.mat'),'m','w','o','-v7.3');
fid=fopen(fullfile(projectDir,'results','acac_baseline_60hz_metrics.json'),'w');
assert(fid>=0); fwrite(fid,jsonencode(m,'PrettyPrint',true),'char'); fclose(fid);
clear m w o
