#!/usr/bin/env python3
"""
VCD-based Metrics Analysis for φⁿ Neural Processor
===================================================
Parses VCD waveforms from tb_state_characterization.v and computes:
- Theta-Gamma Peak-Trough Ratio (PAC measure)
- Phase-Amplitude Coupling (Modulation Index)
- Pattern Entropy (from oscillator-derived patterns)

Uses actual FPGA simulation data, not Python approximations.
"""

import numpy as np
import re
from pathlib import Path
from collections import defaultdict
import matplotlib.pyplot as plt


def twos_complement(val, bits, signed=True):
    """Convert unsigned integer to signed (two's complement).

    Args:
        val: Unsigned integer value
        bits: Number of bits
        signed: If True, interpret as signed. If False, return unsigned.
    """
    if not signed:
        return val
    if val >= 2**(bits-1):
        return val - 2**bits
    return val


# Signals that should be interpreted as unsigned
UNSIGNED_SIGNALS = {'state_select', 'phase_pattern', 'oscillator_derived_pattern',
                    'ca3_learning', 'ca3_recalling', 'ca3_debug'}


def parse_vcd_lightweight(vcd_file, signals_of_interest, max_samples=100000):
    """
    Lightweight VCD parser optimized for large files.

    Args:
        vcd_file: Path to VCD file
        signals_of_interest: List of signal names to extract
        max_samples: Maximum number of samples to extract

    Returns:
        Dict of signal_name -> numpy array of values
    """
    print(f"Parsing VCD file: {vcd_file}")

    # First pass: extract signal IDs from header
    signal_ids = {}
    signal_widths = {}

    with open(vcd_file, 'r') as f:
        in_header = True
        for line in f:
            if '$enddefinitions' in line:
                in_header = False
                break

            if in_header and line.startswith('$var'):
                parts = line.split()
                if len(parts) >= 5:
                    var_type = parts[1]  # wire, reg, integer, etc.
                    if var_type not in ('wire', 'reg', 'integer'):
                        continue  # Skip parameters
                    try:
                        width = int(parts[2])
                    except ValueError:
                        continue
                    var_id = parts[3]
                    # Note: Don't use rstrip('$end') - it strips individual chars!
                    var_name = parts[4]

                    # Check if this signal is one we want
                    # Handle both "signal_name [N:0]" and "signal_name[N:0]" formats
                    if not var_name:
                        continue
                    parts_name = var_name.split()
                    if not parts_name:
                        continue
                    base_name = parts_name[0].split('[')[0]
                    for sig in signals_of_interest:
                        if sig == base_name:
                            signal_ids[var_id] = sig
                            signal_widths[var_id] = width
                            break

    print(f"Found {len(signal_ids)} matching signals: {list(signal_ids.values())}")

    # Second pass: extract values
    signal_data = {sig: [] for sig in signals_of_interest if sig in signal_ids.values()}
    current_time = 0
    sample_count = 0
    last_values = {}

    with open(vcd_file, 'r') as f:
        for line in f:
            line = line.strip()

            # Time marker
            if line.startswith('#'):
                current_time = int(line[1:])
                sample_count += 1

                # Periodically record current values (downsample)
                if sample_count % 10 == 0:  # Every 10th sample
                    for var_id, sig_name in signal_ids.items():
                        if var_id in last_values:
                            signal_data[sig_name].append(last_values[var_id])

                if sample_count >= max_samples * 10:
                    break
                continue

            # Binary value change: bVALUE ID
            if line.startswith('b'):
                parts = line.split()
                if len(parts) == 2:
                    bin_val = parts[0][1:]  # Remove 'b' prefix
                    var_id = parts[1]

                    if var_id in signal_ids:
                        try:
                            val = int(bin_val, 2)
                            width = signal_widths.get(var_id, 18)
                            sig_name = signal_ids[var_id]
                            signed = sig_name not in UNSIGNED_SIGNALS
                            val = twos_complement(val, width, signed=signed)
                            last_values[var_id] = val
                        except ValueError:
                            pass

            # Single-bit value change: 0ID or 1ID
            elif len(line) >= 2 and line[0] in '01xXzZ':
                val_char = line[0]
                var_id = line[1:]

                if var_id in signal_ids:
                    if val_char == '1':
                        last_values[var_id] = 1
                    elif val_char == '0':
                        last_values[var_id] = 0

    # Convert to numpy arrays
    result = {}
    for sig_name, values in signal_data.items():
        if values:
            result[sig_name] = np.array(values)
            print(f"  {sig_name}: {len(values)} samples, range [{min(values)}, {max(values)}]")

    return result


