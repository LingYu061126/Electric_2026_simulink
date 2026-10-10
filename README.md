# MATLAB Electric

MATLAB R2024a / Simscape Electrical models, switching simulations, and validation reports for power converters and inverters.

## Dual single-phase parallel inverter

The current validated model is [dual_single_phase_parallel_inverter_r2024a.slx](models/dual_single_phase_parallel_inverter_r2024a.slx). It contains two independently controlled 48 V full-bridge inverters, a 24 V RMS / 50 Hz load-output mode, parallel load sharing, and a 24:220 V transformer grid-injection mode. Per-inverter protection includes a 0–2 A RMS reference limit, a 4 A instantaneous overcurrent latch, and a 40 V DC undervoltage interlock.

- [System design](docs/dual_inverter_system_design.md) — topology, control loops, assumptions, protection, and limitations.
- [Final validation report](docs/dual_inverter_final_validation.md) — results from all eight Basic, Bonus, and protection stages.
- [Aggregate metrics](results/dual_inverter_all_metrics.json) — machine-readable stage results and operating-point data.

The final regression passed all eight stages. Representative limits were 1.8435% output-voltage THD (harmonics 2–50), 0.1298% load regulation over 0–2 A, 1.232% maximum total-current error, and 0.669% maximum current-ratio error.

To rerun the complete regression, use MATLAB R2024a with Simulink and Simscape Electrical, set the current folder to the repository root, open the model, then run the master script:

```matlab
open_system('models/dual_single_phase_parallel_inverter_r2024a.slx');
run('scripts/run_dual_inverter_full_validation.m');
```

The script runs Basic-1 through Basic-4, Bonus-1 through Bonus-3, then the protection fault tests. It requires the model to be loaded and saved. It writes stage metrics and plots under `results/`, plus the aggregate JSON and final report linked above.

## Other model work

| Workstream | Model and documentation |
| --- | --- |
| AC–AC converter | [Robust optimized model](models/acac_robust_optimized_r2024a.slx), [final design report](docs/acac_final_design_report.md), and [robustness report](docs/acac_robustness_final_report.md). Run `scripts/run_acac_robustness_validation.m` for the fixed-design switching validation. |
| Buck converters | [Dual-loop model](models/buck_dual_loop_r2024a.slx), [design](docs/buck_dual_loop_design.md), and [validation](docs/buck_dual_loop_validation.md). |
| Single-phase inverter | [PR inverter model](models/single_phase_pr_inverter_r2024a.slx), [design](docs/pr_inverter_design.md), and [validation](docs/pr_inverter_validation.md). |
| Energy recovery | [Testbench model](models/energy_recovery_testbench_r2024a.slx) and [final report](docs/converter_energy_recovery_final_report.md). |

## Generated results and caches

`results/` contains compact JSON metrics and figures. Large switching-trace `.mat` files, Simulink build caches (`.slxc`, `slprj/`), and SDI archives are generated locally and excluded from Git. The validation scripts can regenerate the trace files and figures.
