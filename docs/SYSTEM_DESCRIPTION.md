# φⁿ Neural Processor - Comprehensive System Description

**Version:** 9.4 (VIP+ Disinhibition)
**Date:** 2025-12-27
**Based on:** Complete analysis of all 15 source modules (~4,200 lines of Verilog)

---

## Executive Summary

The φⁿ Neural Processor is an FPGA implementation of 21 coupled nonlinear oscillators organized as a thalamo-cortical network. The system models biological neural rhythms using golden ratio (φ ≈ 1.618) frequency relationships, implements associative memory through theta-gated Hebbian learning, and exhibits stochastic resonance sensitivity to weak external electromagnetic fields.

**Version 9.4** completes the five-phase interneuron implementation plan with a biologically realistic cortical microcircuit featuring:
- **PV+ basket cells**: Fast perisomatic inhibition (τ=5ms) with PING gamma dynamics
- **SST+ Martinotti cells**: Slow dendritic inhibition (τ=25ms) via GABA-B kinetics
- **VIP+ interneurons**: Disinhibitory attention gating (τ=50ms) that suppresses SST+
- **Cross-layer PV+ network**: L4 feedforward gating + L5 feedback inhibition to L2/3

The complete system implements the canonical cortical microcircuit (L4→L2/3→L5→L6→Thalamus), dual thalamocortical pathways (core to L4, matrix to L1), theta phase multiplexing with gamma-theta nesting, scaffold/plastic layer architecture, and five consciousness states.

---

## 1. Core Oscillator Engine

### 1.1 Hopf Normal Form (hopf_oscillator.v, v6.0)

Each oscillator implements the Hopf bifurcation equations in Q4.14 fixed-point:

```
dx/dt = μx - ωy - r²x + input_x
dy/dt = μy + ωx - r²y
```

Where:
- `μ` (mu_dt): Growth rate parameter (controls amplitude)
- `ω` (omega_dt): Angular frequency (determines oscillation frequency)
- `r²` = x² + y²: Amplitude squared (provides amplitude stabilization)
- `input_x`: External coupling input

**Key Implementation Details:**

| Parameter | Value | Description |
|-----------|-------|-------------|
| Format | Q4.14 | 18-bit signed, 14 fractional bits |
| Range | [-8.0, +7.99994] | Fixed-point range |
| Update Rate | 4 kHz | dt = 0.00025s (DT = 4 in Q14) |
| Initialization | x=0.5, y=0 | Fast startup (no ramp-up delay) |

**Amplitude Stabilization:**
When r² exceeds threshold (1.0625), applies correction factor to prevent Euler integration runaway:
```
if (r² > 17408):  // 1.0625 in Q14
    correction = clamp(2.0 - r², 0.5, 1.0)
    x_next = x_raw × correction
    y_next = y_raw × correction
```

### 1.2 Stochastic Variant (hopf_oscillator_stochastic.v)

Adds `noise_x` input to dx term for true stochastic resonance behavior:
```
dx/dt = μx - ωy - r²x + input_x + noise_x
```

Used exclusively by the SR harmonic bank to model weak external field detection.

---

## 2. Frequency Architecture

All 21 oscillators follow structured frequency relationships based on the golden ratio φ ≈ 1.618034.

### 2.1 Cortical Oscillators (φⁿ Scaling)

The mathematical relationship: f_n = f_base × φⁿ

| Location | Count | Frequency | φⁿ Exponent | OMEGA_DT (Q14) | Role |
|----------|-------|-----------|-------------|----------------|------|
| Thalamus Theta | 1 | 5.89 Hz | φ⁻⁰·⁵ | 152 | Memory gating, encoding/retrieval |
| Cortex L6 | 3 | 9.53 Hz | φ⁰·⁵ | 245 | Alpha gain control |
| Cortex L5a | 3 | 15.42 Hz | φ¹·⁵ | 397 | Low beta motor output |
| Cortex L5b | 3 | 24.94 Hz | φ²·⁵ | 642 | High beta feedback |
| Cortex L4 | 3 | 31.73 Hz | φ³ | 817 | Thalamocortical boundary |
| Cortex L2/3 | 3 | 40.36/65.3 Hz | φ³·⁵/φ⁴·⁵ | 1040/1681 | Gamma (dynamic) |

**OMEGA_DT Calculation:**
```
OMEGA_DT = round(2π × f_hz × dt × 2^14)
         = round(2π × f_hz × 0.00025 × 16384)
```

### 2.2 SR Harmonic Bank (Observed Frequencies, v8.5)

Based on real-time Schumann Resonance monitoring data:

