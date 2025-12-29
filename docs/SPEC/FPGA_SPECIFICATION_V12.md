# φⁿ Neural Architecture FPGA Implementation
## Comprehensive Specification v12.0

**Version:** 12.0 (Unified State Dynamics)
**Date:** December 2024
**Author:** Neurokinetikz
**Status:** VERIFIED - 365+ Tests Passing
**Target Platform:** Digilent Zybo Z7-20 (Xilinx Zynq-7020)

---

# EXECUTIVE SUMMARY

This specification documents a biologically-realistic neural oscillator system implementing the φⁿ (golden ratio) frequency architecture with Schumann Resonance coupling. The system models thalamo-cortical dynamics with 21 Hopf oscillators organized into a coherent neural processor.

## Key System Features

| Feature | Implementation |
|---------|---------------|
| **Oscillator Count** | 21 Hopf oscillators (1 theta + 5 SR + 15 cortical) |
| **Frequency Architecture** | φⁿ golden ratio spacing (5.89 - 65.3 Hz) |
| **Fixed-Point Format** | Q4.14 (18-bit signed, 4 integer + 14 fractional) |
| **Update Rate** | 4 kHz (125 MHz system clock) |
| **Consciousness States** | 5 states with smooth interpolation |
| **SR Coupling** | 5-harmonic Schumann Resonance bank |
| **Learning** | Hebbian CA3 phase memory with theta gating |

## Version 12.0 Key Innovations

1. **Unified State Dynamics** - Smooth interpolation between consciousness states
2. **Distributed SIE Architecture** - 6.8 dB total boost without stacking artifacts
3. **MU-Based Amplitude Scaling** - State-dependent layer output amplitudes
4. **Parameterized Envelope Bounds** - Per-oscillator amplitude envelope customization
5. **State-Driven Coupling Mode** - MEDITATION forces HARMONIC coupling automatically

## Version History Summary

| Version | Key Feature |
|---------|-------------|
| v12.0 | Unified State Dynamics (current) |
| v11.3 | SIE Dynamics & Population Metrics |
| v11.2 | DAC Anti-Clipping |
| v11.1 | Unified Boundary-Attractor Framework |
| v11.0 | Active φⁿ Dynamics |
| v10.x | EEG Realism (envelopes, drift, spectral shaping) |
| v9.x | Neural Dynamics (dendrites, PV+, VIP+, L1) |
| v8.x | Dupret Integration (scaffold/plastic, theta phases) |

---

# TABLE OF CONTENTS

