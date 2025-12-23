# φⁿ Neural Processor

A biologically-realistic neural oscillator system implemented in Verilog for FPGA, featuring golden ratio (φ) frequency architecture with Schumann Resonance coupling.

## Overview

This project implements a thalamo-cortical neural architecture with 21 coupled Hopf oscillators operating at frequencies scaled by powers of the golden ratio (φ ≈ 1.618). The system models:

- **Theta-gated sensory processing** via thalamic relay
- **Multi-layer cortical columns** (L2/3, L4, L5a, L5b, L6)
- **Hebbian phase memory** in a CA3-inspired circuit
- **Schumann Resonance coupling** with 5 harmonics (7.49-51.33 Hz)
- **Consciousness state transitions** (Normal, Anesthesia, Psychedelic, Flow, Meditation)

## Requirements

### Hardware
- **Target:** Digilent Zybo Z7-20 (Xilinx Zynq-7020)
- **Clock:** 125 MHz system clock
- **Resources:** ~15k LUTs, ~140 DSP48 slices

### Software
- **Simulation:** [Icarus Verilog](http://iverilog.icarus.com/) (`iverilog`, `vvp`)
- **Waveform Viewer:** [GTKWave](http://gtkwave.sourceforge.net/) (optional)
- **Synthesis:** Xilinx Vivado (for FPGA deployment)
- **Analysis:** Python 3 with matplotlib (for visualization scripts)

## Quick Start

### Install Icarus Verilog

```bash
# macOS
brew install icarus-verilog

# Ubuntu/Debian
sudo apt install iverilog

# Windows
# Download from http://bleyer.org/icarus/
```

### Run Simulation

```bash
# Using Makefile
make iverilog-fast      # Fast CA3/theta test
make iverilog-full      # Full system test
make iverilog-all       # All tests

# Manual compilation
iverilog -o tb_full_system_fast.vvp -s tb_full_system_fast \
    src/*.v tb/tb_full_system_fast.v
vvp tb_full_system_fast.vvp
```

### View Waveforms

```bash
make wave-fast          # Opens GTKWave with fast test waveform
# Or manually:
gtkwave tb_full_system_fast.vcd
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    φⁿ NEURAL PROCESSOR                          │
│                                                                 │
│  SR Harmonic Bank (5 oscillators: f₀-f₄ at φⁿ frequencies)     │
│           ↓ coherence-based gain                                │
│  Thalamus (theta oscillator 5.89 Hz, sensory gating)           │
│           ↓ theta-gated output                                  │
│  Cortical Columns ×3 (Sensory → Association → Motor)           │
│    └─ L2/3 (40 Hz γ), L4 (32 Hz), L5a/b (15-25 Hz β), L6 (10 Hz α)
│           ↓ cortical pattern                                    │
│  CA3 Phase Memory (Hebbian learning, theta-phase gated)        │
│           ↓ phase coupling                                      │
│  Output Mixer → DAC (12-bit audio/neurofeedback)               │
└─────────────────────────────────────────────────────────────────┘
```

### Oscillator Frequencies

All frequencies follow φⁿ scaling from a base of ~7.49 Hz:

| Band | Frequency | φⁿ | Location |
|------|-----------|-----|----------|
| Theta | 5.89 Hz | φ⁻⁰·⁵ | Thalamus |
| Alpha | 9.53 Hz | φ⁰·⁵ | Cortex L6 |
| Low Beta | 15.42 Hz | φ¹·⁵ | Cortex L5a |
| High Beta | 24.94 Hz | φ²·⁵ | Cortex L5b |
| Gamma | 40.36 Hz | φ³·⁵ | Cortex L2/3 |

### Consciousness States

The system supports 5 consciousness states via `state_select[2:0]`:

| State | Effect |
|-------|--------|
| **Normal** (0) | Balanced oscillator activity |
| **Anesthesia** (1) | Suppressed gamma, enhanced alpha |
| **Psychedelic** (2) | Enhanced gamma entropy |
| **Flow** (3) | Enhanced beta, motor optimization |
| **Meditation** (4) | Theta coherence, reduced beta |

## Project Structure

```
├── src/                    # Verilog source modules
│   ├── phi_n_neural_processor.v   # Top-level module
│   ├── hopf_oscillator.v          # Core oscillator dynamics
│   ├── thalamus.v                 # Theta generation + gating
│   ├── cortical_column.v          # 5-layer cortical model
│   ├── ca3_phase_memory.v         # Hebbian phase memory
│   ├── sr_harmonic_bank.v         # Schumann Resonance bank
│   └── ...
├── tb/                     # Testbenches
│   ├── tb_full_system_fast.v      # Integration tests
│   ├── tb_learning_fast.v         # CA3 learning tests
│   └── ...
├── scripts/                # Analysis & visualization
│   ├── visualize_*.py             # Python plotting
│   └── run_vivado_*.tcl           # Synthesis scripts
├── docs/                   # Specifications
│   └── FPGA_SPECIFICATION_V8.md   # Full architecture doc
└── Makefile
```

## Technical Details

- **Fixed-point:** Q4.14 format (18-bit signed, 14 fractional bits)
- **Update rate:** 4 kHz oscillator dynamics
- **Simulation:** FAST_SIM parameter for ~3000× speedup

## Documentation

See [docs/FPGA_SPECIFICATION_V8.md](docs/FPGA_SPECIFICATION_V8.md) for complete technical specification including:
- Module interfaces and parameters
- Signal flow diagrams
- Coherence and gain computations
- Test protocols and verification

## License

Copyright (c) 2024 Neurokinetikz

## References

- Hopf bifurcation oscillators for neural modeling
- Golden ratio frequency relationships in neural oscillations
- Schumann Resonance and brain-earth coupling hypotheses
- Theta-gamma phase-amplitude coupling in hippocampus