def parse_vcd_by_state(vcd_file, signals, samples_per_state=8000):
    """
    Parse VCD file and extract data for each consciousness state.

    The testbench runs 5 states sequentially:
    - NORMAL (0), ANESTHESIA (1), PSYCHEDELIC (2), FLOW (3), MEDITATION (4)

    Returns dict of state_name -> {signal_name: array}
    """
    # For now, parse entire file and split by state
    # In practice, would need to detect state transitions from state_select signal

    signals_with_state = signals + ['state_select']
    data = parse_vcd_lightweight(vcd_file, signals_with_state, max_samples=50000)

    if 'state_select' not in data:
        print("Warning: state_select not found, returning all data as NORMAL")
        return {'NORMAL': data}

    # Find minimum common length across all signals
    min_len = min(len(arr) for arr in data.values())
    print(f"Resampling all signals to common length: {min_len}")

    # Resample all signals to common length
    for sig_name in data:
        if len(data[sig_name]) > min_len:
            # Downsample by taking evenly spaced samples
            indices = np.linspace(0, len(data[sig_name])-1, min_len, dtype=int)
            data[sig_name] = data[sig_name][indices]

    state_names = ['NORMAL', 'ANESTHESIA', 'PSYCHEDELIC', 'FLOW', 'MEDITATION']
    state_data = {}

    state_select = data['state_select']

    for state_idx, state_name in enumerate(state_names):
        mask = state_select == state_idx
        if np.any(mask):
            state_data[state_name] = {}
            for sig_name, values in data.items():
                if sig_name != 'state_select':
                    state_data[state_name][sig_name] = values[mask]
            print(f"State {state_name}: {np.sum(mask)} samples")

    return state_data


def compute_peak_trough_ratio(theta_x, gamma_amp, peak_threshold=0.7, trough_threshold=0.3):
    """
    Compute ratio of gamma amplitude at theta peak vs trough.

    Args:
        theta_x: Theta oscillator x component (Q4.14 format)
        gamma_amp: Gamma amplitude (Q4.14 format)

    Returns:
        ratio > 1 indicates theta-gamma coupling
    """
    if len(theta_x) == 0 or len(gamma_amp) == 0:
        return 1.0

    # Normalize theta to [0, 1]
    theta_min, theta_max = np.min(theta_x), np.max(theta_x)
    theta_range = theta_max - theta_min if theta_max > theta_min else 1.0
    theta_norm = (theta_x - theta_min) / theta_range

    # Get gamma amplitude at theta peaks and troughs
    at_peak = gamma_amp[theta_norm > peak_threshold]
    at_trough = gamma_amp[theta_norm < trough_threshold]

    if len(at_peak) == 0 or len(at_trough) == 0:
        return 1.0

    mean_at_peak = np.mean(at_peak)
    mean_at_trough = np.mean(at_trough)

    if mean_at_trough < 1e-6:
        return mean_at_peak if mean_at_peak > 1e-6 else 1.0

    return mean_at_peak / mean_at_trough


def compute_pac_modulation_index(theta_x, theta_y, gamma_amp, n_bins=18):
    """
    Compute Phase-Amplitude Coupling Modulation Index.

    Args:
        theta_x, theta_y: Theta oscillator components
        gamma_amp: Gamma amplitude
        n_bins: Number of phase bins

    Returns:
        mi: Modulation Index (KL divergence from uniform)
        bin_centers: Phase bin centers
        mean_amp: Mean gamma amplitude in each phase bin
    """
    if len(theta_x) == 0:
        return 0.0, np.zeros(n_bins), np.zeros(n_bins)

    # Compute theta phase from x, y components
    theta_phase = np.arctan2(theta_y, theta_x)

    bin_edges = np.linspace(-np.pi, np.pi, n_bins + 1)
    bin_centers = (bin_edges[:-1] + bin_edges[1:]) / 2

    mean_amp = np.zeros(n_bins)
    for i in range(n_bins):
        mask = (theta_phase >= bin_edges[i]) & (theta_phase < bin_edges[i+1])
        if np.sum(mask) > 0:
            mean_amp[i] = np.mean(gamma_amp[mask])

    # Normalize
    total = np.sum(mean_amp)
    if total > 0:
        mean_amp_norm = mean_amp / total
    else:
        mean_amp_norm = np.ones(n_bins) / n_bins

    # Modulation Index (KL divergence from uniform)
    uniform = np.ones(n_bins) / n_bins
    mi = np.sum(mean_amp_norm * np.log(mean_amp_norm / uniform + 1e-10)) / np.log(n_bins)

    return mi, bin_centers, mean_amp


