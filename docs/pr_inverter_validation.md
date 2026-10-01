# PR Inverter Validation

## Validation state

| State | Result | Evidence |
| --- | --- | --- |
| created | YES | Derived model saved as [single_phase_pr_inverter_r2024a.slx](../models/single_phase_pr_inverter_r2024a.slx); original passive model is unchanged. |
| opened | YES | Loaded in MATLAB R2024a and inspected with `model_read`. |
| model_check | healthy | Root structural check reports no unconnected ports/lines or Stateflow lint issues. |
| compiled | YES | `SimulationCommand=update` completed before switching runs. |
| simulated | YES | Physical Simscape Electrical model: 0.12 s open-loop LC smoke run and 0.25 s closed-loop run. |
| measured | YES | Logged signals are finite; native 1 µs gate records and 1 MHz analysis record were checked. |
| validated | YES | All listed pass gates below are true for the specified simulation and analysis windows. |

Repeat the physical switching runs and measurements with [validate_pr_inverter.m](../scripts/validate_pr_inverter.m); run the structural `model_check` gate separately in the Simulink Agentic Toolkit. Full native-rate and resampled data are in [pr_inverter_results.mat](../results/pr_inverter_results.mat); scalar metrics and pass checks are in [pr_inverter_metrics.json](../results/pr_inverter_metrics.json).

## Gate safety

- Leg A overlap samples (`g1 && g2`): **0**
- Leg B overlap samples (`g3 && g4`): **0**
- Samples checked: **250,001** at approximately **1.000 µs** spacing
- Measured dead time: **1.000 µs median and minimum** on both legs

The original four-MOSFET gate paths, unipolar comparator arrangement, 10 kHz PWM, and one-sample 1 µs dead-time logic are retained.

## LC filtering

The open-loop smoke run confirms the physical bridge is PWM-switched and the filtered output is near sinusoidal. Its 0.08–0.12 s window measured **22.5238 Vrms fundamental**, **49.9894 Hz**, and **3.8914% output THD** with feedforward-only modulation.

In the closed-loop 0.08–0.14 s window, raw bridge `vAB` THD is **87.9698%** and filtered `vOut` THD is **3.5116%**. Both use the coherent 60 ms record resampled to 1 MHz and integer 50 Hz harmonics through 500 kHz. The raw-to-filtered waveforms and spectra are in [inverter_lc_filter.png](../results/inverter_lc_filter.png) and [inverter_output_spectrum.png](../results/inverter_output_spectrum.png).

## Nominal output

| Quantity | Target | Measured |
| --- | ---: | ---: |
| Total output RMS | 24 V ±1% | **23.787484 V** |
| RMS error | <1% | **0.885485% low** |
| 50 Hz fundamental RMS | 24 V | **23.773495 V** |
| Measured fundamental frequency | 49.9–50.1 Hz | **50.003358 Hz** |
| `vOut` THD | <5% | **3.511585%** |
| DC offset | <0.1 V magnitude | **+0.0000185 V** |
| Load current RMS | — | **2.012669 A** |
| Load current THD | — | **0.577661%** |

The measured fundamental/reference gain is **0.990562** (−0.08236 dB). The least-squares output frequency and DC offset are taken from simulated `vOut`; neither is copied from the reference settings. See [pr_inverter_steady_state.png](../results/pr_inverter_steady_state.png) and [pr_tracking_zoom.png](../results/pr_tracking_zoom.png).

## PR tracking and stability analysis

- Continuous controller: `Kp + (2 Kr wc s)/(s² + 2 wc s + w0²)`
- `Kp = 0.001`, `Kr = 0.2`, `wc = 2π·8 rad/s`, `w0 = 2π·50 rad/s`
- Sample time: **100 µs**, Tustin prewarped at 50 Hz
- Discrete resonant numerator: **[0.001000117976132425, 0, −0.001000117976132425]**
- Discrete resonant denominator: **[1, −1.989016875948622, 0.9899988202386751]**
- Maximum resonator pole magnitude: **0.994987**
- One 100 µs command delay is included in the sampled loop model.

The physical run's time-domain tracking error is **0.927809 Vrms** and **3.155699 V peak** over 0.08–0.14 s. For the averaged plant, gain at 50 Hz is **46.8122 V/modulation** with **−2.5318°** phase. The sampled loop gain at 50 Hz is **9.40944** (19.471 dB). Including feedforward, the linear sampled reference-to-output gain is **0.997955** (−0.01778 dB, −0.34045°).

