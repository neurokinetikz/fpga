# Full System Architecture Analysis: φⁿ Neural Processor (v12.3)

## Overview

This document provides a complete signal path analysis of the φⁿ Neural Processor FPGA with **all features enabled** (ENABLE_THREE_BOUNDARY=1, ENABLE_ADAPTIVE=1, ENABLE_ALIGNMENT=1).

---

## System Block Diagram

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                           φⁿ NEURAL PROCESSOR (Top Level)                              │
├────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                         │
│  EXTERNAL INPUTS                                                                        │
│  ───────────────                                                                        │
│  sensory_input[17:0] ──────────────────────────────────────────→ [THALAMUS]            │
│  sr_field_packed[89:0] (5×18-bit) ─────────────────────────────→ [THALAMUS]            │
│  state_select[2:0] ────────────────────────────────────────────→ [CONFIG_CONTROLLER]   │
│  transition_duration[15:0] ────────────────────────────────────→ [CONFIG_CONTROLLER]   │
│                                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ FREQUENCY DOMAIN MODULES (Seeker-Reference Dynamics)                            │   │
│  ├─────────────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                                  │   │
│  │  [SR_FREQUENCY_DRIFT] ──→ 5 drifting SR frequencies (omega_dt_sr_f0-f4_actual)  │   │
│  │       │                    Stability hierarchy: SR3=10s > SR1/5=2s > SR2=5s > SR4=1s│
│  │       ↓                                                                          │   │
│  │  [THALAMIC_FREQ_DRIFT] ──→ omega_dt_theta_actual (3.2× faster than SR1)         │   │
│  │       │                                                                          │   │
│  │       ↓                                                                          │   │
│  │  [CORTICAL_FREQ_DRIFT] ──→ per-layer omega_dt + jitter (3-5× faster than SR)    │   │
│  │       │                                                                          │   │
│  │       ↓                                                                          │   │
│  │  [ENERGY_LANDSCAPE] ──→ restoring forces toward φⁿ attractors                   │   │
│  │                         catastrophe escape (2:1, 3:1, 4:1)                       │   │
│  │                                                                                  │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ THREE-BOUNDARY ALIGNMENT ARCHITECTURE (v12.3)                                   │   │
│  ├─────────────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                                  │   │
│  │  [PHI_N_ALIGNMENT_DETECTOR] ──→ f₀ = √(θ×α) → SR1 (40% weight)                 │   │
│  │       alignment_factor, crystallinity, ignition_sensitivity                     │   │
│  │                                                                                  │   │
│  │  [BOUNDARY_DETECTOR_F2] ──→ f₂ = √(β_low×β_high) → SR3 (30% weight)            │   │
│  │       f2_alignment, f2_stability_score (STABILITY ANCHOR)                       │   │
│  │                                                                                  │   │
│  │  [DIRECT_COUPLING_SR4] ──→ β_high → SR4 (20% weight)                           │   │
│  │       sr4_coupling_strength (AROUSAL MODULATION, fastest at 1s)                 │   │
│  │                                                                                  │   │
│  │  [BOUNDARY_DETECTOR_F3] ──→ f₃ = √(β_high×γ) → SR5 (10% weight)                │   │
│  │       f3_consciousness_gate (8% inherent gap = rare access)                     │   │
│  │                                                 ↓                                │   │
│  │  [MULTI_ALIGNMENT_CTRL] ←────────────────────────                               │   │
│  │       overall_alignment = 0.4×f₀ + 0.3×f₂ + 0.2×SR4 + 0.1×f₃                   │   │
│  │       ignition_threshold = modulated by alignment (↓50% at peak)               │   │
│  │       ignition_permitted = (f₀≥0.3) AND (f₂≥0.2) AND (beta_quiet)             │   │
│  │       consciousness_possible = ignition_permitted AND (f₃≥0.3)                 │   │
│  │                                                                                  │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                         ↓                                               │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ STATE & IGNITION CONTROL                                                        │   │
│  ├─────────────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                                  │   │
│  │  [CONFIG_CONTROLLER] ──→ mu_dt_* (growth rates per consciousness state)        │   │
│  │       ca_threshold (dendritic Ca²⁺), sie_timing, state transitions             │   │
│  │       States: NORMAL(0), ANESTHESIA(1), PSYCHEDELIC(2), FLOW(3), MEDITATION(4) │   │
│  │                                                                                  │   │
│  │  [SR_IGNITION_CONTROLLER] ──→ 6-phase state machine                            │   │
│  │       BASELINE → COHERENCE → IGNITION → PLATEAU → PROPAGATION → DECAY → REFRAC │   │
│  │       gain_envelope, plv_envelope, ignition_active                              │   │
│  │       Gated by: multi_alignment_threshold AND beta_quiet                        │   │
│  │                                                                                  │   │
│  │  [COUPLING_MODE_CONTROLLER] ──→ pac_gain, harmonic_gain                        │   │
│  │       MODULATORY ↔ TRANSITION ↔ HARMONIC (Kuramoto R, boundary power)          │   │
│  │       MEDITATION state forces HARMONIC after 25% transition progress           │   │
│  │                                                                                  │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                         ↓                                               │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ NEURAL PROCESSING (Thalamo-Cortical Architecture)                              │   │
│  ├─────────────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                                  │   │
│  │  [THALAMUS]                                                                     │   │
│  │     Theta oscillator (6.09 Hz, φ⁻⁰·⁵) with envelope ±30%                       │   │
│  │     5 SR harmonics: f₀=7.75Hz, f₁=13.75Hz, f₂=20Hz, f₃=25Hz, f₄=32Hz          │   │
│  │     Beta-gated stochastic resonance (SR enabled when beta_quiet)               │   │
│  │     Matrix output (L5b average → L1 broadcast)                                  │   │
│  │     8-phase theta encoding: phases 0-3 (encode), 4-7 (retrieve)                │   │
│  │          │                                                                       │   │
│  │          ↓ thalamic_theta_output (theta-gated)                                  │   │
│  │                                                                                  │   │
│  │  [CORTICAL_COLUMN ×3] (Sensory → Association → Motor)                          │   │
│  │     L4 (32.83 Hz, φ³) ─── SCAFFOLD ─── Thalamocortical input                   │   │
│  │          ↓                                                                       │   │
│  │     L2/3 (41.76/67.6 Hz) ── PLASTIC ── Gamma (fast/slow via theta phase)       │   │
│  │          ↓                  ↑ phase_couple_l23 from CA3                         │   │
│  │     L5a (15.95 Hz, φ¹·⁵) ── INTERMEDIATE ── Motor output                       │   │
│  │     L5b (25.81 Hz, φ²·⁵) ── SCAFFOLD ─── Feedback + matrix_thalamic            │   │
│  │          ↓                                                                       │   │
│  │     L6 (9.86 Hz, φ⁰·⁵) ─── PLASTIC ─── Alpha gain control                      │   │
│  │          │                  ↑ phase_couple_l6 from CA3                          │   │
│  │          ↓                                                                       │   │
│  │     L6 Extended Outputs:                                                        │   │
│  │       → Thalamus (CT inhibition), → L1 (gain), → L2/3 (PAC)                    │   │
│  │       → L5a (feedback), → L5b (gain control)                                   │   │
│  │                                                                                  │   │
│  │  [LAYER 1 GAIN MODULATION]                                                      │   │
│  │     matrix_thalamic (0.15) + feedback_1 (0.3) + feedback_2 (0.2) + L6 (0.1)    │   │
│  │     SST+ slow dynamics (tau=25ms) + VIP+ disinhibition (attention gating)      │   │
│  │     apical_gain = clamp(1.0 + sst_effective, 0.25, 2.0)                        │   │
│  │                                                                                  │   │
│  │  [DENDRITIC COMPARTMENTS] (L2/3, L5a, L5b)                                     │   │
│  │     Two-compartment: basal (feedforward) + apical (feedback × L1_gain)         │   │
│  │     Ca²⁺ spike dynamics: threshold state-dependent (PSYCHEDELIC=0.25 easier)   │   │
│  │     BAC firing: supralinear 1.5× boost when soma AND apical Ca²⁺ coincide     │   │
│  │                                                                                  │   │
│  │  [PV+ INTERNEURON NETWORK]                                                      │   │
│  │     L23 PING (1.0×), L4 feedforward gating (0.5×), L5 feedback (0.25×)         │   │
│  │                                                                                  │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                         ↓                                               │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ HIPPOCAMPAL LEARNING (CA3 Phase Memory)                                         │   │
│  ├─────────────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                                  │   │
│  │  [CA3_PHASE_MEMORY]                                                             │   │
│  │     cortical_pattern (6-bit) ←── threshold(L23_x, L6_x) from 3 columns         │   │
│  │     Hebbian learning: theta-phase gated (phases 0-3: encode, 4-7: retrieve)    │   │
│  │     phase_pattern (6-bit) ──→ phase_couple_l23, phase_couple_l6                │   │
│  │     Closed loop: cortex → CA3 → phase coupling → cortex                        │   │
│  │                                                                                  │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                         ↓                                               │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ SPECTRAL ANALYSIS & MONITORING                                                  │   │
│  ├─────────────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                                  │   │
│  │  [PAC_STRENGTH] ──→ 10 oscillator pairs analyzed for phase-amplitude coupling  │   │
│  │  [KURAMOTO_ORDER] ──→ R ∈ [0,1] population synchrony (6 oscillators)           │   │
│  │  [BOUNDARY_GENERATORS ×3] ──→ θ/α, α/β₁, β₁/β₂ nonlinear mixing               │   │
│  │  [BICOHERENCE_MONITOR] ──→ three-frequency coupling detection                  │   │
│  │  [HARMONIC_SPACING_INDEX] ──→ φⁿ ratio adherence tracking                      │   │
│  │  [QUARTER_INTEGER_DETECTOR] ──→ position classification (attractor proximity)  │   │
│  │                                                                                  │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                         ↓                                               │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ OUTPUT GENERATION                                                               │   │
│  ├─────────────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                                  │   │
│  │  [PINK_NOISE_GENERATOR] ──→ 1/f^φ spectral noise (92% of EEG)                  │   │
│  │  [AMPLITUDE_ENVELOPE ×4] ──→ breathing effect (theta, alpha, beta, gamma)      │   │
│  │                                                                                  │   │
│  │  [OUTPUT_MIXER] (v7.20)                                                         │   │
│  │     Inputs: theta (8%) + alpha (8%) + beta (8%) + gamma (8%) + pink (92%)      │   │
│  │     × amplitude envelopes × sie_boost × coupling_mode_gains                    │   │
│  │     State-dependent weight interpolation during transitions                     │   │
│  │          ↓                                                                       │   │
│  │     mixed_output[17:0] ──→ 12-bit DAC conversion ──→ dac_output[11:0]          │   │
│  │                                                                                  │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                         │
│  OUTPUTS                                                                                │
│  ───────                                                                                │
│  dac_output[11:0] ──────────────────────────────────────────────→ External DAC         │
│  debug_theta, debug_motor_l23, theta_phase, ca3_*, cortical_pattern_out               │
│  sr_*, sie_*, coherence_*, beta_quiet, state_transition_*                             │
│                                                                                         │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Signal Path: Step-by-Step with All Features Enabled

