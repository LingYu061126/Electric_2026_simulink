"""Build the measured AC-AC summary and report from saved switching runs."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RESULTS = ROOT / "results"
DOCS = ROOT / "docs"


def read(name: str) -> dict:
    return json.loads((RESULTS / name).read_text(encoding="utf-8"))


def number(value: float, digits: int = 4) -> str:
    return f"{value:.{digits}f}"


def vec(values: list[float], digits: int = 4) -> str:
    return " / ".join(number(v, digits) for v in values)


def verdict(value: bool) -> str:
    return "PASS" if value else "FAIL"


baseline = read("acac_baseline_60hz_metrics.json")
req5 = read("acac_req5_metrics.json")
req6 = read("acac_req6_load_regulation.json")
req7 = read("acac_req7_line_regulation.json")

combined = {f"requirement_{i}_pass": bool(baseline[f"requirement_{i}_pass"]) for i in range(1, 5)}
combined["requirement_5_pass"] = bool(req5["requirement_5_pass"])
combined["requirement_6_pass"] = bool(req6["requirement_6_pass"])
combined["requirement_7_pass"] = bool(req7["requirement_7_pass"])
combined["requirement_8_defined"] = False
combined["requirements_1_to_7_passed"] = all(combined[f"requirement_{i}_pass"] for i in range(1, 8))
combined["all_explicit_quantitative_requirements_passed"] = combined["requirements_1_to_7_passed"]
combined["Req7_and_original_quality_metrics_pass"] = bool(req7["Req7_and_original_quality_metrics_pass"])
combined["line_sweep_efficiency_ge95_all_points"] = all(v >= 95 for v in req7["efficiency_points_percent"])
combined["load_sweep_PF_ge098_all_points"] = all(v >= 0.98 for v in req6["PF_points"])
combined["all_requirements_simultaneously_satisfied"] = (
    combined["requirements_1_to_7_passed"]
    and combined["Req7_and_original_quality_metrics_pass"]
    and combined["line_sweep_efficiency_ge95_all_points"]
    and combined["load_sweep_PF_ge098_all_points"]
)
(RESULTS / "acac_all_requirements_metrics.json").write_text(
    json.dumps(combined, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8"
)

load_rows = []
for i, current in enumerate(req6["current_points_A"]):
    load_rows.append(
        f"| {current:.1f} | {req6['Rphase_points_Ohm'][i]:.6f} | "
        f"{req6['Uab_points_V'][i]:.4f} / {req6['Ubc_points_V'][i]:.4f} / {req6['Uca_points_V'][i]:.4f} | "
        f"{req6['Uline_average_points_V'][i]:.4f} | {req6['Iline_average_points_A'][i]:.4f} | "
        f"{req6['frequency_points_Hz'][i]:.4f} | {req6['dc_bus_points_V'][i]:.4f} | "
        f"{req6['PF_points'][i]:.5f} | {req6['efficiency_points_percent'][i]:.3f} |"
    )

line_rows = []
for i, voltage in enumerate(req7["input_voltage_points_V"]):
    duty = req7["PFC_duty_min_points"][i]
    duty_text = "未记录" if duty is None else f"{duty:.4f}"
    line_rows.append(
        f"| {voltage:.0f} | {req7['input_voltage_measured_points_V'][i]:.4f} | "
        f"{req7['Uab_points_V'][i]:.4f} / {req7['Ubc_points_V'][i]:.4f} / {req7['Uca_points_V'][i]:.4f} | "
        f"{req7['output_voltage_points_V'][i]:.4f} | {req7['Iline_average_points_A'][i]:.4f} | "
        f"{req7['output_frequency_points_Hz'][i]:.4f} | {req7['dc_bus_points_V'][i]:.4f} | "
        f"{duty_text} | {req7['PF_points'][i]:.5f} | "
        f"{req7['THD_points_percent'][i]:.3f} | {req7['efficiency_points_percent'][i]:.3f} |"
    )

dynamic_figure = RESULTS / "req6_load_dynamic.png"
dynamic_metrics = RESULTS / "acac_req6_dynamic_metrics.json"
if dynamic_figure.exists() and dynamic_metrics.exists():
    dynamic = read("acac_req6_dynamic_metrics.json")
    settling = ["未在观察窗内达到" if v is None else f"{v:.4f} s" for v in dynamic["settling_to_0p3_percent_s"]]
    dynamic_note = (
        "[动态负载切换](../results/req6_load_dynamic.png)来自单独的完整开关仿真："
        f"稳态线电流依次为 {vec(dynamic['measured_current_steady_A'],3)} A，"
        f"平均线电压依次为 {vec(dynamic['line_voltage_steady_V'],3)} V；"
        f"两次阶跃后最大绝对电压偏差为 {vec(dynamic['max_abs_line_voltage_deviation_after_step_V'],3)} V，"
        f"回到 ±0.3% 带并连续保持 20 ms 的时间分别为 {settling[0]} / {settling[1]}；"
        f"对应母线最低值为 {vec(dynamic['dc_bus_min_after_step_V'],3)} V。"
        "动态测试不作为题面硬门槛。"
    )
else:
    dynamic_note = "动态负载切换尚无可信的完整开关仿真图，不纳入本次合格判定。"

report = f"""# 单相输入三相输出 AC-AC 变换器设计报告

