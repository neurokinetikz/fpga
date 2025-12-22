#!/usr/bin/env python3
"""
State Transition & Hysteresis Visualization
Plots oscillator dynamics during consciousness state transitions.

Usage:
    cd fpga
    python3 scripts/plot_state_transitions.py [csv_file]

Default: state_transitions.csv
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.patches import Patch
import sys
import os

# State names and colors
STATE_NAMES = {
    0: 'NORMAL',
    1: 'ANESTHESIA',
    2: 'PSYCHEDELIC',
    3: 'FLOW',
    4: 'MEDITATION'
}

STATE_COLORS = {
    0: '#4CAF50',   # Green - Normal
    1: '#9E9E9E',   # Gray - Anesthesia
    2: '#E91E63',   # Pink - Psychedelic
    3: '#2196F3',   # Blue - Flow
    4: '#9C27B0',   # Purple - Meditation
}

def load_data(csv_path):
    """Load CSV data from simulation."""
    df = pd.read_csv(csv_path)
    # Convert fixed-point to float (Q4.14 format)
    for col in ['theta_x', 'theta_amp', 'gamma_x', 'alpha_x']:
        if col in df.columns:
            df[col] = df[col].astype(float) / 16384.0  # 2^14
    return df

def detect_state_changes(df):
    """Find indices where state changes."""
    state_changes = []
    prev_state = df['state'].iloc[0]
    for i, state in enumerate(df['state']):
        if state != prev_state:
            state_changes.append((i, prev_state, state))
            prev_state = state
    return state_changes

def plot_oscillator_dynamics(df, ax, title):
    """Plot theta and gamma oscillator waveforms with state background."""
    samples = df['sample'].values

    # Plot state background colors
    state_changes = detect_state_changes(df)
    prev_idx = 0
    prev_state = df['state'].iloc[0]

    for i, (idx, from_state, to_state) in enumerate(state_changes):
        ax.axvspan(samples[prev_idx], samples[idx],
                   alpha=0.2, color=STATE_COLORS[prev_state], label=None)
        prev_idx = idx
        prev_state = to_state
    # Fill last segment
    ax.axvspan(samples[prev_idx], samples[-1],
               alpha=0.2, color=STATE_COLORS[prev_state], label=None)

    # Plot waveforms
    ax.plot(samples, df['theta_x'], 'b-', alpha=0.7, linewidth=0.5, label='Theta (5.89 Hz)')
    ax.plot(samples, df['gamma_x'], 'r-', alpha=0.7, linewidth=0.5, label='Gamma (40 Hz)')

    ax.set_xlabel('Sample')
    ax.set_ylabel('Amplitude')
    ax.set_title(title)
    ax.legend(loc='upper right', fontsize=8)
    ax.grid(True, alpha=0.3)

def plot_amplitudes(df, ax, title):
    """Plot amplitude envelopes with state transitions marked."""
    samples = df['sample'].values

    # Calculate running amplitude (absolute value)
    theta_amp = np.abs(df['theta_x'].values)
    gamma_amp = np.abs(df['gamma_x'].values)
    alpha_amp = np.abs(df['alpha_x'].values)

    # Smooth with rolling window
    window = 20
    theta_smooth = pd.Series(theta_amp).rolling(window, min_periods=1).mean()
    gamma_smooth = pd.Series(gamma_amp).rolling(window, min_periods=1).mean()
    alpha_smooth = pd.Series(alpha_amp).rolling(window, min_periods=1).mean()

    # Plot state background
    state_changes = detect_state_changes(df)
    prev_idx = 0
    prev_state = df['state'].iloc[0]

    for idx, from_state, to_state in state_changes:
        ax.axvspan(samples[prev_idx], samples[idx],
                   alpha=0.2, color=STATE_COLORS[prev_state])
        prev_idx = idx
        prev_state = to_state
    ax.axvspan(samples[prev_idx], samples[-1], alpha=0.2, color=STATE_COLORS[prev_state])

    # Plot amplitudes
    ax.plot(samples, theta_smooth, 'b-', linewidth=1.5, label='Theta Amp')
    ax.plot(samples, gamma_smooth, 'r-', linewidth=1.5, label='Gamma Amp')
    ax.plot(samples, alpha_smooth, 'g-', linewidth=1.5, label='Alpha Amp')

    # Mark state transitions
    for idx, from_state, to_state in state_changes:
        ax.axvline(samples[idx], color='black', linestyle='--', alpha=0.5, linewidth=0.8)
        ax.text(samples[idx], ax.get_ylim()[1]*0.95,
                f'{STATE_NAMES[to_state]}',
                rotation=90, va='top', ha='right', fontsize=7)

    ax.set_xlabel('Sample')
    ax.set_ylabel('Amplitude')
    ax.set_title(title)
    ax.legend(loc='upper right', fontsize=8)
    ax.grid(True, alpha=0.3)

def plot_state_comparison(df, ax):
    """Bar chart comparing mean amplitudes per state."""
    states = df['state'].unique()
    states = sorted(states)

    theta_means = []
    gamma_means = []
    alpha_means = []
    state_labels = []
    colors = []

    for state in states:
        state_df = df[df['state'] == state]
        if len(state_df) > 100:  # Only include states with enough samples
            theta_means.append(np.abs(state_df['theta_x']).mean())
            gamma_means.append(np.abs(state_df['gamma_x']).mean())
            alpha_means.append(np.abs(state_df['alpha_x']).mean())
            state_labels.append(STATE_NAMES.get(state, f'State {state}'))
            colors.append(STATE_COLORS.get(state, 'gray'))

    x = np.arange(len(state_labels))
    width = 0.25

    ax.bar(x - width, theta_means, width, label='Theta', color='blue', alpha=0.7)
    ax.bar(x, gamma_means, width, label='Gamma', color='red', alpha=0.7)
    ax.bar(x + width, alpha_means, width, label='Alpha', color='green', alpha=0.7)

    ax.set_xticks(x)
    ax.set_xticklabels(state_labels, rotation=45, ha='right')
    ax.set_ylabel('Mean Amplitude')
    ax.set_title('Average Oscillator Amplitudes by State')
    ax.legend(loc='upper right', fontsize=8)
    ax.grid(True, alpha=0.3, axis='y')

def plot_pattern_dynamics(df, ax):
    """Plot cortical pattern changes over time."""
    samples = df['sample'].values
    patterns = df['pattern'].values

    # Plot state background
    state_changes = detect_state_changes(df)
    prev_idx = 0
    prev_state = df['state'].iloc[0]

    for idx, from_state, to_state in state_changes:
        ax.axvspan(samples[prev_idx], samples[idx],
                   alpha=0.2, color=STATE_COLORS[prev_state])
        prev_idx = idx
        prev_state = to_state
    ax.axvspan(samples[prev_idx], samples[-1], alpha=0.2, color=STATE_COLORS[prev_state])

    # Plot pattern as step function
    ax.step(samples, patterns, 'k-', linewidth=0.8, where='post')

    # Count transitions in sliding window
    window = 50
    transitions = np.zeros(len(patterns))
    for i in range(window, len(patterns)):
        transitions[i] = np.sum(np.diff(patterns[i-window:i]) != 0)

    ax2 = ax.twinx()
    ax2.plot(samples, transitions, 'orange', linewidth=1, alpha=0.7, label='Transitions/window')
    ax2.set_ylabel('Transitions (window=50)', color='orange')
    ax2.tick_params(axis='y', labelcolor='orange')

    ax.set_xlabel('Sample')
    ax.set_ylabel('Cortical Pattern (6-bit)')
    ax.set_title('Cortical Pattern Dynamics')
    ax.set_ylim(-1, 65)
    ax.grid(True, alpha=0.3)

def create_legend_patches():
    """Create legend patches for states."""
    patches = []
    for state, name in STATE_NAMES.items():
        patches.append(Patch(facecolor=STATE_COLORS[state], alpha=0.5, label=name))
    return patches

def main():
    # Find CSV file
    if len(sys.argv) > 1:
        csv_path = sys.argv[1]
    else:
        # Try common locations
        candidates = ['state_transitions.csv', 'fpga/state_transitions.csv']
        csv_path = None
        for c in candidates:
            if os.path.exists(c):
                csv_path = c
                break
        if csv_path is None:
            print("Error: state_transitions.csv not found")
            print("Run the simulation first: vvp tb_state_transitions.vvp")
            sys.exit(1)

    print(f"Loading data from: {csv_path}")
    df = load_data(csv_path)
    print(f"Loaded {len(df)} samples")

    # Create figure with subplots
    fig = plt.figure(figsize=(14, 12))
    fig.suptitle('State Transition & Hysteresis Analysis\nφⁿ Neural Processor v6.1',
                 fontsize=14, fontweight='bold')

    # Create grid layout
    gs = fig.add_gridspec(3, 2, hspace=0.35, wspace=0.25)

    # Plot 1: Oscillator waveforms (top left)
    ax1 = fig.add_subplot(gs[0, 0])
    # Show first 2000 samples for detail
    df_detail = df.head(200)
    plot_oscillator_dynamics(df_detail, ax1, 'Oscillator Waveforms (Detail)')

    # Plot 2: Amplitude envelopes (top right)
    ax2 = fig.add_subplot(gs[0, 1])
    plot_amplitudes(df, ax2, 'Amplitude Envelopes with State Transitions')

    # Plot 3: Full waveforms (middle, spans both columns)
    ax3 = fig.add_subplot(gs[1, :])
    plot_amplitudes(df, ax3, 'Complete Test Session - Oscillator Dynamics')

    # Plot 4: State comparison (bottom left)
    ax4 = fig.add_subplot(gs[2, 0])
    plot_state_comparison(df, ax4)

    # Plot 5: Pattern dynamics (bottom right)
    ax5 = fig.add_subplot(gs[2, 1])
    plot_pattern_dynamics(df, ax5)

    # Add state legend
    patches = create_legend_patches()
    fig.legend(handles=patches, loc='upper center', ncol=5,
               bbox_to_anchor=(0.5, 0.98), fontsize=9)

    plt.tight_layout(rect=[0, 0, 1, 0.96])

    # Save figure
    output_path = csv_path.replace('.csv', '.png')
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    print(f"Saved visualization to: {output_path}")

    # Also save to standard location
    if not output_path.startswith('fpga/'):
        os.makedirs('fpga/exports', exist_ok=True)
        alt_path = 'fpga/exports/state_transitions.png'
        plt.savefig(alt_path, dpi=150, bbox_inches='tight')
        print(f"Also saved to: {alt_path}")

    plt.show()

if __name__ == '__main__':
    main()
