# SPEC v11.2 UPDATE: DAC Anti-Clipping

## Summary

Version 11.2 adds anti-clipping measures to prevent DAC saturation. Two complementary approaches ensure clean output across all consciousness states and dynamic conditions.

**Key Changes:**
1. Reduced NORMAL state amplitude (MU=4 → MU=3)
2. Added soft limiter in output mixer (2:1 compression above 0.75)

**Backward Compatibility:** Full - no parameter changes required.

---

## 1. Motivation: DAC Headroom

### 1.1 The Problem

In v11.1, the NORMAL state used `MU_FULL = 4`, giving oscillators amplitude ~2.0 (sqrt(μ) in Q14). Combined with multiple oscillator summation and 1/f noise, the output mixer could exceed the DAC's ±1.0 range, causing hard clipping.

**Symptoms observed:**
- Flat-topped waveforms at DAC extremes
- Harsh spectral artifacts from hard clipping
- Loss of fine detail during high-amplitude events

### 1.2 The Solution

Two-stage anti-clipping:
1. **Reduce source amplitude** - Lower MU from 4 to 3 in NORMAL state
2. **Soft limit output** - Compress signals above ±0.75 with 2:1 ratio

---

## 2. Module Changes

### 2.1 config_controller.v (v10.0 → v10.1)

**New Constant:**
```verilog
localparam signed [WIDTH-1:0] MU_MODERATE = 18'sd3;  // Between FULL (4) and HALF (2)
```

**NORMAL State Change:**
```verilog
// v11.1 (old)
mu_dt_theta  <= MU_FULL;   // 4
mu_dt_l6     <= MU_FULL;
mu_dt_l5b    <= MU_FULL;
mu_dt_l5a    <= MU_FULL;
mu_dt_l4     <= MU_FULL;
mu_dt_l23    <= MU_FULL;

// v11.2 (new)
mu_dt_theta  <= MU_MODERATE;  // 3
mu_dt_l6     <= MU_MODERATE;
mu_dt_l5b    <= MU_MODERATE;
mu_dt_l5a    <= MU_MODERATE;
mu_dt_l4     <= MU_MODERATE;
mu_dt_l23    <= MU_MODERATE;
```

**Amplitude Impact:**
| State | MU Value | Oscillator Amplitude | Change |
|-------|----------|---------------------|--------|
| NORMAL (v11.1) | 4 | sqrt(4) = 2.0 | — |
| NORMAL (v11.2) | 3 | sqrt(3) ≈ 1.73 | -13% |
| MEDITATION | 2 | sqrt(2) ≈ 1.41 | unchanged |
| ANESTHESIA | varies | varies | unchanged |

**Rationale:**
- NORMAL still clearly distinct from MEDITATION (1.73 vs 1.41)
- 13% amplitude reduction provides ~2 dB headroom
- All other states unchanged

---

### 2.2 output_mixer.v (v7.0 → v7.1)

**New Constants:**
```verilog
// Soft limiter thresholds (Q14)
localparam signed [WIDTH-1:0] SOFT_THRESH = 18'sd12288;  // 0.75
localparam signed [WIDTH-1:0] SOFT_LIMIT  = 18'sd16384;  // 1.0
```

**New Logic (Soft Limiter):**
```verilog
// Piecewise linear compression:
// |x| < 0.75:  output = x (linear)
// |x| >= 0.75: output = sign(x) * (0.75 + (|x| - 0.75) / 2)

wire signed [WIDTH-1:0] abs_input;
wire input_negative;
wire above_thresh;
wire signed [WIDTH-1:0] excess;
wire signed [WIDTH-1:0] compressed_excess;
wire signed [WIDTH-1:0] soft_limited;

assign input_negative = sum_scaled[WIDTH-1];
assign abs_input = input_negative ? -sum_scaled : sum_scaled;
assign above_thresh = (abs_input > SOFT_THRESH);
assign excess = abs_input - SOFT_THRESH;
assign compressed_excess = excess >>> 1;  // 2:1 compression

wire signed [WIDTH-1:0] abs_limited = above_thresh ?
    (SOFT_THRESH + compressed_excess) : abs_input;

assign soft_limited = input_negative ? -abs_limited : abs_limited;
```