## 1. 设计任务

本报告使用 MATLAB R2024a 的完整 Simscape Electrical 开关模型，验证 36 V/50 Hz 单相输入到平衡三相输出。`Uo` 定义为三条线电压的 RMS，`Io` 定义为线电流 RMS。Requirement 1–4 为 32±0.1 V、60±0.2 Hz、约 2 A、输入总功率因数至少 0.98、声明的模型效率至少 95%、三条线电压 THD 各不超过 2%。Requirement 5 将输出改为 30±0.2 Hz；Requirement 6 要求 0.2–2.0 A 电阻负载扫描的调整率 `SI≤0.3%`；Requirement 7 要求 31–41 V 输入扫描的调整率 `SU≤0.3%`。

Requirement 8: No explicit quantitative requirement was provided in the supplied problem statement.

## 2. 总体方案

36 V/50 Hz 单相交流源 → 20 kHz 无桥图腾柱 PFC → 60 V 直流母线 → 六开关三相 VSI → 三相 LC 滤波器 → 浮置星形电阻负载。先整流并调节母线，再由 VSI 合成 60 Hz 或 30 Hz 三相电压，使输出频率独立于输入频率。最终验收使用同一个物理 PFC、母线、逆变器、滤波器和负载同时运行的结果。

## 3. 系统主要参数

| 部分 | 保留设计值 |
|---|---|
| 输入 | 36 V RMS、50 Hz；Req7 扫描 31–41 V RMS |
| PFC | 1 mH 电感、80 mΩ 绕组电阻、20 kHz 开关；四个 MOSFET 支路各 50 mΩ |
| 直流母线 | 60 V 参考、4700 µF、40 mΩ ESR |
| 逆变器 | 六个 MOSFET，12.6 kHz SPWM，1 µs 开通死区 |
| 输出滤波 | 每相 1 mH/80 mΩ、25.33029591 µF、1 Ω 电容串联阻尼 |
| 额定负载 | 浮置 Y 接，每相 9.237604307034 Ω，目标 2 A |
| 仿真与测量 | `daessc`、最大步长 1 µs；总长 1.0 s，0.8–1.0 s 相干窗口 |

## 4. PFC 设计

正半周慢桥臂下管连接交流中性端与 DC−，快桥臂下管导通时电感储能，关断时电感经快桥臂上管向 DC+ 输送能量。负半周由慢桥臂上管换向，快桥臂上管储能、下管续流。快桥臂 20 kHz PWM，慢桥臂只随电网极性换向。1 mH 电感在 60 V、20 kHz 下的近似最大纹波为 `60/(4·1 mH·20 kHz)=0.75 A`。4700 µF 母线电容吸收单相输入的 100 Hz 功率脉动；理论峰峰值约 1.26 V，额定实测见下文。

## 5. PFC 控制

外环以 60 V 母线误差生成输入电导 `g`，内环跟踪 `i_ref=g·vin`，正负半周均保持输入电流与电压同相。外环 `Kp=0.012 S/V, Ki=0.50 S/(V·s)`；内环 `Kp=0.105, Ki=66 s⁻¹`；占空比限于 0.02–0.95。31 V 工况原 0.11 S 电导上限只能给出约 106 W 输入功率，母线跌落到约 55.25 V。将上限提高到 0.14 S 后，31 V 母线恢复约 60 V，额定基线也重新验证。按平均化模型估算内环交越约 1.008 kHz/75.3° 裕度、外环约 10.41 Hz/57.5° 裕度；这些值不是开关模型的环路注入测量。

## 6. 三相逆变器

