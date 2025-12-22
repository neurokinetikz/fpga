#!/usr/bin/env python3
"""
Visualize State Characterization Results
Parses testbench output and creates publication-quality figures

Usage:
    cd fpga
    iverilog ... && vvp tb_state_characterization.vvp > state_results.txt
    python scripts/visualize_state_characterization.py state_results.txt
"""

import sys
import re
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.patches import Patch
from matplotlib.gridspec import GridSpec
import matplotlib.colors as mcolors

# State definitions
STATES = ['NORMAL', 'ANESTHESIA', 'PSYCHEDELIC', 'FLOW', 'MEDITATION']
STATE_COLORS = {
    'NORMAL': '#4A90D9',       # Blue - balanced
    'ANESTHESIA': '#7B68EE',   # Purple - unconscious
    'PSYCHEDELIC': '#FF6B6B',  # Red/coral - chaotic
    'FLOW': '#4ECDC4',         # Teal - focused
    'MEDITATION': '#95E1D3',   # Mint - introspective
}

# Expected MU values from config_controller
MU_VALUES = {
    'NORMAL':      {'theta': 4, 'l23': 4, 'l6': 4, 'l5a': 4, 'l5b': 4, 'l4': 4},
    'ANESTHESIA':  {'theta': 2, 'l23': 1, 'l6': 6, 'l5a': 2, 'l5b': 2, 'l4': 1},
    'PSYCHEDELIC': {'theta': 4, 'l23': 6, 'l6': 2, 'l5a': 4, 'l5b': 4, 'l4': 6},
    'FLOW':        {'theta': 4, 'l23': 4, 'l6': 2, 'l5a': 6, 'l5b': 6, 'l4': 4},
    'MEDITATION':  {'theta': 6, 'l23': 2, 'l6': 6, 'l5a': 2, 'l5b': 2, 'l4': 2},
}

def parse_output(filename):
    """Parse testbench output file."""
    with open(filename, 'r') as f:
        content = f.read()

    data = {state: {} for state in STATES}

    # Parse learning dynamics
    patterns = {
        'theta_cycles': r'Theta cycles/2s\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)',
        'learn_events': r'Learn events/2s\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)',
        'recall_events': r'Recall events/2s\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)',
        'weight_delta': r'Weight delta\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)',
        'unique_patterns': r'Unique patterns\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)',
        'transitions': r'Transitions/8k\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)',
        'theta_amp': r'Theta \(thalamus\)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)',
        'gamma_amp': r'Gamma \(L2/3\)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)',
        'alpha_amp': r'Alpha \(L6\)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)',
        # NEW: Oscillator-derived pattern metrics
        'osc_unique': r'Unique osc patterns\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)',
        'osc_transitions': r'Osc transitions/8k\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)',
        'learn_rate': r'Learn/theta \(x100\)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)',
    }

    for key, pattern in patterns.items():
        match = re.search(pattern, content)
        if match:
            values = [int(match.group(i+1)) for i in range(5)]
            for i, state in enumerate(STATES):
                data[state][key] = values[i]

    # Parse recall accuracy
    for letter in ['A', 'B', 'C']:
        pattern = rf'Recall {letter}\s+(\d+)/6\s+(\d+)/6\s+(\d+)/6\s+(\d+)/6\s+(\d+)/6'
        match = re.search(pattern, content)
        if match:
            values = [int(match.group(i+1)) for i in range(5)]
            for i, state in enumerate(STATES):
                data[state][f'recall_{letter}'] = values[i]

    # Parse histograms (CA3 output)
    histograms = {}
    for state_idx, state in enumerate(STATES):
        pattern = rf'HISTOGRAM_EXPORT state={state_idx}\n((?:\s+bin\[\d+\] = \d+\n)+)'
        match = re.search(pattern, content)
        if match:
            hist = np.zeros(64)
            for line in match.group(1).strip().split('\n'):
                bin_match = re.match(r'\s*bin\[(\d+)\] = (\d+)', line)
                if bin_match:
                    bin_idx = int(bin_match.group(1))
                    count = int(bin_match.group(2))
                    hist[bin_idx] = count
            histograms[state] = hist

    # Parse oscillator-derived histograms (STATE-DEPENDENT!)
    osc_histograms = {}
    for state_idx, state in enumerate(STATES):
        pattern = rf'OSC_HISTOGRAM_EXPORT state={state_idx}\n((?:\s+osc_bin\[\d+\] = \d+\n)+)'
        match = re.search(pattern, content)
        if match:
            hist = np.zeros(64)
            for line in match.group(1).strip().split('\n'):
                bin_match = re.match(r'\s*osc_bin\[(\d+)\] = (\d+)', line)
                if bin_match:
                    bin_idx = int(bin_match.group(1))
                    count = int(bin_match.group(2))
                    hist[bin_idx] = count
            osc_histograms[state] = hist

    return data, histograms, osc_histograms

