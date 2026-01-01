#!/usr/bin/env python3
"""
Show variance between seeds and time-series differences.
Usage: python3 scripts/spectrogram_variance.py
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy import signal
import os

def compute_spectrogram(dac_data, fs=1000):
    """Compute spectrogram from DAC output data."""
    sos = signal.butter(4, 3, btype='high', fs=fs, output='sos')
    dac_filtered = signal.sosfilt(sos, dac_data)
    dac_centered = dac_filtered - np.mean(dac_filtered)
    nperseg = 2048
    noverlap = nperseg * 3 // 4
    f, t, Sxx = signal.spectrogram(dac_centered, fs=fs, nperseg=nperseg,
                                    noverlap=noverlap, scaling='density')
    Sxx_db = 10 * np.log10(Sxx + 1e-10)
    return f, t, Sxx_db

def main():
    # Load all seed files
    seed_files = []
    for seed in range(1, 5):
        fname = f'state_transition_dac_seed{seed}.csv'
        if os.path.exists(fname):
            seed_files.append((seed, fname))

    if len(seed_files) < 4:
        print(f"Error: Need 4 seed files, found {len(seed_files)}")
        return

    # Compute all spectrograms
    spectrograms = []
    time_series = []
    for seed, fname in seed_files:
        df = pd.read_csv(fname)
        dac_data = df['dac_output'].values
        f, t, Sxx_db = compute_spectrogram(dac_data)
        spectrograms.append(Sxx_db)
        time_series.append(dac_data)

    # Stack spectrograms (shape: [4, freq, time])
    spec_stack = np.stack(spectrograms)
    freq_mask = (f >= 4) & (f <= 50)

    # Compute mean and variance across seeds
    spec_mean = np.mean(spec_stack[:, freq_mask, :], axis=0)
    spec_std = np.std(spec_stack[:, freq_mask, :], axis=0)
    f_neural = f[freq_mask]

    # Create figure
    fig = plt.figure(figsize=(16, 12))

    # Row 1: Mean spectrogram and variance
    ax1 = fig.add_subplot(3, 2, 1)
    im1 = ax1.pcolormesh(t, f_neural, spec_mean, shading='gouraud', cmap='jet')
    ax1.set_ylabel('Frequency (Hz)')
    ax1.set_title('Mean Spectrogram Across 4 Seeds')
    plt.colorbar(im1, ax=ax1, label='Power (dB)')

    ax2 = fig.add_subplot(3, 2, 2)
    im2 = ax2.pcolormesh(t, f_neural, spec_std, shading='gouraud', cmap='hot')
    ax2.set_ylabel('Frequency (Hz)')
    ax2.set_title('Standard Deviation Across Seeds (Where They Differ)')
    plt.colorbar(im2, ax=ax2, label='Std Dev (dB)')

    # Row 2: Time series comparison (first 5 seconds)
    ax3 = fig.add_subplot(3, 2, 3)
    t_samples = np.arange(5000) / 1000  # First 5 seconds
    colors = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728']
    for i, (seed, _) in enumerate(seed_files):
        ax3.plot(t_samples, time_series[i][:5000], alpha=0.7, lw=0.5,
                 color=colors[i], label=f'Seed {seed}')
    ax3.set_xlabel('Time (s)')
    ax3.set_ylabel('DAC Output')
    ax3.set_title('Time Series: First 5 Seconds (All 4 Seeds Overlaid)')
    ax3.legend(loc='upper right', fontsize=8)

    # Row 2 right: Time series during MEDITATION (40-45s)
    ax4 = fig.add_subplot(3, 2, 4)
    t_med = np.arange(5000) / 1000 + 40
    for i, (seed, _) in enumerate(seed_files):
        ax4.plot(t_med, time_series[i][40000:45000], alpha=0.7, lw=0.5,
                 color=colors[i], label=f'Seed {seed}')
    ax4.set_xlabel('Time (s)')
    ax4.set_ylabel('DAC Output')
    ax4.set_title('Time Series: MEDITATION Phase (40-45s)')
    ax4.legend(loc='upper right', fontsize=8)

    # Row 3: Correlation matrix between seeds
    ax5 = fig.add_subplot(3, 2, 5)
    # Compute correlation of time series
    corr_matrix = np.corrcoef([ts for ts in time_series])
    im5 = ax5.imshow(corr_matrix, cmap='RdYlGn', vmin=-1, vmax=1)
    ax5.set_xticks(range(4))
    ax5.set_yticks(range(4))
    ax5.set_xticklabels([f'Seed {s}' for s, _ in seed_files])
    ax5.set_yticklabels([f'Seed {s}' for s, _ in seed_files])
    ax5.set_title('Time Series Correlation (Lower = More Different)')
    for i in range(4):
        for j in range(4):
            ax5.text(j, i, f'{corr_matrix[i,j]:.3f}', ha='center', va='center',
                    fontsize=10, color='black' if abs(corr_matrix[i,j]) < 0.5 else 'white')
    plt.colorbar(im5, ax=ax5, label='Correlation')

    # Row 3 right: Power spectrum differences
    ax6 = fig.add_subplot(3, 2, 6)
    # Average power spectrum for each seed
    for i, (seed, _) in enumerate(seed_files):
        # Average power over time for this seed
        mean_power = np.mean(spectrograms[i][freq_mask, :], axis=1)
        ax6.plot(f_neural, mean_power, color=colors[i], label=f'Seed {seed}', lw=1.5)
    ax6.set_xlabel('Frequency (Hz)')
    ax6.set_ylabel('Mean Power (dB)')
    ax6.set_title('Average Power Spectrum per Seed')
    ax6.legend()
    ax6.grid(True, alpha=0.3)

    plt.tight_layout()

    # Save
    os.makedirs('eeg_analysis', exist_ok=True)
    output_file = 'eeg_analysis/spectrogram_variance_analysis.png'
    plt.savefig(output_file, dpi=150, bbox_inches='tight')
    print(f"Saved: {output_file}")

    # Print summary
    print(f"\nSeed Correlation Matrix:")
    print(f"  (1.0 = identical, 0.0 = uncorrelated)")
    for i, (s1, _) in enumerate(seed_files):
        for j, (s2, _) in enumerate(seed_files):
            if j > i:
                print(f"  Seed {s1} vs Seed {s2}: r = {corr_matrix[i,j]:.4f}")

    plt.close()

if __name__ == '__main__':
    main()
