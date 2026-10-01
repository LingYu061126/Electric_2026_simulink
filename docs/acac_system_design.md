# Single-phase to Three-phase AC-AC Converter

## Requirements and interpretation

The target is an independent MATLAB R2024a Simscape Electrical switching model: 36 V RMS, 50 Hz single-phase input; active PFC and a regulated DC link; then a six-switch, three-phase inverter, output filter, and balanced resistive load. The requested 32 V output is treated as RMS line-to-line voltage. The four acceptance gates are 31.9–32.1 V RMS on each line voltage, 59.8–60.2 Hz, input PF at least 0.98, model efficiency at least 95%, and each of the three line-voltage THDs at most 2%.

## Output power calculation

For a balanced floating-star load:

```text
Vphase = Uline / sqrt(3) = 32 / sqrt(3) = 18.4752 Vrms
Iphase = Iline = 2 A rms
Rphase = Vphase / Iphase = 9.23760 ohm
Pout,theory = 3 Vphase Iphase = sqrt(3) Uline Iline = 110.851 W
```

The load is therefore planned as three equal 9.23760 ohm resistors with an ungrounded star point. The resistor value is not tuned to make the electrical acceptance gates pass; the final report will include the measured line currents.

At 95% efficiency the input real power must be no greater than `110.851/0.95 = 116.685 W`. At unity PF this corresponds to 3.241 A RMS from the 36 V source. The input current will be measured at the source and assessed from `mean(vin*iin)/(Vrms*Irms)` over a steady-state window.

## DC bus selection

For a two-level, three-phase bridge using linear sinusoidal PWM, the maximum fundamental line-to-line RMS voltage is `sqrt(3/8) Vdc = 0.612372 Vdc`. At 60 V this is 36.742 V RMS, and 32 V requires modulation index 0.8709. This leaves useful modulation headroom for dead time, device drops, and filter voltage drop.

With space-vector modulation, the linear maximum is `Vdc/sqrt(2) = 42.426 V RMS` at 60 V. The target uses 75.42% of that maximum. The 60 V bus is therefore the selected initial design point: the boost stage can regulate above the 50.91 V input peak, and both PWM methods have enough voltage margin. The model will still verify the loaded bus and modulation limits; this calculation alone is not a pass result.

## PFC topology and switching design

The preferred first attempt is a bridgeless totem-pole boost PFC, with one high-frequency leg, one line-frequency leg, a series boost inductor, and a common DC-link capacitor. The fast leg is planned at 20 kHz. For a boost stage, the approximate worst-case inductor ripple occurs near `|vin| = Vdc/2`:

```text
Delta_i_pp ~= Vdc / (4 Lpfc fsw)
           = 60 / (4 * 1.0 mH * 20 kHz)
           = 0.75 A
```

The selected starting value is `Lpfc = 1.0 mH`, giving about 16% of the approximately 4.59 A peak input-current demand at 116.7 W and unity PF. Its copper resistance, switch losses, current waveform, and conduction path in both AC half-cycles must be verified in the physical model. The line-frequency leg must commutate only with input polarity; the fast leg performs PWM. A half-cycle path review and gate-safety check are required before simulation.

If the R2024a ideal-switch model or its available reverse-conduction paths prevent reliable totem-pole operation after documented debugging, the explicit fallback is a four-diode input bridge plus a one-switch active boost PFC. That remains an active current-shaping rectifier. Any topology change and reason will be recorded in the validation report.

## DC-link capacitor

Single-phase input power has an unavoidable 100 Hz component. The outer DC-voltage loop will be kept well below 100 Hz so it does not force that ripple into the input-current reference. For constant output power, the approximate 100 Hz bus ripple is:

```text
Delta_V_pp ~= P / (2 pi fline Cdc Vdc)
           ~= 110.851 / (2 pi * 50 * 4700 uF * 60)
           ~= 1.26 V peak-to-peak
```

