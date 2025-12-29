# φⁿ Neural Processor - v9.1 Specification Update

## SST+ Slow Dynamics (Phase 2 - Martinotti Cell Model)

**Date:** 2025-12-27
**Version:** 9.1
**Status:** Implemented and Tested

---

## Overview

v9.1 adds **SST+ (somatostatin-positive) Martinotti cell slow dynamics** to Layer 1. This is Phase 2 of the incremental interneuron implementation plan.

The key change: Layer 1 apical gain now tracks a **filtered** version of the combined input, modeling the slow GABA-B receptor kinetics characteristic of SST+ interneurons.

## Biological Basis

SST+ Martinotti cells are GABAergic interneurons that:
- Target the distal apical dendrites of pyramidal cells (dendritic inhibition)
- Have slow GABA-B receptor kinetics (~25-100ms time constants)
- Create slow, divisive inhibition (gain modulation)
- Reside primarily in Layer 1 and upper layers
- Receive input from higher cortical areas (feedback)

### SST+ vs PV+ Interneurons

| Property | PV+ (v9.0) | SST+ (v9.1) |
|----------|-----------|-------------|
| Target | Soma/proximal dendrite | Distal apical dendrite |
| Kinetics | Fast (GABA-A, ~5ms) | Slow (GABA-B, ~25ms) |
| Inhibition type | Subtractive | Divisive (gain) |
| Function | Perisomatic inhibition | Dendritic inhibition |
| Location | Same layer as pyramids | Layer 1 |

## Implementation

### Model

Previous v8.7 L1 model (instantaneous):
```
gain_offset = 0.15*matrix + 0.3*fb1 + 0.2*fb2
apical_gain = clamp(1.0 + gain_offset, 0.5, 1.5)
```

New v9.1 SST+ model (filtered):
```
gain_offset = 0.15*matrix + 0.3*fb1 + 0.2*fb2
sst_activity = lowpass(gain_offset, tau=25ms)   // NEW: slow dynamics
apical_gain = clamp(1.0 + sst_activity, 0.5, 1.5)
```

### IIR Lowpass Filter

The SST+ slow dynamics use a first-order IIR lowpass filter:

```
sst_activity[n] = sst_activity[n-1] + alpha × (gain_offset - sst_activity[n-1])
```

Where:
- `alpha = dt/tau = 0.25ms / 25ms = 0.01` (164 in Q14)
- Time constant τ ≈ 25ms (matches GABA-B kinetics)
- At 4 kHz update rate, dt = 0.25ms

### Signal Flow

```
Matrix Thalamic Input ──┐
                        │    ┌───────────────────────┐
FB1 (adjacent column) ──┼───▶│ Weighted Sum          │
                        │    │ 0.15M + 0.3F1 + 0.2F2 │
FB2 (distant column) ───┘    └───────────┬───────────┘
                                         │
                                         ▼ gain_offset
                              ┌─────────────────────┐
                              │  SST+ Slow Dynamics │
                              │  IIR Lowpass Filter │
                              │  tau ≈ 25ms         │
                              └──────────┬──────────┘
                                         │
                                         ▼ sst_activity (filtered)
                              ┌─────────────────────┐
                              │  1.0 + sst_activity │
                              │  clamp [0.5, 1.5]   │
                              └──────────┬──────────┘
                                         │
                                         ▼ apical_gain
                        ┌────────────────────────────────┐
                        │ To L2/3 and L5 apical dendrites│
                        └────────────────────────────────┘
```

### Code Changes

**File:** `src/layer1_minimal.v`

```verilog
//=============================================================================
// v9.1: SST+ Slow Dynamics Constants
//=============================================================================
// SST+ (Martinotti) cells have slow GABA-B kinetics
// Time constant ~25ms at 4 kHz update rate
// IIR filter: y[n] = y[n-1] + alpha * (x[n] - y[n-1])
// For tau = 25ms at dt = 0.25ms: alpha = dt/tau = 0.25/25 = 0.01
localparam signed [WIDTH-1:0] SST_ALPHA = 18'sd164;  // 0.01 - IIR filter coefficient

// SST+ state variable
reg signed [WIDTH-1:0] sst_activity;

// Intermediate signals for filter computation
wire signed [WIDTH-1:0] sst_error;
wire signed [2*WIDTH-1:0] sst_delta_full;
wire signed [WIDTH-1:0] sst_delta;

assign sst_error = gain_offset - sst_activity;
assign sst_delta_full = sst_error * SST_ALPHA;
assign sst_delta = sst_delta_full >>> FRAC;

always @(posedge clk) begin
    if (rst) begin
        sst_activity <= 0;
    end else if (clk_en) begin
        // IIR lowpass: sst_activity += alpha * (gain_offset - sst_activity)
        sst_activity <= sst_activity + sst_delta;
    end
end

// Compute raw gain using FILTERED SST+ activity (not instantaneous)
wire signed [WIDTH-1:0] gain_raw;
assign gain_raw = GAIN_BASE + sst_activity;
```

