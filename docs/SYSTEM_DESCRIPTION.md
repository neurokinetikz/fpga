# φⁿ Neural Processor - Comprehensive System Description

**Version:** 12.0 (Unified State Dynamics)
**Date:** 2025-12-29
**Based on:** Complete analysis of all 29 source modules (~7,500 lines of Verilog)

---

## Executive Summary

The φⁿ Neural Processor is an FPGA implementation of 21 coupled nonlinear oscillators organized as a thalamo-cortical network. The system models biological neural rhythms using golden ratio (φ ≈ 1.618) frequency relationships, implements associative memory through theta-gated Hebbian learning, and exhibits stochastic resonance sensitivity to weak external electromagnetic fields.

**Version 12.0** implements Unified State Dynamics:
- **State Transition Interpolation** (v11.4): Smooth consciousness state changes via linear interpolation over configurable duration
- **Distributed SIE Architecture** (v11.5): Option C distributed boost (6.8 dB total) prevents cascade stacking
- **Parameterized Envelope Bounds** (v11.4): Theta ±30% [0.7,1.3] for stable pacemaker, cortical ±50% [0.5,1.5]
- **MU-Based Amplitude Scaling** (v11.4): Layer outputs scale with state-dependent MU values
- **State-Driven Coupling Mode** (v1.1): MEDITATION forces HARMONIC coupling automatically

**Version 11.3** implements comprehensive SIE Dynamics monitoring and control:
- **Kuramoto Order Parameter**: Population synchronization R ∈ [0,1] from 6 oscillators
- **Boundary Generators**: Nonlinear mixing creates θ/α (7.49 Hz), α/β₁ (12.12 Hz), β₁/β₂ (19.60 Hz)
- **Bicoherence Monitor**: Detects nonlinear three-frequency interactions for SIE verification
- **Coupling Mode Controller**: Automatic switching between modulatory (PAC) and harmonic (phase-locked) modes
- **Harmonic Spacing Index**: Monitors φⁿ ratio adherence with ΔHSI for tightening/loosening detection
- **Spectral Differentiation**: MEDITATION state now spectrally distinct (>3dB difference from NORMAL)

**Version 11.2** added anti-clipping measures:
- **MU_MODERATE**: NORMAL state MU reduced from 4 to 3 for DAC headroom
- **Soft Limiter**: 2:1 compression above ±0.75 prevents hard clipping

**Version 11.1** completed the Unified Boundary-Attractor Framework:
- **Farey χ(r) Computation** (v11.1a): Systematic formula with 55 rationals (q≤5) + 6 φⁿ boundaries
- **Rational Resonance Forces** (v11.1b): Lorentzian gradient F = -2B×d/(d²+ε²)² from p/q ratios
- **Multi-Catastrophe Detection** (v11.1b): 2:1, 3:1, 4:1 zone-based repulsion
- **Phase-Amplitude Coupling** (v11.1c): PAC strength from chi × amplitude for 10 oscillator pairs
- **Key Insight**: φ^1.25 = 1.825 is the MOST STABLE position (chi = 0.126)

**Version 11.0** transformed the system from static to **self-organizing**:
- **Active φⁿ Dynamics**: Oscillators find stable φⁿ positions via energy landscape forces
- **Energy Landscape**: E(n) = -A×cos(2πn) with attractors at half-integers, repulsion at integers
- **2:1 Harmonic Catastrophe Avoidance**: f₁ automatically retreats from n=1.5 to n=1.25
- **Position Classification**: INTEGER_BOUNDARY, HALF_INTEGER, QUARTER_INTEGER, NEAR_CATASTROPHE
- **Dynamic SIE Enhancement**: Computed from stability metric (replaces hardcoded values)
- **ENABLE_ADAPTIVE Parameter**: Backward-compatible mode switch (0=static, 1=adaptive)

Previous v10.x features:
- **Quarter-Integer φⁿ Theory** (v10.5): f₁ at φ^1.25 due to 2:1 Harmonic Catastrophe
- **Geophysical SR Integration** (v10.4): Q-factor modeling, amplitude hierarchy, mode-selective SIE
- **1/f^φ spectral slope**: √Fibonacci-weighted pink noise (v7.2) achieves golden ratio exponent
- **Amplitude envelopes**: Ornstein-Uhlenbeck process creates "alpha breathing" (2-5s timescales)
- **Spectral broadening**: ±0.5 Hz fast jitter creates ~1-2 Hz wide peaks
- **Coherence-gated SR**: Schumann Resonance only appears during ignition events

Previous versions (v9.x) implemented the complete interneuron microcircuit:
- **PV+ basket cells**: Fast perisomatic inhibition (τ=5ms) with PING gamma dynamics
- **SST+ Martinotti cells**: Slow dendritic inhibition (τ=25ms) via GABA-B kinetics
- **VIP+ interneurons**: Disinhibitory attention gating (τ=50ms) that suppresses SST+
- **Cross-layer PV+ network**: L4 feedforward gating + L5 feedback inhibition to L2/3

