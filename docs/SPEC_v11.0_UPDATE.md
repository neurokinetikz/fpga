# SPEC v11.0 UPDATE: Active phi^n Dynamics

## Summary

Version 11.0 transforms the phi^n Neural Processor from a **static** architecture (hardcoded frequencies) to a **self-organizing** one where frequencies emerge from energy landscape dynamics. The system now computes restoring forces that push oscillators toward stable phi^n positions, with catastrophe avoidance driving the f1 quarter-integer fallback naturally.

**Key Result:**
```
Oscillator positions emerge from energy minimization:
E_total(n) = -A * cos(2*pi*n) + B / (phi^n - 2)^2

Forces push oscillators toward:
- Half-integer attractors (n = 0.5, 1.5, 2.5, ...)
- Away from integer boundaries (n = 0, 1, 2, ...)
- Away from 2:1 harmonic catastrophe (n = 1.44)
```

**Backward Compatibility:**
- `ENABLE_ADAPTIVE = 0` (default): v10.5 static behavior preserved
- `ENABLE_ADAPTIVE = 1`: Active phi^n dynamics enabled

---

## 1. Motivation: From Photograph to Physics

### 1.1 The Limitation of v10.5

Version 10.5 successfully implemented the Quarter-Integer phi^n Theory, explaining why f1 sits at n = 1.25 instead of n = 1.5. However, this was achieved through **hardcoded parameters**:

```verilog
// v10.5: Hardcoded positions
localparam OMEGA_DT_F1 = 354;  // f1 = 13.75 Hz (manually tuned)
localparam SIE_ENHANCE_F1 = 49152;  // 3.0x (empirically determined)
```

The v10.5 system is a "photograph" of the correct state but doesn't contain the underlying physics that creates it.

### 1.2 The Goal of v11.0

v11.0 implements the **energy landscape dynamics** that make the phi^n positions emerge naturally:

```verilog
// v11.0: Computed from physics
wire signed [WIDTH-1:0] force = energy_landscape.force_packed[i];
drift_new = drift + K_FORCE * force;  // Force drives toward stable positions
```

Now the system is a "simulation" of phi^n dynamics, not just a snapshot.

---

## 2. New Modules

### 2.1 Energy Landscape (`energy_landscape.v`)

**Purpose:** Compute restoring forces based on the phi^n energy potential.

**Physics:**
```
E_phi(n) = -A * cos(2*pi*n)
- Minima at half-integers (attractors): n = 0.5, 1.5, 2.5...
- Maxima at integers (boundaries): n = 0, 1, 2...

E_h(n) = B / (phi^n - 2)^2
- Catastrophic near n = 1.44 (where phi^n = 2.0)
- Drives f1 away from n = 1.5 toward n = 1.25

Force F(n) = -dE/dn = 2*pi*A*sin(2*pi*n) + harmonic_repulsion
```

**Implementation:**
- Uses quarter-wave sine LUT for efficient force computation
- Separate phi-landscape and harmonic repulsion components
- Per-oscillator force outputs (packed for 5 cortical layers)
- Catastrophe zone detection (n in [1.35, 1.55])

**Parameters:**
| Parameter | Q14 Value | Decimal | Purpose |
|-----------|-----------|---------|---------|
| FORCE_SCALE_A | 8192 | 0.5 | phi-landscape amplitude |
| FORCE_SCALE_B | 16384 | 1.0 | Harmonic repulsion strength |
| CATASTROPHE_N_MIN | 22118 | 1.35 | Danger zone lower bound |
| CATASTROPHE_N_MAX | 25395 | 1.55 | Danger zone upper bound |

**Ports:**
```verilog
module energy_landscape #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter NUM_OSCILLATORS = 5,
    parameter ENABLE_ADAPTIVE = 1
)(
    input  wire clk, rst, clk_en,
    input  wire signed [NUM_OSCILLATORS*WIDTH-1:0] n_packed,
    input  wire signed [NUM_OSCILLATORS*WIDTH-1:0] drift_packed,
    output wire signed [NUM_OSCILLATORS*WIDTH-1:0] force_packed,
    output wire signed [NUM_OSCILLATORS*WIDTH-1:0] energy_packed,
    output wire [NUM_OSCILLATORS-1:0] near_harmonic_2_1
);
```

