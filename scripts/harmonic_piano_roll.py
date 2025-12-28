#!/usr/bin/env python3
"""
Harmonic Piano Roll Visualization for phi^n Neural Processor

Creates a time-frequency "piano roll" showing power spectral density
of all oscillators organized by their phi^n harmonic frequencies.

Usage:
    python3 harmonic_piano_roll.py oscillator_eeg_export.csv
"""

import sys
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm
from scipy import signal
from pathlib import Path

# Fixed-point scaling
SCALE = 16384

# Oscillator definitions with phi^n frequencies (Hz)
# Organized from low to high frequency
OSCILLATORS = [
    # Thalamic
    {'name': 'Theta', 'col': 'theta_x', 'freq': 5.89, 'phi': '-0.5', 'color': 'purple', 'group': 'Thalamus'},

    # SR Harmonics
    {'name': 'SR f0', 'col': 'sr_f0_x', 'freq': 7.6, 'phi': 'SR', 'color': 'green', 'group': 'Schumann'},
    {'name': 'SR f1', 'col': 'sr_f1_x', 'freq': 13.75, 'phi': 'SR', 'color': 'green', 'group': 'Schumann'},
    {'name': 'SR f2', 'col': 'sr_f2_x', 'freq': 20.0, 'phi': 'SR', 'color': 'green', 'group': 'Schumann'},
    {'name': 'SR f3', 'col': 'sr_f3_x', 'freq': 25.0, 'phi': 'SR', 'color': 'green', 'group': 'Schumann'},
    {'name': 'SR f4', 'col': 'sr_f4_x', 'freq': 32.0, 'phi': 'SR', 'color': 'green', 'group': 'Schumann'},

    # Cortical - L6 (Alpha)
    {'name': 'S-L6', 'col': 'sensory_l6_x', 'freq': 9.53, 'phi': '0.5', 'color': 'blue', 'group': 'L6 Alpha'},
    {'name': 'A-L6', 'col': 'assoc_l6_x', 'freq': 9.53, 'phi': '0.5', 'color': 'blue', 'group': 'L6 Alpha'},
    {'name': 'M-L6', 'col': 'motor_l6_x', 'freq': 9.53, 'phi': '0.5', 'color': 'blue', 'group': 'L6 Alpha'},

    # Cortical - L5a (Low Beta)
    {'name': 'S-L5a', 'col': 'sensory_l5a_x', 'freq': 15.42, 'phi': '1.5', 'color': 'cyan', 'group': 'L5a Beta'},
    {'name': 'A-L5a', 'col': 'assoc_l5a_x', 'freq': 15.42, 'phi': '1.5', 'color': 'cyan', 'group': 'L5a Beta'},
    {'name': 'M-L5a', 'col': 'motor_l5a_x', 'freq': 15.42, 'phi': '1.5', 'color': 'cyan', 'group': 'L5a Beta'},

    # Cortical - L5b (High Beta)
    {'name': 'S-L5b', 'col': 'sensory_l5b_x', 'freq': 24.94, 'phi': '2.5', 'color': 'orange', 'group': 'L5b Beta'},
    {'name': 'A-L5b', 'col': 'assoc_l5b_x', 'freq': 24.94, 'phi': '2.5', 'color': 'orange', 'group': 'L5b Beta'},
    {'name': 'M-L5b', 'col': 'motor_l5b_x', 'freq': 24.94, 'phi': '2.5', 'color': 'orange', 'group': 'L5b Beta'},

    # Cortical - L4 (Low Gamma)
    {'name': 'S-L4', 'col': 'sensory_l4_x', 'freq': 31.73, 'phi': '3', 'color': 'red', 'group': 'L4 Gamma'},
    {'name': 'A-L4', 'col': 'assoc_l4_x', 'freq': 31.73, 'phi': '3', 'color': 'red', 'group': 'L4 Gamma'},
    {'name': 'M-L4', 'col': 'motor_l4_x', 'freq': 31.73, 'phi': '3', 'color': 'red', 'group': 'L4 Gamma'},

    # Cortical - L2/3 (Gamma)
    {'name': 'S-L2/3', 'col': 'sensory_l23_x', 'freq': 40.36, 'phi': '3.5', 'color': 'magenta', 'group': 'L2/3 Gamma'},
    {'name': 'A-L2/3', 'col': 'assoc_l23_x', 'freq': 40.36, 'phi': '3.5', 'color': 'magenta', 'group': 'L2/3 Gamma'},
    {'name': 'M-L2/3', 'col': 'motor_l23_x', 'freq': 40.36, 'phi': '3.5', 'color': 'magenta', 'group': 'L2/3 Gamma'},
]

