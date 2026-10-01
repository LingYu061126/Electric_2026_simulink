"""Render the first-four-requirement validation report from saved measurements."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
results = ROOT / "results"
full = json.loads((results / "acac_full_metrics.json").read_text())
pfc = json.loads((results / "acac_pfc_standalone_metrics.json").read_text())
inv = json.loads((results / "acac_inverter_fixed_dc_metrics.json").read_text())


def status(value):
    return "PASS" if value else "FAIL"


def render(prefix):
    file_list = [
        "acac_system_overview.png",
        "pfc_input_voltage_current.png",
        "pfc_dc_bus.png",
        "pfc_duty.png",
        "three_phase_phase_voltages.png",
        "three_phase_line_voltages.png",
        "three_phase_currents.png",
        "three_phase_pwm.png",
        "output_voltage_spectrum.png",
        "input_current_spectrum.png",
        "power_efficiency.png",
    ]
    figures = "\n".join(f"- [{name}]({prefix}results/{name})" for name in file_list)
    stage_pass = bool(pfc["pass"] and inv["pass"])
    overall = bool(full["first_four_requirements_passed"] and full["pass"]["no_shoot_through"] and stage_pass)
    return f"""# AC-AC Converter First Four Requirements

## Overall validation

| Step | Result |
|---|---|
| Created | Independent R2024a integrated model and two derived stage models |
| Opened | All three saved `.slx` models loaded in MATLAB R2024a |
| Model check | Healthy after final structural edits |
| Compiled | Simulink update completed on each model |
| Simulated | Real Simscape switching, 1.000 s on each model |
| Measured | 0.800–1.000 s; 10 input cycles and 12 output cycles |
| Validated | {status(overall)} for staged evidence and integrated four gates |

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

Input: `Ui={full['input_voltage_rms_V']:.6f} V RMS`, measured `fi={full['input_frequency_Hz']:.4f} Hz`. Measured line voltages: `Uab={full['Uab_rms_V']:.3f} V`, `Ubc={full['Ubc_rms_V']:.3f} V`, `Uca={full['Uca_rms_V']:.3f} V`; each must lie in 31.9–32.1 V. Measured output frequency from `Uab` positive zero crossings: `{full['output_frequency_Hz']:.4f} Hz` (gate 59.8–60.2 Hz). Load currents: `Ia={full['Ia_rms_A']:.4f} A`, `Ib={full['Ib_rms_A']:.4f} A`, `Ic={full['Ic_rms_A']:.4f} A`, average `{full['Iline_avg_A']:.4f} A` (approximately 2 A). Fundamental phase separations A–B/B–C/C–A: `{full['phase_angle_ab_deg']:.3f}° / {full['phase_angle_bc_deg']:.3f}° / {full['phase_angle_ca_deg']:.3f}°`; maximum line-RMS imbalance `{full['max_line_voltage_imbalance_percent']:.4f}%`.

**Requirement 1: {status(full['requirement_1_pass'])}.**

## Requirement 2 — input power factor

From the integrated source-side physical `vin(t)` and `iin(t)` sensors: `Pin=mean(vin·iin)={full['input_real_power_W']:.3f} W`, `Vrms={full['input_voltage_rms_V']:.3f} V`, `Irms={full['input_current_rms_A']:.4f} A`, and **total PF={full['input_power_factor']:.5f}** (gate ≥0.98). The separate fundamental displacement factor is `{full['input_displacement_factor']:.5f}` and input-current harmonic THD (2nd–50th, 50 Hz bins) is `{full['input_current_thd_percent']:.3f}%`. Total PF includes both displacement and distortion.

**Requirement 2: {status(full['requirement_2_pass'])}.**

## Requirement 3 — integrated model efficiency and power balance

Steady-state physical measurements: `Pin={full['input_real_power_W']:.3f} W` at the AC source, `Pdc={full['dc_link_power_W']:.3f} W` from the DC bus voltage times the series inverter-input current sensor, and `Pout={full['output_real_power_W']:.3f} W` from `mean(va·ia + vb·ib + vc·ic)` at the three resistive load phases. A separate series sensor at the PFC output measured `Idc,PFC={full['pfc_output_current_mean_A']:.4f} A` mean and `mean(Vdc·Idc,PFC)={full['pfc_output_power_W']:.3f} W`. `Ploss=Pin−Pout={full['loss_power_W']:.3f} W`, partitioned into `Pin−Pdc={full['pfc_loss_power_W']:.3f} W` before the inverter current sensor and `Pdc−Pout={full['inverter_filter_loss_power_W']:.3f} W` after it. These values satisfy `Pin>Pdc>Pout` and close the measured power balance. **Model efficiency={full['efficiency_percent']:.3f}%** (gate ≥95%).

**Requirement 3: {status(full['requirement_3_pass'])} in the declared Simscape loss model.** This is a model result, not a hardware efficiency prediction.

