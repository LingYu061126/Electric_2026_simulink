"""Freeze the measured pre-optimization AC-AC sweep as an immutable comparison."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RESULTS = ROOT / "results"


def read(name: str) -> dict:
    return json.loads((RESULTS / name).read_text(encoding="utf-8"))


load = read("acac_req6_load_regulation.json")
line = read("acac_req7_line_regulation.json")
nominal_60 = read("acac_baseline_60hz_metrics.json")
nominal_30 = read("acac_req5_metrics.json")

load_points = []
for i, current in enumerate(load["current_points_A"]):
    load_points.append(
        {
            "Iout_target_A": current,
            "Rphase_Ohm": load["Rphase_points_Ohm"][i],
            "Uline_V": load["Uline_average_points_V"][i],
            "Iout_measured_A": load["Iline_average_points_A"][i],
            "PF": load["PF_points"][i],
            "efficiency_percent": load["efficiency_points_percent"][i],
            "THD_max_percent": load["output_THD_max_points_percent"][i],
            "Vdc_V": load["dc_bus_points_V"][i],
        }
    )

input_points = []
for i, voltage in enumerate(line["input_voltage_points_V"]):
    input_points.append(
        {
            "Ui_target_V": voltage,
            "Ui_measured_V": line["input_voltage_measured_points_V"][i],
            "Uline_V": line["output_voltage_points_V"][i],
            "Iout_A": line["Iline_average_points_A"][i],
            "PF": line["PF_points"][i],
            "efficiency_percent": line["efficiency_points_percent"][i],
            "THD_max_percent": line["THD_points_percent"][i],
            "Vdc_V": line["dc_bus_points_V"][i],
        }
    )

baseline = {
    "model": "models/acac_30hz_r2024a.slx",
    "source_metrics": [
        "results/acac_baseline_60hz_metrics.json",
        "results/acac_req5_metrics.json",
        "results/acac_req6_load_regulation.json",
        "results/acac_req7_line_regulation.json",
    ],
    "steady_window_s": [0.8, 1.0],
    "measurement_policy": "Original full-switching measurements; no changed loss parameters or analysis window.",
    "original_requirements_1_to_7_pass": all(
        read("acac_all_requirements_metrics.json")[f"requirement_{i}_pass"]
        for i in range(1, 8)
    ),
    "nominal_60Hz": {
        "PF": nominal_60["input_PF"],
        "efficiency_percent": nominal_60["efficiency_percent"],
        "THD_max_percent": max(nominal_60["output_broadband_residual_percent"]),
        "Uline_V": nominal_60["Uline_average_V"],
    },
    "nominal_30Hz": {
        "PF": nominal_30["input_PF"],
        "efficiency_percent": nominal_30["efficiency_percent"],
        "THD_max_percent": max(nominal_30["output_broadband_residual_percent"]),
        "Uline_V": nominal_30["Uline_average_V"],
    },
    "load_sweep": load_points,
    "input_sweep": input_points,
    "SI_span_percent": load["SI_span_percent"],
    "SI_dev_percent": load["SI_deviation_percent"],
    "SU_span_percent": line["SU_span_percent"],
    "SU_dev_percent": line["SU_deviation_percent"],
    "all_load_PF_ge_0_98": all(p["PF"] >= 0.98 for p in load_points),
    "all_load_eta_ge_95": all(p["efficiency_percent"] >= 95 for p in load_points),
    "all_input_eta_ge_95": all(p["efficiency_percent"] >= 95 for p in input_points),
    "all_THD_le_2": all(
        p["THD_max_percent"] <= 2 for p in load_points + input_points
    ),
}

path = RESULTS / "robust_baseline_metrics.json"
path.write_text(json.dumps(baseline, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(path)
