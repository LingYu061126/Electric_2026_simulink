# Single-phase Passive-load Inverter Design

## Definition of passive inversion

This model converts energy from a **48 V DC source** into a 50 Hz PWM voltage across a floating passive R-L load. There is no AC source, grid connection, synchronization, or power controller. The AC-side circuit contains only the resistor and inductor, so this is a DC-to-AC passive-load inverter.

## Topology

The independent R2024a model is [single_phase_passive_inverter_r2024a.slx](../models/single_phase_passive_inverter_r2024a.slx). Its power path is four real Simscape Electrical MOSFET (Ideal, Switching) blocks arranged as a full H bridge:

| Device | Leg | D | S |
| --- | --- | --- | --- |
| S1 | A upper | +Vdc | A midpoint |
| S2 | A lower | A midpoint | DC return |
| S3 | B upper | +Vdc | B midpoint |
| S4 | B lower | B midpoint | DC return |

The live R2024a port map is G=LConn1 (physical signal input), D=RConn1, and S=RConn2. The exact MOSFET library path contains line breaks: <code>ee_lib/Semiconductors &\nConverters/MOSFET\n(Ideal,\nSwitching)</code>. Each of the four blocks was inspected in the final model with <code>model_read</code>; the diagram does not infer D/S from block placement.

The DC source positive node supplies both upper-device drains. The source negative node is the common return and connects to the Electrical Reference and one Solver Configuration block. The load stays floating between A and B. A dedicated differential Voltage Sensor has its positive terminal at A and negative terminal at B, so the reported output is <code>vAB = vA - vB</code>. Separate pole sensors measure <code>vA</code> and <code>vB</code> relative to DC return.

The passive R-L branch is wired A → Current Sensor → 10 Ω resistor → 20 mH inductor → B. Positive <code>iLoad</code> therefore flows from A to B. The actual R2024a block references and all power-stage connections are recorded in the saved model.

## DC link

- DC source: 48 V
- Measured DC link in the steady analysis window: 48.000000 V
- The source is the model's only energy source.

## SPWM

Unipolar SPWM uses:

- <code>ma = 0.8</code>
- <code>f1 = 50 Hz</code>
- <code>fsw = 10 kHz</code>
- <code>vrefA = ma sin(2πf1t)</code>
- <code>vrefB = -vrefA</code>
- One shared triangle carrier spanning −1…+1

The carrier is generated in the model from a repeating −1…+1 ramp followed by <code>2·abs(ramp) − 1</code>. The resulting carrier is a symmetric triangle with a 100 µs period. The comparators implement <code>pwmA = (vrefA &gt; carrier)</code> and <code>pwmB = (vrefB &gt; carrier)</code>. The measured switching frequency from <code>pwmA</code> is 10,000.000000001 Hz.

For ideal complementary pole averages,

\[
\bar v_A = \frac{V_{dc}}{2}(1+m_a\sin\omega t),\qquad
\bar v_B = \frac{V_{dc}}{2}(1-m_a\sin\omega t),
\]

so

\[
\bar v_{AB}=m_a V_{dc}\sin\omega t.
\]

Therefore the ideal full-bridge fundamental is <code>V1_peak = ma·Vdc = 38.4 V</code> and <code>V1_rms = 38.4/√2 = 27.152900 V</code>. This is the full-bridge line-output relation for the actual two-reference modulation used here.

## Gate logic

The comparator outputs are sampled every 1 µs. Each turn-off is immediate; the opposite device's turn-on is delayed by one 1 µs sample:

- <code>g1 = pwmA(k) AND pwmA(k−1)</code>
- <code>g2 = NOT(pwmA(k)) AND NOT(pwmA(k−1))</code>
- <code>g3 = pwmB(k) AND pwmB(k−1)</code>
- <code>g4 = NOT(pwmB(k)) AND NOT(pwmB(k−1))</code>

Thus each leg has a 1 µs both-off interval at commutation. The controller produces Boolean 0/1 gates; each gate is converted to <code>double</code>, scaled to 0/10 V, and sent through its own Simulink-PS Converter (unit V) to the physical-signal G port of its MOSFET.

A control-only copy of the exact gate subsystem was run for the full 0.20 s before running the power stage. It logged 200,001 gate samples at 1 µs spacing and found zero same-leg overlap on both legs. The full power simulation independently found the same result.

## Freewheeling

A live query of all four installed MOSFET masks showed the integral protection diode set to <code>Diode with no dynamics</code> (<code>diode_param=ee.enum.semiconductors.protectionDiode.nodynamics</code>). Its configured forward voltage is 0.8 V, on resistance 0.001 Ω, and off conductance 1e−5 S. This built-in reverse-current path is enabled, so no external antiparallel diodes were added. MathWorks describes the integral protection diode as a reverse-current conduction path for inductive loads in its [MOSFET (Ideal, Switching) documentation](https://www.mathworks.com/help/simscape-electrical/ref/mosfetidealswitching.html).

In the full switching run, load current remained finite through the dead-time intervals; 1,363 samples in the 0.10–0.20 s analysis window had a blanked bridge leg and <code>|iLoad| &gt; 0.5 A</code>. The model resolves the integral diode's simple static I-V behavior, not detailed charge dynamics or reverse recovery.

## Load

- <code>R = 10 Ω</code>
- <code>L = 20 mH</code>
- Load connection: A-to-B, with no load midpoint ground

At 50 Hz,

\[
Z=R+j\omega L = 10+j6.283185\ \Omega,\qquad
|Z|=11.8117\ \Omega.
\]

The theoretical current based on the ideal SPWM fundamental is <code>I1_rms = V1_rms/|Z| = 2.299126 A</code>. Its expected lag is

\[
\phi=\tan^{-1}(\omega L/R)=32.141908^\circ.
\]

## Fundamental voltage theory

The ideal averaged differential voltage has one sinusoidal fundamental at 50 Hz with 38.4 V peak and 27.152900 V RMS. The instantaneous bridge voltage remains switched among approximately <code>+Vdc</code>, <code>0</code>, and <code>−Vdc</code>; it is not expected to look like a filtered sine wave.

The measured fundamental is lower than the ideal calculation because the switching model includes the specified dead time and the integral diode forward drop. No compensation was added to force the simulated result to match the ideal formula.

## Fundamental load-current theory

The RL impedance makes the 50 Hz load current lag the voltage by about 32.14°. Its ideal fundamental RMS is 2.299126 A. Fundamental voltage and current measurements use sine/cosine orthogonal projection of the simulated physical signals over 0.10–0.20 s, not raw PWM RMS.

## Solver

- MATLAB / Simulink / Simscape Electrical: R2024a / 24.1
- Solver: variable-step <code>ode23t</code>
- Maximum step: 5 µs (<code>Tsw/20</code>)
- Relative tolerance: <code>1e-4</code>
- Stop time: 0.20 s
- Gate sampling period: 1 µs
- Steady analysis interval: 0.10–0.20 s

The repeatable run and metric/plot generation script is [validate_passive_inverter.m](../scripts/validate_passive_inverter.m).

## Limitations

- There is no output LC filter. The full-band bridge-voltage THD is therefore high by design; the RL load current has much lower THD.
- The MOSFET and integral diode are switching-level idealized models. The diode has no charge dynamics; parasitic inductance/capacitance, driver propagation mismatch, device heating, and hardware protection are not modeled.
- The DC source is ideal. The model verifies topology, PWM, dead time, fundamental behavior, and power transfer; it is not a hardware efficiency or stress qualification.
- No grid, PLL, dq, P/Q, output-voltage controller, or three-phase subsystem is present.