The complete system implements the canonical cortical microcircuit (L4→L2/3→L5→L6→Thalamus), dual thalamocortical pathways (core to L4, matrix to L1), theta phase multiplexing with gamma-theta nesting, scaffold/plastic layer architecture, and five consciousness states.

---

## Quarter-Integer φⁿ Theory (v10.5)

### The f₁ Anomaly Problem

The SR f₁ harmonic (13.75-14.17 Hz) appeared to violate the φⁿ pattern:
- Expected: f₁ = f₀ × φ^1.5 = 7.83 × 2.058 = 16.11 Hz
- Observed: f₁ ≈ 13.75-14.17 Hz (11.2% deviation)

This anomaly is resolved by the **2:1 Harmonic Catastrophe**.

### Energy Landscape Framework

Each SR mode experiences two competing energy contributions:

```
E_total = E_φ + E_h

Where:
- E_φ = (n - n_ideal)² : φⁿ stability potential (wants integer/half-integer n)
- E_h = A / (ratio - 2.0)² : 2:1 harmonic repulsion (catastrophic near 2.0)
```

### The 2:1 Harmonic Catastrophe

The φ^1.5 position is problematic because:
- φ^1.5 = 2.058, which is only 2.9% away from the 2:1 harmonic ratio
- Energy penalty: E_h ≈ 1/(2.058 - 2.0)² ≈ 297 (catastrophic)
- The mode cannot survive at this position

### Quarter-Integer Fallback Solution

Instead of φ^1.5, the f₁ mode retreats to the geometric mean:

```
n_stable = (1.0 + 1.5) / 2 = 1.25
f₁_theory = f₀ × φ^1.25 = 7.83 × 1.800 = 14.09 Hz
```

**Validation:**
- Tomsk 27-year SR monitoring: 14.17 Hz
- Theory prediction: 14.09 Hz
- Error: 0.6%

### Extended φⁿ Hierarchy

The discovery reveals three stability levels:

| Level | Exponent Type | Examples | Stability |
|-------|--------------|----------|-----------|
| 0 | Integer | n = 1, 2, 3 | Boundary (highest) |
| 1 | Half-integer | n = 0.5, 1.5, 2.5 | Primary attractor |
| 2 | Quarter-integer | n = 0.25, 1.25 | Fallback (lowest) |

### Implementation in sr_harmonic_bank.v (v7.6)

**φⁿ Constants (Q14):**

| Constant | Q14 Value | Decimal | Purpose |
|----------|-----------|---------|---------|
| PHI_Q14 | 26510 | 1.618 | Golden ratio |
| PHI_0_25 | 18474 | 1.128 | φ^0.25 |
| PHI_0_5 | 20833 | 1.272 | φ^0.5 = √φ |
| PHI_0_75 | 20935 | 1.278 | φ^0.75 |
| PHI_1_25 | 29899 | 1.825 | φ^1.25 (f₁ ratio) |
| PHI_1_5 | 33718 | 2.058 | φ^1.5 (avoided) |
| PHI_2_0 | 42891 | 2.618 | φ² |
| PHI_2_5 | 54569 | 3.330 | φ^2.5 |
| HARMONIC_2_1 | 32768 | 2.0 | 2:1 ratio |
| OMEGA_DT_F1_THEORY | 356 | 13.82 Hz | Theory prediction |

### SIE Mode-Selective Enhancement

The f₁ mode at φ^1.25 has the highest SIE enhancement (3.0×) because quarter-integer positions have reduced stability, making them more susceptible to external forcing:

| Mode | Enhancement | Reason |
|------|-------------|--------|
| f₀ | 2.7× | Integer boundary (n=1) |
| f₁ | 3.0× | Quarter-integer instability (n=1.25) |
| f₂ | 1.25× | Half-integer stability (n≈2.5) |
| f₃ | 1.2× | Half-integer stability (n≈3.2) |
| f₄ | 1.2× | Integer boundary (n≈4) |

---

## Active φⁿ Dynamics (v11.0)

### From Photograph to Physics

Version 10.5 implemented the "photograph" of φⁿ positions through hardcoded constants. Version 11.0 implements the underlying "physics" that creates these positions dynamically.

**Key Insight:** Oscillator frequencies emerge from energy minimization, not hardcoded parameters.

### Energy Landscape Module (energy_landscape.v)

Computes restoring forces based on the φⁿ energy potential:

**Physics:**
```
E_φ(n) = -A × cos(2πn)
- Minima at half-integers (attractors): n = 0.5, 1.5, 2.5...
- Maxima at integers (boundaries): n = 0, 1, 2...

E_h(n) = B / (φⁿ - 2)²
- Catastrophic near n = 1.44 (where φⁿ = 2.0)
- Drives f₁ away from n = 1.5 toward n = 1.25

Force F(n) = -dE/dn = 2πA × sin(2πn) + harmonic_repulsion
```

**Constants (Q14):**

