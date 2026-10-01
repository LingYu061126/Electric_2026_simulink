# R2024a MOSFET port probe

Probe performed in the live MATLAB R2024a session with `model_edit` and `model_read` on `buck_mosfet_probe`.

| R2024a block | Gate | Drain | Source |
| --- | --- | --- | --- |
| `ee_lib/Semiconductors &\nConverters/N-Channel MOSFET` | `G = LConn1`, electrical conserving | `D = RConn1`, electrical conserving | `S = RConn2`, electrical conserving |
| `ee_lib/Semiconductors &\nConverters/MOSFET\n(Ideal,\nSwitching)` | `G = LConn1`, physical signal input | `D = RConn1`, electrical conserving | `S = RConn2`, electrical conserving |

Here `\n` represents an actual newline in the library block path. The first block cannot accept a Simulink-PS Converter at its gate because its gate is electrical. The second block is the R2024a physical-signal-controlled MOSFET selected for this Buck topology.

The live probe model connected `Gate_Pulse.y1 -> Gate_PS.u1` and `Gate_PS.RConn1 <-> Ideal_MOSFET.LConn1`; `model_edit` returned `status: ok`. A subsequent `model_read` showed `G=blk_3.RConn1`, `D=?`, and `S=?`, confirming the gate connection and the actual port mapping. The incomplete probe was intentionally not claimed to compile. Full circuit compilation and simulation belong to `models/buck_r2024a.slx`.

The ideal switching block reports `Rds=0.01 Ohm`, `Goff=1e-6 1/Ohm`, `Vth=2 V`, and `port_option=ee.enum.controlport.ps` from live `get_param` queries. These are the queried R2024a parameter names and defaults, not guessed settings.
