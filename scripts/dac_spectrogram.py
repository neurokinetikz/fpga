#!/usr/bin/env python3
"""
DAC Output Spectrogram Analysis for phi^n Neural Processor

Simulates the DAC output mixer and creates detailed spectrograms
showing the actual frequency content that would be heard/measured
from the hardware output.

The DAC mixer (v7.3) combines 5 channels for realistic EEG spectrum:
- Theta (5.89 Hz) - weight 0.02
- Motor L6 alpha (9.53 Hz) - weight 0.03
- Motor L5a low-beta (15.42 Hz) - weight 0.02
- Motor L2/3 gamma (40.36 Hz) - weight 0.01
- Pink noise - weight 0.92 (1/f background dominates)

Usage:
    python3 dac_spectrogram.py oscillator_eeg_export.csv
"""

import sys
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm
from scipy import signal
from scipy.fft import fft, fftfreq
from pathlib import Path

# Fixed-point scaling
SCALE = 16384

# DAC mixer weights (from output_mixer.v v7.3 - 8% oscillators, 92% pink noise)
# Total oscillators: ~8%, pink noise: ~92% for EEG-realistic 1/f-dominated spectrum
W_THETA      = 328 / SCALE    # 0.02 - theta
W_ALPHA      = 492 / SCALE    # 0.03 - alpha
W_BETA       = 328 / SCALE    # 0.02 - low beta
W_GAMMA      = 164 / SCALE    # 0.01 - gamma
W_PINK_NOISE = 15073 / SCALE  # 0.92 - 1/f background dominates

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

def load_data(filepath):
    """Load oscillator data."""
    print(f"Loading {filepath}...")
    df = pd.read_csv(filepath)

    metadata = ['time_ms', 'state', 'theta_phase', 'beta_quiet', 'sr_amplification']
    for col in df.columns:
        if col not in metadata:
            df[col] = df[col].astype(float) / SCALE

    return df

def generate_pink_noise(n_samples):
    """Generate 1/f pink noise."""
    # Use Voss-McCartney algorithm approximation
    white = np.random.randn(n_samples)

    # Apply 1/f filter
    freqs = fftfreq(n_samples, 1/FS)
    freqs[0] = 1  # Avoid division by zero

    # 1/f spectrum
    spectrum = fft(white)
    pink_spectrum = spectrum / np.sqrt(np.abs(freqs))
    pink = np.real(np.fft.ifft(pink_spectrum))

    # Normalize
    pink = pink / (np.std(pink) * 3)  # ~[-1, 1]

    return pink

def simulate_dac_output(df):
    """Simulate DAC mixer output from oscillator data (v6.0 5-channel mixer)."""
    n_samples = len(df)

    # Get all 5 channels for realistic EEG spectrum
    theta_x = df['theta_x'].values
    motor_l6 = df['motor_l6_x'].values     # Alpha (9.53 Hz)
    motor_l5a = df['motor_l5a_x'].values   # Beta (15.42 Hz)
    motor_l23 = df['motor_l23_x'].values   # Gamma (40.36 Hz)

    # Generate pink noise
    pink = generate_pink_noise(n_samples)

    # Mix according to output_mixer.v v6.0 weights (5-channel)
    mixed = (W_THETA * theta_x +
             W_ALPHA * motor_l6 +
             W_BETA * motor_l5a +
             W_GAMMA * motor_l23 +
             W_PINK_NOISE * pink)

    # Simulate 12-bit DAC quantization
    # Shift to positive range and scale to 12 bits
    shifted = mixed + 1.0  # Assuming signal in [-1, 1]
    dac_12bit = np.clip(shifted * 2048, 0, 4095).astype(int)

    return mixed, dac_12bit, pink