| Parameter | Q14 Value | Decimal | Purpose |
|-----------|-----------|---------|---------|
| FORCE_SCALE_A | 8192 | 0.5 | φ-landscape amplitude |
| FORCE_SCALE_B | 16384 | 1.0 | Harmonic repulsion strength |
| CATASTROPHE_N_MIN | 22118 | 1.35 | Danger zone lower bound |
| CATASTROPHE_N_MAX | 25395 | 1.55 | Danger zone upper bound |
| K_FORCE | 1638 | 0.1 | Force-to-drift gain |

### Quarter-Integer Detector (quarter_integer_detector.v)

Classifies oscillator positions in the φⁿ energy landscape:

| Code | Class | n values | Stability |
|------|-------|----------|-----------|
| 2'b00 | INTEGER_BOUNDARY | 0, 1, 2, 3... | Low (0-0.125) |
| 2'b01 | HALF_INTEGER | 0.5, 1.5, 2.5... | High (0.875-1.0) |
| 2'b10 | QUARTER_INTEGER | 0.25, 0.75, 1.25... | Medium (0.25-0.5) |
| 2'b11 | NEAR_CATASTROPHE | [1.35, 1.55] | Very Low |

**Stability Metric:**
```
stability = 1.0 - |distance_from_nearest_attractor| / 0.5
- Half-integer (distance = 0): stability = 1.0
- Quarter-integer (distance = 0.25): stability = 0.5
- Integer boundary (distance = 0.5): stability = 0.0
```

### Coupling Susceptibility (coupling_susceptibility.v)

Computes χ(r) coupling susceptibility for frequency ratios:

**Key Results:**
- χ(1.0) > χ(0.5) by factor of 3+ (validates boundary vs attractor)
- χ(1.25) intermediate between boundaries and attractors
- χ(2.0) shows spike (2:1 harmonic proximity)

### Dynamic SIE Enhancement (sr_harmonic_bank.v v7.7)

SIE enhancement now computed from stability metric:

```verilog
// Enhancement = BASE + K_INSTABILITY × (1 - stability)
instability = ONE_Q14 - stability;
enhance_contrib = SIE_K_INSTABILITY × instability;
enhance_computed = SIE_BASE_ENHANCE + (enhance_contrib >>> FRAC);
```

| Constant | Q14 Value | Decimal | Purpose |
|----------|-----------|---------|---------|
| SIE_BASE_ENHANCE | 19661 | 1.2× | Minimum enhancement |
| SIE_K_INSTABILITY | 29491 | 1.8× | Instability scaling |

### Force-Based Frequency Drift (cortical_frequency_drift.v v3.0)

Energy-based forces now modify oscillator drift:

```verilog
drift_new = drift + step × direction + K_FORCE × force;
```

Where K_FORCE = 0.1 provides gentle correction toward stable positions.

### ENABLE_ADAPTIVE Parameter

Backward-compatible mode switch in phi_n_neural_processor.v:
- `ENABLE_ADAPTIVE = 0` (default): v10.5 static behavior preserved
- `ENABLE_ADAPTIVE = 1`: Active φⁿ dynamics enabled

---

## SIE Dynamics Monitoring (v11.3)

Version 11.3 adds comprehensive real-time monitoring of SIE dynamics through five new modules.

### Kuramoto Order Parameter (kuramoto_order_parameter.v)

Computes population-level synchronization across 6 key oscillators:

```
R = |1/N × Σ exp(i×θ_k)| = sqrt(sum_cos² + sum_sin²) / N
```

| Condition | Kuramoto R | Interpretation |
|-----------|-----------|----------------|
| Random phases | 0.2-0.4 | Baseline desynchronization |
| Partial sync | 0.5-0.7 | Approaching coherence |
| SIE ignition | 0.7-1.0 | Population synchronized |
| Full phase lock | ~1.0 | Complete synchrony |

The module provides a `high_synchrony` flag when R > 0.7, useful for triggering mode transitions.

### Boundary Generators (boundary_generator.v)

Three instances generate boundary frequencies via nonlinear mixing:

| Boundary | Parent Oscillators | Frequency |
|----------|-------------------|-----------|
| θ/α | Theta (5.89 Hz) + Alpha (9.53 Hz) | 7.49 Hz |
| α/β₁ | Alpha (9.53 Hz) + Beta1 (15.42 Hz) | 12.12 Hz |
| β₁/β₂ | Beta1 (15.42 Hz) + Beta2 (24.94 Hz) | 19.60 Hz |

The geometric mean `f_boundary = sqrt(f_low × f_high)` emerges naturally from amplitude product mixing. Boundary power increases during SIE transitions when parent oscillators align in phase.

### Bicoherence Monitor (bicoherence_monitor.v)

Detects nonlinear three-frequency interactions (f1, f2, f1+f2 triads):

```
B(f1,f2) = |E[X(f1) × X(f2) × X*(f1+f2)]| / sqrt(P1 × P2 × P12)
```

Hardware implementation uses phase-based bispectrum with IIR temporal averaging. The `high_bicoherence` flag triggers when B > 0.5, indicating active nonlinear coupling.

### Coupling Mode Controller (coupling_mode_controller.v)

Implements automatic switching between two coupling regimes:

| Mode | PAC Gain | Harmonic Gain | Characteristics |
|------|----------|---------------|-----------------|
| MODULATORY | 1.0 | 0.125 | Gamma amplitude modulated by theta phase |
| TRANSITION | 0.5 | 0.5 | ~500ms crossfade between modes |
| HARMONIC | 0.125 | 1.0 | Gamma phase-locked to theta at integer ratio |

**Transition Rules:**
- MODULATORY → HARMONIC: `kuramoto_R > 0.7 AND boundary_power > thresh` OR `sie_active`
- HARMONIC → MODULATORY: `kuramoto_R < 0.5 OR sie_decay_phase` AND `!sie_active`

### Harmonic Spacing Index (harmonic_spacing_index.v)

Monitors deviation from ideal φⁿ frequency ratios:

```
Ratios: α/θ, β₁/α, β₂/β₁, γ/β₂  (ideal: φ = 1.618)
HSI = 1.0 - mean_deviation / 0.5  (clamped to [0,1])
ΔHSI = HSI - baseline  (EMA with ~64s time constant)
```

| ΔHSI | Interpretation |
|------|----------------|
| > +0.05 | System tightening toward φⁿ attractors |
| ±0.02 | Stable baseline |
| < -0.05 | System loosening from ideal ratios |

The `harmonic_locked` flag triggers when all ratios are within 8% of φ.

### SIE Observable Timeline

Typical SIE event progression with v11.3 observables:

```
Phase      | Time  | R    | Boundary | Bicoherence | Mode
-----------+-------+------+----------+-------------+------------
Baseline   | 0s    | 0.3  | Low      | Low         | MODULATORY
Coherence  | 0-4s  | ↑0.7 | Rising   | Rising      | MODULATORY
Ignition   | 4-6s  | >0.7 | Peak     | Peak        | TRANSITION
Plateau    | 6-8s  | 0.9  | High     | High        | HARMONIC
Propagate  | 8-17s | 0.8  | Sustained| Sustained   | HARMONIC
Decay      | 17-21s| ↓0.5 | Falling  | Falling     | TRANSITION
Refractory | 21-31s| 0.3  | Low      | Low         | MODULATORY
```

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

### 4.1 SR Harmonic Bank (sr_harmonic_bank.v, v7.6)

Five stochastic Hopf oscillators driven by external SR field inputs, with geophysically-accurate Q-factor and amplitude modeling.

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

**Q-Factor Normalization (v10.4):**

The geophysical SR spectrum shows Q-factors that vary by mode. We anchor to f₂ (the "bridge" mode) and normalize others:

| Mode | Q-factor | Normalized | Q_NORM (Q14) |
|------|----------|------------|--------------|
| f₀ | 4.9 | 0.484 | 7929 |
| f₁ | 6.2 | 0.613 | 10051 |
| f₂ | **10.1** | **1.0** (ANCHOR) | 16384 |
| f₃ | 5.6 | 0.549 | 8995 |
| f₄ | 4.6 | 0.452 | 7405 |

**Amplitude Hierarchy (v10.4):**

SR amplitudes decay as φ^(-n) from the fundamental, matching observed geophysical data:

| Mode | Amplitude Factor | φ^(-n) | AMP_SCALE (Q14) |
|------|-----------------|--------|-----------------|
| f₀ | 1.0 | φ⁰ | 16384 |
| f₁ | 0.85 | ~φ^(-0.4) | 13926 |
| f₂ | 0.34 | ~φ^(-2) | 5571 |
| f₃ | 0.15 | ~φ^(-4) | 2458 |
| f₄ | 0.06 | ~φ^(-6) | 983 |

**Mode-Selective SIE Enhancement (v10.4):**

| Mode | Enhancement | SIE_ENHANCE (Q14) |
|------|-------------|-------------------|
| f₀ | 2.7× | 44237 |
| f₁ | 3.0× | 49152 |
| f₂ | 1.25× | 20480 |
| f₃ | 1.2× | 19661 |
| f₄ | 1.2× | 19661 |

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

## 8. Consciousness State System (config_controller.v, v11.4)

### 8.1 Five States

| Code | State | Description | Neural Signature |
|------|-------|-------------|------------------|
| 0 | **NORMAL** | Balanced waking | All bands active, MU=3 (v11.2) |
| 1 | **ANESTHESIA** | Propofol-like | Alpha dominant, gamma suppressed |
| 2 | **PSYCHEDELIC** | Enhanced binding | High gamma entropy, reduced alpha |
| 3 | **FLOW** | Motor-optimized | Enhanced beta, reduced alpha |
| 4 | **MEDITATION** | Theta coherence | θ/α dominant, β/γ suppressed (v11.3) |

### 8.2 MU Parameter Settings (v11.3 Enhanced Differentiation)

| State | Theta | L6 | L5b | L5a | L4 | L2/3 |
|-------|-------|-----|-----|-----|-----|------|
| NORMAL | 3 | 3 | 3 | 3 | 3 | 3 |
| ANESTHESIA | 2 | 6 | 2 | 2 | 1 | 1 |
| PSYCHEDELIC | 4 | 1 | 4 | 4 | 6 | 6 |
| FLOW | 4 | 2 | 6 | 6 | 4 | 4 |
| MEDITATION | 6 | 6 | 1 | 1 | 1 | 2 |