---

### 2.2 Quarter-Integer Detector (`quarter_integer_detector.v`)

**Purpose:** Classify oscillator positions in the phi^n energy landscape.

**Classification System:**
| Code | Class | n values | Stability |
|------|-------|----------|-----------|
| 2'b00 | INTEGER_BOUNDARY | 0, 1, 2, 3... | Low (0-0.125) |
| 2'b01 | HALF_INTEGER | 0.5, 1.5, 2.5... | High (0.875-1.0) |
| 2'b10 | QUARTER_INTEGER | 0.25, 0.75, 1.25... | Medium (0.25-0.5) |
| 2'b11 | NEAR_CATASTROPHE | [1.35, 1.55] | Very Low |

**Stability Metric:**
```
stability = 1.0 - |distance_from_nearest_attractor| / 0.5
- Half-integer (distance = 0): stability = 1.0
- Quarter-integer (distance = 0.25): stability = 0.5
- Integer boundary (distance = 0.5): stability = 0.0
```

**Ports:**
```verilog
module quarter_integer_detector #(
    parameter WIDTH = 18,
    parameter FRAC = 14,
    parameter NUM_OSCILLATORS = 5
)(
    input  wire clk, rst, clk_en,
    input  wire signed [NUM_OSCILLATORS*WIDTH-1:0] n_packed,
    output wire [NUM_OSCILLATORS*2-1:0] position_class_packed,
    output wire signed [NUM_OSCILLATORS*WIDTH-1:0] stability_packed,
    output wire [NUM_OSCILLATORS-1:0] is_integer_boundary,
    output wire [NUM_OSCILLATORS-1:0] is_half_integer,
    output wire [NUM_OSCILLATORS-1:0] is_quarter_integer,
    output wire [NUM_OSCILLATORS-1:0] is_near_catastrophe
);
```

---

### 2.3 Coupling Susceptibility (`coupling_susceptibility.v`)

**Purpose:** Compute chi(r) coupling susceptibility for frequency ratios.

**Physics:**
```
chi(r) = proximity to simple rational ratios (Farey fractions)
- High chi at integer ratios (1:1, 2:1, 3:1): strong coupling, unstable
- Low chi at half-integer ratios: weak coupling, stable
- Intermediate chi at quarter-integers: moderate coupling
```

**Key Results:**
- chi(1.0) > chi(0.5) by factor of 3+ (validates boundary vs attractor)
- chi(1.25) intermediate between boundaries and attractors
- chi(2.0) shows spike (2:1 harmonic proximity)

**Implementation:**
- 256-entry LUT indexed by ratio
- Position classification output
- Aggregate statistics (chi_max, chi_min, chi_max_index)

---

### 2.4 Quarter-Wave Sine LUT (`sin_quarter_lut.v`)

**Purpose:** Efficient sine computation for energy landscape forces.

**Implementation:**
- 256 entries covering [0, pi/2]
- Full sine reconstruction via symmetry
- 18-bit Q14 output: [-16384, +16384]

**Usage:**
```verilog
// Input: 10-bit phase (0-1023 representing 0 to 2*pi)
// Output: sin(phase * 2*pi / 1024) in Q14
sin_quarter_lut sin_lut (
    .phase(phase_10bit),
    .sin_out(sin_q14)
);
```

---

## 3. Modified Modules

### 3.1 phi_n_neural_processor.v (v10.5 -> v11.0)

**Changes:**
1. Added `ENABLE_ADAPTIVE` parameter
2. Instantiates energy_landscape for 5 cortical layers
3. Instantiates quarter_integer_detector for position classification
4. Routes forces to cortical_frequency_drift

**New Parameter:**
```verilog
parameter ENABLE_ADAPTIVE = 0  // 0 = v10.5 static, 1 = v11.0 adaptive
```

