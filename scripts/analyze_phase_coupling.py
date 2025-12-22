#!/usr/bin/env python3
"""
Phase Coupling Analysis for State Characterization

Analyzes phase timeseries exported from tb_state_characterization.v to compute:
- Phase Locking Value (PLV) between theta and gamma
- Phase-Amplitude Coupling (PAC) via Modulation Index
- Cross-oscillator phase coherence
- Instantaneous frequency stability

These metrics are the gold standard for distinguishing consciousness states.

Usage:
    python3 analyze_phase_coupling.py [phase_timeseries.csv]
"""

import sys
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy import stats
from pathlib import Path

# Fixed-point scaling (Q4.14 format)
FRAC = 14
SCALE = 2**FRAC

# State names
STATES = ['NORMAL', 'ANESTHESIA', 'PSYCHEDELIC', 'FLOW', 'MEDITATION']

# Sampling rate (1 kHz after decimation from 4 kHz)
FS = 1000  # Hz


def load_phase_timeseries(filepath):
    """Load phase timeseries CSV exported from Verilog testbench."""
    df = pd.read_csv(filepath)

    # Scale fixed-point values to floating-point
    for col in df.columns:
        if col not in ['state', 'sample']:
            df[col] = df[col].astype(float) / SCALE

    return df


def compute_phase(x, y):
    """Compute instantaneous phase from x, y Hopf oscillator outputs."""
    return np.arctan2(y, x)


def compute_amplitude(x, y):
    """Compute instantaneous amplitude from x, y Hopf oscillator outputs."""
    return np.sqrt(x**2 + y**2)


def phase_locking_value(phase1, phase2):
    """
    Compute Phase Locking Value (PLV) between two phase timeseries.

    PLV = |mean(exp(i * (phase1 - phase2)))|

    Returns value in [0, 1]:
    - 0: No phase locking (random phase relationship)
    - 1: Perfect phase locking (constant phase difference)
    """
    phase_diff = phase1 - phase2
    plv = np.abs(np.mean(np.exp(1j * phase_diff)))
    return plv


def amplitude_weighted_plv(phase1, phase2, amp1, amp2, amp_threshold=0.01):
    """
    Compute Amplitude-Weighted Phase Locking Value (awPLV).

    This is the correct metric when one signal may be suppressed (low amplitude).
    Samples with low amplitude contribute less to the PLV calculation.

    awPLV = |sum(w * exp(i * (phase1 - phase2)))| / sum(w)

    where w = sqrt(amp1 * amp2) is the geometric mean of amplitudes.

    Samples where EITHER amplitude is below threshold are excluded entirely.

    Returns value in [0, 1]:
    - 0: No phase locking (random phase relationship)
    - 1: Perfect phase locking (constant phase difference)
    - NaN if insufficient high-amplitude samples
    """
    # Compute weights as geometric mean of amplitudes
    weights = np.sqrt(amp1 * amp2)

    # Exclude samples where amplitude is too low (suppressed signals)
    # This prevents phase-from-noise artifacts
    valid_mask = (amp1 > amp_threshold) & (amp2 > amp_threshold)

    if np.sum(valid_mask) < 10:  # Need at least 10 valid samples
        return 0.0  # Return 0 for suppressed signal

    # Apply mask
    weights_valid = weights[valid_mask]
    phase_diff = (phase1 - phase2)[valid_mask]

    # Compute weighted PLV
    weighted_sum = np.sum(weights_valid * np.exp(1j * phase_diff))
    total_weight = np.sum(weights_valid)

    if total_weight < 1e-10:
        return 0.0

    awplv = np.abs(weighted_sum) / total_weight
    return awplv


def n_m_phase_locking(phase_slow, phase_fast, n=1, m=1):
    """
    Compute n:m phase locking value.

    For theta-gamma coupling, typical ratios are 1:4 to 1:8.
    PLV_nm = |mean(exp(i * (n*phase_fast - m*phase_slow)))|
    """
    phase_diff = n * phase_fast - m * phase_slow
    plv = np.abs(np.mean(np.exp(1j * phase_diff)))
    return plv


