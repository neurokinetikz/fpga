# SPEC v11.3 UPDATE: SIE Dynamics & Population Metrics

## Summary

Version 11.3 implements comprehensive SIE (Schumann Ignition Event) dynamics monitoring and control through five new modules. These provide real-time population synchronization metrics, boundary frequency generation, mode switching, and harmonic ratio tracking.

**Key Changes:**
1. **Kuramoto Order Parameter** - Population-level synchronization metric R
2. **Boundary Generators** - Nonlinear mixing creates boundary frequencies
3. **Bicoherence Monitor** - Detects nonlinear three-frequency interactions
4. **Coupling Mode Controller** - Switches modulatory ↔ harmonic coupling
5. **Harmonic Spacing Index** - Monitors φⁿ ratio adherence
6. **Spectral Differentiation** - Enhanced MEDITATION state distinction

**Backward Compatibility:** Full - new modules are monitoring/control additions.

---

## 1. Motivation: Closing the SIE Analysis Gap

### 1.1 The Problem

The v11.2 system implemented φⁿ energy landscapes and force-based frequency control, but lacked runtime observables for SIE dynamics:

| Empirical Metric | v11.2 Status | Impact |
|------------------|--------------|--------|
| Population synchronization | Not computed | Can't detect ignition onset |
| Boundary frequencies | Not generated | Missing transition signatures |
| Coupling mode | Fixed PAC | Can't distinguish modulatory/harmonic |
| Bicoherence | Not measured | Can't verify nonlinear coupling |
| Harmonic tightening | Not tracked | Can't monitor φⁿ convergence |

### 1.2 The Solution

Five interconnected modules provide complete SIE observability:

```
                    ┌─────────────────────┐
                    │  Kuramoto R         │ ← Population sync metric
                    │  (6 oscillators)    │
                    └────────┬────────────┘
                             │
    ┌────────────────────────┼────────────────────────┐
    │                        │                        │
    ▼                        ▼                        ▼
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│ Boundary    │      │ Bicoherence │      │ Harmonic    │
│ Generators  │      │ Monitor     │      │ Spacing     │
│ (3 pairs)   │      │ (θ/α/bound) │      │ Index       │
└──────┬──────┘      └──────┬──────┘      └──────┬──────┘
       │                    │                    │
       └────────────────────┼────────────────────┘
                            │
                            ▼
                    ┌─────────────────────┐
                    │ Coupling Mode       │
                    │ Controller          │
                    │ (modulatory/harmonic)│
                    └─────────────────────┘
```

---

## 2. New Modules

### 2.1 Kuramoto Order Parameter (kuramoto_order_parameter.v)

**Purpose:** Computes population-level synchronization across 6 key oscillators.

**Algorithm:**
```
R = |1/N × Σ exp(i×θ_k)| = sqrt(sum_cos² + sum_sin²) / N

Where:
- θ_k = atan2(y_k, x_k) for each oscillator
- N = 6 oscillators (theta, alpha, beta1, beta2, gamma, SR_f0)
```

**Implementation:**
```verilog
module kuramoto_order_parameter #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter N_OSC = 6
)(
    input  wire clk, rst, clk_en,
    // Oscillator (x, y) coordinates
    input  wire signed [WIDTH-1:0] theta_x, theta_y,
    input  wire signed [WIDTH-1:0] alpha_x, alpha_y,
    input  wire signed [WIDTH-1:0] beta1_x, beta1_y,
    input  wire signed [WIDTH-1:0] beta2_x, beta2_y,
    input  wire signed [WIDTH-1:0] gamma_x, gamma_y,
    input  wire signed [WIDTH-1:0] sr_f0_x, sr_f0_y,
    // Outputs
    output reg signed [WIDTH-1:0] kuramoto_R,     // [0, 1.0] Q14
    output reg signed [WIDTH-1:0] mean_phase,     // Average phase
    output reg high_synchrony                     // R > 0.7 flag
);
```

**Key Features:**
- Single-cycle latency (v1.1 combinational rewrite)
- Amplitude-normalized phase vectors
- `high_synchrony` flag for threshold detection

