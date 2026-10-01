# Closed-loop Buck Validation

## Validation state

| State | Result | Evidence |
| --- | --- | --- |
| created | YES | [`../models/buck_closed_loop_r2024a.slx`](../models/buck_closed_loop_r2024a.slx), copied from the validated open-loop model and edited through Simulink Agentic Toolkit |
| opened | YES | Live MATLAB R2024a `open_system` and model path query |
| model_check | healthy | Root `model_check` after wiring the control, switched load, and line source |
| compiled | YES | `SimulationCommand=update` completed after fixes |
| simulated | YES | Physical switching `sim` completed to 0.25 s |
| measured | YES | Vin, Vref, Vout, error, duty, PWM, inductor current, total load current, and switched-branch current read from `SimulationOutput` |
| validated | **NO** | The 10→5 Ω load-step output deviation was **11.451%**, exceeding the specified **<10%** target |

The data contain no NaN or Inf. The MATLAB R2024a switching simulation and disturbance recovery are real results; the final validation flag remains false because one requested performance gate failed. The full measured values are in [`../results/closed_loop_buck_metrics.json`](../results/closed_loop_buck_metrics.json), and the recorded timeseries are in [`../results/closed_loop_buck_results.mat`](../results/closed_loop_buck_results.mat). [`../scripts/validate_closed_loop_buck.m`](../scripts/validate_closed_loop_buck.m) reruns the saved model and regenerates the metrics and figures.

## Nominal steady state

Measured at **0.08–0.10 s**, before either disturbance:

| Metric | Value |
| --- | ---: |
| Vin | 24 V |
| Vout mean | 11.971941 V |
| Absolute 12 V error | 0.028059 V (0.234%) |
| Vout peak-to-peak over the 20 ms window | 0.072676 V |
| Duty mean | 0.501209 |
| iL mean | 1.204660 A |
| iL peak-to-peak | 0.608529 A |
| iL minimum | 0.893624 A |
| Iload mean | 1.197194 A |

The 20 ms Vout peak-to-peak includes the decaying low-frequency LC startup transient as well as switching ripple; it should not be interpreted as a pure single-cycle switching ripple. The positive iL minimum confirms CCM in the nominal window.

## Startup

With the 0→12 V reference ramp over **50 ms**, Vout peaked at **12.001147 V** (0.00956% above target) and iL peaked at **1.503362 A**. The measured 10–90% rise time was **53.216 ms**. Vout entered and remained within ±1% of 12 V at **75.338 ms** from the start.

The prior saved open-loop MAT data measured **21.376240 V** Vout peak and **8.720030 A** iL peak. The closed-loop soft-start reduced these peaks by **43.86%** and **82.76%**, respectively. The complete startup waveform, including its early low-voltage oscillation, is shown in [closed_loop_startup.png](../results/closed_loop_startup.png).

## Load step

At **0.10 s**, a controlled physical switch adds a 10 Ω branch in parallel with the retained 10 Ω load. The effective load changes approximately **10→5 Ω**; measured total load current changes from about **1.20 A** to **2.40 A**.

| Metric | Value |
| --- | ---: |
| Vout minimum during 0.10–0.15 s | 10.625860 V |
| Vout maximum during 0.10–0.15 s | 13.148358 V |
| Maximum absolute 12 V deviation | **11.451%** |
| Recovery to ±1% and stays there until line step | 16.195 ms after load step |
| New Vout mean, 0.13–0.15 s | 12.001401 V |
| New Iload mean | 2.399081 A |
| Duty mean | 0.502696 |
| Post-step steady iL minimum | 2.091138 A, CCM |

The load step recovers and meets the ±1% new steady-state band. Its first voltage dip misses the requested <10% deviation target. The measured waveforms are in [closed_loop_load_step.png](../results/closed_loop_load_step.png).

## Line step

At **0.15 s**, a physical controlled voltage source in series with the retained input source changes measured Vin from **24→20 V**.

| Metric | Value |
| --- | ---: |
| Vout minimum during 0.15–0.25 s | 9.048914 V |
| Vout maximum during 0.15–0.25 s | 12.004957 V |
| Maximum absolute 12 V deviation | 24.592% |
| Recovery to ±1% and stays there | 28.849 ms after line step |
| Final Vout mean, 0.23–0.25 s | 11.998230 V |
| Final Iload mean | 2.398447 A |
| Final duty mean | 0.602658 |

