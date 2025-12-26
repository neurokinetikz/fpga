# φⁿ Neural Processor - Comprehensive System Description

**Version:** 8.7
**Date:** 2025-12-26
**Based on:** Complete analysis of all 14 source modules (~3,200 lines of Verilog)

---

## Executive Summary

The φⁿ Neural Processor is an FPGA implementation of 21 coupled nonlinear oscillators organized as a thalamo-cortical network. The system models biological neural rhythms using golden ratio (φ ≈ 1.618) frequency relationships, implements associative memory through theta-gated Hebbian learning, and exhibits stochastic resonance sensitivity to weak external electromagnetic fields. Version 8.7 implements Layer 1 (molecular layer) with matrix thalamic input for top-down gain modulation, completing the 6-layer spectrolaminar cortical architecture.

---

## 1. Core Oscillator Engine

### Hopf Normal Form (hopf_oscillator.v, v6.0)

Each oscillator implements the Hopf bifurcation equations in Q4.14 fixed-point:

```
dx/dt = μx - ωy - r²x + input_x
dy/dt = μy + ωx - r²y
```

**Key Implementation Details:**
- **Format**: 18-bit signed, 14 fractional bits (range: -8.0 to +7.99994)
- **Update Rate**: 4 kHz (dt = 0.00025s, DT = 4 in Q14)
- **Amplitude Stabilization**: When r² > 1.0625 (threshold), applies correction factor to prevent Euler integration runaway
- **Fast Startup**: Initialized at x = 0.5 (8192 in Q14) for immediate oscillation

**Stochastic Variant** (hopf_oscillator_stochastic.v):
- Adds `noise_x` input to dx term
- Enables true stochastic resonance behavior in SR bank

---

## 2. Frequency Architecture

All 21 oscillators follow structured frequency relationships:

### 2.1 Cortical Oscillators (φⁿ Scaling)

| Location | Count | Frequency | φⁿ Exponent | OMEGA_DT (Q14) | Role |
|----------|-------|-----------|-------------|----------------|------|
| Thalamus Theta | 1 | 5.89 Hz | φ⁻⁰·⁵ | 152 | Memory gating |
| Cortex L6 | 3 | 9.53 Hz | φ⁰·⁵ | 245 | Alpha gain control |
| Cortex L5a | 3 | 15.42 Hz | φ¹·⁵ | 397 | Low beta motor |
| Cortex L5b | 3 | 24.94 Hz | φ²·⁵ | 642 | High beta feedback |
| Cortex L4 | 3 | 31.73 Hz | φ³ | 817 | Thalamocortical boundary |
| Cortex L2/3 | 3 | 40.36/65.3 Hz | φ³·⁵/φ⁴·⁵ | 1040/1681 | Gamma (dynamic) |

### 2.2 SR Harmonic Bank (Observed Frequencies, v8.5)

| Harmonic | Center Frequency | Drift Range | OMEGA_DT | Coherence Target |
|----------|-----------------|-------------|----------|------------------|
| f₀ | 7.6 Hz | ±0.6 Hz | 196 ± 15 | theta (thalamus) |
| f₁ | 13.75 Hz | ±0.75 Hz | 354 ± 19 | alpha (L6) |
| f₂ | 20 Hz | ±1 Hz | 514 ± 26 | low_beta (L5a) |
| f₃ | 25 Hz | ±1.5 Hz | 643 ± 39 | high_beta (L5b) |
| f₄ | 32 Hz | ±2 Hz | 823 ± 51 | gamma (L4) |

---

## 3. Thalamic Theta System (thalamus.v, v8.7)

### 3.1 Theta Phase Multiplexing (v8.0)

The theta oscillator (5.89 Hz) provides an 8-phase cycle (~170ms period):

**Phase Detection Algorithm:**
1. DC-removal IIR filter on theta_y: `theta_y_dc = theta_y_dc + (theta_y - theta_y_dc) >>> 4`
2. Zero-crossing detection on DC-removed signal
3. Rising-edge counting: theta_phase increments 0→7 per cycle

**Phase Windows:**

| Phases | Window | theta_x | Function |
|--------|--------|---------|----------|
| 0-3 | Encoding | > 0 (peak) | Learning enabled |
| 4-7 | Retrieval | < 0 (trough) | Recall enabled |

**Sub-windows** (2-bit phase_subwindow):
- 00: Early encoding (phases 0-1) - sensory-dominated
- 01: Late encoding (phases 2-3) - consolidation
- 10: Early retrieval (phases 4-5) - pattern completion
- 11: Late retrieval (phases 6-7) - output/decay

