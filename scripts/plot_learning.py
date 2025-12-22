#!/usr/bin/env python3
"""
Learning & Memory Test Visualization
Plots CA3 Hebbian learning dynamics from simulation data.

Usage:
    cd fpga
    python3 scripts/plot_learning.py [csv_file]

Default: learning_test.csv
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
    0: '#4CAF50',
    1: '#9E9E9E',
    2: '#E91E63',
    3: '#2196F3',
    4: '#9C27B0',
}

def load_data(csv_path):
    """Load CSV data from simulation."""
    df = pd.read_csv(csv_path)
    # Convert fixed-point theta to float (Q4.14)
    if 'theta_x' in df.columns:
        df['theta_x'] = df['theta_x'].astype(float) / 16384.0
    return df

def plot_theta_and_learning(df, ax):
    """Plot theta oscillation with learning/recall events."""
    samples = df['sample'].values
    theta = df['theta_x'].values

    # Plot theta
    ax.plot(samples, theta, 'b-', linewidth=0.5, alpha=0.7, label='Theta')

    # Mark learning events
    learning_mask = df['learning'] == 1
    if learning_mask.any():
        ax.scatter(samples[learning_mask], theta[learning_mask],
                   c='green', s=30, marker='^', label='Learning', zorder=5)

    # Mark recall events
    recall_mask = df['recalling'] == 1
    if recall_mask.any():
        ax.scatter(samples[recall_mask], theta[recall_mask],
                   c='orange', s=30, marker='v', label='Recall', zorder=5)

    ax.axhline(y=0.75, color='green', linestyle='--', alpha=0.5, label='Learn threshold')
    ax.axhline(y=-0.75, color='orange', linestyle='--', alpha=0.5, label='Recall threshold')

    ax.set_xlabel('Sample')
    ax.set_ylabel('Theta Amplitude')
    ax.set_title('Theta Oscillation with Learning/Recall Events')
    ax.legend(loc='upper right', fontsize=8)
    ax.grid(True, alpha=0.3)

def plot_patterns(df, ax):
    """Plot pattern_in and phase_pattern over time."""
    samples = df['sample'].values

    ax.step(samples, df['pattern_in'], 'g-', linewidth=1, where='post', label='Pattern In', alpha=0.8)
    ax.step(samples, df['phase_pattern'], 'r-', linewidth=1, where='post', label='Phase Pattern Out', alpha=0.8)

    ax.set_xlabel('Sample')
    ax.set_ylabel('Pattern (6-bit)')
    ax.set_title('CA3 Input/Output Patterns')
    ax.set_ylim(-1, 65)
    ax.legend(loc='upper right', fontsize=8)
    ax.grid(True, alpha=0.3)

def plot_cortical_pattern(df, ax):
    """Plot cortical pattern (closed-loop feedback)."""
    samples = df['sample'].values

    ax.step(samples, df['cortical'], 'purple', linewidth=0.8, where='post', label='Cortical Pattern')

    # Count transitions
    cortical = df['cortical'].values
    transitions = np.zeros(len(cortical))
    window = 50
    for i in range(window, len(cortical)):
        transitions[i] = np.sum(np.diff(cortical[i-window:i]) != 0)

    ax2 = ax.twinx()
    ax2.plot(samples, transitions, 'orange', linewidth=1, alpha=0.6, label='Transitions/50')
    ax2.set_ylabel('Transitions', color='orange')
    ax2.tick_params(axis='y', labelcolor='orange')

    ax.set_xlabel('Sample')
    ax.set_ylabel('Cortical Pattern (6-bit)')
    ax.set_title('Cortical Activity (Closed-Loop Feedback to CA3)')
    ax.set_ylim(-1, 65)
    ax.legend(loc='upper left', fontsize=8)
    ax.grid(True, alpha=0.3)

def plot_learning_events_histogram(df, ax):
    """Histogram of learning events by theta phase."""
    theta = df['theta_x'].values
    learning = df['learning'].values

    # Get theta values where learning occurred
    learning_theta = theta[learning == 1]

    if len(learning_theta) > 0:
        ax.hist(learning_theta, bins=20, color='green', alpha=0.7, edgecolor='black')
        ax.axvline(x=0.75, color='red', linestyle='--', label='Learn threshold')

    ax.set_xlabel('Theta Phase at Learning')
    ax.set_ylabel('Count')
    ax.set_title('Learning Events by Theta Phase')
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)

def plot_state_comparison(df, ax):
    """Compare learning events across states."""
    states = df['state'].unique()

    learn_counts = []
    recall_counts = []
    state_labels = []
    colors = []

    for state in sorted(states):
        state_df = df[df['state'] == state]
        learn_counts.append(state_df['learning'].sum())
        recall_counts.append(state_df['recalling'].sum())
        state_labels.append(STATE_NAMES.get(state, f'S{state}'))
        colors.append(STATE_COLORS.get(state, 'gray'))

    x = np.arange(len(state_labels))
    width = 0.35

    ax.bar(x - width/2, learn_counts, width, label='Learning', color='green', alpha=0.7)
    ax.bar(x + width/2, recall_counts, width, label='Recall', color='orange', alpha=0.7)

    ax.set_xticks(x)
    ax.set_xticklabels(state_labels)
    ax.set_ylabel('Event Count')
    ax.set_title('Learning/Recall Events by State')
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3, axis='y')

def plot_ca3_debug(df, ax):
    """Plot CA3 state machine debug output."""
    samples = df['sample'].values
    debug = df['debug'].values

    ax.step(samples, debug, 'k-', linewidth=0.8, where='post')

    # Add state labels
    state_names = {0: 'IDLE', 1: 'LEARN', 2: 'LEARN_DONE', 3: 'RECALL', 4: 'RECALL_DONE', 5: 'DECAY', 6: 'DECAY_DONE'}
    ax.set_yticks(range(7))
    ax.set_yticklabels([state_names.get(i, str(i)) for i in range(7)])

    ax.set_xlabel('Sample')
    ax.set_ylabel('CA3 State')
    ax.set_title('CA3 State Machine Transitions')
    ax.grid(True, alpha=0.3)

def main():
    # Find CSV file
    if len(sys.argv) > 1:
        csv_path = sys.argv[1]
    else:
        candidates = ['learning_test.csv', 'fpga/learning_test.csv']
        csv_path = None
        for c in candidates:
            if os.path.exists(c):
                csv_path = c
                break
        if csv_path is None:
            print("Error: learning_test.csv not found")
            print("Run the simulation first: vvp tb_learning_fast.vvp")
            sys.exit(1)

    print(f"Loading data from: {csv_path}")
    df = load_data(csv_path)
    print(f"Loaded {len(df)} samples")
    print(f"Learning events: {df['learning'].sum()}")
    print(f"Recall events: {df['recalling'].sum()}")

    # Create figure
    fig = plt.figure(figsize=(14, 12))
    fig.suptitle('CA3 Hebbian Learning Analysis\nφⁿ Neural Processor (Full Closed-Loop)',
                 fontsize=14, fontweight='bold')

    gs = fig.add_gridspec(3, 2, hspace=0.35, wspace=0.25)

    # Plot 1: Theta with learning/recall markers
    ax1 = fig.add_subplot(gs[0, :])
    plot_theta_and_learning(df, ax1)

    # Plot 2: CA3 input/output patterns
    ax2 = fig.add_subplot(gs[1, 0])
    plot_patterns(df, ax2)

    # Plot 3: Cortical pattern (closed-loop)
    ax3 = fig.add_subplot(gs[1, 1])
    plot_cortical_pattern(df, ax3)

    # Plot 4: Learning events histogram
    ax4 = fig.add_subplot(gs[2, 0])
    plot_learning_events_histogram(df, ax4)

    # Plot 5: CA3 state machine
    ax5 = fig.add_subplot(gs[2, 1])
    plot_ca3_debug(df, ax5)

    plt.tight_layout(rect=[0, 0, 1, 0.96])

    # Save figure
    output_path = csv_path.replace('.csv', '.png')
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    print(f"Saved visualization to: {output_path}")

    os.makedirs('fpga/exports', exist_ok=True)
    alt_path = 'fpga/exports/learning_test.png'
    plt.savefig(alt_path, dpi=150, bbox_inches='tight')
    print(f"Also saved to: {alt_path}")

    plt.show()

if __name__ == '__main__':
    main()