The duty increase from about 0.503 to 0.603 agrees with the approximate ideal Buck requirement `D≈Vout/Vin` when Vin falls to 20 V. The line-step transient is large but recovers by the final window. See [closed_loop_overview.png](../results/closed_loop_overview.png).

## Controller and PWM

- Single discrete voltage PI: **Kp=0.004**, **Ki=5**, `Ts=100 µs`.
- PI zero: **198.944 Hz**; ideal CCM loop crossover: **19.32 Hz**; phase margin: **94.85°**. See [`buck_closed_loop_design.md`](buck_closed_loop_design.md).
- Duty limits: **0.05–0.95**, both inside the PI block and at a visible output Saturation block; built-in anti-windup method: **clamping**.
- Measured full-run duty range: **0.05–0.602672**. Duty changed in response to both disturbances.
- Measured PWM frequency: **10,000 Hz**; physical MOSFET gate voltage: **0/10 V**.
- Feedback is the actual Simscape Vout sensor through a PS-Simulink Converter.

## PI tuning iterations

Each candidate below was simulated non-destructively on the same physical switching model through `Simulink.SimulationInput`. The persistent saved controller remained at Kp=0.004, Ki=5. The problem being addressed was the initial **11.451%** load-step deviation.

| Old Kp, Ki | Candidate Kp, Ki | Load-step Vout minimum | Result |
| --- | --- | ---: | --- |
| 0.004, 5 | 0.006, 3 | 10.5408 V | Worse first dip; not retained |
| 0.004, 5 | 0.008, 3 | 10.5451 V | Worse first dip; not retained |
| 0.004, 5 | 0.006, 5 | 10.6436 V | Slight improvement, still >10% deviation; ideal-loop phase margin falls to 37.3° |
| 0.004, 5 | 0.004, 7 | 10.6426 V | Slight improvement, still >10% deviation; phase margin falls to about 31.8° |
| 0.004, 5 | 0.0045, 5.5 | 10.635 V | 11.377% deviation; still fails |
| 0.004, 5 | 0.005, 6 | 10.641 V | 11.322% deviation; phase margin falls to about 36.0° |

The modest reductions in first dip did not meet the target and cost robustness or increased later overshoot. The more conservative initial PI was retained; no plant values, load-step size, or target were changed to force a pass.

## Problems and fixes

1. The R2024a Discrete PID block rejected a positive 0.05 lower limit while its integrator initial condition remained at zero. Setting the integrator initial condition to 0.05 before the lower limit resolved the mask constraint; the final internal limits and clamping were read back from the block.
2. The PWM comparator's Boolean output caused a fixed-point inferred type after the 10 V Gain; the Simulink-PS Converter requires `double`. Setting the Gain output type to `double` resolved the compile error.
3. MATLAB warned of a Simulink/Simscape algebraic loop with discontinuities during gain-sweep simulations. The final model compiled and the 0.25 s switching simulation completed, but this numerical warning remains relevant when changing control gains or solver settings.
4. The <10% load-transient target remains unmet after finite, theory-guided PI comparisons. This is recorded as a failed validation gate.

## Figures

- [Startup: Vref and Vout](../results/closed_loop_startup.png)
- [Steady state: Vout, iL, duty](../results/closed_loop_steady_state.png)
- [10→5 Ω load step](../results/closed_loop_load_step.png)
- [Duty command](../results/closed_loop_duty.png)
- [Inductor current](../results/closed_loop_inductor_current.png)
- [Full overview](../results/closed_loop_overview.png)

## Remaining risks and conclusion

The one-loop PI regulates 12 V to within 1% at nominal load, after the 10→5 Ω load step, and after the 24→20 V line step. Soft-start substantially reduces the measured open-loop startup peaks. Abrupt disturbance excursions remain significant: **11.451%** for load and **24.592%** for line. The high-Q LC stage, sampled PWM, and single PI loop limit how aggressively duty can react without reducing stability margins. The ideal-switch model is not a semiconductor-loss or hardware protection model.

**Closed-loop Buck passed: NO under the stated first-stage acceptance gates**, because the load-step deviation exceeds 10%. The switching model itself is operational, stable over 0.25 s, and its output recovers after both disturbances. No dual loop was introduced.