def compute_pattern_entropy(patterns):
    """
    Compute Shannon entropy of pattern distribution.

    Args:
        patterns: Array of 6-bit pattern values (0-63)

    Returns:
        entropy in bits
    """
    if len(patterns) == 0:
        return 0.0

    counts = np.bincount(patterns.astype(int), minlength=64)
    probs = counts / len(patterns)
    probs = probs[probs > 0]  # Remove zeros

    return -np.sum(probs * np.log2(probs))


def analyze_state_metrics(state_data):
    """
    Compute all metrics for a single state.

    Args:
        state_data: Dict of signal_name -> numpy array

    Returns:
        Dict of metric_name -> value
    """
    metrics = {}

    # Use gamma_amp_raw for coupling metrics (before suppression)
    # Fall back to gamma_amp if raw not available
    gamma_signal = 'gamma_amp_raw' if 'gamma_amp_raw' in state_data else 'gamma_amp'

    # Theta-Gamma Peak-Trough Ratio
    if 'theta_x' in state_data and gamma_signal in state_data:
        metrics['peak_trough_ratio'] = compute_peak_trough_ratio(
            state_data['theta_x'],
            state_data[gamma_signal]
        )
    else:
        metrics['peak_trough_ratio'] = 1.0

    # PAC Modulation Index
    if all(k in state_data for k in ['theta_x', 'theta_y']) and gamma_signal in state_data:
        mi, bins, amps = compute_pac_modulation_index(
            state_data['theta_x'],
            state_data['theta_y'],
            state_data[gamma_signal]
        )
        metrics['pac_mi'] = mi
        metrics['pac_bins'] = bins
        metrics['pac_amp'] = amps
    else:
        metrics['pac_mi'] = 0.0

    # Pattern Entropy (use oscillator_derived_pattern first, then phase_pattern)
    if 'oscillator_derived_pattern' in state_data:
        patterns = state_data['oscillator_derived_pattern']
        # Ensure values are in valid range [0, 63]
        patterns = np.clip(patterns, 0, 63)
        metrics['pattern_entropy'] = compute_pattern_entropy(patterns)
        metrics['unique_patterns'] = len(np.unique(patterns))
    elif 'phase_pattern' in state_data:
        patterns = state_data['phase_pattern']
        patterns = np.clip(patterns, 0, 63)
        metrics['pattern_entropy'] = compute_pattern_entropy(patterns)
        metrics['unique_patterns'] = len(np.unique(patterns))
    else:
        metrics['pattern_entropy'] = 0.0
        metrics['unique_patterns'] = 0

    # Gamma amplitude (both raw and suppressed if available)
    if 'gamma_amp_raw' in state_data:
        metrics['gamma_mean_amp_raw'] = np.mean(state_data['gamma_amp_raw'])
    if 'gamma_amp' in state_data:
        metrics['gamma_mean_amp'] = np.mean(state_data['gamma_amp'])

    # Phase reset activity
    if 'phase_reset_input' in state_data:
        resets = state_data['phase_reset_input']
        metrics['phase_reset_count'] = np.sum(np.abs(resets) > 100)

    return metrics


