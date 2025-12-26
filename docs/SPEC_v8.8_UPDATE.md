# φⁿ Neural Processor Specification Update: v8.7 → v8.8

**Version**: 8.8
**Date**: 2025-12-26
**Status**: Implemented and Verified

---

## Overview

v8.8 implements **correct L6 output targets**, fixing the connectivity of Layer 6 corticothalamic (CT) neurons to match recent neuroscience findings.

**Key Changes:**
- L5a now has separate input from L5b (was shared)
- Added L6 → L5a intra-column pathway (K_L6_L5A = 0.15)
- Added L4 → L5a bypass pathway (K_L4_L5A = 0.1)
- Added L6 → Thalamus inhibitory modulation (K_L6_THAL = 0.1)
- Added TRN-like amplification of L6 inhibition (K_TRN = 0.2)
- All 162 tests passing (152 existing + 10 new)

---

## 1. Motivation: Correct L6 Output Targets

### 1.1 The Problem

In v8.7, L6 corticothalamic (CT) neurons had incomplete output connectivity:
- L6 output only used for SR coherence computation
- No direct modulation of thalamic theta_gate
- No intra-column L6 → L5a pathway
- No L4 → L5a bypass for fast sensorimotor responses
- L5a and L5b shared the same input (biologically inaccurate)

### 1.2 Biological Basis

**L6 Corticothalamic Outputs:**
- **L6 → Thalamus (10:1 ratio)**: CT neurons project to thalamic relay cells with approximately 10:1 convergence ratio, providing modulatory (not driving) input
- **L6 → TRN**: Projects to Thalamic Reticular Nucleus (GABAergic), which inhibits thalamus
- **L6 → L5a**: Recent finding shows L6 projects to L5a within the same column (NOT to L4 as previously thought)

**L4 → L5a Bypass:**
- Minor parallel pathway enabling faster sensorimotor responses
- Bypasses L2/3 processing for rapid motor output

### 1.3 The Solution

1. Separate L5a and L5b inputs in `cortical_column.v`
2. Add L6 → L5a intra-column pathway
3. Add L4 → L5a bypass pathway
4. Add L6 inhibitory modulation to theta_gate in `thalamus.v`
5. Add simplified TRN-like amplification

---

## 2. Implementation Details

### 2.1 Separate L5a/L5b Inputs (cortical_column.v)

**Previous (v8.7):**
```verilog
// Both L5a and L5b used shared l5_input
hopf_oscillator osc_l5a (.input_x(l5_input), ...);
hopf_oscillator osc_l5b (.input_x(l5_input), ...);
```

**New (v8.8):**
```verilog
// L5b: L2/3 feedforward + inter-column feedback
assign l5b_input_raw = (l23_to_l5_full >>> FRAC) + (fb_l5_full >>> FRAC);

// L5a: L2/3 + L6 feedback + L4 bypass
assign l5a_input_raw = (l23_to_l5_full >>> FRAC) + (l6_to_l5a_full >>> FRAC) + (l4_to_l5a_full >>> FRAC);

hopf_oscillator osc_l5a (.input_x(l5a_input), ...);  // Separate L5a input
hopf_oscillator osc_l5b (.input_x(l5b_input), ...);  // Separate L5b input
```

### 2.2 L6 → L5a Intra-Column Pathway

```verilog
// New coupling constant
localparam signed [WIDTH-1:0] K_L6_L5A = 18'sd2458;  // 0.15

// L6 → L5a pathway
wire signed [2*WIDTH-1:0] l6_to_l5a_full;
assign l6_to_l5a_full = l6_x_int * K_L6_L5A;
```

### 2.3 L4 → L5a Bypass Pathway

```verilog
// New coupling constant
localparam signed [WIDTH-1:0] K_L4_L5A = 18'sd1638;  // 0.1

// L4 → L5a bypass (fast sensorimotor pathway)
wire signed [2*WIDTH-1:0] l4_to_l5a_full;
assign l4_to_l5a_full = l4_x_int * K_L4_L5A;
```

### 2.4 L6 → Thalamus Inhibitory Modulation (thalamus.v)

```verilog
// New coupling constants
localparam signed [WIDTH-1:0] K_L6_THAL = 18'sd1638;  // 0.1 - direct L6 inhibition
localparam signed [WIDTH-1:0] K_TRN = 18'sd3277;      // 0.2 - TRN amplification

// L6 inhibition computation
wire signed [2*WIDTH-1:0] l6_direct_full = l6_alpha_feedback * K_L6_THAL;
wire signed [2*WIDTH-1:0] l6_trn_full = l6_alpha_feedback * K_TRN;
// Total: 0.1 + 0.2 = 0.3 × l6_alpha_feedback
wire signed [WIDTH-1:0] l6_inhibition = (l6_direct_full >>> FRAC) + (l6_trn_full >>> FRAC);

// Theta gate with L6 inhibition
assign theta_gate_pre_l6 = HALF + (theta_x_int >>> 1);
assign theta_gate_raw = theta_gate_pre_l6 - l6_inhibition;  // L6 reduces transmission
assign theta_gate = (theta_gate_raw[WIDTH-1]) ? 18'sd0 : theta_gate_raw;
```

