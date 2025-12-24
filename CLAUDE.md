# CLAUDE.md - φⁿ Neural Processor FPGA Project

## Project Overview

This is an FPGA implementation of a biologically-realistic neural oscillator system based on the **φⁿ (golden ratio) frequency architecture** with Schumann Resonance coupling. The system implements 21 Hopf oscillators organized into a thalamo-cortical architecture for neural signal processing and consciousness state modeling.

**Current Version:** v8.6 (Canonical Microcircuit)
**Target Platform:** Digilent Zybo Z7-20 (Xilinx Zynq-7020)

## Quick Start

### Build & Simulate with Icarus Verilog

```bash
# Compile and run fast CA3/theta test
iverilog -o tb_v55_fast.vvp -s tb_v55_fast src/hopf_oscillator.v src/ca3_phase_memory.v tb/tb_v55_fast.v && vvp tb_v55_fast.vvp

# Compile and run full system test
iverilog -o tb_full_system_fast.vvp -s tb_full_system_fast \
    src/clock_enable_generator.v src/hopf_oscillator.v src/hopf_oscillator_stochastic.v \
    src/ca3_phase_memory.v src/thalamus.v src/cortical_column.v src/config_controller.v \
    src/pink_noise_generator.v src/output_mixer.v src/phi_n_neural_processor.v \
    src/sr_harmonic_bank.v src/sr_noise_generator.v src/sr_frequency_drift.v \
    tb/tb_full_system_fast.v && vvp tb_full_system_fast.vvp

# Run learning test
iverilog -o tb_learning_fast.vvp -s tb_learning_fast \
    src/clock_enable_generator.v src/hopf_oscillator.v src/hopf_oscillator_stochastic.v \
    src/ca3_phase_memory.v src/thalamus.v src/cortical_column.v src/config_controller.v \
    src/pink_noise_generator.v src/output_mixer.v src/phi_n_neural_processor.v \
    src/sr_harmonic_bank.v src/sr_noise_generator.v src/sr_frequency_drift.v \
    tb/tb_learning_fast.v && vvp tb_learning_fast.vvp
```

### Makefile Targets

```bash
make iverilog-fast     # Fast CA3/theta test
make iverilog-full     # Full system test
make iverilog-hopf     # Hopf oscillator unit test
make iverilog-theta    # Theta phase multiplexing test (v8.3)
make iverilog-scaffold # Scaffold architecture test (v8.3)
make iverilog-all      # All tests
make wave-fast         # Open waveform in GTKWave
make clean             # Clean generated files
```

## Project Structure

```
fpga/
├── src/                          # Verilog source modules (13 files)
│   ├── phi_n_neural_processor.v  # Top-level (v8.2, 21 oscillators integrated)
│   ├── hopf_oscillator.v         # Core oscillator (v6.0, dx/dt = μx - ωy - r²x)
│   ├── hopf_oscillator_stochastic.v # Stochastic variant with noise input
│   ├── ca3_phase_memory.v        # Hebbian phase memory (v8.0, theta-gated)
│   ├── thalamus.v                # Theta oscillator + SR gain (v8.1)
│   ├── cortical_column.v         # 5-layer cortical model (v8.6, canonical microcircuit)
│   ├── sr_harmonic_bank.v        # 5-harmonic SR bank (v7.4, continuous gain)
│   ├── sr_noise_generator.v      # Per-harmonic stochastic noise (5 LFSRs)
│   ├── sr_frequency_drift.v      # v8.5: Realistic SR frequency drift
│   ├── config_controller.v       # Consciousness states (v8.0, scaffold architecture)
│   ├── clock_enable_generator.v  # FAST_SIM-aware 4kHz clock (v6.0)
│   ├── pink_noise_generator.v    # 1/f noise (v5.5, Voss-McCartney)
│   └── output_mixer.v            # DAC output mixing (v5.5)
├── tb/                           # Testbenches (24 files)
│   ├── tb_full_system_fast.v     # Full system integration (v6.5, 15 tests)
│   ├── tb_theta_phase_multiplexing.v # Theta phase tests (19 tests)
│   ├── tb_scaffold_architecture.v    # Scaffold layer tests (14 tests)
│   ├── tb_gamma_theta_nesting.v      # Gamma-theta PAC tests (7 tests)
│   ├── tb_sr_frequency_drift.v       # v8.5: SR drift tests (30 tests)
│   ├── tb_canonical_microcircuit.v   # v8.6: Canonical pathway tests (20 tests)
│   ├── tb_learning_fast.v        # CA3 learning test (v2.1, 8 tests)
│   ├── tb_hopf_oscillator.v      # Hopf oscillator unit test
│   ├── tb_state_transitions.v    # State machine test (12 tests)
│   ├── tb_multi_harmonic_sr.v    # Multi-harmonic SR tests (17 tests)
│   └── ...                       # Other testbenches
├── scripts/                      # Simulation and analysis scripts
│   ├── visualize_*.py            # Python visualization
│   └── run_vivado_*.tcl          # Vivado TCL scripts
├── docs/                         # Specifications
│   ├── FPGA_SPECIFICATION_V8.md  # Base architecture spec (v8.0)
│   ├── SPEC_v8.6_UPDATE.md       # Current version (v8.6)
│   └── SYSTEM_DESCRIPTION.md     # Comprehensive system description
└── Makefile
```

