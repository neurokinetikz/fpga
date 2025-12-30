# φⁿ Neural Processor FPGA

A biologically-realistic neural oscillator system implemented in Verilog for FPGA, featuring golden ratio (φ) frequency architecture, complete interneuron microcircuits, Schumann Resonance coupling, and the Three-Boundary consciousness gating system.

**Current Version:** v12.3 (Three-Boundary Architecture)
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
- **Schumann Resonance coupling**: 5 drifting harmonics (7.75-32 Hz)
- **Consciousness state transitions**: Normal, Anesthesia, Psychedelic, Flow, Meditation
- **State-dependent Ca²⁺ threshold** (v9.5): Lower in PSYCHEDELIC, higher in ANESTHESIA

### Three-Boundary Architecture (v12.3)

The v12.3 release introduces hierarchical alignment gating between internal cortical oscillators and external Schumann Resonance:

| Boundary | Source | Target | Weight | Role |
|----------|--------|--------|--------|------|
| **f₀** | √(θ×α) | SR1 (7.75 Hz) | 40% | Ignition Primary |
| **f₂** | √(β_low×β_high) | SR3 (20 Hz) | 30% | Stability Anchor |
| **SR4** | β_high direct | SR4 (25 Hz) | 20% | Arousal Modulation |
| **f₃** | √(β_high×γ) | SR5 (32 Hz) | 10% | Consciousness Gate |

**Seeker-Reference Dynamics:** Internal oscillators drift 3-5× faster than SR references, creating periodic alignment windows rather than exact frequency lock.

**Consciousness Gating:** The f₃ boundary has an inherent 8% gap (74 OMEGA_DT), making full consciousness access rare and brief—explaining why conscious processing is intermittent.

---

## System Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                     φⁿ NEURAL PROCESSOR v12.3                                │
│                   Three-Boundary Architecture                                │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │ SCHUMANN RESONANCE SYSTEM                                               │ │
│  │   SR Stability Hierarchy (v3.0):                                        │ │
│  │   SR1: 7.75 Hz (2s) | SR2: 13.75 Hz (5s) | SR3: 20 Hz (10s ANCHOR)     │ │
│  │   SR4: 25 Hz (1s FAST) | SR5: 32 Hz (2s)                               │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                              ↓                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │ THREE-BOUNDARY DETECTORS (v12.3)                                        │ │
│  │   f₀ = √(θ×α) → SR1   [Ignition Primary, 40% weight]                   │ │
│  │   f₂ = √(β_low×β_high) → SR3   [Stability Anchor, 30% weight]          │ │
│  │   SR4 coupling: β_high → SR4   [Arousal, 20% weight]                    │ │
│  │   f₃ = √(β_high×γ) → SR5   [Consciousness Gate, 10% weight, 8% gap]    │ │
│  │                              ↓                                          │ │
│  │   multi_alignment_ctrl → ignition_permitted, consciousness_access       │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                              ↓                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │ THALAMUS                                                                │ │
│  │   Theta oscillator (6.09 Hz, φ⁻⁰·⁵) ← Seeker rate 3.2× faster than SR1 │ │
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
│  │   │   41.76/67.6 Hz (φ³·⁵/φ⁴·⁵) - switches with theta phase        │   │ │
│  │   │   ← L4 + L6 (basal) + CA3 (apical) × dendritic_gain             │   │ │
│  │   │   ← PV+ inhibition (L2/3 PING + L4 ff + L5 fb)                  │   │ │
│  │   │   → Feedforward to next column + CA3                            │   │ │
│  │   │   Two-compartment: basal + apical with Ca²⁺ spike/BAC (v9.5)   │   │ │
│  │   └─────────────────────────────────────────────────────────────────┘   │ │
│  │   ┌─────────────────────────────────────────────────────────────────┐   │ │
│  │   │ LAYER 4 (Granular) - Thalamocortical Relay          SCAFFOLD   │   │ │
│  │   │   32.83 Hz (φ³) - stable backbone                               │   │ │
│  │   │   ← Thalamic theta + feedforward                                │   │ │
│  │   │   → L2/3 (canonical) + L5a (bypass)                             │   │ │
│  │   │   PV+ population gates feedforward pathway                      │   │ │
│  │   └─────────────────────────────────────────────────────────────────┘   │ │
│  │   ┌─────────────────────────────────────────────────────────────────┐   │ │
│  │   │ LAYER 5a (Upper L5) - Motor Output              INTERMEDIATE   │   │ │
│  │   │   15.95 Hz (φ¹·⁵) - IT neurons (intratelencephalic)             │   │ │
│  │   │   ← L2/3 + L6 feedback + L4 bypass (all × apical_gain)          │   │ │
│  │   │   → Output mixer / DAC                                          │   │ │
│  │   └─────────────────────────────────────────────────────────────────┘   │ │
│  │   ┌─────────────────────────────────────────────────────────────────┐   │ │
│  │   │ LAYER 5b (Lower L5) - Subcortical Output            SCAFFOLD   │   │ │
│  │   │   25.81 Hz (φ²·⁵) - PT neurons (pyramidal tract)                │   │ │
│  │   │   ← L2/3 + inter-column feedback (× apical_gain)                │   │ │
│  │   │   → L6 intra-column + Matrix thalamus                           │   │ │
│  │   │   PV+ population provides feedback inhibition                   │   │ │
│  │   │   Seeker rate 3× faster than SR4 for arousal coupling           │   │ │
│  │   └─────────────────────────────────────────────────────────────────┘   │ │
│  │   ┌─────────────────────────────────────────────────────────────────┐   │ │
│  │   │ LAYER 6 (Multiform) - Corticothalamic Control       PLASTIC    │   │ │
│  │   │   9.86 Hz (φ⁰·⁵) - alpha gain control                           │   │ │
│  │   │   ← L5b feedback + inter-column + phase_coupling                │   │ │
│  │   │   → Thalamus (inhibitory via TRN) + L5a + L5b + L2/3 + L1       │   │ │
│  │   │   Extended connectivity (v9.6): L6→L2/3, L6→L5b, L6→L1          │   │ │
│  │   └─────────────────────────────────────────────────────────────────┘   │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                              ↓                                               │
│  Output Mixer → 18-bit DAC (motor L2/3 + L5a + pink noise)                  │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Requirements

