#!/usr/bin/env python3
"""
SR Realism Analysis - 3-Day Validation

Generates 3-panel visualization comparing simulated SR data to real geophysical
observations. Format matches typical SR monitoring station output.

Usage:
    python3 scripts/analyze_sr_realism.py
    python3 scripts/analyze_sr_realism.py --input sr_realism_3day.csv

Output:
    sr_analysis/sr_realism_3day.png - 3-panel plot (F, A, Q)
    sr_analysis/sr_histograms.png - Distribution histograms
    sr_analysis/sr_statistics.txt - Summary statistics
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import argparse
import os
import sys

# Real SR data reference ranges (from Dec 2025 geophysical data)
SR_REFERENCE = {
    'F1': {'center': 7.75, 'range': (7.25, 8.25), 'observed': (7.3, 8.2)},
    'F2': {'center': 13.75, 'range': (12.95, 14.55), 'observed': (13.5, 14.7)},
    'F3': {'center': 20.0, 'range': (19.0, 21.0), 'observed': (19.5, 20.7)},
    'F4': {'center': 25.0, 'range': (23.5, 26.5), 'observed': (24.3, 26.6)},
    'F5': {'center': 32.0, 'range': (30.0, 34.0), 'observed': (30.0, 34.0)},

    'A1': {'center': 10, 'range': (2, 19)},
    'A2': {'center': 8, 'range': (2, 15)},
    'A3': {'center': 3.5, 'range': (1, 6)},
    'A4': {'center': 2, 'range': (1, 3)},
    'A5': {'center': 1.5, 'range': (0.5, 3)},

    'Q1': {'center': 7.5, 'range': (5, 16)},
    'Q2': {'center': 9.5, 'range': (6, 14)},
    'Q3': {'center': 15.5, 'range': (5, 21)},
    'Q4': {'center': 8.5, 'range': (5, 15)},
    'Q5': {'center': 7.0, 'range': (4, 12)},
}

# Colors matching real SR monitoring plots
COLORS = {
    'F1': '#FFFFFF',  # White
    'F2': '#FFFF00',  # Yellow
    'F3': '#FF0000',  # Red
    'F4': '#00FF00',  # Green
    'F5': '#00FFFF',  # Cyan (added for F5)
}

LABELS = ['f1 (7.75 Hz)', 'f2 (13.75 Hz)', 'f3 (20 Hz)', 'f4 (25 Hz)', 'f5 (32 Hz)']


def load_data(filepath, sample_rate=None):
    """Load CSV and validate columns.

    Args:
        filepath: Path to CSV file
        sample_rate: Samples per second (auto-detected if None)
    """
    print(f"Loading {filepath}...")

    if not os.path.exists(filepath):
        print(f"ERROR: {filepath} not found!")
        print("\nRun the simulation first:")
        print("  make iverilog-sr-realism")
        print("  # or manually:")
        print("  iverilog -o tb_sr_realism_3day.vvp -s tb_sr_realism_3day -DFAST_SIM \\")
        print("      src/clock_enable_generator.v src/hopf_oscillator.v \\")
        print("      src/sr_frequency_drift.v src/sr_q_factor_drift.v \\")
        print("      tb/tb_sr_realism_3day.v && vvp tb_sr_realism_3day.vvp")
        sys.exit(1)

    df = pd.read_csv(filepath)

    # Validate expected columns
    expected_cols = ['time_s', 'F1', 'F2', 'F3', 'F4', 'F5',
                     'A1', 'A2', 'A3', 'A4', 'A5',
                     'Q1', 'Q2', 'Q3', 'Q4', 'Q5']
    missing = [c for c in expected_cols if c not in df.columns]
    if missing:
        print(f"WARNING: Missing columns: {missing}")

    # Auto-detect sample rate if not provided
    # time_s column contains sample indices, not actual seconds
    # Heuristic: if max(time_s) >> num_samples, assume 1 Hz; otherwise detect from data
    n_samples = len(df)
    max_time_s = df['time_s'].max()

    if sample_rate is None:
        # Common sample rates: 1 Hz (4000 divisor), 10 Hz (400 divisor), 100 Hz (40 divisor)
        # The time_s column is sample index, so actual_seconds = time_s / sample_rate
        # Try to detect based on reasonable simulation durations
        if max_time_s == n_samples - 1:
            # time_s is just row index - need to infer sample rate
            # Assume 10 Hz if we have round numbers suggesting that
            if n_samples % 36000 == 0:  # 1 hour at 10 Hz
                sample_rate = 10.0
            elif n_samples % 3600 == 0:  # 1 hour at 1 Hz
                sample_rate = 1.0
            else:
                sample_rate = 10.0  # Default to 10 Hz
        else:
            sample_rate = 1.0

    # Convert sample index to actual hours
    # Each sample represents 1/sample_rate seconds
    df['hours'] = df['time_s'] / sample_rate / 3600.0

    duration_hours = df['hours'].max()
    print(f"  Loaded {n_samples} samples ({duration_hours:.2f} hours at {sample_rate} Hz)")

    return df, duration_hours


def plot_3panel(df, output_dir, duration_hours):
    """Generate 3-panel SR visualization matching real monitoring format."""

    # Create figure with dark background like real SR plots
    fig, axes = plt.subplots(3, 1, figsize=(16, 12), facecolor='#1a1a1a')

    hours = df['hours']

    # Determine x-axis scaling based on actual duration
    max_hours = max(duration_hours, 1)  # Minimum 1 hour
    if max_hours <= 2:
        x_tick_step = 0.25
        title_duration = f"{max_hours:.1f} Hour"
    elif max_hours <= 12:
        x_tick_step = 1
        title_duration = f"{max_hours:.0f} Hour"
    elif max_hours <= 24:
        x_tick_step = 2
        title_duration = f"{max_hours:.0f} Hour"
    else:
        x_tick_step = 6
        title_duration = f"{max_hours:.0f} Hour"

    #=========================================================================
    # Panel 1: Frequencies
    #=========================================================================
    ax1 = axes[0]
    ax1.set_facecolor('#0a0a0a')

    freq_cols = ['F1', 'F2', 'F3', 'F4', 'F5']
    for col in freq_cols:
        ax1.plot(hours, df[col], color=COLORS[col], linewidth=0.5, alpha=0.9, label=col)

    ax1.set_ylabel('Frequency (Hz)', fontsize=11, color='white')
    ax1.set_title(f'Schumann Resonance Frequencies - {title_duration} Simulation',
                  fontsize=14, color='white', fontweight='bold')
    ax1.legend(loc='upper right', ncol=5, fontsize=9,
               facecolor='#2a2a2a', edgecolor='gray', labelcolor='white')
    ax1.grid(True, alpha=0.2, color='gray')
    ax1.tick_params(colors='white')
    for spine in ax1.spines.values():
        spine.set_color('gray')

    # Add center frequency lines
    for col in freq_cols:
        ax1.axhline(SR_REFERENCE[col]['center'], color=COLORS[col],
                    linestyle='--', alpha=0.3, linewidth=0.5)

    ax1.set_ylim(5, 35)
    ax1.set_xlim(0, max_hours)

    #=========================================================================
    # Panel 2: Amplitudes (with vertical offset for visibility)
    #=========================================================================
    ax2 = axes[1]
    ax2.set_facecolor('#0a0a0a')

    amp_cols = ['A1', 'A2', 'A3', 'A4', 'A5']
    offsets = [0, 30, 60, 90, 120]  # Vertical offsets for each harmonic

    for i, col in enumerate(amp_cols):
        # Apply offset for visual separation
        offset_data = df[col] + offsets[i]
        ax2.plot(hours, offset_data, color=COLORS[f'F{i+1}'], linewidth=0.5, alpha=0.9,
                 label=f'{col} (offset +{offsets[i]})')

    ax2.set_ylabel('Amplitude (normalized, offset)', fontsize=11, color='white')
    ax2.set_title('Schumann Resonance Amplitudes (stacked for visibility)',
                  fontsize=14, color='white', fontweight='bold')
    ax2.legend(loc='upper right', ncol=5, fontsize=8,
               facecolor='#2a2a2a', edgecolor='gray', labelcolor='white')
    ax2.grid(True, alpha=0.2, color='gray')
    ax2.tick_params(colors='white')
    for spine in ax2.spines.values():
        spine.set_color('gray')

    # Y-axis range to show all offset traces
    max_amp = df[amp_cols].max().max()
    ax2.set_ylim(0, max_amp + offsets[-1] + 50)
    ax2.set_xlim(0, max_hours)

    #=========================================================================
    # Panel 3: Q-Factors (with vertical offset for visibility)
    #=========================================================================
    ax3 = axes[2]
    ax3.set_facecolor('#0a0a0a')

    q_cols = ['Q1', 'Q2', 'Q3', 'Q4', 'Q5']
    q_offsets = [0, 5, 10, 15, 20]  # Smaller offsets for Q

    for i, col in enumerate(q_cols):
        offset_data = df[col] + q_offsets[i]
        ax3.plot(hours, offset_data, color=COLORS[f'F{i+1}'], linewidth=0.5, alpha=0.9,
                 label=f'{col} (offset +{q_offsets[i]})')

    ax3.set_xlabel('Time (hours)', fontsize=11, color='white')
    ax3.set_ylabel('Q-Factor (offset)', fontsize=11, color='white')
    ax3.set_title('Quality Factors of Schumann Resonances (stacked for visibility)',
                  fontsize=14, color='white', fontweight='bold')
    ax3.legend(loc='upper right', ncol=5, fontsize=8,
               facecolor='#2a2a2a', edgecolor='gray', labelcolor='white')
    ax3.grid(True, alpha=0.2, color='gray')
    ax3.tick_params(colors='white')
    for spine in ax3.spines.values():
        spine.set_color('gray')

    max_q = df[q_cols].max().max()
    ax3.set_ylim(0, max_q + q_offsets[-1] + 10)
    ax3.set_xlim(0, max_hours)

    # X-axis ticks for all panels
    x_ticks = np.arange(0, max_hours + x_tick_step, x_tick_step)
    for ax in axes:
        ax.set_xticks(x_ticks)

    # Add day markers if duration > 24 hours
    if max_hours >= 24:
        for ax in axes:
            ax.axvline(24, color='gray', linestyle='-', alpha=0.5, linewidth=1)
            if max_hours >= 48:
                ax.axvline(48, color='gray', linestyle='-', alpha=0.5, linewidth=1)

        # Day labels
        if max_hours >= 24:
            axes[0].text(12, axes[0].get_ylim()[1] * 0.95, 'Day 1',
                         ha='center', fontsize=10, color='white', alpha=0.7)
        if max_hours >= 48:
            axes[0].text(36, axes[0].get_ylim()[1] * 0.95, 'Day 2',
                         ha='center', fontsize=10, color='white', alpha=0.7)
        if max_hours >= 72:
            axes[0].text(60, axes[0].get_ylim()[1] * 0.95, 'Day 3',
                         ha='center', fontsize=10, color='white', alpha=0.7)

    plt.tight_layout()

    output_path = os.path.join(output_dir, 'sr_realism_3day.png')
    plt.savefig(output_path, dpi=150, bbox_inches='tight', facecolor='#1a1a1a')
    print(f"  Saved: {output_path}")
    plt.close()


def plot_frequency_detail(df, output_dir, duration_hours):
    """Generate detailed frequency plots with individual Y-axis scaling."""

    fig, axes = plt.subplots(5, 1, figsize=(16, 14), facecolor='#1a1a1a')

    hours = df['hours']
    max_hours = max(duration_hours, 1)

    # X-axis tick step based on duration
    if max_hours <= 2:
        x_tick_step = 0.25
    elif max_hours <= 12:
        x_tick_step = 1
    elif max_hours <= 24:
        x_tick_step = 2
    else:
        x_tick_step = 6

    freq_cols = ['F1', 'F2', 'F3', 'F4', 'F5']
    harmonic_names = ['f₁ (7.75 Hz)', 'f₂ (13.75 Hz)', 'f₃ (20 Hz)', 'f₄ (25 Hz)', 'f₅ (32 Hz)']

    for i, (col, name) in enumerate(zip(freq_cols, harmonic_names)):
        ax = axes[i]
        ax.set_facecolor('#0a0a0a')

        data = df[col]
        center = SR_REFERENCE[col]['center']

        # Plot data
        ax.plot(hours, data, color=COLORS[col], linewidth=0.5, alpha=0.9)

        # Add center frequency line
        ax.axhline(center, color='red', linestyle='--', alpha=0.5, linewidth=1, label=f'Center: {center} Hz')

        # Add expected range shading
        exp_range = SR_REFERENCE[col].get('observed', SR_REFERENCE[col]['range'])
        ax.axhspan(exp_range[0], exp_range[1], alpha=0.1, color='green', label='Expected range')

        # Y-axis: scale to show actual variation with padding
        data_min, data_max = data.min(), data.max()
        data_range = data_max - data_min
        padding = max(data_range * 0.2, 0.1)  # At least 0.1 Hz padding
        ax.set_ylim(data_min - padding, data_max + padding)

        # Stats annotation
        stats_text = f'μ={data.mean():.2f} Hz  σ={data.std():.3f} Hz  range=[{data_min:.2f}, {data_max:.2f}]'
        ax.text(0.02, 0.95, stats_text, transform=ax.transAxes, fontsize=9,
                color='white', verticalalignment='top', family='monospace',
                bbox=dict(boxstyle='round', facecolor='#2a2a2a', alpha=0.8))

        ax.set_ylabel(f'{name}', fontsize=10, color='white')
        ax.grid(True, alpha=0.2, color='gray')
        ax.tick_params(colors='white')
        ax.legend(loc='upper right', fontsize=8, facecolor='#2a2a2a', edgecolor='gray', labelcolor='white')
        for spine in ax.spines.values():
            spine.set_color('gray')

        ax.set_xlim(0, max_hours)

    # X-axis label only on bottom
    axes[-1].set_xlabel('Time (hours)', fontsize=11, color='white')

    # X-axis ticks
    x_ticks = np.arange(0, max_hours + x_tick_step, x_tick_step)
    for ax in axes:
        ax.set_xticks(x_ticks)

    # Title
    fig.suptitle(f'SR Frequency Drift Detail - {duration_hours:.1f} Hour Simulation',
                 fontsize=14, color='white', fontweight='bold', y=0.995)

    plt.tight_layout()

    output_path = os.path.join(output_dir, 'sr_frequencies_detail.png')
    plt.savefig(output_path, dpi=150, bbox_inches='tight', facecolor='#1a1a1a')
    print(f"  Saved: {output_path}")
    plt.close()


def plot_histograms(df, output_dir):
    """Generate distribution histograms."""

    fig, axes = plt.subplots(3, 5, figsize=(18, 10))

    freq_cols = ['F1', 'F2', 'F3', 'F4', 'F5']
    amp_cols = ['A1', 'A2', 'A3', 'A4', 'A5']
    q_cols = ['Q1', 'Q2', 'Q3', 'Q4', 'Q5']

    # Frequency histograms
    for i, col in enumerate(freq_cols):
        ax = axes[0, i]
        color = COLORS[col] if COLORS[col] != '#FFFFFF' else '#666666'
        ax.hist(df[col], bins=50, color=color, alpha=0.7, edgecolor='black', linewidth=0.5)
        ax.axvline(SR_REFERENCE[col]['center'], color='red', linestyle='--', linewidth=2, label='Center')
        ax.set_xlabel('Hz')
        ax.set_title(f'{col} ({SR_REFERENCE[col]["center"]} Hz)')
        if i == 0:
            ax.set_ylabel('Frequency')

    # Amplitude histograms
    for i, col in enumerate(amp_cols):
        ax = axes[1, i]
        color = COLORS[f'F{i+1}'] if COLORS[f'F{i+1}'] != '#FFFFFF' else '#666666'
        ax.hist(df[col], bins=50, color=color, alpha=0.7, edgecolor='black', linewidth=0.5)
        ax.set_xlabel('Amplitude')
        ax.set_title(f'{col}')
        if i == 0:
            ax.set_ylabel('Count')

    # Q-factor histograms
    for i, col in enumerate(q_cols):
        ax = axes[2, i]
        color = COLORS[f'F{i+1}'] if COLORS[f'F{i+1}'] != '#FFFFFF' else '#666666'
        ax.hist(df[col], bins=50, color=color, alpha=0.7, edgecolor='black', linewidth=0.5)
        ax.axvline(SR_REFERENCE[col]['center'], color='red', linestyle='--', linewidth=2, label='Center')
        ax.set_xlabel('Q')
        ax.set_title(f'{col} (center={SR_REFERENCE[col]["center"]})')
        if i == 0:
            ax.set_ylabel('Count')

    plt.suptitle('SR Parameter Distributions - 72 Hour Simulation', fontsize=14)
    plt.tight_layout()

    output_path = os.path.join(output_dir, 'sr_histograms.png')
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    print(f"  Saved: {output_path}")
    plt.close()


def compute_statistics(df, output_dir):
    """Compute and save summary statistics with comparison to real SR data."""

    report = []
    report.append("=" * 80)
    report.append("SR Realism Validation - 3-Day Statistics")
    report.append("=" * 80)
    report.append("")

    # Frequency statistics
    report.append("FREQUENCY STATISTICS (Hz)")
    report.append("-" * 80)
    report.append(f"{'Harmonic':<10} {'Mean':>8} {'Std':>8} {'Min':>8} {'Max':>8} "
                  f"{'Center':>8} {'Expected Range':>18} {'Match':>8}")
    report.append("-" * 80)

    freq_cols = ['F1', 'F2', 'F3', 'F4', 'F5']
    for col in freq_cols:
        mean = df[col].mean()
        std = df[col].std()
        min_val = df[col].min()
        max_val = df[col].max()
        center = SR_REFERENCE[col]['center']
        exp_range = SR_REFERENCE[col].get('observed', SR_REFERENCE[col]['range'])

        # Check if within expected range
        in_range = exp_range[0] <= min_val and max_val <= exp_range[1]
        match = "OK" if in_range else "CHECK"

        report.append(f"{col:<10} {mean:>8.2f} {std:>8.3f} {min_val:>8.2f} {max_val:>8.2f} "
                      f"{center:>8.2f} [{exp_range[0]:>5.1f}, {exp_range[1]:>5.1f}]  {match:>8}")

    report.append("")

    # Q-factor statistics
    report.append("Q-FACTOR STATISTICS")
    report.append("-" * 80)
    report.append(f"{'Harmonic':<10} {'Mean':>8} {'Std':>8} {'Min':>8} {'Max':>8} "
                  f"{'Center':>8} {'Expected Range':>18} {'Match':>8}")
    report.append("-" * 80)

    q_cols = ['Q1', 'Q2', 'Q3', 'Q4', 'Q5']
    for col in q_cols:
        mean = df[col].mean()
        std = df[col].std()
        min_val = df[col].min()
        max_val = df[col].max()
        center = SR_REFERENCE[col]['center']
        exp_range = SR_REFERENCE[col]['range']

        # Check if overlaps expected range
        overlap = not (max_val < exp_range[0] or min_val > exp_range[1])
        match = "OK" if overlap else "CHECK"

        report.append(f"{col:<10} {mean:>8.1f} {std:>8.2f} {min_val:>8.1f} {max_val:>8.1f} "
                      f"{center:>8.1f} [{exp_range[0]:>5.0f}, {exp_range[1]:>5.0f}]  {match:>8}")

    report.append("")

    # Amplitude statistics
    report.append("AMPLITUDE STATISTICS (normalized)")
    report.append("-" * 80)
    report.append(f"{'Harmonic':<10} {'Mean':>8} {'Std':>8} {'Min':>8} {'Max':>8}")
    report.append("-" * 80)

    amp_cols = ['A1', 'A2', 'A3', 'A4', 'A5']
    for col in amp_cols:
        mean = df[col].mean()
        std = df[col].std()
        min_val = df[col].min()
        max_val = df[col].max()

        report.append(f"{col:<10} {mean:>8.1f} {std:>8.2f} {min_val:>8.1f} {max_val:>8.1f}")

    report.append("")

    # Stability hierarchy validation
    report.append("STABILITY HIERARCHY VALIDATION")
    report.append("-" * 80)
    report.append("Expected hierarchy: F3 (20 Hz) most stable, F4 (25 Hz) most variable")
    report.append("")

    freq_stds = {col: df[col].std() for col in freq_cols}
    sorted_by_stability = sorted(freq_stds.items(), key=lambda x: x[1])

    report.append("Frequency stability ranking (most to least stable):")
    for i, (col, std) in enumerate(sorted_by_stability):
        expected_rank = {'F3': 1, 'F2': 2, 'F1': 3, 'F5': 4, 'F4': 5}
        match = "OK" if expected_rank.get(col, 0) == i + 1 else ""
        report.append(f"  {i+1}. {col}: std = {std:.4f} Hz {match}")

    report.append("")

    q_stds = {col: df[col].std() for col in q_cols}
    sorted_q = sorted(q_stds.items(), key=lambda x: x[1])

    report.append("Q-factor stability ranking (most to least stable):")
    for i, (col, std) in enumerate(sorted_q):
        report.append(f"  {i+1}. {col}: std = {std:.3f}")

    report.append("")
    report.append("=" * 80)

    report_text = "\n".join(report)

    output_path = os.path.join(output_dir, 'sr_statistics.txt')
    with open(output_path, 'w') as f:
        f.write(report_text)

    print(f"  Saved: {output_path}")
    print("\n" + report_text)


def main():
    parser = argparse.ArgumentParser(description='SR Realism Analysis - 3-Day Validation')
    parser.add_argument('--input', default='sr_realism_3day.csv', help='Input CSV file')
    parser.add_argument('--output-dir', default='sr_analysis', help='Output directory')
    parser.add_argument('--sample-rate', type=float, default=None,
                        help='Sample rate in Hz (auto-detected if not specified)')
    args = parser.parse_args()

    print("=" * 60)
    print("SR Realism Analysis - 3-Day Validation")
    print("=" * 60)

    # Create output directory
    os.makedirs(args.output_dir, exist_ok=True)

    # Load data
    df, duration_hours = load_data(args.input, args.sample_rate)

    # Generate visualizations
    print("\nGenerating visualizations...")
    plot_3panel(df, args.output_dir, duration_hours)
    plot_frequency_detail(df, args.output_dir, duration_hours)
    plot_histograms(df, args.output_dir)

    # Compute statistics
    print("\nComputing statistics...")
    compute_statistics(df, args.output_dir)

    print(f"\nAnalysis complete! Results saved to {args.output_dir}/")


if __name__ == '__main__':
    main()