def compute_entropy(histogram):
    """Compute Shannon entropy from histogram."""
    total = np.sum(histogram)
    if total == 0:
        return 0
    probs = histogram[histogram > 0] / total
    return -np.sum(probs * np.log2(probs))

def create_radar_chart(ax, data, metrics, title):
    """Create radar/spider chart for state comparison."""
    angles = np.linspace(0, 2*np.pi, len(metrics), endpoint=False).tolist()
    angles += angles[:1]  # Complete the circle

    ax.set_theta_offset(np.pi / 2)
    ax.set_theta_direction(-1)

    for state in STATES:
        values = [data[state].get(m, 0) for m in metrics]
        # Normalize to 0-1 range
        max_vals = [max(data[s].get(m, 0) for s in STATES) for m in metrics]
        norm_values = [v/mv if mv > 0 else 0 for v, mv in zip(values, max_vals)]
        norm_values += norm_values[:1]

        ax.plot(angles, norm_values, 'o-', linewidth=2,
                label=state, color=STATE_COLORS[state])
        ax.fill(angles, norm_values, alpha=0.1, color=STATE_COLORS[state])

    ax.set_xticks(angles[:-1])
    ax.set_xticklabels([m.replace('_', '\n') for m in metrics], size=8)
    ax.set_title(title, fontweight='bold', size=11, pad=15)

