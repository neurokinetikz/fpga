# φⁿ Neural Processor Specification Update: v8.3 → v8.4

**Version**: 8.4
**Date**: 2025-12-23
**Status**: Implemented and Verified

---

## Overview

v8.4 completes the v8.x feature set with **gamma-theta phase-amplitude coupling (PAC)** implementation and **comprehensive integration testing**. This update ensures all v8.x features (theta phase multiplexing, scaffold architecture, gamma-theta nesting) work together correctly, not just in isolation.

**Key Achievements:**
- Implemented gamma-theta nesting in cortical columns (L2/3 frequency switching)
- Added 7-test dedicated gamma-theta nesting testbench
- Enhanced tb_full_system_fast.v with 5 integration tests (v6.5)
- Total test count: 121+ tests across 14 active testbenches
- All features verified working together across consciousness states

---

## 1. New Feature: Gamma-Theta Nesting (v8.1 Implementation)

### 1.1 Biological Basis

Gamma-theta phase-amplitude coupling (PAC) is a well-established neural mechanism where:
- **Encoding** (theta peak, phases 0-3): Fast gamma (~65 Hz) supports sensory binding
- **Retrieval** (theta trough, phases 4-7): Slow gamma (~40 Hz) supports memory recall

The frequency ratio is exactly φ (golden ratio):
```
fast_gamma / slow_gamma = 65.3 / 40.36 = 1.618 ≈ φ
```

### 1.2 Implementation in `cortical_column.v`

**New Input:**
```verilog
input wire encoding_window,  // v8.1: From theta phase (1=encoding, 0=retrieval)
```

**Gamma Frequency Parameters:**
```verilog
// v8.1: Gamma-theta nesting - L2/3 frequency switches based on theta phase
// Fast gamma (65.3 Hz, phi^4.5) during encoding, slow gamma (40.36 Hz, phi^3.5) during retrieval
localparam signed [WIDTH-1:0] OMEGA_DT_L23_FAST = 18'sd1681;  // 65.3 Hz (phi^4.5)
localparam signed [WIDTH-1:0] OMEGA_DT_L23_SLOW = 18'sd1039;  // 40.36 Hz (phi^3.5)
```

**Dynamic Frequency Selection:**
```verilog
// v8.1: Select L2/3 gamma frequency based on encoding window
wire signed [WIDTH-1:0] omega_dt_l23_active;
assign omega_dt_l23_active = encoding_window ? OMEGA_DT_L23_FAST : OMEGA_DT_L23_SLOW;
```

**L2/3 Oscillator Uses Active Frequency:**
```verilog
hopf_oscillator #(.WIDTH(WIDTH), .FRAC(FRAC)) l23_osc (
    .clk(clk), .rst(rst), .clk_en(clk_en),
    .mu_dt(mu_dt_l23),
    .omega_dt(omega_dt_l23_active),  // v8.1: Dynamic frequency
    .input_x(l23_input),
    .x(l23_x_int), .y(l23_y_int), .amplitude(l23_amp_int)
);
```

### 1.3 Signal Routing in `phi_n_neural_processor.v`

The encoding_window signal is routed from thalamus to all three cortical columns:

```verilog
cortical_column col_sensory (
    // ...
    .encoding_window(ca3_encoding_window),  // v8.1: gamma-theta nesting
    // ...
);

cortical_column col_association (
    // ...
    .encoding_window(ca3_encoding_window),  // v8.1: gamma-theta nesting
    // ...
);

cortical_column col_motor (
    // ...
    .encoding_window(ca3_encoding_window),  // v8.1: gamma-theta nesting
    // ...
);
```

---

## 2. New Testbench: `tb_gamma_theta_nesting.v`

### 2.1 Test Coverage (7 Tests)

| Test | Description | Verification |
|------|-------------|--------------|
| 1 | OMEGA_DT switching | Fast (1681) during encoding, slow (1039) during retrieval |
| 2 | Gamma period measurement | Both fast and slow modes active |
| 3 | OMEGA_DT ratio | Ratio = 1.618 (φ) |
| 4 | Encoding/OMEGA_DT sync | Perfect synchronization verified |
| 5 | Smooth transitions | No amplitude discontinuities at phase boundaries |
| 6 | State independence (MEDITATION) | Gamma switching works |
| 7 | State independence (PSYCHEDELIC) | Gamma switching works |

### 2.2 Key Assertions

```verilog
// TEST 1: Verify OMEGA_DT switches correctly
if (encoding_window && omega_dt_active == 18'sd1681) encoding_omega_seen = 1;
if (!encoding_window && omega_dt_active == 18'sd1039) retrieval_omega_seen = 1;

// TEST 3: Verify frequency ratio is phi
omega_ratio = 1681.0 / 1039.0;  // = 1.618

// TEST 4: Verify synchronization
if (encoding_window && omega_dt_active == 18'sd1681) synced_fast++;
else if (!encoding_window && omega_dt_active == 18'sd1039) synced_slow++;
else mismatched++;
// Result: mismatched == 0
```