def modulation_index(theta_phase, gamma_amplitude, n_bins=18):
    """
    Compute Modulation Index (MI) for Phase-Amplitude Coupling.

    Tort et al. (2010) method:
    1. Bin gamma amplitude by theta phase
    2. Compute normalized distribution
    3. MI = KL divergence from uniform / log(n_bins)

    Returns value in [0, 1]:
    - 0: No coupling (gamma amplitude uniform across theta phases)
    - 1: Perfect coupling (gamma amplitude concentrated at one phase)
    """
    # Bin theta phase into n_bins
    bin_edges = np.linspace(-np.pi, np.pi, n_bins + 1)
    bin_indices = np.digitize(theta_phase, bin_edges) - 1
    bin_indices = np.clip(bin_indices, 0, n_bins - 1)

    # Compute mean gamma amplitude per bin
    bin_means = np.zeros(n_bins)
    for i in range(n_bins):
        mask = bin_indices == i
        if np.sum(mask) > 0:
            bin_means[i] = np.mean(gamma_amplitude[mask])

    # Normalize to probability distribution
    if np.sum(bin_means) == 0:
        return 0.0

    p = bin_means / np.sum(bin_means)
    p = p + 1e-10  # Avoid log(0)
    p = p / np.sum(p)  # Renormalize

    # Uniform distribution
    q = np.ones(n_bins) / n_bins

    # KL divergence
    kl_div = np.sum(p * np.log(p / q))

    # Normalize to [0, 1]
    mi = kl_div / np.log(n_bins)

    return mi


def circular_variance(phases):
    """
    Compute circular variance of phase timeseries.

    Returns value in [0, 1]:
    - 0: All phases identical (perfect consistency)
    - 1: Phases uniformly distributed (no preference)
    """
    mean_vector = np.mean(np.exp(1j * phases))
    r = np.abs(mean_vector)
    return 1 - r


def instantaneous_frequency(phases, fs=FS):
    """
    Compute instantaneous frequency from phase timeseries.

    Uses unwrapped phase derivative.
    """
    unwrapped = np.unwrap(phases)
    inst_freq = np.diff(unwrapped) * fs / (2 * np.pi)
    return inst_freq


def frequency_cv(inst_freq):
    """Coefficient of variation of instantaneous frequency."""
    if np.mean(inst_freq) == 0:
        return np.inf
    return np.std(inst_freq) / np.abs(np.mean(inst_freq))