### 3.2 SR Integration

Thalamus instantiates the SR harmonic bank and applies per-harmonic continuous gain to the theta oscillator input.

### 3.3 Matrix Thalamic Pathway (v8.7)

In addition to the core relay (sensory → theta-gated → L4), thalamus now implements a matrix pathway:

**Two Thalamic Systems:**
| System | Nuclei | Projection | Function |
|--------|--------|------------|----------|
| **Core** | dLGN, VPM | Focal to L4 | Fast, precise sensory relay |
| **Matrix** | POm, Pulvinar | Diffuse to L1 | Attention, arousal, context |

**Matrix Computation:**
```
// L5b from all cortical columns drives matrix thalamus
l5b_sum = l5b_sensory + l5b_assoc + l5b_motor
l5b_avg = l5b_sum × ONE_THIRD

// Theta-gated for temporal coherence
matrix_output = l5b_avg × theta_gate
```

The matrix_output is broadcast identically to all cortical columns' Layer 1, enabling global attention/arousal modulation.

---

## 4. Stochastic Resonance System

### 4.1 SR Harmonic Bank (sr_harmonic_bank.v, v7.4)

Five stochastic Hopf oscillators at observed SR frequencies, externally driven by SR field inputs:

**Per-Harmonic Coherence:**
- Dot product: `coherence = target_x × f_x + target_y × f_y`
- Target mapping: f₀→theta, f₁→alpha, f₂→low_beta, f₃→high_beta, f₄→gamma

**Continuous Gain Computation (v7.4):**

```
// Coherence factor (piecewise linear sigmoid)
coh_factor = 0              if coherence < 0.5
           = (coh - 0.5) × 2  if 0.5 ≤ coherence < 1.0
           = 1.0             if coherence ≥ 1.0

// Beta factor (inverse linear)
beta_factor = max(0, 1 - beta_amplitude / threshold)

// Final per-harmonic gain
gain[h] = coh_factor × beta_factor
```

**Thresholds:**
- Beta quiet: 0.9375 (15360 Q14) - gates all SR sensitivity
- Coherence: 0.75 (12288 Q14) - legacy binary SIE threshold

### 4.2 SR Frequency Drift (sr_frequency_drift.v, v8.5)

Models realistic Schumann Resonance frequency variation based on monitoring data:

**Drift Model:**
- Bounded random walk with reflecting boundaries
- Per-harmonic 16-bit LFSR for direction selection
- Update rate: 15 minutes real-time (1500 clk_en in FAST_SIM)
- Step size: ±1 OMEGA_DT unit per update

**Observed Drift Rates:**
- ~0.05-0.1 Hz/hour (matches real SR monitoring)
- Random walk σ ≈ 0.08 Hz/hour

**Purpose:**
- Prevents unrealistic high coherence from exact frequency matches
- Creates natural detuning between SR and neural oscillators
- Produces realistic hours-scale drift patterns

### 4.3 SR Noise Generator (sr_noise_generator.v)

Five independent 16-bit LFSRs with maximally different seeds:
- Polynomial: x¹⁶ + x¹⁴ + x¹³ + x¹¹ + 1
- Output: centered white noise, amplitude ~0.015 (256 Q14)
- Seeds: 0xACE1, 0x7B3F, 0xD4A9, 0x1E6C, 0x92F5

---

## 5. CA3 Phase Memory (ca3_phase_memory.v, v8.0)

### 5.1 Hebbian Weight Matrix

6×6 symmetric weight matrix (36 weights, 8-bit signed each):

**Learning Rule (theta peak, phases 0-3):**
```
if (pattern_in[i] && pattern_in[j] && i ≠ j):
    weights[i][j] += LEARN_RATE (2)
    weights[j][i] += LEARN_RATE (2)  // Symmetric update
    Saturates at WEIGHT_MAX (100)
```

**Recall Rule (theta trough, phases 4-7):**
```
for each unit i:
    accum[i] = Σ_j (weights[i][j] × pattern_in[j])
    phase_pattern[i] = (accum[i] > RECALL_THRESHOLD) ? 1 : 0
```

### 5.2 Memory Decay (v5.3)

Synaptic homeostasis every 10 theta cycles when no pattern active:
```
if (weights[i][j] > DECAY_RATE):
    weights[i][j] -= DECAY_RATE (1)
else:
    weights[i][j] = 0
```

### 5.3 State Machine

