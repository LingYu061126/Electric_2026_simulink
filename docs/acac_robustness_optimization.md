# AC-AC Robustness Optimization Evidence

All final figures use the original full switching model and the 0.8–1.0 s coherent window. The retained model keeps the original controller and physical losses; it adds PFC diagnostic logging only.

## Baseline versus final

| Operating Point | Baseline PF | Final PF | Baseline η (%) | Final η (%) | Final THD max (%) | Decision |
|---|---:|---:|---:|---:|---:|---|
| 36 V / 0.2 A | 0.87938 | 0.87938 | 94.450 | 94.450 | 1.375 | Extended PF and η fail |
| 36 V / 0.5 A | 0.97617 | 0.97617 | 96.848 | 96.848 | 1.216 | Extended PF fails |
| 36 V / 1 A | 0.99272 | 0.99272 | 96.994 | 96.994 | 1.192 | Quality targets pass |
| 36 V / 1.5 A | 0.99573 | 0.99573 | 96.451 | 96.451 | 1.199 | Quality targets pass |
| 36 V / 2 A | 0.99692 | 0.99692 | 95.731 | 95.731 | 1.204 | Quality targets pass |
| 31 V / 2 A | 0.99757 | 0.99757 | 94.979 | 94.979 | 1.183 | Extended η fails |
| 33 V / 2 A | 0.99738 | 0.99738 | 95.337 | 95.337 | 1.189 | Quality targets pass |
| 36 V / 2 A | 0.99692 | 0.99692 | 95.731 | 95.731 | 1.204 | Quality targets pass |
| 39 V / 2 A | 0.99630 | 0.99630 | 96.060 | 96.060 | 1.194 | Quality targets pass |
| 41 V / 2 A | 0.99591 | 0.99591 | 96.267 | 96.267 | 1.192 | Quality targets pass |

## Light-load input-current quality

| Iout (A) | PF baseline | PF final | Iin THD baseline (%) | Iin THD final (%) | DPF final |
|---:|---:|---:|---:|---:|---:|
| 0.2 | 0.87938 | 0.87938 | 17.861 | 17.861 | 0.999050 |
| 0.5 | 0.97617 | 0.97617 | 6.827 | 6.827 | 0.999617 |
| 1 | 0.99272 | 0.99272 | 5.717 | 5.717 | 0.999832 |
| 1.5 | 0.99573 | 0.99573 | — | 5.884 | 0.999893 |
| 2 | 0.99692 | 0.99692 | 5.760 | 5.764 | 0.999942 |

## Low-line power and loss evidence

| Ui (V) | η baseline (%) | η final (%) | Pin final (W) | Pout final (W) | Dominant measured or estimated losses |
|---:|---:|---:|---:|---:|---|
| 31 | 94.979035 | 94.979035 | 116.773 | 110.910 | boost Cu 1.141 W; PFC switch R proxy 1.426 W; unresolved 1.420 W |
| 36 | 95.731093 | 95.731012 | 115.857 | 110.911 | boost Cu 0.834 W; PFC switch R proxy 1.042 W; unresolved 1.243 W |
| 41 | 96.266972 | 96.266972 | 115.216 | 110.915 | boost Cu 0.637 W; PFC switch R proxy 0.796 W; unresolved 1.081 W |

PFC and VSI switch losses are current-path estimates from the declared external resistances; the corresponding switch branch currents were not logged. The unresolved aggregate is the measured Pin–Pout remainder after identified loss terms, not a fabricated component loss.

## Strategy log

- A, smooth PI gain schedule: Kp 0.160 / Ki 100 at light load, nominal Kp 0.105 / Ki 66; averaged crossover/phase margin 1.531 kHz / 72.5° at light load and 1.008 kHz / 75.3° at nominal. At 0.2 A PF 0.88538, η 94.556%; at 0.5 A PF 0.976177. Rejected as an insufficient and load-dependent improvement.
- B, zero-crossing duty correction: 0.2 A PF 0.86287. Rejected because PF decreased.
- D, 50 kHz PFC carrier: 0.2 A PF 0.92492, η 93.811%. Rejected because PF stayed below 0.98 and modeled efficiency decreased. This model does not include semiconductor transition losses, so the physical efficiency penalty at higher frequency may be larger.
- E, 31 V bus-reference screen: 56 V gave η 95.211246% and Uline 30.997113 V; 58 V gave η 95.078249% and Uline 31.599257 V; 59.5 V gave η 94.996378% and Uline 31.949012 V. Rejected because no tested point satisfied both original voltage and strict efficiency limits.
- C, current-reference shaping: analytically screened out. At 0.2 A the measured 0.166 A high-frequency current alone bounds PF near 0.890 even if all low-frequency distortion vanished. A reference reshaping pass could not meet 0.98 without reducing the physical switching ripple. No switching simulation or performance claim is assigned to C.

The 10–15 kHz reduced-frequency option was ruled out by the measured 20 kHz ripple: at fixed L and voltage, ripple increases approximately inversely with carrier frequency. The 50 kHz test retained the 1 µs controller step (20 samples per carrier period) and 1 µs dead time (5% of the period); switching events and EMI spectral lines move upward. The model does not resolve all transition-loss and conducted-EMI effects. Burst mode and SVPWM were not introduced after the targeted tests failed to support a robust all-range improvement.

## Figures

[0.2 A before/after](../results/robust_02A_before_after.png), [31 V before/after](../results/robust_31V_before_after.png), [PF versus load](../results/robust_pf_vs_load.png), [efficiency versus input](../results/robust_efficiency_vs_input.png), [six-point operating map](../results/robust_operating_map.png).
