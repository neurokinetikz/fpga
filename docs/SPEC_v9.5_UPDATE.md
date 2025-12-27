# v9.5 Specification Update: Two-Compartment Dendritic Computation

**Version:** 9.5
**Date:** 2025-12-27
**Feature:** Biologically realistic basal/apical dendritic integration with Ca²⁺ spike dynamics

---

## Summary

v9.5 adds two-compartment dendritic computation to L2/3, L5a, and L5b pyramidal neurons. This separates feedforward (basal) from feedback (apical) inputs and implements calcium spike-mediated coincidence detection (BAC firing) for supralinear responses when both compartments are active.

---

## Biological Rationale

| Compartment | Location | Inputs | Function |
|-------------|----------|--------|----------|
| **Basal** | Proximal dendrites | Feedforward (L4→L2/3) | "What is the sensory input?" |
| **Apical** | Distal dendrites (L1) | Feedback (matrix, phase coupling) | "Is this input relevant?" |

**Key mechanism:** When both compartments are active simultaneously, Ca²⁺ spikes in the apical dendrite create a **supralinear** response (BAC firing = Backpropagation-Activated Calcium).

### Ca²⁺ Spike Dynamics

The apical compartment implements plateau potentials via:
1. **Cable filter** (tau=10ms): Models electrotonic decay along apical dendrite trunk
2. **Ca²⁺ threshold detection**: State-dependent threshold crossing triggers spike
3. **Plateau duration** (tau=30ms): Slow IIR filter models Ca²⁺ spike duration

### BAC Firing (Coincidence Detection)

When BOTH conditions are met:
- Basal input exceeds threshold (sensory/feedforward active)
- Ca²⁺ spike is active (feedback/apical active)

The output receives a **1.5× supralinear boost**, implementing context-dependent amplification.

---

## Implementation Details

### New Module: `src/dendritic_compartment.v`

```verilog
module dendritic_compartment #(
    parameter WIDTH = 18,
    parameter FRAC = 14
)(
    input  wire clk, rst, clk_en,
    input  wire signed [WIDTH-1:0] basal_input,      // Feedforward
    input  wire signed [WIDTH-1:0] apical_input,     // Feedback
    input  wire signed [WIDTH-1:0] apical_gain,      // From L1 SST+/VIP+
    input  wire signed [WIDTH-1:0] ca_threshold,     // State-dependent
    output wire signed [WIDTH-1:0] dendritic_output,
    output wire ca_spike_active,
    output wire bac_active
);
```

### Constants (Q4.14)

| Name | Q14 Value | Decimal | Purpose |
|------|-----------|---------|---------|
| APICAL_CABLE_ALPHA | 410 | 0.025 | Cable filter (tau=10ms at 4kHz) |
| CA_DURATION_ALPHA | 137 | 0.00833 | Spike duration (tau=30ms at 4kHz) |
| K_APICAL | 4096 | 0.25 | Apical contribution weight |
| K_BAC | 24576 | 1.5 | BAC supralinear boost |
| BAC_BASAL_THRESH | 4096 | 0.25 | Basal activity threshold |
| BAC_APICAL_THRESH | 4096 | 0.25 | Ca²⁺ threshold for BAC |

### State-Dependent Ca²⁺ Threshold

The `config_controller` outputs a state-dependent `ca_threshold`:

| State | CA_THRESHOLD | Q14 Value | Effect |
|-------|--------------|-----------|--------|
| NORMAL | 0.5 | 8192 | Balanced |
| ANESTHESIA | 0.75 | 12288 | Higher → fewer Ca²⁺ spikes |
| PSYCHEDELIC | 0.25 | 4096 | Lower → more Ca²⁺ spikes |
| FLOW | 0.5 | 8192 | Balanced |
| MEDITATION | 0.375 | 6144 | Slightly lower → enhanced top-down |

---

## Modified Files

### 1. `src/config_controller.v`
- Added `ca_threshold` output port
- Added state-dependent threshold values
- Updated version to v9.5

### 2. `src/cortical_column.v`
- Added `ca_threshold` input port
- Instantiated `dendritic_compartment` for L2/3, L5a, L5b
- Added debug outputs: `l23_ca_spike`, `l23_bac`, etc.
- Replaced simple gain modulation with two-compartment model

**Layer-Compartment Mapping:**

| Layer | Basal Input | Apical Input |
|-------|-------------|--------------|
| L2/3 | L4 feedforward + PAC - PV | phase_couple_l23 (CA3) |
| L5a | L2/3 + L6 + L4_bypass | feedback_input_2 (distant) |
| L5b | L2/3 + inter-column FB | feedback_input_1 (adjacent) |
| L4 | (unchanged) | N/A - no apical in L1 |
| L6 | (unchanged) | N/A - CT neurons |