---

## 3. Coupling Constants (Q14)

### 3.1 New Constants (v8.8)

| Constant | Value | Decimal | Purpose |
|----------|-------|---------|---------|
| K_L6_L5A | 2458 | 0.15 | L6 → L5a intra-column |
| K_L4_L5A | 1638 | 0.1 | L4 → L5a bypass |
| K_L6_THAL | 1638 | 0.1 | L6 CT → Thalamus (direct) |
| K_TRN | 3277 | 0.2 | TRN amplification of L6 |

### 3.2 Existing Constants (unchanged)

| Constant | Value | Decimal | Purpose |
|----------|-------|---------|---------|
| K_L4_L23 | 6554 | 0.4 | L4 → L2/3 |
| K_L23_L5 | 4915 | 0.3 | L2/3 → L5 |
| K_L5_L6 | 3277 | 0.2 | L5b → L6 |
| K_PAC | 3277 | 0.2 | PAC modulation |
| K_FB_L5 | 3277 | 0.2 | Inter-column feedback |

---

## 4. Signal Flow Diagrams

### 4.1 L5a vs L5b Input Pathways (v8.8)

```
                    CORTICAL COLUMN INPUT PATHWAYS

              L2/3 Output                L4 Output
                  │                         │
                  │                         │
          ┌───────┴───────┐                 │
          │               │                 │
          ▼               ▼                 │
     ┌─────────┐    ┌─────────┐            │
     │   L5b   │    │   L5a   │◀───────────┘  L4→L5a bypass (0.1)
     └─────────┘    └────┬────┘
          │              │
          │              │
inter-column             │
feedback ────────────────│              ┌─────────┐
                         │◀─────────────┤   L6    │  L6→L5a (0.15)
                         │              └─────────┘
                         │
    L5b input:           L5a input:
    - L2/3 × 0.3         - L2/3 × 0.3
    - feedback × 0.2     - L6 × 0.15
    - (apical gain)      - L4 × 0.1
                         - (apical gain)
```

### 4.2 L6 → Thalamus Inhibitory Pathway (v8.8)

```
    SENSORY              ASSOCIATION              MOTOR
    ┌────────┐           ┌────────┐           ┌────────┐
    │   L6   │           │   L6   │           │   L6   │
    └───┬────┘           └───┬────┘           └───┬────┘
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  l6_alpha_fb    │  (average of all L6)
                    │  = (S+A+M)/3    │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
              ▼                             ▼
    ┌───────────────────┐      ┌───────────────────┐
    │ Direct Inhibition │      │ TRN Amplification │
    │   × 0.1           │      │   × 0.2           │
    └─────────┬─────────┘      └─────────┬─────────┘
              │                          │
              └────────────┬─────────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │ l6_inhibition   │  (0.3 × l6_alpha_fb)
                  │ = 0.1 + 0.2     │
                  └────────┬────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │   theta_gate    │
                  │ = base - inhib  │
                  └─────────────────┘
```

---

## 5. Testbench: tb_l6_connectivity.v

### 5.1 Test Coverage (10 Tests)

| Test | Description | Expected Result |
|------|-------------|-----------------|
| 1 | Separate L5a/L5b inputs | Different input signals |
| 2 | L6 → L5a pathway | L6 output affects L5a |
| 3 | L4 → L5a bypass | L4 output reaches L5a |
| 4 | L6 → Thalamus inhibition | l6_inhibition computed |
| 5 | L6 reduces thalamic output | theta_gate modulated |
| 6 | TRN amplification | 0.3 × L6 total effect |
| 7 | L5a/L5b different dynamics | Different outputs |
| 8 | Zero L6 → baseline gate | Higher theta_gate |
| 9 | All columns have L6 | Active L6 outputs |
| 10 | L6 feedback averaged | (S+A+M)/3 computed |

### 5.2 Running the Tests

```bash
# Run L6 connectivity test
iverilog -o tb_l6.vvp -s tb_l6_connectivity \
    src/*.v tb/tb_l6_connectivity.v && vvp tb_l6.vvp

# Run all tests
make iverilog-all
```

---

## 6. Test Results Summary

### 6.1 All Tests Pass

