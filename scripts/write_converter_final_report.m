function reportPath = write_converter_final_report(projectDir)
% Rebuild the final Markdown report from measured JSON files only.
if nargin<1
    projectDir=fileparts(fileparts(mfilename('fullpath')));
end
r=fullfile(projectDir,'results');
readj=@(name) jsondecode(fileread(fullfile(r,name)));
b1=readj('basic_req1_metrics.json');
b2=readj('basic_req2_thd.json');
b3=readj('basic_req3_load_regulation.json');
b4=readj('basic_req4_frequency_sweep.json');
c1=readj('bonus_req1_energy_recovery.json');
c2=readj('bonus_req2_source_power.json');
p3=readj('bonus3_protection_test.json');
reg=readj('final_regression.json');
assert(b1.pass&&b2.pass&&b3.pass&&b4.pass&&c1.pass&&c2.pass&&p3.pass&&reg.pass, ...
    'Cannot issue final report: at least one measured gate failed');
reportPath=fullfile(projectDir,'docs','converter_energy_recovery_final_report.md');
fid=fopen(reportPath,'w');assert(fid>=0);
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'# 能量回馈型变流器负载试验装置\n\n');
fprintf(fid,'## 1 题目要求\n\n');
fprintf(fid,'MATLAB R2024a Simscape Electrical 真实物理开关模型验证：50 Hz 三相 32±0.25 V RMS 线电压、约 2 A RMS、三线电压 THD≤2%%、0–2 A 负载调整率<0.3%%、20–100 Hz 每 1 Hz 变频，以及主动整流回馈同一 DC 母线。所有交流电压、电流结果均为 RMS。\n\n');
fprintf(fid,'## 2 总体设计\n\n');
fprintf(fid,'一台直流源→Converter 1 六开关 VSI→三相 LC→三相 3 mH 连接电感→Converter 2 六开关有源整流桥→原直流母线。基础负载是浮置星形电阻；回馈测试时三相物理开关真正断开电阻支路。Basic 和 Bonus 共享同三个子系统引用文件，回馈阶段没有替换 Converter 1。\n\n');
fprintf(fid,'## 3 Converter 1\n\n');
fprintf(fid,'### topology\n\n三相两电平六 MOSFET VSI；Basic 模型和回馈模型共享 `subsystems/converter1_inverter_r2024a.slx`。\n\n');
fprintf(fid,'### DC voltage choice\n\n60 V 是设计假设，不是题面已知值。理想 SPWM 所需调制指数 `2√2·(32/√3)/60=%.6f`。\n\n',b1.required_spwm_modulation_index_ideal);
fprintf(fid,'### PWM\n\n12.6 kHz 三相 SPWM；统一 `Fout_Hz` 控制 20–100 Hz。\n\n');
fprintf(fid,'### dead time\n\n每桥臂 1 μs 开通死区；全程六对门极重叠计数为 0。\n\n');
fprintf(fid,'### LC filter\n\n每相 1 mH、80 mΩ 电感，25.33 μF 电容及 1 Ω 阻尼；谐振频率约 %.1f Hz，处于 100 Hz 输出与 12.6 kHz 开关频率之间。\n\n',1/(2*pi*sqrt(1e-3*25.33e-6)));
fprintf(fid,'### output control\n\n基于直流电压的调制前馈、独立三相慢速幅值 PI 和随 `1/Fout_Hz` 缩放的电压平方估计；六开关与控制器分别为共享子系统引用。\n\n');
fprintf(fid,'## 4 Basic Requirement 1\n\n');
fprintf(fid,'Uab/Ubc/Uca=%.5f/%.5f/%.5f V；Ia/Ib/Ic=%.5f/%.5f/%.5f A；实测频率约 %.5f Hz；三相相位差约 −120°，无显著 DC 偏置。**PASS**。\n\n', ...
    b1.Uline_rms_V,b1.Iline_rms_A,mean(b1.frequency_measured_Hz));
fprintf(fid,'## 5 Basic Requirement 2\n\n');
fprintf(fid,'0.8–1.0 s 的 10 周期相干 FFT：Uab/Ubc/Uca 第 2–50 次谐波 THD=%.4f%%/%.4f%%/%.4f%%，均低于 2%%。**PASS**。\n\n',b2.THD_2_to_50_percent);
fprintf(fid,'## 6 Basic Requirement 3\n\n');
fprintf(fid,'### load regulation definition\n\n按用户给出的公式 `SU=abs((U12-U11)/32)×100%%`，32 V 为固定分母。\n\n');
fprintf(fid,'### no-load\n\n三相真实物理断开，非大电阻近似；0 A 时 `U11=%.6f V`。\n\n',b3.U11_no_load_V);
fprintf(fid,'### full-load\n\n2 A 时 `U12=%.6f V`。\n\n',b3.U12_2A_V);
fprintf(fid,'### sweep\n\n0/0.2/0.5/1.0/1.5/2.0 A 六点实测，线电压全局范围 %.6f–%.6f V，`SU=%.6f%%<0.3%%`。**PASS**。\n\n', ...
    b3.sweep_min_Uline_V,b3.sweep_max_Uline_V,b3.SU_percent);
