# φⁿ Neural Processor FPGA - v12.4 Specification Update

## State-Dependent Phase Coupling & Geophysical Realism

**Date:** January 1, 2026
**Version:** v12.4

### Overview

v12.4 introduces **state-dependent phase coupling gain** to fix the 20:1 hippocampal dominance bug and adds **geophysical SR realism features** for multi-day validation. Key changes:

1. **Phase Coupling Balance:** New `k_phase_couple` output scales hippocampal→cortical signal strength per consciousness state
2. **External SEED Parameter:** Top-level seed enables reproducible frequency drift trajectories
3. **Geophysical Drift Mode:** 120× slower drift timescales for realistic multi-day SR simulation
4. **Q-Factor Drift Module:** Per-harmonic Q-factor variation matching real SR observations
5. **Signed Arithmetic Fix:** Corrected random initialization offset computation

### Core Insight

The hippocampal CA3 phase memory generates phase coupling signals that drive cortical L2/3 and L6 oscillators toward learned phase relationships. In v12.3 and earlier, these signals entered at **1.0× gain** while L4 feedforward input used **K_L4_L23=0.05×**—a 20:1 imbalance that made hippocampal signals dominate sensory processing in all states.

v12.4 introduces **state-dependent phase coupling gain** that:
- Balances hippocampal and sensory inputs in NORMAL/FLOW states (1:1)
- Enhances memory consolidation in MEDITATION (3:1 hippocampal dominance)
- Suppresses hippocampal influence in ANESTHESIA/PSYCHEDELIC (0.4:1)

---

## State-Dependent Phase Coupling

### Problem Analysis

Previous architecture (v12.3):
```
L2/3 input = L4_feedforward×0.05 + L6_feedback×0.01 + PAC×0.02 + phase_couple×1.0
                 ↑ 0.05                                              ↑ 1.0

Ratio: phase_couple / L4_feedforward = 1.0 / 0.05 = 20:1
```

This 20:1 ratio meant hippocampal phase coupling dominated cortical dynamics regardless of consciousness state.

### Solution

New architecture (v12.4):
```
L2/3 input = L4_feedforward×0.05 + L6_feedback×0.01 + PAC×0.02 + phase_couple×k_phase_couple
                                                                              ↑ state-dependent

NORMAL:      k_phase_couple = 0.05  → ratio = 1:1 (balanced)
MEDITATION:  k_phase_couple = 0.15  → ratio = 3:1 (memory consolidation)
PSYCHEDELIC: k_phase_couple = 0.02  → ratio = 0.4:1 (sensory-dominant)
```

### State-Dependent Gain Values

| State | k_phase_couple | Q14 Value | Ratio vs L4 | Purpose |
|-------|----------------|-----------|-------------|---------|
| NORMAL | 0.05 | 820 | 1:1 | Balanced sensory-memory integration |
| ANESTHESIA | 0.02 | 328 | 0.4:1 | Suppressed hippocampal activity |
| PSYCHEDELIC | 0.02 | 328 | 0.4:1 | Sensory dominance, reduced memory |
| FLOW | 0.05 | 820 | 1:1 | Balanced motor-memory integration |
| MEDITATION | 0.15 | 2458 | 3:1 | Memory consolidation, theta coherence |

### Q14 Value Derivation

```
K_PHASE_NORMAL = 0.05 × 16384 = 819.2 ≈ 820
K_PHASE_ANESTHESIA = 0.02 × 16384 = 327.68 ≈ 328
K_PHASE_PSYCHEDELIC = 0.02 × 16384 = 327.68 ≈ 328
K_PHASE_FLOW = 0.05 × 16384 = 819.2 ≈ 820
K_PHASE_MEDITATION = 0.15 × 16384 = 2457.6 ≈ 2458
```

### Biological Rationale

| State | Hippocampal Role | Phase Coupling |
|-------|------------------|----------------|
| NORMAL | Active encoding/retrieval | Balanced with sensory |
| ANESTHESIA | Suppressed consolidation | Minimal influence |
| PSYCHEDELIC | Disrupted pattern completion | Sensory flood |
| FLOW | Motor sequence learning | Balanced integration |
| MEDITATION | Enhanced consolidation | Memory dominant |

---

## External SEED Parameter

### Purpose