`allmargin` finds multiple unity-gain crossings: phase-margin results are **−100.548° at 14.876 Hz** and **+87.155° at 162.680 Hz**. Gain margin is **14.686 dB at 963.909 Hz**. Because the quasi-PR loop has multiple crossings, a single scalar phase margin is ambiguous; the negative signed result at the rising crossing should not be hidden. The sampled closed-loop poles are inside the unit circle, maximum magnitude **0.989724**. These linear results and the physical 0.25 s run support the tested operating case; they do not establish robustness for other loads or component tolerances. [pr_control_bode.png](../results/pr_control_bode.png) shows plant magnitude/phase and sampled loop magnitude/phase; the sampled loop plot ends at the 5 kHz control Nyquist frequency.

## Modulation

- Maximum measured `|m_cmd|`: **0.746854**
- Maximum `|m_PR|` correction: **0.088526** over the full run and **0.063515** in the nominal window
- Saturation range: **−0.95 to +0.95**
- Saturated controller samples: **0 total**, including nominal and post-step windows
- Longest saturation run: **0 samples**

No separate anti-windup tracking path is present. The resonant state has finite stable poles, and the run never entered saturation, so this test did not exercise saturation recovery. The raw bridge command retains the original complementary unipolar SPWM references. See [pr_modulation.png](../results/pr_modulation.png).

## Load step

At **0.15 s**, a passive **20 Ω resistor** closes across the filtered output in parallel with the original 10 Ω / 20 mH RL load. A trailing 20 ms RMS window gives:

- Before step, 0.13–0.15 s: **23.791992 V**
- Minimum after step: **23.775409 V**
- Maximum after step: **23.812854 V**
- Allowed band: **23.52–24.48 V**
- Recovery time to the band: **0 ms**; the first complete post-step RMS window was already within the band, and all subsequent windows remained there.
- Maximum instantaneous `vref−vOut` error over 0.15–0.25 s: **2.785323 V**

The instantaneous error is reported separately from the cycle-RMS recovery criterion. The load-step voltage envelope is shown in [pr_inverter_load_step.png](../results/pr_inverter_load_step.png).

## Filter current

- Startup peak, maximum of both winding currents through 0.05 s: **2.657061 A**
- Steady RMS, combined winding-current RMS over 0.08–0.14 s: **1.947578 A**
- Load-step peak, maximum of both winding currents after 0.15 s: **4.497493 A**
- Startup load-current peak: **2.592723 A**

See [pr_filter_current.png](../results/pr_filter_current.png) and [pr_inverter_startup.png](../results/pr_inverter_startup.png).

## Problems and fixes

1. An initial control connection formed an algebraic loop through the measured output and PWM comparator. A 100 µs command Unit Delay now separates the sampled controller command from the comparator; the sampled-data stability analysis includes this delay.
2. The first R2024a driver attempt passed `ReturnWorkspaceOutputs` as a `SimulationInput` parameter. The unsupported option was removed; `sim(SimulationInput)` returns the `SimulationOutput` directly.
3. MATLAB rejected two Bode `xline` labels because the label followed name/value arguments. Their argument order was fixed. The discrete open-loop plot was also limited to its 5 kHz Nyquist frequency, and the spectrum uses separate low-frequency/LC and 10 kHz switching panels.
4. The final Diagnostic Viewer contains **10 `SetParamLinkChangeWarn` warnings** from parameters overridden inside the built-in Ramp subsystem used for the 50 ms soft start. It contains **0 errors**; the model compiled, simulated, and passed the root structural check.

All fixes are reflected in the saved model and final validation script. The original passive inverter model remains untouched.

## Remaining risks

- The 23.7875 Vrms total output is within the 1% acceptance band but has only about **0.115 percentage point** of margin to its lower limit.
- The multi-crossing sampled loop has a negative signed phase-margin result at one crossing; the averaged closed-loop poles and tested physical run are stable, but broader robustness needs a load/tolerance sweep.
- Modulation saturation was not observed; therefore the resonant-state response during saturation and recovery remains untested.
- Device and passive models omit parasitics, thermal effects, MOSFET diode reverse recovery, real gate-driver delays, and protection behavior.

## Conclusion

**PR inverter passed: YES** for the specified R2024a model, 24 Vrms / 50 Hz target, 0.25 s physical switching run, and 20 Ω passive load step. All explicit numeric pass gates are true in the JSON metrics. This is a simulation validation of the modeled operating case, not a hardware qualification.