def run_vcd_analysis(vcd_file):
    """
    Main analysis function.

    Args:
        vcd_file: Path to VCD file

    Returns:
        Dict of state_name -> metrics dict
    """
    # Signal names must match VCD exactly
    # Note: state_select is a reg, not wire, so parser may need adjustment
    signals = [
        'theta_x', 'theta_y', 'theta_amp', 'theta_envelope',
        'gamma_x', 'gamma_y', 'gamma_amp',
        'gamma_x_raw', 'gamma_amp_raw',
        'gamma_x_pac', 'gamma_amp_pac',
        'alpha_x', 'alpha_y', 'alpha_amp',
        'phase_pattern', 'oscillator_derived_pattern',
        'ca3_learning', 'ca3_recalling',
        'mu_modulation', 'mu_gamma_modulated',
        'phase_reset_input',
        # Per-column signals
        'sens_gamma_amp_raw', 'motor_gamma_amp_raw', 'assoc_gamma_amp_raw',
    ]

    print("\n" + "="*60)
    print("VCD METRICS ANALYSIS")
    print("="*60)

    state_data = parse_vcd_by_state(vcd_file, signals)

    results = {}
    for state_name, data in state_data.items():
        print(f"\nAnalyzing {state_name}...")
        results[state_name] = analyze_state_metrics(data)

    # Print summary
    print("\n" + "="*80)
    print("FPGA SIMULATION METRICS SUMMARY")
    print("="*80)
    print(f"{'State':<15} {'Peak/Trough':>12} {'PAC (MI)':>10} {'Entropy':>8} {'Patterns':>10} {'γ Raw':>12} {'γ Supp':>10}")
    print("-"*80)

    for state in ['NORMAL', 'ANESTHESIA', 'PSYCHEDELIC', 'FLOW', 'MEDITATION']:
        if state in results:
            m = results[state]
            ptr = m.get('peak_trough_ratio', 1.0)
            pac = m.get('pac_mi', 0.0)
            ent = m.get('pattern_entropy', 0.0)
            pats = m.get('unique_patterns', 0)
            amp_raw = m.get('gamma_mean_amp_raw', 0)
            amp = m.get('gamma_mean_amp', 0)
            print(f"{state:<15} {ptr:>12.2f} {pac:>10.4f} {ent:>8.2f} {pats:>10} {amp_raw:>12.0f} {amp:>10.0f}")
        else:
            print(f"{state:<15} {'(no data)':<12}")

    print("="*80)
    print("\nMetric Definitions:")
    print("  Peak/Trough: Gamma amplitude at theta peak / trough (>1 = coupling)")
    print("  PAC (MI):    Modulation Index (higher = stronger theta-gamma PAC)")
    print("  Entropy:     Pattern entropy in bits (max = 6 bits for 64 patterns)")
    print("  Patterns:    Unique 6-bit patterns observed")
    print("  γ Raw:       Mean gamma amplitude BEFORE suppression (Q4.14 units)")
    print("  γ Supp:      Mean gamma amplitude AFTER suppression (ANESTHESIA = ~5%)")

    return results


