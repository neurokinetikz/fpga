#!/usr/bin/env python3
"""
State Transition DAC Analysis

Analyzes DAC output from state transition simulation using the same
visualization style as dac_spectrogram.py.

Uses raw DAC output (already mixed by Verilog) instead of simulating mixer.

Usage:
    python3 scripts/state_transition_dac_analysis.py
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy import signal
from scipy.fft import fft, fftfreq
import os

# Sampling rate
FS = 1000  # Hz

# Expected phi^n frequencies
PHI_FREQS = {
    'theta': 5.89,
    'SR f0': 7.6,
    'L6 alpha': 9.53,
    'SR f1': 13.75,
    'L5a low-beta': 15.42,
    'SR f2': 20.0,
    'L5b high-beta': 24.94,
    'SR f3': 25.0,
    'L4 low-gamma': 31.73,
    'SR f4': 32.0,
    'L2/3 gamma (slow)': 40.36,
    'L2/3 gamma (fast)': 65.3,
}

def main():
    # Load data
    csv_path = 'state_transition_dac.csv'
    if not os.path.exists(csv_path):
        print(f"ERROR: {csv_path} not found!")
        return

    print(f"Loading {csv_path}...")
    df = pd.read_csv(csv_path)
    print(f"  Loaded {len(df)} samples ({len(df)/1000:.1f} seconds at 1 kHz)")

    # Extract DAC output (already mixed by Verilog)
    dac_raw = df['dac_output'].values
    phases = df['phase'].values
    mu_values = df['mu_l5b'].values

    # Convert 12-bit DAC to float [-1, 1]
    dac_float = (dac_raw.astype(float) - 2048) / 2048

    n_samples = len(dac_float)
    time_axis = np.arange(n_samples) / FS

    # Create output directory
    os.makedirs('eeg_analysis', exist_ok=True)

    #=========================================================================
    # Figure 1: Time-Domain Waveform
    #=========================================================================
    print("Generating time-domain waveform...")
    fig1, axes1 = plt.subplots(3, 1, figsize=(14, 10))

    # Full waveform
    ax = axes1[0]
    ax.plot(time_axis, dac_float, 'b-', linewidth=0.3, alpha=0.7)
    ax.set_xlabel('Time (s)')
    ax.set_ylabel('Amplitude')
    ax.set_title('DAC Output - Full 100 Second Recording')
    ax.set_xlim(0, 100)

    # Phase boundaries
    phase_times = [0, 20, 40, 60, 80, 100]
    phase_names = ['NORMAL', 'N→M', 'MEDITATION', 'M→N', 'NORMAL']
    for i, t in enumerate(phase_times[:-1]):
        ax.axvline(t, color='red', linestyle='--', alpha=0.5)
        ax.text(t + 10, ax.get_ylim()[1] * 0.9, phase_names[i],
                ha='center', fontsize=10, color='red')

    # Zoomed NORMAL section (0-5s)
    ax = axes1[1]
    mask = time_axis < 5
    ax.plot(time_axis[mask], dac_float[mask], 'b-', linewidth=0.5)
    ax.set_xlabel('Time (s)')
    ax.set_ylabel('Amplitude')
    ax.set_title('NORMAL State Detail (0-5s)')
    ax.set_xlim(0, 5)

    # Zoomed MEDITATION section (45-50s)
    ax = axes1[2]
    mask = (time_axis >= 45) & (time_axis < 50)
    ax.plot(time_axis[mask], dac_float[mask], 'g-', linewidth=0.5)
    ax.set_xlabel('Time (s)')
    ax.set_ylabel('Amplitude')
    ax.set_title('MEDITATION State Detail (45-50s)')
    ax.set_xlim(45, 50)

    plt.tight_layout()
    plt.savefig('eeg_analysis/state_transition_waveform.png', dpi=150)
    print("  Saved: eeg_analysis/state_transition_waveform.png")

    #=========================================================================
    # Figure 2: Spectrogram with Phase Annotations
    #=========================================================================
    print("Generating spectrogram...")
    fig2, ax = plt.subplots(figsize=(14, 6))

    # Compute spectrogram
    nperseg = 4096
    noverlap = 3584
    f, t, Sxx = signal.spectrogram(dac_float, FS,
                                    nperseg=nperseg,
                                    noverlap=noverlap,
                                    window='hamming')

    # Limit to 0-80 Hz
    freq_mask = f <= 80
    power_db = 10 * np.log10(Sxx[freq_mask, :] + 1e-12)

    im = ax.pcolormesh(t, f[freq_mask], power_db,
                       shading='gouraud', cmap='viridis',
                       vmin=-60, vmax=-20)

    # Add phi^n frequency markers
    for name, freq in PHI_FREQS.items():
        if freq <= 80:
            ax.axhline(freq, color='white', linestyle='--', alpha=0.4, linewidth=0.8)

    # Phase boundaries
    phase_colors = ['#00ff00', '#ffff00', '#0080ff', '#ffff00', '#00ff00']
    for i, (start, end) in enumerate(zip(phase_times[:-1], phase_times[1:])):
        if i > 0:
            ax.axvline(start, color='red', linestyle='-', alpha=0.6, linewidth=2)
        mid = (start + end) / 2
        ax.text(mid, 75, phase_names[i], ha='center', va='top',
                fontsize=11, color='white', fontweight='bold',
                bbox=dict(boxstyle='round,pad=0.3', facecolor=phase_colors[i],
                         alpha=0.5, edgecolor='none'))

    ax.set_xlabel('Time (s)', fontsize=12)
    ax.set_ylabel('Frequency (Hz)', fontsize=12)
    ax.set_title('State Transition Spectrogram: NORMAL ↔ MEDITATION (MU Interpolation)', fontsize=14)
    ax.set_xlim(0, 100)
    ax.set_ylim(0, 80)

    plt.colorbar(im, ax=ax, label='Power (dB)')
    plt.tight_layout()
    plt.savefig('eeg_analysis/state_transition_dac_spectrogram.png', dpi=150)
    print("  Saved: eeg_analysis/state_transition_dac_spectrogram.png")

    #=========================================================================
    # Figure 3: Power Spectral Density Comparison
    #=========================================================================
    print("Computing PSDs for each phase...")
    fig3, axes3 = plt.subplots(2, 3, figsize=(15, 10))

    phase_data = {
        'NORMAL (0-20s)': (0, 20000),
        'N→M Transition': (20000, 40000),
        'MEDITATION': (40000, 60000),
        'M→N Transition': (60000, 80000),
        'NORMAL (80-100s)': (80000, 100000),
    }

    colors = ['green', 'orange', 'blue', 'orange', 'green']

    for idx, ((name, (start, end)), color) in enumerate(zip(phase_data.items(), colors)):
        row, col = divmod(idx, 3)
        ax = axes3[row, col] if idx < 5 else None
        if ax is None:
            continue

        segment = dac_float[start:end]

        # Welch PSD
        f_psd, psd = signal.welch(segment, FS, nperseg=2048)

        # Limit to 0-80 Hz
        mask = f_psd <= 80
        ax.semilogy(f_psd[mask], psd[mask], color=color, linewidth=1.5)

        # Add phi^n markers
        for freq_name, freq in PHI_FREQS.items():
            if freq <= 80:
                ax.axvline(freq, color='gray', linestyle='--', alpha=0.3, linewidth=0.8)

        ax.set_xlabel('Frequency (Hz)')
        ax.set_ylabel('PSD')
        ax.set_title(name)
        ax.set_xlim(0, 80)
        ax.grid(True, alpha=0.3)

    # 6th subplot: overlay comparison
    ax = axes3[1, 2]
    for (name, (start, end)), color in zip(list(phase_data.items())[:3], ['green', 'orange', 'blue']):
        segment = dac_float[start:end]
        f_psd, psd = signal.welch(segment, FS, nperseg=2048)
        mask = f_psd <= 80
        label = name.split()[0]  # First word
        ax.semilogy(f_psd[mask], psd[mask], color=color, linewidth=1.5, alpha=0.8, label=label)

    ax.set_xlabel('Frequency (Hz)')
    ax.set_ylabel('PSD')
    ax.set_title('Overlay: NORMAL vs N→M vs MEDITATION')
    ax.set_xlim(0, 80)
    ax.legend()
    ax.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig('eeg_analysis/state_transition_psd_comparison.png', dpi=150)
    print("  Saved: eeg_analysis/state_transition_psd_comparison.png")

    #=========================================================================
    # Figure 4: Band Power Timeline
    #=========================================================================
    print("Computing band power timeline...")
    fig4, axes4 = plt.subplots(2, 1, figsize=(14, 8))

    # Define EEG bands
    bands = {
        'Delta (1-4 Hz)': (1, 4),
        'Theta (4-8 Hz)': (4, 8),
        'Alpha (8-13 Hz)': (8, 13),
        'Beta (13-30 Hz)': (13, 30),
        'Gamma (30-80 Hz)': (30, 80),
    }

    band_colors = ['purple', 'blue', 'green', 'orange', 'red']

    # Compute band power over time
    ax = axes4[0]
    for (band_name, (low, high)), color in zip(bands.items(), band_colors):
        band_mask = (f >= low) & (f <= high)
        band_power = 10 * np.log10(np.mean(Sxx[band_mask, :], axis=0) + 1e-12)
        ax.plot(t, band_power, color=color, linewidth=1.5, label=band_name, alpha=0.8)

    # Phase boundaries
    for i, pt in enumerate(phase_times[1:-1]):
        ax.axvline(pt, color='gray', linestyle='--', alpha=0.5)

    ax.set_xlabel('Time (s)')
    ax.set_ylabel('Band Power (dB)')
    ax.set_title('EEG Band Power Over Time During State Transitions')
    ax.set_xlim(0, 100)
    ax.legend(loc='upper right')
    ax.grid(True, alpha=0.3)

    # MU value timeline
    ax = axes4[1]
    ax.plot(time_axis, mu_values, 'b-', linewidth=1.5)
    ax.fill_between(time_axis, 0, mu_values, alpha=0.3)
    ax.axhline(4, color='green', linestyle=':', alpha=0.5)
    ax.axhline(2, color='blue', linestyle=':', alpha=0.5)
    ax.text(5, 4.2, 'NORMAL (μ=4)', color='green', fontsize=9)
    ax.text(45, 2.2, 'MEDITATION (μ=2)', color='blue', fontsize=9)
    ax.set_xlabel('Time (s)')
    ax.set_ylabel('MU Value')
    ax.set_title('Growth Rate (μ) Parameter Over Time')
    ax.set_xlim(0, 100)
    ax.set_ylim(0, 5)
    ax.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig('eeg_analysis/state_transition_band_timeline.png', dpi=150)
    print("  Saved: eeg_analysis/state_transition_band_timeline.png")

    #=========================================================================
    # Summary Statistics
    #=========================================================================
    print("\n" + "="*70)
    print("STATE TRANSITION ANALYSIS SUMMARY")
    print("="*70)

    print(f"\nRecording: {n_samples/FS:.1f} seconds at {FS} Hz")
    print(f"DAC range: [{dac_raw.min()}, {dac_raw.max()}] (12-bit)")

    print("\nBand Power by Phase (dB):")
    print("-" * 70)
    header = f"{'Phase':<20}"
    for band_name in bands.keys():
        header += f" {band_name.split()[0]:<10}"
    print(header)
    print("-" * 70)

    for name, (start, end) in phase_data.items():
        segment = dac_float[start:end]
        f_psd, psd = signal.welch(segment, FS, nperseg=2048)

        row = f"{name:<20}"
        for band_name, (low, high) in bands.items():
            band_mask = (f_psd >= low) & (f_psd <= high)
            band_power = 10 * np.log10(np.mean(psd[band_mask]) + 1e-12)
            row += f" {band_power:>10.1f}"
        print(row)

    print("\n" + "="*70)
    print("Analysis complete! Output files in: eeg_analysis/")
    print("="*70)

if __name__ == '__main__':
    main()
