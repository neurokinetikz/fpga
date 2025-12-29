# v10.0 Specification Update: EEG Realism Phase 1

**Version:** 10.0
**Date:** 2025-12-27
**Feature:** Foundation for biologically-realistic DAC output

---

## Summary

Version 10.0 introduces the first phase of EEG realism improvements, adding three critical mechanisms:

1. **Amplitude Envelope Generator** - Ornstein-Uhlenbeck process for "alpha breathing"
2. **SR Ignition Controller** - Six-phase SIE state machine with coherence-first signature
3. **Cortical Frequency Drift** - Slow frequency wandering (±0.5 Hz over minutes)
4. **Coherence-Gated SR** - SR only appears during ignition events (GAIN_BASELINE = 0)

**Goal:** Make DAC output spectrally similar to real EEG recordings rather than sharp synthetic peaks.

---

## New Modules

### 1. Amplitude Envelope Generator (`src/amplitude_envelope_generator.v`, v1.0)

**Purpose:** Generate slow amplitude modulation to create "alpha breathing" - the characteristic waxing and waning of oscillator power observed in real EEG.

**Algorithm:** Ornstein-Uhlenbeck stochastic process
```
x[n+1] = x[n] + alpha*(mu - x[n]) + sigma*noise
```

Where:
- `alpha = dt/tau` (mean-reversion rate)
- `mu = 1.0` (equilibrium)
- `sigma` = noise amplitude
- `noise` = pseudo-random from 16-bit LFSR

**Parameters:**

| Name | Q14 Value | Decimal | Purpose |
|------|-----------|---------|---------|
| ENVELOPE_MEAN | 16384 | 1.0 | Equilibrium (no modulation) |
| ENVELOPE_MIN | 8192 | 0.5 | Lower bound |
| ENVELOPE_MAX | 24576 | 1.5 | Upper bound |
| DEFAULT_TAU_INV | 1 | ~3s tau | Mean-reversion rate |

**Timescale:** 2-5 seconds (state-dependent tau)

**Usage:**
```verilog
mu_effective = (mu_dt * envelope) >>> FRAC;
```

**Biological Basis:**
- Real EEG alpha power shows 2-5 second amplitude fluctuations
- Known as "alpha breathing" in resting-state recordings
- State-dependent: slower in MEDITATION, faster in PSYCHEDELIC

---

### 2. SR Ignition Controller (`src/sr_ignition_controller.v`, v1.0)

**Purpose:** Implement the six-phase Schumann Ignition Event (SIE) state machine with biologically-realistic "coherence-first" signature.

**Key Design:** Phase-Locking Value (PLV) rises 3-4 seconds before amplitude increase, distinguishing external SR forcing from internal oscillation.

**Six Phases:**

| Phase | Name | Duration | Gain | Description |
|-------|------|----------|------|-------------|
| 0 | QUIET | Variable | 0 | Baseline, waiting for coherence |
| 1 | COHERENCE_RISE | ~3s | 0 | PLV building, no amplitude yet |
| 2 | AMPLITUDE_RISE | ~2s | 0→1 | Gain ramps up |
| 3 | PEAK | ~1s | 1.0 | Full coupling |
| 4 | AMPLITUDE_FALL | ~2s | 1→0 | Gain ramps down |
| 5 | COHERENCE_FALL | ~2s | 0 | PLV decays |

**Trigger Condition:**
```verilog
coherence >= SIE_COHERENCE_THRESH && beta_quiet
```

**Constants (Q14):**

| Name | Value | Decimal | Purpose |
|------|-------|---------|---------|
| SIE_COHERENCE_THRESH | 9830 | 0.60 | Trigger threshold |
| SIE_GAIN_BASELINE | 0 | 0.0 | No SR in quiet state |
| SIE_GAIN_PEAK | 16384 | 1.0 | Full coupling at peak |

**Coherence-Gated Design:**
- `GAIN_BASELINE = 0` means SR only appears during active ignition events
- Prevents false SR signatures in baseline recordings
- Requires coherence threshold to trigger any coupling

---

### 3. Cortical Frequency Drift (`src/cortical_frequency_drift.v`, v1.0)

**Purpose:** Add slow, bounded random walk to oscillator frequencies for spectral broadening.

**Algorithm:**
```verilog
drift[n+1] = drift[n] + random_step
if (drift > DRIFT_MAX) drift = DRIFT_MAX;
if (drift < -DRIFT_MAX) drift = -DRIFT_MAX;
omega_out = omega_base + drift;
```

**Parameters:**

| Name | Value | Decimal | Purpose |
|------|-------|---------|---------|
| DRIFT_MAX | 13 | ±0.5 Hz | Maximum drift range |
| STEP_SIZE | 1 | ~0.04 Hz | Per-update drift step |

**Update Rate:** Once per ~250 updates (~16 Hz), creating smooth minute-scale drift

**Biological Basis:**
- Real EEG peaks are 1-3 Hz wide, not sharp lines
- Frequency wandering occurs over seconds to minutes
- Creates realistic spectral "smearing"

---

## Architecture Changes

### Coherence-Gated SR Design

Previous versions had `GAIN_BASELINE > 0`, meaning SR always contributed to output. In v10.0:

**Before (v9.x):**
```
SR_contribution = GAIN_BASELINE + (coherence * GAIN_MULTIPLIER)
```

**After (v10.0):**
```
SR_contribution = SIE_controller_gain  // 0 unless actively igniting
```

This ensures:
1. Clean baseline spectrum without SR artifacts
2. Clear ignition events visible in spectrograms
3. "Coherence-first" signature preserved (PLV before amplitude)

---

## Module Instances

| Module | Count | Location |
|--------|-------|----------|
| amplitude_envelope_generator | 4 | Top-level (theta, alpha, beta, gamma bands) |
| amplitude_envelope_generator | 15 | cortical_column.v (5 layers × 3 columns) |
| sr_ignition_controller | 1 | thalamus.v |
| cortical_frequency_drift | 15 | cortical_column.v (5 layers × 3 columns) |

---

## Testbenches

| Testbench | Tests | Description |
|-----------|-------|-------------|
| tb_amplitude_envelope.v | 8 | O-U process, bounds, state-dependence |
| tb_sr_ignition_phases.v | 10 | Six-phase SIE evolution, coherence-first |

---

## Files Modified

| File | Changes |
|------|---------|
| src/amplitude_envelope_generator.v | NEW |
| src/sr_ignition_controller.v | NEW |
| src/cortical_frequency_drift.v | NEW |
| src/thalamus.v | Integrate SIE controller, gain envelope |
| src/cortical_column.v | Add envelope and drift per layer |
| src/config_controller.v | SIE timing parameters |

---

## Result

After v10.0, the DAC output exhibits:
- Slow amplitude modulation ("alpha breathing")
- Coherence-gated SR events (not continuous background)
- Frequency wandering for spectral broadening
- Foundation for v10.1 envelope integration and v10.2 fast jitter
