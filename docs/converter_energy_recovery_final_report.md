# 能量回馈型变流器负载试验装置

## 1 题目要求

MATLAB R2024a Simscape Electrical 真实物理开关模型验证：50 Hz 三相 32±0.25 V RMS 线电压、约 2 A RMS、三线电压 THD≤2%、0–2 A 负载调整率<0.3%、20–100 Hz 每 1 Hz 变频，以及主动整流回馈同一 DC 母线。所有交流电压、电流结果均为 RMS。

## 2 总体设计

一台直流源→Converter 1 六开关 VSI→三相 LC→三相 3 mH 连接电感→Converter 2 六开关有源整流桥→原直流母线。基础负载是浮置星形电阻；回馈测试时三相物理开关真正断开电阻支路。Basic 和 Bonus 共享同三个子系统引用文件，回馈阶段没有替换 Converter 1。

## 3 Converter 1

### topology

三相两电平六 MOSFET VSI；Basic 模型和回馈模型共享 `subsystems/converter1_inverter_r2024a.slx`。

### DC voltage choice

60 V 是设计假设，不是题面已知值。理想 SPWM 所需调制指数 `2√2·(32/√3)/60=0.870930`。

### PWM

12.6 kHz 三相 SPWM；统一 `Fout_Hz` 控制 20–100 Hz。

### dead time

每桥臂 1 μs 开通死区；全程六对门极重叠计数为 0。

### LC filter

每相 1 mH、80 mΩ 电感，25.33 μF 电容及 1 Ω 阻尼；谐振频率约 1000.0 Hz，处于 100 Hz 输出与 12.6 kHz 开关频率之间。

### output control

基于直流电压的调制前馈、独立三相慢速幅值 PI 和随 `1/Fout_Hz` 缩放的电压平方估计；六开关与控制器分别为共享子系统引用。

## 4 Basic Requirement 1

Uab/Ubc/Uca=32.01272/32.01241/32.01249 V；Ia/Ib/Ic=2.00058/2.00057/2.00056 A；实测频率约 50.00006 Hz；三相相位差约 −120°，无显著 DC 偏置。**PASS**。

## 5 Basic Requirement 2

0.8–1.0 s 的 10 周期相干 FFT：Uab/Ubc/Uca 第 2–50 次谐波 THD=1.1874%/1.1276%/1.1941%，均低于 2%。**PASS**。

## 6 Basic Requirement 3

### load regulation definition

按用户给出的公式 `SU=abs((U12-U11)/32)×100%`，32 V 为固定分母。

### no-load

三相真实物理断开，非大电阻近似；0 A 时 `U11=32.013876 V`。

### full-load

2 A 时 `U12=32.012541 V`。

### sweep

0/0.2/0.5/1.0/1.5/2.0 A 六点实测，线电压全局范围 32.011264–32.015882 V，`SU=0.004171%<0.3%`。**PASS**。

## 7 Basic Requirement 4

### 20–100 Hz

### 1 Hz steps

全部 81 个整数频点分别做了物理开关仿真；20/30/40/50/60/70/80/90/100 Hz 另做完整 1 s 独立验证。最大实测频率误差 0.08202 Hz，线电压全局 32.01981–32.06075 V，所有点稳定。0.5 Hz 是内部检查界限，不是题面误差要求。**PASS**。全部 81 行数据在 `results/basic_req4_frequency_sweep.json`。

## 8 Energy Recovery Architecture

回馈模型物理拓扑在 Bonus-1/2 间固定；两座桥与 DC 链接到同一源。正 `Id_source` 表示源供能，正 `Id_return` 表示 Converter 2 向原母线注入能量，均直接按传感器方向积分。

## 9 Converter 2

### topology

三相六真实 MOSFET 有源整流桥，12.6 kHz SPWM 与 1 μs 开通死区。

### connection unit

每相 3 mH、50 mΩ；`Δi_pp≈60/(4·0.003·12600)=0.397 A`，为 2 A 额定值的约 19.8%。

### synchronization

共享 `Fout_Hz=50` 的内部电角度，以实际三相电压前馈和电流测量检验 d/q 方向。

### dq current control

正向电流由 Converter 1 流入 Converter 2；`L·di/dt=v1−v2−R·i`。所用 sin 基底的 d/q 方程、300 Hz PI 设计和符号见 `docs/energy_recovery_validation.md`。

## 10 Bonus Requirement 1

### current

三相实测 1.2294/1.1941/1.2068 A RMS，均≥1 A。

### energy direction

Converter 1 输出 67.296 W 交流有功；Converter 2 吸收 67.276 W 交流有功，向原母线回注 66.826 W 直流有功；源仍正向输出 1.255 W。**PASS**。

## 11 Bonus Requirement 2

### Pa

60 V 直流源平均电流 +0.054113 A，`Pa=3.246795 W`；50 Hz 三相线电压均约 32.013 V、线电流 2.0046/2.0060/2.0077 A。

### source-current reduction