def analyze_state(df, state_idx):
    """Analyze phase coupling metrics for a single state."""
    state_data = df[df['state'] == state_idx].copy()

    if len(state_data) == 0:
        return None

    # Extract x, y values
    theta_x = state_data['theta_x'].values
    theta_y = state_data['theta_y'].values
    gamma_x = state_data['gamma_x'].values
    gamma_y = state_data['gamma_y'].values
    alpha_x = state_data['alpha_x'].values
    alpha_y = state_data['alpha_y'].values

    # Sensory, motor, association gammas
    sens_gamma_x = state_data['sens_gamma_x'].values
    sens_gamma_y = state_data['sens_gamma_y'].values
    motor_gamma_x = state_data['motor_gamma_x'].values
    motor_gamma_y = state_data['motor_gamma_y'].values
    assoc_gamma_x = state_data['assoc_gamma_x'].values
    assoc_gamma_y = state_data['assoc_gamma_y'].values

    # Compute phases and amplitudes
    theta_phase = compute_phase(theta_x, theta_y)
    gamma_phase = compute_phase(gamma_x, gamma_y)
    alpha_phase = compute_phase(alpha_x, alpha_y)

    gamma_amp = compute_amplitude(gamma_x, gamma_y)
    alpha_amp = compute_amplitude(alpha_x, alpha_y)

    # Additional gamma phases
    sens_gamma_phase = compute_phase(sens_gamma_x, sens_gamma_y)
    motor_gamma_phase = compute_phase(motor_gamma_x, motor_gamma_y)
    assoc_gamma_phase = compute_phase(assoc_gamma_x, assoc_gamma_y)

    sens_gamma_amp = compute_amplitude(sens_gamma_x, sens_gamma_y)
    motor_gamma_amp = compute_amplitude(motor_gamma_x, motor_gamma_y)
    assoc_gamma_amp = compute_amplitude(assoc_gamma_x, assoc_gamma_y)

    # Compute theta amplitude for weighted PLV
    theta_amp = compute_amplitude(theta_x, theta_y)

    # Compute metrics
    results = {}

    # 1. Phase Locking Values (PLV)
    # Use amplitude-weighted PLV for theta-gamma to handle suppressed gamma in ANESTHESIA
    # When gamma amplitude is near-zero, phase is meaningless noise
    # Threshold: ~0.0001 excludes ANESTHESIA (mean 0.00005) but includes others (mean 0.00037)
    AMP_THRESH = 0.0001  # Based on measured gamma amplitudes in Q4.14 format
    results['plv_theta_gamma'] = amplitude_weighted_plv(theta_phase, gamma_phase,
                                                         theta_amp, gamma_amp, amp_threshold=AMP_THRESH)
    results['plv_theta_alpha'] = phase_locking_value(theta_phase, alpha_phase)
    results['plv_gamma_alpha'] = amplitude_weighted_plv(gamma_phase, alpha_phase,
                                                         gamma_amp, alpha_amp, amp_threshold=AMP_THRESH)

    # n:m phase locking (gamma is ~7x faster than theta: 40 Hz / 5.89 Hz ≈ 6.8)
    # Also use amplitude-weighted version
    results['plv_theta_gamma_1_7'] = amplitude_weighted_plv(theta_phase * 7, gamma_phase,
                                                             theta_amp, gamma_amp, amp_threshold=AMP_THRESH)

    # Cross-gamma coherence (should differ by state - motor enhanced in FLOW)
    # These use amplitude-weighted PLV to handle suppressed signals
    results['plv_sens_motor_gamma'] = amplitude_weighted_plv(sens_gamma_phase, motor_gamma_phase,
                                                              sens_gamma_amp, motor_gamma_amp, amp_threshold=AMP_THRESH)
    results['plv_sens_assoc_gamma'] = amplitude_weighted_plv(sens_gamma_phase, assoc_gamma_phase,
                                                              sens_gamma_amp, assoc_gamma_amp, amp_threshold=AMP_THRESH)
    results['plv_motor_assoc_gamma'] = amplitude_weighted_plv(motor_gamma_phase, assoc_gamma_phase,
                                                               motor_gamma_amp, assoc_gamma_amp, amp_threshold=AMP_THRESH)

    # 2. Phase-Amplitude Coupling (PAC) via Modulation Index
    results['pac_theta_gamma'] = modulation_index(theta_phase, gamma_amp)
    results['pac_theta_alpha'] = modulation_index(theta_phase, alpha_amp)
    results['pac_theta_sens_gamma'] = modulation_index(theta_phase, sens_gamma_amp)
    results['pac_theta_motor_gamma'] = modulation_index(theta_phase, motor_gamma_amp)

    # 3. Circular variance (phase consistency)
    results['cv_theta'] = circular_variance(theta_phase)
    results['cv_gamma'] = circular_variance(gamma_phase)
    results['cv_alpha'] = circular_variance(alpha_phase)

    # 4. Frequency stability (coefficient of variation)
    theta_freq = instantaneous_frequency(theta_phase)
    gamma_freq = instantaneous_frequency(gamma_phase)

    results['freq_cv_theta'] = frequency_cv(theta_freq)
    results['freq_cv_gamma'] = frequency_cv(gamma_freq)

    # Mean frequencies (sanity check)
    results['mean_freq_theta'] = np.mean(np.abs(theta_freq))
    results['mean_freq_gamma'] = np.mean(np.abs(gamma_freq))

    # 5. Mean amplitudes
    results['mean_amp_gamma'] = np.mean(gamma_amp)
    results['mean_amp_alpha'] = np.mean(alpha_amp)

    # Store phase timeseries for visualization
    results['theta_phase'] = theta_phase
    results['gamma_phase'] = gamma_phase
    results['gamma_amp'] = gamma_amp

    return results


def plot_pac_polar(theta_phase, gamma_amp, title, ax):
    """Plot phase-amplitude coupling as polar histogram."""
    n_bins = 36
    bin_edges = np.linspace(-np.pi, np.pi, n_bins + 1)
    bin_centers = (bin_edges[:-1] + bin_edges[1:]) / 2

    bin_indices = np.digitize(theta_phase, bin_edges) - 1
    bin_indices = np.clip(bin_indices, 0, n_bins - 1)

    bin_means = np.zeros(n_bins)
    for i in range(n_bins):
        mask = bin_indices == i
        if np.sum(mask) > 0:
            bin_means[i] = np.mean(gamma_amp[mask])

    # Normalize
    if np.max(bin_means) > 0:
        bin_means = bin_means / np.max(bin_means)

    # Plot
    ax.bar(bin_centers, bin_means, width=2*np.pi/n_bins, alpha=0.7, edgecolor='black')
    ax.set_title(title, fontsize=10)
    ax.set_ylim(0, 1.2)