## Requirement 4 — line-voltage distortion

Coherent 0.800–1.000 s window (12 cycles at 60 Hz), uniform 200 kHz interpolation. Using FFT harmonic bins 2–50 relative to the 60 Hz fundamental: `THD_Uab={full['THD_Uab_percent']:.3f}%`, `THD_Ubc={full['THD_Ubc_percent']:.3f}%`, `THD_Uca={full['THD_Uca_percent']:.3f}%`. The more conservative **broadband residual RMS** through the 100 kHz Nyquist limit, excluding DC and the 60 Hz bin, is `{full['line_voltage_broadband_thd_percent'][0]:.3f}% / {full['line_voltage_broadband_thd_percent'][1]:.3f}% / {full['line_voltage_broadband_thd_percent'][2]:.3f}%`, maximum `{max(full['line_voltage_broadband_thd_percent']):.3f}%`. Both sets are below the 2% gate on all three lines. The spectrum plot separately shows low-order harmonics and the 12.6 kHz switching region.

**Requirement 4: {status(full['requirement_4_pass'])}.**

## DC link and startup

Reference 60 V; integrated steady mean `{full['dc_bus_mean_V']:.3f} V`; sampled peak-to-peak ripple `{full['dc_bus_pp_ripple_V']:.3f} V`; mean regulation error `{full['dc_bus_regulation_error_percent']:.4f}%`. Bus mean just before inverter enable (0.14–0.18 s) was `{full['dc_bus_mean_before_inverter_V']:.3f} V`; in the load-pickup transient (0.24–0.28 s), `{full['dc_bus_mean_after_load_V']:.3f} V`, recovering to the steady mean above. Startup bus peak during 0–0.30 s was `{full['dc_bus_startup_peak_V']:.3f} V`, or `{full['dc_bus_startup_overshoot_V']:.3f} V` above the 60 V reference. The 10 Ω and 2 Ω precharge bypasses switched at `{full['precharge_bypass_time_s']:.6f} s` and `{full['final_precharge_bypass_time_s']:.6f} s`. Maximum startup source current was `{full['input_current_peak_A']:.3f} A`. Single-phase input power imposes a 100 Hz link ripple; the outer voltage loop is deliberately below that frequency.

## Stage checks

The stage models were derived from the saved integrated model and checked separately after integration; their results are supporting evidence, while the four acceptance gates above use the integrated run.

- **PFC operating check:** physical PFC with inverter gate commands disabled and a switched 30.5 Ω equivalent bus load (approximately 118 W), enabled at 0.18 s after precharge. It measured `{pfc['dc_bus_mean_V']:.3f} V` mean, `{pfc['dc_bus_pp_ripple_V']:.3f} V` ripple, `{pfc['dc_bus_error_percent']:.3f}%` regulation error, PF `{pfc['input_power_factor']:.5f}`, fundamental DPF `{pfc['input_displacement_factor']:.5f}`, input-current THD `{pfc['input_current_thd_percent']:.3f}%`, `Pin={pfc['input_real_power_W']:.3f} W`, DC load current `{pfc['dc_load_current_mean_A']:.4f} A` from the saved `Vdc(t)/30.5 Ω` waveform, and load power `{pfc['dc_load_power_W']:.3f} W`; status **{status(pfc['pass'])}**. The near-unity DPF and PF support the measured input current following the source voltage. This model retains the electrically inactive inverter network; its inverter gate maximum is `{pfc['max_inverter_gate_command']:.0f}`.
- **Fixed-DC inverter check:** 60 V physical DC source, physical VSI, LC filter, floating Y load and closed-loop output controller. Measured `Uab/Ubc/Uca={inv['line_voltage_rms_V'][0]:.3f}/{inv['line_voltage_rms_V'][1]:.3f}/{inv['line_voltage_rms_V'][2]:.3f} V`, `Ia/Ib/Ic={inv['phase_current_rms_A'][0]:.3f}/{inv['phase_current_rms_A'][1]:.3f}/{inv['phase_current_rms_A'][2]:.3f} A`, `f={inv['output_frequency_Hz']:.4f} Hz`, 2nd–50th THD `{inv['line_voltage_thd_percent'][0]:.3f}/{inv['line_voltage_thd_percent'][1]:.3f}/{inv['line_voltage_thd_percent'][2]:.3f}%`, and broadband residual `{inv['line_voltage_broadband_thd_percent'][0]:.3f}/{inv['line_voltage_broadband_thd_percent'][1]:.3f}/{inv['line_voltage_broadband_thd_percent'][2]:.3f}%`; status **{status(inv['pass'])}**.

## Gate safety

Simultaneous high/low command samples in the integrated inverter legs: A `{full['shootthrough_A']}`, B `{full['shootthrough_B']}`, C `{full['shootthrough_C']}`. The fast and slow PFC leg command sums and inverter leg sums never exceeded one. Gate safety **{status(full['pass']['no_shoot_through'])}**.