---

## 3. Enhanced Integration Testing: `tb_full_system_fast.v` v6.5

### 3.1 New Signal Access

```verilog
// v6.5: Integration test signals - gamma-theta nesting
wire signed [WIDTH-1:0] omega_dt_active = dut.col_sensory.omega_dt_l23_active;

// v6.5: Integration test signals - scaffold/plastic layer access
wire signed [WIDTH-1:0] sensory_l4_x = dut.col_sensory.l4_x;
wire signed [WIDTH-1:0] sensory_l5b_x = dut.col_sensory.l5b_x;
```

### 3.2 New Integration Tests (TEST 11-15)

| Test | Feature Chain | Verification |
|------|---------------|--------------|
| 11 | Gamma-Theta Nesting Integration | theta_phase → encoding_window → omega_dt → L2/3 output |
| 12 | Learning-Plastic Layer Integration | CA3 learning → phase_couple → L2/3/L6 modulation |
| 13 | Scaffold Stability During Learning | L4/L5b stable while L2/3/L6 respond |
| 14 | Full Feature Chain (End-to-End) | Complete pathway with all features |
| 15 | State-Dependent Integration | All features work across NORMAL, MEDITATION, PSYCHEDELIC, FLOW |

### 3.3 TEST 11: Gamma-Theta Nesting Integration

```verilog
// Track omega_dt values and synchronization
if (omega_dt_active == 18'sd1681) fast_gamma_count++;
if (omega_dt_active == 18'sd1039) slow_gamma_count++;

// Track synchronization
if (encoding_window && omega_dt_active == 18'sd1681)
    omega_sync_encoding++;
else if (!encoding_window && omega_dt_active == 18'sd1039)
    omega_sync_retrieval++;
else
    omega_mismatch++;

// PASS criteria: Both modes active, zero mismatch
```

### 3.4 TEST 13: Scaffold Stability During Learning

```verilog
// Compute variance proxy for each layer
l4_var = (1.0 * l4_sum_sq) / sample_count;    // Scaffold
l5b_var = (1.0 * l5b_sum_sq) / sample_count;  // Scaffold
l23_var = (1.0 * l23_sum_sq) / sample_count;  // Plastic
l6_var = (1.0 * l6_sum_sq) / sample_count;    // Plastic

// Verify all layers active, scaffold/plastic differentiation present
```

### 3.5 TEST 14: Full Feature Chain

```verilog
// Phase 1: Encoding
// Verify: encoding_window=1 → fast gamma (1681) → CA3 learning → phase coupling

// Phase 2: Retrieval
// Verify: encoding_window=0 → slow gamma (1039) → scaffold stable

// PASS: All chain elements verified
```

### 3.6 TEST 15: State-Dependent Integration

```verilog
// For each state (NORMAL, MEDITATION, PSYCHEDELIC, FLOW):
//   1. Verify gamma switching (encoding→fast, retrieval→slow)
//   2. Verify theta phase cycling
//   3. Verify scaffold layers active

// PASS: All features work across all states
```

---

## 4. Updated Makefile

### 4.1 New Targets

```makefile
# v8.3: Theta phase multiplexing test
.PHONY: iverilog-theta
iverilog-theta: $(SIM_DIR)/tb_theta_phase_multiplexing.vvp
	@echo "Running theta phase multiplexing test (v8.3)..."
	cd $(SIM_DIR) && vvp tb_theta_phase_multiplexing.vvp

# v8.3: Scaffold architecture test
.PHONY: iverilog-scaffold
iverilog-scaffold: $(SIM_DIR)/tb_scaffold_architecture.vvp
	@echo "Running scaffold architecture test (v8.3)..."
	cd $(SIM_DIR) && vvp tb_scaffold_architecture.vvp

# Run all iverilog tests
.PHONY: iverilog-all
iverilog-all: iverilog-hopf iverilog-fast iverilog-full iverilog-theta iverilog-scaffold
```

---

## 5. Test Results Summary

### 5.1 All Tests Pass

```
tb_full_system_fast.v:     15/15 PASS (v6.5 with integration tests)
tb_theta_phase_multiplexing.v: 19/19 PASS
tb_scaffold_architecture.v:    14/14 PASS
tb_gamma_theta_nesting.v:       7/7 PASS
tb_learning_fast.v:             8/8 PASS
tb_multi_harmonic_sr.v:        17/17 PASS
tb_state_transitions.v:        12/12 PASS
tb_hopf_oscillator.v:           5/5 PASS
tb_v55_fast.v:                  6/6 PASS
```