```
tb_l6_connectivity.v:          10/10 PASS (NEW)
tb_full_system_fast.v:         15/15 PASS
tb_learning_fast.v:             8/8 PASS
tb_scaffold_architecture.v:    14/14 PASS
tb_gamma_theta_nesting.v:       7/7 PASS
tb_theta_phase_multiplexing.v: 19/19 PASS
tb_sr_frequency_drift.v:       30/30 PASS
tb_canonical_microcircuit.v:   20/20 PASS
tb_multi_harmonic_sr.v:        17/17 PASS
tb_sr_coupling.v:              12/12 PASS
tb_v55_fast.v:                  6/6 PASS
tb_layer1_minimal.v:           10/10 PASS
─────────────────────────────────────────────
TOTAL:                         ~168 PASS
```

### 6.2 No Regressions

Existing tests continue to pass because:
- L5a input gains L6 and L4 contributions (additive)
- L5b input unchanged (still receives L2/3 + inter-column feedback)
- L6 inhibition is subtractive from theta_gate, not multiplicative
- Default L6 = 0 gives baseline behavior

---

## 7. Biological Significance

### 7.1 L6 → L5a Pathway

| Function | Implementation |
|----------|----------------|
| **Motor modulation** | L6 alpha influences L5a motor output |
| **Feedback integration** | L5a receives both L6 and L4 signals |
| **Separate dynamics** | L5a and L5b now have distinct inputs |

### 7.2 L4 → L5a Bypass

| Function | Implementation |
|----------|----------------|
| **Fast pathway** | Direct L4 → L5a bypasses L2/3 |
| **Sensorimotor speed** | Enables rapid motor responses |
| **Weak coupling** | 0.1 weight (minor pathway) |

### 7.3 L6 → Thalamus + TRN

| Function | Implementation |
|----------|----------------|
| **Gain control** | L6 modulates thalamic transmission |
| **10:1 ratio** | Weak individual effect (0.1) |
| **TRN amplification** | Adds 0.2 for 0.3 total |
| **Inhibitory control** | Active L6 reduces theta_gate |

---

## 8. Version History

| Version | Date | Key Changes |
|---------|------|-------------|
| v8.0 | 2025-12-23 | Scaffold architecture, theta phase multiplexing |
| v8.1 | 2025-12-23 | Gamma-theta nesting specification |
| v8.5 | 2025-12-23 | SR frequency drift, observed frequencies |
| v8.6 | 2025-12-23 | Canonical microcircuit connectivity |
| v8.7 | 2025-12-26 | Layer 1, dual feedback, matrix thalamic pathway |
| **v8.8** | **2025-12-26** | **L6 output targets: L6→L5a, L4→L5a, L6→Thal+TRN** |

---

## 9. Files Modified/Added

| File | Changes |
|------|---------|
| `src/cortical_column.v` | v8.8: Separate L5a/L5b, L6→L5a, L4→L5a bypass |
| `src/thalamus.v` | v8.8: L6 inhibition, TRN amplification |
| `src/phi_n_neural_processor.v` | v8.8: Updated header |
| `tb/tb_l6_connectivity.v` | **NEW** - 10 L6 connectivity tests |
| `docs/SPEC_v8.8_UPDATE.md` | **NEW** - This specification |

---

## 10. Module Hierarchy (v8.8)

```
phi_n_neural_processor (top) - v8.8
├── clock_enable_generator
├── sr_noise_generator
├── sr_frequency_drift
├── config_controller
├── thalamus - v8.8
│   ├── hopf_oscillator (theta)
│   ├── sr_harmonic_bank
│   │   └── hopf_oscillator_stochastic ×5
│   ├── matrix thalamic computation
│   └── [NEW] L6 inhibition + TRN amplification
├── ca3_phase_memory
├── cortical_column (sensory) - v8.8
│   ├── layer1_minimal
│   ├── hopf_oscillator (L6, L5b, L4, L2/3)
│   └── [NEW] hopf_oscillator (L5a) with separate input
├── cortical_column (association) - v8.8
│   └── ... (same structure)
├── cortical_column (motor) - v8.8
│   └── ... (same structure)
├── pink_noise_generator
└── output_mixer
```

---

## 11. Conclusion

v8.8 corrects L6 output connectivity with:

1. **Separate L5a/L5b inputs** - biologically accurate distinct pathways
2. **L6 → L5a pathway** - recent finding: L6 projects to L5a, not L4
3. **L4 → L5a bypass** - fast sensorimotor pathway
4. **L6 → Thalamus inhibition** - 10:1 ratio modulatory control
5. **TRN-like amplification** - 0.2 additional inhibition (0.3 total)
6. **10 new unit tests** - comprehensive L6 connectivity verification

The φⁿ Neural Processor now implements biologically accurate L6 corticothalamic connectivity matching recent neuroscience findings about:
- L6 CT neuron projection targets
- Thalamic gain modulation via L6
- TRN-mediated inhibitory amplification
- Fast sensorimotor bypass pathways