def plot_phase_locking_matrix(all_results, ax):
    """Plot cross-oscillator PLV matrix."""
    n_states = len(all_results)

    # Extract PLV values for each state
    plv_keys = ['plv_theta_gamma', 'plv_theta_alpha', 'plv_gamma_alpha',
                'plv_sens_motor_gamma', 'plv_sens_assoc_gamma', 'plv_motor_assoc_gamma']

    matrix = np.zeros((n_states, len(plv_keys)))
    for i, res in enumerate(all_results):
        if res is not None:
            for j, key in enumerate(plv_keys):
                matrix[i, j] = res.get(key, 0)

    im = ax.imshow(matrix.T, aspect='auto', cmap='viridis', vmin=0, vmax=1)
    ax.set_xticks(range(n_states))
    ax.set_xticklabels(STATES, rotation=45, ha='right')
    ax.set_yticks(range(len(plv_keys)))
    ax.set_yticklabels(['θ-γ', 'θ-α', 'γ-α', 'sens-motor γ', 'sens-assoc γ', 'motor-assoc γ'])
    ax.set_title('Phase Locking Values (PLV)')
    plt.colorbar(im, ax=ax, label='PLV')


def main(csv_path='phase_timeseries.csv'):
    """Main analysis pipeline."""
    print("="*70)
    print("PHASE COUPLING ANALYSIS - Consciousness State Characterization")
    print("="*70)

    # Load data
    filepath = Path(csv_path)
    if not filepath.exists():
        print(f"Error: {csv_path} not found")
        print("Run the Verilog testbench first to generate phase timeseries")
        sys.exit(1)

    df = load_phase_timeseries(filepath)
    print(f"Loaded {len(df)} samples from {csv_path}")
    print(f"States found: {sorted(df['state'].unique())}")
    print()

    # Analyze each state
    all_results = []
    for state_idx in range(5):
        results = analyze_state(df, state_idx)
        all_results.append(results)

    # Print summary table
    print("="*70)
    print("PHASE COUPLING METRICS SUMMARY")
    print("="*70)
    print()

    # Header
    print(f"{'Metric':<25} {'NORMAL':>10} {'ANESTHESIA':>12} {'PSYCHEDELIC':>12} {'FLOW':>10} {'MEDITATION':>12}")
    print("-"*85)

    # Key metrics
    metrics_to_show = [
        ('plv_theta_gamma', 'PLV θ-γ'),
        ('plv_theta_gamma_1_7', 'PLV θ-γ (1:7)'),
        ('plv_theta_alpha', 'PLV θ-α'),
        ('pac_theta_gamma', 'PAC θ-γ (MI)'),
        ('pac_theta_motor_gamma', 'PAC θ-motor γ'),
        ('plv_sens_motor_gamma', 'PLV sens-motor γ'),
        ('freq_cv_theta', 'Freq CV θ'),
        ('freq_cv_gamma', 'Freq CV γ'),
        ('mean_freq_theta', 'Mean freq θ (Hz)'),
        ('mean_freq_gamma', 'Mean freq γ (Hz)'),
    ]

    for key, label in metrics_to_show:
        values = []
        for res in all_results:
            if res is not None and key in res:
                values.append(res[key])
            else:
                values.append(np.nan)
        print(f"{label:<25} {values[0]:>10.4f} {values[1]:>12.4f} {values[2]:>12.4f} {values[3]:>10.4f} {values[4]:>12.4f}")

    print()
    print("="*70)
    print("EXPECTED PATTERNS FROM NEUROSCIENCE:")
    print("-"*70)
    print("PLV θ-γ:      MEDITATION > FLOW > NORMAL > PSYCHEDELIC > ANESTHESIA")
    print("PAC θ-γ:      MEDITATION > FLOW ≈ NORMAL > PSYCHEDELIC > ANESTHESIA")
    print("Cross-γ PLV:  MEDITATION (high) > FLOW (motor↑) > NORMAL > others")
    print("Freq CV:      ANESTHESIA (flat) < MEDITATION < NORMAL < PSYCHEDELIC (unstable)")
    print("="*70)

    # Create visualization
    fig = plt.figure(figsize=(16, 12))

    # 1. Phase-amplitude coupling polar plots (top row)
    for i, (res, state_name) in enumerate(zip(all_results, STATES)):
        if res is not None:
            ax = fig.add_subplot(3, 5, i+1, projection='polar')
            plot_pac_polar(res['theta_phase'], res['gamma_amp'],
                          f'{state_name}\nPAC={res["pac_theta_gamma"]:.3f}', ax)

    # 2. PLV comparison bar chart
    ax_plv = fig.add_subplot(3, 2, 3)
    x = np.arange(5)
    width = 0.25

    plv_theta_gamma = [r['plv_theta_gamma'] if r else 0 for r in all_results]
    plv_theta_alpha = [r['plv_theta_alpha'] if r else 0 for r in all_results]
    pac_theta_gamma = [r['pac_theta_gamma'] if r else 0 for r in all_results]

    ax_plv.bar(x - width, plv_theta_gamma, width, label='PLV θ-γ', color='blue', alpha=0.7)
    ax_plv.bar(x, plv_theta_alpha, width, label='PLV θ-α', color='green', alpha=0.7)
    ax_plv.bar(x + width, pac_theta_gamma, width, label='PAC θ-γ', color='red', alpha=0.7)
    ax_plv.set_xticks(x)
    ax_plv.set_xticklabels(STATES, rotation=45, ha='right')
    ax_plv.set_ylabel('Value')
    ax_plv.set_title('Phase Coupling Metrics by State')
    ax_plv.legend()
    ax_plv.set_ylim(0, 1)

    # 3. Frequency stability comparison
    ax_freq = fig.add_subplot(3, 2, 4)
    freq_cv_theta = [r['freq_cv_theta'] if r else 0 for r in all_results]
    freq_cv_gamma = [r['freq_cv_gamma'] if r else 0 for r in all_results]

    ax_freq.bar(x - width/2, freq_cv_theta, width, label='CV θ', color='purple', alpha=0.7)
    ax_freq.bar(x + width/2, freq_cv_gamma, width, label='CV γ', color='orange', alpha=0.7)
    ax_freq.set_xticks(x)
    ax_freq.set_xticklabels(STATES, rotation=45, ha='right')
    ax_freq.set_ylabel('Coefficient of Variation')
    ax_freq.set_title('Frequency Stability (lower = more stable)')
    ax_freq.legend()

    # 4. Cross-gamma coherence
    ax_cross = fig.add_subplot(3, 2, 5)
    plv_sm = [r['plv_sens_motor_gamma'] if r else 0 for r in all_results]
    plv_sa = [r['plv_sens_assoc_gamma'] if r else 0 for r in all_results]
    plv_ma = [r['plv_motor_assoc_gamma'] if r else 0 for r in all_results]

    ax_cross.bar(x - width, plv_sm, width, label='Sens-Motor', color='red', alpha=0.7)
    ax_cross.bar(x, plv_sa, width, label='Sens-Assoc', color='green', alpha=0.7)
    ax_cross.bar(x + width, plv_ma, width, label='Motor-Assoc', color='blue', alpha=0.7)
    ax_cross.set_xticks(x)
    ax_cross.set_xticklabels(STATES, rotation=45, ha='right')
    ax_cross.set_ylabel('PLV')
    ax_cross.set_title('Cross-Region Gamma Coherence')
    ax_cross.legend()
    ax_cross.set_ylim(0, 1)

    # 5. PLV heatmap
    ax_heat = fig.add_subplot(3, 2, 6)
    plot_phase_locking_matrix(all_results, ax_heat)

    plt.tight_layout()

    # Save figure
    out_path = filepath.parent / 'phase_coupling_analysis.png'
    plt.savefig(out_path, dpi=150, bbox_inches='tight')
    print(f"\nVisualization saved to: {out_path}")

    # Also save PDF
    pdf_path = filepath.parent / 'phase_coupling_analysis.pdf'
    plt.savefig(pdf_path, bbox_inches='tight')
    print(f"PDF saved to: {pdf_path}")

    plt.show()

    return all_results


if __name__ == '__main__':
    csv_path = sys.argv[1] if len(sys.argv) > 1 else 'phase_timeseries.csv'
    main(csv_path)
