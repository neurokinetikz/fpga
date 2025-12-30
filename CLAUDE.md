# CLAUDE.md - φⁿ Neural Processor FPGA Project

## Project Overview

This is an FPGA implementation of a biologically-realistic neural oscillator system based on the **φⁿ (golden ratio) frequency architecture** with Schumann Resonance coupling. The system implements 21 Hopf oscillators organized into a thalamo-cortical architecture for neural signal processing and consciousness state modeling.

**Current Version:** v12.2 (Dual Alignment Ignition)
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
├── src/                          # Verilog source modules (31 files)
│   ├── phi_n_neural_processor.v  # Top-level (v11.6, dual alignment ignition)
│   ├── hopf_oscillator.v         # Core oscillator (v6.0, dx/dt = μx - ωy - r²x)
│   ├── hopf_oscillator_stochastic.v # Stochastic variant with noise input
│   ├── ca3_phase_memory.v        # Hebbian phase memory (v8.0, theta-gated)
│   ├── thalamus.v                # Theta + SR + matrix (v11.6, alignment drift)
│   ├── thalamic_frequency_drift.v # v1.0: Theta frequency drift for alignment
│   ├── cortical_column.v         # 6-layer cortical model (v12.2, φⁿ×7.75 Hz)
│   ├── phi_n_alignment_detector.v # v1.0: √(θ×α) = SR1 alignment detection
│   ├── dendritic_compartment.v   # v9.5: Two-compartment dendritic model
│   ├── layer1_minimal.v          # Layer 1 with L6 input (v9.6)
│   ├── pv_interneuron.v          # PV+ basket cell dynamics (v9.2)
│   ├── sr_harmonic_bank.v        # 5-harmonic SR bank (v7.7, dynamic SIE from stability)
│   ├── sr_noise_generator.v      # Per-harmonic stochastic noise (5 LFSRs)
│   ├── sr_frequency_drift.v      # v2.1: f₀=7.75 Hz, tightened drift ±0.5 Hz
│   ├── sr_ignition_controller.v  # v1.4: Alignment-modulated threshold
│   ├── amplitude_envelope_generator.v # v11.4: O-U process with parameterized bounds
│   ├── cortical_frequency_drift.v # v3.5: Per-layer drift matching SR harmonics
│   ├── config_controller.v       # Consciousness states (v11.4, state interpolation)
│   ├── clock_enable_generator.v  # FAST_SIM-aware 4kHz clock (v6.0)
│   ├── pink_noise_generator.v    # 1/f^φ noise (v7.2, √Fibonacci-weighted)
│   ├── output_mixer.v            # DAC output mixing (v7.20, continuous gain blending)
│   ├── energy_landscape.v        # v11.2: Ratio-based catastrophe + escape mechanism
│   ├── quarter_integer_detector.v # v11.0: Position classification and stability
│   ├── sin_quarter_lut.v         # v11.0: 256-entry quarter-wave sine LUT
│   ├── coupling_susceptibility.v # v11.1a: Farey χ(r) with 55 rationals + φⁿ boundaries
│   ├── pac_strength.v            # v11.1c: Phase-amplitude coupling strength (10 pairs)
│   ├── kuramoto_order_parameter.v # v11.3: Population synchronization metric
│   ├── boundary_generator.v      # v11.3: Nonlinear mixing for boundary frequencies
│   ├── bicoherence_monitor.v     # v11.3: Three-frequency coupling detection
│   ├── coupling_mode_controller.v # v1.2b: Synchronized gain interpolation
│   └── harmonic_spacing_index.v  # v11.3: φⁿ ratio deviation monitoring
├── tb/                           # Testbenches (37 files)
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
│   ├── tb_coupling_susceptibility.v # v11.1a: Farey χ(r) tests (20 tests)
│   ├── tb_energy_landscape.v     # v11.1b: Force + rational tests (24 tests)
│   ├── tb_quarter_integer_detector.v # v11.0: Position classification (8 tests)
│   ├── tb_self_organization.v    # v11.0: Full integration tests (10 tests)
│   ├── tb_pac_strength.v         # v11.1c: PAC strength tests (10 tests)
│   ├── tb_kuramoto_order.v       # v11.3: Kuramoto R tests (7 tests)
│   ├── tb_boundary_generator.v   # v11.3: Boundary mixing tests (7 tests)
│   ├── tb_bicoherence_monitor.v  # v11.3: Bicoherence tests (6 tests)
│   ├── tb_coupling_mode_controller.v # v11.3: Mode switching tests (8 tests)
│   ├── tb_harmonic_spacing_index.v # v11.3: HSI tests (8 tests)
│   ├── tb_state_interpolation.v  # v11.4: State transition tests (10 tests)
│   ├── tb_state_transition_spectrogram.v # v12.1: 100s spectrogram with debug columns
│   ├── tb_learning_fast.v        # CA3 learning test (v2.1, 8 tests)
│   ├── tb_hopf_oscillator.v      # Hopf oscillator unit test
│   ├── tb_state_transitions.v    # State machine test (12 tests)
│   ├── tb_multi_harmonic_sr.v    # Multi-harmonic SR tests (17 tests)
│   └── ...                       # Other testbenches
├── scripts/                      # Simulation and analysis scripts
│   ├── visualize_*.py            # Python visualization
│   ├── dac_spectrogram.py        # v10.2: DAC output spectrogram analysis
│   ├── analyze_eeg_comparison.py # v10.0: Comprehensive EEG analysis
│   ├── state_transition_spectrogram.py # v11.4: State transition analysis
│   └── run_vivado_*.tcl          # Vivado TCL scripts
├── docs/                         # Specifications
│   ├── FPGA_SPECIFICATION_V8.md  # Base architecture spec (v8.0)
│   ├── SPEC_v12.2_UPDATE.md      # Current version (v12.2 Dual Alignment Ignition)
│   ├── SPEC_v12.1_UPDATE.md      # Previous (v12.1 Synchronized State Transitions)
│   ├── SPEC_v12.0_UPDATE.md      # Previous (v12.0 Unified State Dynamics)
│   ├── SPEC_v11.3_UPDATE.md      # Previous (v11.3 SIE Dynamics)
│   ├── SPEC_v11.2_UPDATE.md      # DAC anti-clipping
│   ├── SPEC_v11.1_UPDATE.md      # Unified Boundary-Attractor
│   ├── SPEC_v11.0_UPDATE.md      # Active φⁿ Dynamics
│   ├── SPEC_v10.5_UPDATE.md      # Quarter-Integer φⁿ Theory
│   ├── SPEC_v10.4_UPDATE.md      # φⁿ Geophysical SR Integration
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

