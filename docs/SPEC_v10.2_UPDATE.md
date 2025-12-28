# v10.2 Specification Update: EEG Realism

**Version:** 10.2
**Date:** 2025-12-27
**Feature:** Biologically-realistic DAC output with 1/f-dominated spectrum and natural temporal dynamics

---

## Summary

The v10.x series adds EEG realism to the DAC output through three major mechanisms:

| Version | Name | Key Feature |
|---------|------|-------------|
| v10.0 | EEG Realism Phase 1 | Amplitude envelopes + slow frequency drift + SIE controller |
| v10.1 | Envelope Integration | Per-band envelopes wired to output mixer |
| v10.2 | Spectral Broadening | Fast frequency jitter (±0.5 Hz) for ~1-2 Hz peak width |

**Result:** DAC output now exhibits:
- **1/f-dominated spectrum** (92% pink noise, 8% oscillators)
- **Subtle oscillator peaks** (~1-3 dB above 1/f floor)
- **Alpha breathing** (2-5 second amplitude waxing/waning)
- **Spectral broadening** (~1-2 Hz wide peaks instead of sharp lines)
- **Coherence-gated SR** (SR only appears during ignition events)

---

## New Modules (3 files)

### 1. Amplitude Envelope Generator (`src/amplitude_envelope_generator.v`, v1.0)

**Purpose:** Ornstein-Uhlenbeck stochastic process for slow amplitude modulation ("alpha breathing")

**Algorithm:**
```
x[n+1] = x[n] + alpha*(mu - x[n]) + sigma*noise
```

Where:
- `alpha = dt/tau` (mean-reversion rate, state-dependent)
- `mu = 1.0` (equilibrium = no modulation)
- `sigma` = noise amplitude
- `noise` = pseudo-random from 16-bit LFSR

**Output Range:**
- Q14 format: 8192 to 24576 (0.5 to 1.5)
- Mean: 16384 (1.0 = no change)
- Timescale: 2-5 seconds (state-dependent tau)

**Usage:**
```verilog
mu_effective = (mu_dt * envelope) >>> FRAC;
```

**Instances in System:**
- 4× in top-level for output mixer bands (theta, alpha, beta, gamma)
- 15× in cortical columns (5 layers × 3 columns) for per-layer modulation

**Constants (Q14):**

| Name | Value | Decimal | Purpose |
|------|-------|---------|---------|
| ENVELOPE_MEAN | 16384 | 1.0 | Equilibrium (no modulation) |
| ENVELOPE_MIN | 8192 | 0.5 | Lower bound |
| ENVELOPE_MAX | 24576 | 1.5 | Upper bound |
| NOISE_AMPLITUDE | 100-150 | ~0.01 | O-U noise amplitude |
| DEFAULT_TAU_INV | 1 | ~3s tau | Mean-reversion rate |

**Biological Basis:**
- Real EEG alpha power waxes and wanes over 2-5 second timescales
- Observed in resting-state recordings as "alpha breathing"
- State-dependent: slower in MEDITATION, faster in PSYCHEDELIC

---

### 2. SR Ignition Controller (`src/sr_ignition_controller.v`, v1.1)

**Purpose:** Six-phase Schumann Ignition Event (SIE) state machine

**Key Feature:** "Coherence-first" signature - PLV rises 3-4 seconds before amplitude, distinguishing external SR forcing from internal oscillation.

**v1.1 Change:** `GAIN_BASELINE = 0` for coherence-gated behavior (no tonic SR presence)

**Six-Phase Evolution:**

| Phase | Name | Duration | Gain | PLV | Description |
|-------|------|----------|------|-----|-------------|
| 0 | BASELINE | — | 0.0 | 0.45 | Wait for trigger |
| 1 | COHERENCE | ~3.5s | 0.20 | → 0.80 | PLV rises BEFORE amplitude |
| 2 | IGNITION | ~2.5s | → 1.0 | 0.80 | Amplitude surge |
| 3 | PLATEAU | ~2.5s | 1.0 | 0.80 | Peak sustained |
| 4 | PROPAGATION | ~9s | → 0.60 | → 0.55 | PAC peak, gradual decay |
| 5 | DECAY | ~4s | → 0.0 | → 0.45 | Exponential relaxation |
| 6 | REFRACTORY | ~10s | 0.0 | 0.45 | No re-ignition |

