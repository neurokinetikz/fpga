# φⁿ Neural Processor

A biologically-realistic neural oscillator system implemented in Verilog for FPGA, featuring golden ratio (φ) frequency architecture, complete interneuron microcircuits, and Schumann Resonance coupling.

**Current Version:** v10.3 (1/f^φ Spectral Slope)
**Target Platform:** Digilent Zybo Z7-20 (Xilinx Zynq-7020)

---

## Overview

This project implements a comprehensive thalamo-cortical neural architecture with **21 coupled Hopf oscillators** operating at frequencies scaled by powers of the golden ratio (φ ≈ 1.618). The system models biologically realistic neural dynamics including:

### Core Architecture
- **Thalamic relay** with theta-gated sensory processing and 8-phase multiplexing
- **Multi-layer cortical columns** (L1, L2/3, L4, L5a, L5b, L6) with canonical microcircuit connectivity
- **Dual thalamic pathways**: Core (sensory relay to L4) and Matrix (L5b→L1 diffuse broadcast)
- **Hebbian phase memory** in CA3-inspired circuit with theta-gated learning
- **Two-compartment dendritic model** (v9.5): Basal/apical separation with Ca²⁺ spike dynamics and BAC firing
- **Extended L6 connectivity** (v9.6): L6→L2/3, L6→L5b, L6→L1 modulatory pathways

### Interneuron Microcircuits (v9.x)
- **PV+ basket cells**: Fast perisomatic inhibition, PING gamma mechanism (τ=5ms)
- **SST+ Martinotti cells**: Slow dendritic inhibition, GABA-B kinetics (τ=25ms)
- **VIP+ interneurons**: Disinhibitory circuit for attention gating (τ=50ms)
- **Cross-layer PV+ network**: L4 feedforward gating + L5 feedback inhibition

### Oscillatory Dynamics
- **Gamma-theta nesting**: L2/3 switches 65/40 Hz based on theta phase
- **Spectrolaminar organization**: Gamma superficial, alpha/beta deep
- **Schumann Resonance coupling**: 5 drifting harmonics (7.6-32 Hz)
- **Consciousness state transitions**: Normal, Anesthesia, Psychedelic, Flow, Meditation
- **State-dependent Ca²⁺ threshold** (v9.5): Lower in PSYCHEDELIC (more Ca²⁺ spikes), higher in ANESTHESIA

---