### 21 Hopf Oscillators at φⁿ Frequencies (v12.2: Base = 7.75 Hz)

| Location | Frequency | φⁿ | OMEGA_DT | Purpose |
|----------|-----------|-----|----------|---------|
| Thalamus Theta | 6.09 Hz | φ⁻⁰·⁵ | 157 | Learn/recall gating |
| SR f₀ | 7.75 Hz | — | 199 | Schumann fundamental |
| SR f₁ | 13.75 Hz | — | 354 | Alpha-band coupling |
| SR f₂ | 20 Hz | — | 514 | Low beta coupling |
| SR f₃ | 25 Hz | — | 643 | High beta coupling |
| SR f₄ | 32 Hz | — | 823 | Gamma coupling |
| Cortex L6 ×3 | 9.86 Hz | φ⁰·⁵ | 254 | Alpha, gain control |
| Cortex L5a ×3 | 15.95 Hz | φ¹·⁵ | 410 | Low beta, motor |
| Cortex L5b ×3 | 25.81 Hz | φ²·⁵ | 664 | High beta, feedback |
| Cortex L4 ×3 | 32.83 Hz | φ³ | 845 | Thalamocortical |
| Cortex L2/3 ×3 | 41.76/67.6 Hz | φ³·⁵/φ⁴·⁵ | 1075/1740 | Gamma (switches with theta) |

### SR Frequency-to-EEG-Band Mapping (v12.2: Tightened for Alignment)

| SR Harmonic | Observed Frequency | Drift Range | Coherence Target |
|-------------|-------------------|-------------|------------------|
| f₀ | 7.75 Hz | ±0.5 Hz | theta/alpha boundary |
| f₁ | 13.75 Hz | ±0.8 Hz | alpha (L6) |
| f₂ | 20 Hz | ±1.0 Hz | low_beta (L5a) |
| f₃ | 25 Hz | ±1.5 Hz | high_beta (L5b) |
| f₄ | 32 Hz | ±2.0 Hz | gamma (L4) |

### Consciousness States (state_select[2:0])