**State Diagram:**
```
BASELINE ──(coherence > 0.6 && beta_quiet)──▶ COHERENCE
    ▲                                              │
    │                                         phase2_dur
    │                                              ▼
REFRACTORY ◀─── DECAY ◀─── PROPAGATION ◀─── PLATEAU ◀─── IGNITION
```

**Trigger Conditions:**
- `coherence_in > COHERENCE_THRESH` (0.60)
- `beta_quiet` asserted

**Constants (Q14):**

| Name | Value | Decimal | Purpose |
|------|-------|---------|---------|
| COHERENCE_THRESH | 9830 | 0.60 | Trigger threshold |
| PLV_BASELINE | 7373 | 0.45 | Baseline PLV |
| PLV_PEAK | 13107 | 0.80 | Peak PLV |
| GAIN_BASELINE | 0 | 0.0 | No tonic SR (v1.1) |
| GAIN_COHERENCE | 3277 | 0.20 | Coherence phase gain |
| GAIN_PEAK | 16384 | 1.0 | Peak gain |
| GAIN_PROPAGATION | 9830 | 0.60 | Sustained gain |

**Biological Basis:**
- Empirical observations show PLV rises before amplitude during SR events
- Hysteresis loop in Kuramoto R vs SR Power plots
- Matches "Continuous Golden Ratio Architecture" paper findings

---

### 3. Cortical Frequency Drift (`src/cortical_frequency_drift.v`, v2.1)

**Purpose:** Dual-component frequency modulation for spectral broadening

**Two Components:**

1. **Slow Drift:** Bounded random walk (±0.5 Hz over seconds)
   - Updates every 0.2s (800 cycles at 4 kHz in FAST_SIM)
   - Models slow frequency drift seen in EEG
   - Per-layer 16-bit LFSR for stochastic direction

2. **Fast Jitter:** Cycle-by-cycle frequency noise (±0.5 Hz per sample)
   - Updates every clk_en cycle (4 kHz)
   - Creates spectral broadening around oscillator peaks
   - 5-bit triangular distribution for quasi-Gaussian shape

**v2.1 Changes:**
- Increased jitter from ±0.15 Hz to ±0.5 Hz
- Uses 5 LFSR bits instead of 3 for wider distribution
- Creates ~1-2 Hz wide peaks (more EEG-realistic)

**Jitter Computation (v2.1):**
```verilog
// 5-bit triangular distribution: range [-15, +14], clamped to ±13
jitter = (bit4 ? +8 : -8) + (bit3 ? +4 : -4) + (bit2 ? +2 : -2) +
         (bit1 ? +1 : -1) + (bit0 ? +1 : 0)
```

**Layer Frequencies:**

| Layer | Frequency | φⁿ | OMEGA_DT | Drift Range |
|-------|-----------|-----|----------|-------------|
| L6 | 9.53 Hz | φ⁰·⁵ | 245 | ±0.5 Hz |
| L5a | 15.42 Hz | φ¹·⁵ | 397 | ±0.5 Hz |
| L5b | 24.94 Hz | φ²·⁵ | 642 | ±0.5 Hz |
| L4 | 31.73 Hz | φ³ | 817 | ±0.5 Hz |
| L2/3 | 40.36/65.3 Hz | φ³·⁵/φ⁴·⁵ | 1040/1681 | ±0.5 Hz |

**Constants (Q14/OMEGA_DT units):**

| Name | Value | Decimal | Purpose |
|------|-------|---------|---------|
| DRIFT_MAX | 13 | ±0.5 Hz | Slow drift range |
| JITTER_MAX | 13 | ±0.5 Hz | Fast jitter range (v2.1) |
| UPDATE_PERIOD | 800 | 0.2s | Slow drift update interval |

**LFSR Seeds:**

