#!/usr/bin/env python3
"""
State Transition Spectrogram Generator

Generates a spectrogram visualization from the state transition DAC output,
showing smooth NORMAL ↔ MEDITATION transitions with MU interpolation.

Timeline (600 seconds):
- Phase 0 (0-120s):     NORMAL baseline
- Phase 1 (120-240s):   Smooth transition NORMAL → MEDITATION
- Phase 2 (240-360s):   MEDITATION steady-state
- Phase 3 (360-480s):   Smooth transition MEDITATION → NORMAL
- Phase 4 (480-600s):   NORMAL steady-state

Expected observations:
- Theta (5.89 Hz) and alpha (9.53 Hz): stable throughout (MU unchanged)
- Beta (15.42 Hz, 24.94 Hz) and gamma (40.36 Hz):
  - Full power in NORMAL phases (0-120s, 480-600s)
  - Reduced amplitude (~50%) in MEDITATION phase (240-360s)
  - Smooth gradient during transitions (120-240s, 360-480s)
- 1/f^φ pink noise background: continuous throughout

Usage:
    python3 scripts/state_transition_spectrogram.py
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy import signal
import os

def main():
    # Load DAC output
    csv_path = 'state_transition_dac.csv'
    if not os.path.exists(csv_path):
        print(f"ERROR: {csv_path} not found!")
        print("Run the Verilog simulation first:")
        print("  iverilog -o tb_state_transition_spectrogram.vvp -s tb_state_transition_spectrogram \\")
        print("      src/*.v tb/tb_state_transition_spectrogram.v && \\")
        print("  vvp tb_state_transition_spectrogram.vvp")
        return

    print(f"Loading {csv_path}...")
    df = pd.read_csv(csv_path)
    print(f"  Loaded {len(df)} samples ({len(df)/1000:.1f} seconds at 1 kHz)")

    # Parameters
    fs = 1000  # 1 kHz sample rate
    dac_values = df['dac_output'].values
    phases = df['phase'].values
    # v11.4: Changed from mu_l5b to state_select
    state_values = df['state_select'].values if 'state_select' in df.columns else df.get('mu_l5b', np.zeros(len(df))).values

    # Convert 12-bit DAC to float [-1, 1]
    dac_float = (dac_values.astype(float) - 2048) / 2048

    # Generate spectrogram
    # Use 4-second window for good frequency resolution at low frequencies
    nperseg = 4096  # 4 second window at 1 kHz
    noverlap = 3584  # 87.5% overlap for smooth time resolution

    print("Computing spectrogram...")
    f, t, Sxx = signal.spectrogram(dac_float, fs,
                                    nperseg=nperseg,
                                    noverlap=noverlap,
                                    window='hamming')

    # Create output directory if needed
    os.makedirs('eeg_analysis', exist_ok=True)

    #=========================================================================
    # Plot 1: Main Spectrogram with Phase Annotations
    #=========================================================================
    fig, axes = plt.subplots(2, 1, figsize=(20, 10), height_ratios=[3, 1])

    ax1 = axes[0]

    # Limit to 0-80 Hz (covers all relevant EEG bands)
    freq_mask = f <= 80

    # Plot spectrogram
    power_db = 10 * np.log10(Sxx[freq_mask, :] + 1e-10)
    im = ax1.pcolormesh(t, f[freq_mask], power_db,
                        shading='gouraud', cmap='viridis',
                        vmin=-60, vmax=-20)

    # φⁿ frequency markers (golden ratio architecture)
    phi_freqs = {
        5.89: 'θ (φ⁻⁰·⁵)',
        9.53: 'α (φ⁰·⁵)',
        15.42: 'β₁ (φ¹·⁵)',
        24.94: 'β₂ (φ²·⁵)',
        40.36: 'γ₁ (φ³·⁵)',
        65.30: 'γ₂ (φ⁴·⁵)'
    }

    for freq, label in phi_freqs.items():
        if freq <= 80:
            ax1.axhline(freq, color='white', linestyle='--', alpha=0.5, linewidth=0.8)
            ax1.text(10, freq + 1.5, label, color='white', fontsize=8, alpha=0.8)

    # Phase boundary markers
    phase_times = [0, 120, 240, 360, 480, 600]
    phase_names = ['NORMAL', 'N→M', 'MEDITATION', 'M→N', 'NORMAL']
    phase_colors = ['#00ff00', '#ffff00', '#0080ff', '#ffff00', '#00ff00']

    for i, (start, end) in enumerate(zip(phase_times[:-1], phase_times[1:])):
        # Phase boundary line
        if i > 0:
            ax1.axvline(start, color='red', linestyle='-', alpha=0.6, linewidth=2)

        # Phase label
        mid = (start + end) / 2
        ax1.text(mid, 75, phase_names[i], ha='center', va='top',
                fontsize=11, color='white', fontweight='bold',
                bbox=dict(boxstyle='round,pad=0.3', facecolor=phase_colors[i],
                         alpha=0.5, edgecolor='none'))

    ax1.set_xlabel('Time (s)', fontsize=12)
    ax1.set_ylabel('Frequency (Hz)', fontsize=12)
    ax1.set_title('State Transition Spectrogram: NORMAL ↔ MEDITATION\n'
                  '(MU interpolation over 120-second transitions)', fontsize=14)
    ax1.set_xlim(0, 600)
    ax1.set_ylim(0, 80)

    plt.colorbar(im, ax=ax1, label='Power (dB)', shrink=0.8)

    #=========================================================================
    # Plot 2: State Select Timeline
    #=========================================================================
    ax2 = axes[1]

    time_axis = np.arange(len(state_values)) / 1000  # Convert to seconds
    ax2.plot(time_axis, state_values, 'b-', linewidth=1.5, label='state_select (0=NORMAL, 4=MEDITATION)')
    ax2.fill_between(time_axis, 0, state_values, alpha=0.3)

    # Phase boundary markers
    for i, start in enumerate(phase_times[1:-1], 1):
        ax2.axvline(start, color='red', linestyle='--', alpha=0.6, linewidth=1)

    ax2.set_xlabel('Time (s)', fontsize=12)
    ax2.set_ylabel('State', fontsize=12)
    ax2.set_title('State Select (0=NORMAL, 4=MEDITATION)', fontsize=12)
    ax2.set_xlim(0, 600)
    ax2.set_ylim(-0.5, 5)
    ax2.legend(loc='upper right')
    ax2.grid(True, alpha=0.3)

    # Add annotations for MU levels
    ax2.axhline(4, color='green', linestyle=':', alpha=0.5, linewidth=1)
    ax2.axhline(2, color='blue', linestyle=':', alpha=0.5, linewidth=1)
    ax2.text(30, 4.2, 'NORMAL (μ=4)', color='green', fontsize=9)
    ax2.text(270, 2.2, 'MEDITATION (μ=2)', color='blue', fontsize=9)

    plt.tight_layout()

    output_path = 'eeg_analysis/state_transition_spectrogram.png'
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    print(f"Saved: {output_path}")

    #=========================================================================
    # Plot 3: Band Power Time Series
    #=========================================================================
    fig2, ax3 = plt.subplots(figsize=(20, 6))

    # Define frequency bands
    bands = {
        'Theta (4-8 Hz)': (4, 8),
        'Alpha (8-13 Hz)': (8, 13),
        'Beta (13-30 Hz)': (13, 30),
        'Gamma (30-80 Hz)': (30, 80)
    }

    colors = ['purple', 'green', 'orange', 'red']

    for (band_name, (low, high)), color in zip(bands.items(), colors):
        # Find frequency indices for this band
        band_mask = (f >= low) & (f <= high)
        # Average power in band over time
        band_power = 10 * np.log10(np.mean(Sxx[band_mask, :], axis=0) + 1e-10)
        ax3.plot(t, band_power, color=color, linewidth=1.5, label=band_name, alpha=0.8)

    # Phase boundary markers
    for start in phase_times[1:-1]:
        ax3.axvline(start, color='gray', linestyle='--', alpha=0.6, linewidth=1)

    ax3.set_xlabel('Time (s)', fontsize=12)
    ax3.set_ylabel('Band Power (dB)', fontsize=12)
    ax3.set_title('Band Power Over Time During State Transitions', fontsize=14)
    ax3.set_xlim(0, 600)
    ax3.legend(loc='upper right')
    ax3.grid(True, alpha=0.3)

    # Add phase labels
    for i, (start, end) in enumerate(zip(phase_times[:-1], phase_times[1:])):
        mid = (start + end) / 2
        ypos = ax3.get_ylim()[1] - 2
        ax3.text(mid, ypos, phase_names[i], ha='center', fontsize=10,
                fontweight='bold', alpha=0.7)

    plt.tight_layout()

    output_path2 = 'eeg_analysis/state_transition_band_power.png'
    plt.savefig(output_path2, dpi=150, bbox_inches='tight')
    print(f"Saved: {output_path2}")

    #=========================================================================
    # Summary Statistics
    #=========================================================================
    print("\n" + "="*60)
    print("SUMMARY: Band Power Changes by Phase")
    print("="*60)

    for i, (phase_name, start, end) in enumerate(zip(phase_names, phase_times[:-1], phase_times[1:])):
        # Find time indices for this phase
        t_mask = (t >= start) & (t < end)
        if not np.any(t_mask):
            continue

        print(f"\nPhase {i}: {phase_name} ({start}-{end}s)")
        print("-" * 40)

        for band_name, (low, high) in bands.items():
            band_mask = (f >= low) & (f <= high)
            phase_power = Sxx[band_mask, :][:, t_mask]
            mean_power = 10 * np.log10(np.mean(phase_power) + 1e-10)
            print(f"  {band_name}: {mean_power:.1f} dB")

    print("\n" + "="*60)
    print("Spectrogram generation complete!")
    print(f"Output files in: eeg_analysis/")
    print("="*60)

if __name__ == '__main__':
    main()
