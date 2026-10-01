# Buck Dual-loop Validation

## Validation state

| State | Result | Evidence |
| --- | --- | --- |
| created | YES | Saved [`../models/buck_dual_loop_r2024a.slx`](models/buck_dual_loop_r2024a.slx), derived from the verified single-loop model |
| opened | YES | Opened in live MATLAB R2024a through MCP |
| model_check | healthy | Root-level Simulink Agentic Toolkit `model_check` |
| compiled | YES | Actual `SimulationCommand=update` completed |
| simulated | YES | Independent 0.08 s current-loop test and full 0.25 s Simscape Electrical switching simulation completed |
| measured | YES | Current-loop and final `SimulationOutput` timeseries read and saved |
| validated | **YES** | Finite data, stable startup and nominal operation, **9.384%** load-step deviation, recovery after both disturbances, and bounded current reference/duty |

The saved model was run with a 100 µs controller/PWM period, `ode23t`, `MaxStep=5e-6 s`, and unchanged 1 mH / 470 µF / 10 Ω physical power stage. The load remains a 10 Ω branch plus a switched 10 Ω branch at 0.10 s; the series source produces the same 24→20 V line step at 0.15 s as the single-loop baseline. The validation code is [`../scripts/validate_dual_loop_buck.m`](scripts/validate_dual_loop_buck.m). Full numeric evidence is [`../results/dual_loop_buck_metrics.json`](results/dual_loop_buck_metrics.json) and [`../results/dual_loop_buck_results.mat`](results/dual_loop_buck_results.mat).

## Inner-loop independent test

Before connecting the voltage outer loop, `Current_Mode=0` selected a fixed **0→1.2 A** iL reference step at 10 ms. The final model stores `Current_Mode=1`; the test was rerun non-destructively with `Simulink.SimulationInput` and saved in [`../results/dual_loop_current_test.mat`](results/dual_loop_current_test.mat).

| Measurement | Value |
| --- | ---: |
| Reference | 1.2000 A |
| Last-window cycle-average current | 1.1977 A |
| Last-window raw iL mean | 1.2165 A |
| Cycle-average steady error | 0.00230 A |
| Cycle-average peak / overshoot | 1.3516 A / 12.63% |
| 10–90% initial rise time | 0.240 ms |
| Sustained ±5% settling time | 24.24 ms after step |
| Duty range | 0.05–0.5019 |

The inner loop is stable and regulates the real sensed current. The initial rise is fast, while final settling is slower because the output capacitor/load voltage also evolves with no voltage controller in this independent test. The raw iL contains about 0.6 A switching ripple; control uses a one-period average of the same sensor signal. [Independent current-loop waveform](results/dual_loop_current_loop_test.png).

## Nominal and startup results

Nominal measurements use **0.08–0.10 s**, before either disturbance.

| Metric | Single voltage loop | Dual loop |
| --- | ---: | ---: |
| Nominal Vout error | 0.234% | **0.00127%** |
| Nominal Vout | 11.9719 V | **12.00015 V** |
| Startup Vout peak | 12.001 V | **12.137 V** |
| Startup raw iL peak | 1.503 A | **1.601 A** |
| Load-step maximum deviation | 11.451% | **9.384%** |
| Load-step recovery to ±1% | 16.20 ms | **11.94 ms** |
| Line-step maximum deviation | 24.592% | **5.266%** |
| Line-step recovery to ±1% | 28.85 ms | **2.86 ms** |

The dual-loop soft-start Vout peak is about **0.136 V** higher and iL peak about **0.098 A** higher than the single-loop result, but both remain modest. The dual-loop output reached and stayed within ±1% of 12 V at **56.085 ms** from start; the measured 10–90% rise time was **44.4 ms**. The startup iL-reference peak was **1.421 A** and startup duty peak **0.5075**. [Startup waveform](results/dual_loop_startup.png).

At nominal steady state, measured Vout peak-to-peak over the 20 ms window was **0.0160 V**, iL mean **1.2129 A**, iL peak-to-peak **0.6025 A**, iL minimum **0.8986 A**, and duty mean **0.5024**. The positive minimum confirms CCM. [Steady-state waveform](results/dual_loop_steady_state.png).

## 10→5 Ω load step

The same physical load step occurs at **0.10 s**.

| Metric | Dual-loop measurement |
| --- | ---: |
| Vout minimum / maximum, 0.10–0.15 s | **10.8740 / 12.0150 V** |
| Maximum deviation from 12 V | **9.3835%** |
| Recovery to ±1% and stays there until 0.15 s | **11.935 ms** |
| New steady Vout, 0.13–0.15 s | **12.00034 V** |
| iL-reference peak | **2.4283 A** |
| Raw iL peak | **2.7023 A** |
| Post-step steady iL minimum | **2.0976 A**, CCM |

Compared with the single voltage loop, the maximum deviation fell by about **18.1% relative**, crossing the requested **<10%** threshold, and recovery became about **4.26 ms faster**. [Load-step figure](results/dual_loop_load_step.png) shows Vout, iL reference, real iL, duty, and load current. The outer loop raises iL reference as Vout falls; the inner loop raises sensed current, allowing the capacitor/output voltage to recover. The physical current also has a switching ripple and can momentarily exceed its commanded average.

## 24→20 V line step

