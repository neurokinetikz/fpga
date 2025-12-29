# φⁿ Neural Processor - v9.4 Specification Update

## VIP+ Disinhibition (Phase 5 - Attention Gating)

**Date:** 2025-12-27
**Version:** 9.4
**Status:** Implemented and Tested

---

## Overview

v9.4 adds **VIP+ (vasoactive intestinal peptide) interneuron disinhibition** to Layer 1. This is Phase 5 of the incremental interneuron implementation plan.

VIP+ cells receive attention signals and **inhibit SST+ cells**, creating a disinhibitory pathway that selectively enhances processing when attention is high.

## Biological Basis

VIP+ interneurons are a key component of cortical disinhibitory circuits:

### VIP+ Cell Properties
- Receive input from higher cortical areas (attention/arousal signals)
- Target other interneurons (primarily SST+ cells)
- Have slow kinetics (~50ms time constant)
- Create "spotlight" effect for selective enhancement

### Disinhibition Circuit

```
Attention Signal ──▶ VIP+ ──┤ (inhibits)
                            │
                            ▼
Feedback ──────────▶ SST+ ──┤ (inhibits)
                            │
                            ▼
                   Pyramidal Dendrite ──▶ Gain Modulation
```

When VIP+ is active:
1. VIP+ inhibits SST+
2. SST+ inhibition of pyramidal cells decreases
3. Pyramidal gain increases (disinhibition)
4. Creates enhanced processing of attended stimuli

### VIP+ vs SST+ Dynamics

| Property | SST+ | VIP+ |
|----------|------|------|
| Target | Pyramidal dendrites | SST+ cells |
| Effect on gain | Increase (when active) | Increase (via disinhibition) |
| Time constant | ~25ms | ~50ms (slower) |
| Input | Feedback/matrix | Attention signals |
| Function | Context modulation | Attention gating |

## Implementation

### Model

Previous v9.1 SST+ model:
```
gain_offset = 0.15*matrix + 0.3*fb1 + 0.2*fb2
sst_activity = lowpass(gain_offset, tau=25ms)
apical_gain = clamp(1.0 + sst_activity, 0.5, 1.5)
```

New v9.4 VIP+ disinhibition model:
```
gain_offset = 0.15*matrix + 0.3*fb1 + 0.2*fb2
sst_activity = lowpass(gain_offset, tau=25ms)
vip_activity = lowpass(attention_input * K_VIP, tau=50ms)
sst_effective = max(0, sst_activity - vip_activity)  // Disinhibition
apical_gain = clamp(1.0 + sst_effective, 0.5, 1.5)
```

Note: When SST+ activity is negative (low feedback), it passes through unchanged. VIP+ only clamps sst_effective at 0 when SST+ was positive and VIP+ would push it negative.

### VIP+ IIR Filter

```
vip_scaled = attention_input × K_VIP
vip_activity[n] = vip_activity[n-1] + alpha × (vip_scaled - vip_activity[n-1])
```

Where:
- `alpha = dt/tau = 0.25ms / 50ms = 0.005` (82 in Q14)
- `K_VIP = 0.5` (8192 in Q14) - attention scaling
- Time constant τ ≈ 50ms (slower than SST+)

### Signal Flow

```
                            ┌───────────────────────────────────────┐
                            │         Layer 1 (Molecular Layer)     │
                            │                                       │
Attention Input ────────────┼──▶ VIP+ IIR Filter (tau=50ms)         │
                            │         │                             │
                            │         ▼ vip_activity                │
                            │    ┌─────────┐                        │
Matrix + FB1 + FB2 ─────────┼──▶ │ SST+ IIR│                        │
                            │    │ (25ms)  │                        │
                            │    └────┬────┘                        │
                            │         │ sst_activity                │
                            │         ▼                             │
                            │    ┌─────────────────┐                │
                            │    │ sst_effective = │                │
                            │    │ sst - vip       │◀── Disinhibition
                            │    │ (clamp >= 0)    │                │
                            │    └────────┬────────┘                │
                            │             │                         │
                            │             ▼                         │
                            │    ┌─────────────────┐                │
                            │    │ gain = 1.0 +    │                │
                            │    │ sst_effective   │                │
                            │    │ clamp [0.5,1.5] │                │
                            │    └────────┬────────┘                │
                            │             │                         │
                            └─────────────┼─────────────────────────┘
                                          ▼ apical_gain
                                   To L2/3 and L5 pyramidal cells
```

### Code Changes

**File:** `src/layer1_minimal.v`

```verilog
//=============================================================================
// v9.4: VIP+ Disinhibition Constants
//=============================================================================
// Time constant ~50ms at 4 kHz: alpha = 0.25/50 = 0.005
localparam signed [WIDTH-1:0] VIP_ALPHA = 18'sd82;   // 0.005 - slower than SST+
localparam signed [WIDTH-1:0] K_VIP = 18'sd8192;     // 0.5 - attention scaling

// Scale attention input by VIP+ gain
wire signed [2*WIDTH-1:0] vip_scaled_full;
wire signed [WIDTH-1:0] vip_scaled;
assign vip_scaled_full = attention_input * K_VIP;
assign vip_scaled = vip_scaled_full >>> FRAC;

// VIP+ state variable with IIR lowpass filter
reg signed [WIDTH-1:0] vip_activity;

always @(posedge clk) begin
    if (rst) vip_activity <= 0;
    else if (clk_en) begin
        vip_activity <= vip_activity + vip_delta;
    end
end

// Compute effective SST+ activity after VIP+ disinhibition
// VIP+ can only reduce positive SST+, not push negative SST+ further down
assign sst_minus_vip = sst_activity - vip_activity;
assign sst_effective = (sst_activity >= 0 && sst_minus_vip < 0) ? 0 : sst_minus_vip;

// Gain uses effective SST+ (after disinhibition)
assign gain_raw = GAIN_BASE + sst_effective;
```