### 5.2 Feature Coverage Matrix

| Feature | Dedicated TB | Integration TB | Status |
|---------|--------------|----------------|--------|
| Theta Phase Multiplexing | tb_theta_phase_multiplexing | tb_full_system_fast TEST 9-10 | ✅ |
| Scaffold Architecture | tb_scaffold_architecture | tb_full_system_fast TEST 13 | ✅ |
| Gamma-Theta Nesting | tb_gamma_theta_nesting | tb_full_system_fast TEST 11 | ✅ |
| Cross-Feature Integration | - | tb_full_system_fast TEST 14-15 | ✅ |

---

## 6. φⁿ Frequency Architecture (Complete)

### 6.1 All 21 Oscillators

| Location | Frequency | φⁿ | Layer Type | Notes |
|----------|-----------|-----|------------|-------|
| Thalamus Theta | 5.89 Hz | φ⁻⁰·⁵ | - | Learn/recall gating |
| SR f₀ | 7.49 Hz | φ⁰ | - | Schumann fundamental |
| SR f₁ | 12.12 Hz | φ¹ | - | Alpha band |
| SR f₂ | 19.60 Hz | φ² | - | Low beta |
| SR f₃ | 31.73 Hz | φ³ | - | High beta |
| SR f₄ | 51.33 Hz | φ⁴ | - | Low gamma |
| L6 ×3 | 9.53 Hz | φ⁰·⁵ | Plastic | Alpha, gain control |
| L5a ×3 | 15.42 Hz | φ¹·⁵ | Intermediate | Low beta, motor |
| L5b ×3 | 24.94 Hz | φ²·⁵ | Scaffold | High beta, feedback |
| L4 ×3 | 31.73 Hz | φ³ | Scaffold | Thalamocortical |
| L2/3 ×3 | 40.36/65.3 Hz | φ³·⁵/φ⁴·⁵ | Plastic | Gamma, dynamic |

### 6.2 Gamma-Theta Nesting Frequencies

```
Encoding (theta phases 0-3):  L2/3 = 65.3 Hz (φ⁴·⁵)
Retrieval (theta phases 4-7): L2/3 = 40.36 Hz (φ³·⁵)
Ratio: 65.3 / 40.36 = 1.618 = φ
```

---

## 7. Version History

| Version | Date | Key Changes |
|---------|------|-------------|
| v8.0 | 2025-12-23 | Scaffold architecture, theta phase multiplexing |
| v8.1 | 2025-12-23 | Gamma-theta nesting specification |
| v8.2 | 2025-12-23 | DC offset analysis |
| v8.3 | 2025-12-23 | DC removal IIR filter fix |
| **v8.4** | **2025-12-23** | **Gamma-theta implementation, integration testing** |

---

## 8. Files Modified

| File | Changes |
|------|---------|
| `src/cortical_column.v` | Added encoding_window input, omega_dt switching |
| `src/phi_n_neural_processor.v` | Routed encoding_window to all columns |
| `tb/tb_gamma_theta_nesting.v` | New testbench (7 tests) |
| `tb/tb_full_system_fast.v` | v6.5 with 5 integration tests |
| `tb/tb_learning_fast.v` | v2.1 with encoding_window usage |
| `Makefile` | Added iverilog-theta, iverilog-scaffold targets |

---

## 9. Running the Tests

```bash
# Run all tests
make iverilog-all

# Run specific v8.x tests
make iverilog-theta     # Theta phase multiplexing (19 tests)
make iverilog-scaffold  # Scaffold architecture (14 tests)

# Run integration tests
iverilog -o sim/tb_full.vvp -s tb_full_system_fast \
    src/*.v tb/tb_full_system_fast.v && vvp sim/tb_full.vvp

# Run gamma-theta nesting tests
iverilog -o sim/tb_gamma.vvp -s tb_gamma_theta_nesting \
    src/*.v tb/tb_gamma_theta_nesting.v && vvp sim/tb_gamma.vvp
```

---

## 10. Conclusion

v8.4 completes the v8.x feature implementation with:

1. **Gamma-theta nesting** fully implemented and tested
2. **Integration testing** verifying all features work together
3. **121+ tests** providing comprehensive coverage
4. **All consciousness states** verified with full feature support

The φⁿ Neural Processor now implements a complete biologically-realistic neural architecture with:
- Theta-gated encoding/retrieval (8-phase multiplexing)
- Scaffold/plastic layer differentiation (Dupret et al. 2025)
- Gamma-theta phase-amplitude coupling (PAC)
- 5-harmonic Schumann resonance bank with stochastic resonance
- 5 consciousness states with distinct oscillator configurations
