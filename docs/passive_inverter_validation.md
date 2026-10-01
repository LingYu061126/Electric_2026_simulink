# Passive Inverter Validation

## Validation state

| Check | Result | Evidence |
| --- | --- | --- |
| created | YES | Independent model saved at [single_phase_passive_inverter_r2024a.slx](../models/single_phase_passive_inverter_r2024a.slx) |
| opened | YES | Saved model reopened and inspected in MATLAB R2024a; final <code>model_read</code> confirms four MOSFETs and their D/S/G connections |
| model_check | healthy | Root <code>model_check</code> reports no structural errors |
| compiled | YES | <code>SimulationCommand=update</code> completed |
| simulated | YES | Physical Simscape H bridge ran to 0.20 s using <code>ode23t</code> |
| measured | YES | 15 logged signals; 200,001 gate samples at 1 µs; all checked values finite |
| validated | YES | Gate safety, 50 Hz fundamental, RL current magnitude/phase, output offset, and average load power pass |

Full simulation data are in [passive_inverter_results.mat](../results/passive_inverter_results.mat). Metrics are in [passive_inverter_metrics.json](../results/passive_inverter_metrics.json). Run [validate_passive_inverter.m](../scripts/validate_passive_inverter.m) to repeat the simulation and regenerate the data and figures.

## Gate safety

- Leg A shoot-through (<code>g1 &amp;&amp; g2</code>): **0 samples**
- Leg B shoot-through (<code>g3 &amp;&amp; g4</code>): **0 samples**
- Full-run gate samples checked: **200,001** at **1.000 µs**
- Commanded dead time: **1.000 µs**
- Measured median dead time: **1.000 µs** on both legs
- Minimum measured interval: **approximately 1.000 µs** on both legs

Both-off intervals are visible in the PWM plot. The internal integral protection diode is enabled on all four MOSFETs and provides the RL current's reverse path during commutation. No external antiparallel diode is used.

## Output

The measured output frequency comes from a least-squares fundamental fit to physical <code>vAB</code> over 0.10–0.20 s:

| Quantity | Theory | Simulation | Error |
| --- | ---: | ---: | ---: |
| Fundamental peak | 38.400000 V | 37.098216 V | 3.391% |
| Fundamental RMS | 27.152900 V | 26.232088 V | 3.391% |
| Fundamental frequency | 50.000000 Hz | 49.996820 Hz | 0.0064% |
| Mean <code>vAB</code> | 0 V | −6.03e−13 V | — |

The directly measured differential sensor agrees with <code>vA−vB</code> to <code>2.01e−14 V</code> maximum error after resampling. Pole and differential voltages are shown in [inverter_bridge_voltage.png](../results/inverter_bridge_voltage.png).

## Load current

For <code>Z=10+j2π(50)(0.02) Ω</code>:

- Theoretical <code>I1_rms</code>: **2.299126 A**
- Simulated <code>I1_rms</code>: **2.221172 A**
- Error from ideal theory: **3.391%**
- Theoretical lag: **32.141908°**
- Simulated lag: **32.150027°**
- Phase error: **0.008119°**

The load current is continuous through the switching intervals and lags the fundamental voltage as an inductive load should. The 1 µs gate plot is [inverter_pwm.png](../results/inverter_pwm.png); three load-voltage/current cycles are in [inverter_load.png](../results/inverter_load.png).

## Harmonics

Orthogonal projection extracts the 50 Hz fundamental. THD is computed from the 0.10–0.20 s record resampled at 1 MHz, using integer 50 Hz harmonic bins through the 500 kHz Nyquist limit:

- <code>vAB</code> voltage THD: **80.804786%**
- <code>iLoad</code> current THD: **0.787065%**

The unfiltered bridge voltage is PWM, so its high THD is expected. The RL load attenuates the switching harmonics, giving much lower current THD.

## Power

Over 0.10–0.20 s:

| Quantity | Measured |
| --- | ---: |
| Total <code>vAB</code> RMS | 33.725747 V |
| Total <code>iLoad</code> RMS | 2.221241 A |
| Average <code>Pload = mean(vAB·iLoad)</code> | 49.322258 W |
| Apparent power <code>S = Vrms·Irms</code> | 74.913017 VA |
| Overall power factor <code>P/S</code> | 0.658394 |
| Fundamental displacement factor | 0.846658 |
| DC source average power | 49.533823 W |

The overall PF uses total PWM voltage/current RMS. The displacement factor uses only the 50 Hz fundamental phase.

## DC offset

The mean differential output over the analysis window is **−6.03e−13 V**, effectively zero. The A/B bridge and gate timings remain balanced over the coherent five-cycle measurement interval.

## Problems encountered

1. The Repeating Sequence block rejected an initial three-point vector edit because the time and output vectors must remain the same length during each parameter update.
2. The first compile found a Boolean-to-double signal mismatch at the gate conversion path.
3. MATLAB rejected the initial multi-series <code>stairs</code> plotting call.

## Fixes

1. Configured the carrier as a two-point −1…+1 ramp and formed the symmetric triangle with <code>2·abs(ramp)−1</code>.
2. Added an explicit Boolean-to-double conversion before each 0/10 V gate Gain and Simulink-PS Converter.
3. Plotted each gate trace with separate <code>stairs</code> calls. The script was rerun to regenerate the figures.

## Remaining risks

- The integral diode uses a no-dynamics I-V model. Reverse recovery, device parasitics, thermal behavior, and real gate-driver delays are outside this switching-topology validation.
- No LC output filter is present; <code>vAB</code> is not a low-distortion sine and its **80.805%** THD is expected for this stage.
- The ideal DC source and device-level approximations do not establish hardware efficiency, ratings, or protection margins.
- MATLAB logged library-link parameter-override warnings for masked block internals; there were no compile errors, structural <code>model_check</code> errors, or simulation failures. These warnings did not affect the measured outputs.

## Conclusion

**Passive inverter passed: YES.** MATLAB R2024a successfully simulated the real Simscape Electrical four-MOSFET H bridge for 0.20 s. The measured <code>vAB</code> has a 49.996820 Hz fundamental, the 10 Ω / 20 mH passive load draws 49.322258 W average, the current lags by 32.150027°, and both bridge legs show zero shoot-through with 1.000 µs dead time.
