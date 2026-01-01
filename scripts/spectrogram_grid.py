#!/usr/bin/env python3
"""
Generate 2x2 grid of spectrograms from multiple seed runs.
Usage: python3 scripts/spectrogram_grid.py
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy import signal
import os

def compute_spectrogram(dac_data, fs=1000):
    """Compute spectrogram from DAC output data."""
    # High-pass filter at 3 Hz to remove ultra-low frequency dominance
    sos = signal.butter(4, 3, btype='high', fs=fs, output='sos')
    dac_filtered = signal.sosfilt(sos, dac_data)

    # Center the data
    dac_centered = dac_filtered - np.mean(dac_filtered)

    # Spectrogram parameters
    nperseg = 2048  # ~2s window at 1kHz
    noverlap = nperseg * 3 // 4  # 75% overlap

    f, t, Sxx = signal.spectrogram(dac_centered, fs=fs, nperseg=nperseg,
                                    noverlap=noverlap, scaling='density')

    # Convert to dB
    Sxx_db = 10 * np.log10(Sxx + 1e-10)

    return f, t, Sxx_db

def plot_spectrogram(ax, csv_file, seed_num, vmin=None, vmax=None):
    """Plot spectrogram on given axis."""
    # Load data
    df = pd.read_csv(csv_file)
    dac_data = df['dac_output'].values
    duration = len(dac_data) / 1000  # seconds

    # Compute spectrogram
    f, t, Sxx_db = compute_spectrogram(dac_data)

    # Auto-scale color range if not provided
    if vmin is None:
        vmin = np.percentile(Sxx_db, 5)
    if vmax is None:
        vmax = np.percentile(Sxx_db, 95)

    # Plot with jet colormap for better contrast
    im = ax.pcolormesh(t, f, Sxx_db, shading='gouraud', cmap='jet',
                       vmin=vmin, vmax=vmax)
    ax.set_ylim(4, 50)  # Focus on neural bands (4-50 Hz)
    ax.set_xlabel('Time (s)')
    ax.set_ylabel('Frequency (Hz)')
    ax.set_title(f'Seed {seed_num} ({duration:.0f}s)')

    # Add phase boundaries
    phase_duration = duration / 5
    for i in range(1, 5):
        ax.axvline(x=i * phase_duration, color='white', linestyle='--', alpha=0.5)

    # Add band labels
    ax.axhline(y=8, color='white', linestyle=':', alpha=0.3)   # theta/alpha
    ax.axhline(y=13, color='white', linestyle=':', alpha=0.3)  # alpha/beta
    ax.axhline(y=30, color='white', linestyle=':', alpha=0.3)  # beta/gamma

    return im

def main():
    # Find seed files
    seed_files = []
    for seed in range(1, 5):
        fname = f'state_transition_dac_seed{seed}.csv'
        if os.path.exists(fname):
            seed_files.append((seed, fname))

    if len(seed_files) < 4:
        print(f"Error: Need 4 seed files, found {len(seed_files)}")
        return

    # First pass: compute common color scale and gather statistics
    print("Computing spectrograms and statistics...")
    all_db = []
    spectrograms = []
    stats = []
    for seed, fname in seed_files:
        df = pd.read_csv(fname, on_bad_lines='skip')  # Skip malformed lines
        dac_data = df['dac_output'].values
        f, t, Sxx_db = compute_spectrogram(dac_data)
        # Only include 4-50 Hz for color scale
        freq_mask = (f >= 4) & (f <= 50)
        band_data = Sxx_db[freq_mask, :]
        all_db.append(band_data)
        spectrograms.append((f, t, Sxx_db, dac_data))
        # Statistics for this seed
        stats.append({
            'seed': seed,
            'dac_mean': np.mean(dac_data),
            'dac_std': np.std(dac_data),
            'band_mean': np.mean(band_data),
            'band_std': np.std(band_data),
        })
        print(f"  Seed {seed}: DAC mean={stats[-1]['dac_mean']:.1f}, std={stats[-1]['dac_std']:.1f}, "
              f"Band mean={stats[-1]['band_mean']:.1f} dB, std={stats[-1]['band_std']:.1f} dB")

    all_db_flat = np.concatenate([s.flatten() for s in all_db])
    vmin = np.percentile(all_db_flat, 2)
    vmax = np.percentile(all_db_flat, 98)
    print(f"Common color scale: {vmin:.1f} to {vmax:.1f} dB")

    # Create figure with GridSpec for proper colorbar placement
    fig = plt.figure(figsize=(16, 10))
    gs = fig.add_gridspec(2, 3, width_ratios=[1, 1, 0.05], wspace=0.3, hspace=0.3)

    axes = [[fig.add_subplot(gs[i, j]) for j in range(2)] for i in range(2)]
    cax = fig.add_subplot(gs[:, 2])  # Colorbar axis spans both rows

    fig.suptitle('State Transition Spectrograms (4 Random Seeds)', fontsize=14, y=0.98)

    im = None
    for idx, (seed, fname) in enumerate(seed_files):
        row, col = idx // 2, idx % 2
        ax = axes[row][col]
        f, t, Sxx_db, dac_data = spectrograms[idx]
        duration = len(dac_data) / 1000

        # Plot spectrogram
        im = ax.pcolormesh(t, f, Sxx_db, shading='gouraud', cmap='jet',
                           vmin=vmin, vmax=vmax)
        ax.set_ylim(4, 50)
        ax.set_xlabel('Time (s)')
        ax.set_ylabel('Frequency (Hz)')

        # Title with statistics
        s = stats[idx]
        ax.set_title(f'Seed {seed} (σ={s["dac_std"]:.0f})', fontsize=11)

        # Add phase boundaries
        phase_duration = duration / 5
        for i in range(1, 5):
            ax.axvline(x=i * phase_duration, color='white', linestyle='--', alpha=0.5)

        # Add band labels
        ax.axhline(y=8, color='white', linestyle=':', alpha=0.3)
        ax.axhline(y=13, color='white', linestyle=':', alpha=0.3)
        ax.axhline(y=30, color='white', linestyle=':', alpha=0.3)

        # Add phase labels at top
        if row == 0:
            for i, label in enumerate(['N', 'N→M', 'M', 'M→N', 'N']):
                ax.text((i + 0.5) * phase_duration, 48, label, ha='center', va='top',
                        color='white', fontsize=8, fontweight='bold')

    # Add colorbar to dedicated axis
    cbar = fig.colorbar(im, cax=cax, label='Power (dB)')

    # Save
    os.makedirs('eeg_analysis', exist_ok=True)
    output_file = 'eeg_analysis/spectrogram_grid_4seeds.png'
    plt.savefig(output_file, dpi=150, bbox_inches='tight')
    print(f"\nSaved: {output_file}")

    plt.close()

if __name__ == '__main__':
    main()