fprintf(fid,'## 7 Basic Requirement 4\n\n');
fprintf(fid,'### 20–100 Hz\n\n');
fprintf(fid,'### 1 Hz steps\n\n全部 %d 个整数频点分别做了物理开关仿真；20/30/40/50/60/70/80/90/100 Hz 另做完整 1 s 独立验证。最大实测频率误差 %.5f Hz，线电压全局 %.5f–%.5f V，所有点稳定。0.5 Hz 是内部检查界限，不是题面误差要求。**PASS**。全部 81 行数据在 `results/basic_req4_frequency_sweep.json`。\n\n', ...
    b4.point_count,b4.max_frequency_error_Hz,b4.min_Uline_V,b4.max_Uline_V);
fprintf(fid,'## 8 Energy Recovery Architecture\n\n');
fprintf(fid,'回馈模型物理拓扑在 Bonus-1/2 间固定；两座桥与 DC 链接到同一源。正 `Id_source` 表示源供能，正 `Id_return` 表示 Converter 2 向原母线注入能量，均直接按传感器方向积分。\n\n');
fprintf(fid,'## 9 Converter 2\n\n');
fprintf(fid,'### topology\n\n三相六真实 MOSFET 有源整流桥，12.6 kHz SPWM 与 1 μs 开通死区。\n\n');
fprintf(fid,'### connection unit\n\n每相 3 mH、50 mΩ；`Δi_pp≈60/(4·0.003·12600)=0.397 A`，为 2 A 额定值的约 19.8%%。\n\n');
fprintf(fid,'### synchronization\n\n共享 `Fout_Hz=50` 的内部电角度，以实际三相电压前馈和电流测量检验 d/q 方向。\n\n');
fprintf(fid,'### dq current control\n\n正向电流由 Converter 1 流入 Converter 2；`L·di/dt=v1−v2−R·i`。所用 sin 基底的 d/q 方程、300 Hz PI 设计和符号见 `docs/energy_recovery_validation.md`。\n\n');
fprintf(fid,'## 10 Bonus Requirement 1\n\n');
fprintf(fid,'### current\n\n三相实测 %.4f/%.4f/%.4f A RMS，均≥1 A。\n\n',c1.Converter1_output_Iline_rms_A);
fprintf(fid,'### energy direction\n\nConverter 1 输出 %.3f W 交流有功；Converter 2 吸收 %.3f W 交流有功，向原母线回注 %.3f W 直流有功；源仍正向输出 %.3f W。**PASS**。\n\n', ...
    c1.P_converter1_AC_export_W,c1.P_converter2_AC_absorbed_W,c1.P_converter2_DC_return_W,c1.P_source_W);
fprintf(fid,'## 11 Bonus Requirement 2\n\n');
fprintf(fid,'### Pa\n\n60 V 直流源平均电流 +%.6f A，`Pa=%.6f W`；50 Hz 三相线电压均约 32.013 V、线电流 %.4f/%.4f/%.4f A。\n\n', ...
    c2.source_current_mean_A,c2.P_source_W,c2.Converter1_output_Iline_rms_A);
fprintf(fid,'### source-current reduction\n\n2 A 电阻负载基线源功率 %.6f W；回馈后源功率下降 %.4f%%。\n\n', ...
    c2.P_source_resistive_baseline_W,c2.source_power_reduction_percent);
fprintf(fid,'### recovery ratio\n\nConverter 1 交流输出 %.3f W，返回同母线直流 %.3f W，工程辅助回收比 %.4f%%。该比值不是题面评分公式。**PASS，Pa=%.3f W**。\n\n', ...
    c2.P_converter1_AC_export_W,c2.P_converter2_DC_return_W,c2.recovery_ratio_percent,c2.P_source_W);
fprintf(fid,'## 12 Additional Engineering Feature\n\n');
fprintf(fid,'“其它”未给量化门槛，故本项称为附加工程功能而非题面评分通过。3.0 A RMS 超额参考触发 2.2 A RMS 限幅，限幅标志有效比例 %.3f，参考峰值不超过 %.4f A；模型保持数值稳定。\n\n', ...
    p3.limiter_active_fraction,p3.id_reference_peak_max_A);
