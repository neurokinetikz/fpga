# v10.1 Specification Update: Envelope Integration

**Version:** 10.1
**Date:** 2025-12-27
**Feature:** Per-band amplitude envelopes connected to output mixer

---

## Summary

Version 10.1 completes the envelope integration by connecting the amplitude envelope generators (introduced in v10.0) to the output mixer. Each frequency band now has independent amplitude modulation for realistic "alpha breathing" in the DAC output.

---

## Changes

### Output Mixer Envelope Integration

**Before (v10.0):**
```verilog
// Output mixer used fixed weights
dac_out = W_THETA * theta + W_ALPHA * alpha + W_BETA * beta + W_GAMMA * gamma + W_PINK * pink;
```

**After (v10.1):**
```verilog
// Output mixer modulates by envelope
theta_scaled = (theta * theta_envelope) >>> FRAC;
alpha_scaled = (alpha * alpha_envelope) >>> FRAC;
beta_scaled  = (beta * beta_envelope) >>> FRAC;
gamma_scaled = (gamma * gamma_envelope) >>> FRAC;

dac_out = W_THETA * theta_scaled + W_ALPHA * alpha_scaled +
          W_BETA * beta_scaled + W_GAMMA * gamma_scaled + W_PINK * pink;
```

### Top-Level Envelope Instances

Four envelope generators in `phi_n_neural_processor.v`:

| Instance | Band | Frequency | Tau (typical) |
|----------|------|-----------|---------------|
| env_theta | Theta | 5.89 Hz | 3-4 seconds |
| env_alpha | Alpha | 9.53 Hz | 2-3 seconds |
| env_beta | Beta | 15.42-24.94 Hz | 1-2 seconds |
| env_gamma | Gamma | 40.36 Hz | 0.5-1 second |

### Signal Flow

```
cortical_column outputs
        │
        ▼
┌───────────────────┐
│ envelope generator │◄── tau from config_controller
│  (O-U process)    │
└───────────────────┘
        │
        ▼ envelope (0.5-1.5)
        │
┌───────────────────┐
│   output mixer    │
│ (oscillator × env)│
└───────────────────┘
        │
        ▼
   DAC output
```

---

## Cortical Column Integration

Each cortical layer also has its own envelope for per-layer modulation:

| Column | Layer | Purpose |
|--------|-------|---------|
| sensory | L6, L5a, L5b, L4, L2/3 | Sensory processing amplitude |
| assoc | L6, L5a, L5b, L4, L2/3 | Association cortex amplitude |
| motor | L6, L5a, L5b, L4, L2/3 | Motor output amplitude |

**Total:** 15 per-layer envelope generators + 4 per-band envelope generators = **19 O-U processes**

---

## Output Mixer Changes (`src/output_mixer.v`)

### New Inputs

```verilog
input wire signed [WIDTH-1:0] theta_envelope,
input wire signed [WIDTH-1:0] alpha_envelope,
input wire signed [WIDTH-1:0] beta_envelope,
input wire signed [WIDTH-1:0] gamma_envelope
```

### Envelope Application

```verilog
// Apply envelope modulation before weighting
wire signed [2*WIDTH-1:0] theta_modulated = theta_in * theta_envelope;
wire signed [2*WIDTH-1:0] alpha_modulated = alpha_in * alpha_envelope;
wire signed [2*WIDTH-1:0] beta_modulated = beta_in * beta_envelope;
wire signed [2*WIDTH-1:0] gamma_modulated = gamma_in * gamma_envelope;

// Truncate back to WIDTH after multiplication
wire signed [WIDTH-1:0] theta_scaled = theta_modulated[2*WIDTH-2:FRAC];
wire signed [WIDTH-1:0] alpha_scaled = alpha_modulated[2*WIDTH-2:FRAC];
wire signed [WIDTH-1:0] beta_scaled = beta_modulated[2*WIDTH-2:FRAC];
wire signed [WIDTH-1:0] gamma_scaled = gamma_modulated[2*WIDTH-2:FRAC];
```

---

## Expected Behavior

### Spectrogram Appearance

With envelope integration:
- **Theta band:** 3-4 second power fluctuations
- **Alpha band:** 2-3 second "breathing" (most visible)
- **Beta band:** 1-2 second modulation
- **Gamma band:** 0.5-1 second rapid fluctuations

### PSD Changes

- Peak heights vary ±50% over time (envelope range 0.5-1.5)
- Creates more realistic "soft" peaks instead of sharp synthetic spikes
- Pink noise floor remains constant (not envelope-modulated)

---

## Files Modified

| File | Changes |
|------|---------|
| src/output_mixer.v | v7.3: Add envelope inputs, apply modulation |
| src/phi_n_neural_processor.v | Instantiate 4 band envelope generators |
| src/cortical_column.v | v10.0: Instantiate 5 per-layer envelope generators |

---

## Verification

Envelope integration is verified by:
1. `tb_amplitude_envelope.v` - Unit tests for O-U process
2. `tb_full_system_fast.v` - Integration tests with envelope modulation
3. Visual inspection of DAC spectrogram for amplitude fluctuations

---

## Result

After v10.1, the DAC output exhibits:
- Visible amplitude modulation in spectrograms ("breathing")
- Per-band independent timing (alpha slower than gamma)
- More natural-looking power fluctuations
- Foundation ready for v10.2 spectral broadening
