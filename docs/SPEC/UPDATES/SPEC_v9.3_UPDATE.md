# φⁿ Neural Processor - v9.3 Specification Update

## Cross-Layer PV+ Network (Phase 4 - L4/L5 Interneuron Populations)

**Date:** 2025-12-27
**Version:** 9.3
**Status:** Implemented and Tested

---

## Overview

v9.3 extends the PV+ network from a single L2/3 population (Phase 3) to a **cross-layer architecture** with three distinct PV+ populations:

1. **L2/3 PV+** - Local PING network (1.0× weight) - from v9.2
2. **L4 PV+** - Feedforward gating (0.5× weight) - new
3. **L5 PV+** - Feedback inhibition (0.25× weight) - new

This creates a multi-layer inhibitory network that gates both feedforward and feedback pathways.

## Biological Basis

Cortical PV+ interneurons are distributed across layers with distinct functional roles:

### L2/3 PV+ (Basket Cells)
- Local gamma generation via PING network
- Target nearby L2/3 pyramidal cells
- Create E-I oscillation essential for gamma

### L4 PV+ (Feedforward Inhibition)
- Gate thalamocortical input to L2/3
- Driven by L4 spiny stellate activity
- Provide feedforward inhibition matching sensory drive
- Create temporal precision in sensory responses

### L5 PV+ (Feedback Inhibition)
- Gate top-down signals from L5b
- Driven by PT (pyramidal tract) neuron activity
- Provide feedback inhibition proportional to output
- Balance excitation from cortical feedback

### Weight Hierarchy

| Population | Weight | Rationale |
|------------|--------|-----------|
| L2/3 PV+ | 1.0× | Local, strongest inhibition |
| L4 PV+ | 0.5× | Feedforward gating |
| L5 PV+ | 0.25× | Feedback gating |

The decreasing weights reflect the distance from L2/3 and the indirect nature of cross-layer inhibition.

## Implementation

### Cross-Layer PV+ Architecture

```
                    ┌─────────────────────────────────────┐
                    │         L2/3 Pyramidal Cell          │
                    │                                     │
                    │  ┌───────────────────────────────┐  │
                    │  │   Combined PV+ Inhibition      │  │
                    │  │   = L23 + L4/2 + L5/4          │  │
                    │  └──────────────┬────────────────┘  │
                    │                 │                   │
                    └─────────────────┼───────────────────┘
                                      │
            ┌─────────────────────────┼─────────────────────────┐
            │                         │                         │
            ▼ (1.0×)                  ▼ (0.5×)                  ▼ (0.25×)
   ┌────────────────┐        ┌────────────────┐        ┌────────────────┐
   │   L2/3 PV+     │        │    L4 PV+      │        │    L5 PV+      │
   │ (local PING)   │        │ (feedforward)  │        │ (feedback)     │
   │                │        │                │        │                │
   │ pyramid_input: │        │ pyramid_input: │        │ pyramid_input: │
   │   l23_x_int    │        │   l4_x_int     │        │   l5b_x_int    │
   └────────────────┘        └────────────────┘        └────────────────┘
           ▲                         ▲                         ▲
           │                         │                         │
      L2/3 oscillator           L4 oscillator            L5b oscillator
```

### Code Changes in cortical_column.v

```verilog
//=============================================================================
// v9.3: Cross-Layer PV+ Network
//=============================================================================
// Three PV+ populations create multi-layer inhibitory control:
// - L2/3 PV+: Local PING network (1.0× weight)
// - L4 PV+:   Feedforward gating (0.5× weight)
// - L5 PV+:   Feedback inhibition (0.25× weight)

// L2/3 local PV+ (PING network) - from v9.2
wire signed [WIDTH-1:0] pv_l23_inhibition;
wire signed [WIDTH-1:0] pv_l23_state;

pv_interneuron #(.WIDTH(WIDTH), .FRAC(FRAC)) pv_l23 (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .pyramid_input(l23_x_int),
    .inhibition(pv_l23_inhibition),
    .pv_state_out(pv_l23_state)
);

// L4 PV+ (feedforward gating) - new in v9.3
wire signed [WIDTH-1:0] pv_l4_inhibition;
wire signed [WIDTH-1:0] pv_l4_state;

pv_interneuron #(.WIDTH(WIDTH), .FRAC(FRAC)) pv_l4 (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .pyramid_input(l4_x_int),
    .inhibition(pv_l4_inhibition),
    .pv_state_out(pv_l4_state)
);

// L5 PV+ (feedback inhibition) - new in v9.3
wire signed [WIDTH-1:0] pv_l5_inhibition;
wire signed [WIDTH-1:0] pv_l5_state;

pv_interneuron #(.WIDTH(WIDTH), .FRAC(FRAC)) pv_l5 (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .pyramid_input(l5b_x_int),
    .inhibition(pv_l5_inhibition),
    .pv_state_out(pv_l5_state)
);

// Combined inhibition: 1.0× L23 + 0.5× L4 + 0.25× L5
wire signed [WIDTH-1:0] pv_total_inhibition;
assign pv_total_inhibition = pv_l23_inhibition +
                             (pv_l4_inhibition >>> 1) +   // 0.5×
                             (pv_l5_inhibition >>> 2);    // 0.25×

// L2/3 input with combined PV+ inhibition
assign l23_input_with_pv = l23_input_raw - pv_total_inhibition;
```