def load_data(filepath):
    """Load and scale oscillator data."""
    print(f"Loading {filepath}...")
    df = pd.read_csv(filepath)

    metadata = ['time_ms', 'state', 'theta_phase', 'beta_quiet', 'sr_amplification']
    for col in df.columns:
        if col not in metadata:
            df[col] = df[col].astype(float) / SCALE

    return df

def compute_spectrogram(signal_data, fs=1000, nperseg=512, noverlap=480):
    """Compute spectrogram for a signal."""
    f, t, Sxx = signal.spectrogram(signal_data, fs=fs, nperseg=nperseg,
                                    noverlap=noverlap, scaling='density')
    return f, t, Sxx

def create_harmonic_piano_roll(df, output_path):
    """Create the main piano roll visualization."""

    n_oscillators = len(OSCILLATORS)
    duration = len(df) / 1000  # seconds

    # Compute spectrograms for all oscillators
    print("Computing spectrograms...")
    spectrograms = []
    for osc in OSCILLATORS:
        if osc['col'] in df.columns:
            sig = df[osc['col']].values
            f, t, Sxx = compute_spectrogram(sig)
            spectrograms.append({'osc': osc, 'f': f, 't': t, 'Sxx': Sxx})

    # Create figure
    fig = plt.figure(figsize=(20, 14))

    # Main spectrogram panel
    ax_main = fig.add_axes([0.1, 0.35, 0.75, 0.55])

    # Create combined piano roll image
    # Y-axis: oscillators sorted by frequency
    # X-axis: time
    # Color: power at the oscillator's target frequency band

    time_bins = spectrograms[0]['t']
    n_time = len(time_bins)

    # Extract power at each oscillator's expected frequency
    piano_roll = np.zeros((n_oscillators, n_time))

    for i, spec in enumerate(spectrograms):
        osc = spec['osc']
        target_freq = osc['freq']
        f = spec['f']
        Sxx = spec['Sxx']

        # Find frequency bin closest to target
        freq_idx = np.argmin(np.abs(f - target_freq))

        # Also include neighboring bins for bandwidth
        bandwidth = 5  # Hz
        freq_mask = (f >= target_freq - bandwidth) & (f <= target_freq + bandwidth)

        # Sum power in bandwidth
        if np.any(freq_mask):
            piano_roll[i, :] = np.sum(Sxx[freq_mask, :], axis=0)
        else:
            piano_roll[i, :] = Sxx[freq_idx, :]

    # Normalize each row independently for better visibility
    for i in range(n_oscillators):
        row_max = np.max(piano_roll[i, :])
        if row_max > 0:
            piano_roll[i, :] = piano_roll[i, :] / row_max

    # Plot piano roll
    im = ax_main.imshow(piano_roll, aspect='auto', origin='lower',
                        extent=[0, duration, 0, n_oscillators],
                        cmap='magma', vmin=0, vmax=1)

    # Add oscillator labels
    y_labels = [f"{osc['name']} ({osc['freq']:.1f} Hz)" for osc in OSCILLATORS]
    ax_main.set_yticks(np.arange(n_oscillators) + 0.5)
    ax_main.set_yticklabels(y_labels, fontsize=8)

    # Add frequency group separators
    group_boundaries = []
    current_group = OSCILLATORS[0]['group']
    for i, osc in enumerate(OSCILLATORS):
        if osc['group'] != current_group:
            group_boundaries.append(i)
            current_group = osc['group']

    for boundary in group_boundaries:
        ax_main.axhline(y=boundary, color='white', linewidth=0.5, linestyle='--', alpha=0.5)

    ax_main.set_xlabel('Time (seconds)', fontsize=12)
    ax_main.set_ylabel('Oscillator (sorted by frequency)', fontsize=12)
    ax_main.set_title('Harmonic Piano Roll: Power at Target Frequencies Over Time', fontsize=14)

    # Colorbar
    cax = fig.add_axes([0.87, 0.35, 0.02, 0.55])
    plt.colorbar(im, cax=cax, label='Normalized Power')

    # Add waveform panel at bottom
    ax_wave = fig.add_axes([0.1, 0.08, 0.75, 0.2])

    # Plot theta and L2/3 gamma as reference
    time_s = df['time_ms'].values / 1000

    # Downsample for plotting
    downsample = 10
    time_ds = time_s[::downsample]
    theta_ds = df['theta_x'].values[::downsample]
    l23_ds = df['sensory_l23_x'].values[::downsample]

    ax_wave.plot(time_ds, theta_ds, 'purple', alpha=0.7, linewidth=0.5, label='Theta')
    ax_wave.plot(time_ds, l23_ds, 'magenta', alpha=0.7, linewidth=0.5, label='L2/3 Gamma')
    ax_wave.set_xlabel('Time (seconds)', fontsize=10)
    ax_wave.set_ylabel('Amplitude', fontsize=10)
    ax_wave.set_xlim(0, duration)
    ax_wave.legend(loc='upper right', fontsize=8)
    ax_wave.set_title('Reference Waveforms: Theta & Gamma', fontsize=10)
    ax_wave.grid(True, alpha=0.3)

    # Add phi^n frequency scale on right side
    ax_phi = fig.add_axes([0.86, 0.35, 0.02, 0.55])
    ax_phi.set_ylim(0, n_oscillators)
    ax_phi.set_yticks(np.arange(n_oscillators) + 0.5)
    ax_phi.set_yticklabels([osc['phi'] for osc in OSCILLATORS], fontsize=7)
    ax_phi.set_ylabel('phi exponent', fontsize=9)
    ax_phi.yaxis.set_label_position('right')
    ax_phi.yaxis.tick_right()
    ax_phi.set_xticks([])

    plt.savefig(output_path, dpi=150, bbox_inches='tight', facecolor='white')
    plt.close()
    print(f"Saved: {output_path}")