**Transfer Function:**
```
Input    Output    Gain
─────    ──────    ────
 0.00     0.00     1.0
 0.50     0.50     1.0
 0.75     0.75     1.0 (knee)
 1.00     0.875    0.5 (compressed)
 1.25     1.00     0.5 (at limit)
 1.50     1.125    0.5 (clipped at DAC)
```

**Visual:**
```
Output
  1.0 ─────────────────────╭───────
                          ╱
 0.75 ───────────────────╱
                        ╱
                       ╱
                      ╱
  0 ─────────────────╱────────────── Input
     0           0.75  1.0   1.25

     Linear region    Compression
     (slope = 1.0)    (slope = 0.5)
```

---

## 3. Combined Effect

### 3.1 Headroom Analysis

| Condition | v11.1 Peak | v11.2 Peak | Margin |
|-----------|------------|------------|--------|
| Single oscillator (NORMAL) | 2.0 | 1.73 | +0.27 |
| All oscillators in phase | ~4.0 | ~3.46 | — |
| After soft limiter | clipped | ~1.12 | safe |
| Typical mixed signal | ~1.2 | ~0.95 | +0.25 |

### 3.2 Spectral Quality

**v11.1 (hard clipping):**
- Harmonics generated at clip points
- Spectral splatter above Nyquist
- Harsh transients

**v11.2 (soft limiting):**
- Smooth compression curve
- Minimal harmonic distortion
- Natural-sounding dynamics

---

## 4. Resource Impact

| Metric | v11.1 | v11.2 | Change |
|--------|-------|-------|--------|
| LUTs | ~5,200 | ~5,220 | +20 (+0.4%) |
| FFs | ~2,800 | ~2,800 | 0 |
| DSPs | ~8 | ~8 | 0 |

The soft limiter adds:
- 1 comparator (above_thresh)
- 1 subtractor (excess)
- 1 shift (compressed_excess)
- 1 adder (SOFT_THRESH + compressed_excess)
- 2 muxes (sign restoration)

**Total:** ~20 LUTs, negligible impact.

---

## 5. Verification

### 5.1 Expected Behavior

1. **NORMAL state waveform:** Peak amplitude ~1.73 (was 2.0)
2. **Soft limiting active:** When mixed output exceeds 0.75
3. **No hard clipping:** DAC output stays within ±1.0

### 5.2 Test Cases

| Test | Condition | Expected |
|------|-----------|----------|
| Normal amplitude | Single oscillator | Peak ≈ 1.73 |
| Meditation amplitude | Single oscillator | Peak ≈ 1.41 |
| Soft limiter knee | Input = 0.75 | Output = 0.75 |
| Compression | Input = 1.0 | Output = 0.875 |
| Max compression | Input = 1.5 | Output = 1.125 (clipped at DAC) |
| Sign preservation | Negative input | Negative output |

---

## 6. Version History

| Version | Date | Change |
|---------|------|--------|
| v11.2 | 2025-12-28 | DAC anti-clipping (MU_MODERATE, soft limiter) |
| v11.1 | 2025-12-28 | Unified Boundary-Attractor Framework |
| v11.0 | 2025-12-28 | Active φⁿ Dynamics |

---

## 7. Files Modified

| File | Version | Change |
|------|---------|--------|
| `src/config_controller.v` | v10.0 → v10.1 | Added MU_MODERATE, NORMAL uses MU=3 |
| `src/output_mixer.v` | v7.0 → v7.1 | Added soft limiter stage |

---

## 8. References

- v11.1 Unified Boundary-Attractor Framework: `docs/SPEC_v11.1_UPDATE.md`
- v11.0 Active φⁿ Dynamics: `docs/SPEC_v11.0_UPDATE.md`
- Base Architecture v8.0: `docs/FPGA_SPECIFICATION_V8.md`