## Key Architecture Concepts

### Fixed-Point Format: Q4.14
- 18-bit signed integers
- 4 integer bits, 14 fractional bits
- Range: [-8.0, +7.99994]
- Unity (1.0) = 16384

### 21 Hopf Oscillators at φⁿ Frequencies

| Location | Frequency | φⁿ | OMEGA_DT | Purpose |
|----------|-----------|-----|----------|---------|
| Thalamus Theta | 5.89 Hz | φ⁻⁰·⁵ | 152 | Learn/recall gating |
| SR f₀ | 7.6 Hz | — | 196 | Schumann fundamental |
| SR f₁ | 13.75 Hz | — | 354 | Alpha-band coupling |
| SR f₂ | 20 Hz | — | 514 | Low beta coupling |
| SR f₃ | 25 Hz | — | 643 | High beta coupling |
| SR f₄ | 32 Hz | — | 823 | Gamma coupling |
| Cortex L6 ×3 | 9.53 Hz | φ⁰·⁵ | 245 | Alpha, gain control |
| Cortex L5a ×3 | 15.42 Hz | φ¹·⁵ | 397 | Low beta, motor |
| Cortex L5b ×3 | 24.94 Hz | φ²·⁵ | 642 | High beta, feedback |
| Cortex L4 ×3 | 31.73 Hz | φ³ | 817 | Thalamocortical |
| Cortex L2/3 ×3 | 40.36/65.3 Hz | φ³·⁵/φ⁴·⁵ | 1040/1681 | Gamma (switches with theta) |

### SR Frequency-to-EEG-Band Mapping (v8.5)

| SR Harmonic | Observed Frequency | Drift Range | Coherence Target |
|-------------|-------------------|-------------|------------------|
| f₀ | 7.6 Hz | ±0.6 Hz | theta (thalamus) |
| f₁ | 13.75 Hz | ±0.75 Hz | alpha (L6) |
| f₂ | 20 Hz | ±1 Hz | low_beta (L5a) |
| f₃ | 25 Hz | ±1.5 Hz | high_beta (L5b) |
| f₄ | 32 Hz | ±2 Hz | gamma (L4) |

### Consciousness States (state_select[2:0])

| Code | State | Description | Key Changes |
|------|-------|-------------|-------------|
| 0 | NORMAL | Baseline | All MU = 4 |
| 1 | ANESTHESIA | Propofol-like | L6 high, L4/L2/3 weak |
| 2 | PSYCHEDELIC | Enhanced binding | L4/L2/3 enhanced, L6 reduced |
| 3 | FLOW | Motor-optimized | L5a/L5b enhanced |
| 4 | MEDITATION | Theta coherence | L5a/L5b/L4/L2/3 reduced |

