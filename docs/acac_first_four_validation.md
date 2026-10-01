# AC-AC Converter First Four Requirements

## Overall validation

| Step | Result |
|---|---|
| Created | Independent R2024a integrated model and two derived stage models |
| Opened | All three saved `.slx` models loaded in MATLAB R2024a |
| Model check | Healthy after final structural edits |
| Compiled | Simulink update completed on each model |
| Simulated | Real Simscape switching, 1.000 s on each model |
| Measured | 0.800–1.000 s; 10 input cycles and 12 output cycles |
| Validated | PASS for staged evidence and integrated four gates |

The integrated result comes from the physical 20 kHz totem-pole PFC, 4700 µF DC link, six-switch 12.6 kHz VSI, LC filter, and floating Y load running together. **Assumption: `Uo` is RMS line-to-line voltage.** No measured gate is inferred from a reference value.

## Architecture

| Part | Implemented configuration |
|---|---|
| PFC | Bridgeless totem-pole boost; fast leg 20 kHz PWM, slow leg 50 Hz polarity commutation; 1 mH boost inductor |
| DC bus | 60 V reference; 4700 µF capacitor, 40 mΩ ESR; staged precharge |
| Inverter | Three legs, six physical MOSFETs; 12.6 kHz sinusoidal PWM, 1 µs turn-on dead time |
| Output filter | Per phase 1 mH, 25.33029591 µF, 1 Ω capacitor-series damping; nominal 1 kHz resonance |
| Output control | 60 Hz internal angle, three measured phase-RMS PI amplitude trims, modulation limited to 0.95 |
| Load | Three 9.237604307 Ω resistors, floating star point |

## Requirement 1 — input and balanced three-phase output

Input: `Ui=36.000000 V RMS`, measured `fi=50.0000 Hz`. Measured line voltages: `Uab=32.010 V`, `Ubc=32.008 V`, `Uca=32.009 V`; each must lie in 31.9–32.1 V. Measured output frequency from `Uab` positive zero crossings: `60.0099 Hz` (gate 59.8–60.2 Hz). Load currents: `Ia=2.0007 A`, `Ib=2.0006 A`, `Ic=2.0005 A`, average `2.0006 A` (approximately 2 A). Fundamental phase separations A–B/B–C/C–A: `120.004° / 119.996° / 120.000°`; maximum line-RMS imbalance `0.0044%`.

**Requirement 1: PASS.**

## Requirement 2 — input power factor

From the integrated source-side physical `vin(t)` and `iin(t)` sensors: `Pin=mean(vin·iin)=115.937 W`, `Vrms=36.000 V`, `Irms=3.2303 A`, and **total PF=0.99694** (gate ≥0.98). The separate fundamental displacement factor is `0.99995` and input-current harmonic THD (2nd–50th, 50 Hz bins) is `5.749%`. Total PF includes both displacement and distortion.

**Requirement 2: PASS.**

## Requirement 3 — integrated model efficiency and power balance

Steady-state physical measurements: `Pin=115.937 W` at the AC source, `Pdc=112.703 W` from the DC bus voltage times the series inverter-input current sensor, and `Pout=110.915 W` from `mean(va·ia + vb·ib + vc·ic)` at the three resistive load phases. A separate series sensor at the PFC output measured `Idc,PFC=1.8968 A` mean and `mean(Vdc·Idc,PFC)=113.958 W`. `Ploss=Pin−Pout=5.022 W`, partitioned into `Pin−Pdc=3.234 W` before the inverter current sensor and `Pdc−Pout=1.789 W` after it. These values satisfy `Pin>Pdc>Pout` and close the measured power balance. **Model efficiency=95.668%** (gate ≥95%).

**Requirement 3: PASS in the declared Simscape loss model.** This is a model result, not a hardware efficiency prediction.

## Requirement 4 — line-voltage distortion

