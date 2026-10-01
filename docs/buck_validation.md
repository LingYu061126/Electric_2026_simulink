# Buck Converter Validation

## Environment

| Product | Installed version |
| --- | --- |
| MATLAB | R2024a, 24.1.0.2537033 |
| Simulink | 24.1 |
| Simscape | 24.1 |
| Simscape Electrical | 24.1 |

The model was built and inspected through MATLAB MCP and Simulink Agentic Toolkit in a live MATLAB session. It was compiled and simulated in MATLAB R2024a. The saved model is [`../models/buck_r2024a.slx`](../models/buck_r2024a.slx).

## Model

| Parameter | Value |
| --- | ---: |
| Vin | 24 V |
| Fixed duty | 0.5 |
| PWM frequency | 10 kHz |
| Inductor | 1 mH |
| Capacitor | 470 µF |
| Load | 10 Ω |
| Simulation stop time | 0.1 s |

The open-loop physical power circuit is: 24 V source positive → MOSFET D/S → switching node → inductor current sensor → inductor → output node. The freewheel diode has its **anode at return and cathode at the switching node**. The capacitor and load are connected from output to return. The electrical reference and one Solver Configuration block attach to the same connected network. A Pulse Generator drives a Simulink-PS Converter (unit V), whose physical-signal output drives the MOSFET gate. Vin, Vout, inductor current, load current, and PWM are sent to `To Workspace` blocks and included in the `SimulationOutput`.

## R2024a block paths

- Source: `ee_lib/Sources/Voltage Source`
- MOSFET: `ee_lib/Semiconductors &\nConverters/MOSFET\n(Ideal,\nSwitching)`
- Diode, inductor, capacitor, resistor: `fl_lib/Electrical/Electrical Elements/{Diode,Inductor,Capacitor,Resistor}`
- Voltage and current sensors: `fl_lib/Electrical/Electrical Sensors/{Voltage Sensor,Current Sensor}`
- Electrical reference: `fl_lib/Electrical/Electrical Elements/Electrical Reference`
- Solver Configuration: `nesl_utility/Solver\nConfiguration`
- Simulink-PS and PS-Simulink converters: `nesl_utility/Simulink-PS\nConverter` and `nesl_utility/PS-Simulink\nConverter`

Here `\n` denotes an actual newline in the R2024a library path. `model_read` verified every placed block's reference and port connections. The values of `dc_voltage`, `Rds`, `Vth`, `Vf`, `Ron`, `l`, `c`, `R`, Pulse Generator amplitude/period/width, converter unit, solver, maximum step, and stop time were read back with `get_param` from the saved model.

## MOSFET port probe

See [`buck_mosfet_port_probe.md`](buck_mosfet_port_probe.md). The initially known N-Channel MOSFET has an **electrical** gate and cannot receive the specified physical-signal gate drive directly. The installed `MOSFET (Ideal, Switching)` has `G=LConn1` as a physical-signal input, `D=RConn1` as an electrical port, and `S=RConn2` as an electrical port. A separate live probe connected the converter to G successfully. The final model uses that block with queried parameters `Rds=0.01 Ω`, `Goff=1e-6 1/Ω`, and `Vth=2 V`; the PWM gate voltage is 0/10 V.

## Solver

Variable-step `ode23t`; `MaxStep=5e-6 s` (one twentieth of the 100 µs switching period); relative tolerance `1e-4`; stop time `0.1 s`.

## Validation state

| State | Result | Evidence |
| --- | --- | --- |
| created | YES | Saved `.slx` file |
| opened | YES | `open_system` and live `get_param('buck_r2024a','FileName')` |
| model_check | healthy | MCP `model_check` on root, all checks |
| compiled | YES | `SimulationCommand=update` completed |
| simulated | YES | `sim('buck_r2024a')` completed to 0.1 s; repeated by [`../scripts/validate_buck.m`](../scripts/validate_buck.m) |
| measured | YES | Five timeseries, 20,319 samples each; final 20 ms has 4,001 samples |
| validated | YES | Finite data, 8 V < mean(Vout) < 16 V, measured PWM 10 kHz / 50%, and physical ripple/current checks |

## Numerical results

Measured over `0.08–0.10 s`:

| Metric | Result |
| --- | ---: |
| Vout theoretical, `D × Vin` | 12 V |
| Vout simulated mean | 11.94342085 V |
| Vout error | 0.471493% |
| Vout peak-to-peak ripple | 0.01634168 V |
| Inductor current mean | 1.19427522 A |
| Inductor current minimum | 0.89290653 A |
| Inductor current peak-to-peak ripple | 0.60289521 A |
| Load current mean | 1.19434208 A |
| PWM measured frequency | 10,000 Hz |
| PWM measured duty | 0.500000 |
| Conduction mode | CCM |

For CCM, `ΔiL ≈ (Vin − Vout) D / (L fsw)`. Substituting the measured steady-state Vout yields `0.60282896 A`; the simulated peak-to-peak value differs by `0.01099%`. Using the ideal 12 V gives `0.6 A`. The positive measured minimum current confirms CCM in the steady window. No logged signal contains NaN or Inf.

## Waveforms and data

- [Output voltage, startup to steady state](../results/buck_vout.png)
- [Steady-state inductor current](../results/buck_inductor_current.png)
- [PWM across five switching periods](../results/buck_pwm.png)
- [Vin, Vout, iL, and PWM overview](../results/buck_overview.png)
- [Full simulation result MAT file](../results/buck_results.mat)
- [Numerical metrics JSON](../results/buck_metrics.json)

## Problems encountered and fixes

1. **MATLAB MCP could not attach.** No MATLAB desktop session was running. Started the installed R2024a launcher; the MCP library check and model calls then worked.
2. **Gate-port mismatch.** The initially documented N-Channel MOSFET's G port was electrical, contrary to the proposed direct Simulink-PS gate route. Probed the available ideal switching MOSFET and selected its verified physical-signal G port. No D/S port was inferred from location.
3. **Model save folder missing.** Created `models/` explicitly and saved the `.slx` there.

MATLAB also printed library-link layout warnings while exporting plots. The actual update, simulations, and data reads completed; these warnings did not invalidate the numerical result.

## Remaining risks

- The open-loop LC startup overshot to approximately **21.38 V** and the initial inductor current peaked at approximately **8.72 A**. The requested acceptance window applies to the final 20 ms, not startup protection.
- The ideal switching MOSFET and near-ideal diode are suitable for topology and switching checks, not semiconductor loss or hardware stress prediction.
- The automatically arranged flat schematic is electrically traceable via `model_read`, but its visual return routing is long and cluttered. The physical topology, rather than drawing quality, is the validated result.

## Conclusion

**Buck simulation passed: YES.** The R2024a Simscape Electrical model actually compiled, ran to 0.1 s, produced numeric measurements, and passed the stated steady-state acceptance check for the 24 V → approximately 12 V, 10 kHz, `D=0.5` Buck converter.
