# AC-AC Robust Operating-range Optimization

## Baseline

Original Requirements 1–7 individually passed in the prior report. The new target asks for PF ≥ 0.98, model efficiency ≥ 95%, and line-voltage THD ≤ 2% throughout the extended operating range.
At 36 V / 0.2 A / 30 Hz, baseline PF was 0.87938227 and efficiency 94.450256%. At 31 V / 2 A, baseline efficiency was 94.979035%.

## Root-cause Analysis

### Light-load PF

- 0.2 A: PF 0.879382, DPF 0.999050, I1 0.3266 A, Irms 0.3710 A, 2–50th THD 17.86%, >2.5 kHz current 0.1661 A.
- 0.5 A: PF 0.976171, DPF 0.999617, I1 0.7958 A, Irms 0.8149 A, 2–50th THD 6.83%, >2.5 kHz current 0.1664 A.
- 1 A: PF 0.992719, DPF 0.999832, I1 1.5889 A, Irms 1.6002 A, 2–50th THD 5.72%, >2.5 kHz current 0.1671 A.
- 2 A: PF 0.996925, DPF 0.999944, I1 3.2184 A, Irms 3.2281 A, 2–50th THD 5.76%, >2.5 kHz current 0.1682 A.

PF = DPF × I1rms/Irms agrees with direct P/(Vrms Irms) within numerical precision for the pure-sine input source. At 0.2 A, measured Pin is 11.746 W, fundamental reactive power about 0.512 var, and nonfundamental distortion apparent power 6.339 VA. DPF is near unity while 0.166 A high-frequency current remains nearly unchanged from 2 A. The dominant limitation is fixed switching ripple relative to small fundamental current; the 3rd, 5th and 7th harmonics and a zero-crossing spike add distortion. The controller log shows conductance command 0.00834–0.01034 S, no duty-floor hits and no evidence of quantization. The upper duty clamp is reached near zero crossing; DC-link charging pulses were not identified as the dominant 0.2 A PF loss.

### 31 V efficiency

The measured 31 V Pin–Pout loss is 5.863 W. The boost inductor copper term is 1.141 W; the PFC external switch-resistance current-path estimate is 1.426 W; DC-link ESR is 0.261 W. From 36 to 31 V total loss rises about 0.917 W, of which these three terms account for about 0.741 W (81%). The switch estimates are not direct branch-power measurements; 1.420 W remains unresolved in aggregate at 31 V. See the [loss decomposition](../results/robust_loss_decomposition.json) and [breakdown](../results/robust_loss_breakdown.png).

## Strategies Evaluated

Four meaningful physical switching strategy tests are documented in [the optimization evidence](acac_robustness_optimization.md): PI gain scheduling, zero-crossing duty compensation, 50 kHz switching, and a bounded 56/58/59.5 V bus-reference study. Each failed either the robust quality target or the protected output requirement, so none was retained. Current-reference shaping was excluded by the ripple bound rather than claimed as a simulation result.

## Final Control Architecture

The retained derived model uses the original 20 kHz continuous-PWM PFC current loop (Kp 0.105, Ki 66), original 60 V bus reference, original 12.6 kHz SPWM inverter, original 1 µs dead time, and unchanged physical/loss parameters. The derived model adds a PFC operating-state logger. A [51-block physical mask audit](../results/robust_hardware_frozen_audit.json) found zero parameter mismatches against the 30 Hz baseline. No gain scheduling, zero-crossing compensation, adaptive bus reference, frequency scheduling, SVPWM or burst mode was retained.

## Final Load Sweep

| Iout target (A) | PF | η (%) | Max line THD (%) | Uline (V) |
|---:|---:|---:|---:|---:|
| 0.2 | 0.879382 | 94.450256 | 1.375 | 32.01322 |
| 0.5 | 0.976171 | 96.848310 | 1.216 | 32.01269 |
| 1 | 0.992719 | 96.993989 | 1.192 | 32.01289 |
| 1.5 | 0.995732 | 96.451390 | 1.199 | 32.01316 |
| 2 | 0.996921 | 95.731012 | 1.204 | 32.00865 |