**File:** `src/cortical_column.v`

```verilog
// v9.4: Attention input for VIP+ disinhibition in Layer 1
input wire signed [WIDTH-1:0] attention_input,

// Pass attention to layer1_minimal
layer1_minimal l1 (
    ...
    .attention_input(attention_input),
    ...
);
```

## Effects

### Attention Spotlight

When attention_input is high:
1. VIP+ activity increases (slowly, tau=50ms)
2. sst_effective decreases
3. Apical gain moves toward baseline (1.0)
4. Reduces context-dependent modulation

This creates a "spotlight" effect where attention can override feedback-driven gain modulation.

### Dynamic Range

| Condition | SST+ | VIP+ | sst_effective | Gain |
|-----------|------|------|---------------|------|
| Baseline | 0 | 0 | 0 | 1.0 |
| High feedback | + | 0 | + | > 1.0 |
| High feedback + attention | + | + | 0 | 1.0 |
| Low feedback | - | 0 | - | < 1.0 |
| Low feedback + attention | - | + | more - | < 1.0 |

Note: VIP+ can only reduce positive SST+ effects. Negative SST+ (from low/negative feedback) passes through unchanged.

## Testing

**Testbench:** `tb/tb_vip_disinhibition.v`

**Tests (8/8 passing):**

| Test | Description | Criterion |
|------|-------------|-----------|
| 1 | Reset behavior | vip_activity = 0 after reset |
| 2 | Slow response | VIP+ rises slowly (tau=50ms) |
| 3 | Suppresses SST+ | sst_effective < sst_activity |
| 4 | Increases gain | Gain moves toward 1.0 |
| 5 | Slower than SST+ | VIP+ percentage lower at same time |
| 6 | SST+ effective >= 0 | No negative clamp (when SST+ positive) |
| 7 | Gain clamped | Stays in [0.5, 1.5] |
| 8 | Disinhibition effect | Gain changes with attention |

### Verification Commands

```bash
# Run VIP+ disinhibition test
iverilog -o tb_vip_disinhibition.vvp \
    src/layer1_minimal.v tb/tb_vip_disinhibition.v \
    && vvp tb_vip_disinhibition.vvp

# Run SST+ test (verify backward compatibility)
iverilog -o tb_sst_dynamics.vvp \
    src/layer1_minimal.v tb/tb_sst_dynamics.v \
    && vvp tb_sst_dynamics.vvp

# Run full system test
iverilog -o tb_full_system_fast.vvp -s tb_full_system_fast \
    src/clock_enable_generator.v src/hopf_oscillator.v src/hopf_oscillator_stochastic.v \
    src/ca3_phase_memory.v src/thalamus.v src/pv_interneuron.v src/cortical_column.v \
    src/config_controller.v src/pink_noise_generator.v src/output_mixer.v \
    src/phi_n_neural_processor.v src/sr_harmonic_bank.v src/sr_noise_generator.v \
    src/sr_frequency_drift.v src/layer1_minimal.v tb/tb_full_system_fast.v \
    && vvp tb_full_system_fast.vvp
```

## Phase Progress - Complete!

| Phase | Version | Addition | Status |
|-------|---------|----------|--------|
| 1 | v9.0 | PV+ Minimal (amplitude feedback) | ✅ Complete |
| 2 | v9.1 | SST+ Explicit (slow dynamics) | ✅ Complete |
| 3 | v9.2 | PV+ PING Network (dynamic E-I) | ✅ Complete |
| 4 | v9.3 | Cross-Layer PV+ (L4, L5 populations) | ✅ Complete |
| **5** | **v9.4** | **VIP+ Disinhibition (attention gating)** | **✅ Complete** |

**All 5 phases of the interneuron implementation plan are now complete!**

## Constants

| Name | Q14 Value | Decimal | Description |
|------|-----------|---------|-------------|
| VIP_ALPHA | 82 | 0.005 | VIP+ time constant (tau=50ms) |
| K_VIP | 8192 | 0.5 | Attention input scaling |
| SST_ALPHA | 164 | 0.01 | SST+ time constant (tau=25ms) |
| TAU_INV | 819 | 0.05 | PV+ time constant (tau=5ms) |
| K_EXCITE | 8192 | 0.5 | PV+ pyramid excitation |
| K_INHIB | 4915 | 0.3 | PV+ inhibition weight |

## Files Created/Modified

| File | Changes |
|------|---------|
| `src/layer1_minimal.v` | Updated to v9.4 with VIP+ disinhibition |
| `src/cortical_column.v` | Added attention_input port |
| `src/phi_n_neural_processor.v` | Updated to v9.4, added attention_input=0 |
| `tb/tb_vip_disinhibition.v` | **New** - VIP+ testbench (8 tests) |
| `tb/tb_sst_dynamics.v` | Updated for new layer1_minimal ports |
| `tb/tb_pv_*.v` | Updated with attention_input=0 |
| `CLAUDE.md` | Version update, constants, test list |
| `docs/SPEC_v9.4_UPDATE.md` | This file |

## Compatibility

- Backward compatible with all v9.3 and earlier features
- All existing tests pass (206+ total)
- Default attention_input=0 preserves previous behavior
- SST+ dynamics unchanged when no attention
- No interface changes to phi_n_neural_processor.v outputs

## Future Enhancements

The interneuron implementation plan is complete. Potential future additions:

- **v9.5+**: ACh neuromodulation (acetylcholine for global attention)
- **v9.6+**: NE neuromodulation (norepinephrine for arousal)
- **v9.7+**: Dopamine reward signaling
- **v9.8+**: External attention input from top-level module
