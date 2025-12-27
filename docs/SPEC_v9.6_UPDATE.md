# v9.6 Specification Update: Extended L6 Connectivity

**Version:** 9.6
**Date:** 2025-12-27
**Feature:** L6 corticothalamic neurons provide modulatory feedback to all cortical layers

---

## Summary

v9.6 adds three new L6 modulatory connections to implement complete infragranular feedback:

| Connection | Weight | Q14 Value | Compartment | Biological Basis |
|------------|--------|-----------|-------------|------------------|
| L6 → L2/3 | 0.15 | 2458 | Basal | Alpha-gamma coupling |
| L6 → L5b | 0.1 | 1638 | Basal | Intra-column feedback |
| L6 → L1 | 0.1 | 1638 | SST+ pathway | Apical gain modulation |

All connections are excitatory (additive) and modulatory (weak weights).

---

## Biological Rationale

### L6 Corticothalamic Neurons

L6 corticothalamic (CT) neurons are unique in having extensive local axon collaterals that project within the cortical column before leaving for thalamus. They provide:

1. **Feedforward modulation**: L6 → L4 (weak, debated in literature)
2. **Feedback modulation**: L6 → L5a, L5b (gain control)
3. **Superficial modulation**: L6 → L2/3, L1 (alpha-gamma coupling)
4. **Thalamic modulation**: L6 → Thalamus + TRN (sensory gating)

### Design Decision: Basal vs Apical

All three new L6 connections go to the **basal compartment** (not apical):

- Consistent with existing L6 → L5a (also basal)
- Intra-column feedback is quasi-feedforward, not top-down context
- Apical compartment reserved for cross-column and CA3 feedback
- Simpler: L6 effect not gated by Ca²⁺ spike state

### L6 → L1 Exception

L6 → L1 is unique: it feeds into the SST+ pathway in `layer1_minimal`, which then modulates `apical_gain`. This means L6 indirectly affects apical processing of ALL layers (L2/3, L5a, L5b) through gain modulation.

---

## Implementation Details

### New Constants (Q4.14)

| Name | Q14 Value | Decimal | Location | Purpose |
|------|-----------|---------|----------|---------|
| K_L6_L23 | 2458 | 0.15 | cortical_column.v | L6 → L2/3 alpha-gamma coupling |
| K_L6_L5B | 1638 | 0.1 | cortical_column.v | L6 → L5b intra-column feedback |
| K_L6_L1 | 1638 | 0.1 | layer1_minimal.v | L6 → L1 direct gain modulation |

### Signal Flow

```
L6 oscillator (l6_x_int)
    │
    ├──> L6 → L2/3 (K=0.15) ──> l23_input_raw ──> dend_l23.basal_input
    │
    ├──> L6 → L5a (K=0.15, existing v8.8) ──> l5a_input_raw ──> dend_l5a.basal_input
    │
    ├──> L6 → L5b (K=0.1, NEW) ──> l5b_input_raw ──> dend_l5b.basal_input
    │
    ├──> L6 → L1 (K=0.1, NEW) ──> layer1_minimal.gain_offset ──> SST+ ──> apical_gain
    │                                                                        │
    │                                                      ┌─────────────────┴─────────────────┐
    │                                                      │                                   │
    │                                              dend_l23.apical_gain            dend_l5a/l5b.apical_gain
    │
    └──> L6 → Thalamus (K=0.3 combined, existing v8.8) ──> theta_gate inhibition
```

### Modified Files

#### 1. `src/cortical_column.v`
- Added `K_L6_L23 = 18'sd2458` (line 202)
- Added `K_L6_L5B = 18'sd1638` (line 203)
- Added wire declarations `l6_to_l23_full`, `l6_to_l5b_full` (lines 221-222)
- Added L6 → L5b computation (line 277)
- Modified `l5b_input_raw` to include L6 contribution (line 280)
- Added L6 → L2/3 computation (line 340)
- Modified `l23_input_raw` to include L6 contribution (line 343)
- Added `l6_direct_input` port to layer1_minimal instantiation (line 247)
- Updated version to v9.6 (line 2)