## Effects

### Slow Rise Dynamics

When feedback suddenly increases:
- Old behavior: Gain instantly jumps to new value
- New behavior: Gain rises exponentially with τ ≈ 25ms
- Reaches 63% of final value after 25ms
- Reaches 95% after ~75ms (3τ)

### Slow Decay Dynamics

When feedback suddenly decreases:
- Old behavior: Gain instantly drops
- New behavior: Gain decays exponentially with τ ≈ 25ms
- Provides "memory" of recent high activity

### Biological Realism

The slow dynamics match observed SST+ cell behavior:
- GABA-B receptors have slow activation (~25-50ms)
- GABA-B receptors have slow deactivation (~100-200ms)
- Creates smoothed, temporally integrated feedback signal

### Preserved Features

- Gain range unchanged: [0.5, 1.5]
- Input weighting unchanged: 0.15/0.3/0.2
- Final steady-state behavior unchanged
- All other layer dynamics unchanged

## Testing

**Testbench:** `tb/tb_sst_dynamics.v`

**Tests (8/8 passing):**

| Test | Description | Criterion |
|------|-------------|-----------|
| 1 | Reset to zero | sst_activity = 0 after reset |
| 2 | Slow rise | sst_activity < gain_offset after 50 clk_en |
| 3 | Approach target | sst_activity approaches gain_offset |
| 4 | Time constant | 63% reached in ~100 cycles (25ms) |
| 5 | Slow decay | sst_activity decreases toward new target |
| 6 | Minimum clamp | apical_gain >= 0.5 (8192) |
| 7 | Maximum clamp | apical_gain <= 1.5 (24576) |
| 8 | Filter smoothing | Filtered value smoother than input |

### Verification Commands

```bash
# Run SST+ dynamics test
iverilog -o tb_sst_dynamics.vvp -DFAST_SIM \
    src/hopf_oscillator.v src/cortical_column.v src/layer1_minimal.v \
    tb/tb_sst_dynamics.v && vvp tb_sst_dynamics.vvp

# Run full system test (confirms no regression)
iverilog -o tb_full_system_fast.vvp -DFAST_SIM \
    src/clock_enable_generator.v src/hopf_oscillator.v src/hopf_oscillator_stochastic.v \
    src/ca3_phase_memory.v src/thalamus.v src/cortical_column.v src/config_controller.v \
    src/pink_noise_generator.v src/output_mixer.v src/phi_n_neural_processor.v \
    src/sr_harmonic_bank.v src/sr_noise_generator.v src/sr_frequency_drift.v \
    src/layer1_minimal.v tb/tb_full_system_fast.v && vvp tb_full_system_fast.vvp
```

## Phase Progress

| Phase | Version | Addition | Status |
|-------|---------|----------|--------|
| 1 | v9.0 | PV+ Minimal (amplitude feedback) | ✅ Complete |
| **2** | **v9.1** | **SST+ Explicit (slow dynamics)** | **✅ Complete** |
| 3 | v9.2 | PV+ Feedback Loop (PING network) | Planned |
| 4 | v9.3 | Cross-Layer PV+ (L4, L5 populations) | Planned |
| 5 | v9.4 | VIP+ Disinhibition (attention gating) | Planned |

## Constants

| Name | Q14 Value | Decimal | Description |
|------|-----------|---------|-------------|
| SST_ALPHA | 164 | 0.01 | IIR filter coefficient (tau = 25ms) |
| K_PV | 4915 | 0.3 | PV+ inhibition weight (v9.0) |

## Files Modified

| File | Changes |
|------|---------|
| `src/layer1_minimal.v` | Added SST_ALPHA, sst_activity, IIR filter logic |
| `tb/tb_sst_dynamics.v` | New testbench (8 tests) |
| `CLAUDE.md` | Version update, SST_ALPHA constant, tb_sst_dynamics |
| `docs/SPEC_v9.1_UPDATE.md` | This file |

## Compatibility

- Backward compatible with all v9.0 and v8.x features
- All existing tests pass (182+ total)
- No interface changes to layer1_minimal.v or phi_n_neural_processor.v
- Steady-state behavior unchanged (only transient dynamics differ)
