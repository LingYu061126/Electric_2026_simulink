# Basic-2：三相线电压 THD 验证

沿用 [Basic-1 模型](../models/converter1_basic_test_r2024a.slx)，参数不变：60 V 设计直流源、50 Hz、32 V RMS 线电压目标、额定 2 A 浮置星形电阻负载。Basic-1 已先通过；此阶段重新运行了完整 1 s 的 R2024a Simscape Electrical 物理开关仿真。

稳态窗为 0.8–1.0 s，恰含 10 个 50 Hz 周期。将真实仿真输出插值到 200 kHz 等间隔序列，去直流分量后执行 FFT；以基波幅值为分母，合成第 2–50 次谐波的 RMS 比值。另报告包含开关纹波的宽带残差，仅作工程辅助指标。

| 线电压 | 第 2–50 次谐波 THD | 宽带残差 | 题面门槛 |
| --- | ---: | ---: | ---: |
| Uab | 1.18737% | 1.34618% | ≤2% |
| Ubc | 1.12758% | 1.29344% | ≤2% |
| Uca | 1.19407% | 1.35228% | ≤2% |

三个线电压均满足门槛，**Basic-2：PASS**。本表是增加三相物理负载开关后的回归结果。数据见 `results/basic_req2_thd.json`，频谱图见 `results/basic2_voltage_spectrum.png`；复现脚本是 `scripts/run_converter1_basic2.m`。