The same physical line step occurs at **0.15 s** with the heavy load still connected.

| Metric | Dual-loop measurement |
| --- | ---: |
| Measured Vin before / after | **24 / 20 V** |
| Vout minimum / maximum, 0.15–0.25 s | **11.3681 / 12.1175 V** |
| Maximum deviation from 12 V | **5.2662%** |
| Recovery to ±1% and stays there | **2.859 ms** |
| Final Vout, 0.23–0.25 s | **11.99866 V** |
| Final duty mean | **0.60268** |
| iL-reference / raw iL peak in line window | **2.7524 / 2.8549 A** |

The dual loop substantially improves the line transient compared with the single-loop **24.592%** deviation and **28.85 ms** recovery. [Line-step figure](results/dual_loop_line_step.png).

## Controller stability, limits, and PWM

The current PI has **Kp_i=0.15708**, **Ki_i=78.9568**; the voltage PI has **Kp_v=0.5**, **Ki_v=160**. On the stated CCM averaged models with a 150 µs equivalent measurement/computation delay, the estimated current-loop crossover/margins are **682.83 Hz / 46.82° / 8.41 dB**; the outer-loop values are **129.78 Hz / 91.52° / 12.09 dB**. Bandwidth separation is **5.26:1**. These analytical estimates were checked against actual switching behavior, which remained stable over the full simulation.

Both PI controllers use built-in **clamping** anti-windup. The outer PI and external current-reference block limit iL reference to **0–4 A**; the inner PI and external duty block limit duty to **0.05–0.95**. Measured full-run maxima were **2.752 A iL reference**, **2.855 A raw iL**, and **0.6538 duty**. These limits did not require saturation at the upper bound. The current-reference limit is not hardware overcurrent protection. Measured PWM frequency remained **10 kHz**. MATLAB `Simulink.BlockDiagram.getAlgebraicLoops` reported **zero algebraic loops** in the final model, in contrast to the single-loop warnings.

## Finite outer-loop tuning

The independent current loop was designed and tested first, then **Kp_i/Ki_i were held fixed**. Only the outer PI gains changed in the following `SimulationInput` runs on the same physical plant. The initial 0.45/60 pair yielded an **11.219%** load deviation. The table shows finite theory-guided refinements, not an unrestricted four-gain search.

| Outer Kp_v, Ki_v | Load deviation | Startup Vout peak | Analytical nominal bandwidth ratio | Decision |
| --- | ---: | ---: | ---: | --- |
| 0.45, 60 | 11.219% | 12.071 V | 7.04 | Initial design; missed load target |
| 0.45, 160 | 9.843% | 12.151 V | 5.98 | Passes, small target margin |
| 0.60, 60 | 9.615% | 12.017 V | 4.11 | Bandwidth separation below preferred 5:1 |
| 0.60, 120 | 8.995% | 12.100 V | 4.01 | Better deviation, smaller separation |
| 0.50, 140 | 9.579% | 12.133 V | 5.37 | Passes |
| 0.52, 140 | 9.407% | 12.128 V | 5.05 | Passes |
| **0.50, 160** | **9.384%** | **12.137 V** | **5.26** | **Retained** |

## Problems encountered and fixes

1. **Synchronous ripple-valley sampling:** the first independent current-loop test controlled the sampled valley to 1.2 A, while raw iL mean was about 1.48 A. A 20-tap, 5 µs/sample FIR averages one PWM period of the actual sensor signal. The repeated test measured 1.1977 A filtered mean and 1.2165 A raw mean.
2. **Current test before outer loop:** a model Switch selects a fixed 1.2 A step for the isolated test. The saved model selects the outer-PI reference; the test overrides the switch non-destructively with `SimulationInput`.
3. **Algebraic-loop risk:** one-period Unit Delays on the sensed Vout and averaged iL represent discrete controller computation; their delay was included in the analytical margins. The final MATLAB inspection found zero algebraic loops.
4. **Initial outer gain insufficient:** the first dual-loop run still missed the 10% load-deviation target. Finite outer-only tuning found 0.5/160, then a complete 0.25 s run verified all three operating periods.

## Figures

- [Independent current-loop test](results/dual_loop_current_loop_test.png)
- [Startup](results/dual_loop_startup.png)
- [Nominal steady state](results/dual_loop_steady_state.png)
- [Load step: Vout, iL reference, iL, duty](results/dual_loop_load_step.png)
- [Line step](results/dual_loop_line_step.png)
- [Current tracking](results/dual_loop_current_tracking.png)
- [Duty](results/dual_loop_duty.png)
- [Full overview](results/dual_loop_overview.png)

## Remaining risks and conclusion

The stated phase and gain margins are from a nominal CCM averaged model with an approximate delay; digital sampling, PWM events, current ripple, and ideal-switch nonlinearities are validated by the switching simulation rather than captured exactly by that model. The 4 A current-reference limit is not a hardware OCP circuit. A 200 µs effective-delay sensitivity estimate reduces the analytical inner-loop phase margin to roughly **34.5°**; changing timing or hardware would warrant another margin and switching check.

**Dual-loop Buck passed: YES** for the requested R2024a physical switching scenario. The inner loop improved load-step energy compensation, while measured current peaks stayed below 3 A; the same 10→5 Ω step now has **9.384%** maximum output deviation, below the **10%** gate.