def create_dac_spectrogram(mixed, output_path):
    """Create detailed spectrogram of DAC output."""

    fig = plt.figure(figsize=(18, 14))

    duration = len(mixed) / FS

    # Main spectrogram
    ax1 = fig.add_axes([0.1, 0.55, 0.75, 0.38])

    # High resolution spectrogram
    f, t, Sxx = signal.spectrogram(mixed, fs=FS, nperseg=2048,
                                    noverlap=1920, scaling='density')

    # Limit frequency range
    freq_mask = f <= 100
    f = f[freq_mask]
    Sxx = Sxx[freq_mask, :]

    # Plot in dB
    Sxx_db = 10 * np.log10(Sxx + 1e-12)

    im = ax1.pcolormesh(t, f, Sxx_db, shading='gouraud', cmap='inferno',
                        vmin=np.percentile(Sxx_db, 5), vmax=np.percentile(Sxx_db, 99))

    # Add phi^n frequency markers
    colors = {'theta': 'white', 'SR': 'lime', 'L': 'cyan'}
    for name, freq in PHI_FREQS.items():
        if freq <= 100:
            color = 'lime' if 'SR' in name else ('white' if 'theta' in name else 'cyan')
            ax1.axhline(y=freq, color=color, linestyle='--', alpha=0.6, linewidth=1)
            ax1.text(duration + 0.3, freq, f'{name}\n({freq:.1f}Hz)',
                    fontsize=7, va='center', color=color)

    ax1.set_ylabel('Frequency (Hz)', fontsize=12)
    ax1.set_title('DAC Output Spectrogram (High Resolution)', fontsize=14)
    ax1.set_xlim(0, duration)
    ax1.set_ylim(0, 80)

    # Colorbar
    cbar = plt.colorbar(im, ax=ax1)
    cbar.set_label('Power (dB)', fontsize=10)

    # Power spectrum (averaged)
    ax2 = fig.add_axes([0.1, 0.32, 0.75, 0.18])

    # Compute Welch PSD
    f_psd, psd = signal.welch(mixed, fs=FS, nperseg=4096, noverlap=3072)
    freq_mask = f_psd <= 100

    ax2.semilogy(f_psd[freq_mask], psd[freq_mask], 'b-', linewidth=1)

    # Mark peaks
    peaks, _ = signal.find_peaks(psd[freq_mask], height=np.max(psd[freq_mask])*0.01,
                                  distance=3, prominence=np.max(psd[freq_mask])*0.005)

    peak_freqs = f_psd[freq_mask][peaks]
    peak_powers = psd[freq_mask][peaks]

    ax2.scatter(peak_freqs, peak_powers, c='red', s=50, zorder=5, marker='v')

    # Annotate top peaks
    sorted_idx = np.argsort(peak_powers)[::-1][:10]
    for idx in sorted_idx:
        ax2.annotate(f'{peak_freqs[idx]:.1f}Hz',
                    xy=(peak_freqs[idx], peak_powers[idx]),
                    xytext=(5, 10), textcoords='offset points',
                    fontsize=8, color='red')

    # Add phi^n markers
    for name, freq in PHI_FREQS.items():
        if freq <= 100:
            ax2.axvline(x=freq, color='gray', linestyle=':', alpha=0.5)

    ax2.set_xlabel('Frequency (Hz)', fontsize=12)
    ax2.set_ylabel('PSD', fontsize=12)
    ax2.set_title('Power Spectral Density with Peak Detection', fontsize=12)
    ax2.set_xlim(0, 80)
    ax2.grid(True, alpha=0.3)

    # Waveform sample
    ax3 = fig.add_axes([0.1, 0.08, 0.75, 0.18])

    # Show first 2 seconds
    t_wave = np.arange(2000) / FS
    ax3.plot(t_wave, mixed[:2000], 'b-', linewidth=0.5)
    ax3.set_xlabel('Time (seconds)', fontsize=12)
    ax3.set_ylabel('DAC Output', fontsize=12)
    ax3.set_title('DAC Output Waveform (First 2 Seconds)', fontsize=12)
    ax3.set_xlim(0, 2)
    ax3.grid(True, alpha=0.3)

    plt.savefig(output_path, dpi=150, bbox_inches='tight', facecolor='white')
    plt.close()
    print(f"Saved: {output_path}")