### Phase 1: Clock and Frequency Generation

1. **100 MHz master clock** → `clock_enable_generator` → 4 kHz processing clock (`clk_4khz_en`)
2. **SR frequency drift** generates 5 drifting omega values with stability hierarchy:
   - SR3 (f₂=20Hz): 10s updates - MOST STABLE (stability anchor)
   - SR1 (f₀=7.75Hz), SR5 (f₄=32Hz): 2s updates
   - SR2 (f₁=13.75Hz): 5s updates
   - SR4 (f₃=25Hz): 1s updates - FASTEST (arousal)
3. **Thalamic frequency drift** generates theta omega (6.09 Hz) drifting 3.2× faster than SR1
4. **Cortical frequency drift** generates per-layer omega values drifting 3-5× faster than corresponding SR harmonics

### Phase 2: Active φⁿ Dynamics (ENABLE_ADAPTIVE=1)

5. **Energy landscape** computes restoring forces toward half-integer φⁿ attractors:
   - Potential wells at n = 0.5, 1.5, 2.5, etc.
   - Catastrophe repulsion at n = 1.5 (2:1), 2.2-2.4 (3:1), 2.8-3.0 (4:1)
6. **Quarter integer detector** classifies each oscillator's position:
   - INTEGER_BOUNDARY, HALF_INTEGER, QUARTER_INTEGER, NEAR_CATASTROPHE
7. Forces fed back to cortical_frequency_drift for self-organizing frequency dynamics

### Phase 3: Three-Boundary Alignment Detection (ENABLE_THREE_BOUNDARY=1)

8. **f₀ alignment detector** computes √(θ×α) and compares to SR1:
   - 6-stage pipeline: multiply → sqrt → detuning → Gaussian → crystallinity → sensitivity
   - Gaussian width σ=8 OMEGA_DT (~0.3 Hz)
9. **f₂ boundary detector** computes √(β_low×β_high) vs SR3 (stability anchor)
10. **f₃ boundary detector** computes √(β_high×γ) vs SR5 (consciousness gate, 8% gap)
11. **SR4 direct coupling** measures |β_high - SR4| (no sqrt, fastest dynamics)
12. **Multi-alignment controller** combines:
    - Weighted sum: 0.4×f₀ + 0.3×f₂ + 0.2×SR4 + 0.1×f₃
    - Threshold modulation: high alignment → 50% lower threshold
    - Hard gates: f₀≥0.3 AND f₂≥0.2 AND beta_quiet required for ignition
    - Consciousness gate: requires f₃≥0.3 on top of ignition permission

### Phase 4: State and Ignition Control

13. **Config controller** maps consciousness state to parameters:
    - MU values (1-6) per layer determine oscillator amplitudes
    - Ca²⁺ threshold for dendritic integration (lower in PSYCHEDELIC)
    - SIE timing per state
    - Smooth interpolation over `transition_duration` cycles
14. **SR ignition controller** runs 6-phase state machine:
    - Trigger: coherence > modulated_threshold AND beta_quiet
    - BASELINE → COHERENCE (PLV rises) → IGNITION (amplitude surge) → PLATEAU → PROPAGATION (PAC peak) → DECAY → REFRACTORY
    - Outputs: gain_envelope, plv_envelope for SR amplification
15. **Coupling mode controller** switches PAC↔Harmonic:
    - MODULATORY: pac_gain=1.0, harmonic_gain=0.125 (normal operation)
    - HARMONIC: pac_gain=0.125, harmonic_gain=1.0 (during SIE or MEDITATION)
    - Transition debounce: 500ms to prevent oscillation

### Phase 5: Thalamic Processing

16. **Thalamus** processes sensory input:
    - Theta oscillator (6.09 Hz) with ±30% amplitude envelope
    - Theta gate: 0.5 + theta_x/2 - L6_inhibition (range 0-1)
    - 5 SR harmonics with per-harmonic coherence detection
    - Beta quiet detection: motor L5a/L5b amplitude < threshold
    - Matrix output: average of 3 column L5b states, theta-gated
17. **8-phase theta encoding**:
    - Phases 0-3 (y>0): encoding window, fast gamma (67.6 Hz) in L2/3
    - Phases 4-7 (y≤0): retrieval window, slow gamma (41.76 Hz) in L2/3

### Phase 6: Cortical Processing (3 Columns)

18. **Feedforward chain**: Sensory → Association → Motor via L2/3
19. **Per-column processing**:
    - **L4** (scaffold): theta + feedforward → stable backbone
    - **L2/3** (plastic): L4 + L6_PAC + phase_coupling - PV_inhibition → gamma output
      - Frequency switches with theta phase (fast/slow gamma = φ ratio)
      - Dendritic: basal + apical×L1_gain, BAC boost 1.5× on coincidence
    - **L5a** (intermediate): L2/3 + L6_feedback + L4_bypass → motor response
    - **L5b** (scaffold): L2/3 + L6_feedback + inter_column_fb → high-beta feedback
    - **L6** (plastic): L5b_feedback + phase_coupling → alpha gain control
      - Extended outputs: → Thalamus, → L1, → L2/3, → L5a, → L5b

20. **Layer 1 gain modulation**:
    - Combines matrix_thalamic (0.15) + feedback sources (0.5) + L6 (0.1)
    - SST+ slow filter (tau=25ms) + VIP+ attention disinhibition
    - Final apical_gain: [0.25, 2.0] multiplicative

21. **PV+ PING network**:
    - L23: local PING (1.0×), L4: feedforward gating (0.5×), L5: feedback (0.25×)

