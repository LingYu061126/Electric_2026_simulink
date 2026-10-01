# PR-controlled Single-phase Inverter

## Existing validated H bridge

The derived model is [single_phase_pr_inverter_r2024a.slx](../models/single_phase_pr_inverter_r2024a.slx). It retains the four physical Simscape Electrical MOSFETs, their integral protection diodes, the 48 V DC source, unipolar SPWM carrier/comparators, four Simulink-PS gate paths, 1 µs sampled dead-time logic, solver configuration, electrical reference, and raw bridge voltage/current measurements from [the passive inverter](passive_inverter_design.md).

Only the comparator modulation references change: the Control subsystem now receives measured filtered `vOut`; the former modulation sine is replaced by the closed-loop command. The same carrier, comparator sampling, gate logic, and physical MOSFET gate paths remain in place.

## LC filter design

| Item | Value |
| --- | ---: |
| `Lf_A` | 1 mH |
| `Lf_B` | 1 mH |
| Differential `Lf_total` | 2 mH |
| `Cf` | 20 µF |
| Capacitor damping | 10 Ω in series with `Cf` |

The undamped LC estimate is

```text
fLC = 1 / (2π√(Lf_total·Cf)) = 795.775 Hz
```

The 10 kHz carrier is about 12.6 times this frequency, while the 50 Hz fundamental is about 1/15.9 of it. The output capacitor is across the floating filtered A-B terminals, not tied to DC return. The original R-L load is connected across those same terminals. The separate `vAB` sensor remains across the raw bridge nodes; `vOut` measures filtered A-B voltage.

### Damping selection

The differential filter's characteristic impedance is

```text
sqrt(Lf_total/Cf) = 10 Ω
```

This sets the series capacitor damping resistor to 10 Ω. In the averaged plant including the 10 Ω / 20 mH load, the predicted bridge-to-output peak falls from approximately 5.08 kV/m at 834 Hz without damping to 62.2 V/m at 703 Hz with damping, an approximately 38.2 dB reduction. At 50 Hz the damped plant magnitude is 46.81 V/m with −2.53° phase, so damping has little effect on the fundamental. At 24 Vrms, the damping branch dissipates approximately 0.23 W at 50 Hz in the linear steady-state estimate.

The load disturbance is an additional 20 Ω passive resistor switched across filtered A-B at 0.15 s. The switch has 10 mΩ closed resistance and 10⁻⁸ S open conductance.

## Averaged plant

Let `s` be the Laplace variable and `Zload(s) = Rload + s·Lload`. The series-RC damping branch has admittance

```text
Yd(s) = s·Cf / (1 + s·Cf·Rd)
Yload(s) = 1 / (Rload + s·Lload)
```

With two symmetric filter inductors in the differential path,

```text
Hfilter(s) = Vout(s)/Vbridge_avg(s)
           = 1 / (1 + s·Lf_total·(Yload(s) + Yd(s)))
P(s) = Vout(s)/m(s) = Vdc·Hfilter(s)
```

The undamped comparison uses `Yd(s) = s·Cf`. This averaged plant omits PWM ripple, switching-device drops, and dead-time effects; those effects are assessed separately with the physical switching simulation.

## Voltage reference

```text
Vrms_ref = 24 V
Vpeak_ref = sqrt(2)·24 = 33.941125 V
f_ref = 50 Hz
vref(t) = Vpeak_ref·sin(2π·50·t)·min(max(20·t, 0), 1)
```

The amplitude ramps from 0 to 1 in 50 ms. The sampled reference and sampled physical `vOut` both enter the controller at `Ts = 100 µs`.

## Feedforward

```text
m_ff = vref / Vdc
```

This provides the nominal bridge command. The PR controller supplies the correction based on instantaneous voltage error.

## PR controller

```text
e(t) = vref(t) - vOut(t)
Gpr(s) = Kp + (2·Kr·wc·s)/(s² + 2·wc·s + w0²)
w0 = 2π·50 rad/s
Kp = 0.001
Kr = 0.2
wc = 2π·8 rad/s
m_raw = m_ff + Gpr(e)
```

This is a finite-bandwidth quasi-PR controller. The resonant term has finite gain at 50 Hz rather than the infinite gain of an ideal PR controller, making frequency mismatch, finite precision, and sampled implementation less sensitive.

The controller uses a resonant transfer-function block plus a separate proportional gain. There is no ideal integrator. Its saturation is limited to `−0.95 ≤ m ≤ +0.95`; the resonator poles are strictly inside the unit circle, so its state decays when excitation is removed. The validation report records every saturation sample and checks for sustained limiting.