**Expected Values:**
| Condition | Kuramoto R |
|-----------|-----------|
| Random phases | 0.2-0.4 |
| Partial sync | 0.5-0.7 |
| SIE ignition | 0.7-1.0 |
| Full phase lock | ~1.0 |

---

### 2.2 Boundary Generator (boundary_generator.v)

**Purpose:** Creates boundary frequencies via nonlinear mixing of adjacent attractor oscillators.

**Physics:**
```
f_boundary = sqrt(f_low × f_high)  (geometric mean)

Boundaries generated:
- θ/α: sqrt(5.89 × 9.53) = 7.49 Hz
- α/β₁: sqrt(9.53 × 15.42) = 12.12 Hz
- β₁/β₂: sqrt(15.42 × 24.94) = 19.60 Hz
```

**Implementation:**
```verilog
module boundary_generator #(
    parameter WIDTH = 18,
    parameter FRAC = 14
)(
    input  wire clk, rst, clk_en,
    input  wire signed [WIDTH-1:0] osc_low_x, osc_low_y,
    input  wire signed [WIDTH-1:0] osc_high_x, osc_high_y,
    input  wire signed [WIDTH-1:0] mixing_strength,
    output reg signed [WIDTH-1:0] boundary_x, boundary_y,
    output reg signed [WIDTH-1:0] boundary_amplitude
);
```

**Algorithm:**
1. Compute amplitudes: `amp = approx_sqrt(x² + y²)`
2. Geometric mean: `amp_geom = sqrt(amp_low × amp_high)`
3. Phase average via unit vector sum: `avg = (norm_low + norm_high) / 2`
4. Output: `boundary = mixing_strength × amp_geom × amp_alignment × direction`

**Key Insight:** Boundary amplitude scales with parent alignment - anti-phase parents produce weak boundaries.

---

### 2.3 Bicoherence Monitor (bicoherence_monitor.v)

**Purpose:** Detects nonlinear three-frequency interactions (f1, f2, f1+f2 triads).

**Standard Bicoherence:**
```
B(f1,f2) = |E[X(f1) × X(f2) × X*(f1+f2)]| / sqrt(P1 × P2 × P12)
```

**Hardware-Friendly Implementation:**
```verilog
module bicoherence_monitor #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter AVG_SHIFT = 6  // IIR α = 1/64
)(
    input  wire clk, rst, clk_en,
    input  wire signed [WIDTH-1:0] osc1_x, osc1_y,    // f1
    input  wire signed [WIDTH-1:0] osc2_x, osc2_y,    // f2
    input  wire signed [WIDTH-1:0] osc12_x, osc12_y,  // f1+f2 (boundary)
    output reg signed [WIDTH-1:0] bicoherence,        // [0, 1.0] Q14
    output reg high_bicoherence                       // > 0.5 flag
);
```

**Algorithm:**
1. Normalize oscillators to unit phasors: `cos_k = x_k/|z_k|`, `sin_k = y_k/|z_k|`
2. Compute bispectral phase product: `exp(i×θ1) × exp(i×θ2) × exp(-i×θ12)`
3. Bicoherence = |bispectrum| with IIR temporal averaging

**Interpretation:**
| Bicoherence | Meaning |
|-------------|---------|
| < 0.3 | Random/uncoupled |
| 0.3-0.5 | Weak coupling |
| 0.5-0.7 | Moderate coupling |
| > 0.7 | Strong nonlinear coupling |

---

### 2.4 Coupling Mode Controller (coupling_mode_controller.v)

**Purpose:** Dynamically switches between modulatory (PAC) and harmonic coupling regimes.

**Modes:**
```
MODULATORY (baseline):
  - Gamma amplitude modulated by theta phase (high PAC)
  - pac_gain = 1.0, harmonic_gain = 0.125

HARMONIC (ignition):
  - Gamma phase-locked to theta at integer ratio
  - pac_gain = 0.125, harmonic_gain = 1.0

TRANSITION:
  - Gradual crossfade (~500ms)
  - pac_gain = 0.5, harmonic_gain = 0.5
```

