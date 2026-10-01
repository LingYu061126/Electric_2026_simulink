% PFC startup/precharge check before enabling the three-phase bridge at 0.18 s.
projectDir = fileparts(fileparts(mfilename('fullpath')));
mdl = 'acac_single_to_three_phase_r2024a';
load_system(fullfile(projectDir,'models',[mdl '.slx']));
simIn = Simulink.SimulationInput(mdl);
simIn = simIn.setModelParameter('StopTime','0.179');
simOut = sim(simIn);

vin = simOut.get('acac_vin');
iin = simOut.get('acac_iin');
vdc = simOut.get('acac_vdc');
precharge = simOut.get('acac_precharge_bypass');
assert(all(isfinite(vin.Data(:))) && all(isfinite(iin.Data(:))) && ...
    all(isfinite(vdc.Data(:))), 'PFC startup has a nonfinite voltage/current sample.');
[iPeak,kPeak] = max(abs(iin.Data(:)));
kBypass = find(precharge.Data > 0.5,1,'first');
if isempty(kBypass)
    bypassTime = NaN;
else
    bypassTime = precharge.Time(kBypass);
end
steady = vdc.Time >= 0.16 & vdc.Time <= 0.179;
fprintf('PRECHARGE_CHECK stop=%.3f s Vdc_end=%.3f V Vdc_160_179ms=[%.3f, %.3f] V\n', ...
    simOut.tout(end),vdc.Data(end),min(vdc.Data(steady)),max(vdc.Data(steady)));
fprintf('Input current peak=%.3f A at %.6f s (vin=%.3f V); bypass first closes at %.6f s\n', ...
    iPeak,iin.Time(kPeak),vin.Data(kPeak),bypassTime);
save(fullfile(projectDir,'results','acac_precharge_check.mat'),'simOut','-v7.3');