1. [System Architecture Overview](#1-system-architecture-overview)
2. [Hardware Platform](#2-hardware-platform)
3. [Mathematical Foundations](#3-mathematical-foundations)
4. [Core Modules](#4-core-modules)
5. [Neural Dynamics Modules](#5-neural-dynamics-modules)
6. [Self-Organization System](#6-self-organization-system)
7. [Metrics and Monitoring](#7-metrics-and-monitoring)
8. [SIE System](#8-sie-system)
9. [Signal Processing](#9-signal-processing)
10. [Consciousness State System](#10-consciousness-state-system)
11. [Constants Reference](#11-constants-reference)
12. [Verification and Testing](#12-verification-and-testing)
13. [Resource Utilization](#13-resource-utilization)

---

# 1. SYSTEM ARCHITECTURE OVERVIEW

## 1.1 System Block Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                           φⁿ NEURAL PROCESSOR v12.0                                     │
│                       (Unified State Dynamics Architecture)                              │
│                                                                                          │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                           CLOCK MANAGEMENT (FAST_SIM aware)                         │ │
│  │   125 MHz ───►[clock_enable_generator]───► 4 kHz clk_en (oscillator update rate)   │ │
│  │                    │ FAST_SIM=0: ÷31250 (real-time)                                 │ │
│  │                    │ FAST_SIM=1: ÷10 (simulation ~3000× speedup)                    │ │
│  └────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                          │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐   │
│  │                              EXTERNAL INPUTS                                      │   │
│  │   sensory_input[17:0]      ─────► Sensory data (THE ONLY external data path)     │   │
│  │   state_select[2:0]        ─────► Consciousness state (0-4)                       │   │
│  │   transition_duration[15:0]─────► State transition time (v11.4)                   │   │
│  │   sr_field_packed[89:0]    ─────► External Schumann field (5 × 18 bits)          │   │
│  └──────────────────────────────────────────────────────────────────────────────────┘   │
│                                        │                                                 │
│  ┌─────────────────────────────────────┼──────────────────────────────────────────────┐ │
│  │              CONFIG_CONTROLLER (v11.4 - State Transition Interpolation)           │ │
│  │                                     │                                              │ │
│  │   state_select ──┬──► LERP ──► mu_dt_theta, mu_dt_l6, mu_dt_l5b, mu_dt_l5a,       │ │
│  │                  │            mu_dt_l4, mu_dt_l23                                  │ │
│  │   transition_   │                                                                  │ │
│  │   duration ─────┘──► LERP ──► ca_threshold, sie_phase_durations                   │ │
│  │                                                                                    │ │
│  │   Outputs: transitioning, transition_progress[15:0], from/to states               │ │
│  └────────────────────────────────────┬───────────────────────────────────────────────┘ │
│                                       │                                                  │
│  ┌────────────────────────────────────┼───────────────────────────────────────────────┐ │
│  │                    SR STOCHASTIC COMPONENTS                                        │ │
│  │                                    │                                               │ │
│  │   ┌─────────────────────┐  ┌───────┴────────┐  ┌─────────────────────────────┐   │ │
│  │   │ sr_noise_generator  │  │ sr_freq_drift  │  │ cortical_frequency_drift    │   │ │
│  │   │ 5 × LFSR white noise│  │ Hours-scale SR │  │ ±0.5 Hz drift + ±0.15 Hz   │   │ │
│  │   │ for SR oscillators  │  │ freq variation │  │ fast jitter per layer       │   │ │
│  │   └─────────────────────┘  └────────────────┘  └─────────────────────────────┘   │ │
│  └────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                          │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                    ENERGY LANDSCAPE (v11.0 - Active φⁿ Dynamics)                   │ │
│  │                                                                                    │ │
│  │   n_packed (exponents) ──► E(n) = -A×cos(2πn) + F_rational + F_catastrophe        │ │
│  │                                                                                    │ │
│  │   force_packed ──► cortical_frequency_drift (self-organizing corrections)         │ │
│  │                                                                                    │ │
│  │   quarter_integer_detector ──► position_class (INTEGER/HALF/QUARTER/CATASTROPHE)  │ │
│  └────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                          │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                   AMPLITUDE ENVELOPE GENERATORS (Ornstein-Uhlenbeck)               │ │
│  │                                                                                    │ │
│  │   Theta: [0.7, 1.3] (±30%)    Alpha/Beta/Gamma: [0.5, 1.5] (±50%)                 │ │
│  │   Creates biological "alpha breathing" effect (2-5 second timescale)              │ │
│  └────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                          │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                              THALAMUS (v11.5)                                      │ │
│  │                                                                                    │ │
│  │   ┌─────────────────────────────────────────────────────────────────────────────┐ │ │
│  │   │  THETA OSCILLATOR: 5.89 Hz (φ⁻⁰·⁵)                                          │ │ │
│  │   │    • Amplitude envelope: ±30% [0.7, 1.3] (stable pacemaker)                 │ │ │
│  │   │    • MU-scaled output for state-dependent amplitude                         │ │ │
│  │   │    • 8-phase cycle: phases 0-3 encoding, 4-7 retrieval                      │ │ │
│  │   └─────────────────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                                    │ │
│  │   ┌─────────────────────────────────────────────────────────────────────────────┐ │ │
│  │   │  SR HARMONIC BANK: 5 oscillators                                            │ │ │
│  │   │    f₀: 7.6 Hz   (SR fundamental)                                            │ │ │
│  │   │    f₁: 13.75 Hz (φ^1.25 quarter-integer fallback)                           │ │ │
│  │   │    f₂: 20 Hz    (anchor, highest Q-factor)                                  │ │ │
│  │   │    f₃: 25 Hz                                                                │ │ │
│  │   │    f₄: 32 Hz                                                                │ │ │
│  │   │                                                                             │ │ │
│  │   │  v11.5 Distributed SIE: f₀ +2.3dB (1.3×), f₁ +1.6dB (1.2×)                 │ │ │
│  │   └─────────────────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                                    │ │
│  │   ┌─────────────────────────────────────────────────────────────────────────────┐ │ │
│  │   │  MATRIX THALAMIC PATHWAY (POm/Pulvinar analog)                              │ │ │
│  │   │    L5b (all columns) ──► theta_gate ──► matrix_output ──► L1 (all columns)  │ │ │
│  │   └─────────────────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                                    │ │
│  │   Output: theta_gated_output ──────────────────────────────────────────────────►  │ │
│  └────────────────────────────────────┬───────────────────────────────────────────────┘ │
│                                       │                                                  │
│  ┌────────────────────────────────────┼───────────────────────────────────────────────┐ │
│  │                           CORTICAL SYSTEM (3 Columns × 6 Layers)                   │ │
│  │                                    │                                               │ │
│  │   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                        │ │
│  │   │   SENSORY    │───►│ ASSOCIATION  │───►│    MOTOR     │  Feedforward (L2/3)    │ │
│  │   │   COLUMN     │◄───│   COLUMN     │◄───│   COLUMN     │  Feedback (L5b)        │ │
│  │   │              │    │              │    │              │                         │ │
│  │   │ L1  (gain)   │    │ L1  (gain)   │    │ L1  (gain)   │  Molecular layer       │ │
│  │   │ L2/3 (γ) ◄PC │    │ L2/3 (γ) ◄PC │    │ L2/3 (γ) ◄PC │  40/65 Hz PLASTIC     │ │
│  │   │ L4  (φ³)     │◄θ──│ L4  (φ³)     │◄θ──│ L4  (φ³)     │  31.73 Hz SCAFFOLD    │ │
│  │   │ L5a (β₁)     │    │ L5a (β₁)     │    │ L5a (β₁)     │  15.42 Hz             │ │
│  │   │ L5b (β₂)     │    │ L5b (β₂)     │    │ L5b (β₂)     │  24.94 Hz SCAFFOLD    │ │
│  │   │ L6  (α)  ◄PC │    │ L6  (α)  ◄PC │    │ L6  (α)  ◄PC │  9.53 Hz PLASTIC      │ │
│  │   └──────┬───────┘    └──────┬───────┘    └──────┬───────┘                        │ │
│  │          │                   │                   │                                 │ │
│  │   PC = Phase Coupling from CA3    SCAFFOLD = stable backbone                      │ │
│  │                                   PLASTIC = flexible integration                   │ │
│  └──────────────────────────────────┬─────────────────────────────────────────────────┘ │
│                                     │ cortical_pattern[5:0]                              │
│                                     ▼                                                    │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                     CA3 PHASE MEMORY (v8.0 Theta Phase Multiplexing)               │ │
│  │                                                                                    │ │
│  │   theta_phase[2:0] ──► 8-phase encoding/retrieval windows                         │ │
│  │   Phases 0-3: Encoding (theta_x > 0)   Phases 4-7: Retrieval (theta_x < 0)        │ │
│  │                                                                                    │ │
│  │   Hebbian learning: weight += pattern_in[i] × pattern_in[j]                       │ │
│  │   Memory decay: -1 every 10 theta cycles when pattern_in = 0                      │ │
│  │                                                                                    │ │
│  │   phase_pattern[5:0] ──► phase coupling ──► L2/3 and L6 (PLASTIC layers)          │ │
│  └────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                          │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                        POPULATION METRICS (v11.3)                                  │ │
│  │                                                                                    │ │
│  │   ┌─────────────────┐  ┌─────────────────┐  ┌──────────────────────┐              │ │
│  │   │ kuramoto_order  │  │ pac_strength    │  │ coupling_mode_ctrl   │              │ │
│  │   │ R ∈ [0,1]       │  │ 10 oscillator   │  │ MODULATORY ↔ HARMONIC│              │ │
│  │   │ 6 core oscs     │  │ pairs           │  │ State-driven (v1.1)  │              │ │
│  │   └─────────────────┘  └─────────────────┘  └──────────────────────┘              │ │
│  │                                                                                    │ │
│  │   ┌─────────────────┐  ┌─────────────────┐  ┌──────────────────────┐              │ │
│  │   │ boundary_gen    │  │ bicoherence_mon │  │ harmonic_spacing_idx │              │ │
│  │   │ θ/α, α/β₁,      │  │ θ+α nonlinear   │  │ φⁿ ratio deviation   │              │ │
│  │   │ β₁/β₂ mixing    │  │ coupling detect │  │ HSI ∈ [0,1]          │              │ │
│  │   └─────────────────┘  └─────────────────┘  └──────────────────────┘              │ │
│  └────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                          │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                      SIE IGNITION CONTROLLER (v1.3 - Six-Phase FSM)                │ │
│  │                                                                                    │ │
│  │   coherence_in + beta_quiet ──► 6-phase state machine                             │ │
│  │                                                                                    │ │
│  │   ┌────────┐   ┌──────────┐   ┌─────────┐   ┌─────────┐   ┌───────┐   ┌────────┐ │ │
│  │   │BASELINE│──►│COHERENCE │──►│IGNITION │──►│ PLATEAU │──►│ DECAY │──►│REFRACT │ │ │
│  │   │PLV=0.45│   │PLV↑ first│   │Gain↑    │   │Peak hold│   │Exp↓   │   │No re-ig│ │ │
│  │   │Gain=0  │   │Gain=0.4  │   │Gain→1.0 │   │Gain=1.0 │   │Gain↓0 │   │Gain=0  │ │ │
│  │   └────────┘   └──────────┘   └─────────┘   └─────────┘   └───────┘   └────────┘ │ │
│  │       │                                                                      │      │ │
│  │       └──────────────────────────────────────────────────────────────────────┘      │ │
│  │                                                                                    │ │
│  │   Output: gain_envelope[17:0] ──► distributed to mixer + thalamus (6.8 dB total)  │ │
│  └────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                          │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                         OUTPUT MIXER (v7.19 - Dark Baseline)                       │ │
│  │                                                                                    │ │
│  │   5-Channel Mix:                                                                   │ │
│  │     • Theta (5.89 Hz)      × W_THETA × envelope × SIE_boost                       │ │
│  │     • Alpha (9.53 Hz)      × W_ALPHA × envelope × SIE_boost                       │ │
│  │     • Beta (15.42 Hz)      × W_BETA  × envelope                                   │ │
│  │     • Gamma (40.36 Hz)     × W_GAMMA × envelope                                   │ │
│  │     • Pink Noise (1/f^φ)   × W_PINK (98% modulatory, 85% harmonic)                │ │
│  │                                                                                    │ │
│  │   Coupling Mode Dynamic Mixing:                                                    │ │
│  │     MODULATORY: 98% pink, 0.25× osc (dark baseline)                               │ │
│  │     HARMONIC:   85% pink, 0.35× osc (meditation)                                  │ │
│  │                                                                                    │ │
│  │   v7.17: SIE boost [1.0, 1.4] (+2.9 dB contribution)                              │ │
│  │   v7.1:  Soft limiter at ±0.75 (2:1 compression to ±1.0)                          │ │
│  │                                                                                    │ │
│  │   mixed_output[17:0] ──► [+offset, >>3, clamp] ──► dac_output[11:0]               │ │
│  └────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                          │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                               OUTPUTS                                              │ │
│  │                                                                                    │ │
│  │   dac_output[11:0]        ─────► 12-bit DAC [0-4095]                              │ │
│  │   ca3_phase_pattern[5:0]  ─────► Current Hebbian pattern                          │ │
│  │   theta_phase[2:0]        ─────► 8-phase theta cycle                              │ │
│  │   sie_per_harmonic[4:0]   ─────► Per-harmonic SIE status                          │ │
│  │   state_transitioning     ─────► High during state interpolation                  │ │
│  │   kuramoto_R[17:0]        ─────► Population synchronization                       │ │
│  └────────────────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

## 1.2 Module Hierarchy

```
phi_n_neural_processor (top-level, v11.5)
├── clock_enable_generator (v6.0)
├── config_controller (v11.4)
│
├── sr_noise_generator
├── sr_frequency_drift (v2.0)
├── cortical_frequency_drift (v3.0)
│
├── energy_landscape (v11.1b)
├── quarter_integer_detector (v11.0)
│
├── amplitude_envelope_generator ×4 (v11.4)
│
├── sr_ignition_controller (v1.3)
│
├── thalamus (v11.5)
│   ├── hopf_oscillator (theta)
│   ├── sr_harmonic_bank (v7.7)
│   │   └── hopf_oscillator_stochastic ×5
│   └── amplitude_envelope_generator (theta, ±30%)
│
├── cortical_column ×3 (v10.0)
│   ├── layer1_minimal (v9.6)
│   ├── hopf_oscillator ×5 (L6, L5b, L5a, L4, L2/3)
│   ├── dendritic_compartment ×3 (v9.5)
│   └── pv_interneuron ×3 (v9.2)
│
├── ca3_phase_memory (v8.0)
│
├── pink_noise_generator (v7.2)
│
├── coupling_susceptibility (v11.1a)
├── pac_strength (v11.1c)
├── kuramoto_order_parameter (v11.3)
├── boundary_generator ×3 (v11.3)
├── bicoherence_monitor (v11.3)
├── coupling_mode_controller (v1.1)
├── harmonic_spacing_index (v11.3)
│
└── output_mixer (v7.19)
```

## 1.3 Signal Flow Summary

```
SENSORY PATH:
sensory_input ──► thalamus ──► theta_gate ──► cortical_columns ──► output_mixer ──► DAC

LEARNING PATH:
cortical_outputs ──► threshold ──► cortical_pattern ──► CA3 ──► phase_coupling ──► L2/3, L6

SR COUPLING PATH:
sr_field_packed ──► sr_harmonic_bank ──► coherence ──► ignition_ctrl ──► gain_envelope
                                                                            │
                                          thalamus SIE enhancement ◄────────┤
                                          mixer SIE boost ◄─────────────────┘

STATE CONTROL PATH:
state_select ──► config_controller ──► MU values ──► oscillator growth rates
            │                      └──► ca_threshold ──► dendritic compartments
            │
            └──► transition_duration ──► smooth interpolation over N cycles
```

## 1.4 21-Oscillator Topology

| # | Location | Frequency | φⁿ Exponent | OMEGA_DT | Purpose |
|---|----------|-----------|-------------|----------|---------|
| 1 | Thalamus | 5.89 Hz | φ⁻⁰·⁵ | 152 | Theta, learn/recall gating |
| 2 | SR f₀ | 7.6 Hz | — | 196 | Schumann fundamental |
| 3 | SR f₁ | 13.75 Hz | φ¹·²⁵ | 354 | Quarter-integer fallback |
| 4 | SR f₂ | 20 Hz | — | 514 | Anchor (highest Q) |
| 5 | SR f₃ | 25 Hz | — | 643 | High beta coupling |
| 6 | SR f₄ | 32 Hz | — | 823 | Gamma coupling |
| 7-9 | Cortex L6 ×3 | 9.53 Hz | φ⁰·⁵ | 245 | Alpha, gain control |
| 10-12 | Cortex L5a ×3 | 15.42 Hz | φ¹·⁵ | 397 | Low beta, motor |
| 13-15 | Cortex L5b ×3 | 24.94 Hz | φ²·⁵ | 642 | High beta, feedback |
| 16-18 | Cortex L4 ×3 | 31.73 Hz | φ³ | 817 | Thalamocortical |
| 19-21 | Cortex L2/3 ×3 | 40.36/65.3 Hz | φ³·⁵/φ⁴·⁵ | 1039/1681 | Gamma (theta-switched) |

---

# 2. HARDWARE PLATFORM

## 2.1 Target FPGA

| Specification | Value |
|---------------|-------|
| Board | Digilent Zybo Z7-20 |
| Device | Xilinx Zynq-7020 (XC7Z020-1CLG400C) |
| Logic Cells | 85,000 |
| LUTs | 53,200 |
| Flip-Flops | 106,400 |
| DSP48 Slices | 220 |
| Block RAM | 4.9 Mb (140 × 36Kb) |
| System Clock | 125 MHz (from PS) |

## 2.2 Fixed-Point Format: Q4.14

| Property | Value |
|----------|-------|
| Total Width | 18 bits |
| Sign | 1 bit (MSB) |
| Integer Bits | 4 bits |
| Fractional Bits | 14 bits |
| Range | [-8.0, +7.99994] |
| Resolution | 2⁻¹⁴ ≈ 0.000061 |
| Unity (1.0) | 16384 |

**Common Q14 Values:**
| Decimal | Q14 Value | Usage |
|---------|-----------|-------|
| 0.0 | 0 | Zero |
| 0.25 | 4096 | Quarter |
| 0.5 | 8192 | Half |
| 1.0 | 16384 | Unity |
| 1.618 | 26510 | φ (golden ratio) |
| 2.0 | 32768 | Double |

## 2.3 Clock Structure

| Clock | Frequency | Divider | Purpose |
|-------|-----------|---------|---------|
| clk | 125 MHz | — | System clock |
| clk_4khz_en | 4 kHz | ÷31250 (FAST_SIM=0) | Oscillator updates |
| clk_4khz_en | 12.5 MHz | ÷10 (FAST_SIM=1) | Fast simulation |

**Timing Relationships:**
- 4 kHz → 250 µs per update cycle
- 40 Hz gamma → 100 samples per cycle
- 5.89 Hz theta → 679 samples per cycle
- dt = 0.00025 seconds (used in OMEGA_DT calculations)

---

# 3. MATHEMATICAL FOUNDATIONS

## 3.1 Hopf Oscillator Dynamics

The core oscillator uses the Hopf normal form with amplitude correction:

**Continuous Form:**
```
dx/dt = μx - ωy - r²x + input_x
dy/dt = μy + ωx - r²y
r² = x² + y²
```

**Discrete Implementation (Euler):**
```verilog
dx = ((mu_dt × x - omega_dt × y - dt × r² × x) >>> FRAC) + input_x
dy = ((mu_dt × y + omega_dt × x - dt × r² × y) >>> FRAC)

x_next = x + dx
y_next = y + dy
```

**Amplitude Correction:**
Prevents Euler integration instability by clamping amplitude growth:
```verilog
correction = over_threshold ? [0.5, 1.0] : 1.0
x_final = (x_next × correction) >>> FRAC
y_final = (y_next × correction) >>> FRAC
```

**Parameters:**
| Name | Q14 Value | Description |
|------|-----------|-------------|
| DT | 4 | dt = 0.00025 for 4 kHz |
| R_SQ_TARGET | 16384 | Target radius² = 1.0 |
| R_SQ_THRESHOLD | 17408 | Correction trigger |
| INIT_X | 8192 | Fast startup (0.5) |
| INIT_Y | 0 | Initial y = 0 |

## 3.2 Golden Ratio (φⁿ) Frequency Architecture

The φⁿ frequency architecture places neural oscillators at golden ratio intervals:

**Golden Ratio:**
```
φ = (1 + √5) / 2 ≈ 1.618033988749895
```

**Frequency Formula:**
```
f_layer = f_reference × φⁿ

where:
  f_reference = 5.89 Hz (theta)
  n = exponent defining layer frequency
```

**Layer Frequencies:**

| Layer | n | φⁿ | Frequency | Formula Verification |
|-------|---|----|-----------|---------------------|
| L6 | 0.5 | 1.272 | 9.53 Hz | 5.89 × 1.272 = 7.49 Hz (≈) |
| L5a | 1.5 | 2.058 | 15.42 Hz | 5.89 × 2.618 = 15.4 Hz |
| L5b | 2.5 | 3.330 | 24.94 Hz | 5.89 × 4.236 = 24.9 Hz |
| L4 | 3.0 | 4.236 | 31.73 Hz | 5.89 × 5.387 = 31.7 Hz |
| L2/3 | 3.5 | 5.387 | 40.36 Hz | 5.89 × 6.854 = 40.4 Hz |
| L2/3 fast | 4.5 | 8.716 | 65.3 Hz | 5.89 × 11.09 = 65.3 Hz |

**OMEGA_DT Calculation:**
```
OMEGA_DT = round(2π × f_hz × dt × 2^FRAC)
         = round(2π × f_hz × 0.00025 × 16384)
         = round(25.7 × f_hz)
```

## 3.3 Energy Landscape and Self-Organization (v11.0)

The energy landscape provides restoring forces toward φⁿ attractor positions:

**Energy Function:**
```
E(n) = E_φ(n) + E_rational(n) + E_catastrophe(n)

E_φ(n) = -A × cos(2πn)           // Half-integer attractors
E_rational(n) = Σ B_q × 1/(n - p/q)²  // Rational resonance forces
E_catastrophe(n) = C × zone_active    // Harmonic catastrophe repulsion
```

**Force Computation:**
```
F(n) = -dE/dn = 2πA × sin(2πn) + F_rational + F_catastrophe
```

**Position Classification:**
| Class | n Value | Stability | Description |
|-------|---------|-----------|-------------|
| INTEGER_BOUNDARY | n ≈ 0, 1, 2... | Unstable | Integer boundaries |
| HALF_INTEGER | n ≈ 0.5, 1.5... | Stable | Attractors |
| QUARTER_INTEGER | n ≈ 0.25, 0.75... | Medium | Fallback positions |
| NEAR_CATASTROPHE | n ∈ [1.35, 1.55] | Unstable | 2:1 danger zone |

**2:1 Harmonic Catastrophe:**
- φ^1.5 = 2.058 is too close to 2:1 harmonic (ratio = 2.0)
- f₁ retreats to φ^1.25 = 1.825 (quarter-integer fallback)
- This explains f₁ = 13.75 Hz observation

## 3.4 Schumann Resonance Coupling Theory

**Stochastic Resonance Model:**
The brain doesn't generate SR frequencies—it TUNES INTO the external Schumann field when cortical beta activity is quiet:

```
                    ┌─────────────────────────┐
                    │ External Schumann Field │
                    │  f₀ = 7.6 Hz           │
                    │  f₁ = 13.75 Hz          │
                    │  f₂ = 20 Hz             │
                    └───────────┬─────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │   Beta Quiet Gate       │
                    │  β_factor = 1 - β/0.75  │
                    │  (meditation enables)   │
                    └───────────┬─────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │  Coherence Detection    │
                    │  PLV(SR, brain band)    │
                    └───────────┬─────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │  SIE Ignition           │
                    │  (6-phase state machine)│
                    └─────────────────────────┘
```

**Coherence-First Signature:**
Key distinguishing feature of external SR forcing:
- PLV rises 3-4 seconds BEFORE amplitude increases
- Creates hysteresis loop in Kuramoto R vs SR Power plot
- Distinguishes SR from internal oscillation artifacts

## 3.5 Kuramoto Order Parameter

Measures population-level synchronization:

**Formula:**
```
R × e^(iΨ) = (1/N) × Σ e^(iθ_k)

where:
  R = order parameter ∈ [0, 1]
  Ψ = mean phase
  θ_k = phase of oscillator k
  N = number of oscillators
```

**Implementation (without sqrt):**
```verilog
// Amplitude approximation: |z| ≈ max(|x|,|y|) + 0.4×min(|x|,|y|)
// Normalization: unit_x = x / amp, unit_y = y / amp
// Mean phasor: sum_cos = Σ unit_x, sum_sin = Σ unit_y
// R = sqrt(sum_cos² + sum_sin²)  [approximated]
```

---

# 4. CORE MODULES

## 4.1 phi_n_neural_processor.v (Top-Level, v11.5)

**Purpose:** Master orchestration module integrating all subsystems.

### Port Table

| Port | Width | Dir | Description |
|------|-------|-----|-------------|
| clk | 1 | I | 125 MHz system clock |
| rst | 1 | I | Synchronous reset (active high) |
| sensory_input | 18 | I | Q14 sensory data input |
| state_select | 3 | I | Consciousness state (0-4) |
| transition_duration | 16 | I | State transition cycles (0=instant) |
| sr_field_input | 18 | I | Single SR field (v7.2 compat) |
| sr_field_packed | 90 | I | 5 × 18-bit SR harmonics |
| dac_output | 12 | O | DAC output [0-4095] |
| debug_motor_l23 | 18 | O | Motor L2/3 gamma |
| debug_theta | 18 | O | Theta oscillator state |
| ca3_learning | 1 | O | CA3 in learning mode |
| ca3_recalling | 1 | O | CA3 in recall mode |
| ca3_phase_pattern | 6 | O | Current Hebbian pattern |
| cortical_pattern_out | 6 | O | Thresholded cortical pattern |
| f0_x, f0_y | 18 | O | SR f₀ oscillator state |
| f0_amplitude | 18 | O | SR f₀ amplitude |
| sr_f_x_packed | 90 | O | 5 × 18-bit SR x states |
| sr_coherence_packed | 90 | O | 5 × 18-bit coherences |
| sie_per_harmonic | 5 | O | Per-harmonic SIE flags |
| coherence_mask | 5 | O | High-coherence flags |
| sr_coherence | 18 | O | f₀ coherence (v7.2 compat) |
| sr_amplification | 1 | O | SIE active (any harmonic) |
| beta_quiet | 1 | O | SR-ready state |
| theta_phase | 3 | O | 8-phase theta cycle |
| state_transitioning | 1 | O | Active state transition |
| state_transition_progress | 16 | O | Transition ramp [0-65535] |
| state_transition_from | 3 | O | Source state |
| state_transition_to | 3 | O | Target state |

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| WIDTH | 18 | Data width |
| FRAC | 14 | Fractional bits |
| FAST_SIM | 0 | Simulation speedup |
| NUM_HARMONICS | 5 | SR harmonic count |
| SR_STOCHASTIC_ENABLE | 1 | Enable SR noise |
| SR_DRIFT_ENABLE | 1 | Enable SR freq drift |
| ENABLE_ADAPTIVE | 0 | Active φⁿ dynamics |

### v11.5 Key Change: Distributed SIE Boost
```verilog
// SIE signal-level boosts DISABLED (Option C distributed reduction)
// SIE gain now ONLY through mixer(1.4×) + thalamus(1.3×/1.2×)
wire signed [WIDTH-1:0] sie_theta_boost = ONE;  // Constant 1.0×
wire signed [WIDTH-1:0] sie_alpha_boost = ONE;  // Constant 1.0×
```

## 4.2 hopf_oscillator.v (v6.0)

**Purpose:** Core Hopf oscillator with amplitude correction.

### Port Table

| Port | Width | Dir | Description |
|------|-------|-----|-------------|
| clk | 1 | I | System clock |
| rst | 1 | I | Reset |
| clk_en | 1 | I | 4 kHz enable |
| mu_dt | 18 | I | Growth rate × dt |
| omega_dt | 18 | I | Angular frequency × dt |
| input_x | 18 | I | External input to x |
| x | 18 | O | x state |
| y | 18 | O | y state |
| amplitude | 18 | O | |x| + |y| estimate |

### Implementation Details

```verilog
// Radius squared computation
assign x_sq = x * x;
assign y_sq = y * y;
assign r_sq = x_sq + y_sq;
assign r_sq_scaled = r_sq[FRAC +: WIDTH];

// Hopf dynamics
assign dx = ((mu_dt_x - omega_dt_y - dt_r_sq_x) >>> FRAC) + input_x;
assign dy = ((mu_dt_y + omega_dt_x - dt_r_sq_y) >>> FRAC);

// Amplitude correction (prevents instability)
assign over_threshold = (r_sq_scaled > R_SQ_THRESHOLD);
assign correction = over_threshold ? [HALF, R_SQ_TARGET] : R_SQ_TARGET;
assign x_next = (x_raw * correction) >>> FRAC;
assign y_next = (y_raw * correction) >>> FRAC;
```

## 4.3 thalamus.v (v11.5)

**Purpose:** Theta oscillator + SR harmonic bank + matrix thalamic pathway.

### Port Table (Key Ports)

| Port | Width | Dir | Description |
|------|-------|-----|-------------|
| sensory_input | 18 | I | Sensory data |
| l6_alpha_feedback | 18 | I | L6 alpha for inhibition |
| mu_dt | 18 | I | Theta growth rate |
| omega_dt_packed | 90 | I | 5 × drifting SR omegas |
| sr_field_packed | 90 | I | External SR field |
| noise_packed | 90 | I | Per-harmonic noise |
| beta_amplitude | 18 | I | For SR gating |
| l5b_sensory/assoc/motor | 18 | I | Matrix pathway inputs |
| gain_envelope | 18 | I | SIE gain from controller |
| theta_gated_output | 18 | O | Gated sensory output |
| theta_x, theta_y | 18 | O | Theta state (MU-scaled) |
| theta_amplitude | 18 | O | Theta amplitude |
| theta_phase | 3 | O | 8-phase cycle |
| sr_f_x_packed | 90 | O | SR x states |
| sr_coherence_packed | 90 | O | Per-harmonic coherences |
| matrix_output | 18 | O | Diffuse L1 broadcast |

### v11.5 SIE Enhancement Factors

```verilog
// Distributed reduction (Option C)
localparam signed [WIDTH-1:0] SIE_ENHANCE_F0 = 18'sd21299;  // 1.3× (+2.3 dB)
localparam signed [WIDTH-1:0] SIE_ENHANCE_F1 = 18'sd19661;  // 1.2× (+1.6 dB)
localparam signed [WIDTH-1:0] SIE_ENHANCE_F2 = 18'sd20480;  // 1.25× (protected)
localparam signed [WIDTH-1:0] SIE_ENHANCE_F3 = 18'sd19661;  // 1.2×
localparam signed [WIDTH-1:0] SIE_ENHANCE_F4 = 18'sd19661;  // 1.2×
```

### Theta Phase Computation (8-phase)

```verilog
// DC removal with IIR low-pass filter
theta_y_avg <= theta_y_avg + ((theta_y - theta_y_avg) >>> 8);
theta_y_hp = theta_y - theta_y_avg;  // High-pass (AC only)

// Phase from truth table: {y_positive, y_rising, y_gt_half_amp}
case ({theta_y_positive, y_rising, y_gt_half_amp})
    3'b111: theta_phase = 3'd0;  // Early encoding
    3'b110: theta_phase = 3'd1;  // Late encoding (near peak)
    3'b100: theta_phase = 3'd2;  // Just past peak
    3'b101: theta_phase = 3'd3;  // Late falling
    3'b001: theta_phase = 3'd4;  // Early retrieval
    3'b000: theta_phase = 3'd5;  // Near trough
    3'b010: theta_phase = 3'd6;  // Just past trough
    3'b011: theta_phase = 3'd7;  // Late rising
endcase
```

## 4.4 cortical_column.v (v10.0)

**Purpose:** 6-layer cortical model with dendritic compartments.

### Layer Architecture

```
                     ┌──────────────────────────────────────────────────┐
                     │              CORTICAL COLUMN                      │
                     │                                                   │
   matrix_thalamic ──┤  ┌────────────────────────────────────────────┐  │
   feedback_1/2    ──┤  │  LAYER 1 (Molecular)                       │  │
   attention       ──┤  │  SST+ slow dynamics, VIP+ disinhibition    │  │
   l6_direct       ──┤  │  Output: apical_gain ──► L2/3, L5a, L5b   │  │
                     │  └────────────────────────────────────────────┘  │
                     │                    │                              │
                     │                    ▼                              │
   phase_couple    ──┤  ┌────────────────────────────────────────────┐  │
   (CA3 memory)      │  │  LAYER 2/3 (Gamma, 40/65 Hz) [PLASTIC]    │  │
                     │  │  Two-compartment dendrite + PV+ PING       │  │
                     │  │  Theta-switched: fast γ encoding, slow γ   │  │
                     │  │  retrieval                                  │  │
                     │  └────────────────────────────────────────────┘  │
                     │                    │                              │
                     │                    ▼                              │
   thalamic_theta  ──┤  ┌────────────────────────────────────────────┐  │
                     │  │  LAYER 4 (φ³, 31.73 Hz) [SCAFFOLD]        │  │
                     │  │  Thalamocortical input boundary            │  │
                     │  │  Stable backbone, no phase coupling        │  │
                     │  └────────────────────────────────────────────┘  │
                     │                    │                              │
                     │                    ▼                              │
                     │  ┌────────────────────────────────────────────┐  │
                     │  │  LAYER 5a (Low β, 15.42 Hz)               │  │
                     │  │  Motor output, two-compartment dendrite    │  │
                     │  │  Receives: L2/3 + L6 feedback + L4 bypass  │  │
                     │  └────────────────────────────────────────────┘  │
                     │                    │                              │
                     │                    ▼                              │
                     │  ┌────────────────────────────────────────────┐  │
                     │  │  LAYER 5b (High β, 24.94 Hz) [SCAFFOLD]   │  │
                     │  │  Subcortical projection, matrix thalamus   │  │
                     │  │  Two-compartment dendrite                  │  │
                     │  └────────────────────────────────────────────┘  │
                     │                    │                              │
                     │                    ▼                              │
   phase_couple    ──┤  ┌────────────────────────────────────────────┐  │
   (CA3 memory)      │  │  LAYER 6 (Alpha, 9.53 Hz) [PLASTIC]       │  │
                     │  │  Corticothalamic, gain control             │  │
                     │  │  Extended connectivity: L1, L5a, L5b, L2/3 │  │
                     │  └────────────────────────────────────────────┘  │
                     │                                                   │
                     │  Outputs: l23_x/y, l4_x, l5a_x/y, l5b_x/y, l6_x/y │
                     └──────────────────────────────────────────────────┘
```

### Layer Frequency Parameters

| Layer | OMEGA_DT | Frequency | Type |
|-------|----------|-----------|------|
| L6 | 245 | 9.53 Hz | PLASTIC |
| L5b | 642 | 24.94 Hz | SCAFFOLD |
| L5a | 397 | 15.42 Hz | Intermediate |
| L4 | 817 | 31.73 Hz | SCAFFOLD |
| L2/3 slow | 1039 | 40.36 Hz | PLASTIC |
| L2/3 fast | 1681 | 65.3 Hz | PLASTIC (encoding) |

### v9.6 Extended L6 Connectivity

```verilog
// L6 outputs to multiple targets (all basal compartment)
localparam signed [WIDTH-1:0] K_L6_L23 = 18'sd164;   // 0.01 - L6 → L2/3
localparam signed [WIDTH-1:0] K_L6_L5B = 18'sd328;   // 0.02 - L6 → L5b
localparam signed [WIDTH-1:0] K_L6_L5A = 18'sd328;   // 0.02 - L6 → L5a
// L6 → L1 handled by layer1_minimal (l6_direct_input)
```

## 4.5 sr_harmonic_bank.v (v7.7)

**Purpose:** 5-harmonic Schumann Resonance bank with per-harmonic coherence.

### SR Harmonic Frequencies

| Harmonic | Frequency | Drift Range | EEG Band Match |
|----------|-----------|-------------|----------------|
| f₀ | 7.6 Hz | ±0.9 Hz | Theta |
| f₁ | 13.75 Hz | ±1.1 Hz | Alpha |
| f₂ | 20 Hz | ±1.5 Hz | Low Beta |
| f₃ | 25 Hz | ±2.25 Hz | High Beta |
| f₄ | 32 Hz | ±3.0 Hz | Gamma |

### Q-Factor Normalization (v10.4)

Based on December 2025 geophysical observations:

| Harmonic | Q-factor | Normalized | Amplitude Scale |
|----------|----------|------------|-----------------|
| f₀ | 7.5 | 0.484 | 1.0 |
| f₁ | 9.5 | 0.613 | 0.85 (elevated) |
| f₂ | 15.5 | 1.0 (anchor) | 0.34 |
| f₃ | 8.5 | 0.549 | 0.15 |
| f₄ | 7.0 | 0.452 | 0.06 |

---

# 5. NEURAL DYNAMICS MODULES

## 5.1 ca3_phase_memory.v (v8.0)

**Purpose:** Hebbian learning with theta-phase multiplexing.

### 8-Phase Encoding/Retrieval Windows

| Phase | Theta Position | Window | Description |
|-------|----------------|--------|-------------|
| 0-1 | Rising to peak | Early encoding | Fast gamma, sensory |
| 2-3 | Falling from peak | Late encoding | Pattern consolidation |
| 4-5 | Falling to trough | Early retrieval | CA3 reactivation |
| 6-7 | Rising from trough | Late retrieval | Memory completion |

### Hebbian Learning

```verilog
// Learning: increment weights for co-active pairs
if (learning && clk_en) begin
    for (i = 0; i < N_UNITS; i = i + 1) begin
        for (j = 0; j < N_UNITS; j = j + 1) begin
            if (pattern_in[i] && pattern_in[j] && weights[i][j] < MAX_WEIGHT) begin
                weights[i][j] <= weights[i][j] + 1;
            end
        end
    end
end

// Decay: decrement weights when pattern_in = 0
if (decay_counter >= DECAY_PERIOD && pattern_in == 0) begin
    for (i = 0; i < N_UNITS; i = i + 1) begin
        for (j = 0; j < N_UNITS; j = j + 1) begin
            if (weights[i][j] > 0)
                weights[i][j] <= weights[i][j] - 1;
        end
    end
end
```

## 5.2 dendritic_compartment.v (v9.5)

**Purpose:** Two-compartment pyramidal dendrite model with Ca²⁺ spikes.

### Compartment Structure

```
                    ┌─────────────────────────────────────┐
                    │         APICAL DENDRITE             │
                    │   (feedback, layer 1 termination)   │
                    │                                     │
                    │   Cable filter (tau = 10ms)         │
                    │           │                         │
                    │           ▼                         │
                    │   Ca²⁺ threshold crossing?          │
                    │           │                         │
                    │           ▼                         │
                    │   Ca²⁺ spike (tau = 30ms)          │
                    └───────────┬─────────────────────────┘
                                │
                    ┌───────────┼─────────────────────────┐
                    │           │ BAC Coincidence?        │
                    │           ▼                         │
                    │   basal + apical + 1.5× boost       │
                    └───────────┬─────────────────────────┘
                                │
                    ┌───────────┴─────────────────────────┐
                    │         BASAL DENDRITE              │
                    │   (feedforward, direct passthrough) │
                    └─────────────────────────────────────┘
```

### State-Dependent Ca²⁺ Thresholds

| State | ca_threshold | Effect |
|-------|--------------|--------|
| NORMAL | 0.5 (8192) | Balanced integration |
| PSYCHEDELIC | 0.25 (4096) | More Ca²⁺ spikes |
| ANESTHESIA | 0.75 (12288) | Fewer Ca²⁺ spikes |
| FLOW | 0.5 (8192) | Balanced |
| MEDITATION | 0.375 (6144) | Slightly easier |

### BAC Firing

```verilog
// BAC (Backpropagating Action potential-activated Ca²⁺ spike)
// Supralinear boost when basal AND apical are both active
localparam signed [WIDTH-1:0] K_BAC = 18'sd24576;  // 1.5×

wire bac_coincidence = basal_active && ca_spike_active;
wire [2*WIDTH-1:0] bac_boost_full = combined * K_BAC;
assign output = bac_coincidence ? (bac_boost_full >>> FRAC) : combined;
```

## 5.3 pv_interneuron.v (v9.2)

**Purpose:** PV+ basket cell PING network dynamics.

### Leaky Integrator Model

```verilog
// Time constant: tau = 5ms → alpha = 0.05
localparam signed [WIDTH-1:0] TAU_INV = 18'sd819;  // 0.05

// Excitation from pyramidal cells
wire [2*WIDTH-1:0] excite_full = pyramid_input * K_EXCITE;
wire signed [WIDTH-1:0] excitation = excite_full >>> FRAC;

// Leaky integration
// pv_state = pv_state + alpha × (excitation - pv_state)
wire signed [WIDTH-1:0] delta = excitation - pv_state;
wire [2*WIDTH-1:0] update_full = TAU_INV * delta;
pv_state <= pv_state + (update_full >>> FRAC);

// Inhibition output
assign inhibition = (pv_state * K_INHIB) >>> FRAC;
```

### Cross-Layer PV+ Network (v9.3)

| PV+ Population | Source | Weight | Function |
|----------------|--------|--------|----------|
| L2/3 PV+ | L2/3 pyramids | 1.0× | Local PING |
| L4 PV+ | L4 pyramids | 0.5× | Feedforward gating |
| L5 PV+ | L5b pyramids | 0.25× | Feedback inhibition |

## 5.4 layer1_minimal.v (v9.6)

**Purpose:** Molecular layer gain modulation with VIP+ disinhibition.

### Gain Computation

```
             ┌─────────────────────────────────────────┐
             │           LAYER 1 GAIN MODULATION       │
             │                                         │
   matrix    │  ┌────────────────────────────────────┐│
   thalamic ─┤  │  Combined Input (weighted sum)     ││
             │  │  0.15×matrix + 0.3×fb1 + 0.2×fb2   ││
   feedback1─┤  │  + 0.1×l6_direct                   ││
             │  └──────────────┬─────────────────────┘│
   feedback2─┤                 │                      │
             │                 ▼                      │
   l6_direct─┤  ┌────────────────────────────────────┐│
             │  │  SST+ Slow Dynamics                ││
             │  │  IIR filter (tau = 25ms)           ││
             │  │  sst_activity = lowpass(combined)  ││
             │  └──────────────┬─────────────────────┘│
             │                 │                      │
   attention─┤  ┌──────────────▼─────────────────────┐│
             │  │  VIP+ Disinhibition                ││
             │  │  IIR filter (tau = 50ms)           ││
             │  │  vip_activity = lowpass(attention) ││
             │  │  sst_effective = sst - vip         ││
             │  └──────────────┬─────────────────────┘│
             │                 │                      │
             │                 ▼                      │
             │  ┌────────────────────────────────────┐│
             │  │  Apical Gain Output                ││
             │  │  gain = 1.0 - sst_effective        ││
             │  │  Clamped to [0.25, 2.0]           ││
             │  └────────────────────────────────────┘│
             └─────────────────────────────────────────┘
```

---

# 6. SELF-ORGANIZATION SYSTEM

## 6.1 energy_landscape.v (v11.1b)

**Purpose:** Computes restoring forces toward φⁿ attractor positions.

### Three Force Components

```verilog
// 1. φⁿ Landscape Force (half-integer attractors)
F_phi = 2πA × sin(2πn)

// 2. Rational Resonance Force (Farey fractions)
F_rational = Σ B_q × gradient(1/(n - p/q)²)
           = Σ B_q × 2(n - p/q) / ((n - p/q)² + ε²)²

// 3. Catastrophe Repulsion Force (2:1, 3:1, 4:1 zones)
F_catastrophe = zone_active ? sign(n - center) × K_catastrophe : 0

// Total force
F_total = F_phi + F_rational + F_catastrophe
```

### Catastrophe Zones

| Zone | n Range | Center | Strength |
|------|---------|--------|----------|
| 2:1 | [1.35, 1.55] | 1.5 | 1.0 (K_CATASTROPHE_2_1) |
| 3:1 | [2.20, 2.36] | 2.28 | 1.0 (K_CATASTROPHE_3_1) |
| 4:1 | [2.80, 2.96] | 2.88 | 0.75 (K_CATASTROPHE_4_1) |

## 6.2 quarter_integer_detector.v (v11.0)

**Purpose:** Classifies oscillator positions in φⁿ landscape.

### Position Classification

```verilog
// Extract fractional part of n
frac = n & ((1 << FRAC) - 1);  // 14-bit fraction

// Classification based on fractional value
if (frac < 0.125 || frac > 0.875)
    class = INTEGER_BOUNDARY;      // 00 - unstable
else if (frac > 0.375 && frac < 0.625)
    class = HALF_INTEGER;          // 01 - stable attractor
else if (n_in_catastrophe_zone)
    class = NEAR_CATASTROPHE;      // 11 - danger zone
else
    class = QUARTER_INTEGER;       // 10 - fallback position
```

### Stability Metric

```verilog
// Linear interpolation from center of half-integer band
// Center (0.5) = 1.0, edges (0.375, 0.625) = 0.5
distance = |frac - 0.5|;
stability = 1.0 - distance × 2;  // [0.5, 1.0]
```

## 6.3 coupling_susceptibility.v (v11.1a)

**Purpose:** Computes χ(r) coupling susceptibility from frequency ratios.

### Farey Fraction Lookup

The χ(r) value indicates coupling strength based on frequency ratio:

| Ratio | Type | χ Value | Interpretation |
|-------|------|---------|----------------|
| 1.0, 2.0, 3.0 | Integer | 0.77-0.98 | Unstable, strong coupling |
| 1.5, 2.5 | Half-integer | 0.25-0.28 | Stable attractor |
| 1.25 (φ^1.25) | Quarter | 0.126 | MOST STABLE |
| 1.618 (φ) | Golden | 0.15 | Very stable |

### 256-Entry LUT

```verilog
// Precomputed chi values for ratio range [1.0, 4.0]
// Index: ratio_scaled = (ratio - 1.0) × 256 / 3.0
// Output: chi[17:0] in Q14 format

// Key entries:
chi_lut[0]   = 16056;  // ratio=1.0, chi=0.98
chi_lut[43]  = 2064;   // ratio=1.5, chi=0.126 (most stable)
chi_lut[85]  = 15892;  // ratio=2.0, chi=0.97
chi_lut[128] = 4096;   // ratio=2.5, chi=0.25
```

## 6.4 coupling_mode_controller.v (v1.1)

**Purpose:** Dynamically switches between PAC and harmonic coupling modes.

### Mode Definitions

| Mode | Code | Pink Weight | Osc Scale | Condition |
|------|------|-------------|-----------|-----------|
| MODULATORY | 00 | 0.98 | 0.25× | Default baseline |
| TRANSITION | 01 | 0.67 | 2.2× | During crossfade |
| HARMONIC | 10 | 0.85 | 0.35× | High sync or MEDITATION |

### v1.1 State-Driven Mode

```verilog
// MEDITATION (state=4) forces HARMONIC mode directly
wire state_driven_harmonic = (state_select == 3'd4);

// Transition rules
MODULATORY → HARMONIC:
  state_driven_harmonic OR (R > 0.5 AND boundary > 0.25)

HARMONIC → MODULATORY:
  R < 0.4 AND NOT state_driven_harmonic
```

### Thresholds (v1.1 Lowered)

| Threshold | v11.0 | v1.1 | Q14 |
|-----------|-------|------|-----|
| R entry | 0.7 | 0.5 | 8192 |
| R exit | 0.5 | 0.4 | 6554 |
| Boundary | 0.5 | 0.25 | 4096 |

---

# 7. METRICS AND MONITORING

## 7.1 kuramoto_order_parameter.v (v11.3)

**Purpose:** Population synchronization metric R ∈ [0, 1].

### 6-Oscillator Inputs

| Oscillator | x Input | y Input |
|------------|---------|---------|
| Theta | thalamic_theta_x | thalamic_theta_y |
| Alpha | motor_l6_x | motor_l6_y |
| Beta₁ | motor_l5a_x | motor_l5a_y |
| Beta₂ | motor_l5b_x | motor_l5b_y |
| Gamma | motor_l23_x | motor_l23_y |
| SR f₀ | sr_f0_x | sr_f0_y |

### Amplitude Approximation (No sqrt)

```verilog
// |z| ≈ max(|x|,|y|) + 0.4 × min(|x|,|y|)  [4% error]
abs_x = x[WIDTH-1] ? -x : x;
abs_y = y[WIDTH-1] ? -y : y;
max_xy = (abs_x > abs_y) ? abs_x : abs_y;
min_xy = (abs_x > abs_y) ? abs_y : abs_x;
amplitude = max_xy + ((min_xy * 6554) >>> FRAC);  // 0.4 × min
```

## 7.2 pac_strength.v (v11.1c)

**Purpose:** Phase-amplitude coupling strength for 10 oscillator pairs.

### PAC Formula

```verilog
// PAC = χ(ratio) × sqrt(A_low × A_high)
// χ from coupling_susceptibility lookup

wire [WIDTH-1:0] ratio = (omega_high << FRAC) / omega_low;
wire [WIDTH-1:0] chi = chi_lut[ratio_index];
wire [2*WIDTH-1:0] amp_product = amp_low * amp_high;
wire [WIDTH-1:0] amp_geo = sqrt_approx(amp_product);  // Geometric mean
wire [2*WIDTH-1:0] pac_full = chi * amp_geo;
assign pac = pac_full >>> FRAC;
```

### Key Pairs

| Pair | Ratio | Expected PAC |
|------|-------|--------------|
| Theta-Alpha | 1.62 (φ) | Low (attractor) |
| Beta₁-Gamma | 2.05 (near 2:1) | High (boundary) |
| Alpha-Beta₁ | 1.62 (φ) | Low (attractor) |
| SR f₀-f₂ | 2.63 (φ²) | Low (attractor) |

## 7.3 bicoherence_monitor.v (v11.3)

**Purpose:** Detects nonlinear three-frequency interactions.

### Bispectral Phase

```verilog
// For frequencies f₁, f₂, f₁₂ = f₁ + f₂
// Bispectral phase: ψ₁ + ψ₂ - ψ₁₂

// Phase extraction from (x, y) state
phase_1 = atan2_approx(y1, x1);
phase_2 = atan2_approx(y2, x2);
phase_12 = atan2_approx(y12, x12);

// Bispectral phase
bispec_phase = phase_1 + phase_2 - phase_12;

// Bicoherence: |cos(bispec_phase)| with IIR averaging
bicoh = |cos(bispec_phase)|;
bicoh_avg <= bicoh_avg + ((bicoh - bicoh_avg) >>> AVG_SHIFT);
```

## 7.4 harmonic_spacing_index.v (v11.3)

**Purpose:** Monitors deviation from ideal φⁿ frequency ratios.

### HSI Computation

```verilog
// Compute 4 frequency ratios
ratio_alpha_theta = omega_alpha / omega_theta;   // Target: φ
ratio_beta1_alpha = omega_beta1 / omega_alpha;   // Target: φ
ratio_beta2_beta1 = omega_beta2 / omega_beta1;   // Target: φ
ratio_gamma_beta2 = omega_gamma / omega_beta2;   // Target: φ

// Compute deviations from φ
dev_0 = |ratio_alpha_theta - PHI|;
dev_1 = |ratio_beta1_alpha - PHI|;
dev_2 = |ratio_beta2_beta1 - PHI|;
dev_3 = |ratio_gamma_beta2 - PHI|;

// Mean deviation
mean_dev = (dev_0 + dev_1 + dev_2 + dev_3) >> 2;

// HSI = 1.0 - clamp(mean_dev / 0.5, 0, 1)
HSI = (mean_dev < HALF) ? (ONE - mean_dev * 2) : 0;

// Harmonic lock: all ratios within 8% of φ
harmonic_locked = (dev_0 < 0.13) && (dev_1 < 0.13) &&
                  (dev_2 < 0.13) && (dev_3 < 0.13);
```

## 7.5 boundary_generator.v (v11.3)

**Purpose:** Generates boundary oscillations at geometric means.

### Boundary Frequencies

| Boundary | Parent Oscillators | Frequency |
|----------|-------------------|-----------|
| θ/α | Theta (5.89) + Alpha (9.53) | 7.49 Hz |
| α/β₁ | Alpha (9.53) + Beta₁ (15.42) | 12.12 Hz |
| β₁/β₂ | Beta₁ (15.42) + Beta₂ (24.94) | 19.60 Hz |

### Generation Method

```verilog
// Amplitude: geometric mean
amp_boundary = sqrt(amp_low × amp_high);

// Phase: average of parent phases
// Using unit vector averaging
unit_low_x = x_low / amp_low;
unit_high_x = x_high / amp_high;
boundary_x = amp_boundary × (unit_low_x + unit_high_x) / 2;
```

---

# 8. SIE SYSTEM

## 8.1 sr_ignition_controller.v (v1.3)

**Purpose:** Six-phase SIE state machine based on empirical EEG observations.

### State Machine Diagram

```
    ┌───────────────────────────────────────────────────────────────────────────┐
    │                      SIE IGNITION STATE MACHINE                           │
    │                                                                           │
    │   ┌─────────┐   coh>0.75    ┌──────────┐   3.5s    ┌─────────┐          │
    │   │BASELINE │   && beta_q   │COHERENCE │──────────►│IGNITION │          │
    │   │  (0)    │──────────────►│   (1)    │           │   (2)   │          │
    │   │         │               │          │           │         │          │
    │   │ PLV=0.45│               │ PLV↑0.80 │           │ Gain↑1.0│          │
    │   │ Gain=0  │               │ Gain=0.40│           │         │          │
    │   └────▲────┘               └──────────┘           └────┬────┘          │
    │        │                                                 │               │
    │        │                                            2.5s │               │
    │        │                                                 ▼               │
    │   ┌────┴─────┐   10s    ┌─────────┐   4s    ┌─────────┐                 │
    │   │REFRACTORY│◄─────────│  DECAY  │◄────────│ PLATEAU │                 │
    │   │   (6)    │          │   (5)   │         │   (3)   │                 │
    │   │          │          │         │         │         │                 │
    │   │ Gain=0   │          │ Gain↓0  │         │ Gain=1.0│                 │
    │   │ no re-ig │          │ Exp τ=1s│         │ 2.5s    │                 │
    │   └──────────┘          └─────────┘         └────┬────┘                 │
    │                                                   │                      │
    │                                              2.5s │                      │
    │                                                   ▼                      │
    │                                            ┌───────────┐                │
    │                                            │PROPAGATION│                │
    │                                            │    (4)    │                │
    │                                            │           │                │
    │                                            │ Gain=0.60 │                │
    │                                            │ PAC peak  │                │
    │                                            │ 9s        │                │
    │                                            └───────────┘                │
    │                                                                          │
    └──────────────────────────────────────────────────────────────────────────┘
```

### Phase Timing (State-Dependent)

| Phase | NORMAL | MEDITATION | ANESTHESIA | PSYCHEDELIC |
|-------|--------|------------|------------|-------------|
| COHERENCE (1) | 3.5s | 4s | 5s | 4s |
| IGNITION (2) | 2.5s | 3s | 2s | 3s |
| PLATEAU (3) | 2.5s | 3s | 2s | 4s |
| PROPAGATION (4) | 9s | 10s | 6s | 12s |
| DECAY (5) | 4s | 5s | 5s | 5s |
| REFRACTORY (6) | 10s | 8s | 15s | 6s |

### Gain/PLV Envelopes

```verilog
// Phase 1: COHERENCE - PLV rises first, gain rises slowly
if (plv_envelope < PLV_PEAK)
    plv_envelope <= plv_envelope + PLV_ATTACK_ALPHA;
if (gain_envelope < GAIN_COHERENCE)
    gain_envelope <= gain_envelope + (PLV_ATTACK_ALPHA >>> 1);

// Phase 2: IGNITION - Gain ramps up rapidly
if (gain_envelope < GAIN_PEAK)
    gain_envelope <= gain_envelope + GAIN_ATTACK_ALPHA;

// Phase 5: DECAY - Exponential relaxation
gain_envelope <= gain_envelope - ((gain_envelope - GAIN_BASELINE) >>> DECAY_SHIFT);
```

## 8.2 sr_frequency_drift.v (v2.0)

**Purpose:** Hours-scale realistic SR frequency variation.

### Drift Ranges (v2.0 Expanded)

| Harmonic | Base Freq | Drift Range | Update Period |
|----------|-----------|-------------|---------------|
| f₀ | 7.6 Hz | ±0.9 Hz | 0.1s |
| f₁ | 13.75 Hz | ±1.1 Hz | 0.1s |
| f₂ | 20 Hz | ±1.5 Hz | 0.1s |
| f₃ | 25 Hz | ±2.25 Hz | 0.1s |
| f₄ | 32 Hz | ±3.0 Hz | 0.1s |

### Bounded Random Walk

```verilog
// Update every 400 cycles at 4 kHz (0.1s)
if (update_counter >= UPDATE_PERIOD) begin
    // Lévy flight-like step sizes (1-4 units)
    step = lfsr[1:0] + 1;  // 1, 2, 3, or 4
    direction = lfsr[2];    // 0 = negative, 1 = positive

    // Bounded walk
    if (direction && drift < DRIFT_MAX)
        drift <= drift + step;
    else if (!direction && drift > -DRIFT_MAX)
        drift <= drift - step;
end
```

## 8.3 Distributed SIE Architecture (v11.5)

### Boost Distribution

```
    ┌─────────────────────────────────────────────────────────────┐
    │               DISTRIBUTED SIE ARCHITECTURE (v11.5)          │
    │                                                             │
    │   v11.3 Cascade (PROBLEMATIC):                             │
    │   ┌───────────┐   ┌───────────┐   ┌───────────┐            │
    │   │sie_theta  │ × │sie_alpha  │ × │ Mixer     │ × Thalamus │
    │   │  2.0×     │   │  2.0×     │   │  2.0×     │    4-5×    │
    │   └───────────┘   └───────────┘   └───────────┘            │
    │        Total: 2 × 2 × 2 × 4 = 32× (15 dB) → CLIPPING       │
    │                                                             │
    │   v11.5 Option C (DISTRIBUTED):                            │
    │   ┌───────────┐   ┌───────────┐   ┌───────────┐            │
    │   │ Mixer     │ + │ Thalamus  │ + │ Thalamus  │            │
    │   │  +2.9 dB  │   │ f₀ +2.3dB │   │ f₁ +1.6dB │            │
    │   │ (1.0-1.4×)│   │ (1.3×)    │   │ (1.2×)    │            │
    │   └───────────┘   └───────────┘   └───────────┘            │
    │                                                             │
    │   Signal-level boosts: DISABLED (constant 1.0×)            │
    │   Total: 2.9 + 2.3 + 1.6 = 6.8 dB (matches empirical SIE)  │
    └─────────────────────────────────────────────────────────────┘
```

---

# 9. SIGNAL PROCESSING

## 9.1 output_mixer.v (v7.19)

**Purpose:** 5-channel spectral mixing with coupling-mode dynamics.

### Channel Weights

| Channel | Base Weight (Q14) | Function |
|---------|-------------------|----------|
| Theta (5.89 Hz) | 82 (0.005) | Thalamic timing |
| Alpha (9.53 Hz) | 164 (0.01) | L6 gain control |
| Beta (15.42 Hz) | 102 (0.00625) | Motor output |
| Gamma (40.36 Hz) | 61 (0.00375) | Feedforward |
| Pink Noise | Mode-dependent | 1/f background |

### Mode-Dependent Mixing (v7.19)

| Mode | Pink Weight | Osc Scale | Description |
|------|-------------|-----------|-------------|
| MODULATORY | 0.98 | 0.25× | Dark baseline (v7.19) |
| TRANSITION | 0.67 | 2.2× | Crossfade |
| HARMONIC | 0.85 | 0.35× | Meditation (v7.19) |

### Soft Limiter (v7.1)

```verilog
// Piecewise linear compression
// Below ±0.75: linear
// Above ±0.75: 2:1 compression toward ±1.0

if (abs_input > SOFT_THRESH) begin
    excess = abs_input - SOFT_THRESH;
    compressed_excess = excess >>> 1;  // Divide by 2
    abs_limited = SOFT_THRESH + compressed_excess;
end else begin
    abs_limited = abs_input;
end

// Restore sign
soft_limited = input_negative ? -abs_limited : abs_limited;
```

### DAC Output Conversion

```verilog
// Shift to unsigned range
shifted = mixed_output + 18'sd16384;  // Center at 1.0

// Scale to 12 bits
dac_raw = shifted[17:3];

// Clamp to [0, 4095]
dac_output = (dac_raw > 16'd4095) ? 12'd4095 : dac_raw[11:0];
```

## 9.2 pink_noise_generator.v (v7.2)

**Purpose:** 1/f^φ noise using √Fibonacci-weighted Voss-McCartney.

### √Fibonacci Weights

| Row | Fibonacci | √Weight | Normalized |
|-----|-----------|---------|------------|
| 0 | 1 | 1 | 0.019 |
| 1 | 1 | 1 | 0.019 |
| 2 | 2 | 1 | 0.019 |
| 3 | 3 | 2 | 0.038 |
| 4 | 5 | 2 | 0.038 |
| 5 | 8 | 3 | 0.057 |
| 6 | 13 | 4 | 0.075 |
| 7 | 21 | 5 | 0.094 |
| 8 | 34 | 6 | 0.113 |
| 9 | 55 | 7 | 0.132 |
| 10 | 89 | 9 | 0.170 |
| 11 | 144 | 12 | 0.226 |
| **Total** | — | **53** | **1.0** |

### 1/f^φ Spectral Slope

```
Standard 1/f: -10 dB/decade
1/f^φ:        -10 × 1.618 = -16.2 dB/decade

This matches biological EEG power spectral density more closely
than standard 1/f noise.
```

## 9.3 amplitude_envelope_generator.v (v11.4)

**Purpose:** Ornstein-Uhlenbeck process for biological amplitude variability.

### O-U Process

```verilog
// dx = -θ(x - μ)dt + σdW
// Discrete: x[n+1] = x[n] - τ_inv × (x[n] - equilibrium) + noise

// Mean reversion
delta = equilibrium - envelope;
reversion = (tau_inv * delta) >>> FRAC;

// Noise injection (from LFSR)
noise = (lfsr[3:0] - 8) << (FRAC - 4);  // ±0.5 range

// Update with decimation (every 16 samples for smooth drift)
if (decimate_counter >= 16) begin
    envelope <= envelope + reversion + (noise >>> 4);
end

// Clamp to bounds
if (envelope < ENVELOPE_MIN) envelope <= ENVELOPE_MIN;
if (envelope > ENVELOPE_MAX) envelope <= ENVELOPE_MAX;
```

### Parameterized Bounds (v11.4)

| Oscillator | ENVELOPE_MIN | ENVELOPE_MAX | Range |
|------------|--------------|--------------|-------|
| Cortical (default) | 8192 (0.5) | 24576 (1.5) | ±50% |
| Theta | 11469 (0.7) | 21299 (1.3) | ±30% |

## 9.4 cortical_frequency_drift.v (v3.0)

**Purpose:** Per-layer frequency variability for EEG-realistic peaks.

### Two Components

| Component | Range | Update Rate | Purpose |
|-----------|-------|-------------|---------|
| Slow Drift | ±0.5 Hz | 0.2s | Hours-scale variation |
| Fast Jitter | ±0.15 Hz | Every sample | Spectral broadening |

### Force-Based Adaptive (v3.0)

```verilog
// When ENABLE_ADAPTIVE=1, forces from energy_landscape modify drift
drift_update = random_walk_step + (force * K_FORCE) >>> FRAC;

// Combined offset for oscillator
omega_offset = drift + jitter;
omega_effective = OMEGA_DT_BASE + omega_offset;
```

---

# 10. CONSCIOUSNESS STATE SYSTEM

## 10.1 config_controller.v (v11.4)

**Purpose:** Consciousness state management with smooth interpolation.

### State Definitions

| State | Code | Description |
|-------|------|-------------|
| NORMAL | 0 | Balanced baseline |
| ANESTHESIA | 1 | Propofol-like suppression |
| PSYCHEDELIC | 2 | Enhanced gamma, reduced L6 |
| FLOW | 3 | Motor-optimized |
| MEDITATION | 4 | Theta coherence maximized |

### MU Values by State

| State | Theta | L6 | L5b | L5a | L4 | L2/3 |
|-------|-------|-----|-----|-----|-----|------|
| NORMAL | 3 | 3 | 3 | 3 | 3 | 3 |
| ANESTHESIA | 2 | 6 | 2 | 2 | 1 | 1 |
| PSYCHEDELIC | 4 | 1 | 4 | 4 | 6 | 6 |
| FLOW | 4 | 2 | 6 | 6 | 4 | 4 |
| MEDITATION | 6 | 6 | 1 | 1 | 1 | 2 |

### Ca²⁺ Thresholds by State

| State | ca_threshold (Q14) | Effect |
|-------|-------------------|--------|
| NORMAL | 8192 (0.5) | Balanced |
| ANESTHESIA | 12288 (0.75) | Hard to trigger |
| PSYCHEDELIC | 4096 (0.25) | Easy to trigger |
| FLOW | 8192 (0.5) | Balanced |
| MEDITATION | 6144 (0.375) | Slightly easier |

### State Transition Interpolation (v11.4)

```verilog
// Linear interpolation between states
function signed [WIDTH-1:0] lerp_signed;
    input signed [WIDTH-1:0] start_val;
    input signed [WIDTH-1:0] end_val;
    input [15:0] t;
    input [15:0] duration;
    begin
        delta = end_val - start_val;
        scaled = delta * $signed({1'b0, t});
        lerp_signed = start_val + scaled / $signed({1'b0, duration});
    end
endfunction

// Applied to all MU values, Ca²⁺ threshold, SIE timing
mu_dt_theta <= lerp_signed(mu_start_theta, mu_tgt_theta, ramp_counter, ramp_dur);
```

### Transition Duration Examples

| Cycles | Time (4 kHz) | Use Case |
|--------|--------------|----------|
| 0 (→1) | 0.25 ms | Instant (v11.3 behavior) |
| 4000 | 1 second | Quick transition |
| 40000 | 10 seconds | Moderate |
| 80000 | 20 seconds | Full meditation ramp |

---

# 11. CONSTANTS REFERENCE

## 11.1 Frequency Parameters (OMEGA_DT)

| Name | Q14 Value | Frequency | Formula |
|------|-----------|-----------|---------|
| OMEGA_DT_THETA | 152 | 5.89 Hz | 2π × 5.89 × 0.00025 × 16384 |
| OMEGA_DT_L6 | 245 | 9.53 Hz | φ⁰·⁵ × theta |
| OMEGA_DT_L5A | 397 | 15.42 Hz | φ¹·⁵ × theta |
| OMEGA_DT_L5B | 642 | 24.94 Hz | φ²·⁵ × theta |
| OMEGA_DT_L4 | 817 | 31.73 Hz | φ³ × theta |
| OMEGA_DT_L23 | 1039 | 40.36 Hz | φ³·⁵ × theta |
| OMEGA_DT_L23_FAST | 1681 | 65.3 Hz | φ⁴·⁵ × theta |
| OMEGA_DT_SR_F0 | 196 | 7.6 Hz | SR fundamental |
| OMEGA_DT_SR_F1 | 354 | 13.75 Hz | φ¹·²⁵ fallback |
| OMEGA_DT_SR_F2 | 514 | 20 Hz | SR anchor |
| OMEGA_DT_SR_F3 | 643 | 25 Hz | — |
| OMEGA_DT_SR_F4 | 823 | 32 Hz | — |

## 11.2 Coupling Weights (K_*)

| Name | Q14 Value | Decimal | Usage |
|------|-----------|---------|-------|
| K_PHASE | 328 | 0.02 | Phase coupling (minimal) |
| K_L4_L23 | 820 | 0.05 | L4 → L2/3 |
| K_L23_L5 | 328 | 0.02 | L2/3 → L5 |
| K_L5_L6 | 328 | 0.02 | L5b → L6 |
| K_PAC | 328 | 0.02 | PAC modulation |
| K_FB_L5 | 328 | 0.02 | Inter-column feedback |
| K_L6_L5A | 328 | 0.02 | L6 → L5a |
| K_L4_L5A | 328 | 0.02 | L4 → L5a bypass |
| K_L6_L23 | 164 | 0.01 | L6 → L2/3 |
| K_L6_L5B | 328 | 0.02 | L6 → L5b |
| K_L6_THAL | 164 | 0.01 | L6 → Thalamus |
| K_TRN | 164 | 0.01 | TRN amplification |
| K_MATRIX | 2458 | 0.15 | Matrix thalamus → L1 |
| K_FB1 | 4915 | 0.3 | Adjacent column feedback |
| K_FB2 | 3277 | 0.2 | Distant column feedback |
| K_EXCITE | 8192 | 0.5 | PV+ excitation gain |
| K_INHIB | 4915 | 0.3 | PV+ inhibition weight |
| K_APICAL | 4096 | 0.25 | Apical contribution |
| K_BAC | 24576 | 1.5 | BAC supralinear boost |
| K_VIP | 8192 | 0.5 | VIP+ attention scaling |
| K_FORCE | 1638 | 0.1 | Force-to-drift gain |

## 11.3 Threshold Values

| Name | Q14 Value | Decimal | Usage |
|------|-----------|---------|-------|
| COHERENCE_THRESH | 12288 | 0.75 | SIE trigger |
| BETA_QUIET_THRESHOLD | 12288 | 0.75 | SR gating |
| R_SQ_TARGET | 16384 | 1.0 | Hopf target radius² |
| R_SQ_THRESHOLD | 17408 | 1.0625 | Hopf correction trigger |
| SOFT_THRESH | 12288 | 0.75 | Mixer soft limiter |
| SOFT_LIMIT | 16384 | 1.0 | Mixer max output |
| KURAMOTO_R_ENTRY | 8192 | 0.5 | HARMONIC mode entry |
| KURAMOTO_R_EXIT | 6554 | 0.4 | HARMONIC mode exit |
| BOUNDARY_THRESH | 4096 | 0.25 | Boundary power threshold |
| CATASTROPHE_N_MIN | 22118 | 1.35 | 2:1 danger zone lower |
| CATASTROPHE_N_MAX | 25395 | 1.55 | 2:1 danger zone upper |

## 11.4 SIE Enhancement Values

| Name | Q14 Value | Decimal | Usage |
|------|-----------|---------|-------|
| SIE_ENHANCE_F0 | 21299 | 1.3× | f₀ enhancement (v11.5) |
| SIE_ENHANCE_F1 | 19661 | 1.2× | f₁ enhancement (v11.5) |
| SIE_ENHANCE_F2 | 20480 | 1.25× | f₂ enhancement |
| SIE_ENHANCE_F3 | 19661 | 1.2× | f₃ enhancement |
| SIE_ENHANCE_F4 | 19661 | 1.2× | f₄ enhancement |
| SIE_BOOST_RANGE | 6554 | 0.4 | Mixer boost range |
| GAIN_BASELINE | 0 | 0.0 | SIE baseline gain |
| GAIN_COHERENCE | 6554 | 0.4 | SIE coherence phase |
| GAIN_PEAK | 16384 | 1.0 | SIE peak gain |
| GAIN_PROPAGATION | 9830 | 0.6 | SIE propagation |

## 11.5 Envelope Bounds

| Name | Q14 Value | Decimal | Usage |
|------|-----------|---------|-------|
| ENVELOPE_MIN | 8192 | 0.5 | Cortical lower |
| ENVELOPE_MAX | 24576 | 1.5 | Cortical upper |
| ENVELOPE_MIN_THETA | 11469 | 0.7 | Theta lower |
| ENVELOPE_MAX_THETA | 21299 | 1.3 | Theta upper |
| ENVELOPE_MEAN | 16384 | 1.0 | Equilibrium |

## 11.6 Golden Ratio Constants

| Name | Q14 Value | Decimal | Usage |
|------|-----------|---------|-------|
| PHI | 26510 | 1.618 | φ¹·⁰ |
| PHI_0_25 | 18474 | 1.1276 | φ⁰·²⁵ |
| PHI_0_5 | 20833 | 1.272 | φ⁰·⁵ |
| PHI_0_75 | 20935 | 1.2785 | φ⁰·⁷⁵ |
| PHI_1_25 | 29899 | 1.8249 | φ¹·²⁵ (f₁ fallback) |
| PHI_1_5 | 33718 | 2.058 | φ¹·⁵ (unstable!) |
| PHI_2_0 | 42891 | 2.618 | φ² |
| PHI_2_5 | 54569 | 3.330 | φ²·⁵ |
| HARMONIC_2_1 | 32768 | 2.0 | 2:1 harmonic ratio |

## 11.7 Timing Parameters

| Name | Value | Description |
|------|-------|-------------|
| DT | 4 | dt = 0.00025 for 4 kHz |
| MU_FULL | 4 | Full growth rate |
| MU_MODERATE | 3 | Moderate (NORMAL) |
| MU_HALF | 2 | Half |
| MU_WEAK | 1 | Minimum practical |
| MU_ENHANCED | 6 | Enhanced |
| MU_DIV3 | 5461 | 1/3 for MU scaling |
| TRANSITION_DEFAULT | 80000 | 20s at 4 kHz |
| SST_ALPHA | 164 | 0.01 (25ms tau) |
| VIP_ALPHA | 82 | 0.005 (50ms tau) |
| TAU_INV_PV | 819 | 0.05 (5ms tau) |
| APICAL_CABLE_ALPHA | 410 | 0.025 (10ms tau) |
| CA_DURATION_ALPHA | 137 | 0.00833 (30ms tau) |

## 11.8 Output Mixer Weights (v7.19)

| Name | Q14 Value | Decimal | Mode |
|------|-----------|---------|------|
| W_PINK_MODULATORY | 16056 | 0.98 | MODULATORY |
| W_PINK_TRANSITION | 10978 | 0.67 | TRANSITION |
| W_PINK_HARMONIC | 13926 | 0.85 | HARMONIC |
| OSC_SCALE_MODULATORY | 4096 | 0.25× | MODULATORY |
| OSC_SCALE_TRANSITION | 36045 | 2.2× | TRANSITION |
| OSC_SCALE_HARMONIC | 5734 | 0.35× | HARMONIC |
| W_THETA_BASE | 82 | 0.005 | Theta weight |
| W_ALPHA_BASE | 164 | 0.01 | Alpha weight |
| W_BETA_BASE | 102 | 0.00625 | Beta weight |
| W_GAMMA_BASE | 61 | 0.00375 | Gamma weight |

---

# 12. VERIFICATION AND TESTING

## 12.1 Testbench Inventory (365+ Tests)

### Core System Tests

| Testbench | Tests | Description |
|-----------|-------|-------------|
| tb_full_system_fast | 15 | Full integration |
| tb_hopf_oscillator | 6 | Hopf dynamics |
| tb_v55_fast | 6 | Fast CA3/theta |
| tb_learning_fast | 8 | CA3 Hebbian learning |
| tb_state_transitions | 12 | State machine |

### Theta Phase & Scaffold Architecture

| Testbench | Tests | Description |
|-----------|-------|-------------|
| tb_theta_phase_multiplexing | 19 | 8-phase theta |
| tb_scaffold_architecture | 14 | Scaffold/plastic |
| tb_gamma_theta_nesting | 7 | Gamma-theta PAC |

### SR System Tests

| Testbench | Tests | Description |
|-----------|-------|-------------|
| tb_sr_frequency_drift | 30 | SR drift |
| tb_multi_harmonic_sr | 17 | Multi-harmonic |
| tb_sr_coupling | 12 | SR coupling |
| tb_sr_ignition_phases | 10 | SIE phases |
| tb_amplitude_envelope | 8 | O-U envelopes |

### Canonical Microcircuit Tests

| Testbench | Tests | Description |
|-----------|-------|-------------|
| tb_canonical_microcircuit | 20 | Canonical pathway |
| tb_layer1_minimal | 10 | L1 gain modulation |
| tb_l6_connectivity | 10 | L6 output targets |
| tb_l6_extended | 10 | Extended L6 |

### Interneuron Tests

| Testbench | Tests | Description |
|-----------|-------|-------------|
| tb_pv_minimal | 6 | PV+ basket cell |
| tb_sst_dynamics | 8 | SST+ slow dynamics |
| tb_pv_feedback | 8 | PV+ PING network |
| tb_pv_crosslayer | 8 | Cross-layer PV+ |
| tb_vip_disinhibition | 8 | VIP+ disinhibition |

### Dendritic Tests

| Testbench | Tests | Description |
|-----------|-------|-------------|
| tb_dendritic_compartment | 10 | Ca²⁺/BAC |

### Self-Organization Tests (v11.x)

| Testbench | Tests | Description |
|-----------|-------|-------------|
| tb_coupling_susceptibility | 20 | Farey χ(r) |
| tb_energy_landscape | 24 | Forces + rational |
| tb_quarter_integer_detector | 8 | Position classification |
| tb_self_organization | 10 | Full integration |
| tb_pac_strength | 10 | PAC strength |

### Population Metrics Tests (v11.3)

| Testbench | Tests | Description |
|-----------|-------|-------------|
| tb_kuramoto_order | 7 | Kuramoto R |
| tb_boundary_generator | 7 | Boundary mixing |
| tb_bicoherence_monitor | 6 | Bicoherence |
| tb_coupling_mode_controller | 8 | Mode switching |
| tb_harmonic_spacing_index | 8 | HSI tracking |

### State Transition Tests (v11.4/v12.0)

| Testbench | Tests | Description |
|-----------|-------|-------------|
| tb_state_interpolation | 10 | State transition lerp |
| tb_state_transition_spectrogram | Visual | 100s spectrogram |

### φⁿ Theory Tests

| Testbench | Tests | Description |
|-----------|-------|-------------|
| tb_phi_n_sr_relationships | 10 | Q-factor, amplitude |
| tb_quarter_integer_theory | 12 | Quarter-integer fallback |

## 12.2 Build Commands

### Icarus Verilog

```bash
# Fast CA3/theta test
iverilog -o tb_v55_fast.vvp -s tb_v55_fast \
    src/hopf_oscillator.v src/ca3_phase_memory.v \
    tb/tb_v55_fast.v && vvp tb_v55_fast.vvp

# Full system test
iverilog -o tb_full_system_fast.vvp -s tb_full_system_fast \
    src/clock_enable_generator.v src/hopf_oscillator.v \
    src/hopf_oscillator_stochastic.v src/ca3_phase_memory.v \
    src/thalamus.v src/cortical_column.v src/config_controller.v \
    src/pink_noise_generator.v src/output_mixer.v \
    src/phi_n_neural_processor.v src/sr_harmonic_bank.v \
    src/sr_noise_generator.v src/sr_frequency_drift.v \
    tb/tb_full_system_fast.v && vvp tb_full_system_fast.vvp

# Learning test
iverilog -o tb_learning_fast.vvp -s tb_learning_fast \
    src/*.v tb/tb_learning_fast.v && vvp tb_learning_fast.vvp
```

### Makefile Targets

```bash
make iverilog-fast     # Fast CA3/theta test
make iverilog-full     # Full system test
make iverilog-hopf     # Hopf oscillator unit test
make iverilog-theta    # Theta phase multiplexing test
make iverilog-scaffold # Scaffold architecture test
make iverilog-all      # All tests
make wave-fast         # Open waveform in GTKWave
make clean             # Clean generated files
```

---

# 13. RESOURCE UTILIZATION

## 13.1 FPGA Resource Budget

| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| LUTs | ~6,230 | 53,200 | 11.7% |
| Flip-Flops | ~3,430 | 106,400 | 3.2% |
| DSP48 Slices | ~8 | 220 | 3.6% |
| Block RAM | ~0 | 140 | 0% |

## 13.2 Resource Breakdown by Module

| Module | LUTs | FFs | DSPs |
|--------|------|-----|------|
| phi_n_neural_processor (top) | ~200 | ~100 | 0 |
| hopf_oscillator (×21) | ~1,680 | ~840 | 0 |
| thalamus | ~400 | ~200 | 0 |
| cortical_column (×3) | ~1,500 | ~750 | 0 |
| sr_harmonic_bank | ~300 | ~150 | 0 |
| ca3_phase_memory | ~100 | ~50 | 0 |
| output_mixer | ~200 | ~100 | 0 |
| pink_noise_generator | ~150 | ~80 | 0 |
| config_controller | ~150 | ~180 | 0 |
| sr_ignition_controller | ~100 | ~80 | 0 |
| energy_landscape | ~200 | ~100 | 0 |
| Population metrics | ~400 | ~200 | 0 |
| Other modules | ~850 | ~600 | 8 |

## 13.3 v12.0 Resource Impact

| Addition | LUTs | FFs | DSPs |
|----------|------|-----|------|
| Interpolation (config_controller) | ~50 | ~100 | 0 |
| Shadow registers | ~20 | ~80 | 0 |
| Lerp functions | ~30 | 0 | 0 |
| **Total v12.0 additions** | **~100** | **~180** | **0** |

## 13.4 Headroom Analysis

| Resource | Remaining | Additional Capacity |
|----------|-----------|---------------------|
| LUTs | 46,970 | ~7× current usage |
| Flip-Flops | 102,970 | ~30× current usage |
| DSP48 | 212 | ~26× current usage |
| Block RAM | 140 | Full (unused) |

**Conclusion:** The design uses <12% of available FPGA resources, leaving substantial headroom for future enhancements.

---

# APPENDIX A: FILE INVENTORY

## A.1 Source Modules (29 files)

| File | Version | Lines | Purpose |
|------|---------|-------|---------|
| phi_n_neural_processor.v | v11.5 | 1305 | Top-level |
| hopf_oscillator.v | v6.0 | 104 | Core oscillator |
| hopf_oscillator_stochastic.v | v6.0 | 120 | Stochastic variant |
| thalamus.v | v11.5 | 695 | Theta + SR + matrix |
| cortical_column.v | v10.0 | 650 | 6-layer cortical |
| ca3_phase_memory.v | v8.0 | 280 | Hebbian learning |
| sr_harmonic_bank.v | v7.7 | 450 | 5-harmonic SR |
| sr_ignition_controller.v | v1.3 | 306 | SIE FSM |
| sr_frequency_drift.v | v2.0 | 180 | SR freq drift |
| sr_noise_generator.v | v1.0 | 120 | Per-harmonic noise |
| cortical_frequency_drift.v | v3.0 | 200 | Cortical drift + jitter |
| amplitude_envelope_generator.v | v11.4 | 150 | O-U envelopes |
| output_mixer.v | v7.19 | 352 | DAC mixing |
| config_controller.v | v11.4 | 345 | State management |
| clock_enable_generator.v | v6.0 | 80 | Clock divider |
| pink_noise_generator.v | v7.2 | 150 | 1/f^φ noise |
| dendritic_compartment.v | v9.5 | 180 | Two-compartment |
| layer1_minimal.v | v9.6 | 160 | L1 gain mod |
| pv_interneuron.v | v9.2 | 100 | PV+ PING |
| energy_landscape.v | v11.1b | 280 | φⁿ forces |
| quarter_integer_detector.v | v11.0 | 150 | Position class |
| sin_quarter_lut.v | v11.0 | 300 | 256-entry sine LUT |
| coupling_susceptibility.v | v11.1a | 350 | Farey χ(r) |
| pac_strength.v | v11.1c | 250 | PAC metric |
| kuramoto_order_parameter.v | v11.3 | 200 | Kuramoto R |
| boundary_generator.v | v11.3 | 150 | Boundary mixing |
| bicoherence_monitor.v | v11.3 | 180 | Bicoherence |
| coupling_mode_controller.v | v1.1 | 200 | Mode switching |
| harmonic_spacing_index.v | v11.3 | 180 | HSI tracking |

**Total:** ~9,211 lines of Verilog

## A.2 Testbenches (37 files)

See Section 12.1 for complete inventory.

## A.3 Scripts

| File | Purpose |
|------|---------|
| dac_spectrogram.py | DAC output spectrogram |
| analyze_eeg_comparison.py | EEG analysis |
| state_transition_spectrogram.py | State transition visualization |
| visualize_*.py | Various visualizations |
| run_vivado_*.tcl | Vivado synthesis scripts |

---

# APPENDIX B: VERSION HISTORY

| Version | Date | Key Changes |
|---------|------|-------------|
| v12.0 | 2025-12-29 | Unified State Dynamics |
| v11.5 | 2025-12-29 | Distributed SIE Boost |
| v11.4 | 2025-12-29 | State Transition Interpolation |
| v11.3 | 2025-12-28 | SIE Dynamics & Population Metrics |
| v11.2 | 2025-12-28 | DAC Anti-Clipping |
| v11.1 | 2025-12-27 | Unified Boundary-Attractor Framework |
| v11.0 | 2025-12-27 | Active φⁿ Dynamics |
| v10.5 | 2025-12-26 | Quarter-Integer φⁿ Theory |
| v10.4 | 2025-12-26 | φⁿ Geophysical SR Integration |
| v10.3 | 2025-12-25 | 1/f^φ Spectral Slope |
| v10.2 | 2025-12-25 | Spectral Broadening |
| v10.1 | 2025-12-24 | Envelope Integration |
| v10.0 | 2025-12-24 | EEG Realism Phase 1 |
| v9.6 | 2025-12-23 | Extended L6 Connectivity |
| v9.5 | 2025-12-22 | Dendritic Compartment |
| v9.4 | 2025-12-21 | VIP+ Disinhibition |
| v9.3 | 2025-12-20 | Cross-Layer PV+ |
| v9.2 | 2025-12-19 | PV+ PING Network |
| v9.1 | 2025-12-18 | SST+ Slow Dynamics |
| v9.0 | 2025-12-17 | PV+ Interneuron Phase 1 |
| v8.8 | 2025-12-16 | L6 Output Targets |
| v8.7 | 2025-12-15 | Matrix Thalamic Input |
| v8.6 | 2025-12-14 | Canonical Microcircuit |
| v8.5 | 2025-12-13 | SR Frequency Drift |
| v8.4 | 2025-12-12 | Gamma-Theta Nesting |
| v8.3 | 2025-12-11 | Theta Phase Tests |
| v8.2 | 2025-12-10 | SR Frequency Variation |
| v8.1 | 2025-12-09 | Gamma-Theta PAC |
| v8.0 | 2025-12-08 | Dupret Integration |
| v7.x | 2025-12 | Multi-harmonic SR, stochastic resonance |
| v6.x | 2025-12 | 4 kHz update, sensory-only architecture |
| v5.x | 2025-11 | Foundation (Hopf, CA3, config) |

---

# APPENDIX C: REFERENCES

## Biological Foundations

- Dupret et al. (2025) - Theta phase multiplexing, scaffold/plastic architecture
- Schumann Resonance monitoring data (Dec 2025)
- Standard EEG frequency band definitions

## Technical References

- FPGA_SPECIFICATION_V8.md - Base architecture
- SPEC_v12.0_UPDATE.md - Current version update
- CLAUDE.md - Project quick reference

## Theoretical Framework

- Hopf normal form dynamics
- Golden ratio (φⁿ) frequency architecture
- Kuramoto order parameter
- Farey fractions and coupling susceptibility

---

*Document generated for φⁿ Neural Processor v12.0*
*December 2024*
