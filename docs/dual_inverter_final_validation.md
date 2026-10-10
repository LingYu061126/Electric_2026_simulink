# Dual Single-Phase Parallel Inverter — Final Validation

All listed results come from R2024a Simscape Electrical physical switching simulations of the saved model. The final stage order was Basic-1 through Basic-4, Bonus-1 through Bonus-3, then protection.

Overall result: **PASS**

## Model and protection configuration

- Two independent full-bridge inverters, separate 48 V DC sources and separate controllers.
- 220 V RMS, 50 Hz grid through the 24:220 V transformer model.
- Each inverter filter: 1 mH series inductance, 20 µF capacitor, 10 Ω damping resistance.
- Solver: ode23t (variable-step), max step 5e-06 s, RelTol 0.0001, AbsTol auto.
- Protection: 0–2 A RMS branch-reference clamp, 4 A instantaneous overcurrent latch, and 40 V DC undervoltage interlock. Both gate drive and the inverter output isolator follow the local permit.

## Basic requirements

| Stage | Measured result | Requirement | Result |
|---|---:|---:|---|
| Basic-1 | 23.8995 V RMS; 50.0010 Hz; 1.9881 A RMS | 24 V ±0.2 V; 50 Hz ±0.2 Hz; ≈2 A (below 1.8 A fails) | PASS |
| Basic-2 | THD 1.8435% (harmonics 2–50) | ≤2% | PASS |
| Basic-3 | 95.4596% efficiency; Pout 47.516 W / Pdc 49.776 W | ≥88% | PASS |
| Basic-4 | 0.1298% load regulation, 0–2 A | ≤0.2% | PASS |

Efficiency includes the physical 1 W auxiliary-load assumption. Switching-transition losses are not modeled.

## Bonus-1: parallel load operation

| Uo | Frequency | Io total | Io1 | Io2 | Sharing imbalance | Result |
|---:|---:|---:|---:|---:|---:|---|
| 23.9036 V RMS | 50.0010 Hz | 3.9704 A RMS | 1.9852 A RMS | 1.9852 A RMS | 0.0000% | PASS |

## Bonus-2: grid-connected total-current command

| Io set | Io measured | Error | PLLs locked | Gates safe | Result |
|---:|---:|---:|---|---|---|
| 2.00 A | 1.9754 A | 1.232% | PASS | PASS | PASS |
| 2.50 A | 2.4706 A | 1.178% | PASS | PASS | PASS |
| 3.00 A | 2.9696 A | 1.014% | PASS | PASS | PASS |
| 3.50 A | 3.4664 A | 0.960% | PASS | PASS | PASS |
| 4.00 A | 3.9639 A | 0.902% | PASS | PASS | PASS |

## Bonus-3: current-ratio command

| Io set | K set | Io1 | Io2 | K measured | Ratio error | Circulating current stable | Result |
|---:|---:|---:|---:|---:|---:|---|---|
| 1.0 A | 0.50 | 0.3275 A | 0.6576 A | 0.4981 | 0.389% | PASS | PASS |
| 1.0 A | 0.75 | 0.4221 A | 0.5650 A | 0.7471 | 0.385% | PASS | PASS |
| 1.0 A | 1.00 | 0.4935 A | 0.4935 A | 1.0000 | 0.000% | PASS | PASS |
| 1.0 A | 1.50 | 0.5920 A | 0.3920 A | 1.5100 | 0.669% | PASS | PASS |
| 1.0 A | 2.00 | 0.6576 A | 0.3275 A | 2.0078 | 0.391% | PASS | PASS |
| 2.0 A | 0.50 | 0.6587 A | 1.3199 A | 0.4990 | 0.198% | PASS | PASS |
| 2.0 A | 0.75 | 0.8462 A | 1.1292 A | 0.7493 | 0.090% | PASS | PASS |
| 2.0 A | 1.00 | 0.9877 A | 0.9877 A | 1.0000 | 0.000% | PASS | PASS |
| 2.0 A | 1.50 | 1.1865 A | 0.7896 A | 1.5026 | 0.173% | PASS | PASS |
| 2.0 A | 2.00 | 1.3199 A | 0.6587 A | 2.0040 | 0.198% | PASS | PASS |
| 3.0 A | 0.50 | 0.9882 A | 1.9824 A | 0.4985 | 0.302% | PASS | PASS |
| 3.0 A | 0.75 | 1.2720 A | 1.6985 A | 0.7489 | 0.141% | PASS | PASS |
| 3.0 A | 1.00 | 1.4848 A | 1.4848 A | 1.0000 | 0.000% | PASS | PASS |
| 3.0 A | 1.50 | 1.7827 A | 1.1883 A | 1.5002 | 0.011% | PASS | PASS |
| 3.0 A | 2.00 | 1.9824 A | 0.9882 A | 2.0061 | 0.303% | PASS | PASS |

## Protection fault injection

| Test | Vdc1 | Io1 peak | Vdc OK | Trip | Permit | PLL lock fractions | Limited refs | Result |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| dc_undervoltage | 32.00 V | 0.000 A | 0 / 1 | 0 | 0 | 0.770 / 0.770 | 1.00 / 1.00 A | PASS |
| overcurrent_trip | 48.00 V | 4.019 A | 1 / 1 | 1 | 0 | 0.904 / 0.904 | 1.00 / 1.00 A | PASS |
| reference_limit | 48.00 V | 1.219 A | 1 / 1 | 0 | 1 | 0.856 / 0.856 | 2.00 / 1.50 A | PASS |
| grid_voltage_out_of_range | 48.00 V | 0.146 A | 1 / 1 | 0 | 1 | 0.000 / 0.000 | 1.00 / 1.00 A | PASS |
| grid_frequency_out_of_range | 48.00 V | 0.280 A | 1 / 1 | 0 | 1 | 0.000 / 0.000 | 1.00 / 1.00 A | PASS |

## Artifacts

- Aggregate machine-readable results: `results/dual_inverter_all_metrics.json`.
- Stage results and plots: `results/` (Basic-1 through Protection).
- System design notes: `docs/dual_inverter_system_design.md`.