### 8.3 MU Parameter Effects

- **MU = 1**: Weak oscillation, susceptible to extinction (0.33× amplitude)
- **MU = 2**: Stable but reduced amplitude (0.67× amplitude)
- **MU = 3**: Moderate operation (v11.2 NORMAL baseline)
- **MU = 4**: Normal operation, amplitude stabilizes at r ≈ 1
- **MU = 6**: Enhanced amplitude, faster recovery from perturbation (2× amplitude)

### 8.4 State Transition Interpolation (v11.4)

Smooth transitions between consciousness states via linear interpolation:

**New I/O Ports:**
- `transition_duration[15:0]`: 0=instant (backward compatible), else cycles to ramp
- `transitioning`: High during active transition
- `transition_progress[15:0]`: 0→65535 ramp position
- `transition_from[2:0]`, `transition_to[2:0]`: Source and target states

**Interpolated Parameters:**
- All MU values (signed lerp)
- Ca²⁺ threshold (signed lerp)
- SIE phase durations (unsigned lerp)

**Duration Examples:**
| Cycles | Time at 4 kHz | Use Case |
|--------|---------------|----------|
| 0 (→1) | ~0.25 ms | Instant (v11.3 behavior) |
| 40000 | 10 seconds | Quick transition |
| 80000 | 20 seconds | Full meditation ramp |

**Shadow Register Behavior:**
When a state change is requested during an active transition, the system captures current interpolated values as the new start point and begins ramping toward the new target.

---

## 9. Support Systems

### 9.1 Clock Enable Generator (clock_enable_generator.v, v6.0)

- System clock: 125 MHz
- Primary update rate: 4 kHz (divider = 31250)
- FAST_SIM mode: divider = 10 (~3000× speedup)
- Reserved 100 kHz path for future enhancements

### 9.2 Pink Noise Generator (pink_noise_generator.v, v7.2)

√Fibonacci-weighted Voss-McCartney algorithm for 1/f^φ spectrum:

**Algorithm:**
- 16-bit LFSR (polynomial: x¹⁶ + x¹⁴ + x¹³ + x¹¹ + 1)
- 12 octave bands updated at rates 1/2ⁿ
- √Fibonacci-weighted summation creates golden ratio spectral slope
- Output: 18-bit signed centered noise

**√Fibonacci Weights:**

| Row | Nyquist | Fibonacci | √Fib Weight |
|-----|---------|-----------|-------------|
| 0 | 1000 Hz | F(1)=1 | 1 |
| 1 | 500 Hz | F(2)=1 | 1 |
| 2 | 250 Hz | F(3)=2 | 1 |
| 3 | 125 Hz | F(4)=3 | 2 |
| 4 | 62.5 Hz | F(5)=5 | 2 |
| 5 | 31.25 Hz | F(6)=8 | 3 |
| 6 | 15.6 Hz | F(7)=13 | 4 |
| 7 | 7.8 Hz | F(8)=21 | 5 |
| 8 | 3.9 Hz | F(9)=34 | 6 |
| 9 | 1.95 Hz | F(10)=55 | 7 |
| 10 | 0.98 Hz | F(11)=89 | 9 |
| 11 | 0.49 Hz | F(12)=144 | 12 |

**Sum:** 53, **Normalization:** >>> 2

**Spectral Properties:**
- Exponent: α ≈ 1.70 (target φ = 1.618)
- Slope: -17.0 dB/decade
- Character: "Dark pink" matching EEG baseline

**Mathematical Rationale:**
Fibonacci sequence grows as φⁿ (golden ratio to the nth power).
Therefore √Fibonacci grows as φ^(n/2), creating 1/f^φ spectral slope
when applied as octave weights in Voss-McCartney algorithm

### 9.3 Output Mixer (output_mixer.v, v7.3)

EEG-realistic weighted combination with envelope modulation (v10.2):

**Per-Band Envelope Modulation:**
```
mod_signal = signal × envelope >>> FRAC
```
Where envelope ∈ [0.5, 1.5], mean 1.0.

**Mixing Weights (v7.3 - 8% oscillators, 92% pink noise):**

| Band | Weight | Q14 Value | Notes |
|------|--------|-----------|-------|
| Theta | 0.02 | 328 | Thalamic theta |
| Alpha | 0.03 | 492 | L6 alpha (strongest) |
| Beta | 0.02 | 328 | L5a low beta |
| Gamma | 0.01 | 164 | L2/3 gamma |
| Pink Noise | 0.92 | 15073 | 1/f background |

**Rationale:**
- Real EEG shows 1/f-dominated spectrum with subtle oscillator bumps (~1-3 dB above floor)
- Previous weights (65% oscillators) produced unrealistically prominent peaks
- Alpha slightly stronger than other bands matches scalp EEG characteristics