Coherent 0.800–1.000 s window (12 cycles at 60 Hz), uniform 200 kHz interpolation. Using FFT harmonic bins 2–50 relative to the 60 Hz fundamental: `THD_Uab=0.882%`, `THD_Ubc=0.827%`, `THD_Uca=0.901%`. The more conservative **broadband residual RMS** through the 100 kHz Nyquist limit, excluding DC and the 60 Hz bin, is `1.250% / 1.222% / 1.278%`, maximum `1.278%`. Both sets are below the 2% gate on all three lines. The spectrum plot separately shows low-order harmonics and the 12.6 kHz switching region.

**Requirement 4: PASS.**

## DC link and startup

Reference 60 V; integrated steady mean `60.000 V`; sampled peak-to-peak ripple `1.585 V`; mean regulation error `0.0003%`. Bus mean just before inverter enable (0.14–0.18 s) was `60.923 V`; in the load-pickup transient (0.24–0.28 s), `57.618 V`, recovering to the steady mean above. Startup bus peak during 0–0.30 s was `63.742 V`, or `3.742 V` above the 60 V reference. The 10 Ω and 2 Ω precharge bypasses switched at `0.079688 s` and `0.129688 s`. Maximum startup source current was `8.829 A`. Single-phase input power imposes a 100 Hz link ripple; the outer voltage loop is deliberately below that frequency.

## Stage checks

The stage models were derived from the saved integrated model and checked separately after integration; their results are supporting evidence, while the four acceptance gates above use the integrated run.

- **PFC operating check:** physical PFC with inverter gate commands disabled and a switched 30.5 Ω equivalent bus load (approximately 118 W), enabled at 0.18 s after precharge. It measured `60.001 V` mean, `1.506 V` ripple, `0.002%` regulation error, PF `0.99709`, fundamental DPF `0.99995`, input-current THD `5.673%`, `Pin=120.995 W`, DC load current `1.9673 A` from the saved `Vdc(t)/30.5 Ω` waveform, and load power `118.045 W`; status **PASS**. The near-unity DPF and PF support the measured input current following the source voltage. This model retains the electrically inactive inverter network; its inverter gate maximum is `0`.
- **Fixed-DC inverter check:** 60 V physical DC source, physical VSI, LC filter, floating Y load and closed-loop output controller. Measured `Uab/Ubc/Uca=32.010/32.009/32.009 V`, `Ia/Ib/Ic=2.001/2.001/2.001 A`, `f=60.0049 Hz`, 2nd–50th THD `0.865/0.868/0.866%`, and broadband residual `1.250/1.245/1.259%`; status **PASS**.

## Gate safety

Simultaneous high/low command samples in the integrated inverter legs: A `0`, B `0`, C `0`. The fast and slow PFC leg command sums and inverter leg sums never exceeded one. Gate safety **PASS**.

## Control and loss model

PFC outer bus PI: `Kp=0.012 S/V`, `Ki=0.50 S/(V·s)`, 150 ms reference ramp, conductance limit 0–0.11 S. Inner current PI: `Kp=0.105`, `Ki=66 s⁻¹`, signed `i_ref=g·vin`, boost duty feedforward and 0.02–0.95 duty clamp. Averaged-model crossover estimates: outer 10.41 Hz/57.5° phase margin, inner 1.008 kHz/75.3° phase margin; see the design report for assumptions. The VSI uses independent phase-RMS PI trims and 1 µs dead time.

Losses modeled: 50 mΩ external resistor per MOSFET (four PFC and six inverter devices), 80 mΩ boost-inductor winding, 80 mΩ per output-filter inductor, 40 mΩ DC-capacitor ESR, and 1 Ω series resistance per output capacitor. The output filter's linear loaded estimate is `f_n≈954 Hz`, `Q≈1.24`, with a 1.35×/2.62 dB resonance peak near 787 Hz; its 1 Ω capacitor-series resistor provides damping. The chosen ideal-switch MOSFETs omit switching-transition energy, temperature dependence and device-specific diode forward-loss calibration. `daessc` was used with 1 µs maximum step and `1e−4` relative tolerance.