7 states: IDLE → LEARN → LEARN_DONE → IDLE
         IDLE → RECALL → RECALL_DONE → IDLE
         IDLE → DECAY → DECAY_DONE → IDLE

Transitions controlled by theta_x thresholds with hysteresis (±0.25).

---

## 6. Cortical Column Architecture (cortical_column.v, v8.7)

### 6.1 Six-Layer Stack (v8.7)

Each of 3 columns contains Layer 1 plus 5 oscillators:

**Layer 1 (Molecular Layer) - v8.7:**
- Contains only GABAergic interneurons (no oscillator)
- Receives: matrix thalamic input, dual cortico-cortical feedback
- Outputs: apical_gain for L2/3 and L5 modulation
- Function: top-down attention/context gating

**Layers 2-6 (Oscillator Stack):**

| Layer | Frequency | Role | Connectivity (v8.7) |
|-------|-----------|------|---------------------|
| L2/3 | 40.36/65.3 Hz | Gamma, feedforward | L4 input × **apical_gain** + phase coupling |
| L4 | 31.73 Hz | Thalamocortical | Receives theta input, feedforward (no L1 gain) |
| L5a | 15.42 Hz | Low beta, motor output | L2/3 input × **apical_gain** |
| L5b | 24.94 Hz | High beta, feedback | L2/3 input × **apical_gain** |
| L6 | 9.53 Hz | Alpha, gain control | L5b + inter-column FB + phase coupling (no L1 gain) |

### 6.2 Scaffold Architecture (v8.0)

Based on Dupret et al. 2025 - stable backbone vs plastic integration:

**Scaffold Layers (high baseline activity, resist perturbation):**
- L4: Anchors spatial context
- L5b: Maintains state

**Plastic Layers (lower activity, integrate new patterns):**
- L2/3: Receives phase_coupling[0] - gamma feedforward
- L6: Receives phase_coupling[5] - alpha gain control
- L5a: Intermediate plasticity (no coupling)

Phase coupling equation:
```
input_x = K_PHASE × (phase_bit ? +16384 : -16384)
        = ±0.25 (4096 Q14)
```

### 6.3 Gamma-Theta Nesting (v8.1)

L2/3 omega_dt dynamically switches based on encoding_window:

```
if (encoding_window):  // Phases 0-3, theta peak
    omega_dt_l23 = 1681  // 65.3 Hz fast gamma (φ⁴·⁵)
else:                   // Phases 4-7, theta trough
    omega_dt_l23 = 1040  // 40.36 Hz slow gamma (φ³·⁵)
```

This implements differential gamma frequencies for sensory encoding (fast) vs memory retrieval (slow).

### 6.4 Canonical Microcircuit with L1 Modulation (v8.7)

v8.7 adds Layer 1 gain modulation to the canonical cortical signal flow:

**Canonical Pathway with L1:**
```
Matrix Thalamus ──────────────────────▶ L1 (apical_gain)
                                         │
Thalamus → L4 → L2/3 ──────────────────▶ L5 → Output
              (×apical_gain)        (×apical_gain)
                  ↓
                 L6 → Thalamus (corticothalamic)
```

**Layer 1 Gain Formula (v8.7):**
```
combined = 0.15 × matrix + 0.3 × fb1 + 0.2 × fb2
apical_gain = clamp(1.0 + combined, 0.5, 1.5)
```

**Coupling Constants (Q14):**
```
K_MATRIX = 2458  (0.15) - Matrix thalamus → L1
K_FB1    = 4915  (0.3)  - Adjacent column feedback → L1
K_FB2    = 3277  (0.2)  - Distant column feedback → L1
K_L4_L23 = 6554  (0.4)  - L4 → L2/3 feedforward
K_L23_L5 = 4915  (0.3)  - L2/3 → L5 (canonical pathway)
K_L5_L6  = 3277  (0.2)  - L5b → L6 intra-column feedback
K_PAC    = 3277  (0.2)  - PAC modulation
K_FB_L5  = 3277  (0.2)  - Inter-column feedback
```

**Signal Chain (v8.7):**
```
L1 computes apical_gain from matrix + feedbacks
    ↓
L4 oscillates (thalamocortical input)
    ↓ K_L4_L23
L2/3 input = (L4[N-1] + PAC + phase_coupling) × apical_gain
    ↓ K_L23_L5
L5 input = (L2/3[N-1] + inter-column feedback) × apical_gain
    ↓ K_L5_L6
L6 sees L5b[N-1] + inter-column feedback + phase_coupling (no gain)
```

