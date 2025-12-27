# φⁿ Neural Processor - v9.2 Specification Update

## PV+ PING Network (Phase 3 - Dynamic Interneuron Model)

**Date:** 2025-12-27
**Version:** 9.2
**Status:** Implemented and Tested

---

## Overview

v9.2 upgrades the PV+ basket cell model from amplitude-proportional inhibition (Phase 1) to a full **PING (Pyramidal-Interneuron Gamma Network)** model. The PV+ interneuron now has its own dynamics with a leaky integrator, creating realistic E-I oscillatory coupling.

## Biological Basis

PV+ (parvalbumin-positive) basket cells are fast-spiking GABAergic interneurons that:
- Target the soma and proximal dendrites of pyramidal cells
- Fire at gamma frequencies (30-80 Hz)
- Have fast membrane time constants (~5-10ms)
- Create the E-I loop essential for gamma oscillation generation
- Phase relationship: PV+ activity lags pyramidal by ~90°

### Phase 1 vs Phase 3 Model

| Property | Phase 1 (v9.0) | Phase 3 (v9.2) |
|----------|---------------|----------------|
| Inhibition type | Instantaneous | Dynamic with delay |
| State variable | None (amplitude-proportional) | pv_state (leaky integrator) |
| Time constant | N/A | tau = 5ms |
| Phase lag | None | ~90° at gamma frequency |
| PING dynamics | No | Yes |
| Module | Inline in cortical_column.v | Separate pv_interneuron.v |

## Implementation

### New Module: pv_interneuron.v

```verilog
module pv_interneuron #(
    parameter WIDTH = 18,
    parameter FRAC = 14
)(
    input  wire clk, rst, clk_en,
    input  wire signed [WIDTH-1:0] pyramid_input,  // From L2/3 oscillator
    output wire signed [WIDTH-1:0] inhibition,      // To L2/3 input
    output wire signed [WIDTH-1:0] pv_state_out     // Debug
);
```

### Leaky Integrator Dynamics

The PV+ interneuron uses a leaky integrator model:

```
drive = K_EXCITE × pyramid_input - pv_state
delta = TAU_INV × drive
pv_state[n+1] = pv_state[n] + delta
inhibition = K_INHIB × pv_state
```

Where:
- `TAU_INV = 0.05` (819 in Q14) → tau = 5ms
- `K_EXCITE = 0.5` (8192 in Q14) - excitation gain
- `K_INHIB = 0.3` (4915 in Q14) - inhibition output

### Signal Flow

```
        ┌──────────────────────────────────────────────┐
        │                PING E-I Loop                  │
        │                                              │
L4 ─────┴──▶ l23_input_raw ───┬──▶ l23_input_with_pv ──┤
                              │                        │
                              ▼                        │
                    ┌─────────────────┐               │
                    │ pv_interneuron   │               │
                    │                 │               │
                    │  ┌───────────┐  │               │
 L2/3 oscillator ──────▶│ Leaky     │──┼──▶ pv_inhibition
       l23_x_int    │  │ Integrator│  │               │
                    │  │ tau=5ms   │  │               ▼
                    │  └───────────┘  │         (subtracts)
                    │                 │               │
                    │  pv_state       │               │
                    └─────────────────┘               │
                                                      │
        ┌─────────────────────────────────────────────┘
        │
        ▼
   L2/3 Hopf Oscillator ──▶ l23_x, l23_y, l23_amp
        │
        └──────────────▶ (feedback to pv_interneuron)
```

### Integration in cortical_column.v

```verilog
// v9.2: PV+ PING Network
wire signed [WIDTH-1:0] pv_inhibition;
wire signed [WIDTH-1:0] pv_state_debug;

pv_interneuron #(
    .WIDTH(WIDTH),
    .FRAC(FRAC)
) pv_l23 (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .pyramid_input(l23_x_int),     // From L2/3 oscillator
    .inhibition(pv_inhibition),    // To L2/3 input
    .pv_state_out(pv_state_debug)
);

// L2/3 input with PV+ inhibition
assign l23_input_with_pv = l23_input_raw - pv_inhibition;
```

## Effects

### Dynamic Inhibition