**New Instantiations:**
```verilog
energy_landscape #(
    .NUM_OSCILLATORS(5),
    .ENABLE_ADAPTIVE(ENABLE_ADAPTIVE)
) energy_landscape_cortical (
    .n_packed(n_cortical_packed),
    .drift_packed(drift_cortical_packed),
    .force_packed(force_cortical_packed),
    .energy_packed(energy_cortical_packed),
    .near_harmonic_2_1(near_harmonic_2_1_cortical)
);

quarter_integer_detector #(
    .NUM_OSCILLATORS(5)
) quarter_int_cortical (
    .n_packed(n_cortical_packed),
    .stability_packed(cortical_stability_packed),
    .is_half_integer(cortical_is_half_integer),
    .is_quarter_integer(cortical_is_quarter_integer)
);
```

**Exponent Mapping:**
| Layer | Frequency | phi^n | n (Q14) |
|-------|-----------|-------|---------|
| L6 | 9.53 Hz | phi^0.5 | 8192 |
| L5a | 15.42 Hz | phi^1.5 | 24576 |
| L5b | 24.94 Hz | phi^2.5 | 40960 |
| L4 | 31.73 Hz | phi^3.0 | 49152 |
| L2/3 | 40.36 Hz | phi^3.5 | 57344 |

---

### 3.2 cortical_frequency_drift.v (v2.1 -> v3.0)

**Changes:**
1. Added `ENABLE_ADAPTIVE` parameter
2. Added force inputs (force_l6, force_l5a, force_l5b, force_l4, force_l23)
3. Force contribution added to drift update

**New Parameter:**
```verilog
parameter ENABLE_ADAPTIVE = 0
```

**New Ports:**
```verilog
input wire signed [WIDTH-1:0] force_l6,
input wire signed [WIDTH-1:0] force_l5a,
input wire signed [WIDTH-1:0] force_l5b,
input wire signed [WIDTH-1:0] force_l4,
input wire signed [WIDTH-1:0] force_l23
```

**Force Integration:**
```verilog
localparam signed [WIDTH-1:0] K_FORCE = 18'sd1638;  // 0.1 in Q14

// When ENABLE_ADAPTIVE = 1:
drift_l6 <= drift_l6 + step*direction + (K_FORCE * force_l6 >>> FRAC);
```

---

### 3.3 sr_harmonic_bank.v (v7.6 -> v7.7)

**Changes:**
1. Added `ENABLE_ADAPTIVE` parameter
2. Added stability_packed input from quarter_integer_detector
3. Dynamic SIE enhancement computation
4. Added sie_enhance_packed output

**Dynamic Enhancement Formula:**
```verilog
// Enhancement = BASE + K_INSTABILITY * (1 - stability)
localparam SIE_BASE_ENHANCE = 18'sd19661;     // 1.2x
localparam SIE_K_INSTABILITY = 18'sd29491;    // 1.8x

instability = ONE_Q14 - stability;
enhance_contrib = SIE_K_INSTABILITY * instability;
enhance_computed = SIE_BASE_ENHANCE + (enhance_contrib >>> FRAC);
```

**Computed vs Hardcoded Enhancement:**
| Harmonic | Stability | Computed | Hardcoded | Match |
|----------|-----------|----------|-----------|-------|
| f0 (boundary) | 0.0 | 3.0x | 2.7x | ~10% |
| f1 (quarter) | 0.5 | 2.1x | 3.0x | ~30% |
| f2 (half-int) | 1.0 | 1.2x | 1.25x | ~4% |

---

### 3.4 sr_frequency_drift.v (v1.x -> v2.0)

**Changes:**
1. Faster UPDATE_PERIOD: 1500 -> 400 cycles
2. Larger DRIFT_MAX bounds: 1.5x wider for visible spectrogram wobble
3. Variable step sizes (1-4) for Levy flight-like behavior

**New Drift Ranges:**
| Harmonic | Old Range | New Range | Change |
|----------|-----------|-----------|--------|
| f0 | +/-0.6 Hz | +/-0.9 Hz | +50% |
| f1 | +/-0.75 Hz | +/-1.1 Hz | +47% |
| f2 | +/-1.0 Hz | +/-1.5 Hz | +50% |
| f3 | +/-1.5 Hz | +/-2.25 Hz | +50% |
| f4 | +/-2.0 Hz | +/-3.0 Hz | +50% |

---

## 4. Test Coverage

### 4.1 New Testbenches