One-cycle delay between layers implements natural synaptic propagation time.

### 6.5 Inter-Column Connectivity

Three cortical columns with feedforward cascade:

| Column | Role | Input Source | Output Target |
|--------|------|--------------|---------------|
| Sensory | Early processing | External sensory input | Association |
| Association | Integration | Sensory column output | Motor |
| Motor | Action output | Association column output | DAC |

---

## 7. Consciousness State System (config_controller.v, v8.0)

### 7.1 Five States

| Code | State | Description | Key MU Settings |
|------|-------|-------------|-----------------|
| 0 | NORMAL | Baseline | All MU = 4 |
| 1 | ANESTHESIA | Propofol-like | L6 high (6), L4/L2/3 weak (1) |
| 2 | PSYCHEDELIC | Enhanced binding | L4/L2/3 enhanced (6), L6 reduced (2) |
| 3 | FLOW | Motor-optimized | L5a/L5b enhanced (6), L6 reduced (2) |
| 4 | MEDITATION | Theta coherence | L5a/L5b/L4/L2/3 reduced (2) |

### 7.2 MU Parameter Effects

- MU = 1: Weak oscillation, susceptible to extinction
- MU = 2: Stable but reduced amplitude
- MU = 4: Normal operation, amplitude stabilizes at r ≈ 1
- MU = 6: Enhanced amplitude, faster recovery from perturbation

---

## 8. Support Systems

### 8.1 Clock Enable Generator (clock_enable_generator.v, v6.0)

- System clock: 125 MHz
- Primary update rate: 4 kHz (divider = 31250)
- FAST_SIM mode: divider = 10 for ~3000× speedup
- Reserved 100 kHz path for future fast updates

### 8.2 Pink Noise Generator (pink_noise_generator.v, v5.5)

Voss-McCartney algorithm for 1/f noise:
- 16-bit LFSR (polynomial: x¹⁶ + x¹⁴ + x¹³ + x¹¹ + 1)
- 8 octave bands updated at rates 1/2ⁿ
- Sum produces pink spectrum
- Output: 18-bit signed centered noise

### 8.3 Output Mixer (output_mixer.v, v5.5)

Weighted combination for DAC output:
```
mixed = 0.4 × L2/3_x + 0.3 × L5a_x + 0.2 × pink_noise
dac_output = (mixed + 1.0) × 2048  // 12-bit, 0-4095
```

---

## 9. Top-Level Integration (phi_n_neural_processor.v, v8.7)

### 9.1 Signal Flow

```
                    SR Frequency Drift (v8.5)
                            ↓ drifting omega_dt[5]
External SR Fields → SR Harmonic Bank → sr_gains[5]
                                            ↓
Thalamus (theta) ← sr_gain_sum ← weighted_sum(sr_gains × coherence)
     │
     ├─▶ theta_x, theta_phase, encoding_window
     │
     └─▶ matrix_output (v8.7) ─────────────────────────────┐
                                                            │
  ┌──────────────────────────────────────────┐              │
  │ CA3 Phase Memory                          │              │
  │   pattern_in[6] → Hebbian weights → phase_pattern[6] │  │
  └──────────────────────────────────────────┘              │
     ↓                                                      │
phase_coupling[6] = K_PHASE × (phase_bit ? +1 : -1)         │
     ↓                                                      ↓
  ┌────────────┬────────────┬────────────┐           matrix broadcast
  │ Column 0   │ Column 1   │ Column 2   │◀──────────────────┘
  │ (Sensory)  │ (Assoc)    │ (Motor)    │
  │ L1←matrix  │ L1←matrix  │ L1←matrix  │  ← v8.7: Layer 1
  │ L2/3←coup  │ L2/3←coup  │ L2/3←coup  │
  │ L4         │ L4         │ L4         │
  │ L5a        │ L5a        │ L5a        │
  │ L5b ───────┼─▶ Thalamus (matrix input) ← v8.7: L5b feedback
  │ L6←coup    │ L6←coup    │ L6←coup    │
  └────────────┴────────────┴────────────┘
     ↓
  Output Mixer → 12-bit DAC
```

### 9.2 Resource Utilization

- 21 Hopf oscillators (16 deterministic + 5 stochastic)
- 36 Hebbian weights (8-bit × 36 = 288 bits)
- 6 LFSRs (5 for SR noise + 1 for pink noise)
- 5 LFSRs for SR frequency drift
- 5 consciousness state configurations

### 9.3 Module Hierarchy