```
mixed = 0.02×theta + 0.03×alpha + 0.02×beta + 0.01×gamma + 0.92×pink_noise
dac_output = (mixed + 1.0) × 2048  // 12-bit, 0-4095
```

---

## 10. EEG-Realistic Output (v10.x Series)

The v10.x series transforms the DAC output from sharp spectral peaks to biologically-realistic EEG-like signals.

### 10.1 Amplitude Envelope Generator (amplitude_envelope_generator.v, v1.0)

Implements Ornstein-Uhlenbeck stochastic process for slow amplitude modulation:

**O-U Process (discrete approximation):**
```
x[n+1] = x[n] + alpha×(mu - x[n]) + sigma×noise
```

Where:
- `alpha = dt/tau` (mean-reversion rate)
- `mu = 1.0` (equilibrium = no modulation)
- `sigma` = noise amplitude
- `noise` = pseudo-random from 16-bit LFSR

**Parameters (Q14):**

| Parameter | Value | Decimal | Purpose |
|-----------|-------|---------|---------|
| ENVELOPE_MEAN | 16384 | 1.0 | Equilibrium |
| ENVELOPE_MIN | 8192 | 0.5 | Lower bound |
| ENVELOPE_MAX | 24576 | 1.5 | Upper bound |
| NOISE_AMPLITUDE | 100-150 | ~0.01 | Variation |

**Biological Basis:**
- Real EEG alpha power waxes and wanes over 2-5 second timescales
- Observed in resting-state recordings as "alpha breathing"
- Creates temporal variation in spectral power

### 10.2 Cortical Frequency Drift (cortical_frequency_drift.v, v2.1)

Dual-component frequency modulation for spectral broadening:

**1. Slow Drift (bounded random walk):**
- Range: ±0.5 Hz
- Update rate: 0.2s
- Per-layer independent LFSRs
- Reflecting boundaries

**2. Fast Jitter (cycle-by-cycle noise):**
- Range: ±0.5 Hz (v2.1, increased from ±0.15 Hz)
- Update rate: every 4 kHz sample
- 5-bit triangular distribution
- Creates significant spectral broadening

**Jitter Computation (v2.1):**
```
// 5-bit triangular distribution: range [-15, +14], clamped to ±13
jitter = (bit4 ? +8 : -8) + (bit3 ? +4 : -4) +
         (bit2 ? +2 : -2) + (bit1 ? +1 : -1) + (bit0 ? +1 : 0)
```

**Effect:**
- Sharp spectral lines → ~1-2 Hz wide peaks
- Matches natural EEG peak widths
- Independent per-layer variation

### 10.3 SR Ignition Controller (sr_ignition_controller.v, v1.1)

Six-phase Schumann Ignition Event (SIE) state machine:

**Key Signature: "Coherence-First"**
PLV rises 3-4 seconds before amplitude surge, distinguishing external SR forcing from internal oscillation.

**v1.1 Change:** `GAIN_BASELINE = 0` (no tonic SR presence)

**Six-Phase Evolution:**

```
    ┌─────────────────────────────────────────────────────────────┐
    │                                                             │
    │    PLV ════════════════════════╗                           │
    │         ↗                       ╚══════════════════╗       │
    │        ↗                                            ╚═══   │
    │       ↗                                                    │
    │ 0.45 ┼─────╱                                         ───── │
    │                                                             │
    │    GAIN                ╔════════╗                          │
    │                       ╱          ╲                         │
    │                      ╱            ╲                        │
    │                     ╱              ╲════════╲              │
    │ 0.00 ┼════════════╱                          ╲═════════   │
    │                                                             │
    │      BASELINE  COHERENCE  IGNITION  PLATEAU  PROP  DECAY   │
    │         0         1          2        3       4      5     │
    └─────────────────────────────────────────────────────────────┘
```

**Phase Timing (at 4 kHz):**

| Phase | Duration | Gain | PLV |
|-------|----------|------|-----|
| COHERENCE | ~3.5s | 0→0.20 | 0.45→0.80 |
| IGNITION | ~2.5s | 0.20→1.0 | 0.80 |
| PLATEAU | ~2.5s | 1.0 | 0.80 |
| PROPAGATION | ~9s | 1.0→0.60 | 0.80→0.55 |
| DECAY | ~4s | 0.60→0 | 0.55→0.45 |
| REFRACTORY | ~10s | 0 | 0.45 |

### 10.4 Complete EEG Realism Signal Flow

