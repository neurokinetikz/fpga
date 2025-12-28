# FPGA Resource Budget - v10.3

**Target Platform:** Digilent Zybo Z7-20 (Xilinx Zynq-7020)
**Design Version:** v10.3 (1/f^φ Spectral Slope)
**Analysis Date:** 2025-12-28

---

## Summary

| Resource | Used | Available | Utilization | Status |
|----------|------|-----------|-------------|--------|
| **LUTs** | 18,700 | 53,200 | 35% | Good |
| **Flip-Flops** | 4,600 | 106,400 | 4% | Excellent |
| **DSP48E1** | 190 | 220 | 86% | Tight |
| **Block RAM** | 2 | 140 | 1% | Excellent |

**Verdict:** Design fits on Zynq-7020. DSP48 is the limiting resource.

---

## 1. Target Platform Specifications

### Xilinx Zynq-7020 (XC7Z020-1CLG400C)

| Resource | Quantity | Notes |
|----------|----------|-------|
| Logic Cells | 85,000 | — |
| LUTs | 53,200 | 6-input lookup tables |
| Flip-Flops | 106,400 | Registers |
| DSP48E1 Slices | 220 | 18×25 signed multiply-accumulate |
| Block RAM | 140 × 36Kb | 4.9 Mb total |
| Distributed RAM | ~400 Kb | LUT-based |
| Clock Management | 4 MMCM, 4 PLL | — |
| I/O Pins | 200 | MIO + EMIO |

---

## 2. Module Hierarchy

### Architecture Overview

```
phi_n_neural_processor (top)
│
├── Clock & Control
│   ├── clock_enable_generator ────────────── (1)
│   ├── config_controller ─────────────────── (1)
│   └── sr_ignition_controller ────────────── (1)
│
├── Thalamus Subsystem
│   ├── thalamus ──────────────────────────── (1)
│   │   ├── hopf_oscillator (theta) ───────── (1)
│   │   ├── sr_harmonic_bank ──────────────── (1)
│   │   │   └── hopf_oscillator_stochastic ── (5) [generate]
│   │   └── amplitude_envelope_generator ──── (1)
│   ├── sr_noise_generator ────────────────── (1)
│   └── sr_frequency_drift ────────────────── (1)
│
├── Cortical Columns (×3: Sensory, Association, Motor)
│   ├── cortical_column ───────────────────── (3)
│   │   ├── hopf_oscillator (L6,L5b,L5a,L4,L2/3) ─ (5) per column
│   │   ├── layer1_minimal ────────────────── (1) per column
│   │   ├── dendritic_compartment ─────────── (3) per column
│   │   ├── pv_interneuron ────────────────── (3) per column
│   │   └── amplitude_envelope_generator ──── (5) per column
│   └── cortical_frequency_drift ──────────── (1)
│
├── Hippocampal Memory
│   └── ca3_phase_memory ──────────────────── (1)
│
├── Noise Generation
│   └── pink_noise_generator ──────────────── (1)
│
└── Output
    ├── output_mixer ──────────────────────── (1)
    └── amplitude_envelope_generator ──────── (4) [mixer bands]
```

### Instantiation Counts

| Module | Instances | Purpose |
|--------|-----------|---------|
| hopf_oscillator | 16 | Core oscillators (1 theta + 15 cortical) |
| hopf_oscillator_stochastic | 5 | SR harmonic bank |
| dendritic_compartment | 9 | Apical/basal separation (3 per column) |
| pv_interneuron | 9 | E-I balance (3 per column) |
| amplitude_envelope_generator | 24 | Breathing dynamics |
| layer1_minimal | 3 | Gain modulation (1 per column) |
| **Total Hopf oscillators** | **21** | **φⁿ frequency bank** |

---

## 3. Oscillator Resource Breakdown

### 21 Hopf Oscillators at φⁿ Frequencies

