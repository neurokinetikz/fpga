# CLAUDE.md - φⁿ Neural Processor FPGA Project

## Project Overview

This is an FPGA implementation of a biologically-realistic neural oscillator system based on the **φⁿ (golden ratio) frequency architecture** with Schumann Resonance coupling. The system implements 21 Hopf oscillators organized into a thalamo-cortical architecture for neural signal processing and consciousness state modeling.

**Current Version:** v10.3 (1/f^φ Spectral Slope)
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
├── src/                          # Verilog source modules (19 files)
│   ├── phi_n_neural_processor.v  # Top-level (v10.2, 21 oscillators + EEG realism)
│   ├── hopf_oscillator.v         # Core oscillator (v6.0, dx/dt = μx - ωy - r²x)
│   ├── hopf_oscillator_stochastic.v # Stochastic variant with noise input
│   ├── ca3_phase_memory.v        # Hebbian phase memory (v8.0, theta-gated)
│   ├── thalamus.v                # Theta + SR + matrix + L6 inhibition (v8.8)
│   ├── cortical_column.v         # 6-layer cortical model (v10.0, freq drift)
│   ├── dendritic_compartment.v   # v9.5: Two-compartment dendritic model
│   ├── layer1_minimal.v          # Layer 1 with L6 input (v9.6)
│   ├── pv_interneuron.v          # PV+ basket cell dynamics (v9.2)
│   ├── sr_harmonic_bank.v        # 5-harmonic SR bank (v7.4, continuous gain)
│   ├── sr_noise_generator.v      # Per-harmonic stochastic noise (5 LFSRs)
│   ├── sr_frequency_drift.v      # v8.5: Realistic SR frequency drift
│   ├── sr_ignition_controller.v  # v10.0: Six-phase SIE state machine
│   ├── amplitude_envelope_generator.v # v10.0: O-U process for alpha breathing
│   ├── cortical_frequency_drift.v # v10.2: Slow drift + fast jitter
│   ├── config_controller.v       # Consciousness states (v10.0, SIE timing)
│   ├── clock_enable_generator.v  # FAST_SIM-aware 4kHz clock (v6.0)
│   ├── pink_noise_generator.v    # 1/f^φ noise (v7.2, √Fibonacci-weighted)
│   └── output_mixer.v            # DAC output mixing (v7.3, envelope modulation)
├── tb/                           # Testbenches (27 files)
│   ├── tb_full_system_fast.v     # Full system integration (v6.5, 15 tests)
│   ├── tb_theta_phase_multiplexing.v # Theta phase tests (19 tests)
│   ├── tb_scaffold_architecture.v    # Scaffold layer tests (14 tests)
│   ├── tb_gamma_theta_nesting.v      # Gamma-theta PAC tests (7 tests)
│   ├── tb_sr_frequency_drift.v       # v8.5: SR drift tests (30 tests)
│   ├── tb_canonical_microcircuit.v   # v8.6: Canonical pathway tests (20 tests)
│   ├── tb_layer1_minimal.v       # v8.7: Layer 1 gain modulation tests (10 tests)
│   ├── tb_l6_connectivity.v      # v8.8: L6 output target tests (10 tests)
│   ├── tb_l6_extended.v          # v9.6: Extended L6 connectivity tests (10 tests)
│   ├── tb_dendritic_compartment.v # v9.5: Dendritic Ca²⁺/BAC tests (10 tests)
│   ├── tb_amplitude_envelope.v   # v10.0: O-U envelope tests (8 tests)
│   ├── tb_sr_ignition_phases.v   # v10.0: SIE phase evolution tests (10 tests)
│   ├── tb_eeg_export.v           # v10.0: EEG data export testbench
│   ├── tb_learning_fast.v        # CA3 learning test (v2.1, 8 tests)
│   ├── tb_hopf_oscillator.v      # Hopf oscillator unit test
│   ├── tb_state_transitions.v    # State machine test (12 tests)
│   ├── tb_multi_harmonic_sr.v    # Multi-harmonic SR tests (17 tests)
│   └── ...                       # Other testbenches
├── scripts/                      # Simulation and analysis scripts
│   ├── visualize_*.py            # Python visualization
│   ├── dac_spectrogram.py        # v10.2: DAC output spectrogram analysis
│   ├── analyze_eeg_comparison.py # v10.0: Comprehensive EEG analysis
│   └── run_vivado_*.tcl          # Vivado TCL scripts
├── docs/                         # Specifications
│   ├── FPGA_SPECIFICATION_V8.md  # Base architecture spec (v8.0)
│   ├── SPEC_v10.2_UPDATE.md      # Current version (v10.2 EEG Realism)
│   ├── SPEC_v9.6_UPDATE.md       # Extended L6 connectivity (v9.6)
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
| L1 | Gain modulator | Matrix thalamic + dual feedback → apical gain |

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
| K_MATRIX | 2458 | 0.15 | Matrix thalamus → L1 weight |
| K_FB1 | 4915 | 0.3 | Adjacent column feedback weight |
| K_FB2 | 3277 | 0.2 | Distant column feedback weight |
| GAIN_MIN | 4096 | 0.25 | L1 minimum apical gain (v9.6: was 0.5) |
| GAIN_MAX | 32768 | 2.0 | L1 maximum apical gain (v9.6: was 1.5) |
| K_L6_L5A | 2458 | 0.15 | L6 → L5a intra-column (v8.8) |
| K_L4_L5A | 1638 | 0.1 | L4 → L5a bypass (v8.8) |
| K_L6_THAL | 1638 | 0.1 | L6 → Thalamus direct inhibition (v8.8) |
| K_TRN | 3277 | 0.2 | TRN amplification of L6 inhibition (v8.8) |
| SST_ALPHA | 164 | 0.01 | SST+ slow dynamics filter coefficient (v9.1) |
| TAU_INV | 819 | 0.05 | PV+ time constant inverse (tau=5ms) (v9.2) |
| K_EXCITE | 8192 | 0.5 | PV+ excitation gain from pyramid (v9.2) |
| K_INHIB | 4915 | 0.3 | PV+ inhibition output weight (v9.2) |
| VIP_ALPHA | 82 | 0.005 | VIP+ slow dynamics filter coefficient (v9.4) |
| K_VIP | 8192 | 0.5 | VIP+ attention input scaling (v9.4) |
| APICAL_CABLE_ALPHA | 410 | 0.025 | Apical cable filter (tau=10ms) (v9.5) |
| CA_DURATION_ALPHA | 137 | 0.00833 | Ca²⁺ spike duration (tau=30ms) (v9.5) |
| K_APICAL | 4096 | 0.25 | Apical contribution weight (v9.5) |
| K_BAC | 24576 | 1.5 | BAC supralinear boost factor (v9.5) |
| CA_THRESH_NORMAL | 8192 | 0.5 | Ca²⁺ threshold in NORMAL state (v9.5) |
| CA_THRESH_PSYCHEDELIC | 4096 | 0.25 | Ca²⁺ threshold in PSYCHEDELIC (v9.5) |
| CA_THRESH_ANESTHESIA | 12288 | 0.75 | Ca²⁺ threshold in ANESTHESIA (v9.5) |
| K_L6_L23 | 2458 | 0.15 | L6 → L2/3 alpha-gamma coupling (v9.6) |
| K_L6_L5B | 1638 | 0.1 | L6 → L5b intra-column feedback (v9.6) |
| K_L6_L1 | 1638 | 0.1 | L6 → L1 direct gain modulation (v9.6) |
| ENVELOPE_MIN | 8192 | 0.5 | Amplitude envelope minimum (v10.0) |
| ENVELOPE_MAX | 24576 | 1.5 | Amplitude envelope maximum (v10.0) |
| ENVELOPE_MEAN | 16384 | 1.0 | Amplitude envelope equilibrium (v10.0) |
| DRIFT_MAX | 13 | ±0.5 Hz | Cortical frequency drift range (v10.0) |
| JITTER_MAX | 13 | ±0.5 Hz | Fast frequency jitter range (v10.2) |
| W_THETA | 328 | 0.02 | Output mixer theta weight (v7.3) |
| W_ALPHA | 492 | 0.03 | Output mixer alpha weight (v7.3) |
| W_BETA | 328 | 0.02 | Output mixer beta weight (v7.3) |
| W_GAMMA | 164 | 0.01 | Output mixer gamma weight (v7.3) |
| W_PINK_NOISE | 15073 | 0.92 | Output mixer 1/f noise weight (v7.3) |
| SIE_COHERENCE_THRESH | 9830 | 0.60 | SR ignition trigger threshold (v10.0) |
| SIE_GAIN_BASELINE | 0 | 0.0 | SR baseline gain (v10.0, coherence-gated) |
| SIE_GAIN_PEAK | 16384 | 1.0 | SR peak gain during ignition (v10.0) |