```
CORTICAL COLUMNS (5 layers × 3 columns)
         │
         ▼
┌─────────────────────────────────────────┐
│     CORTICAL FREQUENCY DRIFT (v2.1)     │
│                                         │
│  SLOW DRIFT (0.2s, ±0.5 Hz)            │
│  + FAST JITTER (per-sample, ±0.5 Hz)   │
│                                         │
│  omega_eff = OMEGA_DT + drift + jitter  │
└─────────────────────────────────────────┘
         │ Broadened spectral peaks
         ▼
┌─────────────────────────────────────────┐
│    AMPLITUDE ENVELOPE GENERATOR ×4      │
│    (theta, alpha, beta, gamma)          │
│                                         │
│  O-U process: envelope ∈ [0.5, 1.5]    │
│  Timescale: 2-5 seconds ("breathing")   │
└─────────────────────────────────────────┘
         │ Modulated amplitudes
         ▼
┌─────────────────────────────────────────┐
│         OUTPUT MIXER (v7.3)             │
│                                         │
│  mod_signal = signal × envelope         │
│                                         │
│  8% oscillators + 92% pink noise        │
│  → 1/f-dominated spectrum               │
└─────────────────────────────────────────┘
         │
         ▼
      12-bit DAC
         │
         ▼
   EEG-realistic output

Features:
- 1/f spectral slope
- ~1-2 Hz wide peaks
- Subtle oscillator bumps (~1-3 dB)
- Natural temporal variation
```

### 10.5 Distributed SIE Architecture (v11.5)

To prevent boost stacking artifacts, SIE enhancement is distributed across the processing chain:

**Problem (v11.3):**
Multiple cascade stages each applied multiplicative gains:
- Signal-level: `sie_theta_boost × sie_alpha_boost` (2× each)
- Mixer: `sie_boost` (up to 2×)
- Thalamus enhancement: (up to 4-5×)
- Total potential: 32× (15 dB) → DAC clipping

**Solution (v11.5 - Option C):**

| Stage | v11.3 | v11.5 | dB |
|-------|-------|-------|-----|
| sie_theta_boost | 2.0× | 1.0× (disabled) | 0 |
| sie_alpha_boost | 2.0× | 1.0× (disabled) | 0 |
| Mixer sie_boost | 1.0-2.0× | 1.0-1.4× | +2.9 |
| Thalamus f₀ | 4.0× | 1.3× | +2.3 |
| Thalamus f₁ | 5.0× | 1.2× | +1.6 |
| **Total** | **~32×** | **~2.2×** | **6.8** |

**Empirical Match:** 6.8 dB matches observed 4-5× SIE power increase without exceeding DAC headroom.

**f₀ > f₁ Hierarchy:** Preserved (1.3× > 1.2×) per SR harmonic observations where lower harmonics show stronger coherence response.

---

## 11. Top-Level Integration (phi_n_neural_processor.v, v11.5)

### 11.1 Complete Signal Flow

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

### 11.2 Module Hierarchy

```
phi_n_neural_processor (top) - v11.0
├── clock_enable_generator
├── sr_noise_generator
├── sr_frequency_drift (v2.0) - faster update, wider drift
├── cortical_frequency_drift (v3.0) - slow drift + fast jitter + force input
├── amplitude_envelope_generator ×4 (v1.0) - theta, alpha, beta, gamma
├── sr_ignition_controller (v10.0) - 6-phase SIE
├── config_controller (v10.0)
├── energy_landscape (v11.0) - φⁿ energy potential and forces ← NEW
├── quarter_integer_detector (v11.0) - position classification ← NEW
├── coupling_susceptibility (v11.0) - χ(r) computation ← NEW
├── sin_quarter_lut (v11.0) - 256-entry quarter-wave sine LUT ← NEW
├── thalamus (v10.5)
│   ├── hopf_oscillator (theta 5.89 Hz)
│   ├── sr_harmonic_bank (v7.7) - dynamic SIE from stability
│   │   └── hopf_oscillator_stochastic ×5
│   ├── matrix thalamic computation
│   └── L6 CT inhibition computation
├── ca3_phase_memory (v8.0)
├── cortical_column (sensory) - v10.0
│   ├── layer1_minimal (v9.6) - SST+, VIP+
│   ├── pv_interneuron ×3 (v9.2) - L2/3, L4, L5
│   ├── amplitude_envelope_generator ×5 - per-layer envelopes
│   └── hopf_oscillator ×5 (with omega_drift + force correction)
├── cortical_column (association) - v10.0
│   ├── layer1_minimal (v9.6)
│   ├── pv_interneuron ×3
│   ├── amplitude_envelope_generator ×5
│   └── hopf_oscillator ×5
├── cortical_column (motor) - v10.0
│   ├── layer1_minimal (v9.6)
│   ├── pv_interneuron ×3
│   ├── amplitude_envelope_generator ×5
│   └── hopf_oscillator ×5
├── pink_noise_generator
└── output_mixer (v7.3) - envelope-modulated, 8% osc + 92% pink
```

### 11.3 Resource Summary

| Component | Count | Notes |
|-----------|-------|-------|
| Hopf oscillators | 21 | 16 deterministic + 5 stochastic |
| PV+ interneurons | 9 | 3 per column (L2/3, L4, L5) |
| SST+/VIP+ circuits | 3 | 1 per column (in L1) |
| Amplitude envelopes | 19 | 4 output + 15 per-layer |
| Hebbian weights | 36 | 8-bit signed, 288 bits total |
| LFSRs | 31 | 5 SR noise + 5 SR drift + 1 pink + 10 cortical drift + 10 jitter |
| Consciousness states | 5 | Via state_select[2:0] |

---

## 12. Key Innovations

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