**State Machine:**
```verilog
module coupling_mode_controller #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter TRANSITION_CYCLES = 2000  // ~500ms at 4 kHz
)(
    input  wire clk, rst, clk_en,
    input  wire signed [WIDTH-1:0] kuramoto_R,
    input  wire signed [WIDTH-1:0] boundary_power,
    input  wire [2:0] sie_phase,
    input  wire signed [WIDTH-1:0] r_high_thresh,     // Default: 0.7
    input  wire signed [WIDTH-1:0] r_low_thresh,      // Default: 0.5
    input  wire signed [WIDTH-1:0] boundary_thresh,   // Default: 0.5
    output reg [1:0] coupling_mode,                   // 00/01/10
    output reg signed [WIDTH-1:0] pac_gain,
    output reg signed [WIDTH-1:0] harmonic_gain,
    output reg mode_transition_active
);
```

**Transition Rules:**
- MODULATORY → HARMONIC: `kuramoto_R > 0.7 AND boundary_power > thresh` OR `sie_active`
- HARMONIC → MODULATORY: `kuramoto_R < 0.5 OR sie_decay_phase` AND `!sie_active`

---

### 2.5 Harmonic Spacing Index (harmonic_spacing_index.v)

**Purpose:** Monitors deviation from ideal φⁿ frequency ratios.

**Algorithm:**
```
Ratios monitored:
- r1 = omega_alpha / omega_theta     (ideal: φ = 1.618)
- r2 = omega_beta1 / omega_alpha     (ideal: φ = 1.618)
- r3 = omega_beta2 / omega_beta1     (ideal: φ = 1.618)
- r4 = omega_gamma / omega_beta2     (ideal: φ = 1.618)

Deviation = |ratio - φ|
HSI = 1.0 - clamp(mean_deviation / 0.5, 0, 1)
ΔHSI = HSI - baseline (EMA)
```

**Implementation:**
```verilog
module harmonic_spacing_index #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter AVG_SHIFT = 8  // ~64s baseline time constant
)(
    input  wire clk, rst, clk_en,
    input  wire signed [WIDTH-1:0] omega_theta,
    input  wire signed [WIDTH-1:0] omega_alpha,
    input  wire signed [WIDTH-1:0] omega_beta1,
    input  wire signed [WIDTH-1:0] omega_beta2,
    input  wire signed [WIDTH-1:0] omega_gamma,
    output reg signed [WIDTH-1:0] hsi,           // [0, 1.0] Q14
    output reg signed [WIDTH-1:0] delta_hsi,     // HSI - baseline
    output reg harmonic_locked                   // All within 8% of φ
);
```

**Interpretation:**
| ΔHSI | Meaning |
|------|---------|
| > +0.05 | System tightening toward φⁿ attractors |
| ±0.02 | Stable baseline |
| < -0.05 | System loosening from ideal ratios |

---

## 3. Config Controller Changes

### 3.1 Enhanced MEDITATION Spectral Differentiation

**Problem:** NORMAL and MEDITATION states were spectrally similar (all MU=3-4).

**Solution:** MEDITATION now uses enhanced theta/alpha with suppressed beta/gamma:

```verilog
// v11.2 MEDITATION
mu_dt_theta  <= MU_FULL;       // 4
mu_dt_l6     <= MU_FULL;       // 4 (alpha)
mu_dt_l5b    <= MU_HALF;       // 2 (high beta)
mu_dt_l5a    <= MU_HALF;       // 2 (low beta)
mu_dt_l4     <= MU_HALF;       // 2 (gamma)
mu_dt_l23    <= MU_HALF;       // 2 (gamma)

// v11.3 MEDITATION - Enhanced differentiation
mu_dt_theta  <= MU_ENHANCED;   // 6 - strong theta peak
mu_dt_l6     <= MU_ENHANCED;   // 6 - strong alpha peak
mu_dt_l5b    <= MU_WEAK;       // 1 - suppressed high beta
mu_dt_l5a    <= MU_WEAK;       // 1 - suppressed low beta
mu_dt_l4     <= MU_WEAK;       // 1 - sensory withdrawal
mu_dt_l23    <= MU_HALF;       // 2 - moderate gamma
```