| Harmonic | Center Frequency | Drift Range | OMEGA_DT ± Drift | Coherence Target |
|----------|-----------------|-------------|------------------|------------------|
| f₀ | 7.6 Hz | ±0.6 Hz | 196 ± 15 | theta (thalamus) |
| f₁ | 13.75 Hz | ±0.75 Hz | 354 ± 19 | alpha (L6) |
| f₂ | 20 Hz | ±1 Hz | 514 ± 26 | low_beta (L5a) |
| f₃ | 25 Hz | ±1.5 Hz | 643 ± 39 | high_beta (L5b) |
| f₄ | 32 Hz | ±2 Hz | 823 ± 51 | gamma (L4) |

### 2.3 Frequency Ratios

Adjacent layers maintain φ ratio relationships enabling natural harmonic coupling without integer resonance artifacts:

```
L6/Theta   = 9.53/5.89   = 1.618 ≈ φ
L5a/L6     = 15.42/9.53  = 1.618 ≈ φ
L5b/L5a    = 24.94/15.42 = 1.618 ≈ φ
L4/L5b     = 31.73/24.94 = 1.272 ≈ √φ
L2/3/L4    = 40.36/31.73 = 1.272 ≈ √φ (slow gamma)
Fast/Slow  = 65.3/40.36  = 1.618 ≈ φ (gamma switching)
```

---

## 3. Thalamic System (thalamus.v, v8.8)

The thalamus implements dual pathways matching biological core/matrix organization:

### 3.1 Core Pathway (Sensory Relay)

Primary sensory information flows through theta-gated relay to L4:

```
sensory_input → theta_gate → theta_gated_output → L4 (all columns)
```

**Theta Gate Computation:**
```
theta_gate_raw = 0.5 + (theta_x / 2)        // Range: [0, 1]
l6_inhibition = K_L6_THAL × L6 + K_TRN × L6 // v8.8: L6 CT inhibition
theta_gate = max(0, theta_gate_raw - l6_inhibition)
output = sensory × gain × theta_gate
```

### 3.2 Matrix Pathway (L5b→L1 Broadcast, v8.7)

Higher-order thalamic nuclei (POm, Pulvinar analog) provide diffuse modulation:

```
L5b (sensory + assoc + motor) → average → theta_gate → matrix_output → L1 (all columns)
```

**Matrix Computation:**
```
l5b_avg = (l5b_sensory + l5b_assoc + l5b_motor) × ONE_THIRD
matrix_output = l5b_avg × theta_gate
```

The matrix pathway enables:
- Global arousal/attention modulation
- Cross-column coordination
- Top-down gain control via Layer 1

### 3.3 Theta Phase Multiplexing (v8.0)

8-phase theta cycle (~170ms period at 5.89 Hz) enables temporal multiplexing:

**Phase Detection Algorithm:**
1. DC-removal IIR filter: `theta_y_dc += (theta_y - theta_y_dc) >>> 8`
2. High-pass: `theta_y_hp = theta_y - theta_y_dc`
3. Amplitude tracking: IIR on |theta_y_hp|
4. Phase from: {y_positive, y_rising, |y| > amp/4}

**Phase Windows:**

| Phases | Window | theta_x Sign | theta_y_hp | Function |
|--------|--------|--------------|------------|----------|
| 0-1 | Early Encoding | > 0 | Rising to peak | Fast gamma, sensory input |
| 2-3 | Late Encoding | > 0 | Falling from peak | Consolidation |
| 4-5 | Early Retrieval | < 0 | Falling to trough | Pattern completion |
| 6-7 | Late Retrieval | < 0 | Rising from trough | Output/decay |

### 3.4 L6 CT Inhibitory Modulation (v8.8)

L6 corticothalamic neurons provide inhibitory feedback with TRN amplification:

```
L6 alpha feedback
    ├── K_L6_THAL (0.1): Direct inhibition
    └── K_TRN (0.2): TRN amplification
        ↓
Combined = 0.3 × L6 activity → reduces theta_gate
```

**Biological Basis:**
- L6 CT projects to thalamus at 10:1 ratio (modulatory, not driving)
- TRN amplifies L6 inhibition creating surround suppression
- High cortical alpha → reduced thalamic relay → sensory gating

---

## 4. Stochastic Resonance System

### 4.1 SR Harmonic Bank (sr_harmonic_bank.v, v7.4)

Five stochastic Hopf oscillators driven by external SR field inputs:

**Per-Harmonic Coherence Detection:**
```
dot_product = target_x × f_x + target_y × f_y
coherence = |dot_product| >>> FRAC
```

Target mapping: f₀→theta, f₁→alpha, f₂→low_beta, f₃→high_beta, f₄→gamma

**Continuous Gain Computation (v7.4):**

```
// Coherence factor (piecewise linear sigmoid)
coh_factor = 0                        if coherence < 0.5
           = (coherence - 0.5) × 2    if 0.5 ≤ coherence < 1.0
           = 1.0                      if coherence ≥ 1.0

// Beta factor (inverse linear)
beta_factor = max(0, 1 - beta_amplitude / threshold)

// Per-harmonic gain
gain[h] = coh_factor × beta_factor
```