六个真实开关组成三相两电平桥。SPWM 参考为 `sin(θ)`、`sin(θ−2π/3)`、`sin(θ+2π/3)`，`θ=2π·Fout_Hz·t`；三个桥臂均有 1 µs 开通死区。`Fout_Hz` 是模型工作区参数，已在 30 Hz 和 60 Hz 的完整模型中分别验证；控制器的 RMS 时间常数与测量频率设置随输出频率同步。60 V 母线在线性 SPWM 下理论最大线电压约 36.74 V RMS，高于 32 V 目标。

## 7. 输出滤波器

每相 LC 的无载谐振约 1 kHz，处于 30/60 Hz 输出基波与 12.6 kHz 载波之间。每相电容串联 1 Ω 抑制谐振。额定负载线性估算自然频率约 954 Hz、`Q≈1.24`、787 Hz 附近峰值约 1.35 倍；实际谐波以开关仿真 FFT 为准。

## 8. 三相输出控制

三个相电压 RMS 反馈各自调整 SPWM 幅值，控制器 `Kp=0.030, Ki=0.80 s⁻¹`，调制幅值上限 0.95。输出电压参考在 0.18–0.23 s 建立。完整模型直接从三条线电压、三条负载电流测量 RMS、频率和相位，不从参考量推断通过。

## 9. Requirement 1：额定 60 Hz 三相输出

最终保留设计的 36 V/50 Hz 输入实测 {baseline['input_voltage_rms_V']:.4f} V、三条线电压 {vec(baseline['Uline_rms_V'])} V、频率 {vec(baseline['output_frequency_measured_Hz'])} Hz、线电流 {vec(baseline['Iline_rms_A'])} A；最大电压不平衡 {baseline['max_voltage_imbalance_percent']:.4f}%，相位差约 {vec(baseline['phase_separation_deg'], 3)}°。额定波形见[三相线电压](../results/three_phase_line_voltages.png)。结论：**{verdict(combined['requirement_1_pass'])}**。

## 10. Requirement 2：输入功率因数

同次完整仿真源侧 `Pin={baseline['input_power_W']:.3f} W`，输入电流 {baseline['input_current_rms_A']:.4f} A，总功率因数 {baseline['input_PF']:.5f}，50 Hz 基波位移因数 {baseline['input_displacement_factor']:.5f}，输入电流第 2–50 次谐波 THD {baseline['input_current_THD_percent']:.3f}%。总功率因数同时包含位移与畸变。结论：**{verdict(combined['requirement_2_pass'])}**。

## 11. Requirement 3：模型效率与功率平衡

源侧 `Pin={baseline['input_power_W']:.3f} W`，逆变器 DC 输入 `Pdc={baseline['inverter_dc_input_power_W']:.3f} W`，三相负载 `Pout={baseline['output_power_W']:.3f} W`，模型损耗 `Pin−Pout={baseline['input_power_W']-baseline['output_power_W']:.3f} W`，效率 {baseline['efficiency_percent']:.3f}%。结论：**{verdict(combined['requirement_3_pass'])}**。这里的效率只适用于已声明的 Simscape 导通、绕组与 ESR 损耗模型，不能作为硬件效率保证。

## 12. Requirement 4：三条线电压 THD

0.8–1.0 s 的 200 kHz 重采样 FFT 中，第 2–50 次谐波 THD 为 {vec(baseline['output_THD_2to50_percent'],3)}%；包含开关残余的宽带非基波 RMS 比为 {vec(baseline['output_broadband_residual_percent'],3)}%，最大 {max(baseline['output_broadband_residual_percent']):.3f}%，仍低于 2%。[输出频谱](../results/output_voltage_spectrum.png)。结论：**{verdict(combined['requirement_4_pass'])}**。

## 13. Requirement 5：30 Hz 输出

36 V/50 Hz 输入、原额定 9.237604307034 Ω 负载下，三条线电压 {vec(req5['Uline_rms_V'])} V，频率 {vec(req5['output_frequency_measured_Hz'])} Hz，三条线电流 {vec(req5['Iline_rms_A'])} A，相位差 {vec(req5['phase_separation_deg'],3)}°。输入 PF {req5['input_PF']:.5f}、母线平均 {req5['dc_bus_mean_V']:.4f} V、模型效率 {req5['efficiency_percent']:.3f}%、宽带残余最大 {max(req5['output_broadband_residual_percent']):.3f}%。波形见[相电压](../results/req5_three_phase_30hz.png)、[线电压](../results/req5_line_voltage_30hz.png)、[电流](../results/req5_current_30hz.png)、[母线](../results/req5_dc_bus.png)。结论：**{verdict(combined['requirement_5_pass'])}**。

## 14. Requirement 6：负载调整率

