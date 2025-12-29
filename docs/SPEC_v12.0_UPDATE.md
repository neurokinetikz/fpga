# SPEC v12.0 UPDATE: Unified State Dynamics

## Summary

Version 12.0 consolidates v11.4 (State Transition Interpolation) and v11.5 (Distributed SIE Boost) into a unified architecture for smooth consciousness state dynamics and biologically-accurate SIE modeling.

**Key Changes:**
1. **State Transition Interpolation** (v11.4) - Smooth linear interpolation between consciousness states
2. **Distributed SIE Architecture** (v11.5) - Option C distributed boost prevents stacking artifacts
3. **Parameterized Envelope Bounds** (v11.4) - Per-oscillator amplitude envelope customization
4. **MU-Based Amplitude Scaling** (v11.4) - State-dependent layer output amplitudes
5. **State-Driven Coupling Mode** (v1.1) - MEDITATION forces HARMONIC coupling automatically

**Backward Compatibility:** Full - `transition_duration=0` preserves instant state changes.

---

## 1. Motivation: Unifying State Dynamics

### 1.1 The Problems

**Problem 1: Abrupt State Transitions**
- v11.3 state changes were instantaneous (step functions)
- Created spectral discontinuities visible in spectrograms
- Biologically unrealistic: real consciousness states transition over seconds

**Problem 2: SIE Boost Stacking**
- Multiple cascade stages each applied multiplicative gains:
  - Signal-level: `sie_theta_boost` × `sie_alpha_boost` (2× each)
  - Mixer: `sie_boost` (up to 2×)
  - Thalamus enhancement: (up to 4-5×)
- Total potential: 16× (12+ dB) - far exceeding DAC headroom
- Caused hard clipping and distorted SIE signatures

### 1.2 The Solution

**Unified State Dynamics** addresses both problems:

```
┌─────────────────────────────────────────────────────────────┐
│                    STATE TRANSITION SYSTEM                  │
│                                                             │
│   state_select ────┬──► config_controller ──┬──► MU values  │
│                    │    (v11.4 lerp)        │    (smooth)   │
│   transition_      │                        │               │
│   duration    ─────┘                        ├──► Ca²⁺ thresh│
│                                             │               │
│                                             └──► SIE timing │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                  DISTRIBUTED SIE ARCHITECTURE               │
│                                                             │
│   ┌───────────┐   ┌───────────┐   ┌───────────┐            │
│   │  Mixer    │ + │ Thalamus  │ + │ Thalamus  │ = 6.8 dB   │
│   │  +2.9 dB  │   │ f₀ +2.3dB │   │ f₁ +1.6dB │            │
│   │ (1.0-1.4×)│   │ (1.3×)    │   │ (1.2×)    │            │
│   └───────────┘   └───────────┘   └───────────┘            │
│                                                             │
│   Signal-level boosts: DISABLED (constant 1.0×)            │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. State Transition Interpolation System (v11.4)

### 2.1 config_controller Changes

**New Inputs/Outputs:**

```verilog
module config_controller #(
    parameter WIDTH = 18,
    parameter FRAC = 14
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,
    input  wire [2:0] state_select,

    // v11.4: Transition control - 0 = instant (backward compatible)
    input  wire [15:0] transition_duration,

    // Existing MU outputs (now interpolated)
    output reg signed [WIDTH-1:0] mu_dt_theta,
    output reg signed [WIDTH-1:0] mu_dt_l6,
    // ... other MU outputs ...

    // v11.4: Transition status outputs
    output reg        transitioning,           // High during active transition
    output reg [15:0] transition_progress,     // 0-65535 ramp position
    output reg [2:0]  transition_from,         // Source state
    output reg [2:0]  transition_to            // Target state
);
```

**Linear Interpolation Functions:**

```verilog
// lerp_signed: Returns start + (end - start) * t / duration
function signed [WIDTH-1:0] lerp_signed;
    input signed [WIDTH-1:0] start_val;
    input signed [WIDTH-1:0] end_val;
    input [15:0] t;
    input [15:0] duration;
    reg signed [WIDTH+16:0] delta;
    reg signed [WIDTH+16:0] scaled;
    reg signed [WIDTH+16:0] result;
    begin
        delta = end_val - start_val;
        scaled = delta * $signed({1'b0, t});
        result = start_val + scaled / $signed({1'b0, duration});
        lerp_signed = result[WIDTH-1:0];
    end
endfunction

// lerp_unsigned: Unsigned version for SIE timing parameters
function [15:0] lerp_unsigned;
    input [15:0] start_val;
    input [15:0] end_val;
    input [15:0] t;
    input [15:0] duration;
    // ... handles both increasing and decreasing transitions
endfunction
```

**Shadow Registers for Mid-Transition Restarts:**

When a new state is requested during an active transition, the system:
1. Captures current interpolated values as new start point
2. Resets ramp counter to zero
3. Continues interpolation toward new target

```verilog
// Shadow registers: start values for interpolation
reg signed [WIDTH-1:0] mu_start_theta, mu_start_l6, mu_start_l5b;
reg signed [WIDTH-1:0] mu_start_l5a, mu_start_l4, mu_start_l23;
reg signed [WIDTH-1:0] ca_thresh_start;
reg [15:0] sie_start_p2, sie_start_p3, sie_start_p4;
reg [15:0] sie_start_p5, sie_start_p6, sie_start_refr;

always @(posedge clk or posedge rst) begin
    if (state_changed) begin
        // NEW TRANSITION: Capture current values as start point
        mu_start_theta <= mu_dt_theta;
        mu_start_l6 <= mu_dt_l6;
        // ... capture all current values

        transition_from <= transition_to;  // From wherever we are
        transition_to <= state_select;
        transitioning <= 1'b1;
        ramp_counter <= 16'd0;
    end
end
```

### 2.2 Interpolated Parameters

| Parameter Type | Start Values | End Values | Interpolation |
|----------------|--------------|------------|---------------|
| MU values (6) | Current mu_dt_* | Target state MU | Signed lerp |
| Ca²⁺ threshold | Current ca_threshold | Target threshold | Signed lerp |
| SIE phase 2-6 durations | Current sie_phase*_dur | Target durations | Unsigned lerp |
| SIE refractory | Current sie_refractory | Target refractory | Unsigned lerp |

### 2.3 Transition Duration

```verilog
// Default: 80000 cycles = 20 seconds at 4 kHz
parameter [15:0] TRANSITION_DURATION_DEFAULT = 16'd80000;

// Backward compatibility: duration=0 means instant (1 cycle)
wire [15:0] ramp_dur = (transition_duration == 16'd0) ? 16'd1 : transition_duration;
```

**Duration Examples:**
| Duration (cycles) | Time at 4 kHz | Use Case |
|-------------------|---------------|----------|
| 0 (→1) | ~0.25 ms | Instant (v11.3 behavior) |
| 4000 | 1 second | Quick transition |
| 40000 | 10 seconds | Moderate transition |
| 80000 | 20 seconds | Full meditation ramp |

---

## 3. Distributed SIE Architecture (v11.5)

### 3.1 Problem: Boost Cascade Stacking

**v11.3 SIE Signal Chain:**
```
SR Detection → sie_theta_boost (2×) → sie_alpha_boost (2×) →
    Mixer sie_boost (2×) → Thalamus SIE_ENHANCE_F0 (4×) → DAC

Worst case: 2 × 2 × 2 × 4 = 32× (15 dB) → CLIPPING
```

**Empirical Target:** SIE events show ~4-5× (6-7 dB) power increase, not 30×.

### 3.2 Option C: Distributed Reduction

**Solution:** Disable signal-level boosts entirely, distribute SIE gain across stages:

| Stage | v11.3 Enhancement | v11.5 Enhancement | dB Contribution |
|-------|-------------------|-------------------|-----------------|
| sie_theta_boost | 2.0× | 1.0× (disabled) | 0 dB |
| sie_alpha_boost | 2.0× | 1.0× (disabled) | 0 dB |
| Mixer sie_boost | 1.0-2.0× | 1.0-1.4× | +2.9 dB |
| Thalamus f₀ | 4.0× | 1.3× | +2.3 dB |
| Thalamus f₁ | 5.0× | 1.2× | +1.6 dB |
| **Total** | **~32×** | **~2.2×** | **6.8 dB** |

### 3.3 phi_n_neural_processor.v Changes (v11.5)

```verilog
// v11.5 CHANGES (Option C Distributed SIE Reduction):
// - DISABLED sie_theta_boost and sie_alpha_boost (set to constant 1.0×)
// - Signal-level boosts removed; SIE now distributed across mixer + thalamus

// SIE BOOST DISABLED (Option C distributed reduction)
// SIE gain is now ONLY applied through:
//   - Mixer: [1.0, 1.4] range (+2.9 dB)
//   - Thalamus f₀: 1.3× (+2.3 dB)
//   - Thalamus f₁: 1.2× (+1.6 dB)
// Total: 6.8 dB (matches empirical 4-5× SIE power increase)
wire signed [WIDTH-1:0] sie_theta_boost = ONE;  // Constant 1.0×
wire signed [WIDTH-1:0] sie_alpha_boost = ONE;  // Constant 1.0×
```

### 3.4 thalamus.v Changes (v11.5)

```verilog
// v11.5 SIE Enhancement Factors (distributed reduction)
// Part of Option C: 6.8 dB distributed across mixer + thalamus
localparam signed [WIDTH-1:0] SIE_ENHANCE_F0 = 18'sd21299;  // 1.3× (+2.3 dB)
localparam signed [WIDTH-1:0] SIE_ENHANCE_F1 = 18'sd19661;  // 1.2× (+1.6 dB)
localparam signed [WIDTH-1:0] SIE_ENHANCE_F2 = 18'sd19661;  // 1.2× (protected)
localparam signed [WIDTH-1:0] SIE_ENHANCE_F3 = 18'sd19661;  // 1.2× (protected)
localparam signed [WIDTH-1:0] SIE_ENHANCE_F4 = 18'sd19661;  // 1.2× (protected)
```

**Rationale:** f₀ > f₁ hierarchy preserved (1.3× > 1.2×) matching SR harmonic observations where lower harmonics show stronger coherence response.

### 3.5 output_mixer.v Changes (v7.17)

```verilog
// v7.17 SIE boost reduced from [1.0, 2.0] to [1.0, 1.4] (+2.9 dB contribution)
// Part of distributed 6.8 dB target: mixer(2.9) + f₀(2.3) + f₁(1.6) = 6.8 dB

// SIE boost factor: scales final output during ignition events
// Range: 1.0 (baseline) to 1.4 (peak SIE)
// Formula: sie_boost = 1.0 + 0.4 × sr_gain_envelope
localparam signed [WIDTH-1:0] SIE_BOOST_RANGE = 18'sd6554;  // 0.4 in Q14

wire signed [WIDTH-1:0] sie_boost = ONE + ((sr_gain_envelope * SIE_BOOST_RANGE) >>> FRAC);
```

---

## 4. Parameterized Envelope Bounds (v11.4)

### 4.1 amplitude_envelope_generator.v Changes

```verilog
module amplitude_envelope_generator #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter FAST_SIM = 0,
    // v11.4: Parameterized envelope bounds for per-oscillator customization
    parameter signed [WIDTH-1:0] ENVELOPE_MIN = 18'sd8192,   // 0.5 default
    parameter signed [WIDTH-1:0] ENVELOPE_MAX = 18'sd24576   // 1.5 default
)(
    // ... ports unchanged
);
```

### 4.2 Theta vs Cortical Envelope Bounds

| Oscillator | ENVELOPE_MIN | ENVELOPE_MAX | Rationale |
|------------|--------------|--------------|-----------|
| Cortical (default) | 8192 (0.5) | 24576 (1.5) | ±50% "alpha breathing" |
| Theta (thalamus) | 11469 (0.7) | 21299 (1.3) | ±30% stable pacemaker |

**Biological Justification:**
- Medial septum pacemaker is more stable than cortical oscillators
- Theta provides timing reference for gamma-theta nesting
- Tighter theta bounds ensure coherent phase locking across columns

### 4.3 Thalamus Instantiation

```verilog
// v11.4: Theta envelope with narrower bounds [0.7, 1.3]
amplitude_envelope_generator #(
    .WIDTH(WIDTH),
    .FRAC(FRAC),
    .FAST_SIM(FAST_SIM),
    .ENVELOPE_MIN(18'sd11469),  // 0.7
    .ENVELOPE_MAX(18'sd21299)   // 1.3
) theta_envelope_gen (
    .clk(clk),
    .rst(rst),
    .clk_en(clk_en),
    .seed(16'hBEEF),
    .tau_inv(18'sd1),
    .envelope(theta_amplitude_envelope)
);
```

---

## 5. MU-Based Amplitude Scaling (v11.4)

### 5.1 cortical_column.v Changes

Layer outputs now scale with MU values for state-dependent amplitude:

```verilog
// v11.4: MU-based amplitude scaling
// Output amplitude proportional to MU value
// MU=3 (NORMAL) → 1.0× amplitude
// MU=6 (ENHANCED) → 2.0× amplitude
// MU=1 (WEAK) → 0.33× amplitude
localparam signed [WIDTH-1:0] MU_DIV3 = 18'sd5461;  // 1/3 in Q14

// Apply MU scaling to layer outputs
wire signed [2*WIDTH-1:0] l6_scaled = l6_x * mu_dt_l6 * MU_DIV3;
assign l6_y_out = l6_scaled[2*FRAC+WIDTH-1:2*FRAC];
```

### 5.2 Impact on Consciousness States

| State | Theta MU | L6 MU | L5a MU | L5b MU | L4 MU | L2/3 MU |
|-------|----------|-------|--------|--------|-------|---------|
| NORMAL | 3 | 3 | 3 | 3 | 3 | 3 |
| MEDITATION | 6 | 6 | 1 | 1 | 1 | 2 |
| PSYCHEDELIC | 4 | 1 | 4 | 4 | 6 | 6 |
| FLOW | 4 | 2 | 6 | 6 | 4 | 4 |
| ANESTHESIA | 2 | 6 | 2 | 2 | 1 | 1 |

**Spectral Differentiation (MEDITATION vs NORMAL):**
| Band | NORMAL Power | MEDITATION Power | Difference |
|------|--------------|------------------|------------|
| Theta (5.89 Hz) | MU=3 (1.0×) | MU=6 (2.0×) | +6 dB |
| Alpha (9.53 Hz) | MU=3 (1.0×) | MU=6 (2.0×) | +6 dB |
| Beta (15-25 Hz) | MU=3 (1.0×) | MU=1 (0.33×) | -10 dB |
| Gamma (40 Hz) | MU=3 (1.0×) | MU=2 (0.67×) | -4 dB |

---

## 6. State-Driven Coupling Mode (v1.1)

### 6.1 coupling_mode_controller.v Changes

```verilog
// v1.1 CHANGES (State-Driven Mode):
// - Added state_select input for consciousness state
// - MEDITATION state (4) directly forces HARMONIC mode
// - Lowered thresholds: R 0.7→0.5, boundary 0.5→0.25

module coupling_mode_controller #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter TRANSITION_CYCLES = 2000
)(
    // v1.1: Consciousness state for state-driven mode
    input  wire [2:0] state_select,

    // Synchronization metrics
    input  wire signed [WIDTH-1:0] kuramoto_R,
    input  wire signed [WIDTH-1:0] boundary_power,
    // ...
);

// State-driven mode: MEDITATION forces HARMONIC coupling
localparam [2:0] STATE_MEDITATION = 3'd4;
wire state_driven_harmonic = (state_select == STATE_MEDITATION);

// v1.1: Lowered thresholds for more responsive transitions
localparam signed [WIDTH-1:0] DEFAULT_R_HIGH = 18'sd8192;     // 0.5 (was 0.7)
localparam signed [WIDTH-1:0] DEFAULT_R_LOW = 18'sd6554;      // 0.4 (was 0.5)
localparam signed [WIDTH-1:0] DEFAULT_BOUNDARY = 18'sd4096;   // 0.25 (was 0.5)
```

### 6.2 Mode Transition Rules

```
MODULATORY → TRANSITION:
  - state_driven_harmonic (MEDITATION) OR
  - (kuramoto_R > 0.5 AND boundary_power > 0.25)

TRANSITION → HARMONIC:
  - After TRANSITION_CYCLES (~500ms)

HARMONIC → MODULATORY:
  - kuramoto_R < 0.4 AND NOT state_driven_harmonic
```

---

## 7. New Constants

### 7.1 State Transition Constants

| Name | Q14 Value | Decimal | Usage |
|------|-----------|---------|-------|
| TRANSITION_DURATION_DEFAULT | 80000 | 20s | Default state transition cycles |
| MU_DIV3 | 5461 | 0.333 | MU scaling divisor |

### 7.2 Envelope Bounds Constants

| Name | Q14 Value | Decimal | Usage |
|------|-----------|---------|-------|
| ENVELOPE_MIN_CORTICAL | 8192 | 0.5 | Cortical envelope lower bound |
| ENVELOPE_MAX_CORTICAL | 24576 | 1.5 | Cortical envelope upper bound |
| ENVELOPE_MIN_THETA | 11469 | 0.7 | Theta envelope lower bound (v11.4) |
| ENVELOPE_MAX_THETA | 21299 | 1.3 | Theta envelope upper bound (v11.4) |

### 7.3 Distributed SIE Constants (v11.5)

| Name | Q14 Value | Decimal | Usage |
|------|-----------|---------|-------|
| SIE_ENHANCE_F0_v12 | 21299 | 1.3× | Distributed f₀ enhancement |
| SIE_ENHANCE_F1_v12 | 19661 | 1.2× | Distributed f₁ enhancement |
| SIE_BOOST_RANGE | 6554 | 0.4 | Mixer boost range (1.0→1.4) |

### 7.4 Coupling Mode Constants (v1.1)

| Name | Q14 Value | Decimal | Usage |
|------|-----------|---------|-------|
| KURAMOTO_R_ENTRY | 8192 | 0.5 | HARMONIC mode entry threshold |
| KURAMOTO_R_EXIT | 6554 | 0.4 | HARMONIC mode exit threshold |
| BOUNDARY_THRESH | 4096 | 0.25 | Boundary power threshold |

---

## 8. New Testbenches

### 8.1 tb_state_interpolation.v (10 tests)

Validates config_controller state transition interpolation:

| Test | Focus | Validation |
|------|-------|------------|
| 1 | Instant mode (duration=0) | Completes in ~3 cycles |
| 2 | Linear ramp values | 25%, 50%, 75% progress monotonic |
| 3 | Mid-transition interrupt | Restart from current values |
| 4 | NORMAL → ANESTHESIA | L6=6 (enhanced), L23=1 (weak) |
| 5 | NORMAL → PSYCHEDELIC | L4=6, L23=6 (enhanced) |
| 6 | MU bounds check | All MU stay in [1, 6] |
| 7 | Ca_threshold interpolation | Proper ramping |
| 8 | SIE timing interpolation | Duration values lerp correctly |
| 9 | Progress output scaling | 0 → 65535 range |
| 10 | Transitioning flag | Rises during ramp, falls after |

### 8.2 tb_state_transition_spectrogram.v (Visual)

Generates 100-second DAC output with NORMAL ↔ MEDITATION transitions:

```
Timeline (100 seconds):
├── 0-20s:  NORMAL baseline
├── 20-40s: NORMAL → MEDITATION transition (20s ramp)
├── 40-60s: MEDITATION steady-state
├── 60-80s: MEDITATION → NORMAL transition (20s ramp)
└── 80-100s: NORMAL steady-state

Output: state_transition_dac.csv (100,000 samples at 1 kHz)
```

**Expected Observations:**
- Theta/alpha: stable power, slight increase during MEDITATION
- Beta/gamma: full power in NORMAL phases, reduced (~50%) in MEDITATION
- Smooth gradients during 20-second transition windows

### 8.3 scripts/state_transition_spectrogram.py

Python visualization script:
- Generates spectrogram with φⁿ frequency overlay
- Band power time series (theta, alpha, beta, gamma)
- Summary statistics by phase

---

## 9. Resource Impact

| Addition | LUTs | FFs | DSPs |
|----------|------|-----|------|
| Interpolation (config_controller) | ~50 | ~100 | 0 |
| Shadow registers | ~20 | ~80 | 0 |
| Lerp functions | ~30 | 0 | 0 |
| **Total v12.0 additions** | **~100** | **~180** | **0** |

**Cumulative System (v12.0):**
| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| LUTs | ~6,130 | 53,200 | 11.5% |
| FFs | ~3,250 | 106,400 | 3.1% |
| DSPs | ~8 | 220 | 3.6% |

---

## 10. Verification

### 10.1 New Testbenches

| Testbench | Tests | Status |
|-----------|-------|--------|
| tb_state_interpolation.v | 10 | PASS |
| tb_state_transition_spectrogram.v | Visual | PASS |

### 10.2 Integration Tests (No Regressions)

| Test | Result |
|------|--------|
| tb_full_system_fast | 15/15 PASS |
| tb_gamma_theta_nesting | 7/7 PASS |
| tb_kuramoto_order | 7/7 PASS |
| tb_coupling_mode_controller | 8/8 PASS |
| tb_harmonic_spacing_index | 8/8 PASS |

---

## 11. Observable Signatures

### 11.1 State Transition Timeline (NORMAL → MEDITATION)

```
t=0s:      NORMAL state, all MU=3, modulatory coupling
t=0-20s:   Ramp: MU values interpolating toward MEDITATION
           - Theta MU: 3 → 6 (increasing)
           - Beta MU: 3 → 1 (decreasing)
           - transition_progress: 0 → 65535
t=20s:     MEDITATION state reached
           - transitioning flag drops
           - Coupling forced to HARMONIC mode
t=20s+:    Steady MEDITATION with enhanced theta/alpha, reduced beta/gamma
```

### 11.2 SIE Event During Transition

```
During state transition:
  - SIE can still trigger if coherence threshold met
  - SIE boost now distributed (6.8 dB total)
  - No cascade stacking artifacts
  - Visible as smooth power increase in spectrogram
```

---

## 12. Version History

| Version | Date | Change |
|---------|------|--------|
| v12.0 | 2025-12-29 | Unified State Dynamics (interpolation + distributed SIE) |
| v11.5 | 2025-12-29 | Distributed SIE Boost (Option C) |
| v11.4 | 2025-12-29 | State Transition Interpolation |
| v11.3 | 2025-12-28 | SIE Dynamics (Kuramoto, boundaries, bicoherence, mode controller, HSI) |
| v11.2 | 2025-12-28 | DAC anti-clipping (MU_MODERATE, soft limiter) |

---

## 13. Files Modified/Created

### 13.1 Source Files Modified

| File | Version | Change |
|------|---------|--------|
| `src/phi_n_neural_processor.v` | v11.5 | SIE boost disabled, distributed model |
| `src/config_controller.v` | v11.4 | State transition interpolation |
| `src/cortical_column.v` | v11.4 | MU-based amplitude scaling |
| `src/thalamus.v` | v11.5 | SIE enhancement reduction (1.3×/1.2×) |
| `src/output_mixer.v` | v7.17 | SIE boost [1.4×], state transitions |
| `src/amplitude_envelope_generator.v` | v11.4 | Parameterized bounds |
| `src/coupling_mode_controller.v` | v1.1 | State-driven HARMONIC mode |

### 13.2 Testbenches Created

| File | Purpose |
|------|---------|
| `tb/tb_state_interpolation.v` | State transition unit tests (10) |
| `tb/tb_state_transition_spectrogram.v` | 100s spectrogram generation |

### 13.3 Scripts Created

| File | Purpose |
|------|---------|
| `scripts/state_transition_spectrogram.py` | Spectrogram + band power visualization |

---

## 14. References

- v11.3 SIE Dynamics: `docs/SPEC_v11.3_UPDATE.md`
- v11.2 DAC Anti-Clipping: `docs/SPEC_v11.2_UPDATE.md`
- v11.1 Unified Boundary-Attractor: `docs/SPEC_v11.1_UPDATE.md`
- v11.0 Active φⁿ Dynamics: `docs/SPEC_v11.0_UPDATE.md`
- Base Architecture v8.0: `docs/FPGA_SPECIFICATION_V8.md`