**Thresholds (Q14):**
- Beta quiet: 15360 (0.9375) - gates all SR sensitivity
- Coherence: 12288 (0.75) - legacy binary SIE threshold

### 4.2 SR Frequency Drift (sr_frequency_drift.v, v8.5)

Models realistic hours-scale SR variation based on monitoring data:

**Drift Model:**
- Bounded random walk with reflecting boundaries
- Per-harmonic 16-bit LFSR for stochastic direction
- Update rate: ~15 minutes real-time (scaled for simulation)
- Step size: ±1 OMEGA_DT unit per update

**Observed Drift Rates:**
- Real SR: ~0.05-0.1 Hz/hour
- Model σ: ~0.08 Hz/hour

**Purpose:**
- Prevents unrealistic high coherence from exact frequency matches
- Creates natural detuning between SR and neural oscillators
- Produces biologically plausible detection dynamics

### 4.3 SR Noise Generator (sr_noise_generator.v)

Five independent 16-bit LFSRs with maximally different seeds:

| Harmonic | LFSR Seed | Polynomial |
|----------|-----------|------------|
| f₀ | 0xACE1 | x¹⁶ + x¹⁴ + x¹³ + x¹¹ + 1 |
| f₁ | 0x7B3F | " |
| f₂ | 0xD4A9 | " |
| f₃ | 0x1E6C | " |
| f₄ | 0x92F5 | " |

Output: Centered white noise, amplitude ~0.015 (256 Q14)

---

## 5. CA3 Phase Memory (ca3_phase_memory.v, v8.0)

### 5.1 Hebbian Weight Matrix

6×6 symmetric weight matrix storing phase relationships:

**Structure:**
- 36 weights (8-bit signed each, 288 bits total)
- Symmetric: w[i][j] = w[j][i]
- Diagonal = 0 (no self-connections)

**Learning Rule (theta peak, phases 0-3):**
```
if (pattern_in[i] && pattern_in[j] && i ≠ j):
    weights[i][j] += LEARN_RATE (2)
    weights[j][i] += LEARN_RATE (2)  // Symmetric
    Saturate at WEIGHT_MAX (100)
```

**Recall Rule (theta trough, phases 4-7):**
```
for each unit i:
    accum[i] = Σ_j (weights[i][j] × pattern_in[j])
    phase_pattern[i] = (accum[i] > RECALL_THRESHOLD) ? 1 : 0
```

### 5.2 Memory Decay (v5.3)

Synaptic homeostasis prevents weight saturation:

```
if (theta_cycle_count >= DECAY_INTERVAL && pattern_in == 0):
    for all weights:
        if (weight > DECAY_RATE):
            weight -= DECAY_RATE (1)
        else:
            weight = 0
```

- Decay interval: 10 theta cycles
- Creates competitive learning: reinforced patterns persist

### 5.3 State Machine

```
IDLE ──(theta peak + pattern)──▶ LEARN ──▶ LEARN_DONE ──▶ IDLE
IDLE ──(theta trough + pattern)──▶ RECALL ──▶ RECALL_DONE ──▶ IDLE
IDLE ──(theta trough + no pattern + interval)──▶ DECAY ──▶ DECAY_DONE ──▶ IDLE
```

Transitions use hysteresis (±0.25) to prevent oscillation.

### 5.4 Pattern Mapping

6-bit pattern maps to cortical oscillators:

| Bit | Oscillator | Function |
|-----|------------|----------|
| 0 | Sensory L2/3 | Gamma feedforward |
| 1 | Sensory L6 | Alpha gain |
| 2 | Association L2/3 | Integration |
| 3 | Association L6 | Attention |
| 4 | Motor L2/3 | Motor planning |
| 5 | Motor L6 | Motor control |

---

## 6. Cortical Column Architecture (cortical_column.v, v9.4)

### 6.1 Six-Layer Structure

Each of 3 columns contains Layer 1 (modulatory) plus 5 oscillatory layers:

```
┌─────────────────────────────────────────────────────────────────┐
│                    CORTICAL COLUMN (v9.4)                        │
├─────────────────────────────────────────────────────────────────┤
│ LAYER 1 (Molecular) - NO OSCILLATOR                             │
│   Inputs: Matrix thalamic + Dual feedback + Attention           │
│   Cells: SST+ (slow GABA-B) + VIP+ (disinhibition)             │
│   Output: apical_gain [0.5, 1.5]                                │
│   Modulates: L2/3 and L5 (apical dendrite targets)              │
├─────────────────────────────────────────────────────────────────┤
│ LAYER 2/3 (Supragranular) - PLASTIC                             │
│   Frequency: 40.36/65.3 Hz (φ³·⁵/φ⁴·⁵) - theta-phase switch    │
│   Input: (L4 × K_L4_L23 + PAC + phase_coupling) × apical_gain   │
│          - PV+ inhibition (L2/3 + L4_ff + L5_fb)                │
│   Output: Feedforward to next column, CA3, L5                   │
│   PV+ populations: 3 sources (local, L4, L5)                    │
├─────────────────────────────────────────────────────────────────┤
│ LAYER 4 (Granular) - SCAFFOLD                                   │
│   Frequency: 31.73 Hz (φ³)                                      │
│   Input: Thalamic theta + Feedforward (no L1 gain)              │
│   Output: L2/3 (canonical) + L5a (bypass)                       │
│   PV+ population: Gates feedforward pathway                     │
├─────────────────────────────────────────────────────────────────┤
│ LAYER 5a (Upper L5) - INTERMEDIATE                              │
│   Frequency: 15.42 Hz (φ¹·⁵)                                    │
│   Input: (L2/3 + L6_feedback + L4_bypass) × apical_gain         │
│   Output: Motor output, DAC                                     │
│   Cell type: IT neurons (intratelencephalic)                    │
├─────────────────────────────────────────────────────────────────┤
│ LAYER 5b (Lower L5) - SCAFFOLD                                  │
│   Frequency: 24.94 Hz (φ²·⁵)                                    │
│   Input: (L2/3 + inter-column FB) × apical_gain                 │
│   Output: L6 intra-column, Matrix thalamus                      │
│   Cell type: PT neurons (pyramidal tract)                       │
│   PV+ population: Provides feedback inhibition to L2/3          │
├─────────────────────────────────────────────────────────────────┤
│ LAYER 6 (Multiform) - PLASTIC                                   │
│   Frequency: 9.53 Hz (φ⁰·⁵)                                     │
│   Input: L5b + inter-column FB + phase_coupling (no L1 gain)    │
│   Output: Thalamus (inhibitory via TRN), L5a intra-column       │
│   Cell type: CT neurons (corticothalamic)                       │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 Scaffold vs Plastic Architecture (v8.0)

Based on Dupret et al. 2025 - stable backbone vs flexible integration:

| Layer | Type | Phase Coupling | Behavior |
|-------|------|----------------|----------|
| L4 | **Scaffold** | No | Stable thalamocortical boundary, anchors context |
| L5b | **Scaffold** | No | Maintains state, PT neuron stability |
| L2/3 | **Plastic** | Yes | Integrates new patterns, gamma dynamics |
| L6 | **Plastic** | Yes | Memory-dependent attention modulation |
| L5a | Intermediate | No | Motor output adaptation |
| L1 | Modulator | — | Top-down gain control |

**Phase Coupling Computation:**
```
phase_couple = K_PHASE × theta_x × sign
sign = +1 if phase_pattern[bit]=1 (in-phase)
     = -1 if phase_pattern[bit]=0 (anti-phase)
K_PHASE = 4096 (0.25 in Q14)
```

### 6.3 Gamma-Theta Nesting (v8.1)

L2/3 frequency dynamically switches based on theta phase:

```
if (encoding_window):  // Phases 0-3, theta peak
    omega_dt_l23 = 1681  // 65.3 Hz fast gamma (φ⁴·⁵)
else:                   // Phases 4-7, theta trough
    omega_dt_l23 = 1040  // 40.36 Hz slow gamma (φ³·⁵)
```

**Biological Basis:**
- Fast gamma during encoding: precise temporal coding of sensory input
- Slow gamma during retrieval: matches CA3 reactivation patterns
- Frequency ratio = φ (exactly one golden ratio step)

### 6.4 Canonical Microcircuit Signal Flow (v8.6)

```
              Matrix Thalamus
                    │
                    ▼
    ┌──────────────────────────────────────────┐
    │             LAYER 1                       │
    │  matrix + fb1 + fb2 + attention          │
    │         ↓ SST+/VIP+ processing           │
    │         ↓ apical_gain                     │
    └──────────┼────────────┼──────────────────┘
               │            │
    Core       │            │
    Thalamus   ▼            ▼
        │    ┌───────┐   ┌─────────┐
        └───▶│  L4   │   │ L5a/L5b │ (thick-tufted dendrites)
             │       │   │         │
             └───┬───┘   └────▲────┘
                 │            │
            K_L4_L23      K_L23_L5
                 │            │
                 ▼            │
             ┌───────┐        │
             │ L2/3  │────────┘ (apical dendrites in L1)
             │       │
             └───┬───┘
                 │
                 ▼
             ┌───────┐
             │  L6   │───────▶ Thalamus (inhibitory)
             └───────┘