**Spectral Impact:**
| Band | NORMAL (v11.3) | MEDITATION (v11.3) | Difference |
|------|----------------|--------------------| -----------|
| Theta (5.89 Hz) | MU=3 (amp≈1.73) | MU=6 (amp≈2.45) | +3 dB |
| Alpha (9.53 Hz) | MU=3 (amp≈1.73) | MU=6 (amp≈2.45) | +3 dB |
| Beta (15-25 Hz) | MU=3 (amp≈1.73) | MU=1 (amp=1.0) | -5 dB |
| Gamma (40 Hz) | MU=3 (amp≈1.73) | MU=2 (amp≈1.41) | -2 dB |

---

## 4. Integration in phi_n_neural_processor.v

### 4.1 Module Instantiations

All new modules are instantiated in `phi_n_neural_processor.v` with appropriate signal routing:

```verilog
// Kuramoto Order Parameter
kuramoto_order_parameter kuramoto_inst (
    .theta_x(thalamic_theta_x), .theta_y(thalamic_theta_y),
    .alpha_x(motor_l6_x), .alpha_y(motor_l6_y),
    .beta1_x(motor_l5a_x), .beta1_y(motor_l5a_y),
    .beta2_x(motor_l5b_x), .beta2_y(motor_l5b_y),
    .gamma_x(motor_l23_x), .gamma_y(motor_l23_y),
    .sr_f0_x(sr_f0_x), .sr_f0_y(sr_f0_y),
    .kuramoto_R(kuramoto_R),
    .high_synchrony(kuramoto_high_synchrony)
);

// Three Boundary Generators
boundary_generator boundary_theta_alpha (
    .osc_low_x(thalamic_theta_x), .osc_low_y(thalamic_theta_y),
    .osc_high_x(motor_l6_x), .osc_high_y(motor_l6_y),
    .boundary_amplitude(boundary_theta_alpha_amp)
);

boundary_generator boundary_alpha_beta1 (...);
boundary_generator boundary_beta1_beta2 (...);

// Total boundary power
wire signed [WIDTH-1:0] total_boundary_power =
    boundary_theta_alpha_amp + boundary_alpha_beta1_amp + boundary_beta1_beta2_amp;

// Bicoherence Monitor (θ + α → boundary)
bicoherence_monitor bicoherence_inst (
    .osc1_x(thalamic_theta_x), .osc1_y(thalamic_theta_y),
    .osc2_x(motor_l6_x), .osc2_y(motor_l6_y),
    .osc12_x(boundary_theta_alpha_x), .osc12_y(boundary_theta_alpha_y),
    .bicoherence(bicoherence_theta_alpha),
    .high_bicoherence(high_bicoherence)
);

// Coupling Mode Controller
coupling_mode_controller coupling_ctrl (
    .kuramoto_R(kuramoto_R),
    .boundary_power(total_boundary_power),
    .sie_phase(sie_ignition_phase),
    .coupling_mode(coupling_mode),
    .pac_gain(pac_gain),
    .harmonic_gain(harmonic_gain)
);

// Harmonic Spacing Index
harmonic_spacing_index hsi_inst (
    .omega_theta(OMEGA_DT_THETA),
    .omega_alpha(OMEGA_DT_ALPHA),
    .omega_beta1(OMEGA_DT_BETA_LOW),
    .omega_beta2(OMEGA_DT_BETA_HIGH),
    .omega_gamma(OMEGA_DT_GAMMA_FAST),
    .hsi(hsi_value),
    .delta_hsi(hsi_delta),
    .harmonic_locked(hsi_locked)
);
```

---

## 5. Resource Impact

| Module | LUTs | FFs | DSPs |
|--------|------|-----|------|
| kuramoto_order_parameter | ~150 | ~60 | 0 |
| boundary_generator (×3) | ~300 | ~60 | 0 |
| bicoherence_monitor | ~200 | ~40 | 0 |
| coupling_mode_controller | ~80 | ~50 | 0 |
| harmonic_spacing_index | ~100 | ~60 | 0 |
| **Total v11.3 additions** | **~830** | **~270** | **0** |

**Cumulative System (v11.3):**
| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| LUTs | ~6,030 | 53,200 | 11.3% |
| FFs | ~3,070 | 106,400 | 2.9% |
| DSPs | ~8 | 220 | 3.6% |