| Location | Frequency | OMEGA_DT | Purpose |
|----------|-----------|----------|---------|
| Thalamus Theta | 5.89 Hz | 152 | Learn/recall gating |
| SR f₀ | 7.6 Hz | 196 | Schumann fundamental |
| SR f₁ | 13.75 Hz | 354 | Alpha coupling |
| SR f₂ | 20 Hz | 514 | Low beta coupling |
| SR f₃ | 25 Hz | 643 | High beta coupling |
| SR f₄ | 32 Hz | 823 | Gamma coupling |
| Cortex L6 ×3 | 9.53 Hz | 245 | Alpha, gain control |
| Cortex L5a ×3 | 15.42 Hz | 397 | Low beta, motor |
| Cortex L5b ×3 | 24.94 Hz | 642 | High beta, feedback |
| Cortex L4 ×3 | 31.73 Hz | 817 | Thalamocortical |
| Cortex L2/3 ×3 | 40.36/65.3 Hz | 1040/1681 | Gamma (theta-switched) |

### Per-Oscillator Resources

| Metric | hopf_oscillator | hopf_oscillator_stochastic |
|--------|-----------------|---------------------------|
| Registers | 54 bits (3×18) | 54 bits (3×18) |
| Multiplications/cycle | 12 | 12 |
| Additions/cycle | 15 | 16 |
| DSP48 (optimal) | 8-10 | 8-10 |

---

## 4. Detailed Resource Estimation

### 4.1 Register (Flip-Flop) Count

| Module Category | Count | Bits Each | Total Bits |
|-----------------|-------|-----------|------------|
| Hopf Oscillators | 21 | 54 | 1,134 |
| Dendritic Compartments | 9 | 36 | 324 |
| PV+ Interneurons | 9 | 18 | 162 |
| Amplitude Envelopes | 24 | 37 | 888 |
| Layer1 Modules | 3 | 130 | 390 |
| CA3 Phase Memory | 1 | 414 | 414 |
| Config Controller | 1 | 222 | 222 |
| SR Harmonic Bank | 1 | 270 | 270 |
| SR Noise Generator | 1 | 80 | 80 |
| SR Frequency Drift | 1 | 192 | 192 |
| Pink Noise Generator | 1 | 172 | 172 |
| Clock/Ignition/Mixer | 3 | 100 | 300 |
| **TOTAL** | — | — | **4,548** |

**FF Utilization:** 4,600 / 106,400 = **4.3%**

### 4.2 Multiplication Operations (per 4kHz cycle)

| Module | Instances | Mults/Instance | Total |
|--------|-----------|----------------|-------|
| Hopf Oscillators | 21 | 12 | 252 |
| Dendritic Compartments | 9 | 5 | 45 |
| PV+ Interneurons | 9 | 3 | 27 |
| Layer1 Modules | 3 | 8 | 24 |
| Amplitude Envelopes | 24 | 2 | 48 |
| SR Coherence/Gain | 5 | 4 | 20 |
| Pink Noise | 1 | 12 | 12 |
| Output Mixer | 1 | 8 | 8 |
| **TOTAL** | — | — | **436** |

### 4.3 DSP48E1 Mapping Strategy

**Problem:** 436 multiplications but only 220 DSP48s available.

**Solution:** Mixed DSP + LUT strategy

| Category | Multiplies | Resource | Rationale |
|----------|------------|----------|-----------|
| Hopf core (var × var) | 168 | DSP48 | Performance-critical |
| Hopf correction | 42 | DSP48 | Variable operands |
| Dendritic/PV | 72 | LUT | Constant coefficients |
| Envelopes | 48 | LUT | Small constants |
| Layer1 | 24 | LUT | Constants |
| SR/Mixer/Pink | 82 | LUT | Mixed constants |

**Result:** ~190 DSP48s + ~150 LUT multipliers

### 4.4 LUT Estimation

| Category | LUTs | Notes |
|----------|------|-------|
| Register routing | 2,000 | Muxes for 4,600 FFs |
| LUT multipliers | 10,800 | ~150 × 72 LUTs each |
| Adder chains | 2,500 | 18-bit arithmetic |
| Comparators/Muxes | 1,500 | State selection |
| State machines | 500 | CA3, Ignition, Config |
| LFSR generators | 400 | 7 noise LFSRs |
| Misc logic | 1,000 | Routing, buffers |
| **TOTAL** | **18,700** | **35% utilization** |

### 4.5 Block RAM Usage

| Use Case | BRAM | Notes |
|----------|------|-------|
| CA3 weight matrix | 0 | 36 bytes → distributed RAM |
| Pink noise buffers | 0 | 18 bytes → distributed RAM |
| DAC output buffer | 0-2 | Optional double-buffering |
| **TOTAL** | **0-2** | **<2% utilization** |

