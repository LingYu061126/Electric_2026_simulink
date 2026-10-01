"""Write the evidence tables and final report from measured scorecard files."""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RESULTS = ROOT / "results"
DOCS = ROOT / "docs"


def read(name):
    return json.loads((RESULTS / name).read_text())


baseline = read("robust_baseline_metrics.json")
score = read("robustness_scorecard.json")
pf_diag = read("robust_pf_decomposition.json")
loss_diag = read("robust_loss_decomposition.json")
iter_a = read("robust_iteration_A_metrics.json")
iter_b = read("robust_iteration_B_metrics.json")
iter_d = read("robust_iteration_D_metrics.json")
iter_e = read("robust_iteration_E_metrics.json")


def raw_case(name):
    return read(f"robust_final_{name}.json")


def yn(value):
    return "PASS" if value else "FAIL"


def f(value, digits=5):
    return f"{value:.{digits}f}"


comparison = [
    "# AC-AC Robustness Optimization Evidence",
    "",
    "All final figures use the original full switching model and the 0.8–1.0 s coherent window. The retained model keeps the original controller and physical losses; it adds PFC diagnostic logging only.",
    "",
    "## Baseline versus final",
    "",
    "| Operating Point | Baseline PF | Final PF | Baseline η (%) | Final η (%) | Final THD max (%) | Decision |",
    "|---|---:|---:|---:|---:|---:|---|",
]
for before, after in zip(baseline["load_sweep"], score["load_sweep"]):
    amps = before["Iout_target_A"]
    decision = "Extended PF and η fail" if amps == 0.2 else ("Extended PF fails" if amps == 0.5 else "Quality targets pass")
    comparison.append(
        f"| 36 V / {amps:g} A | {f(before['PF'])} | {f(after['PF'])} | "
        f"{f(before['efficiency_percent'], 3)} | {f(after['efficiency_percent'], 3)} | "
        f"{f(after['THD_max_percent'], 3)} | {decision} |"
    )
for before, after in zip(baseline["input_sweep"], score["input_sweep"]):
    volts = before["Ui_target_V"]
    decision = "Extended η fails" if volts == 31 else "Quality targets pass"
    comparison.append(
        f"| {volts:g} V / 2 A | {f(before['PF'])} | {f(after['PF'])} | "
        f"{f(before['efficiency_percent'], 3)} | {f(after['efficiency_percent'], 3)} | "
        f"{f(after['THD_max_percent'], 3)} | {decision} |"
    )

comparison += [
    "",
    "## Light-load input-current quality",
    "",
    "| Iout (A) | PF baseline | PF final | Iin THD baseline (%) | Iin THD final (%) | DPF final |",
    "|---:|---:|---:|---:|---:|---:|",
]
diag_by_load = {p["Iout_target_A"]: p for p in pf_diag["points"]}
for before, after in zip(baseline["load_sweep"], score["load_sweep"]):
    amps = before["Iout_target_A"]
    final_raw = raw_case(after["case"])
    baseline_thd = diag_by_load[amps]["harmonic_THD_2to50_percent"] if amps in diag_by_load else None
    baseline_thd_text = f(baseline_thd, 3) if baseline_thd is not None else "—"
    comparison.append(
        f"| {amps:g} | {f(before['PF'])} | {f(after['PF'])} | {baseline_thd_text} | "
        f"{f(final_raw['input_current_THD_percent'], 3)} | {f(final_raw['input_displacement_factor'], 6)} |"
    )

comparison += [
    "",
    "## Low-line power and loss evidence",
    "",
    "| Ui (V) | η baseline (%) | η final (%) | Pin final (W) | Pout final (W) | Dominant measured or estimated losses |",
    "|---:|---:|---:|---:|---:|---|",
]
loss_by_input = {p["Ui_target_V"]: p for p in loss_diag["points"]}
for volts in [31, 36, 41]:
    index = [p["Ui_target_V"] for p in baseline["input_sweep"]].index(volts)
    before = baseline["input_sweep"][index]
    after = score["input_sweep"][index]
    loss = loss_by_input[volts]
    dominant = (
        f"boost Cu {f(loss['boost_inductor_copper_W'], 3)} W; "
        f"PFC switch R proxy {f(loss['PFC_MOSFET_external_R_est_W'], 3)} W; "
        f"unresolved {f(loss['unresolved_aggregate_W'], 3)} W"
    )
    comparison.append(
        f"| {volts} | {f(before['efficiency_percent'], 6)} | "
        f"{f(after['efficiency_percent'], 6)} | {f(after['Pin_W'], 3)} | "
        f"{f(after['Pout_W'], 3)} | {dominant} |"
    )