2 A 电阻负载基线源功率 112.626044 W；回馈后源功率下降 97.1172%。

### recovery ratio

Converter 1 交流输出 107.767 W，返回同母线直流 106.443 W，工程辅助回收比 98.7714%。该比值不是题面评分公式。**PASS，Pa=3.247 W**。

## 12 Additional Engineering Feature

“其它”未给量化门槛，故本项称为附加工程功能而非题面评分通过。3.0 A RMS 超额参考触发 2.2 A RMS 限幅，限幅标志有效比例 1.000，参考峰值不超过 3.1113 A；模型保持数值稳定。

## 13 Test Points

`TestPoints` 永久记录 Ud、Id_source、三线电压、三线电流、三相电压、滤波电流、三相调制量、Converter 1 六门极；回馈模型另记录 Converter 2 三相电流、三相桥端电压、直流回流电流和功率、六门极、d/q 电流、限幅状态。测试时不重新接线。

| 题目测试点 | `To Workspace` 信号名 |
| --- | --- |
| TP_Ud / TP_Id_source | `acac_vdc` / `tp_id_source` |
| TP_Uab / TP_Ubc / TP_Uca | `acac_uab` / `acac_ubc` / `acac_uca` |
| TP_Ia / TP_Ib / TP_Ic | `acac_ia` / `acac_ib` / `acac_ic` |
| TP_Va / TP_Vb / TP_Vc | `acac_va` / `acac_vb` / `acac_vc` |
| TP_filter_current_A/B/C | `tp_filter_current_a`, `tp_filter_current_b`, `tp_filter_current_c` |
| TP_modA/B/C | `tp_modA`, `tp_modB`, `tp_modC` |
| TP_gate1…TP_gate6 | `acac_qah`, `acac_qal`, `acac_qbh`, `acac_qbl`, `acac_qch`, `acac_qcl` |
| TP_Conv2_Iabc | `tp_conv2_ia`, `tp_conv2_ib`, `tp_conv2_ic` |
| TP_Conv2_DC_voltage / TP_Conv2_DC_current | `tp_conv2_dc_voltage` / `tp_conv2_dc_return_current` |
| TP_return_power | `tp_return_power` |

## 14 Protection

Converter 2 仅在使能、t≥0.25 s、50≤Vdc≤70 V 时开门极；2.2 A RMS 限流为 2 A 额定值的 110%。50/70 V 是相对 60 V 标称母线的启动/过压阈值；1 μs 死区与门极重叠检查覆盖两座桥。

## 15 Problems and Fixes

81 点扫描曾使默认 `/tmp` SDI 仓库耗尽；已将缓存移至用户磁盘并逐轮清理由脚本新建的 SDI run。插入回流电流传感器时，源侧正母线曾被断开；根据 `model_read` 恢复正确物理节点后再仿真。双桥共母线存在零序电流，用浮置中性点相电压计算交流功率会漏算共模项，最终改用三相端对 DC− 的直接物理电压测点。

## 16 Limitations

当前证据为 R2024a Simscape Electrical 开关模型验证，不是硬件鉴定。尚未建模开关过渡能量、热行为、磁芯损耗、全部寄生参数、实际驱动器不一致和传感器误差。连接电感的节点功率积分与 `R·i²+dE/dt` 在 2 A 窗口相差 0.233 W（传输功率的 0.216%）；数值残差在报告中保留，不把它解释为负损耗。

## 17 Final Results

| Requirement | Target | Measured | Result |
| --- | --- | --- | --- |
| Basic-1 voltage | 32±0.25 V RMS | 32.0127/32.0124/32.0125 V | PASS |
| Basic-1 frequency | 50 Hz | 50.0001 Hz mean | PASS |
| Basic-1 current | 约 2 A RMS | 2.0006/2.0006/2.0006 A | PASS |
| Basic-2 THD max | ≤2% | 1.1941% | PASS |
| Basic-3 SU | <0.3% | 0.004171% | PASS |
| Basic-4 frequency range | 20–100 Hz / 1 Hz | 81 点，最大误差 0.0820 Hz | PASS |
| Bonus-1 I1 | ≥1 A RMS | 最小 1.1941 A | PASS |
| Bonus-1 returned power | >0 W | 66.826 W | PASS |
| Bonus-2 Pa | 越小越好、源非负 | 3.247 W | PERFORMANCE RESULT |
| Bonus-2 source-power reduction | 比基线减少 | 97.117% | PASS |
| Bonus-2 recovery ratio | 工程辅助指标 | 98.771% | REPORTED |

最终回归：Basic-1/2、0/2 A 端点、20/50/100 Hz 均通过；端点 `SU=0.004085%`。

**结论：** 在 MATLAB R2024a 真实 Simscape Electrical 开关模型内，基本要求 1–4 均由实测数据通过；Converter 2 在同一固定拓扑下实现主动整流回馈，在 50 Hz / 32 V / 2 A 工况使直流源主要承担模型损耗，实测 `Pa=3.247 W`。