## Discretization

| Item | Setting |
| --- | --- |
| Method | Tustin / bilinear transform, prewarped at 50 Hz |
| Sample time | 100 µs (10 kHz) |
| Continuous resonant term | `2·Kr·wc·s / (s² + 2·wc·s + w0²)` |
| Discrete numerator `B` | `[0.001000117976132425, 0, -0.001000117976132425]` |
| Discrete denominator `A` | `[1, -1.989016875948622, 0.9899988202386751]` |
| Discrete resonator poles | `0.994508438 ± j·0.030851046` |

The coefficients were generated in MATLAB R2024a with `c2d` and `c2dOptions('Method','tustin','PrewarpFrequency',w0)`. The poles have magnitude less than one.

## Stability analysis

The discrete loop analysis uses the damped plant discretized with a zero-order hold at 100 µs, the prewarped discrete PR, and one conservative sample of command/PWM delay. The predicted closed-loop poles lie inside the unit circle; the largest pole magnitude is approximately 0.9897.

`allmargin` finds multiple unity-gain crossings because of the resonant controller. The phase margins are **−100.55° at 14.876 Hz** and **+87.16° at 162.680 Hz**; the lower-frequency crossing is on the rising side of the resonant gain lobe. A single textbook phase-margin number is therefore ambiguous for this multi-crossing loop. The sampled closed-loop poles are all inside the unit circle, with maximum magnitude **0.989724**. The gain margin is **14.69 dB at 963.909 Hz**. The damped plant peak is **62.24 V/mod near 703.30 Hz**. These are linear averaged-model results; the 0.25 s physical switching run is a separate finite-scenario check, not a proof of global robustness. The generated Bode figure shows the continuous plant through 100 kHz and the sampled open loop only through its 5 kHz control Nyquist frequency.

## Switching validation result

The saved derived model passed the open-loop LC smoke test and the full closed-loop physical switching run. The smoke test measured **22.5238 Vrms** fundamental, **49.9894 Hz**, and **3.8914% THD**. The closed-loop run measured **23.7875 Vrms total** (0.8855% below target), **23.7735 Vrms fundamental**, **50.00336 Hz**, **3.5116% filtered-output THD**, and **1.85e−5 V** DC offset. The output current was **2.0127 Arms** with **0.5777% THD**.

The modulation peak was **0.746854**, with no saturation samples. The PR correction peak was **0.088526** over the run and **0.063515** in the nominal window. The 20 ms RMS envelope after the 0.15 s 20 Ω load step stayed between **23.7754 V and 23.8129 V**, inside the 24 V ±2% band for every measured window. Both legs had zero overlap in 250,001 native 1 µs gate samples; measured median and minimum dead time were 1.000 µs. Startup filter-current peak was **2.6571 A**, steady filter-current RMS was **1.9476 A**, and load-step filter-current peak was **4.4975 A**. The full metrics and report are in [the validation report](pr_inverter_validation.md) and [the JSON results](../results/pr_inverter_metrics.json).

## SPWM

The two existing references remain complementary:

```text
vrefA_PWM = m_cmd
vrefB_PWM = -m_cmd
```

They use the existing shared −1…+1 triangular carrier, 10 kHz carrier period, 1 µs PWM sampling, and the original 1 µs both-off dead-time logic. The physical four-MOSFET gate paths are unchanged.

## Saturation

The raw sum `m_ff + Kp·e + m_pr` is saturated to `[−0.95, +0.95]` before a 100 µs command Unit Delay and the existing SPWM comparators. A model constant selects the closed-loop output by default; the validation script temporarily selects `m_ff` for the open-loop LC smoke test using a `SimulationInput` override. The saved model remains in closed-loop mode. No separate anti-windup tracking path is used; the resonant states are finite-pole states, and the measured run had zero saturation samples. Saturation recovery was therefore not exercised by this run.

## Soft-start

The instantaneous 33.941 V-peak sinusoidal reference is multiplied by a 0-to-1 ramp over 50 ms. The voltage reference itself, measured filtered voltage, feedforward, PR correction, command, and error are logged.

## Limitations

- The stability model is averaged; true switching behavior, dead time, and MOSFET integral-diode behavior are checked in Simscape Electrical.
- The MOSFETs, integral diodes, DC source, filter passives, and load are idealized. Parasitics, thermal behavior, reverse recovery, real gate-driver delay, and hardware protections are outside this model.
- No grid connection, PLL, dq/PQ controller, three-phase bridge, or LCL filter is included.
