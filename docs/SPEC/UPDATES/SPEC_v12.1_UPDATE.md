# φⁿ Neural Processor FPGA - v12.1 Specification Update

## Synchronized State Transitions

**Date:** December 30, 2025
**Version:** v12.1

### Overview

v12.1 addresses transient artifacts during consciousness state transitions by synchronizing PAC/harmonic gain changes with MU amplitude interpolation. This eliminates the alpha dip at NORMAL→MEDITATION and spike at MEDITATION→NORMAL transitions.

### Problem: Three-Rate Mismatch

In v12.0, three processes operated at different timescales during state transitions:

| Process | Timescale | v12.0 Behavior | v12.1 Fix |
|---------|-----------|----------------|-----------|
| PAC gain effect | ~1 cycle | Instant switch | Interpolated |
| Harmonic lock | ~5-10 cycles | Instant switch | Interpolated |
| MU amplitude | 20 seconds | Interpolated | (unchanged) |

**Root cause**: PAC support disappeared before MU compensated (N→M), or PAC applied to high-amplitude oscillators (M→N).

---

## Module Changes

### 1. coupling_mode_controller.v v1.2b

**Synchronized Gain Interpolation**

New inputs for state transition tracking:
```verilog
input wire transitioning,           // From config_controller
input wire [2:0] state_transition_from,  // Source state
input wire [2:0] state_transition_to,    // Target state
```

Gain interpolation during MEDITATION transitions:
```verilog
// Linear interpolation: gain = start + (target - start) × progress / duration
// Uses 32-bit arithmetic to prevent overflow
if (harmonic_gain_target >= harmonic_gain_start) begin
    harmonic_gain <= harmonic_gain_start +
        ((({14'd0, harmonic_gain_target - harmonic_gain_start}) *
          {16'd0, transition_progress}) / {16'd0, transition_duration});
end
```

New constants:
- `GAIN_RAMP_STEP = 7` - Non-meditation gain step (~500ms transition)
- `TRANSITION_GATE_25PCT = 16384` - State-gated forcing threshold

**v1.2 Debounce Features** (already documented):
- Entry/exit conditions must hold for 500ms (DEBOUNCE_CYCLES=2000)
- Wider hysteresis: R entry 0.55, R exit 0.35 (20% window)
- Boundary entry 0.30, boundary exit 0.15 (15% window)

---

### 2. output_mixer.v v7.20

**Continuous Gain Blending**

New inputs from coupling_mode_controller:
```verilog
input wire signed [WIDTH-1:0] pac_gain,      // Q14: 0.125 to 1.0
input wire signed [WIDTH-1:0] harmonic_gain, // Q14: 0.125 to 1.0
input wire use_continuous_gains,             // Enable during MEDITATION transitions
```

Mode blend computation:
```verilog
// Normalize harmonic_gain to [0, 1] range
// GAIN_LOW=0.125 (2048), GAIN_RANGE=0.875 (14336)
wire signed [WIDTH-1:0] gain_shifted = harmonic_gain - GAIN_LOW;
wire signed [2*WIDTH-1:0] blend_full = (gain_shifted <<< FRAC) / GAIN_RANGE;
wire signed [WIDTH-1:0] mode_blend_clamped = /* clamped to [0, 1] */;
```

Weight interpolation:
- `pink_weight`: lerp(0.98, 0.85, mode_blend)
- `osc_scale`: lerp(0.25×, 0.35×, mode_blend)

**Debug outputs** for monitoring:
```verilog
output wire signed [WIDTH-1:0] debug_mode_blend,   // Normalized blend [0,1]
output wire signed [WIDTH-1:0] debug_pink_weight,  // Effective pink weight
output wire signed [WIDTH-1:0] debug_osc_scale     // Effective osc scale
```

---

### 3. phi_n_neural_processor.v v11.5.1

**Energy Landscape Integration**

New wiring for ratio-based catastrophe detection:
```verilog
// Pack OMEGA_DT values for energy_landscape
assign omega_dt_cortical_packed = {
    OMEGA_DT_GAMMA_FAST,  // L2/3: 40.36 Hz
    OMEGA_DT_GAMMA,       // L4:   31.73 Hz
    OMEGA_DT_BETA_HIGH,   // L5b:  24.94 Hz
    OMEGA_DT_BETA_LOW,    // L5a:  15.42 Hz
    OMEGA_DT_ALPHA        // L6:   9.53 Hz
};
```

Escape mechanism outputs:
```verilog
wire signed [NUM_CORTICAL_LAYERS*WIDTH-1:0] omega_correction_packed;

// Unpack and connect to cortical_frequency_drift
assign omega_corr_l6  = omega_correction_packed[0*WIDTH +: WIDTH];
assign omega_corr_l5a = omega_correction_packed[1*WIDTH +: WIDTH];
// ... etc
```

**use_continuous_gains logic**:
```verilog
wire use_continuous_gains = state_transitioning_int &&
    ((state_transition_to_int == STATE_MEDITATION) ||
     (state_transition_from_int == STATE_MEDITATION));
```

---

### 4. energy_landscape.v v11.2

**Ratio-Based Catastrophe Detection**

Replaces proximity-based detection with frequency ratio analysis:
- Monitors distance to 2:1, 3:2, 3:1, 4:3, 5:4 ratios
- Computes actual frequency ratios: `ratio = omega_dt[i] / omega_dt_reference`
- Proximity-based repulsion (force increases near ratio center)

New outputs:
```verilog
output wire signed [NUM_OSCILLATORS*WIDTH-1:0] omega_correction_packed,
output wire [NUM_OSCILLATORS-1:0] near_harmonic_3_2,
output wire [NUM_OSCILLATORS-1:0] near_harmonic_5_4
```