## System Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                     φⁿ NEURAL PROCESSOR v9.6                                 │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │ SCHUMANN RESONANCE SYSTEM                                               │ │
│  │   SR Frequency Drift (bounded random walk) → SR Harmonic Bank (f₀-f₄)   │ │
│  │   5 stochastic oscillators: 7.6, 13.75, 20, 25, 32 Hz                   │ │
│  │   Per-harmonic coherence detection → Continuous gain modulation         │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                              ↓                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │ THALAMUS                                                                │ │
│  │   Theta oscillator (5.89 Hz) ← SR entrainment when β quiet             │ │
│  │   8-phase multiplexing (encoding phases 0-3, retrieval phases 4-7)      │ │
│  │   Core pathway → L4    |    Matrix pathway (L5b avg) → L1              │ │
│  │   L6 CT inhibition via TRN amplification                                │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                    ↓ theta_phase, encoding_window                            │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │ CA3 PHASE MEMORY (Hebbian learning, theta-gated)                        │ │
│  │   pattern_in[6] → symmetric weights[6×6] → phase_pattern[6]             │ │
│  │   Learn at theta peak | Recall at theta trough                          │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                    ↓ phase_coupling to plastic layers                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │ CORTICAL COLUMNS ×3 (Sensory → Association → Motor)                     │ │
│  │                                                                         │ │
│  │   ┌─────────────────────────────────────────────────────────────────┐   │ │
│  │   │ LAYER 1 (Molecular) - Modulatory Integration Zone              │   │ │
│  │   │   Matrix thalamic input + Dual cortico-cortical feedback + L6   │   │ │
│  │   │   SST+ slow dynamics (τ=25ms) → VIP+ disinhibition (τ=50ms)    │   │ │
│  │   │   Output: apical_gain [0.25, 2.0] → modulates dendritic Ca²⁺   │   │ │
│  │   └─────────────────────────────────────────────────────────────────┘   │ │
│  │   ┌─────────────────────────────────────────────────────────────────┐   │ │
│  │   │ LAYER 2/3 (Supragranular) - Feedforward Gamma Engine    PLASTIC│   │ │
│  │   │   40.36/65.3 Hz (φ³·⁵/φ⁴·⁵) - switches with theta phase        │   │ │
│  │   │   ← L4 + L6 (basal) + CA3 (apical) × dendritic_gain             │   │ │
│  │   │   ← PV+ inhibition (L2/3 PING + L4 ff + L5 fb)                  │   │ │
│  │   │   → Feedforward to next column + CA3                            │   │ │
│  │   │   Two-compartment: basal + apical with Ca²⁺ spike/BAC (v9.5)   │   │ │
│  │   └─────────────────────────────────────────────────────────────────┘   │ │
│  │   ┌─────────────────────────────────────────────────────────────────┐   │ │
│  │   │ LAYER 4 (Granular) - Thalamocortical Relay          SCAFFOLD   │   │ │
│  │   │   31.73 Hz (φ³) - stable backbone                               │   │ │
│  │   │   ← Thalamic theta + feedforward                                │   │ │
│  │   │   → L2/3 (canonical) + L5a (bypass)                             │   │ │
│  │   │   PV+ population gates feedforward pathway                      │   │ │
│  │   └─────────────────────────────────────────────────────────────────┘   │ │
│  │   ┌─────────────────────────────────────────────────────────────────┐   │ │
│  │   │ LAYER 5a (Upper L5) - Motor Output              INTERMEDIATE   │   │ │
│  │   │   15.42 Hz (φ¹·⁵) - IT neurons (intratelencephalic)             │   │ │
│  │   │   ← L2/3 + L6 feedback + L4 bypass (all × apical_gain)          │   │ │
│  │   │   → Output mixer / DAC                                          │   │ │
│  │   └─────────────────────────────────────────────────────────────────┘   │ │
│  │   ┌─────────────────────────────────────────────────────────────────┐   │ │
│  │   │ LAYER 5b (Lower L5) - Subcortical Output            SCAFFOLD   │   │ │
│  │   │   24.94 Hz (φ²·⁵) - PT neurons (pyramidal tract)                │   │ │
│  │   │   ← L2/3 + inter-column feedback (× apical_gain)                │   │ │
│  │   │   → L6 intra-column + Matrix thalamus                           │   │ │
│  │   │   PV+ population provides feedback inhibition                   │   │ │
│  │   └─────────────────────────────────────────────────────────────────┘   │ │
│  │   ┌─────────────────────────────────────────────────────────────────┐   │ │
│  │   │ LAYER 6 (Multiform) - Corticothalamic Control       PLASTIC    │   │ │
│  │   │   9.53 Hz (φ⁰·⁵) - alpha gain control                           │   │ │
│  │   │   ← L5b feedback + inter-column + phase_coupling                │   │ │
│  │   │   → Thalamus (inhibitory via TRN) + L5a + L5b + L2/3 + L1       │   │ │
│  │   │   Extended connectivity (v9.6): L6→L2/3, L6→L5b, L6→L1          │   │ │
│  │   └─────────────────────────────────────────────────────────────────┘   │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                              ↓                                               │
│  Output Mixer → 12-bit DAC (motor L2/3 + L5a + pink noise)                  │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Requirements

### Hardware
- **Target:** Digilent Zybo Z7-20 (Xilinx Zynq-7020)
- **Clock:** 125 MHz system clock
- **Resources:** ~18k LUTs, ~160 DSP48 slices (estimated)