#### 2. `src/layer1_minimal.v`
- Added `l6_direct_input` port (lines 74-76)
- Added `K_L6_L1 = 18'sd1638` constant (line 124)
- Added L6 contribution computation (lines 142-146)
- Modified `gain_offset` to include L6 contribution (line 150)
- Updated version to v9.6 (line 2)

#### 3. `tb/tb_l6_extended.v` (NEW)
- New testbench with 10 tests for extended L6 connectivity
- Tests L6 → L2/3, L6 → L5b, L6 → L1 pathways
- Verifies functional integration

---

## Complete L6 Connectivity (v9.6)

After v9.6, L6 connects to all major targets:

| Target | Weight | Version | Type | Mechanism |
|--------|--------|---------|------|-----------|
| L2/3 | 0.15 | v9.6 | Excitatory | Alpha-gamma coupling (basal) |
| L5a | 0.15 | v8.8 | Excitatory | Intra-column feedback (basal) |
| L5b | 0.1 | v9.6 | Excitatory | Intra-column feedback (basal) |
| L1 | 0.1 | v9.6 | Excitatory | SST+ → apical gain |
| Thalamus | 0.1 | v8.8 | Inhibitory | Direct L6 → Thalamus |
| TRN | 0.2 | v8.8 | Inhibitory | L6 → TRN → Thalamus |

**NOT implemented:** L6 → L4 (intentionally omitted based on recent literature showing L6 projects to L5a, not L4)

---

## Testing

### New Testbench: `tb/tb_l6_extended.v`

10 tests covering:
1. L6 → L2/3 pathway wire exists
2. L6 contributes to L2/3 input
3. L6 → L5b pathway wire exists
4. L6 contributes to L5b input
5. L6 → L1 pathway wire exists
6. L6 contributes to L1 gain_offset
7. High L6 increases L2/3 input (functional)
8. High L6 increases L5b input (functional)
9. High L6 modulates L1 gain (functional)
10. All pathways work together (integration)

### Regression Results

All existing tests pass (216+ tests total):
- `tb_full_system_fast`: 15/15 tests
- `tb_l6_connectivity`: 10/10 tests
- `tb_l6_extended`: 10/10 tests (NEW)
- `tb_learning_fast`: 8/8 tests
- All other testbenches: PASS

---

## Backward Compatibility

The system maintains backward compatibility:
- L6 contributions are additive (excitatory)
- When L6 activity is low, new pathways have minimal effect
- Existing L6 → L5a and L6 → Thalamus pathways unchanged
- All existing tests pass without modification

---

## Resource Impact

| Component | Additional DSP48s | Additional Registers |
|-----------|-------------------|----------------------|
| L6 → L2/3 × 3 columns | 3 | 0 |
| L6 → L5b × 3 columns | 3 | 0 |
| L6 → L1 × 3 columns | 3 | 0 |
| **Total Added** | 9 | 0 |

Zynq-7020 has 220 DSP48 slices - well within budget.

---

## References

- Constantinople CM, Bruno RM (2013) "Deep cortical layers are activated directly by thalamus" Science
- Kim J et al. (2014) "Layer 6 corticothalamic neurons activate a cortical output layer" J Neurosci
- Thomson AM (2010) "Neocortical layer 6, a review" Front Neuroanat
- Harris KD, Shepherd GM (2015) "The neocortical circuit: themes and variations" Nat Neurosci

---

## Changelog

### v9.6 (2025-12-27)
- NEW: L6 → L2/3 pathway (K_L6_L23 = 0.15)
- NEW: L6 → L5b pathway (K_L6_L5B = 0.1)
- NEW: L6 → L1 pathway (K_L6_L1 = 0.1)
- NEW: `tb_l6_extended.v` testbench (10 tests)
- MODIFIED: `cortical_column.v` - extended L6 output connectivity
- MODIFIED: `layer1_minimal.v` - added l6_direct_input port