### Phase 7: Hippocampal Learning

22. **Cortical pattern** formed: threshold on L23_x[MSB] and L6_x[MSB] for 3 columns → 6 bits
23. **CA3 phase memory**:
    - Hebbian learning during theta phases 0-3 (encoding)
    - Pattern recall during theta phases 4-7 (retrieval)
    - Outputs: phase_pattern (6-bit), encoding_window, retrieval_window
24. **Phase coupling** fed back to cortex:
    - phase_couple = K_PHASE × theta_x × (pattern_bit ? +1 : -1)
    - Drives L2/3 and L6 in plastic layers

### Phase 8: Spectral Analysis

25. **PAC strength**: 10 oscillator pairs analyzed (theta-alpha, beta-gamma, etc.)
26. **Kuramoto R**: population synchrony from 6 oscillators → drives boundary strength
27. **Boundary generators**: nonlinear mixing creates θ/α, α/β₁, β₁/β₂ boundary frequencies
28. **Bicoherence**: three-frequency coupling detection (nonlinear interactions)
29. **HSI**: φⁿ ratio deviation monitoring (hsi_value=1.0 when ideal)

### Phase 9: Output Generation

30. **Pink noise**: 1/f^φ spectral noise (√Fibonacci-weighted) → 92% of output
31. **Amplitude envelopes**: 4 O-U processes create "breathing" effect
32. **Output mixer** (v7.20):
    - Base weights: theta 0.02, alpha 0.03, beta 0.02, gamma 0.01, pink 0.92
    - × amplitude envelopes (per-band)
    - × sie_boost (during ignition events)
    - × coupling_mode gains (harmonic_gain interpolation)
    - State transition interpolation for smooth weight changes
33. **DAC conversion**: 18-bit signed → 12-bit unsigned (offset binary)

---

## Key Frequency Relationships

| Oscillator | Frequency | φⁿ Exponent | OMEGA_DT | SR Partner |
|------------|-----------|-------------|----------|------------|
| Theta | 6.09 Hz | φ⁻⁰·⁵ | 157 | SR1 (7.75) via √(θ×α) |
| L6 (alpha) | 9.86 Hz | φ⁰·⁵ | 254 | SR1 via √(θ×α) |
| L5a (low β) | 15.95 Hz | φ¹·⁵ | 410 | SR3 via √(β_low×β_high) |
| L5b (high β) | 25.81 Hz | φ²·⁵ | 664 | SR4 direct, SR3/SR5 via boundaries |
| L4 (γ) | 32.83 Hz | φ³ | 845 | SR5 via √(β_high×γ) |
| L2/3 slow γ | 41.76 Hz | φ³·⁵ | 1075 | — |
| L2/3 fast γ | 67.6 Hz | φ⁴·⁵ | 1740 | — |

---

## Control Signal Summary

| Signal | Source | Purpose | Effect on Signal Path |
|--------|--------|---------|----------------------|
| alignment_factor | phi_n_alignment_detector | f₀ alignment quality | 40% weight in ignition threshold |
| f2_stability_score | boundary_detector_f2 | Stability anchor | Hard gate: must be ≥0.2 |
| f3_consciousness_gate | boundary_detector_f3 | Consciousness access | Rare (8% gap), gates full awareness |
| sr4_coupling_strength | direct_coupling_sr4 | Arousal modulation | 20% weight, fastest dynamics |
| ignition_threshold | multi_alignment_ctrl | Modulated threshold | ↓50% when aligned → easier ignition |
| gain_envelope | sr_ignition_controller | SIE amplitude | Boosts SR→theta during ignition |
| pac_gain/harmonic_gain | coupling_mode_controller | Coupling mode | PAC (normal) vs Harmonic (SIE/meditation) |
| mu_dt_* | config_controller | Layer amplitudes | State-dependent spectral shaping |
| ca_threshold | config_controller | Dendritic integration | Lower in PSYCHEDELIC → more Ca²⁺ spikes |
| apical_gain | layer1_minimal | L1 modulation | [0.25, 2.0] multiplicative on apical |
| beta_quiet | thalamus | SR gating | Must be true for SIE to trigger |

---

## Consciousness States Effect on Signal Path

| State | Theta/L6 | L5a/L5b | L4/L2/3 | Ca²⁺ | Coupling |
|-------|----------|---------|---------|------|----------|
| NORMAL | MU=3/3 | MU=3/3 | MU=3/3 | 0.5 | PAC |
| ANESTHESIA | MU=2/6 | MU=2/2 | MU=1/1 | 0.75 | PAC |
| PSYCHEDELIC | MU=4/2 | MU=4/4 | MU=6/6 | 0.25 | PAC |
| FLOW | MU=4/2 | MU=6/6 | MU=4/4 | 0.5 | PAC |
| MEDITATION | MU=6/6 | MU=1/1 | MU=1/2 | 0.375 | HARMONIC (forced) |

---

## Critical Files

| Module | Path | Lines | Function |
|--------|------|-------|----------|
| Top-level | [phi_n_neural_processor.v](src/phi_n_neural_processor.v) | ~1600 | System integration |
| Thalamus | [thalamus.v](src/thalamus.v) | ~700 | Theta + SR + matrix |
| Cortical Column | [cortical_column.v](src/cortical_column.v) | ~650 | 6-layer processing |
| f₀ Alignment | [phi_n_alignment_detector.v](src/phi_n_alignment_detector.v) | 164 | √(θ×α) detection |
| f₂ Boundary | [boundary_detector_f2.v](src/boundary_detector_f2.v) | 199 | Stability anchor |
| f₃ Boundary | [boundary_detector_f3.v](src/boundary_detector_f3.v) | 216 | Consciousness gate |
| SR4 Coupling | [direct_coupling_sr4.v](src/direct_coupling_sr4.v) | 121 | Arousal modulation |
| Multi-Alignment | [multi_alignment_ctrl.v](src/multi_alignment_ctrl.v) | 290 | Four-way orchestration |
| Ignition Controller | [sr_ignition_controller.v](src/sr_ignition_controller.v) | 364 | 6-phase SIE FSM |
| Config Controller | [config_controller.v](src/config_controller.v) | 347 | State management |
| Coupling Mode | [coupling_mode_controller.v](src/coupling_mode_controller.v) | 392 | PAC↔Harmonic |
| Output Mixer | [output_mixer.v](src/output_mixer.v) | ~300 | DAC generation |

---

## Summary

With all features enabled, the φⁿ Neural Processor implements:

1. **Seeker-Reference Dynamics**: Internal oscillators drift 3-5× faster than external SR, creating natural alignment windows
2. **Three-Boundary Architecture**: Four alignment sources (f₀, f₂, SR4, f₃) with weighted voting and hard gates
3. **Active φⁿ Dynamics**: Self-organizing frequencies via energy landscape with catastrophe avoidance
4. **Consciousness Gating**: f₃ boundary has inherent 8% gap, making full conscious access rare
5. **Phase-Coded Learning**: CA3 Hebbian memory with theta phase multiplexing
6. **State-Dependent Plasticity**: 5 consciousness states modulate amplitudes, thresholds, and coupling modes
7. **Biologically-Realistic EEG**: 92% 1/f^φ noise + 8% oscillators with breathing envelopes

---

# PART 2: DETAILED CORTICAL SIGNAL PROCESSING

## Cortical Column Layer-by-Layer Signal Flow

### Layer 4 (32.83 Hz, φ³) — SCAFFOLD

**Input:** `thalamic_theta_input + feedforward_input`