```

### 6.5 L6 Output Connectivity (v8.8)

Corrected based on recent neurophysiology:

**L6 → L5a Intra-column (K_L6_L5A = 0.15):**
- L6 CT projects to L5a, NOT L4 (corrects previous assumption)
- Provides feedback modulation of motor output

**L4 → L5a Bypass (K_L4_L5A = 0.1):**
- Fast pathway for rapid sensorimotor responses
- Bypasses L2/3 processing for time-critical signals

**L6 → Thalamus + TRN (K_L6_THAL = 0.1, K_TRN = 0.2):**
- 10:1 modulatory ratio with TRN amplification
- Enables cortical control of sensory gating

### 6.6 Coupling Constants (Q14)

```verilog
// Layer 1 and L6 output (v8.7, v8.8)
K_MATRIX  = 2458  (0.15) - Matrix thalamus → L1
K_FB1     = 4915  (0.3)  - Adjacent column feedback → L1
K_FB2     = 3277  (0.2)  - Distant column feedback → L1
K_L6_L5A  = 2458  (0.15) - L6 → L5a intra-column
K_L4_L5A  = 1638  (0.1)  - L4 → L5a bypass
K_L6_THAL = 1638  (0.1)  - L6 → Thalamus direct inhibition
K_TRN     = 3277  (0.2)  - TRN amplification of L6 inhibition

// Canonical microcircuit
K_L4_L23  = 6554  (0.4)  - L4 → L2/3 feedforward
K_L23_L5  = 4915  (0.3)  - L2/3 → L5 (canonical pathway)
K_L5_L6   = 3277  (0.2)  - L5b → L6 intra-column feedback
K_PAC     = 3277  (0.2)  - PAC modulation
K_FB_L5   = 3277  (0.2)  - Inter-column feedback
```

---

## 7. Interneuron Microcircuits (v9.x Series)

The v9.x series implements the three canonical interneuron classes with biologically accurate dynamics.

### 7.1 Interneuron Classification

| Class | Marker | Target | Time Constant | Function | v9.x Phase |
|-------|--------|--------|---------------|----------|------------|
| **PV+** | Parvalbumin | Soma, proximal dendrites | 5ms | Fast perisomatic inhibition | v9.0-9.3 |
| **SST+** | Somatostatin | Distal dendrites | 25ms | Slow dendritic inhibition | v9.1 |
| **VIP+** | VIP | SST+ cells | 50ms | Disinhibition, attention | v9.4 |

### 7.2 PV+ Basket Cells (pv_interneuron.v, v9.2)

Fast-spiking GABAergic interneurons providing perisomatic inhibition:

**Leaky Integrator Model:**
```
dPV/dt = -PV/tau + K_EXCITE × pyramid_input
```

Discrete implementation:
```
pv_state[n+1] = pv_state[n] + alpha × (K_EXCITE × input - pv_state[n])
inhibition = K_INHIB × pv_state
```

**Constants (Q14):**
```
TAU_INV  = 819   (0.05)  - alpha = dt/tau = 0.25ms/5ms
K_EXCITE = 8192  (0.5)   - Pyramidal → PV+ gain
K_INHIB  = 4915  (0.3)   - PV+ → Pyramidal inhibition
```

**PING Dynamics:**
- Pyramidal excitation → PV+ activation → Pyramidal inhibition → Release → Next cycle
- Creates gamma oscillation (~40-65 Hz) through E-I loop
- PV+ phase lags pyramidal by ~90°

### 7.3 Cross-Layer PV+ Network (v9.3)

Three PV+ populations provide inhibition to L2/3:

```
                    ┌─────────────────────────────────────┐
                    │           LAYER 2/3                 │
                    │                                     │
L2/3 Pyramids ────▶ │ ◀─── pv_l23 (1.0×) ──── local PING │
                    │                                     │
L4 Pyramids ──────▶ │ ◀─── pv_l4 (0.5×) ─── feedforward │
                    │                                     │
L5b Pyramids ─────▶ │ ◀─── pv_l5 (0.25×) ─── feedback   │
                    │                                     │
                    └─────────────────────────────────────┘
```

**Combined Inhibition:**
```
pv_total = pv_l23 + (pv_l4 >>> 1) + (pv_l5 >>> 2)
l23_input = l23_input_raw - pv_total
```

**Biological Basis:**
- **pv_l23**: Local PING creates gamma rhythm
- **pv_l4**: Feedforward inhibition gates sensory input
- **pv_l5**: Feedback inhibition provides top-down control

### 7.4 SST+ Martinotti Cells (layer1_minimal.v, v9.1)

Slow dendritic inhibition with GABA-B receptor kinetics:

**IIR Lowpass Filter:**
```
sst_activity[n] = sst_activity[n-1] + alpha × (gain_offset - sst_activity[n-1])
```

Where:
- `alpha = dt/tau = 0.25ms/25ms = 0.01` (SST_ALPHA = 164 in Q14)
- `gain_offset = K_MATRIX × matrix + K_FB1 × fb1 + K_FB2 × fb2`

**Biological Basis:**
- SST+ Martinotti cells target distal dendrites in L1
- GABA-B receptors have slow kinetics (~25ms time constant)
- Creates sustained inhibition that adapts slowly

### 7.5 VIP+ Disinhibitory Circuit (layer1_minimal.v, v9.4)

VIP+ interneurons inhibit SST+ cells, creating disinhibition:

```
Attention Signal ──▶ VIP+ IIR (tau=50ms)
                          │
                          ▼ vip_activity
                    ┌───────────┐
                    │ SST+ -    │
                    │ VIP+ =    │
                    │ effective │
                    └─────┬─────┘
                          ▼
                    sst_effective = max(0, sst - vip)
                          │
                          ▼
                    gain = 1.0 + sst_effective
                    clamp to [0.5, 1.5]
