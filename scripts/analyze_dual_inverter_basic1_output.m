function metrics = analyze_dual_inverter_basic1_output(out,resultsDir)
% Analyze saved Basic-1 switching-simulation outputs and write its metrics.
vOut = out.get('vOut');
IoTotal = out.get('Io_total');
ILoad = out.get('I_load');
Io1 = out.get('TP_Io1');
Io2 = out.get('TP_Io2');
Vdc1 = out.get('Vdc');
Idc1 = out.get('iDC');

tV = double(vOut.Time(:));
v = double(squeeze(vOut.Data));
v = v(:);
tIo = double(IoTotal.Time(:));
io = double(squeeze(IoTotal.Data));
io = io(:);
tLoad = double(ILoad.Time(:));
iLoad = double(squeeze(ILoad.Data));
iLoad = iLoad(:);
tIo1 = double(Io1.Time(:));
io1 = double(squeeze(Io1.Data));
io1 = io1(:);
tIo2 = double(Io2.Time(:));
io2 = double(squeeze(Io2.Data));
io2 = io2(:);
tDcV = double(Vdc1.Time(:));
vdc = double(squeeze(Vdc1.Data));
tDcI = double(Idc1.Time(:));
idc = double(squeeze(Idc1.Data));
assert(all([numel(tV),numel(tIo),numel(tLoad),numel(tIo1),numel(tIo2),numel(tDcV),numel(tDcI)] > 1), ...
    'Basic-1 signal logs are empty or too short.');

tEndAvailable = min([tV(end),tIo(end),tLoad(end),tIo1(end),tIo2(end),tDcV(end),tDcI(end)]);
tGridEnd = floor(tEndAvailable*1e6)/1e6;
assert(tGridEnd > 0.10,'Logged signals do not cover the steady-state measurement window.');
tGrid = (0.10:1e-6:tGridEnd)';
vGrid = interp1(tV,v,tGrid,'linear');
ioGrid = interp1(tIo,io,tGrid,'linear');
iLoadGrid = interp1(tLoad,iLoad,tGrid,'linear');
io1Grid = interp1(tIo1,io1,tGrid,'linear');
io2Grid = interp1(tIo2,io2,tGrid,'linear');
vdcGrid = interp1(tDcV,vdc(:),tGrid,'linear');
idcGrid = interp1(tDcI,idc(:),tGrid,'linear');
assert(all(isfinite([vGrid;ioGrid;iLoadGrid;io1Grid;io2Grid;vdcGrid;idcGrid])), ...
    'Basic-1 signals contain nonfinite or out-of-range samples.');

UoRms = sqrt(mean(vGrid.^2));
fo = fminbnd(@(f) sinFitResidual(vGrid,tGrid,f),49,51);
IoRms = sqrt(mean(ioGrid.^2));
ILoadRms = sqrt(mean(iLoadGrid.^2));
Io1Rms = sqrt(mean(io1Grid.^2));
Io2Rms = sqrt(mean(io2Grid.^2));

gateTime = double(out.get('Inv1_gate1').Time(:));
inv1Gates = false(numel(gateTime),4);
inv2Gates = false(numel(gateTime),4);
for k = 1:4
    sig1 = out.get(sprintf('Inv1_gate%d',k));
    sig2 = out.get(sprintf('Inv2_gate%d',k));
    inv1Gates(:,k) = interp1(double(sig1.Time(:)),double(squeeze(sig1.Data)),gateTime,'previous','extrap') > 0.5;
    inv2Gates(:,k) = interp1(double(sig2.Time(:)),double(squeeze(sig2.Data)),gateTime,'previous','extrap') > 0.5;
end
overlapA1 = nnz(inv1Gates(:,1) & inv1Gates(:,2));
overlapB1 = nnz(inv1Gates(:,3) & inv1Gates(:,4));
overlapA2 = nnz(inv2Gates(:,1) & inv2Gates(:,2));
overlapB2 = nnz(inv2Gates(:,3) & inv2Gates(:,4));
inv2GateHighSamples = nnz(any(inv2Gates,2));
Pout1 = mean(vGrid.*io1Grid);
Pdc = mean(vdcGrid.*idcGrid);

metrics = struct();
metrics.stage = 'Basic-1';
metrics.inverter1_enabled = true;
metrics.inverter2_enabled = false;
metrics.S1_closed = true;
metrics.S_Load_closed = true;
metrics.S2_open = true;
metrics.R_load_Ohm = 12;
metrics.Uo_rms_V = UoRms;
metrics.output_frequency_Hz = fo;
metrics.Io_total_rms_A = IoRms;
metrics.Io1_rms_A = Io1Rms;
metrics.Io2_rms_A = Io2Rms;
metrics.I_load_rms_A = ILoadRms;
metrics.Pout1_W = Pout1;
metrics.Pout_W = Pout1;
metrics.Pdc1_W = Pdc;
metrics.steady_window_s = [tGrid(1),tGrid(end)];
metrics.measurement_sample_rate_Hz = 1e6;
metrics.gate_overlap_inv1_legA_samples = overlapA1;
metrics.gate_overlap_inv1_legB_samples = overlapB1;
metrics.gate_overlap_inv2_legA_samples = overlapA2;
metrics.gate_overlap_inv2_legB_samples = overlapB2;
metrics.inv2_gate_high_samples = inv2GateHighSamples;
metrics.pass = UoRms >= 23.8 && UoRms <= 24.2 && ...
    fo >= 49.8 && fo <= 50.2 && IoRms >= 1.8 && IoRms <= 2.2 && ...
    overlapA1 == 0 && overlapB1 == 0 && overlapA2 == 0 && overlapB2 == 0 && ...
    inv2GateHighSamples == 0 && Io2Rms <= 1e-3;

fprintf('BASIC1_RESULT Uo=%.6f Vrms, f=%.6f Hz, Io=%.6f Arms, Io1=%.6f Arms, Io2=%.9g Arms, Iload=%.6f Arms, Pout1=%.5f W, Pdc1=%.5f W, overlap Inv1 A/B=%d/%d Inv2 A/B=%d/%d, PASS=%d\n', ...
    UoRms,fo,IoRms,Io1Rms,Io2Rms,ILoadRms,Pout1,Pdc,overlapA1,overlapB1,overlapA2,overlapB2,metrics.pass);

jsonFile = fullfile(resultsDir,'basic1_metrics.json');
fid = fopen(jsonFile,'w');
assert(fid >= 0,'Could not create Basic-1 JSON result.');
fwrite(fid,jsonencode(metrics,'PrettyPrint',true),'char');
fclose(fid);
end

function e = sinFitResidual(x,t,f)
x = double(x(:));
t = double(t(:));
X = [ones(size(t)),cos(2*pi*f*t),sin(2*pi*f*t)];
c = X\x;
r = x-X*c;
e = mean(r.^2);
end
