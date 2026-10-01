# MATLAB R2024a Compatibility

## Environment

- MATLAB: R2024a, 24.1.0.2537033
- Simulink: 24.1
- Simscape: 24.1
- Simscape Electrical: 24.1
- OS: EndeavourOS Linux 7.2.7-zen1-1-zen (niri/Wayland with XWayland)

## MCP

- MATLAB Agentic Toolkit: installed from official `matlab/matlab-agentic-toolkit` (commit `dad44c6`).
- Simulink Agentic Toolkit: installed from official `matlab/simulink-agentic-toolkit` (commit `2d73af4`); `satk_initialize` reports PASS.
- MATLAB MCP Server: official v0.14.0, installed at `/home/chidan/.matlab/agentic-toolkits/bin/matlab-mcp-server`.
- Codex MCP configuration: `/home/chidan/.codex/config.toml`, TOML parsed; `matlab` and prior `node_repl` entries retained. Session mode `auto`.
- Live MCP verification: `evaluate_matlab_code` returned R2024a; `model_edit`, `model_read`, `model_check`, and simulation calls completed.

## ee_lib

- Available: YES, confirmed by `which ee_lib` and `load_system`.
- Library path: `/home/chidan/Matlab/toolbox/physmod/elec/library/m/ee_lib.slx`.

## Block mapping

`\n` in a path below denotes an actual newline in the R2024a block name. Every YES means MATLAB `find_system` or `which` found the path and `get_param` returned parameters and port handles. It does not claim that every listed block was simulated. Full machine-readable results: [R2024a_block_metadata.json](/home/chidan/src/agent-skills/R2024a_block_metadata.json).

| Component | R2024a block path | Parameters | Ports | Verified |
|---|---|---|---|---|
| Voltage Source | `ee_lib/Sources/Voltage Source` | `dc_voltage`, `ac_voltage`, `ac_frequency` | LConn1, RConn1 | YES |
| DC Voltage Source | `fl_lib/Electrical/Electrical Sources/DC Voltage Source` | `v0` | LConn1, RConn1 | YES |
| Resistor | `fl_lib/Electrical/Electrical Elements/Resistor` | `R` | LConn1, RConn1 | YES |
| Inductor | `fl_lib/Electrical/Electrical Elements/Inductor` | `l`, `r`, `g` | LConn1, RConn1 | YES |
| Capacitor | `fl_lib/Electrical/Electrical Elements/Capacitor` | `c`, `r`, `g` | LConn1, RConn1 | YES |
| Diode | `fl_lib/Electrical/Electrical Elements/Diode` | `Vf`, `Ron`, `Goff` | LConn1, RConn1 | YES |
| MOSFET | `ee_lib/Semiconductors &\nConverters/N-Channel MOSFET` | `paramTerminal`, `parameterization`, `Beta`, `Rds`, `Vth` | LConn1, RConn1, RConn2 | YES |
| Electrical Reference | `fl_lib/Electrical/Electrical Elements/Electrical Reference` | None | LConn1 | YES |
| Voltage Sensor | `fl_lib/Electrical/Electrical Sensors/Voltage Sensor` | None | LConn1, RConn1, RConn2 | YES |
| Current Sensor | `fl_lib/Electrical/Electrical Sensors/Current Sensor` | None | LConn1, RConn1, RConn2 | YES |
| Solver Configuration | `nesl_utility/Solver\nConfiguration` | `UseLocalSolver`, `LocalSolverChoice`, `ResidualTolerance` | RConn1 | YES |
| PS-Simulink Converter | `nesl_utility/PS-Simulink\nConverter` | `Unit`, `VectorFormat` | Outport1, LConn1 | YES |
| Simulink-PS Converter | `nesl_utility/Simulink-PS\nConverter` | `Unit`, `FilteringAndDerivatives`, `InputFilterTimeConstant` | Inport1, RConn1 | YES |

For the simulated electrical model, `model_read` additionally identified: source and resistor `LConn1=p`, `RConn1=n`; sensor `LConn1=p`, `RConn1=V` (physical signal), `RConn2=n`; reference `LConn1=V`; converter `LConn1` (physical signal) and `Outport1` (Simulink signal). Other port domains, especially the MOSFET, remain untested at model level; use a fresh `model_read` before wiring them. The Solver Configuration `RConn1` is required once per connected physical network.

## R2025b differences

- The `OrangeXxin/power-electronics-agent` Skill says R2024b and earlier use `elec_lib`. This local R2024a installation demonstrably contains `ee_lib`; its statement must not be used as a version rule on this machine.
- Several actual R2024a paths contain newline characters in block names (for example `nesl_utility/Solver\nConfiguration`). Plain-space paths printed in R2025b-oriented examples have not been verified as exact R2024a paths.
- No R2025b MATLAB installation was available for direct comparison. Parameter and port differences beyond the queried R2024a facts are unknown.

## Skills installed

- `simulink-power-electronics` → `npuzsy/simulink-power-electronics` (`74d2b96`).
- `power-electronics-agent` → `OrangeXxin/power-electronics-agent/skill` (`20219a4`).
- `simulink-interactions`, `simulink-debug-commandline`, `simulink-profiler-analyzer`, `simulink-solver-profiler-analyzer` → `simulink/skills` (`e91fdd1`).
- 19 official MathWorks skills registered by the installer; the six requested community links remain intact.

## Validation

- MATLAB callable: R2024a returned through both `matlab -batch` and MCP.
- SATK initialization: PASS (9 entry points and MATLAB connector).
- Basic Simulink model: [codex_mcp_smoke.slx](/home/chidan/src/agent-skills/validation/codex_mcp_smoke.slx), created with MCP `model_edit`, saved, `model_check` healthy, simulated; `Constant(2) -> Gain(3)` produced `6`.
- Simscape Electrical model: [codex_electrical_smoke.slx](/home/chidan/src/agent-skills/validation/codex_electrical_smoke.slx), created with MCP `model_edit`, saved, `model_check` healthy, compiled and simulated. DC source `10 V`, resistor `10 Ohm`, sensor measured `10 V`.
- Automatic MCP session: after stopping the test desktop, Codex MCP launched fresh MATLAB sessions. The saved Simulink and Simscape Electrical models resimulated to `6` and `10 V` respectively. Detailed MCP results are preserved in [validation/verification.json](/home/chidan/src/agent-skills/validation/verification.json).

## Known incompatibilities

- The R2024a licensing code crashed with newer system GnuTLS. The user launcher and MCP config use user-level compatible GnuTLS/Nettle libraries.
- Compatible GnuTLS needs `libleancrypto.so.1`; the Arch Linux 1.2.0-1 package was signature-verified and the library extracted to the user compatibility directory. It must be preloaded because that historical binary is marked `NOOPEN`.
- The niri/XWayland desktop needs `_JAVA_AWT_WM_NONREPARENTING=1` to render MATLAB contents.

## Ready for Buck simulation

YES — the minimal Simscape Electrical circuit and measured output passed. No Buck, Boost, PFC, or inverter model was run in this installation task.
