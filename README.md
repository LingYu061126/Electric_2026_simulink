# MATLAB Electric

### 电力电子模型与验证 | Power Electronics Models and Validation

本仓库收录基于 MATLAB R2024a 与 Simscape Electrical 的电力电子模型、开关仿真和验证报告，涵盖 Buck 变换器、单相逆变器、并联逆变器系统及 AC–AC 变换器。

This repository brings together power-electronics models, switching simulations, and validation reports built with MATLAB R2024a and Simscape Electrical. Topics include Buck converters, single-phase inverters, parallel inverter systems, and AC–AC conversion.

## 双单相逆变器并联系统 | Dual Single-Phase Parallel Inverter

该模型由两台独立供电、独立控制的 48 V 全桥逆变器组成，支持 24 V RMS / 50 Hz 负载供电、约 4 A 并联负载分担，以及经 24:220 V 变压器并网注入。每台逆变器均配置 0–2 A RMS 电流指令限幅、4 A 瞬时过流锁存和 40 V 直流欠压联锁。

The model has two independently powered and controlled 48 V full-bridge inverters. It supports 24 V RMS / 50 Hz load operation, approximately 4 A parallel load sharing, and grid-current injection through a 24:220 V transformer. Each inverter has a 0–2 A RMS reference limit, a 4 A instantaneous overcurrent latch, and a 40 V DC undervoltage interlock.

- 模型 / Model: [双逆变器并联系统 / Dual inverter system](models/dual_single_phase_parallel_inverter_r2024a.slx)
- 设计说明 / Design notes: [系统设计 / System design](docs/dual_inverter_system_design.md)
- 验证结果 / Validation: [最终报告 / Final report](docs/dual_inverter_final_validation.md) · [汇总指标 / Aggregate metrics](results/dual_inverter_all_metrics.json)

完整回归的 8 个阶段全部通过。关键结果：输出电压 THD（2–50 次谐波）1.8435%，0–2 A 负载调整率 0.1298%，总电流指令误差最高 1.232%，电流比分配误差最高 0.669%。

All eight stages of the full regression passed. Key results: output-voltage THD (harmonics 2–50) of 1.8435%, load regulation of 0.1298% over 0–2 A, maximum total-current command error of 1.232%, and maximum current-ratio error of 0.669%.

### 运行完整验证 | Run the Full Validation

环境：MATLAB R2024a、Simulink 和 Simscape Electrical。将 MATLAB 当前文件夹设为仓库根目录，然后打开并保存模型，再运行总验证脚本。

Requirements: MATLAB R2024a, Simulink, and Simscape Electrical. Set MATLAB's current folder to the repository root, then open and save the model before running the validation script.

```matlab
open_system('models/dual_single_phase_parallel_inverter_r2024a.slx');
run('scripts/run_dual_inverter_full_validation.m');
```

脚本依次运行 Basic-1 至 Basic-4、Bonus-1 至 Bonus-3 和保护故障测试，并在 `results/` 写入阶段指标与图表、汇总 JSON；最终报告写入 `docs/`。

The script runs Basic-1 through Basic-4, Bonus-1 through Bonus-3, and the protection fault tests. It writes stage metrics and figures plus aggregate JSON to `results/`, and the final report to `docs/`.

## 其他模型 | Other Models

| 主题 / Workstream | 模型与文档 / Model and documentation |
| --- | --- |
| AC–AC 变换器 / AC–AC converter | [稳健优化模型 / Robust optimized model](models/acac_robust_optimized_r2024a.slx) · [设计报告 / Design report](docs/acac_final_design_report.md) · [稳健性报告 / Robustness report](docs/acac_robustness_final_report.md) |
| Buck 变换器 / Buck converters | [双环模型 / Dual-loop model](models/buck_dual_loop_r2024a.slx) · [设计 / Design](docs/buck_dual_loop_design.md) · [验证 / Validation](docs/buck_dual_loop_validation.md) |
| 单相逆变器 / Single-phase inverter | [PR 逆变器模型 / PR inverter model](models/single_phase_pr_inverter_r2024a.slx) · [设计 / Design](docs/pr_inverter_design.md) · [验证 / Validation](docs/pr_inverter_validation.md) |
| 能量回馈 / Energy recovery | [试验台模型 / Testbench model](models/energy_recovery_testbench_r2024a.slx) · [最终报告 / Final report](docs/converter_energy_recovery_final_report.md) |

AC–AC 固定设计验证：`scripts/run_acac_robustness_validation.m`；单个候选方案评估：`scripts/run_acac_robustness_optimization.m`。

AC–AC fixed-design validation: `scripts/run_acac_robustness_validation.m`; single-candidate evaluation: `scripts/run_acac_robustness_optimization.m`.

## 运行结果 | Generated Results

`results/` 提供 JSON 指标和图表；运行验证脚本可生成完整的 `.mat` 开关波形。

`results/` contains JSON metrics and figures. Run the validation scripts to generate full `.mat` switching waveforms.