def create_frequency_waterfall(df, output_path):
    """Create a 3D-style waterfall plot of frequency content over time."""

    fig, ax = plt.subplots(figsize=(16, 10))

    # Compute spectrogram of combined signal (sum of all oscillators)
    oscillator_cols = [osc['col'] for osc in OSCILLATORS if osc['col'] in df.columns]
    combined = np.zeros(len(df))
    for col in oscillator_cols:
        combined += df[col].values

    f, t, Sxx = compute_spectrogram(combined, nperseg=1024, noverlap=960)

    # Limit to relevant frequency range
    freq_mask = f <= 100
    f = f[freq_mask]
    Sxx = Sxx[freq_mask, :]

    # Plot spectrogram
    im = ax.pcolormesh(t, f, 10 * np.log10(Sxx + 1e-10),
                       shading='gouraud', cmap='viridis')

    # Add phi^n frequency lines
    phi = 1.618033988749895
    phi_freqs = {
        'theta (phi^-0.5)': 5.89,
        'L6 (phi^0.5)': 9.53,
        'L5a (phi^1.5)': 15.42,
        'L5b (phi^2.5)': 24.94,
        'L4 (phi^3)': 31.73,
        'L2/3 (phi^3.5)': 40.36,
        'fast gamma (phi^4.5)': 65.3,
    }

    colors = ['purple', 'blue', 'cyan', 'orange', 'red', 'magenta', 'pink']
    for (name, freq), color in zip(phi_freqs.items(), colors):
        ax.axhline(y=freq, color=color, linestyle='--', alpha=0.7, linewidth=1.5)
        ax.text(t[-1] + 0.5, freq, name, fontsize=8, va='center', color=color)

    # SR frequencies
    sr_freqs = [7.6, 13.75, 20, 25, 32]
    for freq in sr_freqs:
        ax.axhline(y=freq, color='green', linestyle=':', alpha=0.5, linewidth=1)

    ax.set_xlabel('Time (seconds)', fontsize=12)
    ax.set_ylabel('Frequency (Hz)', fontsize=12)
    ax.set_title('Time-Frequency Spectrogram with phi^n Harmonic Structure', fontsize=14)
    ax.set_ylim(0, 80)

    cbar = plt.colorbar(im, ax=ax, label='Power (dB)')

    plt.savefig(output_path, dpi=150, bbox_inches='tight', facecolor='white')
    plt.close()
    print(f"Saved: {output_path}")