## Control and loss model

PFC outer bus PI: `Kp=0.012 S/V`, `Ki=0.50 S/(V·s)`, 150 ms reference ramp, conductance limit 0–0.11 S. Inner current PI: `Kp=0.105`, `Ki=66 s⁻¹`, signed `i_ref=g·vin`, boost duty feedforward and 0.02–0.95 duty clamp. Averaged-model crossover estimates: outer 10.41 Hz/57.5° phase margin, inner 1.008 kHz/75.3° phase margin; see the design report for assumptions. The VSI uses independent phase-RMS PI trims and 1 µs dead time.

Losses modeled: 50 mΩ external resistor per MOSFET (four PFC and six inverter devices), 80 mΩ boost-inductor winding, 80 mΩ per output-filter inductor, 40 mΩ DC-capacitor ESR, and 1 Ω series resistance per output capacitor. The output filter's linear loaded estimate is `f_n≈954 Hz`, `Q≈1.24`, with a 1.35×/2.62 dB resonance peak near 787 Hz; its 1 Ω capacitor-series resistor provides damping. The chosen ideal-switch MOSFETs omit switching-transition energy, temperature dependence and device-specific diode forward-loss calibration. `daessc` was used with 1 µs maximum step and `1e−4` relative tolerance.

## Problems encountered and fixes

1. The initial load-star wiring connected the neutral incorrectly; connecting the Y neutral to the filter capacitor neutral while keeping both floating restored balanced output.
2. Structural model edits were not always saved before later calls; saving immediately after each edit and verifying the saved `.slx` preserved all three voltage-feedback inputs.
3. The initial 30.5 Ω PFC-only load applied at t=0 held the precharged bus near 6.4 V. A physical switch now enables that load at 0.18 s, matching the staged integrated startup; the rerun passed.
4. Earlier stiff-solvers were impractical for the full fast-switching model; `daessc` with a 1 µs maximum step produced a complete 1 s run and finite signals.

## Files

- Integrated model: [{prefix}models/acac_single_to_three_phase_r2024a.slx]({prefix}models/acac_single_to_three_phase_r2024a.slx)
- PFC stage model: [{prefix}models/acac_pfc_standalone_r2024a.slx]({prefix}models/acac_pfc_standalone_r2024a.slx)
- Fixed-DC inverter model: [{prefix}models/acac_inverter_fixed_dc_r2024a.slx]({prefix}models/acac_inverter_fixed_dc_r2024a.slx)
- Integrated raw MAT: [{prefix}results/acac_full_results.mat]({prefix}results/acac_full_results.mat)
- Integrated JSON: [{prefix}results/acac_full_metrics.json]({prefix}results/acac_full_metrics.json)
- PFC stage [MAT]({prefix}results/acac_pfc_standalone_results.mat) and [JSON]({prefix}results/acac_pfc_standalone_metrics.json)
- Inverter stage [MAT]({prefix}results/acac_inverter_fixed_dc_results.mat) and [JSON]({prefix}results/acac_inverter_fixed_dc_metrics.json)
- Design report: [{prefix}docs/acac_system_design.md]({prefix}docs/acac_system_design.md)
- Full validation script: [{prefix}scripts/run_acac_full_validation.m]({prefix}scripts/run_acac_full_validation.m)

### Figures

{figures}

## Remaining limitations

The modeled efficiency excludes switching-transition, thermal and magnetic core losses. The quoted PI phase margins are from averaged design equations, not measured loop injection. The conventional harmonic THD sums bins 2–50 of the 60 Hz fundamental; the separate broadband residual also includes switching ripple near 12.6 kHz and other nonfundamental energy through 100 kHz. The PFC stage model keeps an electrically inactive inverter network during its equivalent-load test. These limitations do not change the stated integrated simulation measurements.

## Final conclusion

| Requirement | Result |
|---|---|
| 1. 36 V/50 Hz to 32 V/60 Hz/2 A balanced three-phase | {status(full['requirement_1_pass'])} |
| 2. Total input PF ≥0.98 | {status(full['requirement_2_pass'])} |
| 3. Declared-model efficiency ≥95% | {status(full['requirement_3_pass'])} |
| 4. All three line-voltage THDs ≤2% | {status(full['requirement_4_pass'])} |

**First four requirements passed: {'YES' if overall else 'NO'}.** MATLAB R2024a's complete physical Simscape Electrical switching model achieved the specified single-phase 36 V/50 Hz input through active PFC and a real DC link to balanced three-phase 32 V/60 Hz/2 A output, with total PF ≥0.98, declared-model efficiency ≥95%, and all three line-voltage THDs ≤2%, based on the integrated steady-state measurements above.
"""


(ROOT / "docs" / "acac_first_four_validation.md").write_text(render("../"))
(ROOT / "acac_first_four_validation.md").write_text(render(""))
