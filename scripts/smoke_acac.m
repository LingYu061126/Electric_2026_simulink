% Short compile-and-run smoke check for the integrated R2024a model.
mdl = 'acac_single_to_three_phase_r2024a';
projectDir = fileparts(fileparts(mfilename('fullpath')));
load_system(fullfile(projectDir,'models',[mdl '.slx']));
simIn = Simulink.SimulationInput(mdl);
simIn = simIn.setModelParameter('StopTime','0.01');
simOut = sim(simIn);

vdcTs = simOut.get('acac_vdc');
vinTs = simOut.get('acac_vin');
iinTs = simOut.get('acac_iin');
dutyTs = simOut.get('acac_pfc_duty');
qfhTs = simOut.get('acac_qfh');
qflTs = simOut.get('acac_qfl');
qshTs = simOut.get('acac_qsh');
qslTs = simOut.get('acac_qsl');
assert(isa(vdcTs,'timeseries') && isa(vinTs,'timeseries') && isa(iinTs,'timeseries'), ...
    'Physical voltage/current channels were not returned as timeseries.');
assert(all(isfinite(vdcTs.Data(:))) && all(isfinite(vinTs.Data(:))) && all(isfinite(iinTs.Data(:))), ...
    'A smoke-run signal contains NaN or Inf.');
fprintf('SMOKE_OK stop=%.6f s samples=%d Vdc=[%.3f, %.3f] V Iin_peak=%.3f A\n', ...
    simOut.tout(end),numel(vdcTs.Data),min(vdcTs.Data(:)),max(vdcTs.Data(:)),max(abs(iinTs.Data(:))));
fprintf('PFC duty=[%.4f, %.4f] gate_on_counts=[%d %d %d %d]\n', ...
    min(dutyTs.Data(:)),max(dutyTs.Data(:)),nnz(qfhTs.Data),nnz(qflTs.Data),nnz(qshTs.Data),nnz(qslTs.Data));
save(fullfile(projectDir,'results','acac_smoke_results.mat'),'simOut','-v7.3');