comparison += [
    "",
    "PFC and VSI switch losses are current-path estimates from the declared external resistances; the corresponding switch branch currents were not logged. The unresolved aggregate is the measured Pin–Pout remainder after identified loss terms, not a fabricated component loss.",
    "",
    "## Strategy log",
    "",
    f"- A, smooth PI gain schedule: Kp 0.160 / Ki 100 at light load, nominal Kp 0.105 / Ki 66; averaged crossover/phase margin 1.531 kHz / 72.5° at light load and 1.008 kHz / 75.3° at nominal. At 0.2 A PF {f(iter_a['PF'])}, η {f(iter_a['efficiency_percent'], 3)}%; at 0.5 A PF 0.976177. Rejected as an insufficient and load-dependent improvement.",
    f"- B, zero-crossing duty correction: 0.2 A PF {f(iter_b['PF'])}. Rejected because PF decreased.",
    f"- D, 50 kHz PFC carrier: 0.2 A PF {f(iter_d['PF'])}, η {f(iter_d['efficiency_percent'], 3)}%. Rejected because PF stayed below 0.98 and modeled efficiency decreased. This model does not include semiconductor transition losses, so the physical efficiency penalty at higher frequency may be larger.",
    f"- E, 31 V bus-reference screen: 56 V gave η {f(iter_e['measurements'][0]['efficiency_percent'], 6)}% and Uline {f(iter_e['measurements'][0]['Uline_V'], 6)} V; 58 V gave η {f(iter_e['measurements'][1]['efficiency_percent'], 6)}% and Uline {f(iter_e['measurements'][1]['Uline_V'], 6)} V; 59.5 V gave η {f(iter_e['measurements'][2]['efficiency_percent'], 6)}% and Uline {f(iter_e['measurements'][2]['Uline_V'], 6)} V. Rejected because no tested point satisfied both original voltage and strict efficiency limits.",
    "- C, current-reference shaping: analytically screened out. At 0.2 A the measured 0.166 A high-frequency current alone bounds PF near 0.890 even if all low-frequency distortion vanished. A reference reshaping pass could not meet 0.98 without reducing the physical switching ripple. No switching simulation or performance claim is assigned to C.",
    "",
    "The 10–15 kHz reduced-frequency option was ruled out by the measured 20 kHz ripple: at fixed L and voltage, ripple increases approximately inversely with carrier frequency. The 50 kHz test retained the 1 µs controller step (20 samples per carrier period) and 1 µs dead time (5% of the period); switching events and EMI spectral lines move upward. The model does not resolve all transition-loss and conducted-EMI effects. Burst mode and SVPWM were not introduced after the targeted tests failed to support a robust all-range improvement.",
    "",
    "## Figures",
    "",
    "[0.2 A before/after](../results/robust_02A_before_after.png), [31 V before/after](../results/robust_31V_before_after.png), [PF versus load](../results/robust_pf_vs_load.png), [efficiency versus input](../results/robust_efficiency_vs_input.png), [six-point operating map](../results/robust_operating_map.png).",
    "",
]
(DOCS / "acac_robustness_optimization.md").write_text("\n".join(comparison))