```

**VIP+ IIR Filter:**
```
vip_scaled = attention_input × K_VIP
vip_activity[n] = vip_activity[n-1] + alpha × (vip_scaled - vip_activity[n-1])
```

Where:
- `alpha = dt/tau = 0.25ms/50ms = 0.005` (VIP_ALPHA = 82 in Q14)
- `K_VIP = 8192 (0.5)` - attention scaling

**Disinhibition Logic:**
```
sst_minus_vip = sst_activity - vip_activity
// VIP+ can only reduce positive SST+, not push negative further
sst_effective = (sst_activity >= 0 && sst_minus_vip < 0) ? 0 : sst_minus_vip
```

**Effect on Gain:**

| Condition | SST+ | VIP+ | sst_effective | Gain |
|-----------|------|------|---------------|------|
| Baseline | 0 | 0 | 0 | 1.0 |
| High feedback | + | 0 | + | > 1.0 |
| High FB + attention | + | + | 0 | 1.0 |
| Low feedback | - | 0 | - | < 1.0 |
| Low FB + attention | - | + | more - | < 1.0 |

### 7.6 Complete Layer 1 Model (v9.4)

```
                    ┌────────────────────────────────────────────────┐
                    │              LAYER 1 (v9.4)                    │
                    │                                                │
Attention ──────────┼──▶ VIP+ IIR (tau=50ms) ───┐                   │
                    │                            │ vip_activity      │
                    │                            ▼                   │
Matrix + FB1 + FB2 ─┼──▶ SST+ IIR (tau=25ms) ──▶ ─ = sst_effective  │
                    │                                                │
                    │    sst_effective + 1.0 ──▶ clamp[0.5,1.5]     │
                    │                                     │          │
                    └─────────────────────────────────────┼──────────┘
                                                          ▼
                                                    apical_gain
                                                          │
                               ┌──────────────────────────┴───────────┐
                               ▼                                      ▼
                    L2/3 (basal + apical×gain)          L5 (basal + apical×gain)
```

---

## 8. Consciousness State System (config_controller.v, v8.0)

### 8.1 Five States

| Code | State | Description | Neural Signature |
|------|-------|-------------|------------------|
| 0 | **NORMAL** | Balanced waking | All bands active, MU=4 |
| 1 | **ANESTHESIA** | Propofol-like | Alpha dominant, gamma suppressed |
| 2 | **PSYCHEDELIC** | Enhanced binding | High gamma entropy, reduced alpha |
| 3 | **FLOW** | Motor-optimized | Enhanced beta, reduced alpha |
| 4 | **MEDITATION** | Theta coherence | Theta dominant, reduced beta |

### 8.2 MU Parameter Settings

| State | Theta | L6 | L5b | L5a | L4 | L2/3 |
|-------|-------|-----|-----|-----|-----|------|
| NORMAL | 4 | 4 | 4 | 4 | 4 | 4 |
| ANESTHESIA | 2 | 6 | 2 | 2 | 1 | 1 |
| PSYCHEDELIC | 4 | 2 | 4 | 4 | 6 | 6 |
| FLOW | 4 | 2 | 6 | 6 | 4 | 4 |
| MEDITATION | 4 | 4 | 2 | 2 | 2 | 2 |

### 8.3 MU Parameter Effects

- **MU = 1**: Weak oscillation, susceptible to extinction
- **MU = 2**: Stable but reduced amplitude
- **MU = 4**: Normal operation, amplitude stabilizes at r ≈ 1
- **MU = 6**: Enhanced amplitude, faster recovery from perturbation

---

## 9. Support Systems

### 9.1 Clock Enable Generator (clock_enable_generator.v, v6.0)

- System clock: 125 MHz
- Primary update rate: 4 kHz (divider = 31250)
- FAST_SIM mode: divider = 10 (~3000× speedup)
- Reserved 100 kHz path for future enhancements

### 9.2 Pink Noise Generator (pink_noise_generator.v, v5.5)

Voss-McCartney algorithm for 1/f spectrum:

- 16-bit LFSR (polynomial: x¹⁶ + x¹⁴ + x¹³ + x¹¹ + 1)
- 8 octave bands updated at rates 1/2ⁿ
- Sum produces pink spectrum
- Output: 18-bit signed centered noise

### 9.3 Output Mixer (output_mixer.v, v5.5)

Weighted combination for DAC output:

```
mixed = 0.4 × motor_L2/3_x + 0.3 × motor_L5a_x + 0.2 × pink_noise
dac_output = (mixed + 1.0) × 2048  // 12-bit, 0-4095
```

---

## 10. Top-Level Integration (phi_n_neural_processor.v, v9.4)

### 10.1 Complete Signal Flow

```
                         SR Frequency Drift (v8.5)
                                  │ drifting omega_dt[5]
                                  ▼
 External SR Fields ──▶ SR Harmonic Bank ──▶ sr_gains[5]
                                                 │
                                                 ▼
            ┌──────────────────────────────────────────────────┐
            │                   THALAMUS                        │
            │                                                   │
 Sensory ──▶│  Core: theta oscillator (5.89 Hz)                │
            │        ← SR entrainment when beta quiet          │
            │        ← L6 CT inhibition + TRN amplification    │
            │                                                   │
            │  Matrix: L5b average → theta_gate → broadcast    │
            │                                                   │
            │  Outputs: theta_x, theta_phase, encoding_window  │
            │           matrix_output (to all L1)              │
            └──────────────────────────────────────────────────┘
                         │                           │
                         ▼                           │
            ┌────────────────────────┐               │
            │    CA3 PHASE MEMORY    │               │
            │                        │               │
            │ cortical_pattern[6] ──▶│               │
            │ ──▶ Hebbian weights   │               │
            │ ──▶ phase_pattern[6]  │               │
            └────────────────────────┘               │
                         │                           │
                         ▼                           ▼
            ┌────────────────────────────────────────────────┐
            │              CORTICAL COLUMNS ×3               │
            │                                                │
            │  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
            │  │ Sensory  │  │  Assoc   │  │  Motor   │     │
            │  │          │  │          │  │          │     │
            │  │ L1←matrix│  │ L1←matrix│  │ L1←matrix│     │
            │  │ L1←fb1,2 │  │ L1←fb1,2 │  │ L1←fb1,2 │     │
            │  │ L1: SST+ │  │ L1: SST+ │  │ L1: SST+ │     │
            │  │     VIP+ │  │     VIP+ │  │     VIP+ │     │
            │  │          │  │          │  │          │     │
            │  │ L2/3←pv3 │  │ L2/3←pv3 │  │ L2/3←pv3 │     │
            │  │ L4─┬────────────────────────────────▶L5a   │
            │  │ L5a←L6   │  │ L5a←L6   │  │ L5a←L6   │     │
            │  │ L5b─────────▶ Thalamus (matrix input)      │
            │  │ L6──────────▶ Thalamus (CT inhibition)     │
            │  └──────────┘  └──────────┘  └──────────┘     │
            └────────────────────────────────────────────────┘
                                   │
                                   ▼
                           Output Mixer ──▶ 12-bit DAC