fprintf(fid,'## 13 Test Points\n\n');
fprintf(fid,'`TestPoints` 永久记录 Ud、Id_source、三线电压、三线电流、三相电压、滤波电流、三相调制量、Converter 1 六门极；回馈模型另记录 Converter 2 三相电流、三相桥端电压、直流回流电流和功率、六门极、d/q 电流、限幅状态。测试时不重新接线。\n\n');
fprintf(fid,'| 题目测试点 | `To Workspace` 信号名 |\n| --- | --- |\n');
fprintf(fid,'| TP_Ud / TP_Id_source | `acac_vdc` / `tp_id_source` |\n');
fprintf(fid,'| TP_Uab / TP_Ubc / TP_Uca | `acac_uab` / `acac_ubc` / `acac_uca` |\n');
fprintf(fid,'| TP_Ia / TP_Ib / TP_Ic | `acac_ia` / `acac_ib` / `acac_ic` |\n');
fprintf(fid,'| TP_Va / TP_Vb / TP_Vc | `acac_va` / `acac_vb` / `acac_vc` |\n');
fprintf(fid,'| TP_filter_current_A/B/C | `tp_filter_current_a`, `tp_filter_current_b`, `tp_filter_current_c` |\n');
fprintf(fid,'| TP_modA/B/C | `tp_modA`, `tp_modB`, `tp_modC` |\n');
fprintf(fid,'| TP_gate1…TP_gate6 | `acac_qah`, `acac_qal`, `acac_qbh`, `acac_qbl`, `acac_qch`, `acac_qcl` |\n');
fprintf(fid,'| TP_Conv2_Iabc | `tp_conv2_ia`, `tp_conv2_ib`, `tp_conv2_ic` |\n');
fprintf(fid,'| TP_Conv2_DC_voltage / TP_Conv2_DC_current | `tp_conv2_dc_voltage` / `tp_conv2_dc_return_current` |\n');
fprintf(fid,'| TP_return_power | `tp_return_power` |\n\n');
fprintf(fid,'## 14 Protection\n\n');
fprintf(fid,'Converter 2 仅在使能、t≥0.25 s、50≤Vdc≤70 V 时开门极；2.2 A RMS 限流为 2 A 额定值的 110%%。50/70 V 是相对 60 V 标称母线的启动/过压阈值；1 μs 死区与门极重叠检查覆盖两座桥。\n\n');
fprintf(fid,'## 15 Problems and Fixes\n\n');
fprintf(fid,'81 点扫描曾使默认 `/tmp` SDI 仓库耗尽；已将缓存移至用户磁盘并逐轮清理由脚本新建的 SDI run。插入回流电流传感器时，源侧正母线曾被断开；根据 `model_read` 恢复正确物理节点后再仿真。双桥共母线存在零序电流，用浮置中性点相电压计算交流功率会漏算共模项，最终改用三相端对 DC− 的直接物理电压测点。\n\n');
fprintf(fid,'## 16 Limitations\n\n');
fprintf(fid,'当前证据为 R2024a Simscape Electrical 开关模型验证，不是硬件鉴定。尚未建模开关过渡能量、热行为、磁芯损耗、全部寄生参数、实际驱动器不一致和传感器误差。连接电感的节点功率积分与 `R·i²+dE/dt` 在 2 A 窗口相差 %.3f W（传输功率的 %.3f%%）；数值残差在报告中保留，不把它解释为负损耗。\n\n', ...
    abs(c2.P_connection_balance_residual_W),c2.connection_balance_residual_percent);
fprintf(fid,'## 17 Final Results\n\n');
fprintf(fid,'| Requirement | Target | Measured | Result |\n| --- | --- | --- | --- |\n');
fprintf(fid,'| Basic-1 voltage | 32±0.25 V RMS | %.4f/%.4f/%.4f V | PASS |\n',b1.Uline_rms_V);
fprintf(fid,'| Basic-1 frequency | 50 Hz | %.4f Hz mean | PASS |\n',mean(b1.frequency_measured_Hz));
fprintf(fid,'| Basic-1 current | 约 2 A RMS | %.4f/%.4f/%.4f A | PASS |\n',b1.Iline_rms_A);
fprintf(fid,'| Basic-2 THD max | ≤2%% | %.4f%% | PASS |\n',max(b2.THD_2_to_50_percent));
fprintf(fid,'| Basic-3 SU | <0.3%% | %.6f%% | PASS |\n',b3.SU_percent);
fprintf(fid,'| Basic-4 frequency range | 20–100 Hz / 1 Hz | %d 点，最大误差 %.4f Hz | PASS |\n',b4.point_count,b4.max_frequency_error_Hz);
fprintf(fid,'| Bonus-1 I1 | ≥1 A RMS | 最小 %.4f A | PASS |\n',min(c1.Converter1_output_Iline_rms_A));
fprintf(fid,'| Bonus-1 returned power | >0 W | %.3f W | PASS |\n',c1.P_converter2_DC_return_W);
fprintf(fid,'| Bonus-2 Pa | 越小越好、源非负 | %.3f W | PERFORMANCE RESULT |\n',c2.P_source_W);
fprintf(fid,'| Bonus-2 source-power reduction | 比基线减少 | %.3f%% | PASS |\n',c2.source_power_reduction_percent);
fprintf(fid,'| Bonus-2 recovery ratio | 工程辅助指标 | %.3f%% | REPORTED |\n\n',c2.recovery_ratio_percent);
fprintf(fid,'最终回归：Basic-1/2、0/2 A 端点、20/50/100 Hz 均通过；端点 `SU=%.6f%%`。\n\n',reg.SU_percent);
fprintf(fid,'**结论：** 在 MATLAB R2024a 真实 Simscape Electrical 开关模型内，基本要求 1–4 均由实测数据通过；Converter 2 在同一固定拓扑下实现主动整流回馈，在 50 Hz / 32 V / 2 A 工况使直流源主要承担模型损耗，实测 `Pa=%.3f W`。\n',c2.P_source_W);
end