## Current Specification

See [docs/SPEC_v10.3_UPDATE.md](docs/SPEC_v10.3_UPDATE.md) for the latest v10.3 architecture with:
- **1/f^φ Spectral Slope** (v10.3): √Fibonacci-weighted pink noise (v7.2) achieves golden ratio exponent
- **Spectral Broadening** (v10.2): Fast frequency jitter (±0.5 Hz/sample) for ~1-2 Hz wide peaks
- **Envelope Integration** (v10.1): Per-band amplitude envelopes connected to output mixer
- **EEG Realism Phase 1** (v10.0): Amplitude envelopes, slow drift, SIE controller
- **1/f-Dominated Spectrum** (v7.3): 8% oscillators, 92% pink noise for realistic EEG
- **Coherence-Gated SR** (v10.0): SR only appears during ignition events (GAIN_BASELINE = 0)

Previous architecture features (v9.x series):
- **Extended L6 Connectivity** (v9.6): L6→L2/3, L6→L5b, L6→L1 modulatory pathways (all basal compartment)
- **Two-Compartment Dendritic Model** (v9.5): Basal/apical separation with Ca²⁺ spike dynamics and BAC firing
- **State-Dependent Ca²⁺ Threshold** (v9.5): Lower in PSYCHEDELIC (more Ca²⁺), higher in ANESTHESIA (fewer Ca²⁺)
- **VIP+ Disinhibition** (v9.4): VIP+ cells receive attention input and inhibit SST+ for selective enhancement
- **Cross-Layer PV+ Network** (v9.3): L4 PV+ (feedforward gating, 0.5×) + L5 PV+ (feedback inhibition, 0.25×)
- **PV+ PING Network** (v9.2): Dynamic PV+ interneuron model creates proper E-I loop with phase lag
- **SST+ Slow Dynamics** (v9.1): IIR lowpass filter models GABA-B kinetics (~25ms time constant)
- **L6 Output Connectivity** (v8.8): L6→L5a, L4→L5a bypass, L6→Thalamus+TRN inhibition
- **Separate L5a/L5b Inputs** (v8.8): L5a receives L6 feedback + L4 bypass; L5b unchanged
- **Layer 1 Gain Modulation** (v8.7): Molecular layer integrates matrix + feedback → apical gain [0.5, 1.5]
- **Matrix Thalamic Pathway** (v8.7): L5b → Thalamus → L1 diffuse broadcast (POm/Pulvinar analog)
- **Canonical Microcircuit** (v8.6): L4→L2/3→L5→L6 signal flow, L5b→L6 feedback
- **SR Frequency Drift** (v8.5): Realistic bounded random walk within observed SR ranges
- Theta phase multiplexing (8-phase encoding/retrieval windows)
- Scaffold architecture (L4/L5b stable, L2/3/L6 plastic)
- Gamma-theta nesting (L2/3 frequency switching: 65.3/40.36 Hz)

