#!/usr/bin/env python3
"""
EEG Comparison Analysis for phi^n Neural Processor

Comprehensive spectral and phase analysis of FPGA oscillator outputs,
designed for comparison with real EEG recordings.

Features:
- Power Spectral Density (PSD) using Welch's method
- Band power extraction (delta, theta, alpha, beta, gamma)
- Phase-Amplitude Coupling (PAC) via Modulation Index
- Cross-frequency coherence between oscillators
- Visualization and comparison metrics

Usage:
    python3 analyze_eeg_comparison.py oscillator_eeg_export.csv
    python3 analyze_eeg_comparison.py oscillator_eeg_export.csv --eeg real_eeg.csv

Output:
    - eeg_analysis/psd_all_oscillators.png
    - eeg_analysis/band_powers.png
    - eeg_analysis/pac_comodulogram.png
    - eeg_analysis/coherence_matrix.png
    - eeg_analysis/summary_report.txt
"""

import sys
import os
import argparse
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy import signal
from scipy import stats
from pathlib import Path

# Fixed-point scaling (Q4.14 format)
FRAC = 14
SCALE = 2**FRAC

# Sampling rate (1 kHz from testbench)
FS = 1000  # Hz

# EEG frequency bands (Hz)
BANDS = {
    'delta': (0.5, 4),
    'theta': (4, 8),
    'alpha': (8, 13),
    'low_beta': (13, 20),
    'high_beta': (20, 30),
    'gamma': (30, 80)
}

# Expected oscillator frequencies (phi^n architecture)
EXPECTED_FREQS = {
    'theta': 5.89,      # phi^-0.5
    'sr_f0': 7.6,       # SR fundamental
    'sr_f1': 13.75,     # SR harmonic 1
    'sr_f2': 20.0,      # SR harmonic 2
    'sr_f3': 25.0,      # SR harmonic 3
    'sr_f4': 32.0,      # SR harmonic 4
    'l6': 9.53,         # phi^0.5 (alpha)
    'l5a': 15.42,       # phi^1.5 (low beta)
    'l5b': 24.94,       # phi^2.5 (high beta)
    'l4': 31.73,        # phi^3 (low gamma)
    'l23': 40.36        # phi^3.5 (gamma, retrieval) or 65.3 (encoding)
}

# Oscillator groups for analysis
OSCILLATOR_GROUPS = {
    'thalamic': ['theta_x', 'theta_y'],
    'sr_harmonics': ['sr_f0_x', 'sr_f1_x', 'sr_f2_x', 'sr_f3_x', 'sr_f4_x'],
    'sensory': ['sensory_l6_x', 'sensory_l5a_x', 'sensory_l5b_x', 'sensory_l4_x', 'sensory_l23_x'],
    'assoc': ['assoc_l6_x', 'assoc_l5a_x', 'assoc_l5b_x', 'assoc_l4_x', 'assoc_l23_x'],
    'motor': ['motor_l6_x', 'motor_l5a_x', 'motor_l5b_x', 'motor_l4_x', 'motor_l23_x']
}


def load_fpga_data(filepath):
    """
    Load FPGA oscillator export CSV and convert from Q4.14 fixed-point.

    Returns:
        DataFrame with floating-point values in range [-8, +8)
    """
    print(f"Loading FPGA data from {filepath}...")
    df = pd.read_csv(filepath)

    # Convert Q4.14 fixed-point to float (except metadata columns)
    metadata_cols = ['time_ms', 'state', 'theta_phase', 'beta_quiet', 'sr_amplification']
    for col in df.columns:
        if col not in metadata_cols:
            df[col] = df[col].astype(float) / SCALE

    print(f"  Loaded {len(df)} samples ({len(df)/FS:.1f} seconds)")
    print(f"  Columns: {len(df.columns)}")
    return df