| Layer | Slow Drift | Fast Jitter |
|-------|------------|-------------|
| L6 | 0x7A3D | 0xB2C4 |
| L5a | 0xE5B2 | 0x4F8E |
| L5b | 0x29C8 | 0xD1A7 |
| L4 | 0xD4F1 | 0x6E39 |
| L2/3 | 0x8167 | 0x95CB |

**Effect:**
- Sharp spectral lines → broad EEG-like peaks (~1-2 Hz width)
- Combined drift + jitter creates natural frequency variability
- Independent per-layer variation prevents artificial coherence

---

## Updated Modules (4 files)

### 1. Top-Level Processor (`src/phi_n_neural_processor.v`, v9.6 → v10.2)

**Changes:**

1. **Cortical Frequency Drift Instantiation:**
```verilog
cortical_frequency_drift #(.FAST_SIM(FAST_SIM)) freq_drift (
    .drift_l6(drift_l6), .drift_l5a(drift_l5a), ...
    .jitter_l6(jitter_l6), .jitter_l5a(jitter_l5a), ...
);
```

2. **Combined Omega Offset:**
```verilog
// drift + jitter combined for each layer
wire signed [WIDTH-1:0] omega_offset_l6 = drift_l6 + jitter_l6;
```

3. **Amplitude Envelope Generators for Output Mixer:**
```verilog
amplitude_envelope_generator env_theta (.envelope(env_theta), ...);
amplitude_envelope_generator env_alpha (.envelope(env_alpha), ...);
amplitude_envelope_generator env_beta  (.envelope(env_beta),  ...);
amplitude_envelope_generator env_gamma (.envelope(env_gamma), ...);
```

4. **SR Ignition Controller Instantiation:**
```verilog
sr_ignition_controller sie_ctrl (
    .coherence_in(sr_coherence),
    .beta_quiet(beta_quiet),
    .gain_envelope(sie_gain_envelope),
    .plv_envelope(sie_plv_envelope),
    ...
);
```

5. **Envelope Wiring to Output Mixer (v10.1):**
```verilog
output_mixer mixer (
    .env_theta(env_theta),
    .env_alpha(env_alpha),
    .env_beta(env_beta),
    .env_gamma(env_gamma),
    ...
);
```

---

### 2. Cortical Column (`src/cortical_column.v`, v9.6 → v10.0)

**Changes:**

1. **New Omega Drift Input Ports:**
```verilog
input wire signed [WIDTH-1:0] omega_drift_l6,
input wire signed [WIDTH-1:0] omega_drift_l5a,
input wire signed [WIDTH-1:0] omega_drift_l5b,
input wire signed [WIDTH-1:0] omega_drift_l4,
input wire signed [WIDTH-1:0] omega_drift_l23
```

2. **Effective Omega Computation:**
```verilog
wire signed [WIDTH-1:0] omega_eff_l6  = OMEGA_DT_L6  + omega_drift_l6;
wire signed [WIDTH-1:0] omega_eff_l5a = OMEGA_DT_L5A + omega_drift_l5a;
// ... etc for all layers
```

3. **Per-Layer Amplitude Envelope Generators:**
```verilog
amplitude_envelope_generator #(.FAST_SIM(FAST_SIM)) env_l6 (
    .seed(16'hA000 + COLUMN_ID * 5),
    .envelope(env_l6_out),
    ...
);
// 5 instances total per column
```

4. **COLUMN_ID Parameter:**
```verilog
parameter [1:0] COLUMN_ID = 2'd0  // 0=sensory, 1=assoc, 2=motor
```
Used for unique LFSR seeds across columns.

---

### 3. Output Mixer (`src/output_mixer.v`, v5.5 → v7.3)

**Changes:**

**v7.0:** Added envelope inputs and per-band modulation:
```verilog
input wire signed [WIDTH-1:0] env_theta,
input wire signed [WIDTH-1:0] env_alpha,
input wire signed [WIDTH-1:0] env_beta,
input wire signed [WIDTH-1:0] env_gamma
```

**Envelope Modulation:**
```verilog
// Signal × envelope, normalized back to Q14
mod_theta = (theta_x * env_theta_eff) >>> FRAC;
```