```

### 10.2 Module Hierarchy

```
phi_n_neural_processor (top) - v9.4
├── clock_enable_generator
├── sr_noise_generator
├── sr_frequency_drift (v8.5)
├── config_controller (v8.0)
├── thalamus (v8.8)
│   ├── hopf_oscillator (theta 5.89 Hz)
│   ├── sr_harmonic_bank (v7.4)
│   │   └── hopf_oscillator_stochastic ×5
│   ├── matrix thalamic computation
│   └── L6 CT inhibition computation
├── ca3_phase_memory (v8.0)
├── cortical_column (sensory) - v9.4
│   ├── layer1_minimal (v9.4) - SST+, VIP+
│   ├── pv_interneuron ×3 (v9.2) - L2/3, L4, L5
│   └── hopf_oscillator ×5
├── cortical_column (association) - v9.4
│   ├── layer1_minimal (v9.4)
│   ├── pv_interneuron ×3
│   └── hopf_oscillator ×5
├── cortical_column (motor) - v9.4
│   ├── layer1_minimal (v9.4)
│   ├── pv_interneuron ×3
│   └── hopf_oscillator ×5
├── pink_noise_generator
└── output_mixer
```

### 10.3 Resource Summary

| Component | Count | Notes |
|-----------|-------|-------|
| Hopf oscillators | 21 | 16 deterministic + 5 stochastic |
| PV+ interneurons | 9 | 3 per column (L2/3, L4, L5) |
| SST+/VIP+ circuits | 3 | 1 per column (in L1) |
| Hebbian weights | 36 | 8-bit signed, 288 bits total |
| LFSRs | 11 | 5 SR noise + 5 SR drift + 1 pink |
| Consciousness states | 5 | Via state_select[2:0] |

---

## 11. Key Innovations

1. **φⁿ Frequency Architecture**: All cortical frequencies related by golden ratio, creating natural harmonic relationships without integer resonance artifacts

2. **Complete Interneuron Microcircuit**: Three canonical classes (PV+/SST+/VIP+) with biologically accurate time constants and connectivity

3. **Disinhibitory Attention Gating**: VIP+→SST+→Pyramid circuit enables selective enhancement via attention input

4. **Cross-Layer PV+ Network**: Three PV+ populations (L2/3, L4, L5) provide layered inhibition with feedforward and feedback components

5. **Theta Phase Multiplexing**: 8-phase theta cycle enables time-division multiplexing of encoding vs retrieval computations

6. **Gamma-Theta Nesting**: Fast gamma (65 Hz) during encoding, slow gamma (40 Hz) during retrieval, matching empirical PAC observations

7. **Scaffold-Plastic Separation**: Stable layers (L4, L5b) maintain context while plastic layers (L2/3, L6) integrate new information

8. **Dual Thalamocortical Pathways**: Core (L4) for precise relay, Matrix (L1) for diffuse attention modulation

9. **Layer 1 Gain Modulation**: Molecular layer integrates matrix + feedback inputs to produce apical gain [0.5, 1.5]

10. **SR Frequency Drift**: Bounded random walk models realistic hours-scale SR variation, preventing artificial coherence

11. **Continuous SR Gain**: Replaces binary SIE switching with smooth coherence × beta modulation

12. **Corticothalamic Inhibition**: L6 CT neurons modulate thalamic relay with TRN amplification

---

## 12. Test Coverage Summary

220+ automated tests across 17+ testbenches, all passing as of v9.4.

### Key Testbenches

| Testbench | Tests | Version | Coverage |
|-----------|-------|---------|----------|
| tb_full_system_fast | 15 | v6.5 | Full integration, all features |
| tb_vip_disinhibition | 8 | v9.4 | VIP+ attention gating |
| tb_pv_crosslayer | 8 | v9.3 | Cross-layer PV+ network |
| tb_pv_feedback | 8 | v9.2 | PING network dynamics |
| tb_sst_dynamics | 8 | v9.1 | SST+ slow dynamics |
| tb_pv_minimal | 6 | v9.0 | PV+ basket cell |
| tb_l6_connectivity | 10 | v8.8 | L6→L5a, L4→L5a, L6→Thalamus |
| tb_layer1_minimal | 10 | v8.7 | Layer 1 gain modulation |
| tb_canonical_microcircuit | 20 | v8.6 | Canonical pathway verification |
| tb_sr_frequency_drift | 30 | v8.5 | Drift bounds, random walk |
| tb_gamma_theta_nesting | 7 | v8.4 | L2/3 frequency switching |
| tb_theta_phase_multiplexing | 19 | v8.3 | 8-phase cycle, windows |
| tb_scaffold_architecture | 14 | v8.0 | Scaffold/plastic differentiation |
| tb_multi_harmonic_sr | 17 | v7.3 | Per-harmonic coherence |
| tb_learning_fast | 8 | v2.1 | CA3 Hebbian learning |
| tb_sr_coupling | 12 | v7.2 | SR coupling tests |
| tb_v55_fast | 6 | v5.5 | Fast integration tests |

---

## 13. Version History

| Version | Date | Key Changes |
|---------|------|-------------|
| **v9.4** | **2025-12-27** | **VIP+ disinhibition for attention gating (Phase 5 complete)** |
| v9.3 | 2025-12-27 | Cross-layer PV+ network (L4, L5 populations) |
| v9.2 | 2025-12-27 | PV+ PING network with dynamic E-I loop |
| v9.1 | 2025-12-27 | SST+ explicit slow dynamics (IIR filter) |
| v9.0 | 2025-12-27 | PV+ minimal amplitude-proportional inhibition |
| v8.8 | 2025-12-27 | L6 output connectivity: L6→L5a, L4→L5a bypass, L6→Thalamus+TRN |
| v8.7 | 2025-12-26 | Layer 1, dual feedback, matrix thalamic pathway |
| v8.6 | 2025-12-26 | Canonical microcircuit: L2/3→L5, L5b→L6 |
| v8.5 | 2025-12-26 | SR frequency drift with bounded random walk |
| v8.4 | 2025-12-25 | Gamma-theta nesting implementation |
| v8.3 | 2025-12-25 | DC offset fix for theta phase detection |
| v8.0 | 2025-12-24 | Scaffold architecture, theta phase multiplexing |
| v7.4 | 2025-12-23 | Continuous SR gain (replaces binary SIE) |
| v7.3 | 2025-12-22 | Multi-harmonic SR bank |
| v6.0 | 2025-12-21 | Hopf amplitude stabilization, 4 kHz update |
| v5.5 | 2025-12-20 | Pink noise, output mixer |

---

## 14. Future Roadmap

| Phase | Version | Feature | Status |
|-------|---------|---------|--------|
| 5 | v9.4 | VIP+ Disinhibition | ✅ Complete |
| 10 | v9.5+ | ACh Neuromodulation | Planned |
| 11 | v9.6+ | NE Neuromodulation | Planned |
| 12 | v9.8+ | Slow Oscillations (<1 Hz) | Planned |
| 13 | v9.10+ | Sleep Spindles (11-16 Hz) | Planned |
| 14 | v9.11+ | Multiple Gamma Sub-bands | Planned |
| 15 | v9.12+ | Lognormal Synaptic Weights | Planned |