---

## 5. Resource Margin Analysis

### Expansion Capacity

| Addition | LUT Cost | DSP Cost | Feasible? |
|----------|----------|----------|-----------|
| +1 Cortical Column | +5,000 | +60 | Marginal (DSP limit) |
| +5 SR Harmonics | +2,500 | +30 | Yes |
| +Double envelopes | +1,200 | +24 | Yes |
| AXI interface | +2,000 | 0 | Yes |

### Safety Margins

| Resource | Remaining | Critical Threshold |
|----------|-----------|-------------------|
| LUTs | 34,500 (65%) | <20% for routing |
| FFs | 101,800 (96%) | Ample |
| DSP48 | 30 (14%) | Near limit |
| BRAM | 138 (99%) | Ample |

---

## 6. Timing Considerations

### Clock Domains

| Clock | Frequency | Source | Usage |
|-------|-----------|--------|-------|
| clk_125mhz | 125 MHz | PL fabric | Main logic |
| clk_en_4khz | 4 kHz enable | Divider | Oscillator updates |
| clk_en_100khz | 100 kHz enable | Divider | Noise/mixer updates |

### Critical Paths (Estimated)

| Path | Depth | Concern |
|------|-------|---------|
| Hopf oscillator | 12 mults + 15 adds | Single-cycle, may need pipeline |
| Dendritic chain | 5 mults in series | Moderate |
| Output mixer | 5 weighted sums | Moderate |
| CA3 recall | 6×6 MAC | Gated by theta |

### Timing Closure Strategy

1. **Enable DSP pipelining** - Add MREG/PREG stages
2. **Register critical outputs** - Break long combinatorial paths
3. **Use DSP cascade** - Chain accumulates through dedicated fabric

---

## 7. Power Estimation

### Static Power (Estimated)
- Logic: ~150 mW
- Block RAM: ~10 mW
- DSP: ~50 mW
- I/O: ~20 mW
- **Total Static:** ~230 mW

### Dynamic Power (at 125 MHz)
- 190 DSP48 at 50% activity: ~300 mW
- 18K LUTs at 30% activity: ~200 mW
- 4.6K FFs at 50% activity: ~50 mW
- **Total Dynamic:** ~550 mW

### Total Estimated Power: ~780 mW

---

## 8. Optimization Recommendations

### If DSP Overflow Occurs

1. **Time-divide Hopf oscillators**
   - Share 4 DSPs across 21 oscillators
   - 31,250 cycles between updates allows ~7,800 cycles per oscillator

2. **Use shift-add for near-power-of-2**
   - K_PHASE = 0.25 → shift right 2
   - HALF = 0.5 → shift right 1

3. **LUT-only for small constants**
   - SST_ALPHA = 0.01 → 164 (fits in 8 bits)
   - VIP_ALPHA = 0.005 → 82 (fits in 7 bits)

### For Better Timing

1. Register all DSP outputs
2. Pipeline the amplitude correction stage
3. Use cascaded DSP chains for weighted sums

### For Lower Power

1. Clock-gate unused oscillators by state
2. Use lower activity factor constants
3. Consider 100 MHz instead of 125 MHz

---

## 9. Comparison: Zynq Variants

| Spec | Z7-010 | Z7-020 | Z7-045 |
|------|--------|--------|--------|
| LUTs | 17,600 | 53,200 | 218,600 |
| FFs | 35,200 | 106,400 | 437,200 |
| DSP48 | 80 | 220 | 900 |
| BRAM | 60 | 140 | 545 |
| **This Design** | NO | YES | YES+ |

- **Z7-010:** Insufficient DSPs (80 vs 190 needed)
- **Z7-020:** Fits with 14% DSP margin
- **Z7-045:** Ample room for 4× expansion

---

## 10. Verification Checklist

- [ ] Synthesize with Vivado to confirm estimates
- [ ] Check timing closure at 125 MHz
- [ ] Validate DSP48 inference (vs LUT multipliers)
- [ ] Run power analysis with switching activity
- [ ] Test on hardware with all oscillators active

---

## Version History

| Version | Date | Change |
|---------|------|--------|
| v1.0 | 2025-12-28 | Initial resource budget for v10.3 |