## Final Input Sweep

| Ui (V) | PF | η (%) | Max line THD (%) | Uline (V) |
|---:|---:|---:|---:|---:|
| 31 | 0.997570 | 94.979035 | 1.183 | 32.00847 |
| 33 | 0.997377 | 95.337176 | 1.189 | 32.00833 |
| 36 | 0.996921 | 95.731012 | 1.204 | 32.00865 |
| 39 | 0.996304 | 96.060395 | 1.194 | 32.00882 |
| 41 | 0.995914 | 96.266972 | 1.192 | 32.00920 |

## Combined Corner Cases

All six combinations below were simulated as actual joint input/load conditions; the overlapping sweep points reuse their own measured switching runs.

| Ui (V) | Iout target (A) | PF | η (%) | Max line THD (%) | Uline (V) | Stable |
|---:|---:|---:|---:|---:|---:|---|
| 31 | 0.2 | 0.896914 | 94.407429 | 1.374 | 32.01323 | PASS |
| 31 | 2 | 0.997570 | 94.979035 | 1.183 | 32.00847 | PASS |
| 36 | 0.2 | 0.879382 | 94.450256 | 1.375 | 32.01322 | PASS |
| 36 | 2 | 0.996921 | 95.731012 | 1.204 | 32.00865 | PASS |
| 41 | 0.2 | 0.872777 | 95.072813 | 1.375 | 32.01282 | PASS |
| 41 | 2 | 0.995914 | 96.266972 | 1.192 | 32.00920 | PASS |

## Regulation

SI span 0.014304%, SI deviation 0.041322%; SU span 0.002708%, SU deviation 0.028743%. Each remains below the original 0.3% limits.

## PF

All tested points PF ≥ 0.98: **FAIL**. Minimum measured PF is 0.872777 at 41 V / 0.2 A.

## Efficiency

All tested points model efficiency ≥ 95%: **FAIL**. Minimum among the six combined corners is 94.407429% at 31 V / 0.2 A.

## THD

All tested points line THD ≤ 2%: **PASS**. The maximum broadband line residual is 1.374989%. The quality flags use exact unrounded measured values and also check 2nd–50th harmonic THD.

## Regression Requirements 1–7

- Req1: **PASS**
- Req2: **PASS**
- Req3: **PASS**
- Req4: **PASS**
- Req5: **PASS**
- Req6: **PASS**
- Req7: **PASS**

## Remaining Limitations

The continuous-PWM 1 mH / 20 kHz PFC produces roughly 0.166 A input high-frequency RMS current at all measured loads. At 0.2 A, this is large relative to the 0.327 A fundamental input current, making PF 0.98 unattainable through the tested PI and zero-crossing tweaks. Increasing to 50 kHz improved PF only to 0.92492 while the modeled efficiency fell to 93.811%. Low-line 31 V operation incurs larger RMS conduction loss. Reducing the DC bus enough to raise its efficiency sacrifices the original 32 V output target; at 59.5 V the exact measured efficiency was 94.996378%, still below 95%.

The loss model includes declared resistive and damping losses but does not fully represent semiconductor switching-transition, magnetic core or thermal losses. Therefore η is the stated model efficiency, not a hardware efficiency prediction. Unresolved loss is explicitly retained rather than allocated to invented components.

A future hardware study could evaluate interleaved PFC phases or a redesigned input inductor to cancel or reduce the measured light-load ripple, while measuring switching and magnetic losses. This is a recommendation inferred from the ripple and loss data; no such hardware change was made or credited in the results above.

## Final Conclusion

Original Requirements 1–7: **PASS**. The robust extended target across the load/input sweeps and six joint corners: **FAIL**. The complete physical R2024a switching simulations do not support a claim that all extended PF, efficiency and THD targets are simultaneously satisfied without modifying the protected design parameters or original output requirements.

[Scorecard](../results/robustness_scorecard.json) · [optimization evidence](acac_robustness_optimization.md) · [final model](../models/acac_robust_optimized_r2024a.slx) · [fixed-design validation script](../scripts/run_acac_robustness_validation.m)