## Effects

### Feedforward Gating (L4 PV+)

When L4 (thalamocortical layer) is strongly activated:
- L4 PV+ activity increases
- L4 PV+ inhibition to L2/3 increases
- Creates gain control on feedforward pathway
- Matches sensory drive with proportional inhibition

### Feedback Gating (L5 PV+)

When L5b (output layer) is strongly activated:
- L5 PV+ activity increases
- L5 PV+ inhibition to L2/3 increases
- Gates top-down feedback signals
- Prevents runaway feedback amplification

### Combined E-I Balance

The three PV+ populations together create:
- Multi-source inhibitory control of L2/3
- Balanced feedforward and feedback gating
- Stable gamma oscillation under varying input conditions
- Cross-layer coordination of inhibition

### Signal Flow

```
Feedforward Path:
Thalamus → L4 → L4 PV+ ─┐
                        ├──▶ L2/3 (inhibited)
           L4 ──────────┘

Feedback Path:
L6 ← L5 ← L2/3
      │
      L5b → L5 PV+ ─────▶ L2/3 (inhibited)

Local Path:
L2/3 ←→ L2/3 PV+ (PING)
```

## Testing

**Testbench:** `tb/tb_pv_crosslayer.v`

**Tests (8/8 passing):**

| Test | Description | Criterion |
|------|-------------|-----------|
| 1 | Reset behavior | All PV+ states = 0 after reset |
| 2 | All populations active | L23, L4, L5 PV+ all non-zero |
| 3 | L4 PV+ tracks L4 | Higher L4 drive → higher L4 PV+ |
| 4 | L5 PV+ tracks L5b | Feedback input → higher L5 PV+ |
| 5 | Combined sum correct | Total = L23 + L4/2 + L5/4 |
| 6 | L2/3 amplitude bounded | Amplitude in [1000, 40000] |
| 7 | High MU stability | Amplitude < 50000 with MU=6 |
| 8 | Feedforward gating | L4 PV+ contributes > 100 |

### Verification Commands

```bash
# Run cross-layer PV+ test
iverilog -o tb_pv_crosslayer.vvp -DFAST_SIM \
    src/hopf_oscillator.v src/pv_interneuron.v src/cortical_column.v \
    src/layer1_minimal.v tb/tb_pv_crosslayer.v && vvp tb_pv_crosslayer.vvp

# Run full system test (confirms no regression)
iverilog -o tb_full_system_fast.vvp -DFAST_SIM \
    src/clock_enable_generator.v src/hopf_oscillator.v src/hopf_oscillator_stochastic.v \
    src/ca3_phase_memory.v src/thalamus.v src/pv_interneuron.v src/cortical_column.v \
    src/config_controller.v src/pink_noise_generator.v src/output_mixer.v \
    src/phi_n_neural_processor.v src/sr_harmonic_bank.v src/sr_noise_generator.v \
    src/sr_frequency_drift.v src/layer1_minimal.v tb/tb_full_system_fast.v \
    && vvp tb_full_system_fast.vvp

# Run PING network test (should still pass)
iverilog -o tb_pv_feedback.vvp -DFAST_SIM \
    src/hopf_oscillator.v src/pv_interneuron.v src/cortical_column.v \
    src/layer1_minimal.v tb/tb_pv_feedback.v && vvp tb_pv_feedback.vvp
```

## Phase Progress

| Phase | Version | Addition | Status |
|-------|---------|----------|--------|
| 1 | v9.0 | PV+ Minimal (amplitude feedback) | ✅ Complete |
| 2 | v9.1 | SST+ Explicit (slow dynamics) | ✅ Complete |
| 3 | v9.2 | PV+ PING Network (dynamic E-I) | ✅ Complete |
| **4** | **v9.3** | **Cross-Layer PV+ (L4, L5 populations)** | **✅ Complete** |
| 5 | v9.4 | VIP+ Disinhibition (attention gating) | Planned |

## Constants

| Name | Q14 Value | Decimal | Description |
|------|-----------|---------|-------------|
| TAU_INV | 819 | 0.05 | PV+ time constant inverse (tau = 5ms) |
| K_EXCITE | 8192 | 0.5 | Pyramid → PV+ excitation gain |
| K_INHIB | 4915 | 0.3 | PV+ → Pyramid inhibition weight |
| L4 weight | N/A | 0.5 | L4 PV+ contribution (>>> 1) |
| L5 weight | N/A | 0.25 | L5 PV+ contribution (>>> 2) |

## Files Created/Modified

| File | Changes |
|------|---------|
| `src/cortical_column.v` | Updated to v9.3, added L4/L5 PV+ instances |
| `tb/tb_pv_crosslayer.v` | **New** - Cross-layer PV+ testbench (8 tests) |
| `tb/tb_pv_feedback.v` | Fixed signal path for v9.3 compatibility |
| `CLAUDE.md` | Version update, test list, spec reference |
| `docs/SPEC_v9.3_UPDATE.md` | This file |

## Compatibility

- Backward compatible with all v9.2 and earlier features
- All existing tests pass (198+ total)
- Phase 3 testbench (tb_pv_feedback) still passes
- Phase 1 testbench (tb_pv_minimal) still passes
- No interface changes to phi_n_neural_processor.v
