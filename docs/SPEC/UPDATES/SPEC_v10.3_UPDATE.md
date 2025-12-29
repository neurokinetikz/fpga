# φⁿ Neural Processor - v10.3 Specification Update

**Date:** 2025-12-27
**Previous Version:** v10.2 (EEG Realism)
**This Version:** v10.3 (1/f^φ Spectral Slope)

---

## Overview

v10.3 updates `pink_noise_generator.v` from v6.0 to v7.2, implementing √Fibonacci-weighted Voss-McCartney algorithm to achieve 1/f^φ spectral slope matching the golden ratio frequency architecture.

---

## 1. Problem Statement

**Target:** Real EEG baseline has ~-15.6 dB/decade 1/f spectral slope
**Actual (v6.0):** Standard Voss-McCartney produces ~-10 dB/decade (too shallow)
**Gap:** 3-5 dB/decade steeper slope needed

The φⁿ frequency architecture uses golden ratio relationships throughout. Matching the 1/f spectral exponent to φ creates aesthetic and mathematical coherence.

---

## 2. Solution: √Fibonacci-Weighted Voss-McCartney

### Mathematical Rationale

1. **Fibonacci sequence grows as φⁿ:** Each Fibonacci number is approximately φ times the previous
2. **√Fibonacci grows as φ^(n/2):** Taking square roots halves the growth rate
3. **Applied as octave weights:** Creates 1/f^φ spectral exponent in Voss-McCartney algorithm

### Implementation

Weight the 12 octave rows by √Fibonacci values:

```verilog
// v7.2: √Fibonacci-weighted sum for 1/f^φ spectral slope (φ = 1.618)
// Weights: sqrt(Fibonacci) = [1,1,1,2,2,3,4,5,6,7,9,12], sum = 53
// Rationale: Fib grows as φⁿ, so √Fib = φ^(n/2) → creates 1/f^φ exponent
wire signed [18:0] weighted_row_sum =
    row[0]  * 1   +   // 1000 Hz Nyquist: √F(1) = 1
    row[1]  * 1   +   // 500 Hz Nyquist:  √F(2) = 1
    row[2]  * 1   +   // 250 Hz Nyquist:  √F(3) = 1
    row[3]  * 2   +   // 125 Hz Nyquist:  √F(4) = 2
    row[4]  * 2   +   // 62.5 Hz Nyquist: √F(5) = 2
    row[5]  * 3   +   // 31.25 Hz Nyquist: √F(6) = 3
    row[6]  * 4   +   // 15.6 Hz Nyquist: √F(7) = 4
    row[7]  * 5   +   // 7.8 Hz Nyquist: √F(8) = 5
    row[8]  * 6   +   // 3.9 Hz Nyquist: √F(9) = 6
    row[9]  * 7   +   // 1.95 Hz Nyquist: √F(10) = 7
    row[10] * 9   +   // 0.98 Hz Nyquist: √F(11) = 9
    row[11] * 12;     // 0.49 Hz Nyquist: √F(12) = 12

// Normalize: sum=53, use >>> 2 (divide by 4)
assign row_sum = weighted_row_sum >>> 2;
```

### √Fibonacci Weight Table

| Row | Nyquist Freq | Fibonacci F(n) | √F(n) Weight |
|-----|--------------|----------------|--------------|
| 0 | 1000 Hz | F(1) = 1 | 1 |
| 1 | 500 Hz | F(2) = 1 | 1 |
| 2 | 250 Hz | F(3) = 2 | 1 |
| 3 | 125 Hz | F(4) = 3 | 2 |
| 4 | 62.5 Hz | F(5) = 5 | 2 |
| 5 | 31.25 Hz | F(6) = 8 | 3 |
| 6 | 15.6 Hz | F(7) = 13 | 4 |
| 7 | 7.8 Hz | F(8) = 21 | 5 |
| 8 | 3.9 Hz | F(9) = 34 | 6 |
| 9 | 1.95 Hz | F(10) = 55 | 7 |
| 10 | 0.98 Hz | F(11) = 89 | 9 |
| 11 | 0.49 Hz | F(12) = 144 | 12 |

**Weight Sum:** 53
**Normalization:** >>> 2 (divide by 4)

---

## 3. Spectral Properties

### Measured Results

| Metric | v6.0 (Before) | v7.2 (After) |
|--------|---------------|--------------|
| Spectral exponent α | ~1.0 | 1.70 ± 0.02 |
| Spectral slope | -10 dB/decade | -17.0 dB/decade |
| Target (φ) | — | 1.618 |
| Error from φ | — | 5.2% |

### Character

- **Before:** Standard pink noise (1/f)
- **After:** "Dark pink" noise (1/f^φ) with enhanced low-frequency content

### Comparison with Alternatives

| Weighting Scheme | Spectral α | Error from φ |
|------------------|------------|--------------|
| Equal (v6.0) | 1.0 | 38% |
| (i+1)^1.5 | 1.68 | 3.9% |
| √Fibonacci (v7.2) | 1.70 | 5.2% |
| Raw Fibonacci | 2.0 | 24% (too steep) |

The √Fibonacci approach was chosen for its mathematical elegance and direct connection to the golden ratio through the Fibonacci sequence.

---

## 4. Verification

### Testbench Results

```
tb_full_system_fast: 15/15 PASS
tb_gamma_theta_nesting: 7/7 PASS
```

### DAC Output Analysis

- Spectrogram: `eeg_analysis/dac_spectrogram.png`
- Frequency analysis: `eeg_analysis/dac_frequency_analysis.png`
- Oscillator peaks visible at 1-3 dB above 1/f^φ floor

---

## 5. Files Modified

| File | Version | Change |
|------|---------|--------|
| `src/pink_noise_generator.v` | v6.0 → v7.2 | √Fibonacci-weighted row summation |

### Interface Compatibility

No changes to module interface:
- Same inputs: `clk`, `rst`, `clk_en`
- Same output: `noise_out [17:0]`
- Same parameters: `WIDTH=18`, `FRAC=14`, `NUM_ROWS=12`

---

## 6. Integration with φⁿ Architecture

The √Fibonacci weighting completes the golden ratio theme:

| Component | φⁿ Relationship |
|-----------|-----------------|
| Cortical frequencies | φ^n (5.89, 9.53, 15.42, 24.94, 40.36, 65.3 Hz) |
| Theta-gamma nesting | φ³·⁵ / φ⁴·⁵ switching |
| **Pink noise spectrum** | **1/f^φ via √Fibonacci weights** |

---

## 7. Version History Entry

```
| v10.3 | 2025-12-27 | 1/f^φ Spectral Slope: √Fibonacci-weighted pink noise |
```