**Weight Evolution:**

| Version | Oscillators | Pink Noise | Notes |
|---------|-------------|------------|-------|
| v5.5 | ~65% | ~35% | Original |
| v7.1 | ~33% | ~67% | First reduction |
| v7.2 | ~16.5% | ~83.5% | Second reduction |
| v7.3 | ~8% | ~92% | Final (EEG-realistic) |

**Current Weights (v7.3):**

| Band | Q14 Value | Decimal | Notes |
|------|-----------|---------|-------|
| W_THETA | 328 | 0.02 | Theta (thalamic) |
| W_ALPHA | 492 | 0.03 | Alpha (L6) - strongest peak |
| W_BETA | 328 | 0.02 | Low beta (L5a) |
| W_GAMMA | 164 | 0.01 | Gamma (L2/3) |
| W_PINK_NOISE | 15073 | 0.92 | 1/f background dominates |

**Rationale:**
- Real EEG shows 1/f-dominated spectrum with subtle oscillator bumps
- Peaks should be ~1-3 dB above 1/f floor, not 10-20 dB
- Alpha typically strongest, gamma weakest in scalp EEG

---

### 4. Config Controller (`src/config_controller.v`, v9.5 → v10.0)

**Changes:**

Added SIE phase timing outputs for state-dependent ignition dynamics:

```verilog
output wire [15:0] sie_phase2_dur,   // Coherence phase
output wire [15:0] sie_phase3_dur,   // Ignition phase
output wire [15:0] sie_phase4_dur,   // Plateau phase
output wire [15:0] sie_phase5_dur,   // Propagation phase
output wire [15:0] sie_phase6_dur,   // Decay phase
output wire [15:0] sie_refractory    // Refractory period
```

**State-Dependent Timing (at 4 kHz):**

| State | Coherence | Ignition | Plateau | Propagation | Decay | Refractory |
|-------|-----------|----------|---------|-------------|-------|------------|
| NORMAL | 14000 | 10000 | 10000 | 36000 | 16000 | 40000 |
| MEDITATION | 20000 | 14000 | 14000 | 48000 | 20000 | 60000 |
| PSYCHEDELIC | 8000 | 6000 | 6000 | 24000 | 10000 | 20000 |
| FLOW | 10000 | 8000 | 8000 | 30000 | 12000 | 30000 |
| ANESTHESIA | 20000 | 16000 | 16000 | 50000 | 24000 | 80000 |

---

## Signal Flow Diagram

```
                    ┌─────────────────────────────────────────┐
                    │     CORTICAL FREQUENCY DRIFT (v2.1)     │
                    │                                         │
                    │  SLOW DRIFT (0.2s updates, ±0.5 Hz)    │
                    │  + FAST JITTER (per-sample, ±0.5 Hz)   │
                    │                                         │
                    │  drift_l6 + jitter_l6 = omega_offset_l6 │
                    │  ...for all 5 layers...                 │
                    └────────────────────┬────────────────────┘
                                         │ omega_offset per layer
                                         ▼
┌────────────────────────────────────────────────────────────────────────┐
│                          CORTICAL COLUMNS ×3                           │
│                                                                        │
│  omega_eff = OMEGA_DT_BASE + omega_offset                             │
│  → Applied to all layer oscillators                                    │
│  → Creates ~1-2 Hz wide spectral peaks                                │
│                                                                        │
│  l6_x, l5a_x, l5b_x, l4_x, l23_x → oscillator outputs                 │
└────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
┌────────────────────────────────────────────────────────────────────────┐
│                    AMPLITUDE ENVELOPE GENERATORS                        │
│                                                                        │
│  4× for output mixer bands:                                            │
│    env_theta, env_alpha, env_beta, env_gamma                          │
│                                                                        │
│  O-U process: envelope ∈ [0.5, 1.5], mean 1.0, tau 2-5s               │
│  Creates slow "alpha breathing" amplitude modulation                   │
└────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        OUTPUT MIXER (v7.3)                              │
│                                                                        │
│  Per-band envelope modulation:                                         │
│    mod_theta = theta_x × env_theta                                    │
│    mod_alpha = motor_l6_x × env_alpha                                 │
│    mod_beta  = motor_l5a_x × env_beta                                 │
│    mod_gamma = motor_l23_x × env_gamma                                │
│                                                                        │
│  Weighted mixing (v7.3 weights):                                       │
│    mixed = 0.02×theta + 0.03×alpha + 0.02×beta + 0.01×gamma           │
│          + 0.92×pink_noise                                             │
│                                                                        │
│  Result: 1/f-dominated spectrum with subtle oscillator bumps           │
└────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
                                    12-bit DAC
```

