# CLAUDE.md - φⁿ Neural Architecture FPGA

## Project Overview

This repository implements a **neuromorphic FPGA processor** based on the φⁿ (phi-n) golden ratio frequency architecture. The system models biological neural oscillations using Hopf bifurcation dynamics, theta-gated Hebbian learning, and closed-loop thalamocortical circuits.

### Core Concept
The processor implements 16 Hopf oscillators at golden-ratio-spaced frequencies (φⁿ where n = -0.5 to 3.5), creating a biologically-realistic neural timing hierarchy from theta (~6 Hz) through gamma (~40 Hz).

## Quick Start

```bash
# Install Icarus Verilog (macOS)
brew install icarus-verilog

# Run all tests
./scripts/run_sim.sh all

# Or use Makefile
make iverilog-all

# View waveforms (requires GTKWave)
make wave-full
```

## Directory Structure

```
fpga/
├── src/                      # RTL source modules (9 modules, ~1,238 lines)
│   ├── phi_n_neural_processor.v   # Top-level integration
│   ├── hopf_oscillator.v          # Core oscillator primitive
│   ├── thalamus.v                 # Sensory relay with theta gating
│   ├── cortical_column.v          # 5-layer column (L2/3, L4, L5a, L5b, L6)
│   ├── ca3_phase_memory.v         # Hebbian associative memory
│   ├── config_controller.v        # 5 consciousness states
│   ├── clock_enable_generator.v   # 4 kHz update, FAST_SIM support
│   ├── pink_noise_generator.v     # 1/f noise (Voss-McCartney)
│   └── output_mixer.v             # DAC output mixing
├── tb/                       # Testbenches (11 files, ~4,114 lines)
├── sim/                      # Simulation outputs (.vcd, .vvp)
├── scripts/                  # Build & analysis scripts
│   ├── run_sim.sh                 # Quick simulation runner
│   ├── plot_learning.py           # Visualize learning dynamics
│   ├── plot_state_transitions.py  # State transition plots
│   └── analyze_phase_coupling.py  # PAC analysis
├── docs/                     # Documentation
│   ├── FPGA_SPECIFICATION_V7.md   # Full specification
│   └── V7_COMPREHENSIVE_SUMMARY.md
└── Makefile                  # Build system
```

## Architecture

### Signal Flow (Closed-Loop v7.0)

```
sensory_input (ONLY external data input)
    │
    ▼
THALAMUS ──────────────────────────────────────┐
    │ theta_gated_output                       │
    ▼                                          │ L6 alpha feedback
CORTICAL COLUMNS (Sensory → Assoc → Motor)     │
    │                                          │
    │ cortical_pattern[5:0] (sign-bit derived) │
    ▼                                          │
CA3 PHASE MEMORY ◄─────────────────────────────┘
    │ phase_pattern[5:0]
    ▼
PHASE COUPLING ──► back to cortical L2/3 & L6
```

### φⁿ Frequency Hierarchy

| Layer | φⁿ Power | Frequency | Neural Correlate |
|-------|----------|-----------|------------------|
| Theta | φ^-0.5 | 5.89 Hz | Hippocampal timing |
| L6 | φ^0.5 | 9.53 Hz | Alpha, thalamic feedback |
| L5a | φ^1.5 | 15.42 Hz | Low beta, motor output |
| L5b | φ^2.5 | 24.94 Hz | High beta, feedback |
| L4 | φ^3.0 | 31.73 Hz | Consciousness gate |
| L2/3 | φ^3.5 | 40.36 Hz | Gamma, feedforward |

### Five Consciousness States

| State | Code | Signature |
|-------|------|-----------|
| NORMAL | 3'b000 | Balanced baseline |
| ANESTHESIA | 3'b001 | Collapsed dynamics (52× fewer transitions) |
| PSYCHEDELIC | 3'b010 | Maximum entropy (8× more patterns) |
| FLOW | 3'b011 | Enhanced motor output |
| MEDITATION | 3'b100 | Highest theta-gamma PLV (2.7×) |

## Key Parameters

```verilog
// Fixed-point format
parameter WIDTH = 18;        // Total bits
parameter FRAC = 14;         // Fractional bits (Q4.14)

// Phase coupling (validated stable)
localparam K_PHASE = 18'sd4096;  // 0.25 in Q4.14

// Theta thresholds for CA3
localparam LEARN_THRESH = +0.75;   // theta_x > 0.75 → learn
localparam RECALL_THRESH = -0.75;  // theta_x < -0.75 → recall

// CA3 learning
parameter LEARN_RATE = 2;
parameter DECAY_RATE = 1;
parameter WEIGHT_MAX = 100;
```

## Building & Testing

### Makefile Targets

```bash
# Icarus Verilog simulation
make iverilog-hopf    # Hopf oscillator unit test
make iverilog-fast    # Fast CA3/theta test
make iverilog-full    # Full system test
make iverilog-all     # All tests

# Vivado (requires Xilinx tools)
make vivado-sim       # Behavioral simulation
make vivado-synth     # Synthesis

# Waveform viewing
make wave-hopf        # View Hopf waveform
make wave-fast        # View fast test waveform
make wave-full        # View full system waveform

# Cleanup
make clean            # Remove generated files
```

### run_sim.sh Script

```bash
./scripts/run_sim.sh hopf   # Run Hopf oscillator test
./scripts/run_sim.sh fast   # Run fast CA3/theta test
./scripts/run_sim.sh full   # Run full system test
./scripts/run_sim.sh all    # Run all tests (default)
```

### FAST_SIM Mode

Set `FAST_SIM=1` for ~3000× faster simulation:
- Production: ÷31250 clock divider
- FAST_SIM: ÷10 clock divider