## Problems encountered and fixes

1. The initial load-star wiring connected the neutral incorrectly; connecting the Y neutral to the filter capacitor neutral while keeping both floating restored balanced output.
2. Structural model edits were not always saved before later calls; saving immediately after each edit and verifying the saved `.slx` preserved all three voltage-feedback inputs.
3. The initial 30.5 Ω PFC-only load applied at t=0 held the precharged bus near 6.4 V. A physical switch now enables that load at 0.18 s, matching the staged integrated startup; the rerun passed.
4. Earlier stiff-solvers were impractical for the full fast-switching model; `daessc` with a 1 µs maximum step produced a complete 1 s run and finite signals.

## Files

- Integrated model: [../models/acac_single_to_three_phase_r2024a.slx](../models/acac_single_to_three_phase_r2024a.slx)
- PFC stage model: [../models/acac_pfc_standalone_r2024a.slx](../models/acac_pfc_standalone_r2024a.slx)
- Fixed-DC inverter model: [../models/acac_inverter_fixed_dc_r2024a.slx](../models/acac_inverter_fixed_dc_r2024a.slx)
- Integrated raw MAT: [../results/acac_full_results.mat](../results/acac_full_results.mat)
- Integrated JSON: [../results/acac_full_metrics.json](../results/acac_full_metrics.json)
- PFC stage [MAT](../results/acac_pfc_standalone_results.mat) and [JSON](../results/acac_pfc_standalone_metrics.json)
- Inverter stage [MAT](../results/acac_inverter_fixed_dc_results.mat) and [JSON](../results/acac_inverter_fixed_dc_metrics.json)
- Design report: [../docs/acac_system_design.md](../docs/acac_system_design.md)
- Full validation script: [../scripts/run_acac_full_validation.m](../scripts/run_acac_full_validation.m)

### Figures

- [acac_system_overview.png](../results/acac_system_overview.png)
- [pfc_input_voltage_current.png](../results/pfc_input_voltage_current.png)
- [pfc_dc_bus.png](../results/pfc_dc_bus.png)
- [pfc_duty.png](../results/pfc_duty.png)
- [three_phase_phase_voltages.png](../results/three_phase_phase_voltages.png)
- [three_phase_line_voltages.png](../results/three_phase_line_voltages.png)
- [three_phase_currents.png](../results/three_phase_currents.png)
- [three_phase_pwm.png](../results/three_phase_pwm.png)
- [output_voltage_spectrum.png](../results/output_voltage_spectrum.png)
- [input_current_spectrum.png](../results/input_current_spectrum.png)
- [power_efficiency.png](../results/power_efficiency.png)

## Remaining limitations

The modeled efficiency excludes switching-transition, thermal and magnetic core losses. The quoted PI phase margins are from averaged design equations, not measured loop injection. The conventional harmonic THD sums bins 2–50 of the 60 Hz fundamental; the separate broadband residual also includes switching ripple near 12.6 kHz and other nonfundamental energy through 100 kHz. The PFC stage model keeps an electrically inactive inverter network during its equivalent-load test. These limitations do not change the stated integrated simulation measurements.

## Final conclusion

| Requirement | Result |
|---|---|
| 1. 36 V/50 Hz to 32 V/60 Hz/2 A balanced three-phase | PASS |
| 2. Total input PF ≥0.98 | PASS |
| 3. Declared-model efficiency ≥95% | PASS |
| 4. All three line-voltage THDs ≤2% | PASS |

**First four requirements passed: YES.** MATLAB R2024a's complete physical Simscape Electrical switching model achieved the specified single-phase 36 V/50 Hz input through active PFC and a real DC link to balanced three-phase 32 V/60 Hz/2 A output, with total PF ≥0.98, declared-model efficiency ≥95%, and all three line-voltage THDs ≤2%, based on the integrated steady-state measurements above.