report = [
    "# AC-AC Robust Operating-range Optimization",
    "",
    "## Baseline",
    "",
    "Original Requirements 1–7 individually passed in the prior report. The new target asks for PF ≥ 0.98, model efficiency ≥ 95%, and line-voltage THD ≤ 2% throughout the extended operating range.",
    f"At 36 V / 0.2 A / 30 Hz, baseline PF was {f(baseline['load_sweep'][0]['PF'], 8)} and efficiency {f(baseline['load_sweep'][0]['efficiency_percent'], 6)}%. At 31 V / 2 A, baseline efficiency was {f(baseline['input_sweep'][0]['efficiency_percent'], 6)}%.",
    "",
    "## Root-cause Analysis",
    "",
    "### Light-load PF",
    "",
]
for p in pf_diag["points"]:
    report.append(
        f"- {p['Iout_target_A']:g} A: PF {f(p['PF_total'], 6)}, DPF {f(p['displacement_factor'], 6)}, "
        f"I1 {f(p['I1_rms_A'], 4)} A, Irms {f(p['Iin_rms_A'], 4)} A, "
        f"2–50th THD {f(p['harmonic_THD_2to50_percent'], 2)}%, "
        f">2.5 kHz current {f(p['current_above_2p5kHz_rms_A'], 4)} A."
    )
report += [
    "",
    "PF = DPF × I1rms/Irms agrees with direct P/(Vrms Irms) within numerical precision for the pure-sine input source. At 0.2 A, measured Pin is 11.746 W, fundamental reactive power about 0.512 var, and nonfundamental distortion apparent power 6.339 VA. DPF is near unity while 0.166 A high-frequency current remains nearly unchanged from 2 A. The dominant limitation is fixed switching ripple relative to small fundamental current; the 3rd, 5th and 7th harmonics and a zero-crossing spike add distortion. The controller log shows conductance command 0.00834–0.01034 S, no duty-floor hits and no evidence of quantization. The upper duty clamp is reached near zero crossing; DC-link charging pulses were not identified as the dominant 0.2 A PF loss.",
    "",
    "### 31 V efficiency",
    "",
    "The measured 31 V Pin–Pout loss is 5.863 W. The boost inductor copper term is 1.141 W; the PFC external switch-resistance current-path estimate is 1.426 W; DC-link ESR is 0.261 W. From 36 to 31 V total loss rises about 0.917 W, of which these three terms account for about 0.741 W (81%). The switch estimates are not direct branch-power measurements; 1.420 W remains unresolved in aggregate at 31 V. See the [loss decomposition](../results/robust_loss_decomposition.json) and [breakdown](../results/robust_loss_breakdown.png).",
    "",
    "## Strategies Evaluated",
    "",
    "Four meaningful physical switching strategy tests are documented in [the optimization evidence](acac_robustness_optimization.md): PI gain scheduling, zero-crossing duty compensation, 50 kHz switching, and a bounded 56/58/59.5 V bus-reference study. Each failed either the robust quality target or the protected output requirement, so none was retained. Current-reference shaping was excluded by the ripple bound rather than claimed as a simulation result.",
    "",
    "## Final Control Architecture",
    "",
    "The retained derived model uses the original 20 kHz continuous-PWM PFC current loop (Kp 0.105, Ki 66), original 60 V bus reference, original 12.6 kHz SPWM inverter, original 1 µs dead time, and unchanged physical/loss parameters. The derived model adds a PFC operating-state logger. A [51-block physical mask audit](../results/robust_hardware_frozen_audit.json) found zero parameter mismatches against the 30 Hz baseline. No gain scheduling, zero-crossing compensation, adaptive bus reference, frequency scheduling, SVPWM or burst mode was retained.",
    "",
    "## Final Load Sweep",
    "",
    "| Iout target (A) | PF | η (%) | Max line THD (%) | Uline (V) |",
    "|---:|---:|---:|---:|---:|",
]
for p in score["load_sweep"]:
    report.append(f"| {p['Iout_A']:g} | {f(p['PF'], 6)} | {f(p['efficiency_percent'], 6)} | {f(p['THD_max_percent'], 3)} | {f(p['Uline_V'], 5)} |")
report += [
    "",
    "## Final Input Sweep",
    "",
    "| Ui (V) | PF | η (%) | Max line THD (%) | Uline (V) |",
    "|---:|---:|---:|---:|---:|",
]
for p in score["input_sweep"]:
    report.append(f"| {p['Ui_V']:g} | {f(p['PF'], 6)} | {f(p['efficiency_percent'], 6)} | {f(p['THD_max_percent'], 3)} | {f(p['Uline_V'], 5)} |")