**Escape Mechanism**:
When in catastrophe zone, computes escape direction toward nearest φⁿ attractor:
- Near 2:1 → escape toward φ^1.25 (1.825) or φ^2.0 (2.618)
- omega_correction output pushes oscillator away from danger

---

### 5. cortical_frequency_drift.v v3.4

**Escape Mechanism Integration**

New inputs from energy_landscape:
```verilog
input wire signed [WIDTH-1:0] omega_corr_l6,
input wire signed [WIDTH-1:0] omega_corr_l5a,
input wire signed [WIDTH-1:0] omega_corr_l5b,
input wire signed [WIDTH-1:0] omega_corr_l4,
input wire signed [WIDTH-1:0] omega_corr_l23,
```

Drift update includes escape correction:
```verilog
next_drift = drift_reg + step + force_contrib + omega_corr;
```

---

## Bug Fixes

### Overflow in transition_progress (config_controller.v)

**Problem:** `ramp_counter × 65535` overflows 16-bit multiplication
```verilog
// BROKEN: 16-bit × 16-bit wraps around
transition_progress <= (ramp_counter * 16'hFFFF) / ramp_dur;
```

**Fix:** 32-bit arithmetic
```verilog
// FIXED: Zero-extend to 32-bit before multiplication
transition_progress <= ({16'd0, ramp_counter} * 32'd65535) / {16'd0, ramp_dur};
```

### Overflow in gain interpolation (coupling_mode_controller.v)

**Problem:** `delta × progress` overflows 18-bit multiplication (delta=14336, progress=65535 → ~940M)

**Fix:** 32-bit arithmetic
```verilog
// FIXED: Zero-extend operands
harmonic_gain <= harmonic_gain_start +
    ((({14'd0, delta}) * {16'd0, transition_progress}) / {16'd0, transition_duration});
```

### Gain target after M→N transition

**Problem:** After M→N transition ended, harmonic_gain ramped back to GAIN_FULL because target_mode was still MODE_HARMONIC from the metric-driven state machine.

**Fix:** Prioritize state_select over target_mode for gain targets:
```verilog
if (meditation_transition) begin
    // During transition: use direction-based targets
end else if (state_select == STATE_MEDITATION) begin
    // In MEDITATION: HARMONIC targets
end else begin
    // Not in MEDITATION: always MODULATORY targets
    pac_gain_target <= GAIN_FULL;
    harmonic_gain_target <= GAIN_WEAK;
end
```

---

## Verified Behavior

### N→M Transition (20s duration)

| Time | harmonic_gain | mode_blend | pink_weight | osc_scale |
|------|---------------|------------|-------------|-----------|
| t=20s | 3140 (0.19) | 1248 | 15893 (0.97) | 4220 (0.26×) |
| t=25s | 7515 (0.46) | 6248 | 15243 (0.93) | 4720 (0.29×) |
| t=30s | 11890 (0.73) | 11248 | 14593 (0.89) | 5220 (0.32×) |
| t=35s | 16265 (0.99) | 16248 | 13943 (0.85) | 5720 (0.35×) |
| t=40s | 16384 (1.0) | 16384 | 13926 (0.85) | 5733 (0.35×) |

### M→N Transition (20s duration)

| Time | harmonic_gain | mode_blend | pink_weight | osc_scale |
|------|---------------|------------|-------------|-----------|
| t=60s | 15292 (0.93) | 15136 | 14088 (0.86) | 5609 (0.34×) |
| t=65s | 10917 (0.67) | 10136 | 14738 (0.90) | 5109 (0.31×) |
| t=70s | 6542 (0.40) | 5136 | 15388 (0.94) | 4609 (0.28×) |
| t=75s | 2167 (0.13) | 136 | 16038 (0.98) | 4109 (0.25×) |
| t=80s | 2048 (0.125) | 0 | 16056 (0.98) | 4096 (0.25×) |

All transitions are smooth with no discontinuities.

---

## Testbench Updates

### tb_state_transition_spectrogram.v

Extended DAC output CSV to 12 columns for debug verification:

| Column | Description |
|--------|-------------|
| time_ms | Sample timestamp (ms) |
| phase | Current test phase (0-4) |
| state_select | Consciousness state code |
| dac_output | 12-bit DAC value |
| gain_envelope | SIE gain envelope |
| mode_blend | Normalized harmonic_gain [0,1] |
| pink_weight | Effective pink noise weight |
| osc_scale | Effective oscillator scaling |
| transitioning | State transition active flag |
| harmonic_gain | Raw harmonic_gain Q14 value |
| use_cont | use_continuous_gains flag |
| trans_progress | transition_progress [0,65535] |

---

## Resource Impact

| Addition | LUTs | FFs |
|----------|------|-----|
| Gain interpolation (v1.2b) | ~50 | ~40 |
| Continuous blend (v7.20) | ~30 | ~10 |
| Escape mechanism wiring | ~20 | 0 |
| Debug outputs | ~10 | 0 |
| **Total** | **~110** | **~50** |

<1% FPGA utilization impact.

---

## Summary

v12.1 completes the synchronized state transition architecture:

1. **v1.2b coupling_mode_controller**: Gains interpolate with MU during MEDITATION transitions
2. **v7.20 output_mixer**: Continuous weight blending eliminates spectral artifacts
3. **v11.5.1 phi_n_neural_processor**: Full energy landscape integration with escape mechanism
4. **Bug fixes**: 32-bit arithmetic prevents overflow in interpolation calculations

The result is artifact-free, monotonic power transitions between NORMAL and MEDITATION states.