def analyze_frequency_content(mixed, output_path):
    """Detailed frequency analysis with expected vs measured comparison."""

    fig, axes = plt.subplots(2, 2, figsize=(16, 12))

    # 1. Full spectrum comparison
    ax = axes[0, 0]
    f_psd, psd = signal.welch(mixed, fs=FS, nperseg=4096)
    ax.semilogy(f_psd, psd, 'b-', linewidth=1, label='DAC Output PSD')

    # Mark expected frequencies
    for name, freq in PHI_FREQS.items():
        color = 'green' if 'SR' in name else 'red'
        ax.axvline(x=freq, color=color, linestyle='--', alpha=0.5)

    ax.set_xlabel('Frequency (Hz)')
    ax.set_ylabel('Power Spectral Density')
    ax.set_title('Full Spectrum with Expected Frequencies')
    ax.set_xlim(0, 100)
    ax.legend()
    ax.grid(True, alpha=0.3)

    # 2. Peak frequency table
    ax = axes[0, 1]
    ax.axis('off')

    # Find peaks
    peaks, props = signal.find_peaks(psd, height=np.max(psd)*0.001,
                                      distance=3, prominence=np.max(psd)*0.001)
    peak_freqs = f_psd[peaks]
    peak_powers = psd[peaks]

    # Sort by power
    sorted_idx = np.argsort(peak_powers)[::-1][:15]

    table_text = "DETECTED PEAKS (Top 15)\n"
    table_text += "=" * 50 + "\n"
    table_text += f"{'Rank':<6} {'Freq (Hz)':<12} {'Power':<15} {'Nearest phi^n':<20}\n"
    table_text += "-" * 50 + "\n"

    for rank, idx in enumerate(sorted_idx, 1):
        freq = peak_freqs[idx]
        power = peak_powers[idx]

        # Find nearest expected frequency
        nearest = min(PHI_FREQS.items(), key=lambda x: abs(x[1] - freq))
        error = freq - nearest[1]

        table_text += f"{rank:<6} {freq:<12.2f} {power:<15.2e} {nearest[0]} ({error:+.2f})\n"

    ax.text(0.05, 0.95, table_text, transform=ax.transAxes, fontsize=9,
            verticalalignment='top', fontfamily='monospace',
            bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))

    # 3. Harmonic structure analysis
    ax = axes[1, 0]

    # Check for harmonics of fundamental frequencies
    fundamentals = [5.89, 7.6, 9.53]  # theta, SR f0, alpha

    for fund in fundamentals:
        harmonics = [fund * n for n in range(1, 8) if fund * n <= 100]

        # Extract power at each harmonic
        harmonic_powers = []
        for h in harmonics:
            idx = np.argmin(np.abs(f_psd - h))
            harmonic_powers.append(psd[idx])

        ax.semilogy(range(1, len(harmonics)+1), harmonic_powers, 'o-',
                   label=f'{fund:.2f} Hz fundamental')

    ax.set_xlabel('Harmonic Number')
    ax.set_ylabel('Power')
    ax.set_title('Harmonic Series Analysis')
    ax.legend()
    ax.grid(True, alpha=0.3)

    # 4. Time-frequency coherence
    ax = axes[1, 1]

    # Compute short-time spectral centroid
    window = 500  # 500 ms windows
    hop = 100     # 100 ms hop
    n_windows = (len(mixed) - window) // hop

    centroids = []
    times = []

    for i in range(n_windows):
        start = i * hop
        segment = mixed[start:start+window]
        f_seg, psd_seg = signal.welch(segment, fs=FS, nperseg=256)

        # Spectral centroid
        centroid = np.sum(f_seg * psd_seg) / np.sum(psd_seg)
        centroids.append(centroid)
        times.append((start + window/2) / FS)

    ax.plot(times, centroids, 'b-', linewidth=1)
    ax.axhline(y=40.36, color='red', linestyle='--', label='L2/3 gamma (40.36 Hz)')
    ax.axhline(y=15.42, color='orange', linestyle='--', label='L5a beta (15.42 Hz)')

    ax.set_xlabel('Time (seconds)')
    ax.set_ylabel('Spectral Centroid (Hz)')
    ax.set_title('Time-Varying Spectral Centroid')
    ax.legend()
    ax.set_ylim(0, 60)
    ax.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig(output_path, dpi=150, bbox_inches='tight', facecolor='white')
    plt.close()
    print(f"Saved: {output_path}")

    return peak_freqs[sorted_idx], peak_powers[sorted_idx]

