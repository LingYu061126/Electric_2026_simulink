# 能量回馈试验台验证记录

## 固定拓扑与设计选择

`models/energy_recovery_testbench_r2024a.slx` 由通过 Basic-1–4 的基础模型另存；两模型的 Converter 1 逆变桥、LC 滤波器及控制器分别引用相同的 `subsystems/converter1_inverter_r2024a.slx`、`converter1_filter_r2024a.slx`、`converter1_control_r2024a.slx`。两个六开关桥共用**同一** 60 V 直流源和母线电容，没有第二个独立直流电源。Bonus 测试时基本电阻负载由三相物理开关断开，但保留前端电压测试点。Bonus-1/2 只通过 `SimulationInput` 改变回馈电流参考。

连接单元为三相各 3 mH、绕组电阻 50 mΩ 的真实 Simscape 电感，电流传感器方向从 Converter 1 流向 Converter 2。以 60 V 母线、12.6 kHz 开关频率保守估算，`Δi_pp≈Ud/(4·Lconn·fsw)=0.397 A`，约为额定 2 A 的 19.8%，因此选择 3 mH。Converter 2 为六个实际 MOSFET 的有源整流桥，12.6 kHz SPWM，每桥臂 1 μs 开通死区。

Converter 2 使用内部 50 Hz 角度和实际三相电压、电流。定义正向电流为从 Converter 1 经连接电感流入 Converter 2，d 轴与 `sin(theta)` 对齐，因此正 `id` 对应交流侧吸收有功。逐相物理方程为 `L·di/dt = v1 − v2 − R·i`；在该 Park 基底下，`L·did/dt = vd1 − vd2 − R·id + Lωiq`、`L·diq/dt = vq1 − vq2 − R·iq − Lωid`。控制器以实测电压前馈、交叉项补偿和 d/q PI 生成 Converter 2 桥端电压指令；`iq_ref=0`。300 Hz 电流环设计带宽给出 `Kp=L·2π·300≈5.655 V/A`、`Ki=R·2π·300≈94.248 V/(A·s)`。控制器另含 1.5 kHz 测量滤波、0.15 s 参考缓升与输出限幅。

统一功率符号：`P_source=mean(Ud·Id_source)>0` 表示源供能；`P_return=mean(Ud·Id_return)>0` 表示 Converter 2 向同一母线注入能量。交流功率用三个相端相对 DC− 的**直接物理电压测点**乘以连接单元电流积分。由于双桥共母线可有零序环流，不能只用浮置中性点相电压计算交流有功。

## 0.5 A 电流环烟测

在固定拓扑下，0.5 A RMS 指令的实测线电流为 0.523/0.516/0.512 A；d 轴基波电流为 0.707 A 峰值，与 0.707 A 峰值参考一致，`iq≈0`。Converter 1 交流输出为 28.731 W，Converter 2 桥端交流吸收为 28.851 W，直流回流为 28.656 W，直流源正向供电 0.291 W；系统回流功率小于 Converter 1 交流输出。连接电感节点功率积分与其 `R·i²+dE/dt` 的残差为 0.160 W，即传输功率的 0.558%。直接跨电感电压传感器及两端节点电压传感器给出一致数值；残差的具体原因尚未完全定位，因此保留为数值测量限制，不将其计作实际发电。两座桥六个桥臂的门极重叠计数均为 0。烟测通过。

## Bonus-1：至少 1 A 真实回馈

仅把 Converter 2 电流参考改为 1.2 A RMS，重新运行 1 s 的物理开关仿真，取 0.8–1.0 s 稳态窗。

| 测量 | 结果 |
| --- | ---: |
| Converter 1 输出线电流 RMS | 1.229 / 1.194 / 1.207 A |
| Converter 1 线电压 RMS | 32.013 / 32.012 / 32.014 V |
| 实测频率 | 约 50.000 Hz |
| Converter 1 交流输出功率 | 67.296 W |
| Converter 2 交流吸收功率 | 67.276 W |
| Converter 2 注入原母线的直流功率 | 66.826 W |
| 直流源输出功率 | 1.255 W，`Id_source=0.02091 A` |
| 工程辅助回收比 `P_return/P_Conv1_AC` | 99.303% |
| 连接单元功率积分残差 | 0.199 W，即传输功率的 0.296% |
| 两座桥同桥臂门极重叠 | 全部 0 |

交流电流三相均超过 1 A，交流能量流向 Converter 2，Converter 2 的直流电流确实向原母线回注，源侧仅正向供电；**Bonus-1：PASS**。原始数值见 `results/bonus_req1_energy_recovery.json` 与 `results/regen_testbench_results.mat`，复现脚本为 `scripts/run_bonus1_energy_recovery.m`。

## Bonus-2：50 Hz / 32 V / 2 A 与源功率

继续使用上述固定拓扑，仅将 Converter 2 电流参考设为 2.0 A RMS。仍运行 1 s 真实物理开关仿真，取 0.8–1.0 s 窗口。额定电阻负载基线是同一 Converter 1 设计在 Basic-1 回归中直接测得的 112.626 W 源功率。

| 测量 | 结果 |
| --- | ---: |
| Converter 1 输出线电流 RMS | 2.00457 / 2.00599 / 2.00770 A |
| Converter 1 线电压 RMS | 32.01282 / 32.01214 / 32.01345 V |
| 实测频率 | 约 50.000 Hz |
| Converter 1 交流输出有功 | 107.767 W |
| Converter 2 桥端交流吸收有功 | 107.397 W |
| Converter 2 回注原母线直流功率 | 106.443 W |
| 60 V 源平均电流 | +0.05411 A |
| 源平均输出功率 `Pa` | **3.247 W** |
| 额定电阻负载源功率基线 | 112.626 W |
| 源功率下降 | **97.117%** |
| 工程辅助回收比 `P_return/P_Conv1_AC` | 98.771% |
| 连接单元功率积分残差 | 0.233 W，即传输功率的 0.216% |
| 两座桥同桥臂门极重叠 | 全部 0 |

`Pa` 保持正值，未利用源吸收负功率来人为降低该指标。桥端交流吸收功率高于返回直流功率，系统回收比低于 100%；连接单元传感器积分残差如实列出。理想量级 `sqrt(3)·32·2=110.851 W`，实际三相端功率以传感器逐点乘积积分为准。结果见 `results/bonus_req2_source_power.json`、`results/regen_testbench_results.mat`，复现脚本为 `scripts/run_bonus2_source_power.m`。**Bonus-2：PASS，Pa=3.247 W。**