```verilog
phi_n_neural_processor #(.FAST_SIM(1)) dut (...);
```

## Testbench Summary

| Testbench | Purpose | Tests |
|-----------|---------|-------|
| tb_hopf_oscillator.v | Unit test oscillator | Amplitude stability, frequency |
| tb_ca3_learning.v | Hebbian weight updates | Learn/recall/decay |
| tb_v55_fast.v | Fast CA3/theta | 6 integration tests |
| tb_full_system_fast.v | Full integration (fast) | 8 tests |
| tb_full_system.v | Production timing | 8 tests |
| tb_learning_fast.v | Learning dynamics | 7 tests |
| tb_learning_full.v | Production learning | 3 tests |
| tb_state_transitions.v | State machine | 12 tests |
| tb_state_characterization.v | Consciousness metrics | 5 states |
| tb_kphase_sweep.v | Coupling stability | 6 K_PHASE values |
| tb_gamma_suppression_sweep.v | Anesthesia model | 9 levels |

## Module Reference

### phi_n_neural_processor (Top-Level)

```verilog
module phi_n_neural_processor #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter FAST_SIM = 0
)(
    input  wire clk,
    input  wire rst,
    input  wire signed [WIDTH-1:0] sensory_input,  // ONLY external input
    input  wire [2:0] state_select,                // Consciousness state
    output wire [11:0] dac_output,                 // 12-bit DAC
    output wire signed [WIDTH-1:0] debug_motor_l23,
    output wire signed [WIDTH-1:0] debug_theta,
    output wire ca3_learning,
    output wire ca3_recalling,
    output wire [5:0] ca3_phase_pattern,
    output wire [5:0] cortical_pattern_out
);
```

### hopf_oscillator

Implements Hopf normal form: dx/dt = (μ - r²)x - ωy, dy/dt = ωx + (μ - r²)y

```verilog
module hopf_oscillator #(
    parameter WIDTH = 18,
    parameter FRAC = 14
)(
    input  wire clk, rst, clk_en,
    input  wire signed [WIDTH-1:0] omega_dt,      // Angular frequency × dt
    input  wire signed [WIDTH-1:0] mu_dt,         // Bifurcation parameter
    input  wire signed [WIDTH-1:0] stimulus,      // External coupling
    output reg  signed [WIDTH-1:0] x, y,          // State variables
    output wire signed [WIDTH-1:0] amplitude      // |z| = sqrt(x² + y²)
);
```

### ca3_phase_memory

6-unit Hebbian associative memory with theta-gated learning/recall.

```verilog
module ca3_phase_memory #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter N_UNITS = 6
)(
    input  wire clk, rst, clk_en,
    input  wire signed [WIDTH-1:0] theta_x,       // Theta phase
    input  wire [N_UNITS-1:0] pattern_in,         // Input pattern
    output wire [N_UNITS-1:0] phase_pattern,      // Recalled pattern
    output wire learning, recalling,
    output wire [3:0] debug_state
);
```

## Analysis Scripts

### Python Dependencies

```bash
pip install numpy pandas matplotlib seaborn
```

### Available Scripts

```bash
# Learning dynamics visualization
python scripts/plot_learning.py learning_test.csv

# State transition analysis
python scripts/plot_state_transitions.py state_transitions.csv

# Phase coupling analysis (generates PDF)
python scripts/analyze_phase_coupling.py phase_timeseries.csv

# VCD metrics extraction
python scripts/analyze_vcd_metrics.py sim/tb_full_system_fast.vcd
```

## Resource Utilization (Zynq-7020)

| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| LUTs | ~14,300 | 85,150 | 16.8% |
| DSP48 | 129 | 220 | 59% |
| BRAM | <1 KB | 4.9 Mb | <1% |
| Flip-Flops | ~8,850 | 170,300 | 5.2% |

## Development Guidelines

### Adding New Modules

1. Place Verilog files in `src/`
2. Follow Q4.14 fixed-point convention (WIDTH=18, FRAC=14)
3. Include `clk_en` gating for timing
4. Add testbench in `tb/` with matching name

### Verilog Conventions

```verilog
// Fixed-point multiplication pattern
wire signed [2*WIDTH-1:0] product = a * b;
wire signed [WIDTH-1:0] result = product >>> FRAC;

// Sign-bit thresholding
assign active = ~x[WIDTH-1];  // x > 0

// Saturation
assign saturated = (val > MAX) ? MAX : (val < -MAX) ? -MAX : val;
```

### Simulation Best Practices

- Use FAST_SIM=1 for rapid iteration during development
- Run production timing (FAST_SIM=0) before synthesis
- Check VCD files in GTKWave for debugging
- Export CSV from testbenches for Python analysis

## Verified Behaviors

- Hopf oscillator amplitude converges to r²=1.0
- Frequency accuracy: <0.5% error across all layers
- Theta-gated learning: encode at peak, recall at trough
- 83% pattern recall accuracy from 1-bit cues
- 5 consciousness states with distinct signatures
- Closed-loop operation without external injection

## Dependencies

**Required:**
- Icarus Verilog (`brew install icarus-verilog`)

**Optional:**
- GTKWave for waveform viewing (`brew install gtkwave`)
- Vivado for synthesis (Xilinx Zynq target)
- Python 3 + numpy/pandas/matplotlib for analysis

## Related Documentation

- [docs/FPGA_SPECIFICATION_V7.md](docs/FPGA_SPECIFICATION_V7.md) - Full specification
- [docs/V7_COMPREHENSIVE_SUMMARY.md](docs/V7_COMPREHENSIVE_SUMMARY.md) - What's been built and tested