题面没有给出 SI 的计算公式；这里同时采用 `SI_span=(Umax−Umin)/32×100%` 与 `SI_dev=max|U−32|/32×100%`，每点 `U=(Uab+Ubc+Uca)/3`，两者均须不超过 0.3%。每相电阻由 MATLAB 计算 `R=32/(√3·I_target)`，通过 `SimulationInput` 覆盖真实电阻参数，各点均为完整开关仿真。

| 目标电流 A | 每相电阻 Ω | Uab/Ubc/Uca V | 平均线电压 V | 实测线电流 A | 频率 Hz | 母线 V | 输入 PF | 模型效率 % |
|---:|---:|---|---:|---:|---:|---:|---:|---:|
{chr(10).join(load_rows)}

`SI_span={req6['SI_span_percent']:.5f}%`，`SI_dev={req6['SI_deviation_percent']:.5f}%`，全扫描最大三相电压不平衡 {req6['max_voltage_imbalance_percent']:.4f}%。[调整率曲线](../results/req6_load_regulation_curve.png)、[实际电流](../results/req6_load_current_sweep.png)。{dynamic_note} 0.2 A 与 0.5 A 的 PF 分别为 {req6['PF_points'][0]:.5f} 和 {req6['PF_points'][1]:.5f}，低于额定 Req2 的 0.98 门槛；它们是轻载工程限制，Req6 原题只给出调整率门槛。结论：**{verdict(combined['requirement_6_pass'])}**。

## 15. Requirement 7：输入电压调整率

题面没有给出 SU 的计算公式；这里同时采用 `SU_span=(Umax−Umin)/32×100%` 与 `SU_dev=max|U−32|/32×100%`，两者均须不超过 0.3%。输入扫点真实改变物理 AC 源的幅值，负载保持额定电阻；60 V 母线参考保持不变。

| 目标输入 V | 实测输入 V | Uab/Ubc/Uca V | 平均线电压 V | 线电流 A | 频率 Hz | 母线 V | PFC 最小占空比 | 输入 PF | 输出宽带残余最大 % | 模型效率 % |
|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|
{chr(10).join(line_rows)}

`SU_span={req7['SU_span_percent']:.5f}%`，`SU_dev={req7['SU_deviation_percent']:.5f}%`。[输出电压曲线](../results/req7_line_regulation_curve.png)、[母线](../results/req7_dc_bus_vs_input.png)、[输入 PF](../results/req7_pf_vs_input.png)、[模型效率](../results/req7_efficiency_vs_input.png)、[31/41 V 输入波形](../results/req7_input_current_extremes.png)。41 V 高线 PFC 稳定检查：**{verdict(req7['high_line_PFC_stable'])}**；最小/最大占空比为 {req7['PFC_duty_min_points'][-1]:.4f}/{req7['PFC_duty_max_points'][-1]:.4f}，0.02 下限触及次数 {req7['PFC_duty_floor_count_points'][-1]}，0.95 上限触及次数 {req7['PFC_duty_ceiling_count_points'][-1]}，全部扫点的占空比与功率见[Req7 JSON](../results/acac_req7_line_regulation.json)。31 V 点模型效率 {req7['efficiency_points_percent'][0]:.3f}%，略低于 95%；这不是 Req7 的直接电压调整率门槛，但限制了“全输入范围均满足原 Req3 效率门槛”的声明。Req7 电压调整率结论：**{verdict(combined['requirement_7_pass'])}**；全输入范围 PF、THD 与母线的额外质量检查：**{verdict(combined['Req7_and_original_quality_metrics_pass'])}**。

## 16. 其他工程验证

保存模型的额定配置为 36 V 输入、30 Hz 输出、9.237604307034 Ω 每相负载、60 V 母线。输入/负载扫描通过 `Simulink.SimulationInput` 临时覆盖，不永久污染模型。基线 60 Hz 与 30 Hz、负载两端点、输入两端点均有完整 1.0 s 开关仿真，0.8–1.0 s 恰含 10 个输入周期及 6 个 30 Hz 输出周期。额定 60 Hz 三个逆变桥臂同时开通样本数均为零，母线平均 {baseline['dc_bus_mean_V']:.4f} V，稳态纹波峰峰值 {baseline['dc_bus_pp_V']:.3f} V。预充与启动的更完整记录见[前四项验证](acac_first_four_validation.md)。

## 17. 开发过程中的问题与修复