def compute_psd(signal_data, fs=FS, nperseg=1024):
    """
    Compute Power Spectral Density using Welch's method.

    Args:
        signal_data: 1D array of signal values
        fs: Sampling frequency
        nperseg: Segment length for Welch's method

    Returns:
        freqs: Frequency array
        psd: Power spectral density array
    """
    freqs, psd = signal.welch(signal_data, fs=fs, nperseg=nperseg,
                              noverlap=nperseg//2, scaling='density')
    return freqs, psd


def compute_band_power(psd, freqs, band):
    """
    Compute power in a frequency band.

    Args:
        psd: Power spectral density array
        freqs: Frequency array
        band: Tuple of (low_freq, high_freq)

    Returns:
        Total power in band (integrated PSD)
    """
    low, high = band
    mask = (freqs >= low) & (freqs <= high)
    if np.sum(mask) == 0:
        return 0.0
    # Integrate PSD over band (trapezoid rule)
    return np.trapezoid(psd[mask], freqs[mask])


def compute_all_band_powers(psd, freqs):
    """Compute power in all standard EEG bands."""
    return {name: compute_band_power(psd, freqs, band)
            for name, band in BANDS.items()}


def find_peak_frequency(psd, freqs, band=None):
    """
    Find the peak frequency in PSD (optionally within a band).

    Returns:
        peak_freq: Frequency of maximum power
        peak_power: Power at peak
    """
    if band is not None:
        low, high = band
        mask = (freqs >= low) & (freqs <= high)
        if np.sum(mask) == 0:
            return 0.0, 0.0
        idx = np.argmax(psd[mask])
        return freqs[mask][idx], psd[mask][idx]
    else:
        idx = np.argmax(psd)
        return freqs[idx], psd[idx]


def compute_phase(x, y=None):
    """
    Compute instantaneous phase.

    If only x is provided, uses Hilbert transform.
    If x and y are provided, uses arctan2 (for Hopf oscillators).
    """
    if y is not None:
        return np.arctan2(y, x)
    else:
        analytic = signal.hilbert(x)
        return np.angle(analytic)


def compute_amplitude(x, y=None):
    """
    Compute instantaneous amplitude.

    If only x is provided, uses Hilbert transform.
    If x and y are provided, uses sqrt(x^2 + y^2).
    """
    if y is not None:
        return np.sqrt(x**2 + y**2)
    else:
        analytic = signal.hilbert(x)
        return np.abs(analytic)


def modulation_index(phase_signal, amplitude_signal, n_bins=18):
    """
    Compute Modulation Index for Phase-Amplitude Coupling (Tort et al., 2010).

    Args:
        phase_signal: Phase of low-frequency oscillation (radians)
        amplitude_signal: Amplitude of high-frequency oscillation
        n_bins: Number of phase bins

    Returns:
        MI: Modulation Index in [0, 1]
        bin_centers: Phase bin centers
        bin_means: Mean amplitude per bin
    """
    # Bin phase into n_bins
    bin_edges = np.linspace(-np.pi, np.pi, n_bins + 1)
    bin_centers = (bin_edges[:-1] + bin_edges[1:]) / 2
    bin_indices = np.digitize(phase_signal, bin_edges) - 1
    bin_indices = np.clip(bin_indices, 0, n_bins - 1)

    # Compute mean amplitude per bin
    bin_means = np.zeros(n_bins)
    for i in range(n_bins):
        mask = bin_indices == i
        if np.sum(mask) > 0:
            bin_means[i] = np.mean(amplitude_signal[mask])

    # Normalize to probability distribution
    total = np.sum(bin_means)
    if total < 1e-10:
        return 0.0, bin_centers, bin_means

    p = bin_means / total

    # Compute KL divergence from uniform distribution
    uniform = 1.0 / n_bins
    # Avoid log(0) by adding small epsilon
    p_safe = np.maximum(p, 1e-10)
    kl_div = np.sum(p_safe * np.log(p_safe / uniform))

    # Normalize by maximum possible KL divergence
    mi = kl_div / np.log(n_bins)

    return mi, bin_centers, bin_means


def compute_coherence(sig1, sig2, fs=FS, nperseg=256):
    """
    Compute magnitude-squared coherence between two signals.

    Returns:
        freqs: Frequency array
        coh: Coherence array (0-1)
    """
    freqs, coh = signal.coherence(sig1, sig2, fs=fs, nperseg=nperseg)
    return freqs, coh


def compute_plv(phase1, phase2):
    """
    Compute Phase Locking Value between two phase signals.

    PLV = |mean(exp(i * (phase1 - phase2)))|

    Returns value in [0, 1].
    """
    phase_diff = phase1 - phase2
    plv = np.abs(np.mean(np.exp(1j * phase_diff)))
    return plv


def fit_1f_slope(freqs, psd, freq_range=(1, 40)):
    """
    Fit 1/f^alpha slope to PSD in log-log space.

    Returns:
        alpha: Slope (positive for 1/f^alpha decay)
        intercept: Log-space intercept
        r_squared: Goodness of fit
    """
    low, high = freq_range
    mask = (freqs >= low) & (freqs <= high) & (psd > 0)

    if np.sum(mask) < 10:
        return 0.0, 0.0, 0.0

    log_f = np.log10(freqs[mask])
    log_psd = np.log10(psd[mask])

    slope, intercept, r_value, p_value, std_err = stats.linregress(log_f, log_psd)

    return -slope, intercept, r_value**2


def analyze_fpga_data(df):
    """
    Comprehensive analysis of FPGA oscillator data.

    Returns:
        Dictionary containing all analysis results
    """
    results = {
        'psd': {},
        'band_powers': {},
        'peak_freqs': {},
        'pac': {},
        'coherence': {},
        '1f_slope': {}
    }

    print("\nAnalyzing oscillator data...")

    # 1. Compute PSD for each oscillator
    print("  Computing power spectral density...")
    oscillator_cols = [c for c in df.columns if c not in
                       ['time_ms', 'state', 'theta_phase', 'beta_quiet', 'sr_amplification']]

    for col in oscillator_cols:
        freqs, psd = compute_psd(df[col].values)
        results['psd'][col] = {'freqs': freqs, 'psd': psd}
        results['band_powers'][col] = compute_all_band_powers(psd, freqs)

        # Find peak frequency
        peak_f, peak_p = find_peak_frequency(psd, freqs, band=(1, 100))
        results['peak_freqs'][col] = {'freq': peak_f, 'power': peak_p}

    # 2. Compute 1/f slope for theta (representative)
    print("  Fitting 1/f slope...")
    if 'theta_x' in results['psd']:
        psd_data = results['psd']['theta_x']
        alpha, intercept, r2 = fit_1f_slope(psd_data['freqs'], psd_data['psd'])
        results['1f_slope'] = {'alpha': alpha, 'intercept': intercept, 'r_squared': r2}

    # 3. Phase-Amplitude Coupling (theta phase -> gamma amplitude)
    print("  Computing phase-amplitude coupling...")
    if 'theta_x' in df.columns and 'theta_y' in df.columns:
        theta_phase = compute_phase(df['theta_x'].values, df['theta_y'].values)

        # PAC with each gamma-band oscillator
        gamma_cols = ['sensory_l23_x', 'assoc_l23_x', 'motor_l23_x',
                      'sensory_l4_x', 'assoc_l4_x', 'motor_l4_x']

        for col in gamma_cols:
            if col in df.columns:
                gamma_amp = compute_amplitude(df[col].values)
                mi, bin_centers, bin_means = modulation_index(theta_phase, gamma_amp)
                results['pac'][f'theta-{col}'] = {
                    'mi': mi,
                    'bin_centers': bin_centers,
                    'bin_means': bin_means
                }

    # 4. Cross-frequency coherence (between select oscillator pairs)
    print("  Computing cross-frequency coherence...")
    coherence_pairs = [
        ('theta_x', 'sensory_l6_x'),     # Theta-Alpha
        ('theta_x', 'sensory_l23_x'),    # Theta-Gamma
        ('sr_f0_x', 'theta_x'),          # SR-Theta
        ('sensory_l6_x', 'sensory_l23_x'), # Alpha-Gamma
        ('sensory_l23_x', 'motor_l23_x'),  # Cross-column gamma
    ]

    for col1, col2 in coherence_pairs:
        if col1 in df.columns and col2 in df.columns:
            freqs, coh = compute_coherence(df[col1].values, df[col2].values)
            results['coherence'][f'{col1}-{col2}'] = {'freqs': freqs, 'coherence': coh}

    return results


def plot_psd_all(results, output_dir):
    """Plot PSD for all oscillators grouped by type."""
    fig, axes = plt.subplots(2, 3, figsize=(15, 10))
    axes = axes.flatten()

    colors = plt.cm.viridis(np.linspace(0, 1, 5))

    group_names = ['Thalamic', 'SR Harmonics', 'Sensory', 'Association', 'Motor']
    groups = [
        ['theta_x'],
        ['sr_f0_x', 'sr_f1_x', 'sr_f2_x', 'sr_f3_x', 'sr_f4_x'],
        ['sensory_l6_x', 'sensory_l5a_x', 'sensory_l5b_x', 'sensory_l4_x', 'sensory_l23_x'],
        ['assoc_l6_x', 'assoc_l5a_x', 'assoc_l5b_x', 'assoc_l4_x', 'assoc_l23_x'],
        ['motor_l6_x', 'motor_l5a_x', 'motor_l5b_x', 'motor_l4_x', 'motor_l23_x']
    ]

    layer_labels = ['L6 (alpha)', 'L5a (low-beta)', 'L5b (high-beta)', 'L4 (gamma)', 'L2/3 (gamma)']
    sr_labels = ['f0 (7.6)', 'f1 (13.75)', 'f2 (20)', 'f3 (25)', 'f4 (32)']

    for ax_idx, (ax, group_name, group_cols) in enumerate(zip(axes[:5], group_names, groups)):
        for i, col in enumerate(group_cols):
            if col in results['psd']:
                psd_data = results['psd'][col]
                freqs = psd_data['freqs']
                psd = psd_data['psd']

                # Determine label
                if 'sr_f' in col:
                    label = sr_labels[i]
                elif 'theta' in col:
                    label = 'Theta (5.89 Hz)'
                else:
                    label = layer_labels[i]

                ax.semilogy(freqs, psd, color=colors[i], label=label, linewidth=1.5)

        ax.set_xlabel('Frequency (Hz)')
        ax.set_ylabel('PSD (V²/Hz)')
        ax.set_title(f'{group_name} Oscillators')
        ax.set_xlim(0, 80)
        ax.legend(fontsize=8)
        ax.grid(True, alpha=0.3)

    # Use last subplot for summary statistics
    ax = axes[5]
    ax.axis('off')

    # Create summary text
    summary_text = "Peak Frequencies (Hz):\n\n"
    for col, data in results['peak_freqs'].items():
        if data['freq'] > 0:
            short_name = col.replace('_x', '').replace('sensory_', 'S.').replace('assoc_', 'A.').replace('motor_', 'M.')
            summary_text += f"  {short_name}: {data['freq']:.2f}\n"

    if results['1f_slope']:
        summary_text += f"\n1/f Slope:\n  alpha = {results['1f_slope']['alpha']:.2f}\n"
        summary_text += f"  R² = {results['1f_slope']['r_squared']:.3f}"

    ax.text(0.1, 0.9, summary_text, transform=ax.transAxes, fontsize=10,
            verticalalignment='top', fontfamily='monospace')

    plt.tight_layout()
    plt.savefig(output_dir / 'psd_all_oscillators.png', dpi=150)
    plt.close()
    print(f"  Saved: {output_dir / 'psd_all_oscillators.png'}")


def plot_band_powers(results, output_dir):
    """Plot band power comparison across oscillators."""
    fig, axes = plt.subplots(2, 3, figsize=(15, 10))
    axes = axes.flatten()

    bands_to_plot = list(BANDS.keys())

    # Get all oscillator names
    osc_names = list(results['band_powers'].keys())

    # Create short names for display
    short_names = []
    for name in osc_names:
        short = name.replace('_x', '').replace('sensory_', 'S.').replace('assoc_', 'A.').replace('motor_', 'M.')
        short_names.append(short)

    for ax_idx, (ax, band) in enumerate(zip(axes, bands_to_plot)):
        powers = [results['band_powers'][osc][band] for osc in osc_names]

        # Normalize to max for visualization
        max_power = max(powers) if max(powers) > 0 else 1
        powers_norm = [p / max_power for p in powers]

        bars = ax.bar(range(len(osc_names)), powers_norm, color=plt.cm.viridis(ax_idx / 6))
        ax.set_xticks(range(len(osc_names)))
        ax.set_xticklabels(short_names, rotation=45, ha='right', fontsize=7)
        ax.set_ylabel('Relative Power')
        ax.set_title(f'{band.replace("_", " ").title()} Band ({BANDS[band][0]}-{BANDS[band][1]} Hz)')
        ax.set_ylim(0, 1.1)
        ax.grid(True, alpha=0.3, axis='y')

    plt.tight_layout()
    plt.savefig(output_dir / 'band_powers.png', dpi=150)
    plt.close()
    print(f"  Saved: {output_dir / 'band_powers.png'}")


def plot_pac_comodulogram(results, output_dir):
    """Plot Phase-Amplitude Coupling results."""
    pac_results = results['pac']
    if not pac_results:
        print("  No PAC results to plot")
        return

    n_pairs = len(pac_results)
    cols = min(3, n_pairs)
    rows = (n_pairs + cols - 1) // cols

    fig, axes = plt.subplots(rows, cols, figsize=(5*cols, 4*rows), subplot_kw={'projection': 'polar'})
    if n_pairs == 1:
        axes = [axes]
    else:
        axes = axes.flatten() if rows > 1 else axes

    for ax, (pair_name, data) in zip(axes, pac_results.items()):
        bin_centers = data['bin_centers']
        bin_means = data['bin_means']
        mi = data['mi']

        # Polar bar plot
        width = 2 * np.pi / len(bin_centers)
        bars = ax.bar(bin_centers, bin_means, width=width, alpha=0.7, color='steelblue')

        ax.set_title(f'{pair_name}\nMI = {mi:.4f}', fontsize=10)
        ax.set_theta_zero_location('N')
        ax.set_theta_direction(-1)

    # Hide unused axes
    for ax in axes[n_pairs:]:
        ax.set_visible(False)

    plt.suptitle('Phase-Amplitude Coupling (Theta Phase vs Gamma Amplitude)', fontsize=12)
    plt.tight_layout()
    plt.savefig(output_dir / 'pac_comodulogram.png', dpi=150)
    plt.close()
    print(f"  Saved: {output_dir / 'pac_comodulogram.png'}")


def plot_coherence_matrix(results, output_dir):
    """Plot cross-frequency coherence results."""
    coherence_results = results['coherence']
    if not coherence_results:
        print("  No coherence results to plot")
        return

    n_pairs = len(coherence_results)
    fig, axes = plt.subplots(1, n_pairs, figsize=(4*n_pairs, 4))
    if n_pairs == 1:
        axes = [axes]

    for ax, (pair_name, data) in zip(axes, coherence_results.items()):
        freqs = data['freqs']
        coh = data['coherence']

        ax.plot(freqs, coh, 'b-', linewidth=1.5)
        ax.fill_between(freqs, coh, alpha=0.3)
        ax.set_xlabel('Frequency (Hz)')
        ax.set_ylabel('Coherence')
        ax.set_title(pair_name.replace('-', ' vs\n'), fontsize=9)
        ax.set_xlim(0, 80)
        ax.set_ylim(0, 1)
        ax.grid(True, alpha=0.3)

    plt.suptitle('Cross-Frequency Coherence', fontsize=12)
    plt.tight_layout()
    plt.savefig(output_dir / 'coherence_matrix.png', dpi=150)
    plt.close()
    print(f"  Saved: {output_dir / 'coherence_matrix.png'}")


def generate_summary_report(results, output_dir):
    """Generate text summary of analysis results."""
    report = []
    report.append("=" * 70)
    report.append("EEG Comparison Analysis - Summary Report")
    report.append("=" * 70)
    report.append("")

    # Peak frequencies
    report.append("PEAK FREQUENCIES (Hz)")
    report.append("-" * 40)
    for col, data in sorted(results['peak_freqs'].items()):
        if data['freq'] > 0:
            # Check against expected
            expected = None
            if 'theta' in col:
                expected = EXPECTED_FREQS['theta']
            elif 'sr_f0' in col:
                expected = EXPECTED_FREQS['sr_f0']
            elif 'sr_f1' in col:
                expected = EXPECTED_FREQS['sr_f1']
            elif 'sr_f2' in col:
                expected = EXPECTED_FREQS['sr_f2']
            elif 'sr_f3' in col:
                expected = EXPECTED_FREQS['sr_f3']
            elif 'sr_f4' in col:
                expected = EXPECTED_FREQS['sr_f4']
            elif 'l6' in col:
                expected = EXPECTED_FREQS['l6']
            elif 'l5a' in col:
                expected = EXPECTED_FREQS['l5a']
            elif 'l5b' in col:
                expected = EXPECTED_FREQS['l5b']
            elif 'l4' in col:
                expected = EXPECTED_FREQS['l4']
            elif 'l23' in col:
                expected = EXPECTED_FREQS['l23']

            error_str = ""
            if expected:
                error = abs(data['freq'] - expected)
                error_str = f" (expected: {expected:.2f}, error: {error:.2f})"

            report.append(f"  {col:25s}: {data['freq']:6.2f} Hz{error_str}")
    report.append("")

    # 1/f slope
    if results['1f_slope']:
        report.append("1/f SLOPE")
        report.append("-" * 40)
        report.append(f"  Alpha (slope): {results['1f_slope']['alpha']:.3f}")
        report.append(f"  R-squared:     {results['1f_slope']['r_squared']:.3f}")
        report.append("  (Healthy EEG typically shows alpha ~ 1.0-1.5)")
        report.append("")

    # PAC
    if results['pac']:
        report.append("PHASE-AMPLITUDE COUPLING (Modulation Index)")
        report.append("-" * 40)
        for pair, data in sorted(results['pac'].items()):
            report.append(f"  {pair:30s}: MI = {data['mi']:.4f}")
        report.append("  (MI > 0.01 indicates significant coupling)")
        report.append("")

    # Band powers summary (just theta and gamma for key oscillators)
    report.append("BAND POWER RATIOS")
    report.append("-" * 40)
    key_oscs = ['theta_x', 'sensory_l6_x', 'sensory_l23_x']
    for osc in key_oscs:
        if osc in results['band_powers']:
            bp = results['band_powers'][osc]
            total = sum(bp.values())
            if total > 0:
                theta_pct = 100 * bp['theta'] / total
                alpha_pct = 100 * bp['alpha'] / total
                gamma_pct = 100 * bp['gamma'] / total
                report.append(f"  {osc:20s}: theta={theta_pct:5.1f}%, alpha={alpha_pct:5.1f}%, gamma={gamma_pct:5.1f}%")
    report.append("")

    report.append("=" * 70)
    report.append("End of Report")
    report.append("=" * 70)

    # Write report
    report_text = "\n".join(report)
    report_path = output_dir / 'summary_report.txt'
    with open(report_path, 'w') as f:
        f.write(report_text)

    print(f"  Saved: {report_path}")
    print("\n" + report_text)


def main():
    parser = argparse.ArgumentParser(description='EEG Comparison Analysis for phi^n Neural Processor')
    parser.add_argument('fpga_csv', help='Path to FPGA oscillator export CSV')
    parser.add_argument('--eeg', help='Path to real EEG data CSV (optional)', default=None)
    parser.add_argument('--output-dir', help='Output directory for plots', default='eeg_analysis')
    args = parser.parse_args()

    # Create output directory
    output_dir = Path(args.output_dir)
    output_dir.mkdir(exist_ok=True)

    # Load FPGA data
    df = load_fpga_data(args.fpga_csv)

    # Run analysis
    results = analyze_fpga_data(df)

    # Generate visualizations
    print("\nGenerating visualizations...")
    plot_psd_all(results, output_dir)
    plot_band_powers(results, output_dir)
    plot_pac_comodulogram(results, output_dir)
    plot_coherence_matrix(results, output_dir)

    # Generate summary report
    print("\nGenerating summary report...")
    generate_summary_report(results, output_dir)

    print(f"\nAnalysis complete! Results saved to {output_dir}/")

    # TODO: Add EEG comparison when real EEG data is provided
    if args.eeg:
        print(f"\nEEG comparison with {args.eeg} not yet implemented.")
        print("Future: Will compare FPGA oscillators to real EEG recordings.")


if __name__ == '__main__':
    main()