def create_amplitude_envelope_roll(df, output_path):
    """Create piano roll showing amplitude envelopes over time."""

    from scipy.signal import hilbert

    fig, ax = plt.subplots(figsize=(18, 12))

    n_oscillators = len(OSCILLATORS)
    duration = len(df) / 1000
    time_s = df['time_ms'].values / 1000

    # Compute and plot amplitude envelopes
    for i, osc in enumerate(OSCILLATORS):
        if osc['col'] not in df.columns:
            continue

        sig = df[osc['col']].values
        sig_centered = sig - sig.mean()

        # Compute amplitude envelope
        analytic = hilbert(sig_centered)
        amplitude = np.abs(analytic)

        # Smooth the envelope
        window = 50  # 50 ms smoothing
        amplitude_smooth = np.convolve(amplitude, np.ones(window)/window, mode='same')

        # Normalize
        amp_norm = amplitude_smooth / (amplitude_smooth.max() + 1e-10)

        # Plot as filled area offset by oscillator index
        baseline = i
        ax.fill_between(time_s, baseline, baseline + amp_norm * 0.8,
                       alpha=0.7, color=osc['color'], linewidth=0)
        ax.plot(time_s, baseline + amp_norm * 0.8,
               color=osc['color'], linewidth=0.3, alpha=0.8)

    # Labels
    ax.set_yticks(np.arange(n_oscillators) + 0.4)
    ax.set_yticklabels([f"{osc['name']} ({osc['freq']:.1f} Hz)" for osc in OSCILLATORS], fontsize=8)

    ax.set_xlabel('Time (seconds)', fontsize=12)
    ax.set_ylabel('Oscillator', fontsize=12)
    ax.set_title('Amplitude Envelope Piano Roll', fontsize=14)
    ax.set_xlim(0, duration)
    ax.set_ylim(-0.2, n_oscillators + 0.2)
    ax.grid(True, axis='x', alpha=0.3)

    plt.savefig(output_path, dpi=150, bbox_inches='tight', facecolor='white')
    plt.close()
    print(f"Saved: {output_path}")

def main():
    if len(sys.argv) < 2:
        csv_path = 'oscillator_eeg_export.csv'
    else:
        csv_path = sys.argv[1]

    if not Path(csv_path).exists():
        print(f"Error: {csv_path} not found")
        print("Run: make iverilog-eeg first")
        sys.exit(1)

    # Load data
    df = load_data(csv_path)

    # Create output directory
    output_dir = Path('eeg_analysis')
    output_dir.mkdir(exist_ok=True)

    # Generate visualizations
    print("\nGenerating harmonic piano roll...")
    create_harmonic_piano_roll(df, output_dir / 'harmonic_piano_roll.png')

    print("Generating frequency waterfall...")
    create_frequency_waterfall(df, output_dir / 'frequency_waterfall.png')

    print("Generating amplitude envelope roll...")
    create_amplitude_envelope_roll(df, output_dir / 'amplitude_envelope_roll.png')

    print(f"\nVisualization complete! Check {output_dir}/")

if __name__ == '__main__':
    main()