New top-level `SEED[15:0]` parameter enables:
1. **Reproducible simulations** - Same seed produces identical frequency trajectories
2. **Multi-run validation** - Different seeds create statistically independent runs
3. **Ensemble analysis** - Parameter sweeps over seed space

### Implementation

```verilog
// phi_n_neural_processor.v v12.4
parameter [15:0] SEED = 16'h0000  // v12.4: Seed for frequency drift LFSRs

// Propagated to all drift modules
sr_frequency_drift #(
    ...
    .SEED_OFFSET(SEED)
) sr_drift_gen (...);

thalamic_frequency_drift #(
    ...
    .SEED_OFFSET(SEED)
) theta_drift_gen (...);

cortical_frequency_drift #(
    ...
    .SEED_OFFSET(SEED)
) cortical_drift_gen (...);
```

### SEED Transformation per Module

Each module applies different transformations to SEED_OFFSET for LFSR independence:

| Module | LFSR | Transformation |
|--------|------|----------------|
| sr_frequency_drift | f₀ | Direct XOR |
| sr_frequency_drift | f₁ | Byte swap |
| sr_frequency_drift | f₂ | Rotate 4 bits |
| sr_frequency_drift | f₃ | Rotate 12 bits |
| sr_frequency_drift | f₄ | Invert |
| thalamic_freq_drift | drift | Direct XOR |
| thalamic_freq_drift | jitter | Byte swap |
| cortical_freq_drift | L6 | Direct XOR |
| cortical_freq_drift | L5a | Byte swap |
| cortical_freq_drift | L5b | Rotate 4 |
| cortical_freq_drift | L4 | Rotate 12 |
| cortical_freq_drift | L2/3 | Invert |

---

## Geophysical Drift Mode (SLOW_DRIFT)

### Purpose

Real Schumann Resonance frequency variations occur over hours to days, not seconds. The `SLOW_DRIFT` parameter scales all drift timescales by 120× for realistic multi-day simulations.

### Implementation

```verilog
// sr_frequency_drift.v v3.2
parameter SLOW_DRIFT = 0   // 0=real-time, 1=geophysical (120× slower)

localparam [7:0] DRIFT_SCALE = (SLOW_DRIFT != 0) ? 8'd120 : 8'd1;

// Update periods scaled by DRIFT_SCALE
localparam [25:0] UPDATE_PERIOD_F0 = 26'd3200 * DRIFT_SCALE;  // 0.8s → 1.6min
localparam [25:0] UPDATE_PERIOD_F1 = 26'd8000 * DRIFT_SCALE;  // 2.0s → 4min
localparam [25:0] UPDATE_PERIOD_F2 = 26'd16000 * DRIFT_SCALE; // 4.0s → 8min
localparam [25:0] UPDATE_PERIOD_F3 = 26'd1600 * DRIFT_SCALE;  // 0.4s → 48s
localparam [25:0] UPDATE_PERIOD_F4 = 26'd3200 * DRIFT_SCALE;  // 0.8s → 1.6min
```

### Timescale Comparison

| Mode | SR3 Update | 72-Hour Span | Use Case |
|------|------------|--------------|----------|
| SLOW_DRIFT=0 | 4s | ~64,800 transitions | Fast functional testing |
| SLOW_DRIFT=1 | 8 min | ~540 transitions | Geophysical realism |

### Register Width Increase

Counter registers widened from 22 to 26 bits to accommodate SLOW_DRIFT scaling:
```verilog
// v3.0: 22-bit counters (max ~4M cycles)
reg [21:0] update_counter_0;

// v3.2: 26-bit counters (max ~67M cycles)
reg [25:0] update_counter_0;
```

---

## Signed Arithmetic Bug Fix

### Problem

v3.0 random initialization used unsigned subtraction that could wrap around:
```verilog
// v3.0 BUG: Unsigned subtraction may produce large positive values
assign init_offset_0 = RANDOM_INIT ?
    (((LFSR_SEED_0[15:11] - 5'd16) * DRIFT_MAX_F0) >>> 4) : 18'sd0;
//       ↑ unsigned 5-bit minus 16 wraps when seed[15:11] < 16
```

### Solution