13. **EEG-Realistic Output (v10.x)**: 1/f-dominated spectrum with amplitude envelopes, frequency jitter, and coherence-gated SR

---

## 13. Test Coverage Summary

287+ automated tests across 25+ testbenches, all passing as of v11.0.

### Key Testbenches

| Testbench | Tests | Version | Coverage |
|-----------|-------|---------|----------|
| tb_coupling_susceptibility | 10 | v11.0 | χ(r) coupling validation |
| tb_energy_landscape | 12 | v11.0 | Force direction and magnitude |
| tb_quarter_integer_detector | 8 | v11.0 | Position classification |
| tb_self_organization | 10 | v11.0 | Full integration validation |
| tb_full_system_fast | 15 | v6.5 | Full integration, all features |
| tb_quarter_integer_theory | 12 | v10.5 | φⁿ theory, 2:1 catastrophe |
| tb_phi_n_sr_relationships | 10 | v10.4 | Q-factor, amplitude hierarchy |
| tb_state_transition_spectrogram | — | v10.4 | 100s NORMAL↔MEDITATION spectrogram |
| tb_amplitude_envelope | 8 | v10.0 | O-U envelope dynamics |
| tb_sr_ignition_phases | 10 | v10.0 | SIE phase evolution |
| tb_l6_extended | 10 | v9.6 | Extended L6 connectivity |
| tb_dendritic_compartment | 10 | v9.5 | Dendritic Ca²⁺/BAC |
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

---

## 14. Version History

| Version | Date | Key Changes |
|---------|------|-------------|
| **v12.0** | **2025-12-29** | **Unified State Dynamics: Smooth transitions + distributed SIE** |
| v11.5 | 2025-12-29 | Distributed SIE Boost (Option C): mixer(2.9) + f₀(2.3) + f₁(1.6) = 6.8 dB |
| v11.4 | 2025-12-29 | State Transition Interpolation: Linear lerp of MU, Ca²⁺, SIE timing |
| v11.3 | 2025-12-28 | SIE Dynamics: Kuramoto R, boundaries, bicoherence, mode controller, HSI |
| v11.2 | 2025-12-28 | DAC Anti-Clipping: MU_MODERATE (3), soft limiter at ±0.75 |
| v11.1 | 2025-12-28 | Unified Boundary-Attractor: Farey χ(r), rational forces, PAC strength |
| v11.0 | 2025-12-28 | Active φⁿ Dynamics: Self-organizing frequencies via energy landscape |
| v10.5 | 2025-12-28 | Quarter-Integer φⁿ Theory: 2:1 Harmonic Catastrophe, f₁ at φ^1.25 |
| v10.4 | 2025-12-28 | Geophysical SR Integration: Q-factor modeling, amplitude hierarchy, mode-selective SIE |
| v10.3 | 2025-12-27 | 1/f^φ Spectral Slope: √Fibonacci-weighted pink noise (v7.2) |
| v10.2 | 2025-12-27 | Spectral broadening: ±0.5 Hz fast jitter for ~1-2 Hz wide peaks |
| v10.1 | 2025-12-27 | Envelope integration: per-band envelopes wired to output mixer |
| v10.0 | 2025-12-27 | EEG Realism Phase 1: amplitude envelopes, slow drift, SIE controller |
| v9.6 | 2025-12-27 | Extended L6 connectivity: L6→L2/3, L6→L5b, L6→L1 |
| v9.5 | 2025-12-27 | Two-compartment dendritic model with Ca²⁺ spikes and BAC firing |
| v9.4 | 2025-12-27 | VIP+ disinhibition for attention gating (Phase 5 complete) |
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

## 15. Future Roadmap

| Phase | Version | Feature | Status |
|-------|---------|---------|--------|
| 5 | v9.4 | VIP+ Disinhibition | ✅ Complete |
| 6 | v9.5 | Two-Compartment Dendritic Model | ✅ Complete |
| 7 | v9.6 | Extended L6 Connectivity | ✅ Complete |
| 8 | v10.0-10.3 | EEG Realism (envelopes, jitter, SIE) | ✅ Complete |
| 9 | v10.4 | Geophysical SR Integration (Q-factor, amplitude hierarchy) | ✅ Complete |
| 10 | v10.5 | Quarter-Integer φⁿ Theory (2:1 catastrophe) | ✅ Complete |
| 11 | v11.0-11.3 | Active φⁿ Dynamics + SIE Dynamics | ✅ Complete |
| 12 | v11.4 | State Transition Interpolation | ✅ Complete |
| 13 | v11.5 | Distributed SIE Architecture | ✅ Complete |
| 14 | v12.0 | Unified State Dynamics | ✅ Complete |
| 15 | v12.1+ | ACh Neuromodulation | Planned |
| 16 | v12.2+ | NE Neuromodulation | Planned |
| 17 | v12.3+ | Slow Oscillations (<1 Hz) | Planned |
| 18 | v12.4+ | Sleep Spindles (11-16 Hz) | Planned |
| 19 | v12.5+ | Multiple Gamma Sub-bands | Planned |