### 3. `src/phi_n_neural_processor.v`
- Wired `ca_threshold` from config_controller to all cortical columns
- Added debug wires for dendritic compartment outputs
- Updated version to v9.5

### 4. `Makefile`
- Added `pv_interneuron.v` and `dendritic_compartment.v` to COMMON_SRCS
- Updated version to v9.5

---

## Signal Flow

```
                    LAYER 1 (SST+/VIP+ → apical_gain)
    ════════════════════════════════════════════════════════
                              │
    Phase Coupling ──────────▶│ APICAL ──▶ Cable Filter ──▶ Ca²⁺ Threshold
    (feedback)                │           (tau=10ms)            │
                              │                                 ▼
                              │                           Ca²⁺ Spike State
                              │                            (tau=30ms)
                              │                                 │
                              │                                 ▼
    L4 Feedforward ──────────▶│ BASAL ─────────────────▶ BAC Detector
    - PV inhibition           │ (direct)                  (coincidence)
                              │                                 │
                              │                                 ▼
                              │                        dendritic_output
                              │                         (to oscillator)
                              │
    ════════════════════════════════════════════════════════
                         L2/3, L5a, L5b NEURONS
```

---

## Testing

### New Testbench: `tb/tb_dendritic_compartment.v`

10 unit tests covering:
1. Reset behavior
2. Basal-only passthrough
3. Apical below threshold (no Ca²⁺)
4. Apical above threshold (Ca²⁺ spike)
5. Ca²⁺ spike duration (tau=30ms persistence)
6. Apical gain modulation
7. BAC: basal only (no boost)
8. BAC: apical only (no boost)
9. BAC: coincidence (1.5× boost)
10. BAC timing window

### Regression Results

All existing tests continue to pass (206+ tests):
- `tb_full_system_fast`: 15/15 tests
- `tb_theta_phase_multiplexing`: 19/19 tests
- `tb_scaffold_architecture`: 14/14 tests
- `tb_gamma_theta_nesting`: 7/7 tests
- `tb_canonical_microcircuit`: 20/20 tests
- `tb_layer1_minimal`: 10/10 tests
- `tb_l6_connectivity`: 10/10 tests
- `tb_dendritic_compartment`: 10/10 tests (NEW)
- And more...

---

## Backward Compatibility

The system maintains backward compatibility:
- When `apical_input` is small: No Ca²⁺ threshold crossing → output ≈ basal × gain
- Default behavior approximates v9.4 linear gain modulation
- All existing tests pass without modification

---

## Resource Impact

| Component | Count | Additional DSP48s | Additional Registers |
|-----------|-------|-------------------|----------------------|
| L2/3 dend × 3 columns | 3 | 3-6 | 6 |
| L5a dend × 3 columns | 3 | 3-6 | 6 |
| L5b dend × 3 columns | 3 | 3-6 | 6 |
| **Total Added** | 9 | 9-18 | 18 |

Zynq-7020 has 220 DSP48 slices - well within budget.

---

## Usage Notes

### Consciousness State Effects

| State | Ca²⁺ Threshold | Effect on Dendritic Computation |
|-------|----------------|--------------------------------|
| PSYCHEDELIC | Low (0.25) | More Ca²⁺ spikes → enhanced top-down influence |
| ANESTHESIA | High (0.75) | Fewer Ca²⁺ spikes → reduced integration |
| MEDITATION | Slightly low (0.375) | Enhanced internal processing |

### Debug Outputs

Each cortical column exposes:
- `l23_ca_spike`, `l5a_ca_spike`, `l5b_ca_spike`: Ca²⁺ spike active
- `l23_bac`, `l5a_bac`, `l5b_bac`: BAC coincidence active

---

## References

- Larkum, M. E., et al. (2009). "Synaptic integration in tuft dendrites of layer 5 pyramidal neurons"
- Major, G., et al. (2013). "Active properties of neocortical pyramidal neuron dendrites"
- Takahashi, N., et al. (2020). "Active dendritic currents gate descending cortical outputs in perception"

---

## Changelog

### v9.5 (2025-12-27)
- NEW: `dendritic_compartment.v` module
- NEW: `tb_dendritic_compartment.v` testbench (10 tests)
- MODIFIED: `config_controller.v` - added `ca_threshold` output
- MODIFIED: `cortical_column.v` - integrated dendritic compartments
- MODIFIED: `phi_n_neural_processor.v` - wired `ca_threshold`
- MODIFIED: `Makefile` - added new source files
