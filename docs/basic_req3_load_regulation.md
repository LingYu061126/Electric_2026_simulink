# Basic-3：0–2 A 负载调整率

在同一个 50 Hz、32 V 目标值的物理开关模型上，使用 `Simulink.SimulationInput` 分别覆盖模型工作区的 `Rphase` 与 `LoadEnable`。0 A 点令三相 `fl_lib/Electrical/Electrical Elements/Switch` 断开，保留实际 LC 滤波器、控制器及测量链；不是用极大电阻代替开路。非零电流点使用 `Rphase=(32/sqrt(3))/I_target`。每点独立运行 1 s 的 R2024a Simscape Electrical 开关仿真，0.8–1.0 s 为稳态窗。

| 目标线电流 (A) | 三相线电压均值 RMS (V) | 三相线电流均值 RMS (A) |
| ---: | ---: | ---: |
| 0.0 | 32.01388 | 约 0（小于 1e−6） |
| 0.2 | 32.01421 | 0.200087 |
| 0.5 | 32.01386 | 0.500203 |
| 1.0 | 32.01322 | 1.000359 |
| 1.5 | 32.01415 | 1.500541 |
| 2.0 | 32.01254 | 2.000567 |

用户已明确给出原题负载调整率公式，因此这里以 32 V 为固定分母：

\[
SU=\left|\frac{U_{12}-U_{11}}{32}\right|\times100\%,
\]

其中 `U11=32.01388 V` 为 0 A 真开路线电压均值，`U12=32.01254 V` 为 2 A 线电压均值。实际未舍入数据算得 **SU=0.004171%**，低于 0.3%。所有 18 个线电压读数均处于 31.75–32.25 V；中间点未见异常。改变负载结构后，Basic-1、Basic-2 已重新仿真且通过。

**Basic-3：PASS。** 每点完整数值（包括三相电压、电流、频率、THD、调制峰值及源功率）见 `results/basic_req3_load_regulation.json`；曲线见 `results/basic3_load_regulation.png`，脚本见 `scripts/run_converter1_basic3.m`。
