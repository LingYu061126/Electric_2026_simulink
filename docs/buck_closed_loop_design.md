# Closed-loop Buck Design

## Plant

This model is derived from the verified physical switching model [`../models/buck_r2024a.slx`](../models/buck_r2024a.slx). The new model is [`../models/buck_closed_loop_r2024a.slx`](../models/buck_closed_loop_r2024a.slx). It retains the R2024a Simscape Electrical MOSFET, freewheel diode, 1 mH inductor, 470 µF capacitor, 10 Ω base load, sensors, electrical reference, Solver Configuration, and 10 kHz switching frequency. A switched 10 Ω branch creates a 10→5 Ω load step at 0.10 s. A controlled voltage source in series with the retained 24 V source creates a 24→20 V line step at 0.15 s.

## Small-signal model

For an ideal continuous-conduction Buck with resistive load, negligible switch loss and capacitor ESR, and duty averaged over a switching cycle:

`Gvd(s) = Vout(s)/d(s) = Vin / (L C s² + (L/R) s + 1)`.

At Vin=24 V, L=1 mH, C=470 µF, R=10 Ω:

`Gvd(s) = 24 / (4.7e-7 s² + 1e-4 s + 1)`.

The DC gain is 24 V per unit duty. The LC natural frequency is `ω0=1/sqrt(LC)=1458.65 rad/s`, or **f0=232.151 Hz**. The damping ratio is `ζ=sqrt(L/C)/(2R)=0.07293`, so **Q=6.8557**. This is a high-Q plant; the ideal CCM model does not include PWM sampling, switched-device nonlinearities, parasitic resistances, or discontinuous conduction. Actual switching simulation is the validation authority.

## Controller design

The controller is one discrete voltage-loop PI: `Gc(s)=Kp+Ki/s`, with `Ts=100 µs` and measured Simscape output voltage as feedback. The initial and retained gains are **Kp=0.004 duty/V** and **Ki=5 duty/(V·s)**. Its zero is `ωz=Ki/Kp=1250 rad/s`, or **fz=198.944 Hz**.

MATLAB R2024a Control System Toolbox `tf`/`margin` analysis of the ideal CCM loop gives a gain crossover of **19.32 Hz**, phase margin **94.85°**, and gain margin approximately **6.60 dB**. The crossover is deliberately below the suggested 100–500 Hz starting range: this plant's lightly damped 232 Hz resonance makes a PI-only crossover near the LC mode less robust. It is also far below the 10 kHz switch frequency. The large low-frequency phase margin does not replace the switching-model disturbance test; the gain margin near the resonance is modest.

This is a single voltage loop. There is no current loop, load-current feedforward, derivative action, or average-state surrogate for the power stage.

## Duty saturation and anti-windup

The R2024a Discrete PID Controller is set to PI, `SampleTime=1e-4`, internal output limits **0.05–0.95**, and built-in **clamping** anti-windup. Its integrator initial condition is 0.05 duty, within the saturation bounds. A visible downstream Saturation block repeats the same limits before the PWM comparator. The measured duty range in the final 0.25 s switching simulation was **0.05–0.602672**.

The controller output represents duty, not gate voltage. A 0–1 repeating sawtooth at 10 kHz is compared with duty; the comparator output is scaled to 0/10 V, converted by Simulink-PS Converter (unit V), and applied to the physical-signal G port of the R2024a `MOSFET (Ideal, Switching)`.

## Soft-start

The reference is a 240 V/s ramp limited to 12 V, reaching 12 V at **50 ms**. The previous fixed-duty open-loop run supplied the measured baseline: 21.376 V startup output peak and 8.720 A startup inductor-current peak. The final closed-loop switching run measured 12.001 V and 1.503 A respectively.

## Solver and limits of the design

The verified open-loop solver settings were retained: `ode23t`, maximum step `5e-6 s`, relative tolerance `1e-4`. The final simulation extends to 0.25 s for startup, load-step, and line-step windows.

The abrupt 10→5 Ω load step produced an **11.45%** maximum output deviation, above the requested **<10%** target. Finite PI comparisons are recorded in [`buck_closed_loop_validation.md`](buck_closed_loop_validation.md); raising the gains did not satisfy that target without eroding the analytical stability margins or worsening the first excursion. The 24→20 V line step produced a larger transient of 24.59%, although output recovered. Meeting tighter disturbance-transient targets with this high-Q, fixed L/C plant may require an explicitly authorized later control or plant change. No dual loop was added in this stage.