v3.2 uses explicit signed arithmetic:
```verilog
// v3.2 FIX: Explicit signed centering
wire signed [5:0] seed_centered_0 = $signed({1'b0, LFSR_SEED_0[15:11]}) - 6'sd16;
wire signed [5:0] seed_centered_1 = $signed({1'b0, LFSR_SEED_1[15:11]}) - 6'sd16;
// ... (for all harmonics)

assign init_offset_0 = RANDOM_INIT ? ((seed_centered_0 * DRIFT_MAX_F0) >>> 4) : 18'sd0;
```

**Result:** Random initialization now correctly produces values in range [-DRIFT_MAX, +DRIFT_MAX].

---

## New Modules

### sr_q_factor_drift.v v1.0

**Purpose:** Per-harmonic Q-factor drift using Ornstein-Uhlenbeck process, matching real geophysical SR observations.

```verilog
module sr_q_factor_drift #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter NUM_HARMONICS = 5,
    parameter FAST_SIM = 0,
    parameter RANDOM_INIT = 1,
    parameter [15:0] SEED_OFFSET = 16'h0000
)(
    input  wire clk,
    input  wire rst,
    input  wire clk_en,
    output wire signed [NUM_HARMONICS*WIDTH-1:0] q_factor_packed,
    output wire signed [NUM_HARMONICS*WIDTH-1:0] q_scaled_packed,
    output wire signed [WIDTH-1:0] q_f0_scaled,
    output wire signed [WIDTH-1:0] q_f1_scaled,
    output wire signed [WIDTH-1:0] q_f2_scaled,
    output wire signed [WIDTH-1:0] q_f3_scaled,
    output wire signed [WIDTH-1:0] q_f4_scaled
);
```

### Q-Factor Parameters (from real SR data)

| Harmonic | Center Q | Q14 (normalized) | Drift Range | Real Data |
|----------|----------|------------------|-------------|-----------|
| SR1 (f₀) | 7.5 | 7929 (0.484) | ±0.30 | Q varies 5-10 |
| SR2 (f₁) | 9.5 | 10051 (0.613) | ±0.40 | Q varies 6-14 |
| SR3 (f₂) | 15.5 | 16384 (1.0, ANCHOR) | ±0.20 | Q varies 12-18 |
| SR4 (f₃) | 8.5 | 8995 (0.549) | ±0.30 | Q varies 6-11 |
| SR5 (f₄) | 7.0 | 7405 (0.452) | ±0.35 | Q varies 4.5-9.5 |

### O-U Process Dynamics

```
q[n+1] = q[n] + tau_inv × (q_center - q[n]) + sigma × noise
```

Stability hierarchy matches sr_frequency_drift.v:
- SR3 (f₂): MOST STABLE (slowest tau, smallest drift)
- SR4 (f₃): MOST VARIABLE (fastest tau, largest drift)

---

## Modified Modules

### 1. config_controller.v v9.5 → v12.4

**Changes:**
- Added `k_phase_couple` output port
- Added state-dependent phase coupling gain constants
- Added k_phase_couple to state interpolation

```verilog
// v12.4: State-dependent phase coupling gain
output reg signed [WIDTH-1:0] k_phase_couple,

// Constants
localparam signed [WIDTH-1:0] K_PHASE_NORMAL      = 18'sd820;   // 0.05
localparam signed [WIDTH-1:0] K_PHASE_ANESTHESIA  = 18'sd328;   // 0.02
localparam signed [WIDTH-1:0] K_PHASE_PSYCHEDELIC = 18'sd328;   // 0.02
localparam signed [WIDTH-1:0] K_PHASE_FLOW        = 18'sd820;   // 0.05
localparam signed [WIDTH-1:0] K_PHASE_MEDITATION  = 18'sd2458;  // 0.15

// Interpolation registers
reg signed [WIDTH-1:0] k_phase_start, k_phase_tgt;
```

---

### 2. cortical_column.v v10.0 → v12.4

**Changes:**
- Added `k_phase_couple` input port
- Applied gain to phase_couple_l23 and phase_couple_l6 signals