Base specification: [docs/FPGA_SPECIFICATION_V8.md](docs/FPGA_SPECIFICATION_V8.md)

## Testing

All testbenches should pass. Key tests (226+ total):
- `tb_full_system_fast`: 15/15 tests - full integration (v6.5)
- `tb_theta_phase_multiplexing`: 19/19 tests - theta phase (v8.3)
- `tb_scaffold_architecture`: 14/14 tests - scaffold layers (v8.0)
- `tb_gamma_theta_nesting`: 7/7 tests - gamma-theta PAC (v8.4)
- `tb_sr_frequency_drift`: 30/30 tests - SR drift (v8.5)
- `tb_canonical_microcircuit`: 20/20 tests - canonical pathway (v8.6)
- `tb_layer1_minimal`: 10/10 tests - Layer 1 gain modulation (v8.7)
- `tb_l6_connectivity`: 10/10 tests - L6 output targets (v8.8)
- `tb_pv_minimal`: 6/6 tests - PV+ basket cell inhibition (v9.0)
- `tb_sst_dynamics`: 8/8 tests - SST+ slow dynamics (v9.1)
- `tb_pv_feedback`: 8/8 tests - PV+ PING network dynamics (v9.2)
- `tb_pv_crosslayer`: 8/8 tests - Cross-layer PV+ network (v9.3)
- `tb_vip_disinhibition`: 8/8 tests - VIP+ disinhibition (v9.4)
- `tb_dendritic_compartment`: 10/10 tests - Dendritic Ca²⁺/BAC (v9.5)
- `tb_l6_extended`: 10/10 tests - Extended L6 connectivity (v9.6)
- `tb_amplitude_envelope`: 8/8 tests - O-U envelope dynamics (v10.0)
- `tb_sr_ignition_phases`: 10/10 tests - SIE phase evolution (v10.0)
- `tb_multi_harmonic_sr`: 17/17 tests - multi-harmonic SR
- `tb_learning_fast`: 8/8 tests - CA3 Hebbian learning (v2.1)
- `tb_sr_coupling`: 12/12 tests - SR coupling
- `tb_v55_fast`: 6/6 tests - fast integration

## Notes

- Compiled `.vvp` and `.vcd` files are gitignored
- CSV output files from testbenches are gitignored
- Python scripts in `scripts/` visualize simulation data