report += [
    "",
    "## Combined Corner Cases",
    "",
    "All six combinations below were simulated as actual joint input/load conditions; the overlapping sweep points reuse their own measured switching runs.",
    "",
    "| Ui (V) | Iout target (A) | PF | η (%) | Max line THD (%) | Uline (V) | Stable |",
    "|---:|---:|---:|---:|---:|---:|---|",
]
for p in score["combined_corner_cases"]:
    report.append(f"| {p['Ui_V']:g} | {p['Iout_A']:g} | {f(p['PF'], 6)} | {f(p['efficiency_percent'], 6)} | {f(p['THD_max_percent'], 3)} | {f(p['Uline_V'], 5)} | {yn(p['stable'])} |")
report += [
    "",
    "## Regulation",
    "",
    f"SI span {f(score['SI_span_percent'], 6)}%, SI deviation {f(score['SI_dev_percent'], 6)}%; SU span {f(score['SU_span_percent'], 6)}%, SU deviation {f(score['SU_dev_percent'], 6)}%. Each remains below the original 0.3% limits.",
    "",
    "## PF",
    "",
    f"All tested points PF ≥ 0.98: **{yn(score['all_PF_ge_0_98'])}**. Minimum measured PF is {f(min(p['PF'] for p in score['combined_corner_cases']), 6)} at 41 V / 0.2 A.",
    "",
    "## Efficiency",
    "",
    f"All tested points model efficiency ≥ 95%: **{yn(score['all_eta_ge_95'])}**. Minimum among the six combined corners is {f(min(p['efficiency_percent'] for p in score['combined_corner_cases']), 6)}% at 31 V / 0.2 A.",
    "",
    "## THD",
    "",
    f"All tested points line THD ≤ 2%: **{yn(score['all_THD_le_2'])}**. The maximum broadband line residual is {f(max(p['THD_max_percent'] for p in score['load_sweep'] + score['input_sweep'] + score['combined_corner_cases'] + [score['nominal_60Hz']]), 6)}%. The quality flags use exact unrounded measured values and also check 2nd–50th harmonic THD.",
    "",
    "## Regression Requirements 1–7",
    "",
]
for name, status in score["original_requirements"].items():
    report.append(f"- {name}: **{yn(status)}**")
report += [
    "",
    "## Remaining Limitations",
    "",
    "The continuous-PWM 1 mH / 20 kHz PFC produces roughly 0.166 A input high-frequency RMS current at all measured loads. At 0.2 A, this is large relative to the 0.327 A fundamental input current, making PF 0.98 unattainable through the tested PI and zero-crossing tweaks. Increasing to 50 kHz improved PF only to 0.92492 while the modeled efficiency fell to 93.811%. Low-line 31 V operation incurs larger RMS conduction loss. Reducing the DC bus enough to raise its efficiency sacrifices the original 32 V output target; at 59.5 V the exact measured efficiency was 94.996378%, still below 95%.",
    "",
    "The loss model includes declared resistive and damping losses but does not fully represent semiconductor switching-transition, magnetic core or thermal losses. Therefore η is the stated model efficiency, not a hardware efficiency prediction. Unresolved loss is explicitly retained rather than allocated to invented components.",
    "",
    "A future hardware study could evaluate interleaved PFC phases or a redesigned input inductor to cancel or reduce the measured light-load ripple, while measuring switching and magnetic losses. This is a recommendation inferred from the ripple and loss data; no such hardware change was made or credited in the results above.",
    "",
    "## Final Conclusion",
    "",
    f"Original Requirements 1–7: **{yn(score['all_original_requirements_pass'])}**. The robust extended target across the load/input sweeps and six joint corners: **{yn(score['all_extended_quality_targets_pass'])}**. The complete physical R2024a switching simulations do not support a claim that all extended PF, efficiency and THD targets are simultaneously satisfied without modifying the protected design parameters or original output requirements.",
    "",
    "[Scorecard](../results/robustness_scorecard.json) · [optimization evidence](acac_robustness_optimization.md) · [final model](../models/acac_robust_optimized_r2024a.slx) · [fixed-design validation script](../scripts/run_acac_robustness_validation.m)",
    "",
]
(DOCS / "acac_robustness_final_report.md").write_text("\n".join(report))
print("WROTE robustness optimization and final reports")