初版 31 V 点在 0.11 S 外环电导上限下仅有约 106 W 输入，母线跌落约 55.25 V、输出约 30.58 V；提高有依据的电导上限到 0.14 S 后重新运行，输出恢复约 32.01 V、母线约 60 V。控制脚本更新后需重新注册 Stateflow 的 `Fout_Hz` 参数数据，已在最终派生模型中保存并完成编译检查。一次 33 V 运行的辅助控制信号重采样出现 NaN，测量函数已增加有限性断言并重新仿真。另一次仿真因 `/tmp` 内存文件系统近满而无法创建 `tout`；将未被进程打开的旧 SDI 临时文件完整归档到工作磁盘后重测。早期负载星点接线及 PFC 独立级启动负载问题的修复见前四项报告。所有保留的验收数据均来自更新后的完整物理模型。

## 18. 模型局限

MOSFET 为理想开关加外部导通电阻；开关过渡能量、温度变化、磁芯损耗、完整寄生参数、硬件保护、传感器与驱动器误差未被充分建模。外环/内环相位裕度为平均化近似，不是实测开关系统环路裕度。轻载 PF 与 31 V 模型效率的退化已在对应扫描表中明示。输出宽带残余包含开关频率附近能量，常规 THD 则仅累计第 2–50 次谐波。

## 19. 最终结果总表

| Requirement | 指标 | 目标 | 实测 | 结果 |
|---|---|---|---|---|
| 1 | 三线电压；频率；电流 | 各 31.9–32.1 V；59.8–60.2 Hz；约 2 A | {vec(baseline['Uline_rms_V'],3)} V；{vec(baseline['output_frequency_measured_Hz'],3)} Hz；均值 {baseline['Iline_average_A']:.4f} A | {verdict(combined['requirement_1_pass'])} |
| 2 | 输入总 PF | ≥0.98 | {baseline['input_PF']:.5f} | {verdict(combined['requirement_2_pass'])} |
| 3 | 模型效率 | ≥95% | {baseline['efficiency_percent']:.3f}% | {verdict(combined['requirement_3_pass'])} |
| 4 | 三线电压 THD | 各 ≤2% | 宽带最大 {max(baseline['output_broadband_residual_percent']):.3f}% | {verdict(combined['requirement_4_pass'])} |
| 5 | 30 Hz 电压、频率、电流 | 各 31.9–32.1 V；29.8–30.2 Hz；约 2 A | {vec(req5['Uline_rms_V'],3)} V；{vec(req5['output_frequency_measured_Hz'],3)} Hz；均值 {req5['Iline_average_A']:.4f} A | {verdict(combined['requirement_5_pass'])} |
| 6 | 负载调整率 | SI_span 与 SI_dev 均 ≤0.3% | {req6['SI_span_percent']:.5f}% / {req6['SI_deviation_percent']:.5f}% | {verdict(combined['requirement_6_pass'])} |
| 7 | 输入调整率 | SU_span 与 SU_dev 均 ≤0.3% | {req7['SU_span_percent']:.5f}% / {req7['SU_deviation_percent']:.5f}% | {verdict(combined['requirement_7_pass'])} |

## 20. 结论

明确的 Requirement 1–7 各自原题门槛总判定：**{verdict(combined['requirements_1_to_7_passed'])}**。额外的“所有工况同时继承额定 PF 和效率门槛”工程判定：**{verdict(combined['all_requirements_simultaneously_satisfied'])}**，原因是轻载 PF 与 31 V 模型效率的实测限制。该判定基于保留设计的完整 R2024a Simscape Electrical 开关模型，以及真实的 30/60 Hz、0.2–2.0 A 和 31–41 V 扫描数据；所有调整率均由实测线电压计算。Requirement 8 was not numerically specified in the supplied problem statement and therefore was not assigned an artificial simulation pass/fail gate.

模型：[30 Hz 派生模型](../models/acac_30hz_r2024a.slx)；原始[前四项模型](../models/acac_single_to_three_phase_r2024a.slx)保持原样。原始 MAT、逐点 MAT 与 JSON 均保存在 `results/`；复现入口为 [run_acac_remaining_validation.m](../scripts/run_acac_remaining_validation.m)。
"""

(DOCS / "acac_final_design_report.md").write_text(report, encoding="utf-8")
root_report = report.replace("(../", "(").replace(
    "(acac_first_four_validation.md)", "(docs/acac_first_four_validation.md)"
)
(ROOT / "acac_final_design_report.md").write_text(root_report, encoding="utf-8")
print("WROTE", RESULTS / "acac_all_requirements_metrics.json")
print("WROTE", DOCS / "acac_final_design_report.md")
print("WROTE", ROOT / "acac_final_design_report.md")