| Code | State | Description | Key Changes |
|------|-------|-------------|-------------|
| 0 | NORMAL | Baseline | All MU = 3 (v11.2) |
| 1 | ANESTHESIA | Propofol-like | L6=6 high, L4/L2/3 weak |
| 2 | PSYCHEDELIC | Enhanced binding | L4/L2/3=6 enhanced, L6=1 reduced |
| 3 | FLOW | Motor-optimized | L5a/L5b=6 enhanced |
| 4 | MEDITATION | Theta coherence | θ/L6=6, L5a/L5b/L4=1, L2/3=2 |

**v11.4 State Transitions:** Smooth interpolation via `transition_duration` input (0=instant).

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
| Q_NORM_F0 | 7929 | 0.484 | Q-factor normalization f₀ (v10.4) |
| Q_NORM_F1 | 10051 | 0.613 | Q-factor normalization f₁ (bridging) (v10.4) |
| Q_NORM_F2 | 16384 | 1.0 | Q-factor normalization f₂ (ANCHOR) (v10.4) |
| Q_NORM_F3 | 8995 | 0.549 | Q-factor normalization f₃ (v10.4) |
| Q_NORM_F4 | 7405 | 0.452 | Q-factor normalization f₄ (v10.4) |
| AMP_SCALE_F0 | 16384 | 1.0 | Amplitude scale f₀ (v10.4) |
| AMP_SCALE_F1 | 13926 | 0.85 | Amplitude scale f₁ (bridging) (v10.4) |
| AMP_SCALE_F2 | 5571 | 0.34 | Amplitude scale f₂ ≈ φ⁻² (v10.4) |
| AMP_SCALE_F3 | 2458 | 0.15 | Amplitude scale f₃ ≈ φ⁻⁴ (v10.4) |
| AMP_SCALE_F4 | 983 | 0.06 | Amplitude scale f₄ ≈ φ⁻⁶ (v10.4) |
| SIE_ENHANCE_F0 | 44237 | 2.7× | SIE mode-selective enhancement f₀ (v10.4) |
| SIE_ENHANCE_F1 | 49152 | 3.0× | SIE mode-selective enhancement f₁ (v10.4) |
| SIE_ENHANCE_F2 | 20480 | 1.25× | SIE mode-selective enhancement f₂ (v10.4) |
| SIE_ENHANCE_F3 | 19661 | 1.2× | SIE mode-selective enhancement f₃ (v10.4) |
| SIE_ENHANCE_F4 | 19661 | 1.2× | SIE mode-selective enhancement f₄ (v10.4) |
| PHI_Q14 | 26510 | 1.618 | φ^1.0 golden ratio base (v10.5) |
| PHI_0_25 | 18474 | 1.1276 | φ^0.25 quarter power (v10.5) |
| PHI_0_5 | 20833 | 1.272 | φ^0.5 half power (v10.5) |
| PHI_0_75 | 20935 | 1.2785 | φ^0.75 three-quarter power (v10.5) |
| PHI_1_25 | 29899 | 1.8249 | φ^1.25 f₁ fallback ratio (v10.5) |
| PHI_1_5 | 33718 | 2.058 | φ^1.5 UNSTABLE - 2:1 catastrophe (v10.5) |
| PHI_2_0 | 42891 | 2.618 | φ^2.0 (v10.5) |
| PHI_2_5 | 54569 | 3.330 | φ^2.5 (v10.5) |
| HARMONIC_2_1 | 32768 | 2.0 | 2:1 harmonic ratio (v10.5) |
| OMEGA_DT_F1_THEORY | 356 | 13.84 Hz | Theoretical f₁ at φ^1.25 × f₀ (v10.5) |
| ENABLE_ADAPTIVE | 0/1 | — | v11.0: 0=static, 1=self-organizing |
| K_FORCE | 1638 | 0.1 | Force-to-drift gain (v11.0) |
| FORCE_SCALE_A | 8192 | 0.5 | φ-landscape force amplitude (v11.0) |
| FORCE_SCALE_B | 16384 | 1.0 | Catastrophe repulsion strength (v11.0) |
| CATASTROPHE_N_MIN | 22118 | 1.35 | 2:1 danger zone lower bound (v11.0) |
| CATASTROPHE_N_MAX | 25395 | 1.55 | 2:1 danger zone upper bound (v11.0) |
| SIE_BASE_ENHANCE | 19661 | 1.2× | Dynamic SIE minimum enhancement (v11.0) |
| SIE_K_INSTABILITY | 29491 | 1.8× | SIE instability scaling factor (v11.0) |
| B_Q1 | 820 | 0.05 | Rational force weight q=1 (v11.1b) |
| B_Q2 | 205 | 0.0125 | Rational force weight q=2 (v11.1b) |
| B_Q3 | 91 | 0.0056 | Rational force weight q=3 (v11.1b) |
| EPSILON_SQ | 15 | 0.0009 | Lorentzian regularization (v11.1b) |
| N_3_1_LOW | 36045 | 2.20 | 3:1 catastrophe zone lower (v11.1b) |
| N_3_1_HIGH | 38666 | 2.36 | 3:1 catastrophe zone upper (v11.1b) |
| N_4_1_LOW | 45875 | 2.80 | 4:1 catastrophe zone lower (v11.1b) |
| N_4_1_HIGH | 48497 | 2.96 | 4:1 catastrophe zone upper (v11.1b) |
| K_CATASTROPHE_3_1 | 16384 | 1.0 | 3:1 repulsion strength (v11.1b) |
| K_CATASTROPHE_4_1 | 12288 | 0.75 | 4:1 repulsion strength (v11.1b) |
| ENVELOPE_MIN_THETA | 11469 | 0.7 | Theta envelope lower bound (v11.4) |
| ENVELOPE_MAX_THETA | 21299 | 1.3 | Theta envelope upper bound (v11.4) |
| MU_DIV3 | 5461 | 0.333 | MU amplitude scaling divisor (v11.4) |
| TRANSITION_DURATION | 80000 | 20s | Default state transition cycles (v11.4) |
| SIE_ENHANCE_F0_v12 | 21299 | 1.3× | Distributed f₀ enhancement (v11.5) |
| SIE_ENHANCE_F1_v12 | 19661 | 1.2× | Distributed f₁ enhancement (v11.5) |
| SIE_BOOST_RANGE | 6554 | 0.4 | Mixer boost range 1.0→1.4 (v11.5) |
| KURAMOTO_R_ENTRY | 8192 | 0.5 | HARMONIC mode entry threshold (v1.1) |
| KURAMOTO_R_EXIT | 6554 | 0.4 | HARMONIC mode exit threshold (v1.1) |
| BOUNDARY_THRESH | 4096 | 0.25 | Boundary power threshold (v1.1) |
| GAIN_RAMP_STEP | 7 | 0.0004 | Non-meditation gain step (v1.2b) |
| TRANSITION_GATE_25PCT | 16384 | 25% | State-gated forcing threshold (v1.2) |
| GAIN_LOW | 2048 | 0.125 | Minimum harmonic_gain (v7.20) |
| GAIN_RANGE | 14336 | 0.875 | Gain normalization range (v7.20) |

