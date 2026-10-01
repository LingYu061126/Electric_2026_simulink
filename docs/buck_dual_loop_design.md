# Buck Dual-loop Control Design

## Existing single-loop limitation

The verified single-voltage-loop switching model regulated 12 V but produced an **11.451%** maximum deviation for the 10→5 Ω load step. Increasing that controller's gain eroded its analytical margin without reaching the requested <10% target. This stage copies [`../models/buck_closed_loop_r2024a.slx`](../models/buck_closed_loop_r2024a.slx) to [`../models/buck_dual_loop_r2024a.slx`](../models/buck_dual_loop_r2024a.slx). The R2024a Simscape Electrical power stage, 1 mH inductor, 470 µF capacitor, 10 Ω plus switched 10 Ω load, 24→20 V source step, sensors, 10 kHz PWM, and solver settings remain intact.

## Current-loop plant

In CCM, the averaged inductor and output equations are

`L diL/dt = d Vin - Vout`,  `C dVout/dt = iL - Vout/R`.

Linearizing around an operating point, with Vin fixed and the 10 Ω load modeled as a resistor, gives

`Gid(s) = ΔiL(s)/Δd(s) = Vin (C s + 1/R) / (L C s² + (L/R) s + 1)`.

For Vin=24 V, L=1 mH, C=470 µF, R=10 Ω:

`Gid(s) = (0.01128 s + 2.4) / (4.7e-7 s² + 1e-4 s + 1)` A/duty.

Its DC gain is **2.4 A/duty**. If Vout changes little on the current-control time scale, the inductor equation gives the useful high-frequency approximation `Gid(s) ≈ Vin/(L s) = 24000/s` A/duty. Neither transfer function is claimed to be the complete 10 kHz switching plant.

## Current controller and independent test

The inner controller is a discrete PI with **Kp_i=0.15708 duty/A**, **Ki_i=78.9568 duty/(A·s)**, sample time **100 µs**, and zero at **80.0 Hz**. Its duty output is limited to **0.05–0.95** with built-in clamping anti-windup; its integrator initial condition is 0.05 duty. A visible Saturation block repeats the same duty bounds before PWM.

The theoretical initial proportional gain comes from the high-frequency plant at a target near 600 Hz: `Kp_i ≈ 2π(600)L/Vin ≈ 0.157`. MATLAB `margin` on the fuller averaged `Gid` with the final PI and an explicitly stated **150 µs equivalent delay** gives **fci=682.83 Hz**, **phase margin=46.82°**, **gain margin=8.41 dB**. The 150 µs represents the 100 µs digital feedback Unit Delay plus approximately 50 µs group delay of the cycle-average FIR. PWM and zero-order-hold effects are only approximated: at a deliberately conservative 200 µs delay the same analytical current-loop phase margin falls to about **34.5°**. The real switching simulation is the final stability check.

Before connecting the outer loop, the model selected a 0→1.2 A reference step at 10 ms and used the actual Simscape inductor Current Sensor. The last 20 ms measured **1.1977 A** cycle-average current and **1.2165 A** raw-current mean; the reference was 1.2 A. Cycle-average overshoot was **12.63%**, 10–90% initial rise time **0.240 ms**, and sustained ±5% settling time **24.24 ms**. The longer settling reflects interaction with the unregulated output capacitor/load during this inner-only test. See [current-loop test figure](../results/dual_loop_current_loop_test.png) and [`../results/dual_loop_current_test.mat`](../results/dual_loop_current_test.mat).

## Physical current feedback and sampling

The R2024a Current Sensor and PS-Simulink Converter measure real switching iL. The first synchronous current test sampled near the triangular ripple valley; it regulated that valley to 1.2 A while the actual mean was about 1.48 A. This was a measurement-timing error, not a PI gain error.

The final controller applies a **20-tap moving average at 5 µs/sample**, covering one 100 µs PWM period, to the measured iL. A 100 µs Unit Delay then represents one digital control update. The outer-loop Vout sensor also enters through a 100 µs Unit Delay. Raw iL remains separately logged for peak and CCM checks. The moving average is derived solely from the real sensor waveform; no theoretical or estimated inductor current replaces the physical measurement. With these sampled feedback paths, MATLAB `Simulink.BlockDiagram.getAlgebraicLoops` found **zero algebraic loops** in the final model.

## Voltage-loop plant and controller

With the inner loop closed, the outer loop commands an inductor-current reference in amperes. The output capacitor equation gives

`Gvi(s) = ΔVout(s)/ΔiL(s) = 1/(C s + 1/R)`.

At R=10 Ω, `Gvi(s)=1/(0.00047 s + 0.1)` V/A, with DC gain **10 V/A** and pole **33.86 Hz**. The approximate reference-to-output plant is `Ti(s) Gvi(s)`, where `Ti(s)=Li(s)/(1+Li(s))` is the closed current-loop response using the stated analytical delay.

The outer discrete PI has **Kp_v=0.5 A/V**, **Ki_v=160 A/(V·s)**, sample time **100 µs**, and zero **50.93 Hz**. At the nominal 24 V/10 Ω point, the same analytical model gives **fcv=129.78 Hz**, **phase margin=91.52°**, **gain margin=12.09 dB**. The nominal bandwidth ratio is **fci/fcv=5.26**. At the 20 V/5 Ω endpoint, the approximate margins remain positive: current-loop fci≈594 Hz and PM≈51.4°; outer-loop fcv≈100 Hz and PM≈98.2°. These are averaged-model estimates, not measured switching-model margins.

## Saturation, anti-windup, and soft-start

The outer PI output and visible current-reference limiter are both **0–4 A**. This gives room above the 1.2 A nominal and 2.4 A heavy-load currents while bounding the requested transient current. The inner PI and visible duty limiter remain **0.05–0.95**. Both R2024a Discrete PID Controller blocks use built-in **clamping** anti-windup. The output-voltage reference still ramps **0→12 V in 50 ms**.

The current-reference limit is a **control command bound**, not hardware overcurrent protection. In the final 0.25 s switching run, maximum iL reference was **2.752 A**, while the raw physical iL peak was **2.855 A** because switching ripple and transient dynamics are not hard-clamped by the reference.

## Finite tuning and limitations

The current gains were designed and checked with the independent current-reference test, then held fixed. Outer-loop candidates were evaluated on the same switching plant with `Simulink.SimulationInput`; see [`buck_dual_loop_validation.md`](buck_dual_loop_validation.md). The retained 0.5/160 controller meets the <10% load-deviation target with about 5.26:1 bandwidth separation and moderate inner-loop analytical margin. The physical model still uses an ideal switching MOSFET and near-ideal diode, so these simulations do not predict semiconductor loss or implement hardware OCP.