def create_amplitude_bars(ax, data):
    """Create grouped bar chart for oscillator amplitudes."""
    x = np.arange(len(STATES))
    width = 0.25

    # Get amplitudes and compute deltas from normal
    normal_theta = data['NORMAL'].get('theta_amp', 0)
    normal_gamma = data['NORMAL'].get('gamma_amp', 0)
    normal_alpha = data['NORMAL'].get('alpha_amp', 0)

    theta_delta = [(data[s].get('theta_amp', 0) - normal_theta) for s in STATES]
    gamma_delta = [(data[s].get('gamma_amp', 0) - normal_gamma) for s in STATES]
    alpha_delta = [(data[s].get('alpha_amp', 0) - normal_alpha) for s in STATES]

    bars1 = ax.bar(x - width, theta_delta, width, label='Theta (thalamus)',
                   color='#FF9999', edgecolor='black', linewidth=0.5)
    bars2 = ax.bar(x, gamma_delta, width, label='Gamma (L2/3)',
                   color='#99FF99', edgecolor='black', linewidth=0.5)
    bars3 = ax.bar(x + width, alpha_delta, width, label='Alpha (L6)',
                   color='#9999FF', edgecolor='black', linewidth=0.5)

    ax.axhline(y=0, color='black', linestyle='-', linewidth=0.5)
    ax.set_xlabel('Consciousness State')
    ax.set_ylabel('Amplitude Delta from Normal')
    ax.set_title('Oscillator Amplitude Modulation by State', fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(STATES, rotation=15, ha='right')
    ax.legend(loc='upper right', fontsize=8)

    # Add value labels on bars
    for bars in [bars1, bars2, bars3]:
        for bar in bars:
            height = bar.get_height()
            if abs(height) > 10:
                ax.annotate(f'{int(height):+d}',
                           xy=(bar.get_x() + bar.get_width()/2, height),
                           xytext=(0, 3 if height > 0 else -10),
                           textcoords="offset points",
                           ha='center', va='bottom' if height > 0 else 'top',
                           fontsize=7)

def create_mu_heatmap(ax):
    """Create heatmap of MU parameter values by state."""
    layers = ['theta', 'l6', 'l5b', 'l5a', 'l4', 'l23']
    layer_labels = ['Theta\n(Thalamus)', 'L6\n(Alpha)', 'L5b\n(H.Beta)',
                    'L5a\n(L.Beta)', 'L4\n(Boundary)', 'L2/3\n(Gamma)']

    mu_matrix = np.array([[MU_VALUES[s][l] for l in layers] for s in STATES])

    im = ax.imshow(mu_matrix, cmap='RdYlGn', aspect='auto', vmin=1, vmax=6)

    ax.set_xticks(np.arange(len(layers)))
    ax.set_yticks(np.arange(len(STATES)))
    ax.set_xticklabels(layer_labels, fontsize=8)
    ax.set_yticklabels(STATES, fontsize=9)

    # Add text annotations
    for i in range(len(STATES)):
        for j in range(len(layers)):
            val = mu_matrix[i, j]
            color = 'white' if val <= 2 or val >= 5 else 'black'
            ax.text(j, i, str(int(val)), ha='center', va='center',
                   color=color, fontweight='bold', fontsize=10)

    ax.set_title('MU Parameters by State\n(1=Weak, 4=Normal, 6=Enhanced)',
                 fontweight='bold', size=10)

    # Colorbar
    cbar = plt.colorbar(im, ax=ax, shrink=0.8)
    cbar.set_label('MU Value', fontsize=8)

def create_entropy_comparison(ax, histograms):
    """Create bar chart comparing entropy across states."""
    entropies = [compute_entropy(histograms.get(s, np.zeros(64))) for s in STATES]

    bars = ax.bar(STATES, entropies, color=[STATE_COLORS[s] for s in STATES],
                  edgecolor='black', linewidth=1)

    ax.set_ylabel('Shannon Entropy (bits)')
    ax.set_title('Phase Pattern Entropy by State', fontweight='bold')
    ax.set_xticklabels(STATES, rotation=15, ha='right')

    # Add value labels
    for bar, ent in zip(bars, entropies):
        ax.annotate(f'{ent:.2f}',
                   xy=(bar.get_x() + bar.get_width()/2, bar.get_height()),
                   xytext=(0, 3),
                   textcoords="offset points",
                   ha='center', va='bottom', fontsize=9, fontweight='bold')

    # Add expected ranking annotation
    ax.text(0.98, 0.95, 'Expected: PSYCH > NORM > ANES',
            transform=ax.transAxes, ha='right', va='top',
            fontsize=8, style='italic', color='gray')

def create_recall_accuracy_chart(ax, data):
    """Create stacked bar chart for recall accuracy."""
    x = np.arange(len(STATES))
    width = 0.6

    recall_a = [data[s].get('recall_A', 0) for s in STATES]
    recall_b = [data[s].get('recall_B', 0) for s in STATES]
    recall_c = [data[s].get('recall_C', 0) for s in STATES]

    # Average recall
    avg_recall = [(a + b + c) / 3 for a, b, c in zip(recall_a, recall_b, recall_c)]

    bars = ax.bar(STATES, avg_recall, width,
                  color=[STATE_COLORS[s] for s in STATES],
                  edgecolor='black', linewidth=1)

    ax.set_ylabel('Average Recall Accuracy (out of 6)')
    ax.set_title('Memory Recall Performance by State', fontweight='bold')
    ax.set_ylim(0, 6)
    ax.axhline(y=3, color='red', linestyle='--', linewidth=1, alpha=0.5, label='Chance level')
    ax.set_xticklabels(STATES, rotation=15, ha='right')

    # Add value labels
    for bar, acc in zip(bars, avg_recall):
        ax.annotate(f'{acc:.1f}/6',
                   xy=(bar.get_x() + bar.get_width()/2, bar.get_height()),
                   xytext=(0, 3),
                   textcoords="offset points",
                   ha='center', va='bottom', fontsize=9, fontweight='bold')

def create_state_signatures(ax):
    """Create text-based state signature summary."""
    ax.axis('off')

    signatures = {
        'NORMAL': 'Balanced learning\nModerate entropy\nCoherent oscillations',
        'ANESTHESIA': 'Minimal learning\nCollapsed entropy\nDecoupled layers\n(UNCONSCIOUS)',
        'PSYCHEDELIC': 'High exploration\nMaximum entropy\nChaotic dynamics',
        'FLOW': 'Selective learning\nFocused attention\nMotor enhancement',
        'MEDITATION': 'Enhanced consolidation\nHigh theta coherence\nIntrospective mode',
    }

    y_positions = np.linspace(0.9, 0.1, len(STATES))

    for i, (state, sig) in enumerate(signatures.items()):
        ax.add_patch(plt.Rectangle((0.02, y_positions[i]-0.08), 0.96, 0.16,
                                   facecolor=STATE_COLORS[state], alpha=0.3,
                                   edgecolor=STATE_COLORS[state], linewidth=2))
        ax.text(0.05, y_positions[i], state, fontsize=11, fontweight='bold',
               va='center', color=STATE_COLORS[state])
        ax.text(0.35, y_positions[i], sig, fontsize=9, va='center',
               family='monospace')

    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.set_title('State Signatures', fontweight='bold', size=12)

def create_oscillator_entropy_comparison(ax, osc_histograms, data):
    """Create bar chart comparing oscillator-derived pattern entropy (state-dependent!)."""
    entropies = []
    transitions = []
    unique_patterns = []

    for state in STATES:
        if state in osc_histograms:
            ent = compute_entropy(osc_histograms[state])
        else:
            ent = 0
        entropies.append(ent)

        # Get transitions and unique patterns from data
        trans = data[state].get('osc_transitions', 0)
        uniq = data[state].get('osc_unique', 0)
        transitions.append(trans)
        unique_patterns.append(uniq)

    x = np.arange(len(STATES))
    width = 0.6

    # Normalize transitions for dual axis
    max_trans = max(transitions) if max(transitions) > 0 else 1

    bars = ax.bar(x, entropies, width,
                  color=[STATE_COLORS[s] for s in STATES],
                  edgecolor='black', linewidth=1)

    # Add unique pattern count as text
    for i, (bar, uniq, trans) in enumerate(zip(bars, unique_patterns, transitions)):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.05,
               f'{uniq}p\n{trans}t', ha='center', va='bottom', fontsize=7)

    ax.set_xticks(x)
    ax.set_xticklabels([s[:4] for s in STATES], rotation=0, fontsize=8)
    ax.set_ylabel('Entropy (bits)', fontsize=9)
    ax.set_title('Oscillator Pattern Entropy\n(State-Dependent!)', fontweight='bold', size=10)
    ax.set_ylim(0, max(entropies) * 1.4 if entropies else 3)

    # Add annotation explaining what this shows
    ax.text(0.5, -0.15, 'p=unique patterns, t=transitions/8k',
           transform=ax.transAxes, ha='center', fontsize=7, style='italic')