## Current Specification

See [docs/SPEC/UPDATES/SPEC_v12.2_UPDATE.md](docs/SPEC/UPDATES/SPEC_v12.2_UPDATE.md) for the latest v12.2 architecture with:
- **Dual Alignment Ignition** (v12.2): Internal boundary √(θ×α) = SR1 = 7.75 Hz
- **Alignment-Modulated Threshold** (v1.4): Ignition sensitivity increases when aligned
- **Thalamic Frequency Drift** (v1.0): New theta drift module ±0.5 Hz for alignment
- **Tightened SR Drift** (v2.1): f₀ ±0.5 Hz for impedance matching
- **Per-Layer Cortical Drift** (v3.5): Layer-specific ranges match SR harmonics
- **φⁿ × 7.75 Hz Base** (v12.2): All frequencies derived from SR1 center

Previous architecture features (v12.1):
- **Synchronized Gain Interpolation** (v1.2b): PAC/harmonic gains interpolate with MU during MEDITATION transitions
- **Continuous Gain Blending** (v7.20): Output mixer uses harmonic_gain for artifact-free weight interpolation
- **Debug Outputs** (v7.20): mode_blend, pink_weight, osc_scale signals for transition monitoring
- **Ratio-Based Catastrophe Detection** (v11.2): Escape mechanism pushes oscillators toward φⁿ attractors
- **Overflow Fixes**: 32-bit arithmetic in config_controller and coupling_mode_controller

Previous architecture features (v12.0):
- **State Transition Interpolation** (v11.4): Smooth consciousness state changes over configurable duration
- **Distributed SIE Architecture** (v11.5): Option C distributed boost (6.8 dB total) prevents stacking
- **Parameterized Envelope Bounds** (v11.4): Theta ±30% [0.7,1.3], cortical ±50% [0.5,1.5]
- **MU-Based Amplitude Scaling** (v11.4): State-dependent layer output amplitudes
- **State-Driven Coupling Mode** (v1.1): MEDITATION forces HARMONIC coupling automatically