Phase 1: `inhibition = K_PV × amplitude` (instantaneous)
Phase 3: `inhibition = K_INHIB × pv_state` (filtered with tau=5ms)

The filtering creates:
- Temporal smoothing of the inhibitory signal
- Phase lag between pyramid activity and inhibition
- More realistic PING dynamics

### Phase Relationship

At gamma frequency (~40 Hz), the 5ms time constant creates a phase lag:
- Pyramid peaks → PV+ peaks ~1-2ms later
- At 40 Hz (25ms period), this is ~15-30° phase shift
- Creates stable E-I oscillation

### Amplitude Stability

The PING network provides amplitude stabilization through:
- Negative feedback loop (high pyramid → high PV+ → more inhibition)
- Temporal dynamics prevent abrupt changes
- Creates bounded gamma oscillation

## Testing

**Testbench:** `tb/tb_pv_feedback.v`

**Tests (8/8 passing):**

| Test | Description | Criterion |
|------|-------------|-----------|
| 1 | Reset behavior | pv_state = 0 after reset |
| 2 | Temporal dynamics | pv_state evolves over time |
| 3 | Dynamic variation | pv_state span > 100 (filtered) |
| 4 | Gamma stability | Amplitude bounded [1000, 35000] |
| 5 | Pyramid tracking | Correlation > 50% |
| 6 | High MU stability | Amplitude < 45000 with MU=6 |
| 7 | Fast gamma stability | Bounded in encoding window |
| 8 | Inhibition magnitude | Range [100, 20000] |

### Verification Commands

```bash
# Run PV+ PING network test
iverilog -o tb_pv_feedback.vvp -DFAST_SIM \
    src/hopf_oscillator.v src/pv_interneuron.v src/cortical_column.v \
    src/layer1_minimal.v tb/tb_pv_feedback.v && vvp tb_pv_feedback.vvp

# Run full system test (confirms no regression)
iverilog -o tb_full_system_fast.vvp -DFAST_SIM \
    src/clock_enable_generator.v src/hopf_oscillator.v src/hopf_oscillator_stochastic.v \
    src/ca3_phase_memory.v src/thalamus.v src/pv_interneuron.v src/cortical_column.v \
    src/config_controller.v src/pink_noise_generator.v src/output_mixer.v \
    src/phi_n_neural_processor.v src/sr_harmonic_bank.v src/sr_noise_generator.v \
    src/sr_frequency_drift.v src/layer1_minimal.v tb/tb_full_system_fast.v \
    && vvp tb_full_system_fast.vvp
```

## Phase Progress

| Phase | Version | Addition | Status |
|-------|---------|----------|--------|
| 1 | v9.0 | PV+ Minimal (amplitude feedback) | ✅ Complete |
| 2 | v9.1 | SST+ Explicit (slow dynamics) | ✅ Complete |
| **3** | **v9.2** | **PV+ PING Network (dynamic E-I)** | **✅ Complete** |
| 4 | v9.3 | Cross-Layer PV+ (L4, L5 populations) | Planned |
| 5 | v9.4 | VIP+ Disinhibition (attention gating) | Planned |

## Constants

| Name | Q14 Value | Decimal | Description |
|------|-----------|---------|-------------|
| TAU_INV | 819 | 0.05 | Time constant inverse (tau = 5ms) |
| K_EXCITE | 8192 | 0.5 | Pyramid → PV+ excitation gain |
| K_INHIB | 4915 | 0.3 | PV+ → Pyramid inhibition weight |
| SST_ALPHA | 164 | 0.01 | SST+ filter coefficient (v9.1) |

## Files Created/Modified

| File | Changes |
|------|---------|
| `src/pv_interneuron.v` | **New** - PV+ dynamic interneuron module |
| `src/cortical_column.v` | Updated to v9.2, replaced Phase 1 PV+ with module |
| `tb/tb_pv_feedback.v` | **New** - PING network testbench (8 tests) |
| `CLAUDE.md` | Version update, constants, test list |
| `docs/SPEC_v9.2_UPDATE.md` | This file |

## Compatibility

- Backward compatible with all v9.1 and earlier features
- All existing tests pass (190+ total)
- Phase 1 testbench (tb_pv_minimal) still passes with new model
- No interface changes to phi_n_neural_processor.v