| Testbench | Tests | V-Criteria | Focus |
|-----------|-------|------------|-------|
| tb_coupling_susceptibility.v | 10 | V1 | chi(r) correctness |
| tb_energy_landscape.v | 12 | V2 | Force direction and magnitude |
| tb_quarter_integer_detector.v | 8 | V3-V4 | Position classification |
| tb_self_organization.v | 10 | V5 | Full integration |

**Total: 40 new tests**

### 4.2 Validation Criteria

**V1: chi(r) Correctness**
- [x] chi(1.0) > chi(0.5) by factor of 3+
- [x] chi(1.25) intermediate between chi(1.0) and chi(1.5)
- [x] chi(1.44) shows spike (2:1 proximity)

**V2: Force Direction**
- [x] F(n=0.3) < 0 (pushes toward 0.5)
- [x] F(n=0.7) > 0 (pushes toward 0.5)
- [x] F(n=1.5) shows catastrophe repulsion toward n=1.25

**V3: Position Classification**
- [x] Integer boundaries correctly detected
- [x] Half-integer attractors correctly detected
- [x] Quarter-integer fallbacks correctly detected
- [x] Catastrophe zone correctly flagged

**V4: Stability Ordering**
- [x] stability(half-integer) > stability(quarter-integer)
- [x] stability(quarter-integer) > stability(integer)

**V5: Full Self-Organization**
- [x] Multiple oscillators simultaneously classified
- [x] Force directions consistent across layers
- [x] Stability metrics inversely correlate with coupling

---

## 5. Resource Impact

### 5.1 New Module Resources

| Module | LUTs | Registers | DSPs | BRAMs |
|--------|------|-----------|------|-------|
| energy_landscape | 300 | 100 | 1 | 0.5 |
| quarter_integer_detector | 100 | 30 | 0 | 0 |
| sin_quarter_lut | 50 | 20 | 0 | 0.5 |
| coupling_susceptibility | 200 | 50 | 0 | 1 |
| cortical_frequency_drift (extra) | 100 | 50 | 1 | 0 |
| sr_harmonic_bank changes | 50 | 20 | 0 | 0 |
| **Total New** | **800** | **270** | **2** | **2** |

### 5.2 Total Utilization (Z7-20)

| Resource | v10.5 | v11.0 | Available | Utilization |
|----------|-------|-------|-----------|-------------|
| LUTs | ~3,000 | ~3,800 | 53,200 | 7% |
| Registers | ~800 | ~1,070 | 106,400 | 1% |
| DSPs | 4 | 6 | 220 | 3% |
| BRAMs | 2 | 4 | 140 | 3% |

**Verdict:** Well within budget. Z7-20 has ample capacity.

---

## 6. Usage

### 6.1 Enabling Active Dynamics

```verilog
// In top-level instantiation:
phi_n_neural_processor #(
    .ENABLE_ADAPTIVE(1)  // Enable active phi^n dynamics
) processor (
    // ... ports ...
);
```

### 6.2 Monitoring Force Outputs

```verilog
// Access force values for debugging:
wire signed [WIDTH-1:0] force_l6 = dut.force_cortical_packed[0*WIDTH +: WIDTH];
wire signed [WIDTH-1:0] force_l5a = dut.force_cortical_packed[1*WIDTH +: WIDTH];
// etc.
```

### 6.3 Position Classification

```verilog
// Access position classification:
wire [1:0] l6_class = dut.cortical_position_class[0*2 +: 2];
wire [1:0] l5a_class = dut.cortical_position_class[1*2 +: 2];
// 00 = integer boundary, 01 = half-integer, 10 = quarter-integer, 11 = catastrophe
```

---

## 7. Changelog

| Issue | Description | Resolution |
|-------|-------------|------------|
| v10.5 hardcoded | Frequencies and SIE values hardcoded | Energy landscape computes forces dynamically |
| Static positions | Oscillators at fixed positions | Forces drive toward natural attractors |
| Fixed SIE | SIE_ENHANCE constants hardcoded | Dynamic enhancement from stability metric |

---

## 8. References

- v10.5 Quarter-Integer phi^n Theory: `docs/SPEC_v10.5_UPDATE.md`
- v10.4 Geophysical SR Integration: `docs/SPEC_v10.4_UPDATE.md`
- Base Architecture v8.0: `docs/FPGA_SPECIFICATION_V8.md`