### Scaffold vs Plastic Layers (v8.0)

| Layer | Type | Behavior |
|-------|------|----------|
| L4 | Scaffold | Stable backbone, resists perturbation |
| L5b | Scaffold | Maintains state, high-beta feedback |
| L2/3 | Plastic | Receives phase coupling, gamma feedforward |
| L6 | Plastic | Receives phase coupling, alpha gain control |
| L5a | Intermediate | Motor output, no direct coupling |

### Simulation Speedup (FAST_SIM parameter)
- `FAST_SIM=0`: Real-time (4 kHz, divider=31250)
- `FAST_SIM=1`: Simulation (12.5 MHz, divider=10) — ~3000× faster

## Common Development Tasks

### Adding a New Testbench
1. Create `tb/tb_<name>.v`
2. Set `parameter FAST_SIM = 1` for quick simulation
3. Compile with all required source files (use `src/*.v` for convenience)
4. Access internal signals via hierarchical paths: `dut.thal.theta_x`

### Modifying Oscillator Parameters
- Frequency (OMEGA_DT): `round(2π × f_hz × 0.00025 × 16384)`
- Growth rate (MU): Values 1-6 in config_controller.v

### Debugging Tips
- VCD waveforms: Add `$dumpfile`/`$dumpvars` to testbench
- View in GTKWave: `gtkwave <file>.vcd`
- Check test assertions: Look for `$display` output with PASS/FAIL

## Important Constants (Q14 values)

| Name | Q14 Value | Decimal | Usage |
|------|-----------|---------|-------|
| ONE | 16384 | 1.0 | Unity |
| HALF | 8192 | 0.5 | Theta gate baseline |
| K_PHASE | 4096 | 0.25 | Phase coupling strength |
| MAX_GAIN | 32768 | 2.0 | SR amplification limit |
| BETA_QUIET_THRESHOLD | 15360 | 0.9375 | SR gating threshold |
| COHERENCE_THRESHOLD | 12288 | 0.75 | SIE detection |

## Current Specification

See [docs/SPEC_v8.6_UPDATE.md](docs/SPEC_v8.6_UPDATE.md) for the latest v8.6 architecture with:
- **Canonical Microcircuit** (v8.6): L4→L2/3→L5→L6 signal flow, L5b→L6 feedback
- **SR Frequency Drift** (v8.5): Realistic bounded random walk within observed SR ranges
- Theta phase multiplexing (8-phase encoding/retrieval windows)
- Scaffold architecture (L4/L5b stable, L2/3/L6 plastic)
- Gamma-theta nesting (L2/3 frequency switching: 65.3/40.36 Hz)
- Continuous coherence-based SR gain (replaces binary SIE)

Base specification: [docs/FPGA_SPECIFICATION_V8.md](docs/FPGA_SPECIFICATION_V8.md)

## Testing

All testbenches should pass. Key tests (139+ total):
- `tb_full_system_fast`: 15/15 tests - full integration (v6.5)
- `tb_theta_phase_multiplexing`: 19/19 tests - theta phase (v8.3)
- `tb_scaffold_architecture`: 14/14 tests - scaffold layers (v8.0)
- `tb_gamma_theta_nesting`: 7/7 tests - gamma-theta PAC (v8.4)
- `tb_sr_frequency_drift`: 30/30 tests - SR drift (v8.5)
- `tb_canonical_microcircuit`: 20/20 tests - canonical pathway (v8.6)
- `tb_multi_harmonic_sr`: 17/17 tests - multi-harmonic SR
- `tb_learning_fast`: 8/8 tests - CA3 Hebbian learning (v2.1)
- `tb_state_transitions`: 12/12 tests - consciousness states
- `tb_hopf_oscillator`: 5/5 tests - Hopf dynamics

## Notes

- Compiled `.vvp` and `.vcd` files are gitignored
- CSV output files from testbenches are gitignored
- Python scripts in `scripts/` visualize simulation data
