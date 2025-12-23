# CLAUDE.md - φⁿ Neural Processor FPGA Project

## Project Overview

This is an FPGA implementation of a biologically-realistic neural oscillator system based on the **φⁿ (golden ratio) frequency architecture** with Schumann Resonance coupling. The system implements 21 Hopf oscillators organized into a thalamo-cortical architecture for neural signal processing and consciousness state modeling.

**Target Platform:** Digilent Zybo Z7-20 (Xilinx Zynq-7020)

## Quick Start

### Build & Simulate with Icarus Verilog

```bash
# Compile and run fast CA3/theta test
iverilog -o tb_v55_fast.vvp -s tb_v55_fast src/hopf_oscillator.v src/ca3_phase_memory.v tb/tb_v55_fast.v && vvp tb_v55_fast.vvp

# Compile and run full system test
iverilog -o tb_full_system_fast.vvp -s tb_full_system_fast \
    src/clock_enable_generator.v src/hopf_oscillator.v src/ca3_phase_memory.v \
    src/thalamus.v src/cortical_column.v src/config_controller.v \
    src/pink_noise_generator.v src/output_mixer.v src/phi_n_neural_processor.v \
    src/sr_harmonic_bank.v src/sr_noise_generator.v \
    tb/tb_full_system_fast.v && vvp tb_full_system_fast.vvp

# Run learning test
iverilog -o tb_learning_fast.vvp -s tb_learning_fast \
    src/clock_enable_generator.v src/hopf_oscillator.v src/ca3_phase_memory.v \
    src/thalamus.v src/cortical_column.v src/config_controller.v \
    src/pink_noise_generator.v src/output_mixer.v src/phi_n_neural_processor.v \
    src/sr_harmonic_bank.v src/sr_noise_generator.v \
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
├── src/                          # Verilog source modules
│   ├── phi_n_neural_processor.v  # Top-level (21 oscillators integrated)
│   ├── hopf_oscillator.v         # Core oscillator (dx/dt = μx - ωy - r²x)
│   ├── ca3_phase_memory.v        # Hebbian phase memory (theta-gated)
│   ├── thalamus.v                # Theta oscillator + SR gain application
│   ├── cortical_column.v         # 5-layer cortical model (L2/3, L4, L5a, L5b, L6)
│   ├── sr_harmonic_bank.v        # 5-harmonic Schumann Resonance bank
│   ├── config_controller.v       # Consciousness state MU parameters
│   ├── clock_enable_generator.v  # FAST_SIM-aware 4kHz clock generation
│   ├── pink_noise_generator.v    # 1/f noise (LFSR + Voss-McCartney)
│   └── output_mixer.v            # DAC output mixing
├── tb/                           # Testbenches
│   ├── tb_full_system_fast.v     # Full system integration test
│   ├── tb_learning_fast.v        # CA3 learning test
│   ├── tb_v55_fast.v             # CA3/theta fast test
│   ├── tb_hopf_oscillator.v      # Hopf oscillator unit test
│   ├── tb_state_transitions.v    # State machine test
│   └── ...                       # Other testbenches
├── scripts/                      # Simulation and analysis scripts
│   ├── visualize_*.py            # Python visualization
│   └── run_vivado_*.tcl          # Vivado TCL scripts
├── docs/                         # Specifications
│   ├── FPGA_SPECIFICATION_V8.md  # Base architecture spec (v8.0)
│   └── SPEC_v8.4_UPDATE.md       # Current version (v8.4)
└── Makefile
```

## Key Architecture Concepts

### Fixed-Point Format: Q4.14
- 18-bit signed integers
- 4 integer bits, 14 fractional bits
- Range: [-8.0, +7.99994]
- Unity (1.0) = 16384

### 21 Hopf Oscillators at φⁿ Frequencies
| Location | Frequency | φⁿ | Purpose |
|----------|-----------|-----|---------|
| Thalamus Theta | 5.89 Hz | φ⁻⁰·⁵ | Learn/recall gating |
| SR Bank f₀-f₄ | 7.49-51.33 Hz | φ⁰-φ⁴ | Schumann Resonance harmonics |
| Cortex L2/3 ×3 | 40.36 Hz | φ³·⁵ | Gamma, feedforward |
| Cortex L4 ×3 | 31.73 Hz | φ³ | Thalamocortical |
| Cortex L5a/b ×3 | 15-25 Hz | φ¹·⁵-φ²·⁵ | Beta, motor/feedback |
| Cortex L6 ×3 | 9.53 Hz | φ⁰·⁵ | Alpha, gain control |

### Consciousness States (state_select[2:0])
| Code | State | Description |
|------|-------|-------------|
| 0 | NORMAL | Baseline |
| 1 | ANESTHESIA | Propofol-like suppression |
| 2 | PSYCHEDELIC | Enhanced gamma |
| 3 | FLOW | Motor-focused optimal performance |
| 4 | MEDITATION | Theta coherence |

### Simulation Speedup (FAST_SIM parameter)
- `FAST_SIM=0`: Real-time (4 kHz, divider=31250)
- `FAST_SIM=1`: Simulation (12.5 MHz, divider=10) — ~3000× faster

## Common Development Tasks

### Adding a New Testbench
1. Create `tb/tb_<name>.v`
2. Set `parameter FAST_SIM = 1` for quick simulation
3. Compile with all required source files
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
| K_PHASE | 4096 | 0.25 | Phase coupling |
| MAX_GAIN | 32768 | 2.0 | SR amplification limit |
| BETA_QUIET_THRESHOLD | 12288 | 0.75 | SR gating |

## Current Specification

See [docs/SPEC_v8.4_UPDATE.md](docs/SPEC_v8.4_UPDATE.md) for the latest v8.4 architecture with:
- Theta phase multiplexing (8-phase encoding/retrieval windows)
- Scaffold architecture (L4/L5b stable, L2/3/L6 plastic)
- Gamma-theta nesting (L2/3 frequency switching: 65.3/40.36 Hz)
- Comprehensive integration testing (121+ tests)

Base specification: [docs/FPGA_SPECIFICATION_V8.md](docs/FPGA_SPECIFICATION_V8.md)

## Testing

All testbenches should pass. Key tests:
- `tb_full_system_fast`: 15/15 tests - full integration (v6.5)
- `tb_theta_phase_multiplexing`: 19/19 tests - theta phase (v8.3)
- `tb_scaffold_architecture`: 14/14 tests - scaffold layers (v8.0)
- `tb_gamma_theta_nesting`: 7/7 tests - gamma-theta PAC (v8.4)
- `tb_learning_fast`: 8/8 tests - CA3 Hebbian learning (v2.1)
- `tb_state_transitions`: 12/12 tests - consciousness states

## Notes

- Compiled `.vvp` and `.vcd` files are gitignored
- CSV output files from testbenches are gitignored
- Python scripts in `scripts/` visualize simulation data