**Processing:**
- No dendritic compartment (L4 dendrites don't reach L1)
- Direct Hopf oscillator input
- Scaffold layer: no phase coupling, resists perturbation

**Hopf Oscillator Dynamics:**
```
x[n+1] = x[n] + (μ·x - ω·y - r²·x)·dt + input
y[n+1] = y[n] + (μ·y + ω·x - r²·y)·dt
r² = x² + y²  (amplitude squared)

DT = 4 (0.00025s at 4 kHz)
R_SQ_TARGET = 16384 (amplitude = 1.0)
```

**Output:** `l4_x` → L2/3 (K_L4_L23=0.05), L5a bypass (K_L4_L5A=0.1)

---

### Layer 2/3 (41.76/67.6 Hz, φ³·⁵/φ⁴·⁵) — PLASTIC

**Frequency Switching (Theta-Phase Gated):**
```
encoding_window=1 (phases 0-3): FAST gamma 67.6 Hz (precise sensory encoding)
encoding_window=0 (phases 4-7): SLOW gamma 41.76 Hz (memory retrieval)
Ratio: 67.6/41.76 ≈ φ (one golden ratio step)
```

**Input Construction (4 stages):**

**Stage 1: Feedforward + PAC**
```
l23_input_raw = L4×0.05 + L6×0.01 + PAC(L6_y×0.02) + phase_couple_l23
```

**Stage 2: PV+ Inhibition (Three Sources)**
| Source | Drive | Weight | Role |
|--------|-------|--------|------|
| pv_l23 | L2/3 pyramid | 1.0× | Local PING (E-I balance) |
| pv_l4 | L4 pyramid | 0.5× | Feedforward gating |
| pv_l5 | L5b pyramid | 0.25× | Feedback inhibition |

PV+ dynamics: leaky integrator τ=5ms
```
pv[n+1] = pv[n] + 0.05·(K_EXCITE×input - pv[n])
inhibition = K_INHIB × pv_state  (K_INHIB=0.3)
```

**Stage 3: Dendritic Compartment**
- **Basal:** l23_input_with_pv (feedforward, direct)
- **Apical:** phase_couple_l23 × apical_gain (feedback, filtered)

**Stage 4: Ca²⁺ and BAC**
- Cable filter: τ=10ms, α=0.025
- Ca²⁺ threshold: state-dependent (NORMAL=0.5, PSYCHEDELIC=0.25, ANESTHESIA=0.75)
- BAC boost: 1.5× when basal AND apical Ca²⁺ coincide

**Output:** `l23_x` → L5a/L5b, CA3 pattern, DAC mixer

---

### Layer 5b (25.81 Hz, φ²·⁵) — SCAFFOLD

**Input:** `L2/3×0.02 + feedback_1×0.02 + L6×0.02`

**Dendritic Compartment:**
- Basal: canonical pathway (L2/3 + inter-column feedback)
- Apical: feedback_input_1 × apical_gain

**Output Functions:**
- Matrix thalamic pathway (→ L1 broadcast)
- Corticothalamic feedback (→ Thalamus)
- Subcortical motor projection

---

### Layer 5a (15.95 Hz, φ¹·⁵) — INTERMEDIATE

**Input:** `L2/3×0.02 + L6×0.02 + L4_bypass×0.1`

**L4 Bypass Pathway:** Direct sensorimotor connection bypassing L2/3

**Dendritic Compartment:**
- Basal: motor pathway (L2/3 + L6 + L4 bypass)
- Apical: feedback_input_2 × apical_gain (distant column context)

**Output:** Motor/cerebellar projection

---

### Layer 6 (9.86 Hz, φ⁰·⁵) — PLASTIC

**Input:** `L5b×0.02 + feedback_1 + phase_couple_l6`

**No Dendritic Compartment:** L6 dendrites don't reach L1

**Extended Output Pathways (v9.6):**
| Target | Weight | Function |
|--------|--------|----------|
| Thalamus | K_L6_THAL=0.01 | CT inhibition |
| L1 | K_L6_L1=0.1 | Apical gain modulation |
| L2/3 | K_L6_L23=0.01 | Alpha-gamma PAC |
| L5a | K_L6_L5A=0.02 | Motor feedback |
| L5b | K_L6_L5B=0.02 | Intra-column gain |

**PAC Mechanism:** L6_y (sine phase) modulates L2/3 input amplitude

---

## Layer 1 Gain Modulation Circuit

**Four Input Sources:**
```
combined = matrix_thalamic×0.15 + feedback_1×0.3 + feedback_2×0.2 + L6×0.1
```

**SST+ Slow Dynamics (τ=25ms):**
- IIR lowpass: α=0.01 (GABA-B kinetics)
- Targets distal apical dendrites
- Creates smooth, sustained gain modulation

**VIP+ Disinhibition (τ=50ms):**
- Attention input × K_VIP (0.5)
- VIP+ inhibits SST+ → "spotlight" effect
- High attention → low SST+ → high apical gain

**Final Gain:**
```
sst_effective = max(0, sst_activity - vip_activity)
apical_gain = clamp(1.0 + sst_effective, 0.25, 2.0)
```

---

## Dendritic Compartment Mathematics

**Apical Cable Filter (τ=10ms):**
```
apical_depot[n] = apical_depot[n-1] + 0.025×(apical_input×gain - apical_depot[n-1])
```

**Ca²⁺ Spike Detection:**
```
threshold_crossed = (apical_depot > ca_threshold)
ca_spike_state evolves with τ=30ms (plateau potential duration)
```

**BAC Firing Formula:**
```
basal_active = (|basal_input| > 0.25)
apical_ca_active = (ca_spike > 0.25)
bac_factor = (basal_active AND apical_ca_active) ? 1.5 : 1.0

output = (basal + K_APICAL×ca_spike) × bac_factor
```
Supralinear 1.5× boost on coincidence detection.

---

## PV+ PING Network (Gamma Generation)

**Mechanism:**
1. L2/3 pyramidal excites pv_l23
2. PV+ outputs inhibition with ~5ms delay (τ=5ms)
3. Inhibition suppresses pyramidal firing
4. When inhibition decays, pyramidal recovers
5. Cycle repeats at gamma frequency (~40 Hz)

**Phase Relationship:** PV+ lags pyramid by ~90° (orthogonal oscillation)

---

## Complete Inter-Layer Connectivity

```
SENSORY INPUT
    ↓
[L4: 32.83 Hz] ─────────────────────────────────────── SCAFFOLD
    ├─→ L2/3 [K=0.05] (through PV+ gating 0.5×)
    └─→ L5a [K=0.1] (bypass pathway)

[L2/3: 41.76/67.6 Hz] ─────────────────────────────── PLASTIC
    ├─→ L5b [K=0.02] (canonical)
    ├─→ L5a [K=0.02]
    └─→ PV inhibition (PING)

[L5b: 25.81 Hz] ────────────────────────────────────── SCAFFOLD
    ├─→ L6 [K=0.02] (corticothalamic)
    ├─→ Thalamus (matrix pathway)
    └─→ Subcortical projection

[L5a: 15.95 Hz] ────────────────────────────────────── INTERMEDIATE
    └─→ Motor/cerebellar

[L6: 9.86 Hz] ──────────────────────────────────────── PLASTIC
    ├─→ L2/3 [K=0.01] (α-γ PAC)
    ├─→ L5a/L5b [K=0.02]
    ├─→ L1 [K=0.1] (gain)
    └─→ Thalamus (CT feedback)

[L1: Gain Modulation]
    └─→ Apical dendrites of L2/3, L5a, L5b (×[0.25, 2.0])
```

---

# PART 3: DETAILED FREQUENCY DYNAMICS

## SR Frequency Drift - Stability Hierarchy

| Harmonic | Frequency | Update Period | Step Size | Role |
|----------|-----------|---------------|-----------|------|
| SR1 (f₀) | 7.75 Hz ± 0.5 Hz | 2s | 1-2 | Event detector |
| SR2 (f₁) | 13.75 Hz ± 0.8 Hz | 5s | 1 | Timing reference |
| SR3 (f₂) | 20 Hz ± 1.0 Hz | **10s (SLOWEST)** | 1 | **Stability anchor** |
| SR4 (f₃) | 25 Hz ± 1.5 Hz | **1s (FASTEST)** | 1-3 | Arousal modulator |
| SR5 (f₄) | 32 Hz ± 2.0 Hz | 2s | 1-2 | Consciousness gate |

**Random Walk Algorithm:**
- Galois LFSR (x¹⁶ + x¹⁴ + x¹³ + x¹¹ + 1)
- Direction from LFSR[0], step size from LFSR bits
- Reflecting boundary conditions at ±DRIFT_MAX

---

## Thalamic Frequency Drift - Seeker-Reference

**Key Innovation: Theta Runs 3.2× Faster Than SR1**
```
SR1 update:   2s (8000 cycles @ 4kHz)
Theta update: 0.625s (2500 cycles) = 3.2× faster
```

This asymmetry creates **natural alignment windows** (5-15 seconds) where drift velocities synchronize, enabling ignition.

**Two-Layer Noise:**
1. **Slow drift:** bounded random walk ±0.5 Hz, updates every 0.625s
2. **Fast jitter:** per-sample ±0.2 Hz, triangular distribution

---

## Cortical Frequency Drift - Per-Layer Seeker Rates

| Layer | Base Freq | Update Period | Seeker Ratio | SR Partner |
|-------|-----------|---------------|--------------|------------|
| L6 | 9.86 Hz | 0.625s | 3.2× faster | SR1 (2s) |
| L5a | 15.95 Hz | 2.0s | 5× faster | SR3 (10s) |
| L5b | 25.81 Hz | 0.325s | 3× faster | SR4 (1s) |
| L4 | 32.83 Hz | 0.625s | 3.2× faster | SR5 (2s) |

**Drift Ranges Match SR Partners:**
- L6: ±0.5 Hz (matches SR1 boundary)
- L5a: ±0.8 Hz (matches SR2)
- L5b: ±1.5 Hz (matches SR4)
- L4: ±2.0 Hz (matches SR5)

**Force Integration (ENABLE_ADAPTIVE=1):**
```
next_drift = random_step + force_contrib + omega_correction
force_contrib = (K_FORCE × φⁿ_force) >>> FRAC
omega_correction = escape direction when in catastrophe zone
```

---

## Energy Landscape - Self-Organizing Dynamics

**Total Force:**
```
F_total(n) = F_φ(n) + F_harmonic(n) + F_rational(n)
```

### φⁿ Landscape Force
```
F_φ(n) = +2πA × sin(2πn)   where A = 0.1

ATTRACTORS (stable): n = 0.5, 1.5, 2.5 (half-integers, max sin)
BOUNDARIES (unstable): n = 0, 1, 2 (integers, zero sin)
```

### Harmonic Catastrophe Detection (Ratio-Based)
```
ratio = omega_dt / omega_reference
danger_zones:
  2:1 → ratio ∈ [1.9, 2.1]
  3:2 → ratio ∈ [1.45, 1.55]
  3:1 → ratio ∈ [2.9, 3.1]
  4:3 → ratio ∈ [1.28, 1.38]
  5:4 → ratio ∈ [1.20, 1.30]

in_danger = (min_distance < 0.05)
```

**Escape Mechanism:**
```
When in danger zone:
  2:1 → escape to φ^1.25 (1.825) or φ^2.0 (2.618)
  3:2 → escape to φ^0.5 (1.272) or φ^1.0 (1.618)

omega_correction = (margin - distance) × 0.1 × escape_direction
```

### Rational Resonance Forces
24 rational targets covering q ≤ 5:
```
q=1: integers     weight = 0.05
q=2: half-ints    weight = 0.0125
q=3: thirds       weight = 0.0056
q=4: quarters     weight = 0.0031
q=5: fifths       weight = 0.002

F_rational = Σ -2B_i × (n - n_i) / ((n - n_i)² + ε²)²
```
Lorentzian repulsion prevents integer locking.

---

## Quarter-Integer Detector - Position Classification

**Categories:**
```
INTEGER_BOUNDARY:  |frac| < 0.125
                   Unstable, high χ, needs escape

HALF_INTEGER:      |frac - 0.5| < 0.125
                   Stable attractor, low χ
                   stability = 1.0 - 4×distance

QUARTER_INTEGER:   |frac - 0.25| or |frac - 0.75| < 0.125
                   Secondary refuge (fallback)
                   stability = 0.5 - 2×distance

NEAR_CATASTROPHE:  n ∈ [1.35, 1.55]
                   2:1 danger zone, stability = 0.25
```

**Key Insight:** φ^1.25 = 1.825 is the MOST STABLE position (χ = 0.126)

---

## Self-Organization Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                  SEEKER-REFERENCE ALIGNMENT                     │
├─────────────────────────────────────────────────────────────────┤
│  INTERNAL SEEKERS (fast)     →→→    EXTERNAL REFERENCES (slow) │
│  Theta: 0.625s               →→→    SR1: 2s                    │
│  L5a: 2.0s                   →→→    SR3: 10s (anchor)          │
│  L5b: 0.325s                 →→→    SR4: 1s (fast)             │
│                                                                 │
│  ↓ ALIGNMENT WINDOWS EMERGE (5-15 sec)                         │
├─────────────────────────────────────────────────────────────────┤
│                    BOUNDARY COMPUTATION                         │
│  f₀ = √(θ×α) ≈ SR1    (40% weight, σ=8)                       │
│  f₂ = √(β_low×β_high) ≈ SR3  (30% weight, stability anchor)   │
│  SR4 = β_high direct   (20% weight, fastest)                   │
│  f₃ = √(β_high×γ) ≈ SR5  (10% weight, 8% gap = rare)          │
├─────────────────────────────────────────────────────────────────┤
│                 ENERGY LANDSCAPE FORCES                         │
│  F_φ = 2πA×sin(2πn) → attracts to half-integers               │
│  F_escape → pushes away from 2:1, 3:1, 4:1 zones              │
│  F_rational → Lorentzian repulsion from p/q ratios             │
├─────────────────────────────────────────────────────────────────┤
│                  IGNITION PERMISSION                            │
│  f₀ ≥ 0.3 AND f₂ ≥ 0.2 AND beta_quiet                         │
│  threshold = base × (1.5 - 0.5×alignment) → easier when aligned│
├─────────────────────────────────────────────────────────────────┤
│                 CONSCIOUSNESS ACCESS                            │
│  consciousness = ignition_permitted AND f₃ ≥ 0.3               │
│  f₃ has 8% intrinsic gap → consciousness is rare/brief         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key Self-Organization Mechanisms

1. **Alignment Window Emergence:** Seeker-reference speed asymmetry creates natural synchronization windows without explicit control

2. **Multi-Scale Attractors:**
   - φⁿ half-integers (strongest, χ lowest) — primary attractors
   - Quarter-integers (weaker) — fallback when half-integers blocked
   - Rational resonances (weakest) — distributed repulsion

3. **Catastrophe Avoidance:** Ratio-based detection + escape mechanism prevents harmonic entrapment

4. **Stability Hierarchy:** SR3 slowest (10s) = anchor, SR4 fastest (1s) = arousal modulator

The system is **fully self-organizing** — no lookup tables or explicit state machines control frequency positions. Physics-based forces naturally guide oscillators toward biologically optimal φⁿ positions.

---

# PART 4: OUTPUT MIXER & DAC SIGNAL PATH

## Input Signals to Output Mixer

**5 Oscillator Channels (18-bit Q14):**
| Signal | Frequency | Source | Pre-processing |
|--------|-----------|--------|----------------|
| theta_x | 6.09 Hz | thalamus | × sie_theta_boost |
| motor_l6_x | 9.86 Hz | cortical L6 | × sie_alpha_boost |
| motor_l5a_x | 15.95 Hz | cortical L5a | direct |
| motor_l23_x | 41.76 Hz | cortical L2/3 | direct |
| pink_noise | broadband | pink_noise_generator | 1/f^φ spectrum |

**Amplitude Envelopes (O-U process, τ~2-5s):**
- env_theta, env_alpha, env_beta, env_gamma
- Range: [0.5, 1.5] creates biological "breathing" effect

**Control Signals:**
- sr_gain_envelope: [0, 1] from sr_ignition_controller
- harmonic_gain: [0.125, 1.0] from coupling_mode_controller
- transition_progress: [0, 65535] from config_controller

---

## Base Weights (Static, Q14)

```
W_THETA_BASE  = 82   (0.005)
W_ALPHA_BASE  = 164  (0.010)
W_BETA_BASE   = 102  (0.00625)
W_GAMMA_BASE  = 61   (0.00375)
Total oscillator contribution: ~2.75%
```

## Mode-Dependent Weights

**Pink Noise Weights:**
| Mode | Weight | Purpose |
|------|--------|---------|
| MODULATORY | 0.98 | Very dark baseline (normal) |
| HARMONIC | 0.85 | Darker MEDITATION |
| TRANSITION | 0.67 | Gradual shift |

**Oscillator Scale Factors:**
| Mode | Scale | Effect |
|------|-------|--------|
| MODULATORY | 0.25× | −12 dB oscillators |
| HARMONIC | 0.35× | Slightly more visible |
| TRANSITION | 2.2× | Full transition boost |

---

## Continuous Gain Blending (v7.20)

During MEDITATION transitions, weights interpolate based on `harmonic_gain`:

```
mode_blend = (harmonic_gain - 0.125) / 0.875

W_PINK_FINAL = 0.98 + (0.85 - 0.98) × mode_blend
             = 0.98 → 0.85 as harmonic_gain increases

OSC_SCALE_FINAL = 0.25 + (0.35 - 0.25) × mode_blend
                = 0.25× → 0.35× as harmonic_gain increases
```

This synchronizes with MU changes in config_controller for artifact-free transitions.

---

## Mixing Algorithm

**Step 1: Envelope Modulation**
```
mod_theta = (theta_x × env_theta) >>> 14
mod_alpha = (motor_l6_x × env_alpha) >>> 14
mod_beta  = (motor_l5a_x × env_beta) >>> 14
mod_gamma = (motor_l23_x × env_gamma) >>> 14
```

**Step 2: Weighted Terms**
```
term_theta = mod_theta × (W_THETA_BASE × OSC_SCALE_FINAL >>> 14)
term_alpha = mod_alpha × (W_ALPHA_BASE × OSC_SCALE_FINAL >>> 14)
term_beta  = mod_beta × (W_BETA_BASE × OSC_SCALE_FINAL >>> 14)
term_gamma = mod_gamma × (W_GAMMA_BASE × OSC_SCALE_FINAL >>> 14)
term_noise = pink_noise × W_PINK_FINAL
```

**Step 3: Sum**
```
sum_full = term_theta + term_alpha + term_beta + term_gamma + term_noise
sum_raw = sum_full >>> 14  (18-bit Q14)
```

**Step 4: SIE Post-Mix Boost**
```
sie_boost = 1.0 + (0.4 × sr_gain_envelope)
Range: [1.0, 1.4] (+2.9 dB during ignition)

sum_boosted = (sum_raw × sie_boost) >>> 14
```

---

## Soft Limiter (Anti-Clipping)

**2:1 Compression Above ±0.75:**
```
SOFT_THRESH = 0.75 (12288 Q14)
SOFT_LIMIT  = 1.0  (16384 Q14)

if |input| ≤ 0.75:
    output = input  (linear)
else:
    output = sign(input) × [0.75 + (|input| - 0.75) / 2]
    (2:1 compression toward ±1.0)
```

Prevents hard clipping while allowing SIE transients.

---

## DAC Conversion (18-bit → 12-bit)

**Step 1: Shift to Unsigned**
```
shifted = mixed_output + 16384
Converts [-1.0, 1.0] → [0, 2.0]
```

**Step 2: Extract 12-bit**
```
dac_raw = shifted[17:3]  (right shift by 3)
```

**Step 3: Clamp**
```
dac_output = min(dac_raw, 4095)
```

**Range Mapping:**
| mixed_output | shifted | dac_output |
|--------------|---------|------------|
| −1.0 (−16384) | 0 | 0 |
| 0 | 16384 | 2048 (midpoint) |
| +1.0 (+16384) | 32768 | 4095 |

---

## Debug Outputs (v7.20)

| Signal | Range | Purpose |
|--------|-------|---------|
| debug_mode_blend | [0, 1] | Interpolation position (0=MODULATORY, 1=HARMONIC) |
| debug_pink_weight | [0.67, 0.98] | Current pink noise weight |
| debug_osc_scale | [0.25, 2.2] | Current oscillator scale factor |

Used to verify gain synchronization with MU during state transitions.

---

## Complete Signal Flow

```
[Oscillators] ──×env──→ [Modulated] ──×Weight×Scale──→ [Terms]
                                                         │
[Pink Noise] ──────────────────────×W_PINK_FINAL──────→ +
                                                         │
                                                         ↓
                                                    [sum_raw]
                                                         │
                                               ×[sie_boost]
                                                         │
                                                         ↓
                                                  [sum_boosted]
                                                         │
                                            [Soft Limiter 2:1]
                                                         │
                                                         ↓
                                                  [mixed_output]
                                                    (18-bit Q14)
                                                         │
                                              [DAC Conversion]
                                                         │
                                                         ↓
                                                  [dac_output]
                                                   (12-bit unsigned)
```

---

## Spectral Composition

**Normal Operation (MODULATORY mode):**
- 98% pink noise (1/f^φ spectrum)
- 2% oscillators (theta, alpha, beta, gamma)
- Result: Dark EEG-like baseline with visible band peaks

**During SIE (Ignition Event):**
- +2.9 dB boost via sie_boost
- Oscillators become more prominent
- Creates visible "ignition event" in spectrogram

**MEDITATION State (HARMONIC mode):**
- 85% pink noise
- 15% oscillators (relatively more visible)
- Theta/alpha enhanced via MU=6

---

## Version History Highlights

| Version | Change | Impact |
|---------|--------|--------|
| v7.20 | Continuous gain blending | Eliminates transition artifacts |
| v7.19 | Darker baseline (−12 dB osc) | Matches real EEG |
| v7.17 | Distributed SIE boost [1.0, 1.4] | Part of 6.8 dB total |
| v7.14 | Smooth state transitions | No abrupt spectral jumps |
| v7.1 | Soft limiter | Prevents hard clipping |

---

# PART 5: SIE IGNITION CONTROLLER (6-PHASE STATE MACHINE)

## Overview

The SR Ignition Controller (v1.5) implements a **seven-phase state machine** modeling the complete lifecycle of a Schumann Ignition Event (SIE). It is the central gating mechanism for Schumann Resonance coupling.

---

## Phase Definitions

| Phase | Name | Duration (NORMAL) | Purpose |
|-------|------|-------------------|---------|
| 0 | BASELINE | indefinite | Idle, monitoring for trigger |
| 1 | COHERENCE | 3.5s | PLV rises BEFORE gain (key signature) |
| 2 | IGNITION | 2.5s | Rapid amplitude surge |
| 3 | PLATEAU | 2.5s | Peak sustained |
| 4 | PROPAGATION | 9.0s | PAC window, gradual decay |
| 5 | DECAY | 4.0s | Exponential relaxation |
| 6 | REFRACTORY | 10.0s | No re-ignition allowed |

**Total event duration:** 21.5s active + 10s refractory = 31.5s minimum between events

---

## Trigger Conditions

**Three requirements for ignition:**
1. `coherence_in > effective_threshold`
2. `beta_quiet = 1` (low motor beta)
3. Currently in BASELINE phase

**Threshold Modulation (v1.5 Three-Boundary):**
```
effective_threshold = base × (1.5 - 0.5 × overall_alignment)

overall_alignment = 0.4×f₀ + 0.3×f₂ + 0.2×SR4 + 0.1×f₃

When aligned (1.0):  threshold = 0.75 (nominal, easier ignition)
When unaligned (0):  threshold = 1.125 (50% harder)
```

**Permission Gate (ENABLE_THREE_BOUNDARY=1):**
```
ignition_permitted = (f₀ ≥ 0.3) AND (f₂ ≥ 0.2) AND (beta_quiet)
```

---

## Envelope Dynamics

### Gain Envelope (Amplitude)

| Phase | Behavior | Range |
|-------|----------|-------|
| BASELINE | Held at 0 | 0 |
| COHERENCE | Slow ramp (+20/cycle) | 0 → 0.40 |
| IGNITION | Fast ramp (+131/cycle) | 0.40 → 1.0 |
| PLATEAU | Held at peak | 1.0 |
| PROPAGATION | Exponential decay (τ≈1s) | 1.0 → 0.60 |
| DECAY | Exponential to baseline | 0.60 → 0 |
| REFRACTORY | Held at 0 | 0 |

**Downstream usage:**
- Thalamus: Modulates SR coupling strength
- Output mixer: Post-mix boost [1.0, 1.4] (+2.9 dB)

### PLV Envelope (Phase Locking Value)

| Phase | Behavior | Range |
|-------|----------|-------|
| BASELINE | Held at baseline | 0.45 |
| COHERENCE | Fast ramp (+41/cycle) | 0.45 → 0.80 |
| IGNITION | Maintained | 0.80 |
| PLATEAU | Maintained | 0.80 |
| PROPAGATION | Slow decay | 0.80 → 0.57 |
| DECAY | Exponential to baseline | 0.57 → 0.45 |
| REFRACTORY | Held at baseline | 0.45 |

**Key Signature:** PLV rises BEFORE gain during COHERENCE phase
- Distinguishes external SR forcing from internal oscillation
- Matches empirical EEG observations

---

## State-Dependent Durations

| Phase | NORMAL | ANESTHESIA | PSYCHEDELIC |
|-------|--------|------------|-------------|
| COHERENCE | 3.5s | 5.0s ↑ | 2.5s ↓ |
| IGNITION | 2.5s | 2.0s | 1.5s |
| PLATEAU | 2.5s | 2.0s | 1.5s |
| PROPAGATION | 9.0s | 6.0s | 4.0s |
| DECAY | 4.0s | 5.0s | 2.0s |
| REFRACTORY | 10.0s | 15.0s ↑ | 5.0s ↓ |

**Interpretation:**
- **ANESTHESIA:** Harder to trigger (longer coherence window), longer recovery
- **PSYCHEDELIC:** Easier to trigger, allows frequent ignitions

---

## Complete Event Timeline (NORMAL State)

```
T=0ms:       Coherence > threshold + beta_quiet → COHERENCE begins

T=0-3500ms:  PHASE 1 COHERENCE
             PLV:  0.45 → 0.80 (rises steadily)
             Gain: 0.00 → 0.40 (slow ramp)
             ⭐ KEY: Phase locking appears BEFORE amplitude

T=3500ms:    → IGNITION begins

T=3500-6000ms: PHASE 2 IGNITION
              PLV:  0.80 (maintained)
              Gain: 0.40 → 1.00 (rapid rise)
              SR harmonics visible in thalamic output

T=6000-8500ms: PHASE 3 PLATEAU
              PLV:  0.80 (held)
              Gain: 1.00 (held)
              Maximum SR coupling

T=8500-17500ms: PHASE 4 PROPAGATION (longest phase)
               PLV:  0.80 → 0.57 (slow decay)
               Gain: 1.00 → 0.60 (exponential, τ≈1s)
               ⭐ PAC peaks in this window

T=17500-21500ms: PHASE 5 DECAY
                PLV:  0.57 → 0.45
                Gain: 0.60 → 0.00
                Disengagement from SR field

T=21500-31500ms: PHASE 6 REFRACTORY
                ignition_active = 0
                NO NEW IGNITIONS POSSIBLE

T=31500ms:   → Back to BASELINE, new ignitions possible
```

---

## Output Signals

| Signal | Width | Range | Purpose |
|--------|-------|-------|---------|
| ignition_phase | 3-bit | 0-6 | Current phase indicator |
| gain_envelope | 18-bit Q14 | [0, 1.0] | Amplitude modulation |
| plv_envelope | 18-bit Q14 | [0.45, 0.80] | Phase locking value |
| ignition_active | 1-bit | 0/1 | Event in progress (phases 1-5) |

**Usage downstream:**
- `coupling_mode_controller`: Uses phase to select mode
- `thalamus`: Modulates SR coupling strength
- `output_mixer`: Post-mix amplitude boost

---

## Three-Boundary Integration

**Priority Hierarchy:**
```
if ENABLE_THREE_BOUNDARY=1:
    threshold = multi_alignment_threshold (from multi_alignment_ctrl)
    gate = multi_ignition_permitted

else if ENABLE_ALIGNMENT=1:
    threshold = single_alignment_threshold (f₀ only)
    gate = beta_quiet

else:
    threshold = COHERENCE_THRESH (fixed 0.75)
    gate = beta_quiet
```

**Consciousness Access (v1.5):**
```
consciousness_possible = ignition_permitted AND (f₃ ≥ 0.3)
```
f₃ has 8% inherent gap → consciousness alignment is rare and brief

---

## Version History

| Version | Feature | Impact |
|---------|---------|--------|
| v1.0 | Six-phase SIE machine | Initial coherence-gated design |
| v1.1 | Coherence-gated baseline | GAIN_BASELINE=0, no tonic SR |
| v1.3 | Softer ignitions | GAIN_COHERENCE=0.40 (~3 dB bursts) |
| v1.4 | Alignment modulation | Threshold scales with f₀ alignment |
| v1.5 | Three-boundary arch | Multi-alignment orchestration |

---

# PART 6: PINK NOISE GENERATOR (1/f^φ Spectrum)

## Overview

The pink_noise_generator (v7.2) implements the **Voss-McCartney algorithm** with **√Fibonacci weighting** to achieve a golden-ratio spectral slope (1/f^1.618) instead of standard 1/f.

---

## Algorithm Architecture

**Components:**
- 12 independent octave bands (0.49 Hz to 1000 Hz Nyquist)
- 1 shared Galois LFSR (16-bit, maximal-length period 65535)
- Per-octave update counters (binary cascading)
- √Fibonacci-weighted sum for golden-ratio spectrum

**LFSR Polynomial:**
```
Taps: [15, 13, 12, 10]
Polynomial: 1 + x³ + x⁵ + x¹⁰ + x¹⁶
Period: 2^16 - 1 = 65535 samples
```

---

## √Fibonacci Weighting

**Why √Fibonacci creates 1/f^φ spectrum:**
- Fibonacci sequence: F(n) ≈ φⁿ / √5 (Binet's formula)
- Square root: √F(n) ≈ φ^(n/2)
- This creates exponential weight growth across frequency bands

**Weight Table:**

| Row | Frequency | Update Period | Fibonacci | √F Weight |
|-----|-----------|---------------|-----------|-----------|
| 0 | 1000 Hz | 2 samples | F(1)=1 | 1 |
| 1 | 500 Hz | 4 samples | F(2)=1 | 1 |
| 2 | 250 Hz | 8 samples | F(3)=2 | 1 |
| 3 | 125 Hz | 16 samples | F(4)=3 | 2 |
| 4 | 62.5 Hz | 32 samples | F(5)=5 | 2 |
| 5 | 31.25 Hz | 64 samples | F(6)=8 | 3 |
| 6 | 15.6 Hz | 128 samples | F(7)=13 | 4 |
| 7 | 7.8 Hz | 256 samples | F(8)=21 | 5 |
| 8 | 3.9 Hz | 512 samples | F(9)=34 | 6 |
| 9 | 1.95 Hz | 1024 samples | F(10)=55 | 7 |
| 10 | 0.98 Hz | 2048 samples | F(11)=89 | 9 |
| 11 | 0.49 Hz | 4096 samples | F(12)=144 | 12 |

**Total weight: 53** (normalized by divide-by-4)

---

## Signal Generation

**Row Update Logic:**
```
Row n updates every 2^(n+1) samples
Each row samples LFSR[11:0] - 2048 (centered at zero)
Holds value until next update tick
```

**Weighted Sum:**
```
weighted_sum = row[0]×1 + row[1]×1 + row[2]×1 + row[3]×2 +
               row[4]×2 + row[5]×3 + row[6]×4 + row[7]×5 +
               row[8]×6 + row[9]×7 + row[10]×9 + row[11]×12

noise_out = weighted_sum >>> 2  (divide by 4, normalize to Q14)
```

**Output Format:**
- 18-bit signed Q14
- Range: approximately ±0.5 to ±1.0
- Centered at zero

---

## Update Rate Hierarchy (at 4 kHz)

| Row | Period | Frequency Nyquist | Purpose |
|-----|--------|-------------------|---------|
| 0 | 0.5 ms | 1000 Hz | High-frequency texture |
| 7 | 64 ms | 7.8 Hz | Theta-band fluctuation |
| 11 | 1024 ms | 0.49 Hz | Very slow baseline drift |

**Cascading time-constants:** Each row 2× slower than previous

---

## Spectral Properties

**Power Spectrum:**
```
P(f) = C × f^(-1.618)  for 0.5 Hz < f < 500 Hz
Slope: approximately -16.2 dB/decade
```

**Comparison to Standard 1/f:**
| Type | Spectral Exponent | dB/decade |
|------|-------------------|-----------|
| Standard 1/f | β = 1.0 | -10 dB |
| Golden ratio 1/f^φ | β = 1.618 | -16.2 dB |

---

## Biological Realism

**Real EEG Spectral Slopes:**
| State | β Value | Match |
|-------|---------|-------|
| Resting awake | 1.0-1.2 | Standard 1/f |
| Sleep | 1.2-1.5 | Between 1/f and 1/f^φ |
| Deep meditation | 0.8-1.0 | Flatter than 1/f |
| Psychedelic | 1.0-1.4 | Variable |

**Why φ is biologically significant:**
- Dendritic branching follows Fibonacci patterns
- EEG frequency bands approximately related by φ^(n/4)
- Optimal information packing in spectral domains
- φ provides "smooth" power distribution without sharp transitions

---

## Integration in Output Mixer

**Spectral Composition:**
```
MODULATORY mode: 98% pink noise + 2% oscillators
HARMONIC mode:   85% pink noise + 15% oscillators

DAC = 0.005×theta + 0.01×alpha + 0.00625×beta +
      0.00375×gamma + 0.92×pink_noise
```

Pink noise provides the 1/f^φ background; oscillators add spectral peaks at consciousness-relevant frequencies.

---

## Hardware Efficiency

**Resource Usage:**
- 12 × 12-bit row registers = 144 bits
- 1 × 16-bit LFSR = 16 bits
- 1 × 12-bit counter = 12 bits
- **Total: 172 bits of state memory**

Fully synthesizable, minimal resource footprint.

---

## Version Comparison

| Feature | v6.0 | v7.2 |
|---------|------|------|
| Octave bands | 8 | 12 |
| Weighting | Equal | √Fibonacci |
| Spectral slope | 1/f | 1/f^φ (1/f^1.618) |
| High-freq response | Flat above 30 Hz | Proper roll-off |
| Biological realism | Moderate | Excellent |

---

# PART 7: CA3 PHASE MEMORY (Hippocampal Learning)

## Overview

The CA3 phase memory (v8.0) implements a **6×6 Hopfield network** with theta-gated learning and 8-phase temporal multiplexing. It stores phase relationships between cortical oscillators and generates phase coupling signals for memory-driven oscillator synchronization.

---

## Memory Architecture

**Storage Structure:**
- 6×6 symmetric weight matrix (Hopfield network)
- 8-bit signed weights per synapse [-128, +127]
- Total storage: 36 weights × 8 bits = 288 bits
- Diagonal: w[i][i] = 0 (no self-connections)

**Pattern Format:**
- 6-bit binary vector `pattern_in[5:0]`
- Maps to 3 columns × 2 layers (L2/3 + L6)

| Bit | Column | Layer |
|-----|--------|-------|
| 0 | Sensory | L2/3 |
| 1 | Sensory | L6 |
| 2 | Association | L2/3 |
| 3 | Association | L6 |
| 4 | Motor | L2/3 |
| 5 | Motor | L6 |

---

## 8-Phase Theta Encoding

**Phase Detection:**
- Input: 3-bit `theta_phase[2:0]` from thalamus
- Encoding window: phases 0-3 (theta peak, bit[2]=0)
- Retrieval window: phases 4-7 (theta trough, bit[2]=1)

| Phase | Window | Gamma Freq | Purpose |
|-------|--------|------------|---------|
| 0-1 | Encoding (early) | 67.6 Hz (fast) | Sensory-driven storage |
| 2-3 | Encoding (late) | 41.76 Hz (slow) | Consolidation |
| 4-5 | Retrieval (early) | 67.6 Hz (fast) | Pattern completion |
| 6-7 | Retrieval (late) | 41.76 Hz (slow) | Output/decay |

**Window Signals:**
```
encoding_window = ~theta_phase[2]  (phases 0-3)
retrieval_window = theta_phase[2]  (phases 4-7)
```

---

## Hebbian Learning

**Learning Rule:**
```
If units i and j BOTH active during theta peak:
  w[i][j] += LEARN_RATE (2)
  w[j][i] += LEARN_RATE (symmetric)
```

**Learning Parameters:**
| Parameter | Value | Purpose |
|-----------|-------|---------|
| LEARN_RATE | 2 | Weight increment per co-activation |
| WEIGHT_MAX | 100 | Saturation ceiling |
| THETA_LEARN_THRESHOLD | +0.75 | Theta peak detection |

**Learning State Machine:**
```
IDLE → LEARN (when theta_x > +0.75 AND pattern_in ≠ 0)
  └→ 36 cycles: update all co-active weight pairs
  └→ LEARN_DONE → IDLE (when theta_x < +0.5)
```

---

## Pattern Recall

**Hopfield Recall Algorithm:**
```
1. Initialize accumulators: accum[i] = 0
2. For each input column j:
     accum[i] += weights[i][j] × pattern_in[j]
3. Threshold to binary:
     phase_pattern[i] = (accum[i] > RECALL_THRESHOLD) ? 1 : 0
```

**Recall Parameters:**
| Parameter | Value | Purpose |
|-----------|-------|---------|
| RECALL_THRESHOLD | 10 | Accumulator threshold |
| THETA_RECALL_THRESHOLD | -0.75 | Theta trough detection |

**Recall State Machine:**
```
IDLE → RECALL (when theta_x < -0.75 AND pattern_in ≠ 0)
  └→ 6 cycles: accumulate weighted sum
  └→ RECALL_DONE: threshold to phase_pattern
  └→ IDLE (when theta_x > -0.5)
```

---

## Phase Coupling Generation

**Computation (in phi_n_neural_processor.v):**
```
theta_couple_base = (K_PHASE × theta_x) >>> 14
phase_couple[i] = phase_pattern[i] ? +theta_couple_base : -theta_couple_base
```

**K_PHASE = 0.25 (4096 Q14)**

**Effect:**
- phase_pattern[i] = 1 → oscillator driven toward theta phase (0°)
- phase_pattern[i] = 0 → oscillator driven toward anti-phase (180°)
- Magnitude: ±0.25 per theta cycle

**Routing:**
```
phase_couple_sensory_l23 ← phase_pattern[0]
phase_couple_sensory_l6  ← phase_pattern[1]
phase_couple_assoc_l23   ← phase_pattern[2]
phase_couple_assoc_l6    ← phase_pattern[3]
phase_couple_motor_l23   ← phase_pattern[4]
phase_couple_motor_l6    ← phase_pattern[5]
```

---

## Memory Decay (Forgetting)

**Decay Mechanism:**
- Weights decay when `pattern_in == 0` (no external input)
- Decay interval: 10 theta cycles (~1.7 seconds)
- Decay rate: 1 per event

**Decay Algorithm:**
```
Every 10 theta cycles with no input:
  for all i,j:
    if w[i][j] > 0:
      w[i][j] -= DECAY_RATE (1)
```

**Effect:**
- Reinforced patterns (w=100): ~170s to fully decay
- Weak patterns (w=20): ~34s to decay
- Creates recency bias and competitive learning

---

## State Indicators

| Signal | Active During | Purpose |
|--------|---------------|---------|
| learning | LEARN, LEARN_DONE | Marks weight update period |
| recalling | RECALL, RECALL_DONE | Marks pattern retrieval |
| encoding_window | Phases 0-3 | Gates fast gamma (67.6 Hz) |
| retrieval_window | Phases 4-7 | Gates slow gamma (41.76 Hz) |

---

## Complete Data Flow

```
cortical_pattern[5:0] (thresholded L2/3 + L6 activity)
    ↓
[CA3 Memory Core]
    ├─ LEARN: w[i][j] += 2 if pattern[i] AND pattern[j]
    ├─ RECALL: accum[i] = Σ w[i][j] × pattern[j]
    └─ DECAY: w[i][j] -= 1 every 10 theta cycles
    ↓
phase_pattern[5:0] (in-phase=1 / anti-phase=0)
    ↓
[Phase Coupling Computation]
    phase_couple[i] = ±(K_PHASE × theta_x)
    ↓
[Cortical Columns]
    Oscillators driven toward learned phase relationships
```

---

## Constants Summary

| Parameter | Value | Format | Purpose |
|-----------|-------|--------|---------|
| LEARN_RATE | 2 | 8-bit | Weight increment |
| WEIGHT_MAX | 100 | 8-bit | Saturation limit |
| RECALL_THRESHOLD | 10 | 16-bit | Pattern threshold |
| DECAY_RATE | 1 | 8-bit | Forgetting rate |
| DECAY_INTERVAL | 10 | cycles | Decay frequency |
| K_PHASE | 4096 | Q14 (0.25) | Coupling strength |
| N_UNITS | 6 | — | Oscillator count |

---

## Biological Basis

**Theta Phase Multiplexing (Dupret et al. 2025):**
- Encoding during theta peak (sensory input dominant)
- Retrieval during theta trough (recurrent CA3 dominant)
- Single CA3 population performs multiple computations

**Hopfield Network Properties:**
- Symmetric weights ensure convergence to attractors
- Hebbian learning stores co-activation patterns
- Partial cue triggers pattern completion
- Capacity: ~0.15n patterns (1-2 robust for n=6)