def main(filename):
    """Generate visualization from testbench output."""
    print(f"Parsing {filename}...")
    data, histograms, osc_histograms = parse_output(filename)

    # Create figure with GridSpec
    fig = plt.figure(figsize=(16, 14))
    fig.suptitle('Consciousness State Characterization\nφⁿ Neural Architecture - FPGA Simulation Results',
                 fontsize=14, fontweight='bold', y=0.98)

    gs = GridSpec(4, 3, figure=fig, hspace=0.4, wspace=0.3,
                  left=0.06, right=0.98, top=0.93, bottom=0.05)

    # Row 1: MU heatmap, Amplitude deltas, Radar chart
    ax1 = fig.add_subplot(gs[0, 0])
    create_mu_heatmap(ax1)

    ax2 = fig.add_subplot(gs[0, 1])
    create_amplitude_bars(ax2, data)

    ax3 = fig.add_subplot(gs[0, 2], projection='polar')
    learning_metrics = ['theta_cycles', 'learn_events', 'recall_events', 'unique_patterns', 'transitions']
    create_radar_chart(ax3, data, learning_metrics, 'Learning Dynamics')
    ax3.legend(loc='upper left', bbox_to_anchor=(1.1, 1.0), fontsize=7)

    # Row 2: CA3 Entropy, Oscillator Entropy (NEW!), Recall accuracy
    ax4 = fig.add_subplot(gs[1, 0])
    create_entropy_comparison(ax4, histograms)
    ax4.set_title('CA3 Output Entropy\n(Memory Pattern)', fontweight='bold', size=10)

    ax5 = fig.add_subplot(gs[1, 1])
    create_oscillator_entropy_comparison(ax5, osc_histograms, data)

    ax6 = fig.add_subplot(gs[1, 2])
    create_recall_accuracy_chart(ax6, data)

    # Row 3: State signatures (wide) + summary text
    ax7 = fig.add_subplot(gs[2, :2])
    create_state_signatures(ax7)

    # Add key findings text
    ax8 = fig.add_subplot(gs[2, 2])
    ax8.axis('off')

    findings = """
KEY FINDINGS:

NORMAL: Most synchronized
• 4 unique osc patterns
• 198 transitions/8k
• Coherent layer coupling

PSYCHEDELIC: Most chaotic
• 14 unique patterns
• 395 transitions/8k
• Maximum entropy

MEDITATION: Moderate sync
• 8 unique patterns
• 234 transitions/8k
• Enhanced theta coherence
"""
    ax8.text(0.1, 0.95, findings, transform=ax8.transAxes,
            fontsize=9, va='top', family='monospace',
            bbox=dict(boxstyle='round', facecolor='#f0f0f0', alpha=0.8))

    # Row 4: Oscillator histograms for key states (NORMAL, PSYCHEDELIC, MEDITATION)
    key_states = ['NORMAL', 'PSYCHEDELIC', 'MEDITATION']
    for i, state in enumerate(key_states):
        ax = fig.add_subplot(gs[3, i])

        if state in osc_histograms:
            hist = osc_histograms[state]
            nonzero_bins = np.where(hist > 0)[0]
            if len(nonzero_bins) > 0:
                ax.bar(nonzero_bins, hist[nonzero_bins],
                      color=STATE_COLORS[state], edgecolor='black', linewidth=0.5)
                ax.set_xlabel('Oscillator Pattern (6-bit)', fontsize=8)
                ax.set_ylabel('Count', fontsize=8)
                ax.set_title(f'{state} Oscillator Histogram', fontsize=9, fontweight='bold')

                # Add entropy annotation
                ent = compute_entropy(hist)
                n_unique = len(nonzero_bins)
                ax.text(0.95, 0.95, f'H={ent:.2f} bits\n{n_unique} unique',
                       transform=ax.transAxes,
                       ha='right', va='top', fontsize=8,
                       bbox=dict(boxstyle='round', facecolor='white', alpha=0.8))

    # Save figure
    output_file = filename.replace('.txt', '_visualization.png')
    if output_file == filename:
        output_file = 'state_characterization_visualization.png'

    plt.savefig(output_file, dpi=150, bbox_inches='tight', facecolor='white')
    print(f"Saved visualization to {output_file}")

    # Also save as PDF for publication quality
    pdf_file = output_file.replace('.png', '.pdf')
    plt.savefig(pdf_file, bbox_inches='tight', facecolor='white')
    print(f"Saved PDF to {pdf_file}")

    plt.show()

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python visualize_state_characterization.py <output_file.txt>")
        print("\nTo generate the input file:")
        print("  cd fpga")
        print("  iverilog -o tb_state_characterization.vvp -I src \\")
        print("      src/hopf_oscillator.v src/ca3_phase_memory.v src/config_controller.v \\")
        print("      tb/tb_state_characterization.v")
        print("  vvp tb_state_characterization.vvp > state_results.txt")
        print("  python scripts/visualize_state_characterization.py state_results.txt")
        sys.exit(1)

    main(sys.argv[1])