Previous architecture features (v11.3):
- **Kuramoto Order Parameter** (v11.3): Population synchronization R ∈ [0,1] from 6 oscillators
- **Boundary Generators** (v11.3): Nonlinear mixing creates θ/α (7.75 Hz), α/β₁, β₁/β₂ boundaries
- **Bicoherence Monitor** (v11.3): Detects nonlinear three-frequency interactions
- **Coupling Mode Controller** (v11.3): Automatic modulatory ↔ harmonic mode switching
- **Harmonic Spacing Index** (v11.3): Monitors φⁿ ratio adherence with ΔHSI tracking
- **Spectral Differentiation** (v11.3): MEDITATION state now >3dB different from NORMAL

Previous architecture features (v11.2):
- **DAC Anti-Clipping** (v11.2): MU_MODERATE (3) for NORMAL, soft limiter at ±0.75

Previous architecture features (v11.1):
- **Farey χ(r) Computation** (v11.1a): Systematic formula with 55 rationals + 6 φⁿ boundaries
- **Rational Resonance Forces** (v11.1b): Lorentzian gradient F_rational(n) from p/q ratios
- **Multi-Catastrophe Detection** (v11.1b): 2:1, 3:1, 4:1 zone-based repulsion
- **Phase-Amplitude Coupling** (v11.1c): PAC strength from chi × amplitude for 10 oscillator pairs
- **Key Insight**: φ^1.25 = 1.825 is the MOST STABLE position (chi = 0.126)

Previous architecture features (v11.0):
- **Active φⁿ Dynamics** (v11.0): Self-organizing frequencies via energy landscape and restoring forces
- **Energy Landscape** (v11.0): E(n) = -A×cos(2πn) with attractors at half-integers, repulsion at integers
- **2:1 Harmonic Catastrophe Avoidance** (v11.0): Automatic f₁ retreat from n=1.5 to n=1.25
- **Position Classification** (v11.0): INTEGER_BOUNDARY, HALF_INTEGER, QUARTER_INTEGER, NEAR_CATASTROPHE
- **Dynamic SIE Enhancement** (v11.0): SIE gain computed from stability metric (replaces hardcoded values)
- **ENABLE_ADAPTIVE Parameter** (v11.0): Backward compatible mode switch (0=static, 1=adaptive)

Previous architecture features (v10.x series):
- **Quarter-Integer φⁿ Theory** (v10.5): f₁ explained as φ^1.25 fallback due to 2:1 Harmonic Catastrophe
- **φⁿ Geophysical SR Integration** (v10.4): Q-factor modeling, amplitude hierarchy, mode-selective SIE
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

All testbenches should pass. Key tests (365+ total):
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
- `tb_phi_n_sr_relationships`: 10/10 tests - φⁿ Q-factor and amplitude hierarchy (v10.4)
- `tb_quarter_integer_theory`: 12/12 tests - Quarter-integer fallback validation (v10.5)
- `tb_coupling_susceptibility`: 20/20 tests - Farey χ(r) computation (v11.1a)
- `tb_energy_landscape`: 24/24 tests - Forces + rational resonance (v11.1b)
- `tb_quarter_integer_detector`: 8/8 tests - Position classification (v11.0)
- `tb_self_organization`: 10/10 tests - Full integration validation (v11.0)
- `tb_pac_strength`: 10/10 tests - Phase-amplitude coupling (v11.1c)
- `tb_kuramoto_order`: 7/7 tests - Kuramoto order parameter (v11.3)
- `tb_boundary_generator`: 7/7 tests - Boundary frequency mixing (v11.3)
- `tb_bicoherence_monitor`: 6/6 tests - Bicoherence detection (v11.3)
- `tb_coupling_mode_controller`: 8/8 tests - Mode switching (v11.3)
- `tb_harmonic_spacing_index`: 8/8 tests - φⁿ ratio tracking (v11.3)
- `tb_state_interpolation`: 10/10 tests - state transition interpolation (v11.4)
- `tb_state_transition_spectrogram`: Visual - 100s spectrogram validation (v12.1, 12 debug columns)
- `tb_multi_harmonic_sr`: 17/17 tests - multi-harmonic SR
- `tb_learning_fast`: 8/8 tests - CA3 Hebbian learning (v2.1)
- `tb_sr_coupling`: 12/12 tests - SR coupling
- `tb_v55_fast`: 6/6 tests - fast integration

## Notes

- Compiled `.vvp` and `.vcd` files are gitignored
- CSV output files from testbenches are gitignored
- Python scripts in `scripts/` visualize simulation data