---

## Testing

### New Testbenches

| Testbench | Tests | Purpose |
|-----------|-------|---------|
| `tb/tb_amplitude_envelope.v` | ~8 | O-U process bounds, mean-reversion |
| `tb/tb_sr_ignition_phases.v` | ~10 | 6-phase evolution, coherence-first |

### Updated Test Coverage

All existing testbenches pass (226+ tests total):
- `tb_full_system_fast`: 15/15 tests
- `tb_l6_extended`: 10/10 tests
- `tb_learning_fast`: 8/8 tests
- All other testbenches: PASS

---

## Analysis Scripts

### `scripts/dac_spectrogram.py`

Simulates DAC output mixing with matched v7.3 weights:

```python
# Weights matching output_mixer.v v7.3
W_THETA      = 328 / 16384    # 0.02
W_ALPHA      = 492 / 16384    # 0.03
W_BETA       = 328 / 16384    # 0.02
W_GAMMA      = 164 / 16384    # 0.01
W_PINK_NOISE = 15073 / 16384  # 0.92
```

**Usage:**
```bash
python3 scripts/dac_spectrogram.py
```

**Output:** `eeg_analysis/dac_spectrogram.png`

### `scripts/analyze_eeg_comparison.py`

Comprehensive EEG analysis:
- Power spectral density (PSD)
- Phase-amplitude coupling (PAC)
- Cross-frequency coherence

---

## Resource Impact

| Component | Additional DSP48s | Additional Registers |
|-----------|-------------------|----------------------|
| amplitude_envelope_generator ×19 | 0 | ~38 (2/instance) |
| sr_ignition_controller | 0 | ~8 |
| cortical_frequency_drift | 0 | ~50 (LFSRs + state) |
| **Total Added** | 0 | ~96 |

No additional DSP usage - all new logic is control/filter based.

---

## Backward Compatibility

The system maintains backward compatibility:
- Default envelope = 1.0 (no modulation if envelope generator disabled)
- Default drift/jitter = 0 (original frequencies if drift generator disabled)
- SR ignition controller gated by coherence (no effect if coherence low)
- All existing tests pass without modification

---

## References

- Buzsáki, G. (2006) "Rhythms of the Brain" - 1/f spectrum characteristics
- Klimesch, W. (2012) "Alpha-band oscillations, attention, and controlled access to stored information" - Alpha breathing
- Schumann Resonance literature - Coherence-first signature in SIE events

---

## Changelog

### v10.2 (2025-12-27)
- ENHANCED: cortical_frequency_drift.v jitter increased to ±0.5 Hz (was ±0.15 Hz)
- ENHANCED: 5-bit triangular distribution for jitter (was 3-bit)
- RESULT: ~1-2 Hz wide spectral peaks (EEG-realistic)

### v10.1 (2025-12-27)
- WIRED: Amplitude envelopes connected to output_mixer
- RESULT: Per-band envelope modulation active

### v10.0 (2025-12-27)
- NEW: `amplitude_envelope_generator.v` - O-U process for alpha breathing
- NEW: `sr_ignition_controller.v` - 6-phase SIE state machine
- NEW: `cortical_frequency_drift.v` - Slow drift + fast jitter
- MODIFIED: `phi_n_neural_processor.v` - Integrated all new modules
- MODIFIED: `cortical_column.v` - Added omega_drift ports
- MODIFIED: `output_mixer.v` - Added envelope ports, reduced weights to 8%
- MODIFIED: `config_controller.v` - Added SIE timing outputs
