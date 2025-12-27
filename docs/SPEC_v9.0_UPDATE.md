# φⁿ Neural Processor - v9.0 Specification Update

## PV+ Basket Cell Inhibition (Phase 1 - Minimal Model)

**Date:** 2025-12-27
**Version:** 9.0
**Status:** Implemented and Tested

---

## Overview

v9.0 adds the first explicit inhibitory interneuron model to the system: **PV+ (parvalbumin-positive) basket cells** for L2/3 gamma stabilization. This is Phase 1 of the incremental interneuron implementation plan.

## Biological Basis

PV+ basket cells are fast-spiking GABAergic interneurons that:
- Target the soma and proximal dendrites of pyramidal cells (perisomatic inhibition)
- Fire at gamma frequencies (30-80 Hz)
- Receive the same excitatory input as pyramidal cells
- Create the E-I balance necessary for stable gamma oscillations
- Prevent runaway excitation

## Implementation

### Model

The Phase 1 minimal model uses amplitude-proportional inhibition:

```
PV+ inhibition = L2/3_amplitude × K_PV
L2/3 input = (feedforward - PV_inhibition) × apical_gain
```

Where:
- `K_PV = 0.3` (4915 in Q14)
- Subtractive inhibition (not divisive)
- Applied before L1 apical gain modulation

### Signal Flow

```
L4 → L2/3 feedforward
        │
        ▼
l23_input_raw = L4 + PAC + phase_coupling
        │
        ▼
    ┌───────────────────────┐
    │  PV+ Basket Cells     │
    │  inhibition = amp×K   │
    └───────────────────────┘
        │
        ▼
l23_input_with_pv = l23_input_raw - pv_inhibition
        │
        ▼
l23_input = l23_input_with_pv × apical_gain
        │
        ▼
    L2/3 Hopf Oscillator
        │
        └──────────────────────┐
                               │
    l23_amp (amplitude) ───────┘ (feedback to PV+)
```

### Code Changes

**File:** `src/cortical_column.v`

```verilog
// v9.0: PV+ basket cell inhibition constant
localparam signed [WIDTH-1:0] K_PV = 18'sd4915;  // 0.3

// PV+ output proportional to L2/3 amplitude (fast feedback)
wire signed [2*WIDTH-1:0] pv_full;
wire signed [WIDTH-1:0] pv_inhibition;
assign pv_full = l23_amp * K_PV;
assign pv_inhibition = pv_full >>> FRAC;

// L2/3 input with PV+ inhibition subtracted
wire signed [WIDTH-1:0] l23_input_with_pv;
assign l23_input_with_pv = l23_input_raw - pv_inhibition;

// Apply L1 apical gain to PV-adjusted input
assign l23_input_modulated = l23_input_with_pv * l1_apical_gain;
```

## Effects

### Amplitude Stabilization

Without PV+:
- Strong input could cause runaway gamma amplitude
- High MU could lead to unbounded oscillation growth

With PV+:
- Amplitude-proportional negative feedback limits gamma power
- Higher amplitude → more inhibition → natural ceiling
- Creates realistic E-I balance

### Sublinear Gain

The PV+ inhibition compresses the input-output relationship:
- Weak input: minimal PV+ effect
- Strong input: proportionally more inhibition
- Result: sublinear (compressive) gain function

### Preserved Features

- Gamma frequency unchanged (still Hopf-determined)
- Theta-gamma nesting preserved (fast/slow gamma switching)
- L1 apical gain modulation still applies
- All other layer dynamics unchanged

## Testing

**Testbench:** `tb/tb_pv_minimal.v`

**Tests (6/6 passing):**

| Test | Description | Criterion |
|------|-------------|-----------|
| 1 | Baseline oscillation | Amplitude bounded < 35000 |
| 2 | Strong input limiting | Amplitude bounded under drive |
| 3 | High MU stability | Amplitude < 40000 with MU=6 |
| 4 | Oscillation active | Amplitude > 5000, < 35000 |
| 5 | Sublinear gain | Strong/weak ratio < 5× |
| 6 | Fast gamma stability | Bounded in encoding window |

## Future Phases

This is Phase 1 of the interneuron implementation plan:

| Phase | Version | Addition |
|-------|---------|----------|
| **1** | **v9.0** | **PV+ Minimal (amplitude feedback)** ✅ |
| 2 | v9.1 | SST+ Explicit (slow dynamics in L1) |
| 3 | v9.2 | PV+ Feedback Loop (PING network) |
| 4 | v9.3 | Cross-Layer PV+ (L4, L5 populations) |
| 5 | v9.4 | VIP+ Disinhibition (attention gating) |

## Constants

| Name | Q14 Value | Decimal | Description |
|------|-----------|---------|-------------|
| K_PV | 4915 | 0.3 | PV+ inhibition weight |

## Files Modified

| File | Changes |
|------|---------|
| `src/cortical_column.v` | Added K_PV, pv_inhibition, l23_input_with_pv |
| `tb/tb_pv_minimal.v` | New testbench (6 tests) |
| `CLAUDE.md` | Version update, K_PV constant |
| `docs/SPEC_v9.0_UPDATE.md` | This file |

## Compatibility

- Backward compatible with all v8.x features
- All existing tests pass (174+ total)
- No interface changes to phi_n_neural_processor.v
