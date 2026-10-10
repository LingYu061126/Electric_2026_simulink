# Dual Single-phase Parallel Inverter System

## Requirements

The saved model uses two independently powered full-bridge inverters. The fixed physical topology contains an RL load branch through S1 and a grid/transformer branch through S2. Test cases change switch commands, inverter enables, and digital references; they do not rewire the model.

The required operating cases are: one inverter supplying 24 Vrms / 50 Hz / 2 Arms; two inverters supplying a 4 Arms load; and two independently controlled inverters injecting digitally allocated current through a 24:220 V transformer into a 220 Vrms / 50 Hz source. The grid current requirement is measured at the transformer low-voltage primary sensor `TP_Io`.

## DC Source Selection

Each inverter has its own 48 V DC source and DC-side current/voltage measurements. The two sources are not connected to a shared DC bus. The 48 V value is a design assumption; it is not specified by the assignment. A 24 Vrms output has a 33.94 V sinusoidal peak, leaving modulation headroom at 48 V.

Basic-3 counts an explicit auxiliary load in Source 1 power. Its nominal value is an assumed 1.0 W, with 0, 0.5, 1, and 2 W sensitivity cases. Device transition losses are not represented by the current switching-device model and are called out in the validation report.

## Inverter 1

### Topology

Inverter 1 is a physical four-switch single-phase H bridge. Its own MOSFETs, gate signal paths, dead-time logic, LC output filter, voltage/current sensors, and controller are contained in the model. The gate sequence retains the verified 1 µs both-off dead time on each bridge leg.

### Filter

The power stage uses its own two 1 mH filter inductors, each with 0.05 Ω series resistance, a 20 µF output capacitor, and a 10 Ω damping resistor. `TP_Uo` measures the filtered A-B output; `TP_inv1_filter_current` measures the inverter-side filter current.

### Voltage Controller

In load mode, Controller 1 uses measured output voltage and its own quasi-PR voltage-control path with feedforward. Its unipolar SPWM commands pass through the existing complementary comparator and per-leg dead-time logic. The 24 Vrms, 50 Hz reference is soft-started.

### Grid Current Controller and PLL

In grid mode, a separate controller instance uses Controller 1's own `Io1` feedback. Its SOGI generates in-phase/quadrature voltage signals, and a separate discrete PLL estimates `theta`, frequency, and lock state. Current injection remains disabled until measured grid magnitude, frequency, and normalized phase error satisfy the lock window.

The nominal current reference is `sqrt(2)*Iref1_rms*sin(theta1)`, multiplied by the grid-mode, PLL-lock, and soft-start signals. A discrete quasi-PR current controller produces a voltage correction, adds the measured low-voltage grid voltage as feedforward, divides by this inverter's measured DC voltage, and limits modulation to ±0.95. The correction limit is ±16 V.

## Inverter 2

### Topology and Filter

Inverter 2 has its own physical full bridge, 48 V DC source, gate paths, dead time, LC output filter, sensors, and controller. Its filter and switch topology match Inverter 1. No DC source or power-stage state is shared.

### Voltage Controller

Controller 2 has a separately instantiated voltage-control network. It measures its own output voltage and current and maintains its own PR/PWM states. Its voltage-mode command is not copied from Controller 1.

### Grid Current Controller and PLL

Controller 2 has its own SOGI filters, PLL, current-reference path, current feedback, discrete PR states, modulation limiter, and sample delays. Its current reference is derived from `Iref2_rms` and `theta2`. It does not reuse Controller 1's PLL, PR state, or modulation output.

## Independence of Controllers

`Control` and `Control2` are separate Simulink subsystems. Each contains a distinct voltage controller and a distinct grid-current controller with its own discrete transfer-function states. Only digital commands (`Grid_Mode`, total-current reference, and ratio command) and the sensed common low-voltage grid voltage are distributed to both controllers. Current feedback and current-loop state remain local to each inverter.

## S1/S2 Test Architecture

The model uses physical Simscape switch blocks:

| Mode | S1 load breaker | S2 grid breaker | Inverter enables | Control mode |
| --- | ---: | ---: | --- | --- |
| Basic single inverter | closed | open | Inv1 on, Inv2 off | voltage |
| Parallel load | closed | open | Inv1 and Inv2 on | voltage plus local droop |
| Grid current | open | closed | Inv1 and Inv2 on | independent PLL/current control |

Grid current command is not adjusted by changing the load or reconfiguring the wiring.

## Transformer

The grid branch contains an ideal transformer with explicit winding resistance and leakage-inductance elements on both sides. The R2024a transformer parameter is set to the verified 24/220 convention, so the 24 V primary is transformed to the 220 V secondary. The final result report records primary and secondary voltage, current, and real power separately.

## Load

The nominal load is 12 Ω for 24 V / 2 A operation. The 4 A parallel-load case uses 6 Ω. No-load regulation uses the physical load-disconnect switch to create a true open circuit.

## Grid Model

The Simscape AC source is configured for 220 Vrms at 50 Hz (`220*sqrt(2)` peak). The low-voltage transformer primary is sensed directly, and the 220 V side has separate voltage and current sensors. Primary current `TP_Io` defines Bonus-2 and Bonus-3 total current; the secondary current is an additional grid-side measurement.

## Parallel Load Sharing

In parallel-load mode, each inverter retains an independent local voltage controller and uses its own output-current feedback in the virtual-resistance droop path. The tested droop command is 0.02 Ω per inverter. Circulating current is reported as `(Io1-Io2)/2`.

## Grid Current Control

The total-current command and ratio command are digital signals. The reference allocator implements

```text
Iref1 = Io_total_ref*K_set/(1+K_set)
Iref2 = Io_total_ref/(1+K_set)
```

Each allocated RMS current is then processed by its own PLL and current PR loop. Bonus-2 uses `K_set=1` for equal sharing. Bonus-3 measures `K_measured=Io1_rms/Io2_rms` from the separate inverter current sensors.

The PLL lock window checks 49.5–50.5 Hz, 20–48 V peak grid magnitude, and normalized phase-detector magnitude below 0.05. The two PLLs are separately logged. In the first 2 A switching check both lock flags reached 1.0 over the steady measurement window.

## Protection

Each inverter has a separate protection supervisor using its local measured DC voltage, local output current, and allocated current reference. The RMS reference is saturated to 0–2 A. If `Vdc <= 40 V`, the supervisor removes gate permit and opens that inverter's output isolator after a 10 µs sampled delay. If the absolute instantaneous branch current exceeds 4 A, a sampled latch records the trip and removes the same permit until the next simulation starts. The permit signal also gates all four physical-switch commands. The normal 2 A grid smoke run kept both permits active with no trip; fault injection measured 32 V on the undervoltage source, zero gate permit, and no current, and measured a 4.019 A branch peak before the overcurrent latch opened the output. Out-of-range grid voltage and frequency tests left both PLL lock flags at zero and both instantaneous current references at zero.

## Loss Model

The stage includes nonzero MOSFET conduction resistance, filter winding resistance, capacitor damping, transformer winding resistance, and transformer leakage inductance. The 1 W auxiliary load used for Basic-3 is an explicit assumption and receives a 0/0.5/1/2 W sensitivity analysis. Switching-transition, diode reverse-recovery, thermal, and gate-driver losses are not modeled.

## Solver

The model is compiled and simulated as a physical Simscape Electrical switching network in MATLAB/Simulink R2024a. The model uses the variable-step `ode23t` solver, maximum step 5 µs, relative tolerance 1e-4, and automatic absolute tolerance. The control and protection delays are discrete; the controller sample is 100 µs and the supervisor state sample is 10 µs.

## Limitations

The 48 V bus and 1 W auxiliary load are design assumptions. The ideal transformer is supplemented by lumped winding resistance and leakage inductance, but it has no saturation or thermal model. The simulated grid source is stiff. Semiconductor switching-transition losses, reverse recovery, sensor noise, controller quantization beyond the discrete controller sample, and physical protection hardware are not represented. Simulation passes apply only to the measured operating cases and model assumptions.