At the 116.685 W input-power limit the estimate is 1.32 V peak-to-peak. The starting value is `Cdc = 4700 uF`; capacitor ESR and startup energy are to be included and the actual bus ripple reported. The 100 Hz component cannot be removed by a fast voltage regulator without degrading input-current quality.

## Control and modulation plan

The PFC uses an outer bus-voltage PI and an inner inductor-current PI. The inner reference is proportional to signed input voltage so the input current remains in phase with voltage on both half-cycles. The outer-loop bandwidth target is initially 5–10 Hz, below the 100 Hz power ripple; the current loop starts near 1 kHz at 20 kHz switching. Controller gains and margins remain provisional until the averaged plants are checked and the physical switching stages are simulated.

The inverter output frequency reference is 60 Hz. The planned switching frequency is 12.6 kHz. Three balanced sinusoidal references will drive SVPWM if the R2024a implementation can be validated within the schedule; otherwise sinusoidal PWM is acceptable at the selected 60 V bus. The output voltage loop will regulate the fundamental amplitude and limit modulation to its linear region. Frequency and RMS voltage must be estimated from measured output waveforms, not inferred from their references.

## Three-phase output filter and load

An initial per-phase filter design is `Lf = 1.0 mH`, `Cf = 25.33 uF`, with a `1.0 ohm` series damping resistor in each capacitor branch. Its nominal resonance is:

```text
fLC = 1 / (2 pi sqrt(Lf Cf)) ~= 1.00 kHz
```

This is 16.7 times the 60 Hz output fundamental and one-thirteenth of the 12.6 kHz inverter switching frequency. The damping and switching-harmonic attenuation are starting design values only; the output line-voltage THD gate requires the full switching model and may require a documented filter/controller refinement. Each phase feeds one 9.23760 ohm resistor; the star point remains floating and is not connected to DC return, earth, or a DC midpoint.

## Loss model and solver

The validated R2024a ideal-switch MOSFET is the initial switching device because its exact D/S/G mapping has already been read from the saved single-phase model. Since it does not by itself establish hardware switching-loss performance, the new model must include declared nonzero conductive resistances for semiconductor paths, PFC and output inductors, DC-link and filter capacitors where supported. The validation report will distinguish the measured Simscape model efficiency from a hardware efficiency prediction and list losses not represented by the chosen ideal-switch device.

The first run will use the existing R2024a Simscape solver workflow and an appropriately bounded maximum step for 20 kHz and 12.6 kHz switching. The final result must come from the integrated physical switching model, including PFC, DC link, six inverter switches, filter, and load. Separate-stage checks are development evidence only.

## Staged development and remaining design work

1. Size and record the stages (this document).
2. Build and validate the PFC alone into an equivalent approximately 116.7 W DC load.
3. Build the three-phase VSI, LC filter, and load against a fixed DC source; verify RMS, frequency, THD, and dead time.
4. Add output-voltage feedback and verify regulation.
5. Integrate the physical PFC bus and enable the inverter after bus soft-start.
6. Run the complete switching model and calculate the four requirements from steady-state measured signals.

No requirement is marked passed until the corresponding measurement is produced. The final report will also state the assumed loss model, converter control margins, and any residual simulation limitations.

## Implemented switching model and controller

The saved model implements the bridgeless totem-pole topology. The input passes through two precharge resistors (10 Ω and 2 Ω, each independently bypassed after a bus threshold and near an AC zero crossing), an input current sensor, a 1 mH boost inductor with 80 mΩ series resistance, and the fast-leg midpoint. Four `MOSFET (Ideal, Switching)` blocks form the two legs; each has an external 50 mΩ series resistor. The PFC uses 20 kHz carrier PWM on the fast leg and line-polarity commutation on the slow leg. A common 4700 µF capacitor with 40 mΩ ESR holds the 60 V link. The capacitor and six-switch inverter share the physical bus. Separate series physical current sensors measure PFC DC output current before the capacitor/inverter branch and inverter DC input current after that branch.

