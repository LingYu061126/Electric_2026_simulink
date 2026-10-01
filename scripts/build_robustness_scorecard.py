"""Aggregate measured final switching cases without changing pass thresholds."""

import json
from pathlib import Path


PROJECT = Path(__file__).resolve().parent.parent
RESULTS = PROJECT / "results"
def read_case(name):
    return json.loads((RESULTS / f"robust_final_{name}.json").read_text())


def point(name, *, current=None, input_v=None):
    data = read_case(name)
    result = {
        "case": name,
        "PF": data["input_PF"],
        "efficiency_percent": data["efficiency_percent"],
        "THD_max_percent": max(data["output_broadband_residual_percent"]),
        "harmonic_THD_max_percent": max(data["output_THD_2to50_percent"]),
        "Uline_V": data["Uline_average_V"],
        "Uline_phases_V": data["Uline_rms_V"],
        "Iout_measured_A": data["Iline_average_A"],
        "output_frequency_Hz": sum(data["output_frequency_measured_Hz"]) / 3,
        "Vdc_V": data["dc_bus_mean_V"],
        "Pin_W": data["input_power_W"],
        "Pout_W": data["output_power_W"],
        "stable": bool(
            data["all_finite"]
            and data["no_shootthrough"]
            and abs(data["dc_bus_mean_V"] - 60) / 60 < 0.01
            and all(
                abs(freq - data["output_frequency_reference_Hz"]) <= 0.2
                for freq in data["output_frequency_measured_Hz"]
            )
        ),
        "source_file": f"results/robust_final_{name}.json",
    }
    if current is not None:
        result["Iout_A"] = current
    if input_v is not None:
        result["Ui_V"] = input_v
    return result


load_currents = [0.2, 0.5, 1.0, 1.5, 2.0]
load_names = ["load_02A", "load_05A", "load_10A", "load_15A", "load_20A"]
input_voltages = [31, 33, 36, 39, 41]
input_names = ["line_31V", "line_33V", "load_20A", "line_39V", "line_41V"]
load_sweep = [point(name, current=amps, input_v=36) for name, amps in zip(load_names, load_currents)]
input_sweep = [point(name, input_v=volts, current=2) for name, volts in zip(input_names, input_voltages)]
corner_specs = [
    (31, 0.2, "corner_31V_02A"),
    (31, 2.0, "line_31V"),
    (36, 0.2, "load_02A"),
    (36, 2.0, "load_20A"),
    (41, 0.2, "corner_41V_02A"),
    (41, 2.0, "line_41V"),
]
corners = [point(name, input_v=volts, current=amps) for volts, amps, name in corner_specs]
nominal60 = point("nominal_60Hz", input_v=36, current=2)
nominal60_raw = read_case("nominal_60Hz")
nominal30_raw = read_case("load_20A")
highline_raw = read_case("line_41V")
highline_stable = (
    abs(highline_raw["dc_bus_mean_V"] - 60) / 60 < 0.01
    and highline_raw["PFC_duty_min"] > 0.02
    and highline_raw["input_PF"] >= 0.98
    and highline_raw["all_finite"]
)

si_span = 100 * (max(p["Uline_V"] for p in load_sweep) - min(p["Uline_V"] for p in load_sweep)) / 32
si_dev = 100 * max(abs(p["Uline_V"] - 32) for p in load_sweep) / 32
su_span = 100 * (max(p["Uline_V"] for p in input_sweep) - min(p["Uline_V"] for p in input_sweep)) / 32
su_dev = 100 * max(abs(p["Uline_V"] - 32) for p in input_sweep) / 32

requirements = {
    "Req1": all(abs(v - 32) <= 0.1 for v in nominal60_raw["Uline_rms_V"])
    and all(abs(f - 60) <= 0.2 for f in nominal60_raw["output_frequency_measured_Hz"])
    and all(abs(i - 2) <= 0.02 for i in nominal60_raw["Iline_rms_A"])
    and nominal60["stable"],
    "Req2": nominal60["PF"] >= 0.98,
    "Req3": nominal60["efficiency_percent"] >= 95,
    "Req4": max(nominal60_raw["output_broadband_residual_percent"]) <= 2
    and max(nominal60_raw["output_THD_2to50_percent"]) <= 2,
    "Req5": all(abs(v - 32) <= 0.1 for v in nominal30_raw["Uline_rms_V"])
    and all(abs(f - 30) <= 0.2 for f in nominal30_raw["output_frequency_measured_Hz"])
    and all(abs(i - 2) <= 0.02 for i in nominal30_raw["Iline_rms_A"])
    and load_sweep[-1]["stable"],
    "Req6": si_span <= 0.3 and si_dev <= 0.3 and all(p["stable"] for p in load_sweep),
    "Req7": su_span <= 0.3 and su_dev <= 0.3
    and all(p["stable"] for p in input_sweep) and highline_stable,
}
all_points = [nominal60] + load_sweep + input_sweep + corners
score = {
    "model": "models/acac_robust_optimized_r2024a.slx",
    "measurement_window_s": [0.8, 1.0],
    "model_status": "Original 20 kHz continuous-PWM control retained; diagnostics added to derived model",
    "nominal_60Hz": nominal60,
    "load_sweep": load_sweep,
    "input_sweep": input_sweep,
    "combined_corner_cases": corners,
    "all_PF_ge_0_98": all(p["PF"] >= 0.98 for p in all_points),
    "all_eta_ge_95": all(p["efficiency_percent"] >= 95 for p in all_points),
    "all_THD_le_2": all(p["THD_max_percent"] <= 2 and p["harmonic_THD_max_percent"] <= 2 for p in all_points),
    "SI_span_percent": si_span,
    "SI_dev_percent": si_dev,
    "SU_span_percent": su_span,
    "SU_dev_percent": su_dev,
    "original_requirements": requirements,
    "all_original_requirements_pass": all(requirements.values()),
    "all_combined_corners_stable": all(p["stable"] for p in corners),
    "highline_PFC_stable": highline_stable,
    "all_extended_quality_targets_pass": False,
    "baseline_metrics": "results/robust_baseline_metrics.json",
}
score["all_extended_quality_targets_pass"] = (
    score["all_PF_ge_0_98"]
    and score["all_eta_ge_95"]
    and score["all_THD_le_2"]
    and score["all_combined_corners_stable"]
    and all(
        abs(v - 32) <= 0.1
        for p in all_points
        for v in p["Uline_phases_V"]
    )
)
(RESULTS / "robustness_scorecard.json").write_text(json.dumps(score, indent=2, ensure_ascii=False) + "\n")
print(
    "SCORECARD original=%s extended=%s PF=%s eta=%s THD=%s"
    % (
        score["all_original_requirements_pass"],
        score["all_extended_quality_targets_pass"],
        score["all_PF_ge_0_98"],
        score["all_eta_ge_95"],
        score["all_THD_le_2"],
    )
)
