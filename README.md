# φⁿ Neural Processor

A biologically-realistic neural oscillator system implemented in Verilog for FPGA, featuring golden ratio (φ) frequency architecture with Schumann Resonance coupling.

**Current Version:** v8.5

## Overview

This project implements a thalamo-cortical neural architecture with 21 coupled Hopf oscillators operating at frequencies scaled by powers of the golden ratio (φ ≈ 1.618). The system models:

- **Theta-gated sensory processing** via thalamic relay with 8-phase multiplexing
- **Multi-layer cortical columns** (L2/3, L4, L5a, L5b, L6) with scaffold/plastic architecture
- **Hebbian phase memory** in a CA3-inspired circuit with theta-gated learning
- **Schumann Resonance coupling** with 5 drifting harmonics (7.6-32 Hz observed frequencies)
- **Gamma-theta nesting** with dynamic L2/3 frequency switching (40/65 Hz)
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
│                    φⁿ NEURAL PROCESSOR v8.5                     │
│                                                                 │
│  SR Frequency Drift (bounded random walk per harmonic)          │
│           ↓                                                     │
│  SR Harmonic Bank (5 stochastic oscillators: f₀-f₄)            │
│           ↓ coherence-based continuous gain                     │
│  Thalamus (theta 5.89 Hz, 8-phase multiplexing)                │
│           ↓ theta_phase, encoding_window                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ CA3 Phase Memory (Hebbian learning, theta-gated)        │   │
│  │   pattern_in[6] → weights[6×6] → phase_pattern[6]       │   │
│  └─────────────────────────────────────────────────────────┘   │
│           ↓ phase_coupling[6]                                   │
│  Cortical Columns ×3 (Sensory → Association → Motor)           │
│    ├─ L2/3 (40/65 Hz γ) ← gamma-theta nesting, PLASTIC         │
│    ├─ L4 (32 Hz)        ← thalamocortical, SCAFFOLD            │
│    ├─ L5a (15 Hz β)     ← motor output                         │
│    ├─ L5b (25 Hz β)     ← feedback, SCAFFOLD                   │
│    └─ L6 (10 Hz α)      ← gain control, PLASTIC                │
│           ↓                                                     │
│  Output Mixer → 12-bit DAC                                      │
└─────────────────────────────────────────────────────────────────┘
```

### Oscillator Frequencies

All cortical frequencies follow φⁿ scaling. SR harmonics use observed frequencies:

| Location | Frequency | φⁿ | Role |
|----------|-----------|-----|------|
| Theta (thalamus) | 5.89 Hz | φ⁻⁰·⁵ | Memory gating |
| SR f₀ | 7.6 Hz ± 0.6 | — | Schumann fundamental |
| SR f₁ | 13.75 Hz ± 0.75 | — | Alpha coupling |
| SR f₂ | 20 Hz ± 1 | — | Low beta coupling |
| SR f₃ | 25 Hz ± 1.5 | — | High beta coupling |
| SR f₄ | 32 Hz ± 2 | — | Gamma coupling |
| L6 (cortex) | 9.53 Hz | φ⁰·⁵ | Alpha gain control |
| L5a (cortex) | 15.42 Hz | φ¹·⁵ | Low beta motor |
| L5b (cortex) | 24.94 Hz | φ²·⁵ | High beta feedback |
| L4 (cortex) | 31.73 Hz | φ³ | Thalamocortical |
| L2/3 (cortex) | 40.36/65.3 Hz | φ³·⁵/φ⁴·⁵ | Gamma (switches) |

### Consciousness States

The system supports 5 consciousness states via `state_select[2:0]`:

| State | Effect |
|-------|--------|
| **Normal** (0) | Balanced oscillator activity |
| **Anesthesia** (1) | Suppressed gamma, enhanced alpha |
| **Psychedelic** (2) | Enhanced gamma entropy |
| **Flow** (3) | Enhanced beta, motor optimization |
| **Meditation** (4) | Theta coherence, reduced beta, SR-sensitive |

### Key Features (v8.x)

| Version | Feature | Description |
|---------|---------|-------------|
| v8.0 | Scaffold Architecture | L4/L5b stable backbone, L2/3/L6 plastic |
| v8.0 | Theta Phase Multiplexing | 8-phase cycle for encoding/retrieval |
| v8.1 | Gamma-Theta Nesting | L2/3 frequency switches with theta phase |
| v8.5 | SR Frequency Drift | Bounded random walk mimics real SR variation |

## Project Structure

```
├── src/                    # Verilog source modules (13 files)
│   ├── phi_n_neural_processor.v   # Top-level module (v8.2)
│   ├── hopf_oscillator.v          # Core oscillator dynamics (v6.0)
│   ├── hopf_oscillator_stochastic.v # Stochastic variant
│   ├── thalamus.v                 # Theta + SR integration (v8.1)
│   ├── cortical_column.v          # 5-layer cortical model (v8.1)
│   ├── ca3_phase_memory.v         # Hebbian phase memory (v8.0)
│   ├── sr_harmonic_bank.v         # SR bank with coherence (v7.4)
│   ├── sr_noise_generator.v       # Per-harmonic noise (5 LFSRs)
│   ├── sr_frequency_drift.v       # Frequency drift (v8.5)
│   ├── config_controller.v        # Consciousness states (v8.0)
│   └── ...
├── tb/                     # Testbenches (23 files, 125+ tests)
│   ├── tb_full_system_fast.v      # Integration tests (15 tests)
│   ├── tb_theta_phase_multiplexing.v # Phase tests (19 tests)
│   ├── tb_scaffold_architecture.v    # Scaffold tests (14 tests)
│   ├── tb_gamma_theta_nesting.v      # PAC tests (7 tests)
│   ├── tb_sr_frequency_drift.v       # Drift tests (v8.5)
│   ├── tb_learning_fast.v         # CA3 tests (8 tests)
│   └── ...
├── scripts/                # Analysis & visualization
│   ├── visualize_*.py             # Python plotting
│   └── run_vivado_*.tcl           # Synthesis scripts
├── docs/                   # Specifications
│   ├── FPGA_SPECIFICATION_V8.md   # Base architecture
│   ├── SPEC_v8.5_UPDATE.md        # Latest changes
│   └── SYSTEM_DESCRIPTION.md      # Comprehensive description
└── Makefile
```

## Technical Details

- **Fixed-point:** Q4.14 format (18-bit signed, 14 fractional bits)
- **Update rate:** 4 kHz oscillator dynamics
- **Simulation:** FAST_SIM parameter for ~3000× speedup
- **Oscillators:** 21 Hopf (16 deterministic + 5 stochastic)
- **Memory:** 6×6 symmetric Hebbian weight matrix (288 bits)

## Documentation

See [docs/SYSTEM_DESCRIPTION.md](docs/SYSTEM_DESCRIPTION.md) for comprehensive technical description.

See [docs/SPEC_v8.5_UPDATE.md](docs/SPEC_v8.5_UPDATE.md) for latest changes including:
- SR frequency drift implementation
- Updated observed frequencies
- Test coverage summary

See [CLAUDE.md](CLAUDE.md) for development workflow and quick reference.

## License

Copyright (c) 2024-2025 Neurokinetikz

## References

- Hopf bifurcation oscillators for neural modeling
- Golden ratio frequency relationships in neural oscillations
- Schumann Resonance and brain-earth coupling hypotheses
- Theta-gamma phase-amplitude coupling in hippocampus
- Dupret et al. 2025: Scaffold vs plastic neural populations