```
phi_n_neural_processor (top) - v8.7
├── clock_enable_generator
├── sr_noise_generator
├── sr_frequency_drift (v8.5)
├── config_controller
├── thalamus - v8.7
│   ├── hopf_oscillator (theta)
│   ├── sr_harmonic_bank
│   │   └── hopf_oscillator_stochastic ×5
│   └── matrix thalamic computation (L5b→matrix_output)
├── ca3_phase_memory
├── cortical_column (sensory) - v8.7
│   ├── layer1_minimal (matrix + dual feedback → apical_gain)
│   └── hopf_oscillator ×5
├── cortical_column (association) - v8.7
│   ├── layer1_minimal
│   └── hopf_oscillator ×5
├── cortical_column (motor) - v8.7
│   ├── layer1_minimal
│   └── hopf_oscillator ×5
├── pink_noise_generator
└── output_mixer
```

---

## 10. Key Innovations

1. **φⁿ Frequency Architecture**: All cortical frequencies related by golden ratio, creating natural harmonic relationships without integer resonance artifacts

2. **Theta Phase Multiplexing**: 8-phase theta cycle enables time-division multiplexing of encoding vs retrieval computations in same neural population

3. **Scaffold-Plastic Separation**: Stable layers (L4, L5b) maintain context while plastic layers (L2/3, L6) integrate new information, mimicking hippocampal architecture

4. **Continuous SR Gain**: Replaces binary SIE switching with smooth coherence × beta modulation for graceful degradation

5. **Gamma-Theta Nesting**: Fast gamma (65 Hz) during encoding, slow gamma (40 Hz) during retrieval, matching empirical PAC observations

6. **Hebbian Phase Encoding**: Patterns stored as phase relationships to theta, enabling interference-resistant memory

7. **SR Frequency Drift (v8.5)**: Bounded random walk models realistic hours-scale SR variation, preventing artificial coherence from exact frequency matches

8. **Layer 1 Gain Modulation (v8.7)**: Molecular layer integrates matrix thalamic + dual cortico-cortical feedback to produce apical gain [0.5, 1.5] for L2/3 and L5 modulation

9. **Matrix Thalamic Pathway (v8.7)**: L5b PT neurons from all columns drive matrix thalamus (POm/Pulvinar analog), which broadcasts diffuse modulation to all L1

---

## 11. Test Coverage Summary

- 152 automated tests across 11 testbenches
- Coverage: Hopf dynamics, CA3 learning/recall, theta phase, scaffold architecture, gamma nesting, canonical microcircuit, SR coupling, SR drift, state transitions, Layer 1 gain modulation
- All tests passing as of v8.7

### Key Testbenches

| Testbench | Tests | Coverage |
|-----------|-------|----------|
| tb_full_system_fast | 15 | Full integration, all features |
| tb_theta_phase_multiplexing | 19 | 8-phase cycle, windows |
| tb_scaffold_architecture | 14 | Scaffold/plastic differentiation |
| tb_gamma_theta_nesting | 7 | L2/3 frequency switching |
| tb_canonical_microcircuit | 20 | Canonical pathway verification |
| tb_sr_frequency_drift | 30 | Drift bounds, random walk |
| tb_multi_harmonic_sr | 17 | Per-harmonic coherence |
| tb_learning_fast | 8 | CA3 Hebbian learning |
| tb_sr_coupling | 2 | SR coupling tests |
| tb_v55_fast | 6 | Fast integration tests |
| tb_layer1_minimal | 10 | v8.7: Layer 1 gain modulation |

---

## 12. Version History

| Version | Date | Key Changes |
|---------|------|-------------|
| **v8.7** | **2025-12-26** | **Layer 1, dual feedback, matrix thalamic pathway** |
| v8.6 | 2025-12-23 | Canonical microcircuit: L2/3→L5, L5b→L6 intra-column feedback |
| v8.5 | 2025-12-23 | SR frequency drift with bounded random walk |
| v8.4 | 2025-12-23 | Gamma-theta nesting implementation, integration tests |
| v8.3 | 2025-12-23 | DC offset fix for theta phase detection |
| v8.0 | 2025-12-23 | Scaffold architecture, theta phase multiplexing |
| v7.4 | 2025-12-22 | Continuous SR gain (replaces binary SIE) |
| v7.3 | 2025-12-22 | Multi-harmonic SR bank |
| v6.0 | 2025-12-21 | Hopf amplitude stabilization, fast startup |
| v5.5 | 2025-12-20 | Pink noise, output mixer |