### Hardware
- **Target:** Digilent Zybo Z7-20 (Xilinx Zynq-7020)
- **Clock:** 125 MHz system clock
- **Resources:** ~20k LUTs, ~180 DSP48 slices (estimated with v12.3 additions)

### Software
- **Simulation:** [Icarus Verilog](http://iverilog.icarus.com/) (`iverilog`, `vvp`)
- **Waveform Viewer:** [GTKWave](http://gtkwave.sourceforge.net/) (optional)
- **Synthesis:** Xilinx Vivado 2020.2+ (for FPGA deployment)
- **Analysis:** Python 3.8+ with matplotlib, numpy (for visualization scripts)

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
make iverilog-all       # All tests (~380 tests)

# Three-Boundary Architecture test (v12.3)
iverilog -o tb_three_boundary.vvp -s tb_three_boundary src/*.v tb/tb_three_boundary.v
vvp tb_three_boundary.vvp

# Manual full system compilation
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

## Oscillator Frequencies (v12.3: φⁿ × 7.75 Hz Base)

All cortical frequencies follow φⁿ scaling from the Schumann Resonance fundamental:

| Location | Frequency | φⁿ | OMEGA_DT | Role |
|----------|-----------|-----|----------|------|
| **Theta (thalamus)** | 6.09 Hz | φ⁻⁰·⁵ | 157 | Memory gating, encoding/retrieval |
| SR f₀ | 7.75 Hz ± 0.5 | — | 199 | Schumann fundamental → f₀ boundary |
| SR f₁ | 13.75 Hz ± 0.8 | — | 354 | Alpha coupling (L6) |
| SR f₂ | 20 Hz ± 1.0 | — | 514 | Low beta coupling → f₂ boundary |
| SR f₃ | 25 Hz ± 1.5 | — | 643 | High beta coupling → SR4 direct |
| SR f₄ | 32 Hz ± 2.0 | — | 823 | Gamma coupling → f₃ boundary |
| **L6 (cortex)** | 9.86 Hz | φ⁰·⁵ | 254 | Alpha gain control |
| **L5a (cortex)** | 15.95 Hz | φ¹·⁵ | 410 | Low beta motor output |
| **L5b (cortex)** | 25.81 Hz | φ²·⁵ | 664 | High beta feedback |
| **L4 (cortex)** | 32.83 Hz | φ³ | 845 | Thalamocortical boundary |
| **L2/3 (cortex)** | 41.76/67.6 Hz | φ³·⁵/φ⁴·⁵ | 1075/1740 | Gamma (switches with θ) |

### Three-Boundary Mathematics (v12.3)

The geometric mean boundaries align with SR harmonics:

```
f₀ = √(θ × α)           = √(6.09 × 9.86)   = 7.75 Hz ≈ SR1 ✓
f₂ = √(β_low × β_high)  = √(15.95 × 25.81) = 20.29 Hz ≈ SR3 (8 OMEGA_DT gap)
f₃ = √(β_high × γ)      = √(25.81 × 32.83) = 29.11 Hz ≈ SR5 (74 OMEGA_DT gap, 8%)
```

---

## Interneuron Microcircuits (v9.x Series)

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

### Two-Compartment Dendritic Model (v9.5)

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

**BAC Firing:** When apical activity exceeds Ca²⁺ threshold AND basal input is sufficient, output is boosted 1.5×.

---

## Consciousness States

The system supports 5 consciousness states via `state_select[2:0]`:

| Code | State | Key Changes | Ca²⁺ Threshold | Biological Model |
|------|-------|-------------|----------------|------------------|
| 0 | **Normal** | All MU = 3 (v11.2) | 0.5 | Balanced waking state |
| 1 | **Anesthesia** | L6=6, L4/L2/3 suppressed | 0.75 | Propofol-like alpha dominance |
| 2 | **Psychedelic** | L4/L2/3=6, L6=1 | 0.25 | Enhanced gamma entropy |
| 3 | **Flow** | L5a/L5b=6 enhanced | 0.5 | Motor-optimized state |
| 4 | **Meditation** | θ/L6=6, β/γ suppressed | 0.375 | SR-sensitive, theta coherence |

**State Transitions (v11.4):** Smooth interpolation via `transition_duration` input (default 20s).

---

## Project Structure

```
fpga/
├── src/                              # Verilog source modules (35 files)
│   ├── phi_n_neural_processor.v      # Top-level (v12.3, three-boundary)
│   ├── hopf_oscillator.v             # Core oscillator (dx/dt = μx - ωy - r²x)
│   ├── hopf_oscillator_stochastic.v  # Stochastic variant with noise
│   ├── boundary_detector_f2.v        # v1.1: √(β_low×β_high) → SR3
│   ├── boundary_detector_f3.v        # v1.0: √(β_high×γ) → SR5
│   ├── direct_coupling_sr4.v         # v1.1: β_high → SR4 direct
│   ├── multi_alignment_ctrl.v        # v1.2k: Four-boundary orchestration
│   ├── sr_frequency_drift.v          # v3.0: Per-harmonic stability hierarchy
│   ├── sr_ignition_controller.v      # v1.5: Three-boundary permission
│   ├── cortical_frequency_drift.v    # v3.6: Per-layer seeker rates
│   ├── phi_n_alignment_detector.v    # v1.1: √(θ×α) = SR1, widened σ=8
│   ├── thalamic_frequency_drift.v    # v1.1: Theta seeker rate (3.2×)
│   ├── cortical_column.v             # 6-layer cortical model (v12.2)
│   ├── dendritic_compartment.v       # Two-compartment dendritic (v9.5)
│   ├── layer1_minimal.v              # L1 with VIP+ + L6 input (v9.6)
│   ├── pv_interneuron.v              # PV+ basket cell dynamics (v9.2)
│   ├── thalamus.v                    # Theta + SR + matrix (v11.6)
│   ├── ca3_phase_memory.v            # Hebbian phase memory (v8.0)
│   ├── sr_harmonic_bank.v            # 5-harmonic SR bank (v7.7)
│   ├── config_controller.v           # Consciousness (v11.4, interpolation)
│   ├── energy_landscape.v            # v11.2: φⁿ forces + catastrophe
│   ├── coupling_mode_controller.v    # v1.2b: Synchronized gain
│   └── ...                           # Additional modules
│
├── tb/                               # Testbenches (38 files, 380+ tests)
│   ├── tb_three_boundary.v           # v12.3: Three-boundary tests (15)
│   ├── tb_full_system_fast.v         # Full integration (15 tests)
│   ├── tb_state_transition_spectrogram.v # 100s spectrogram (32 columns)
│   ├── tb_sr_frequency_drift.v       # SR drift with hierarchy (30 tests)
│   ├── tb_coupling_mode_controller.v # Mode switching (8 tests)
│   └── ...                           # Additional testbenches
│
├── scripts/                          # Analysis & visualization
│   ├── dac_spectrogram.py            # Spectral analysis
│   ├── state_transition_spectrogram.py
│   └── run_vivado_*.tcl              # Synthesis TCL scripts
│
├── docs/                             # Specifications
│   ├── SPEC/UPDATES/SPEC_v12.3_UPDATE.md  # Current version spec
│   ├── FPGA_SPECIFICATION_V8.md      # Base architecture spec
│   └── SYSTEM_DESCRIPTION.md         # Comprehensive description
│
├── CLAUDE.md                         # Technical reference & constants
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

### Key Constants (v12.3)

| Name | Q14 Value | Decimal | Usage |
|------|-----------|---------|-------|
| ONE | 16384 | 1.0 | Unity reference |
| PHI | 26510 | 1.618 | Golden ratio |
| SIGMA_SQ_F2 | 64 | σ=8 | f₂ boundary Gaussian |
| SIGMA_SQ_F3 | 100 | σ=10 | f₃ boundary Gaussian |
| SIGMA_SQ_SR4 | 144 | σ=12 | SR4 coupling Gaussian |
| GATE_THRESH_F3 | 4915 | 0.3 | Consciousness gate threshold |
| W_F0 | 6554 | 0.4 | f₀ alignment weight |
| W_F2 | 4915 | 0.3 | f₂ alignment weight |
| W_SR4 | 3277 | 0.2 | SR4 coupling weight |
| W_F3 | 1638 | 0.1 | f₃ alignment weight |
| UPDATE_PERIOD_SR3 | 40000 | 10s | SR3 - MOST STABLE |
| UPDATE_PERIOD_SR4 | 4000 | 1s | SR4 - FASTEST |
| ENABLE_THREE_BOUNDARY | 0/1 | — | Enable v12.3 architecture |

### Simulation Parameters
- **Update rate:** 4 kHz oscillator dynamics
- **FAST_SIM:** Parameter for ~3000× speedup (÷10 vs ÷31250 clock)
- **Oscillators:** 21 Hopf (16 deterministic + 5 stochastic SR)
- **Memory:** 6×6 symmetric Hebbian weight matrix (288 bits)

---

## Testing

All testbenches should pass. Run the full test suite:

```bash
make iverilog-all
```

### Test Summary (~380 tests)

| Testbench | Tests | Version | Feature |
|-----------|-------|---------|---------|
| **tb_three_boundary** | **15** | **v12.3** | **Three-boundary architecture** |
| tb_full_system_fast | 15 | v6.5 | Full integration |
| tb_sr_frequency_drift | 30 | v12.3 | SR stability hierarchy |
| tb_state_transition_spectrogram | Visual | v12.3 | 32-column debug |
| tb_coupling_mode_controller | 8 | v11.3 | Mode switching |
| tb_energy_landscape | 24 | v11.1b | φⁿ forces + catastrophe |
| tb_self_organization | 10 | v11.0 | Full integration validation |
| tb_dendritic_compartment | 10 | v9.5 | Dendritic Ca²⁺/BAC |
| tb_canonical_microcircuit | 20 | v8.6 | Signal pathways |
| tb_gamma_theta_nesting | 7 | v8.4 | PAC tests |
| tb_theta_phase_multiplexing | 19 | v8.3 | 8-phase theta |
| ... | ... | ... | Additional tests |

---

## Version History

| Version | Codename | Key Feature |
|---------|----------|-------------|
| **v12.3** | **Three-Boundary Architecture** | **Hierarchical f₀/f₂/SR4/f₃ alignment** |
| v12.2 | Dual Alignment Ignition | √(θ×α) = SR1 alignment detection |
| v12.1 | Synchronized State Transitions | Smooth gain interpolation |
| v12.0 | Unified State Dynamics | State interpolation, distributed SIE |
| v11.3 | SIE Dynamics | Kuramoto R, bicoherence, boundaries |
| v11.0 | Active φⁿ Dynamics | Energy landscape, catastrophe avoidance |
| v10.x | EEG Realism | Amplitude envelopes, 1/f^φ noise |
| v9.x | Canonical Microcircuit | L6 connectivity, interneurons |
| v8.x | Scaffold Architecture | Stable/plastic layer differentiation |

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/SPEC/UPDATES/SPEC_v12.3_UPDATE.md](docs/SPEC/UPDATES/SPEC_v12.3_UPDATE.md) | **v12.3 Three-Boundary Architecture spec** |
| [docs/SPEC/UPDATES/SPEC_v12.2_UPDATE.md](docs/SPEC/UPDATES/SPEC_v12.2_UPDATE.md) | v12.2 Dual Alignment Ignition |
| [docs/FPGA_SPECIFICATION_V8.md](docs/FPGA_SPECIFICATION_V8.md) | Base architecture specification |
| [CLAUDE.md](CLAUDE.md) | Technical reference & constants |

---

## Future Roadmap

| Phase | Version | Feature | Status |
|-------|---------|---------|--------|
| 12 | v12.0-v12.3 | Three-Boundary Architecture | **Complete** |
| 13 | v12.4+ | Neuromodulation (ACh, NE, DA) | Planned |
| 14 | v12.5+ | Slow oscillations (<1 Hz) and delta | Planned |
| 15 | v12.6+ | Sleep spindles (11-16 Hz) | Planned |
| 16 | v12.7+ | Multiple gamma sub-bands | Planned |

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