---

## 6. Verification

### 6.1 New Testbenches

| Testbench | Tests | Status |
|-----------|-------|--------|
| tb_kuramoto_order.v | 7 | PASS |
| tb_boundary_generator.v | 7 | PASS |
| tb_bicoherence_monitor.v | 6 | PASS |
| tb_coupling_mode_controller.v | 8 | PASS |
| tb_harmonic_spacing_index.v | 8 | PASS |

### 6.2 Integration Tests

| Test | Result |
|------|--------|
| tb_full_system_fast | 15/15 PASS |
| tb_gamma_theta_nesting | 7/7 PASS |
| tb_learning_fast | 8/8 PASS |
| tb_coupling_susceptibility | 20/20 PASS |
| tb_energy_landscape | 24/24 PASS |

---

## 7. SIE Dynamics Observable Signatures

### 7.1 Baseline (Modulatory Mode)

```
Kuramoto R: 0.3-0.5 (desynchronized)
Boundary Power: Low (<0.3)
Bicoherence: Low (<0.3)
Coupling Mode: MODULATORY
PAC: High (1.0)
HSI: ~1.0 (stable φⁿ ratios)
```

### 7.2 SIE Ignition (Harmonic Mode)

```
Kuramoto R: 0.7-1.0 (synchronized)
Boundary Power: High (>0.5)
Bicoherence: High (>0.5)
Coupling Mode: HARMONIC
PAC: Low (0.125)
ΔHSI: Positive (tightening)
```

### 7.3 State Transition Timeline

```
t=0s:     Baseline (modulatory)
t=3-4s:   Coherence-first (R rises, PAC still high)
t=4-6s:   Ignition (boundary power spike, mode transition)
t=6-8s:   Plateau (harmonic mode, high bicoherence)
t=8-17s:  Propagation (sustained synchronization)
t=17-21s: Decay (R falls, return to modulatory)
t=21-31s: Refractory (reduced excitability)
```

---

## 8. Version History

| Version | Date | Change |
|---------|------|--------|
| v11.3 | 2025-12-28 | SIE Dynamics (Kuramoto, boundaries, bicoherence, mode controller, HSI) |
| v11.2 | 2025-12-28 | DAC anti-clipping (MU_MODERATE, soft limiter) |
| v11.1 | 2025-12-28 | Unified Boundary-Attractor Framework |
| v11.0 | 2025-12-28 | Active φⁿ Dynamics |

---

## 9. Files Modified/Created

### 9.1 New Files

| File | Purpose |
|------|---------|
| `src/kuramoto_order_parameter.v` | Population synchronization |
| `src/boundary_generator.v` | Nonlinear boundary mixing |
| `src/bicoherence_monitor.v` | Three-frequency coupling |
| `src/coupling_mode_controller.v` | Mode switching |
| `src/harmonic_spacing_index.v` | φⁿ ratio tracking |
| `tb/tb_kuramoto_order.v` | Kuramoto testbench |
| `tb/tb_boundary_generator.v` | Boundary testbench |
| `tb/tb_bicoherence_monitor.v` | Bicoherence testbench |
| `tb/tb_coupling_mode_controller.v` | Mode controller testbench |
| `tb/tb_harmonic_spacing_index.v` | HSI testbench |

### 9.2 Modified Files

| File | Change |
|------|--------|
| `src/phi_n_neural_processor.v` | Instantiate all new modules |
| `src/config_controller.v` | Enhanced MEDITATION spectral differentiation |
| `src/cortical_column.v` | Added l5a_y, l5b_y outputs for Kuramoto |
| `tb/tb_full_system_fast.v` | Updated Test 7 for new MEDITATION values |

---

## 10. References

- v11.2 DAC Anti-Clipping: `docs/SPEC_v11.2_UPDATE.md`
- v11.1 Unified Boundary-Attractor Framework: `docs/SPEC_v11.1_UPDATE.md`
- v11.0 Active φⁿ Dynamics: `docs/SPEC_v11.0_UPDATE.md`
- Base Architecture v8.0: `docs/FPGA_SPECIFICATION_V8.md`
