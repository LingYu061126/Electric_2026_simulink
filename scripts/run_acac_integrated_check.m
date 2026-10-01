% Integrated switching-model check with the three-phase load enabled.
projectDir = fileparts(fileparts(mfilename('fullpath')));
mdl = 'acac_single_to_three_phase_r2024a';
load_system(fullfile(projectDir,'models',[mdl '.slx']));
simIn = Simulink.SimulationInput(mdl);
simIn = simIn.setModelParameter('StopTime','0.50');
reuseCachedRun = exist('reuseAcacSimOut','var') == 1 && reuseAcacSimOut && ...
    exist('simOut','var') == 1 && isa(simOut,'Simulink.SimulationOutput');
if ~reuseCachedRun
    simOut = sim(simIn);
end
s = struct();
q = struct();

names = {'acac_vin','acac_iin','acac_vdc','acac_va','acac_vb','acac_vc', ...
    'acac_uab','acac_ubc','acac_uca','acac_ia','acac_ib','acac_ic', ...
    'acac_qah','acac_qal','acac_qbh','acac_qbl','acac_qch','acac_qcl'};
for k = 1:numel(names)
    s.(names{k}) = simOut.get(names{k});
    assert(all(isfinite(s.(names{k}).Data(:))), ...
        'Nonfinite samples in %s.',names{k});
end

% 0.35 to 0.50 s contains exactly nine 60 Hz output cycles and fifteen
% 50 Hz input cycles. Use time integration because Simscape uses variable steps.
t0 = 0.35;
t1 = 0.50;
fields = fieldnames(s);
for k = 1:numel(fields)
    z = s.(fields{k});
    raw = double(z.Data(:));
    tAll = z.Time(:);
    ix = tAll >= t0 & tAll <= t1;
    t = tAll(ix);
    x = raw(ix);
    t = [t0; t; t1];
    x = [interp1(tAll,raw,t0); x; interp1(tAll,raw,t1)];
    % Keep strict monotonic times if the solver reported an endpoint twice.
    [t,iu] = unique(t,'stable');
    x = x(iu);
    q.(fields{k}) = struct('t',t,'x',x,'avg',trapz(t,x)/(t1-t0), ...
        'rms',sqrt(trapz(t,x.^2)/(t1-t0)));
end

iinOnVin = interp1(q.acac_iin.t,q.acac_iin.x,q.acac_vin.t,'linear');
pin = trapz(q.acac_vin.t,q.acac_vin.x.*iinOnVin)/(t1-t0);
pout = 0;
for phase = {'a','b','c'}
    v = q.(['acac_v' phase{1}]);
    i = q.(['acac_i' phase{1}]);
    iOnV = interp1(i.t,i.x,v.t,'linear');
    pout = pout + trapz(v.t,v.x.*iOnV)/(t1-t0);
end
pf = pin/(q.acac_vin.rms*q.acac_iin.rms);
efficiency = pout/pin;
bus = q.acac_vdc;
busMin = min(bus.x);
busMax = max(bus.x);
overlap = max([max(s.acac_qah.Data(:)+s.acac_qal.Data(:)), ...
    max(s.acac_qbh.Data(:)+s.acac_qbl.Data(:)), ...
    max(s.acac_qch.Data(:)+s.acac_qcl.Data(:))]);

fprintf('INTEGRATED_CHECK stop=%.3f s steady_window=[%.3f, %.3f] s\n',simOut.tout(end),t0,t1);
fprintf('Ull_rms=[%.3f %.3f %.3f] V; Iphase_rms=[%.3f %.3f %.3f] A\n', ...
    q.acac_uab.rms,q.acac_ubc.rms,q.acac_uca.rms, ...
    q.acac_ia.rms,q.acac_ib.rms,q.acac_ic.rms);
fprintf('Vdc_mean=%.3f V range=[%.3f, %.3f] V; Pin=%.3f W Pout=%.3f W PF=%.5f eta=%.5f\n', ...
    bus.avg,busMin,busMax,pin,pout,pf,efficiency);
fprintf('Switch-leg simultaneous gate maximum=%.1f\n',overlap);
save(fullfile(projectDir,'results','acac_integrated_check.mat'),'simOut','-v7.3');