```verilog
// v12.4: State-dependent phase coupling gain input
input wire signed [WIDTH-1:0] k_phase_couple,

// Phase coupling gain application
wire signed [2*WIDTH-1:0] phase_couple_l23_full;
wire signed [WIDTH-1:0] phase_couple_l23_scaled;
wire signed [2*WIDTH-1:0] phase_couple_l6_full;
wire signed [WIDTH-1:0] phase_couple_l6_scaled;

assign phase_couple_l23_full = phase_couple_l23 * k_phase_couple;
assign phase_couple_l23_scaled = phase_couple_l23_full >>> FRAC;

assign phase_couple_l6_full = phase_couple_l6 * k_phase_couple;
assign phase_couple_l6_scaled = phase_couple_l6_full >>> FRAC;

// Updated L2/3 input computation
assign l23_input_raw = (l4_to_l23_full >>> FRAC) + (l6_to_l23_full >>> FRAC)
                     + pac_mod + phase_couple_l23_scaled;  // v12.4: scaled
```

---

### 3. sr_frequency_drift.v v3.0 → v3.2

**Changes:**
- Added `SEED_OFFSET` parameter
- Added `SLOW_DRIFT` parameter (120× scale)
- Widened counters to 26 bits
- Fixed signed arithmetic for initialization

```verilog
parameter [15:0] SEED_OFFSET = 16'h0000,
parameter SLOW_DRIFT = 0   // 0=fast, 1=120× slower

// LFSR seeds with SEED_OFFSET transformation
localparam [15:0] LFSR_SEED_0 = 16'hB5C3 ^ SEED_OFFSET;
localparam [15:0] LFSR_SEED_1 = 16'h4E91 ^ {SEED_OFFSET[7:0], SEED_OFFSET[15:8]};
// ... etc

// Fixed signed initialization
wire signed [5:0] seed_centered_0 = $signed({1'b0, LFSR_SEED_0[15:11]}) - 6'sd16;
```

---

### 4. thalamic_frequency_drift.v v1.1 → v1.2

**Changes:**
- Added `SEED_OFFSET` parameter with byte-swap for jitter LFSR

```verilog
parameter [15:0] SEED_OFFSET = 16'h0000

localparam [15:0] LFSR_SEED = 16'hC3A7 ^ SEED_OFFSET;
localparam [15:0] JLFSR_SEED = 16'h5E91 ^ {SEED_OFFSET[7:0], SEED_OFFSET[15:8]};
```

---

### 5. cortical_frequency_drift.v v3.6 → v3.7

**Changes:**
- Added `SEED_OFFSET` parameter with 5 transformations

```verilog
parameter [15:0] SEED_OFFSET = 16'h0000

// Per-layer LFSR seeds with different transformations
localparam [15:0] LFSR_SEED_L6  = 16'h7A3D ^ SEED_OFFSET;
localparam [15:0] LFSR_SEED_L5A = 16'hE5B2 ^ {SEED_OFFSET[7:0], SEED_OFFSET[15:8]};
localparam [15:0] LFSR_SEED_L5B = 16'h29C8 ^ {SEED_OFFSET[11:0], SEED_OFFSET[15:12]};
localparam [15:0] LFSR_SEED_L4  = 16'hD4F1 ^ {SEED_OFFSET[3:0], SEED_OFFSET[15:4]};
localparam [15:0] LFSR_SEED_L23 = 16'h8167 ^ ~SEED_OFFSET;
```

---

### 6. phi_n_neural_processor.v v12.3 → v12.4

**Changes:**
- Added `SEED` parameter
- Added `k_phase_couple` wire and connections
- Propagated SEED to all drift modules

```verilog
parameter [15:0] SEED = 16'h0000  // v12.4: External seed

wire signed [WIDTH-1:0] k_phase_couple;

// Propagation to drift modules
sr_frequency_drift #(
    ...
    .SEED_OFFSET(SEED)
) sr_drift_gen (...);

// Connection to config_controller
config_controller #(...) config_ctrl (
    ...
    .k_phase_couple(k_phase_couple)
);

// Connection to cortical columns
cortical_column #(...) col_sensory (
    ...
    .k_phase_couple(k_phase_couple)
);
```

---

## New Parameters Summary