def generate_poster_figures(results, output_dir=None):
    """
    Generate poster figures from FPGA metrics.

    Creates bar charts for:
    1. Pattern Entropy by state
    2. Peak/Trough Ratio by state
    3. PAC Modulation Index by state
    """
    if output_dir is None:
        output_dir = Path(__file__).parent.parent / 'poster_figures'
    output_dir = Path(output_dir)
    output_dir.mkdir(exist_ok=True)

    states = ['NORMAL', 'ANESTHESIA', 'PSYCHEDELIC', 'FLOW', 'MEDITATION']
    state_labels = ['Normal', 'Anesthesia', 'Psychedelic', 'Flow', 'Meditation']
    colors = ['#4CAF50', '#9E9E9E', '#FF5722', '#2196F3', '#9C27B0']

    # Extract metrics
    entropy = [results.get(s, {}).get('pattern_entropy', 0) for s in states]
    ptr = [results.get(s, {}).get('peak_trough_ratio', 1.0) for s in states]
    pac = [results.get(s, {}).get('pac_mi', 0.0) for s in states]
    patterns = [results.get(s, {}).get('unique_patterns', 0) for s in states]

    # Figure 1: Pattern Entropy
    fig, ax = plt.subplots(figsize=(8, 5))
    bars = ax.bar(state_labels, entropy, color=colors, edgecolor='black', linewidth=1.5)
    ax.set_ylabel('Pattern Entropy (bits)', fontsize=12)
    ax.set_title('φⁿ Neural Processor: Pattern Complexity by State\n(FPGA Simulation)', fontsize=14)
    ax.set_ylim(0, 6)  # Max entropy = 6 bits
    ax.axhline(y=6, color='gray', linestyle='--', alpha=0.5, label='Max (6 bits)')
    # Add value labels
    for bar, val in zip(bars, entropy):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.1,
                f'{val:.2f}', ha='center', va='bottom', fontsize=10)
    ax.legend()
    plt.tight_layout()
    fig.savefig(output_dir / 'fpga_entropy_by_state.png', dpi=150)
    print(f"Saved: {output_dir / 'fpga_entropy_by_state.png'}")
    plt.close(fig)

    # Figure 2: Peak/Trough Ratio
    fig, ax = plt.subplots(figsize=(8, 5))
    bars = ax.bar(state_labels, ptr, color=colors, edgecolor='black', linewidth=1.5)
    ax.set_ylabel('θ-γ Peak/Trough Ratio', fontsize=12)
    ax.set_title('φⁿ Neural Processor: Theta-Gamma Coupling\n(FPGA Simulation)', fontsize=14)
    ax.axhline(y=1.0, color='red', linestyle='--', alpha=0.7, label='No coupling')
    ax.set_ylim(0.5, 1.5)
    for bar, val in zip(bars, ptr):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.02,
                f'{val:.2f}', ha='center', va='bottom', fontsize=10)
    ax.legend()
    plt.tight_layout()
    fig.savefig(output_dir / 'fpga_peak_trough_by_state.png', dpi=150)
    print(f"Saved: {output_dir / 'fpga_peak_trough_by_state.png'}")
    plt.close(fig)

    # Figure 3: Unique Patterns
    fig, ax = plt.subplots(figsize=(8, 5))
    bars = ax.bar(state_labels, patterns, color=colors, edgecolor='black', linewidth=1.5)
    ax.set_ylabel('Unique Patterns (of 64)', fontsize=12)
    ax.set_title('φⁿ Neural Processor: Pattern Diversity by State\n(FPGA Simulation)', fontsize=14)
    ax.set_ylim(0, 64)
    ax.axhline(y=64, color='gray', linestyle='--', alpha=0.5, label='Max (64 patterns)')
    for bar, val in zip(bars, patterns):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1,
                f'{val}', ha='center', va='bottom', fontsize=10)
    ax.legend()
    plt.tight_layout()
    fig.savefig(output_dir / 'fpga_patterns_by_state.png', dpi=150)
    print(f"Saved: {output_dir / 'fpga_patterns_by_state.png'}")
    plt.close(fig)

    # Figure 4: Combined dashboard
    fig, axes = plt.subplots(1, 3, figsize=(14, 5))

    # Entropy
    axes[0].bar(state_labels, entropy, color=colors, edgecolor='black')
    axes[0].set_ylabel('Entropy (bits)')
    axes[0].set_title('Pattern Entropy')
    axes[0].set_ylim(0, 6)
    axes[0].tick_params(axis='x', rotation=45)

    # Peak/Trough
    axes[1].bar(state_labels, ptr, color=colors, edgecolor='black')
    axes[1].set_ylabel('Ratio')
    axes[1].set_title('θ-γ Peak/Trough')
    axes[1].axhline(y=1.0, color='red', linestyle='--', alpha=0.7)
    axes[1].set_ylim(0.5, 1.5)
    axes[1].tick_params(axis='x', rotation=45)

    # Patterns
    axes[2].bar(state_labels, patterns, color=colors, edgecolor='black')
    axes[2].set_ylabel('Count')
    axes[2].set_title('Unique Patterns')
    axes[2].set_ylim(0, 64)
    axes[2].tick_params(axis='x', rotation=45)

    fig.suptitle('φⁿ Neural Processor: FPGA Simulation Metrics', fontsize=14, y=1.02)
    plt.tight_layout()
    fig.savefig(output_dir / 'fpga_dashboard.png', dpi=150, bbox_inches='tight')
    print(f"Saved: {output_dir / 'fpga_dashboard.png'}")
    plt.close(fig)

    print(f"\nAll figures saved to: {output_dir}")


if __name__ == '__main__':
    import sys

    if len(sys.argv) > 1:
        vcd_file = sys.argv[1]
    else:
        # Default path
        vcd_file = Path(__file__).parent.parent / 'tb_state_characterization.vcd'

    results = run_vcd_analysis(vcd_file)

    # Generate poster figures
    generate_poster_figures(results)