def create_3d_spectrogram(mixed, output_path):
    """Create 3D waterfall spectrogram."""

    from mpl_toolkits.mplot3d import Axes3D

    fig = plt.figure(figsize=(16, 10))
    ax = fig.add_subplot(111, projection='3d')

    # Compute spectrogram
    f, t, Sxx = signal.spectrogram(mixed, fs=FS, nperseg=1024, noverlap=900)

    # Limit frequency range
    freq_mask = f <= 80
    f = f[freq_mask]
    Sxx = Sxx[freq_mask, :]

    # Convert to dB
    Sxx_db = 10 * np.log10(Sxx + 1e-12)

    # Create mesh
    T, F = np.meshgrid(t, f)

    # Plot surface
    surf = ax.plot_surface(T, F, Sxx_db, cmap='viridis',
                           linewidth=0, antialiased=True, alpha=0.8)

    # Add phi^n frequency planes
    for name, freq in [('theta', 5.89), ('L5a', 15.42), ('L2/3', 40.36)]:
        if freq <= 80:
            z_val = np.percentile(Sxx_db, 50)
            ax.plot([0, t[-1]], [freq, freq], [z_val, z_val],
                   'r--', linewidth=2, label=f'{name} ({freq} Hz)')

    ax.set_xlabel('Time (s)')
    ax.set_ylabel('Frequency (Hz)')
    ax.set_zlabel('Power (dB)')
    ax.set_title('3D Spectrogram of DAC Output')

    # Adjust view angle
    ax.view_init(elev=25, azim=-60)

    plt.colorbar(surf, ax=ax, shrink=0.5, label='Power (dB)')

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
        sys.exit(1)

    # Load data
    df = load_data(csv_path)

    # Simulate DAC output
    print("Simulating DAC output mixer...")
    mixed, dac_12bit, pink = simulate_dac_output(df)

    print(f"DAC output range: [{mixed.min():.3f}, {mixed.max():.3f}]")
    print(f"12-bit DAC range: [{dac_12bit.min()}, {dac_12bit.max()}]")

    # Create output directory
    output_dir = Path('eeg_analysis')
    output_dir.mkdir(exist_ok=True)

    # Derive output prefix from input filename
    input_stem = Path(csv_path).stem  # e.g., "state_transition_eeg" or "oscillator_eeg_export"
    output_prefix = input_stem if input_stem != 'oscillator_eeg_export' else 'dac'

    # Generate visualizations
    print(f"\nGenerating DAC spectrogram (prefix: {output_prefix})...")
    create_dac_spectrogram(mixed, output_dir / f'{output_prefix}_spectrogram.png')

    print("Analyzing frequency content...")
    peak_freqs, peak_powers = analyze_frequency_content(mixed, output_dir / f'{output_prefix}_frequency_analysis.png')

    print("Creating 3D spectrogram...")
    create_3d_spectrogram(mixed, output_dir / f'{output_prefix}_3d_spectrogram.png')

    # Print summary
    print("\n" + "=" * 60)
    print("DAC OUTPUT FREQUENCY ANALYSIS SUMMARY")
    print("=" * 60)
    print("\nTop 10 detected frequencies:")
    for i, (freq, power) in enumerate(zip(peak_freqs[:10], peak_powers[:10]), 1):
        # Find nearest expected
        nearest = min(PHI_FREQS.items(), key=lambda x: abs(x[1] - freq))
        error = freq - nearest[1]
        match = "MATCH" if abs(error) < 2 else ""
        print(f"  {i:2d}. {freq:6.2f} Hz  (nearest: {nearest[0]}, error: {error:+.2f} Hz) {match}")

    print("\n" + "=" * 60)
    print(f"Visualizations saved to {output_dir}/")
    print(f"  {output_prefix}_spectrogram.png")
    print(f"  {output_prefix}_frequency_analysis.png")
    print(f"  {output_prefix}_3d_spectrogram.png")

if __name__ == '__main__':
    main()