### Software
- **Simulation:** [Icarus Verilog](http://iverilog.icarus.com/) (`iverilog`, `vvp`)
- **Waveform Viewer:** [GTKWave](http://gtkwave.sourceforge.net/) (optional)
- **Synthesis:** Xilinx Vivado 2023.x or later (for FPGA deployment)
- **Analysis:** Python 3 with matplotlib (for visualization scripts)

---

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
make iverilog-fast      # Fast CA3/theta test (6 tests)
make iverilog-full      # Full system test (15 tests)
make iverilog-all       # All tests (~220 tests)

# Manual compilation (full system)
iverilog -o tb_full_system_fast.vvp -s tb_full_system_fast \
    src/clock_enable_generator.v src/hopf_oscillator.v src/hopf_oscillator_stochastic.v \
    src/ca3_phase_memory.v src/thalamus.v src/pv_interneuron.v src/cortical_column.v \
    src/config_controller.v src/pink_noise_generator.v src/output_mixer.v \
    src/phi_n_neural_processor.v src/sr_harmonic_bank.v src/sr_noise_generator.v \
    src/sr_frequency_drift.v src/layer1_minimal.v tb/tb_full_system_fast.v
vvp tb_full_system_fast.vvp
```

### View Waveforms

```bash
make wave-fast          # Opens GTKWave with fast test waveform
# Or manually:
gtkwave tb_full_system_fast.vcd
```

---

## Oscillator Frequencies

All cortical frequencies follow φⁿ scaling. SR harmonics use observed frequencies:

| Location | Frequency | φⁿ | OMEGA_DT | Role |
|----------|-----------|-----|----------|------|
| **Theta (thalamus)** | 5.89 Hz | φ⁻⁰·⁵ | 152 | Memory gating, encoding/retrieval |
| SR f₀ | 7.6 Hz ± 0.6 | — | 196 | Schumann fundamental → theta |
| SR f₁ | 13.75 Hz ± 0.75 | — | 354 | Alpha coupling (L6) |
| SR f₂ | 20 Hz ± 1 | — | 514 | Low beta coupling (L5a) |
| SR f₃ | 25 Hz ± 1.5 | — | 643 | High beta coupling (L5b) |
| SR f₄ | 32 Hz ± 2 | — | 823 | Gamma coupling (L4) |
| **L6 (cortex)** | 9.53 Hz | φ⁰·⁵ | 245 | Alpha gain control |
| **L5a (cortex)** | 15.42 Hz | φ¹·⁵ | 397 | Low beta motor output |
| **L5b (cortex)** | 24.94 Hz | φ²·⁵ | 642 | High beta feedback |
| **L4 (cortex)** | 31.73 Hz | φ³ | 817 | Thalamocortical boundary |
| **L2/3 (cortex)** | 40.36/65.3 Hz | φ³·⁵/φ⁴·⁵ | 1040/1681 | Gamma (switches with θ) |

---

## Interneuron Microcircuits (v9.x Series)

The v9.x series implements biologically realistic interneuron dynamics:

### Three Interneuron Classes

| Class | Location | Target | Time Constant | Function |
|-------|----------|--------|---------------|----------|
| **PV+ (basket)** | L2/3, L4, L5 | Soma/proximal | 5ms | Fast perisomatic inhibition, PING |
| **SST+ (Martinotti)** | L1 | Distal dendrites | 25ms | Slow dendritic inhibition, GABA-B |
| **VIP+** | L1 | SST+ cells | 50ms | Disinhibition, attention gating |

### VIP→SST→Pyramid Disinhibitory Circuit (v9.4)

```
Attention Signal ──▶ VIP+ ──┤ (inhibits)
                            │
                            ▼
Matrix + Feedback ──▶ SST+ ──┤ (inhibits)
                             │
                             ▼
                      Pyramidal Dendrite ──▶ Gain Modulation [0.5, 1.5]
```

When VIP+ is active: VIP+ inhibits SST+ → SST+ inhibition decreases → Pyramidal gain increases (disinhibition)

### Two-Compartment Dendritic Model (v9.5)

Each pyramidal cell (L2/3, L5a, L5b) has separate basal and apical compartments:

```
                        ┌─────────────────────────┐
  apical_input ───────▶ │ APICAL COMPARTMENT      │
  (CA3/top-down)        │   Ca²⁺ spike detector   │──▶ ca_spike
                        │   threshold varies by   │
  apical_gain ─────────▶│   consciousness state   │
  (from L1)             └──────────┬──────────────┘
                                   │
                        ┌──────────▼──────────────┐
  basal_input ────────▶ │ BASAL COMPARTMENT       │
  (L4/L6/local)         │   + K_APICAL × apical   │──▶ dendritic_out
                        │   × BAC boost if Ca²⁺   │
                        └─────────────────────────┘
```

**BAC (Backpropagating Action Potential-Activated Ca²⁺) Firing:**
When apical activity exceeds the Ca²⁺ threshold AND basal input is sufficient, the dendritic output is boosted by K_BAC (1.5×). This implements associative computation: top-down context (apical) gates bottom-up input (basal).

### Cross-Layer PV+ Network (v9.3)

L2/3 receives combined inhibition from three PV+ populations:
- **pv_l23** (local PING): 1.0× weight - creates E-I gamma oscillation
- **pv_l4** (feedforward): 0.5× weight - gates L4→L2/3 pathway
- **pv_l5** (feedback): 0.25× weight - provides top-down control

---

## Consciousness States

The system supports 5 consciousness states via `state_select[2:0]`:

| Code | State | Key Changes | Ca²⁺ Threshold | Biological Model |
|------|-------|-------------|----------------|------------------|
| 0 | **Normal** | All MU = 4 | 0.5 | Balanced waking state |
| 1 | **Anesthesia** | L6 high, L4/L2/3 suppressed | 0.75 | Propofol-like alpha dominance |
| 2 | **Psychedelic** | L4/L2/3 enhanced, L6 reduced | 0.25 | Enhanced gamma entropy |
| 3 | **Flow** | L5a/L5b enhanced | 0.5 | Motor-optimized state |
| 4 | **Meditation** | Beta reduced, theta coherent | 0.5 | SR-sensitive, theta coherence |

**State-Dependent Ca²⁺ Dynamics (v9.5):** The dendritic Ca²⁺ spike threshold varies by state. Lower thresholds in PSYCHEDELIC produce more Ca²⁺ spikes and BAC firing, enabling enhanced associative processing. Higher thresholds in ANESTHESIA suppress Ca²⁺ spikes, reducing consciousness.

---

## Scaffold vs Plastic Architecture

Based on Dupret et al. 2025 findings:

| Layer | Type | Phase Coupling | Behavior |
|-------|------|----------------|----------|
| L4 | **Scaffold** | No | Stable thalamocortical boundary |
| L5b | **Scaffold** | No | Maintains state, PT neurons |
| L2/3 | **Plastic** | Yes | Integrates new patterns, gamma |
| L6 | **Plastic** | Yes | Memory-dependent attention |
| L5a | Intermediate | No | Motor output adaptation |
| L1 | Modulator | — | Top-down gain control |

---

## Project Structure

```
fpga/
├── src/                              # Verilog source modules (16 files)
│   ├── phi_n_neural_processor.v      # Top-level (v9.6, 21 oscillators + dendritic)
│   ├── hopf_oscillator.v             # Core oscillator (dx/dt = μx - ωy - r²x)
│   ├── hopf_oscillator_stochastic.v  # Stochastic variant with noise
│   ├── cortical_column.v             # 6-layer cortical model (v9.6, extended L6)
│   ├── dendritic_compartment.v       # Two-compartment dendritic model (v9.5)
│   ├── layer1_minimal.v              # L1 with VIP+ + L6 input (v9.6)
│   ├── pv_interneuron.v              # PV+ basket cell dynamics (v9.2)
│   ├── thalamus.v                    # Theta + SR + matrix + L6 inhib (v8.8)
│   ├── ca3_phase_memory.v            # Hebbian phase memory (v8.0)
│   ├── sr_harmonic_bank.v            # 5-harmonic SR bank (v7.4)
│   ├── sr_noise_generator.v          # Per-harmonic stochastic noise
│   ├── sr_frequency_drift.v          # Realistic SR frequency drift (v8.5)
│   ├── config_controller.v           # Consciousness states (v9.5, state-dependent Ca²⁺)
│   ├── clock_enable_generator.v      # FAST_SIM-aware 4kHz clock
│   ├── pink_noise_generator.v        # 1/f^φ noise (v7.2, √Fibonacci-weighted)
│   └── output_mixer.v                # DAC output mixing
│
├── tb/                               # Testbenches (33 files, 230+ tests)
│   ├── tb_full_system_fast.v         # Full integration (15 tests)
│   ├── tb_l6_extended.v              # Extended L6 connectivity (10 tests) - v9.6
│   ├── tb_dendritic_compartment.v    # Dendritic Ca²⁺/BAC (10 tests) - v9.5
│   ├── tb_vip_disinhibition.v        # VIP+ tests (8 tests) - v9.4
│   ├── tb_pv_crosslayer.v            # Cross-layer PV+ (8 tests) - v9.3
│   ├── tb_pv_feedback.v              # PING network (8 tests) - v9.2
│   ├── tb_sst_dynamics.v             # SST+ slow dynamics (8 tests) - v9.1
│   ├── tb_pv_minimal.v               # PV+ baseline (6 tests) - v9.0
│   ├── tb_l6_connectivity.v          # L6 output targets (10 tests) - v8.8
│   ├── tb_layer1_minimal.v           # L1 gain modulation (10 tests) - v8.7
│   ├── tb_canonical_microcircuit.v   # Pathway tests (20 tests) - v8.6
│   ├── tb_sr_frequency_drift.v       # SR drift (30 tests) - v8.5
│   ├── tb_gamma_theta_nesting.v      # PAC tests (7 tests) - v8.4
│   ├── tb_theta_phase_multiplexing.v # Theta phase (19 tests) - v8.3
│   ├── tb_scaffold_architecture.v    # Scaffold layers (14 tests) - v8.0
│   ├── tb_multi_harmonic_sr.v        # Multi-harmonic SR (17 tests)
│   ├── tb_learning_fast.v            # CA3 Hebbian (8 tests)
│   ├── tb_sr_coupling.v              # SR coupling (12 tests)
│   ├── tb_v55_fast.v                 # Fast integration (6 tests)
│   └── ...                           # Additional testbenches
│
├── scripts/                          # Analysis & visualization
│   ├── visualize_*.py                # Python plotting scripts
│   └── run_vivado_*.tcl              # Synthesis TCL scripts
│
├── docs/                             # Specifications
│   ├── FPGA_SPECIFICATION_V8.md      # Base architecture spec
│   ├── SPEC_v9.6_UPDATE.md           # Latest version (extended L6 connectivity)
│   ├── SPEC_v9.5_UPDATE.md           # Two-compartment dendritic model
│   ├── SPEC_v9.4_UPDATE.md           # VIP+ disinhibition
│   ├── SPEC_v9.3_UPDATE.md           # Cross-layer PV+
│   └── SYSTEM_DESCRIPTION.md         # Comprehensive system description
│
├── CLAUDE.md                         # Development workflow & quick reference
├── Makefile                          # Build targets
└── README.md                         # This file
```

---

## Technical Details

### Fixed-Point Format: Q4.14
- **Width:** 18-bit signed integers
- **Fractional bits:** 14
- **Range:** [-8.0, +7.99994]
- **Unity (1.0):** 16384

### Key Constants

| Name | Q14 Value | Decimal | Usage |
|------|-----------|---------|-------|
| ONE | 16384 | 1.0 | Unity reference |
| K_PHASE | 4096 | 0.25 | Phase coupling strength |
| SST_ALPHA | 164 | 0.01 | SST+ time constant (τ=25ms) |
| VIP_ALPHA | 82 | 0.005 | VIP+ time constant (τ=50ms) |
| TAU_INV | 819 | 0.05 | PV+ time constant (τ=5ms) |
| K_EXCITE | 8192 | 0.5 | PV+ pyramid excitation |
| K_INHIB | 4915 | 0.3 | PV+ inhibition weight |
| K_VIP | 8192 | 0.5 | VIP+ attention scaling |
| GAIN_MIN | 4096 | 0.25 | L1 minimum apical gain (v9.6) |
| GAIN_MAX | 32768 | 2.0 | L1 maximum apical gain (v9.6) |
| K_APICAL | 4096 | 0.25 | Apical contribution weight (v9.5) |
| K_BAC | 24576 | 1.5 | BAC supralinear boost (v9.5) |
| CA_THRESH_NORMAL | 8192 | 0.5 | Ca²⁺ threshold in NORMAL state |
| CA_THRESH_PSYCHEDELIC | 4096 | 0.25 | Ca²⁺ threshold in PSYCHEDELIC |
| K_L6_L23 | 2458 | 0.15 | L6 → L2/3 coupling (v9.6) |
| K_L6_L5B | 1638 | 0.1 | L6 → L5b coupling (v9.6) |
| K_L6_L1 | 1638 | 0.1 | L6 → L1 coupling (v9.6) |

### Simulation Parameters
- **Update rate:** 4 kHz oscillator dynamics
- **FAST_SIM:** Parameter for ~3000× speedup (÷10 vs ÷31250 clock)
- **Oscillators:** 21 Hopf (16 deterministic + 5 stochastic SR)
- **Memory:** 6×6 symmetric Hebbian weight matrix (288 bits)

---

## Version History

| Version | Date | Key Features |
|---------|------|--------------|
| **v10.3** | 2025-12-27 | 1/f^φ Spectral Slope: √Fibonacci-weighted pink noise (v7.2) |
| v10.2 | 2025-12-27 | Spectral broadening: ±0.5 Hz fast jitter for ~1-2 Hz wide peaks |
| v10.1 | 2025-12-27 | Envelope integration: per-band envelopes wired to output mixer |
| v10.0 | 2025-12-27 | EEG Realism: amplitude envelopes, slow drift, SIE controller |
| v9.6 | 2025-12-27 | Extended L6 connectivity (L6→L2/3, L6→L5b, L6→L1) |
| v9.5 | 2025-12-27 | Two-compartment dendritic model, Ca²⁺ spikes, BAC firing |
| v9.4 | 2025-12-27 | VIP+ disinhibition for attention gating |
| v9.3 | 2025-12-27 | Cross-layer PV+ network (L4, L5 populations) |
| v9.2 | 2025-12-27 | PV+ PING network with dynamic E-I loop |
| v9.1 | 2025-12-27 | SST+ explicit slow dynamics (IIR filter) |
| v9.0 | 2025-12-27 | PV+ minimal amplitude-proportional inhibition |
| v8.8 | 2025-12-27 | L6 output connectivity (L6→L5a, L6→Thalamus+TRN) |
| v8.7 | 2025-12-26 | Layer 1 gain modulation, matrix thalamic pathway |
| v8.6 | 2025-12-26 | Canonical microcircuit (L4→L2/3→L5→L6) |
| v8.5 | 2025-12-26 | SR frequency drift (bounded random walk) |
| v8.4 | 2025-12-25 | Gamma-theta nesting |
| v8.3 | 2025-12-25 | Theta phase multiplexing (8 phases) |
| v8.0 | 2025-12-24 | Scaffold architecture (Dupret et al. 2025) |
| v7.4 | 2025-12-23 | Continuous coherence-based SR gain |
| v7.3 | 2025-12-22 | Multi-harmonic SR bank (5 harmonics) |

---

## Testing

All testbenches should pass. Run the full test suite:

```bash
make iverilog-all
```

### Test Summary (~230 tests)

| Testbench | Tests | Version | Feature |
|-----------|-------|---------|---------|
| tb_full_system_fast | 15 | v6.5 | Full integration |
| tb_l6_extended | 10 | v9.6 | Extended L6 connectivity |
| tb_dendritic_compartment | 10 | v9.5 | Dendritic Ca²⁺/BAC |
| tb_vip_disinhibition | 8 | v9.4 | VIP+ attention gating |
| tb_pv_crosslayer | 8 | v9.3 | Cross-layer PV+ |
| tb_pv_feedback | 8 | v9.2 | PING network dynamics |
| tb_sst_dynamics | 8 | v9.1 | SST+ slow dynamics |
| tb_pv_minimal | 6 | v9.0 | PV+ basket cell |
| tb_l6_connectivity | 10 | v8.8 | L6 output targets |
| tb_layer1_minimal | 10 | v8.7 | L1 gain modulation |
| tb_canonical_microcircuit | 20 | v8.6 | Signal pathways |
| tb_sr_frequency_drift | 30 | v8.5 | SR drift |
| tb_gamma_theta_nesting | 7 | v8.4 | PAC tests |
| tb_theta_phase_multiplexing | 19 | v8.3 | 8-phase theta |
| tb_scaffold_architecture | 14 | v8.0 | Scaffold layers |
| tb_multi_harmonic_sr | 17 | v7.3 | Multi-harmonic SR |
| tb_learning_fast | 8 | v2.1 | CA3 Hebbian |
| tb_sr_coupling | 12 | v7.2 | SR coupling |
| tb_v55_fast | 6 | v5.5 | Fast integration |

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/SPEC_v9.6_UPDATE.md](docs/SPEC_v9.6_UPDATE.md) | Latest v9.6 extended L6 connectivity spec |
| [docs/SPEC_v9.5_UPDATE.md](docs/SPEC_v9.5_UPDATE.md) | Two-compartment dendritic model spec |
| [docs/FPGA_SPECIFICATION_V8.md](docs/FPGA_SPECIFICATION_V8.md) | Base architecture specification |
| [docs/SYSTEM_DESCRIPTION.md](docs/SYSTEM_DESCRIPTION.md) | Comprehensive system description |
| [CLAUDE.md](CLAUDE.md) | Development workflow & quick reference |

---

## Future Roadmap

| Phase | Version | Feature |
|-------|---------|---------|
| 10 | v9.7+ | Neuromodulation (ACh, NE, DA) |
| 11 | v9.8+ | Slow oscillations (<1 Hz) and delta |
| 12 | v9.9+ | Sleep spindles (11-16 Hz) |
| 13 | v9.10+ | Multiple gamma sub-bands |
| 14 | v9.11+ | Synaptic realism (lognormal weights) |

---

## License

Copyright (c) 2024-2025 Neurokinetikz

---

## References

- Hopf bifurcation oscillators for neural modeling
- Golden ratio frequency relationships in neural oscillations
- Schumann Resonance and brain-earth coupling hypotheses
- Theta-gamma phase-amplitude coupling in hippocampus
- Dupret et al. 2025: Scaffold vs plastic neural populations
- Douglas & Martin: Canonical cortical microcircuit
- PV/SST/VIP interneuron classification and function
- Larkum (2013): A cellular mechanism for cortical associations (BAC firing)
- Thomson (2010): Neocortical layer 6 (L6 connectivity)