| Parameter | Q14 Value | Decimal | Module | Description |
|-----------|-----------|---------|--------|-------------|
| K_PHASE_NORMAL | 820 | 0.05 | config_controller | Phase coupling gain (NORMAL) |
| K_PHASE_ANESTHESIA | 328 | 0.02 | config_controller | Phase coupling gain (ANESTHESIA) |
| K_PHASE_PSYCHEDELIC | 328 | 0.02 | config_controller | Phase coupling gain (PSYCHEDELIC) |
| K_PHASE_FLOW | 820 | 0.05 | config_controller | Phase coupling gain (FLOW) |
| K_PHASE_MEDITATION | 2458 | 0.15 | config_controller | Phase coupling gain (MEDITATION) |
| Q_CENTER_F0 | 7929 | 0.484 | sr_q_factor_drift | SR1 Q-factor center |
| Q_CENTER_F1 | 10051 | 0.613 | sr_q_factor_drift | SR2 Q-factor center |
| Q_CENTER_F2 | 16384 | 1.0 | sr_q_factor_drift | SR3 Q-factor anchor |
| Q_CENTER_F3 | 8995 | 0.549 | sr_q_factor_drift | SR4 Q-factor center |
| Q_CENTER_F4 | 7405 | 0.452 | sr_q_factor_drift | SR5 Q-factor center |
| SLOW_DRIFT | 0/1 | — | sr_frequency_drift | 0=fast, 1=120× slower |
| SEED | 16-bit | — | phi_n_neural_processor | External LFSR seed |
| SEED_OFFSET | 16-bit | — | all drift modules | Per-module seed offset |
| DRIFT_SCALE | 1/120 | — | sr_frequency_drift | Timescale multiplier |

---

## New Testbenches

### tb_sr_realism_3day.v

**Purpose:** 72-hour geophysical realism validation

**Duration:** 259,200 simulated seconds (72 hours)
**Output Rate:** 1 Hz (259,200 samples)
**Wall-clock Time:** ~2 minutes with FAST_SIM

**Output:** `sr_realism_3day.csv`
- Columns: time_s, F1-F5 (Hz), A1-A5 (normalized), Q1-Q5 (integer)
- Per-harmonic frequency, amplitude, and Q-factor

**Features:**
- Uses SLOW_DRIFT=1 for geophysical timescales
- Per-harmonic amplitude scaling (1/f decay)
- External seed via `+seed=N` plusarg

**Makefile Target:**
```bash
make iverilog-sr-realism
```

---

## Modified Testbenches

### tb_state_transition_spectrogram.v

**Changes:**
- Parameterized `DURATION_MS` (default 100,000 ms)
- Added `SEED` parameter for trajectory variation
- Phase timings derived from `DURATION_MS / 5`

```verilog
parameter DURATION_MS = 100000;  // Override with -PDURATION_MS=600000
parameter SEED = 0;              // Override with -PSEED=12345
localparam PHASE_MS = DURATION_MS / 5;
```

---

## Resource Impact

| Module | LUTs | FFs | DSPs |
|--------|------|-----|------|
| sr_q_factor_drift.v | ~200 | ~150 | 0 |
| config_controller changes | ~20 | ~20 | 0 |
| cortical_column changes | ~30 | ~20 | 0 |
| phi_n_neural_processor changes | ~10 | ~10 | 0 |
| sr_frequency_drift changes | ~20 | ~30 | 0 |
| **Total v12.4** | **~280** | **~230** | **0** |

<2% FPGA utilization impact.

---

## Backward Compatibility

- `SEED=0`: Equivalent to v12.3 behavior (original LFSR seeds)
- `SLOW_DRIFT=0`: Equivalent to v12.3 drift timescales
- `k_phase_couple` is new required signal; existing designs need port connection
- All frequency and SR outputs unchanged
- DAC output format unchanged

---

## Summary

v12.4 "State-Dependent Phase Coupling & Geophysical Realism" delivers:

1. **Phase Coupling Balance:** State-dependent `k_phase_couple` gain fixes 20:1 hippocampal dominance bug
2. **Reproducible Simulations:** External `SEED` parameter enables ensemble analysis
3. **Geophysical Validation:** `SLOW_DRIFT=1` enables realistic 72-hour SR simulations
4. **Q-Factor Realism:** New sr_q_factor_drift.v models observed SR Q-factor variations
5. **Bug Fix:** Corrected signed arithmetic in random initialization
6. **3-Day Testbench:** tb_sr_realism_3day.v validates multi-day frequency/Q drift

The result is a more biologically accurate model where:
- Hippocampal-cortical balance varies appropriately with consciousness state
- MEDITATION enhances memory consolidation (3:1 hippocampal gain)
- PSYCHEDELIC/ANESTHESIA suppress hippocampal influence (0.4:1 gain)
- Long-duration simulations match real geophysical SR observations