On the positive AC half-cycle, the slow lower switch joins AC neutral to DC−. The fast lower switch charges the boost inductor from AC line to DC−; when it releases, inductor current flows through the fast upper path into DC+ and the capacitor/load, then returns through DC− and the slow lower switch. On the negative half-cycle the slow upper switch joins AC neutral to DC+, and the fast upper switch is the inductor charging path; when it releases, inductor current transfers through the fast lower path and the DC link before returning through the slow upper switch. The complementary fast commands and 1 µs turn-on delay provide a freewheel interval at commutation. The saved PFC subsystem's `model_read` connections verify the boost inductor at the fast-leg midpoint, the slow leg at AC neutral, both upper devices at DC+, both lower devices at DC−, and all gate converters on the G ports.

The inner current loop uses signed input current error and a duty feedforward `1−|vin|/max(vdc,20)`. Its PI gains are `Kp=0.105` and `Ki=66 s⁻¹`. The outer bus loop commands input conductance `g`, with `i_ref=g·vin`, `Kp=0.012 S/V`, `Ki=0.50 S/(V·s)`, conductance limit 0–0.11 S, and a 0–60 V ramp over 150 ms. Both loops use conditional integration against saturation.

For an *averaged, unsaturated* boost-current plant `G_i(s)≈Vdc/(Lpfc s)`, and a half-period PWM delay at 20 kHz, the nominal inner crossover is approximately **1.008 kHz** with **75.3° phase margin**. Its PI zero is 100 Hz. For the low-frequency bus plant `G_v(s)≈Vin,rms²/(Cdc Vdc s)`, treating the inner current loop as unity gain, the nominal outer crossover is approximately **10.41 Hz** with **57.5° phase margin**; its PI zero is 6.63 Hz. The inner/outer crossover ratio is about **96.8**. These are averaged-model design estimates, not loop-gain measurements from the nonlinear switching simulation; they omit sensor filtering, operating-point changes, saturation, and the 100 Hz power ripple. The 10.41 Hz outer crossover stays well below 100 Hz.

The implemented inverter uses 12.6 kHz three-phase SPWM, a 60 Hz internal angle, 1 µs turn-on dead time in each of three legs, and a bus-qualified enable at `t≥0.18 s` and `Vdc≥52 V`. Three independent phase-RMS PI trims (`Kp=0.030`, `Ki=0.80 s⁻¹`) adjust the phase modulation amplitudes around `m_ff=2√2·Vphase,ref/Vdc`, with a 0.95 limit. The phase voltage reference ramps to `32/√3 V RMS` during 0.18–0.23 s. The phase-voltage RMS estimate has a 20 ms first-order squared-voltage average. The output filter uses 1 mH per-phase inductance (80 mΩ winding resistance), 25.33029591 µF per-phase capacitance with 1 Ω series damping, giving nominal `fLC≈1.00 kHz`, between 60 Hz and 12.6 kHz. The load star and filter capacitor neutral are connected to one another and float relative to DC− and electrical reference.

The Simscape model uses `daessc`, maximum step 1 µs, and relative tolerance `1e−4`. The explicit resistances represent conduction, winding, and capacitor ESR losses. Ideal-switch transition losses, semiconductor temperature behavior, magnetic core losses, and hardware gate-driver losses are not represented; measured efficiency is therefore specific to this simulation loss model.

For the loaded filter, an approximate per-phase small-signal voltage transfer from bridge midpoint to load is

```text
H(s) = R(1+s C rC) / (a0+a1 s+a2 s^2)
a0 = R+rL
a1 = L+rL C(R+rC)+R C rC
a2 = L C(R+rC)
```

With `R=9.237604 Ω`, `L=1 mH`, `C=25.33029591 µF`, `rL=0.08 Ω`, and `rC=1 Ω`, this gives a loaded natural frequency of about **954 Hz**, `Q≈1.24`, and a calculated resonance peak of **1.35× (2.62 dB) near 787 Hz**. The 1 Ω capacitor-series resistor damps the peak. These are linear filter estimates; the switching FFT in the validation report measures the actual output harmonics.
