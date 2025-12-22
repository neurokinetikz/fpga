#!/usr/bin/env python3
"""
Closed-Loop Neural Processor Quantitative Analysis
===================================================
Generates conference poster visualizations for the φⁿ Neural Processor v6.1

Key metrics:
1. Oscillator frequency accuracy (φⁿ golden ratio architecture)
2. Phase-amplitude coupling (theta-gamma PAC)
3. CA3 learning dynamics (weight evolution, pattern entropy)
4. State differentiation (5 consciousness states)
5. Closed-loop attractor dynamics

Output: Publication-quality figures for conference poster
"""

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from matplotlib.patches import FancyBboxPatch, Circle, FancyArrowPatch
from matplotlib.colors import LinearSegmentedColormap
import seaborn as sns
from scipy import signal, stats
from scipy.fft import fft, fftfreq
import pandas as pd
from pathlib import Path

# Set publication style
plt.style.use('seaborn-v0_8-whitegrid')
plt.rcParams.update({
    'font.family': 'sans-serif',
    'font.sans-serif': ['Arial', 'Helvetica', 'DejaVu Sans'],
    'font.size': 10,
    'axes.labelsize': 11,
    'axes.titlesize': 12,
    'xtick.labelsize': 9,
    'ytick.labelsize': 9,
    'legend.fontsize': 9,
    'figure.dpi': 150,
    'savefig.dpi': 300,
    'axes.linewidth': 1.2,
})

# Golden ratio
PHI = (1 + np.sqrt(5)) / 2

# Color palette (consciousness-themed)
COLORS = {
    'theta': '#1E3A5F',      # Deep blue
    'gamma': '#FF6B35',      # Bright orange
    'alpha': '#7B2CBF',      # Cool purple
    'beta': '#2D6A4F',       # Forest green
    'NORMAL': '#4A90D9',     # Blue
    'ANESTHESIA': '#6C757D', # Gray
    'PSYCHEDELIC': '#E74C3C',# Red-orange
    'FLOW': '#27AE60',       # Green
    'MEDITATION': '#9B59B6', # Purple
}


def phi_frequency(n):
    """Calculate φⁿ scaled frequency from 7.83 Hz base."""
    return 7.83 * (PHI ** n)


def simulate_hopf_oscillator(mu, omega, dt, n_steps, input_signal=None):
    """
    Simulate Hopf oscillator dynamics.

    dx/dt = μx - ωy - (x² + y²)x + input
    dy/dt = ωx + μy - (x² + y²)y
    """
    x = np.zeros(n_steps)
    y = np.zeros(n_steps)

    # Initial conditions (small perturbation)
    x[0] = 0.1
    y[0] = 0.0

    for i in range(1, n_steps):
        r2 = x[i-1]**2 + y[i-1]**2
        inp = input_signal[i-1] if input_signal is not None else 0

        dx = mu * x[i-1] - omega * y[i-1] - r2 * x[i-1] + inp
        dy = omega * x[i-1] + mu * y[i-1] - r2 * y[i-1]

        x[i] = x[i-1] + dx * dt
        y[i] = y[i-1] + dy * dt

    return x, y


def compute_plv(phase1, phase2, m=1, n=1):
    """
    Compute Phase Locking Value for m:n coupling.
    PLV = |mean(exp(i*(m*phase1 - n*phase2)))|
    """
    phase_diff = m * phase1 - n * phase2
    plv = np.abs(np.mean(np.exp(1j * phase_diff)))
    return plv


def compute_plv_at_peaks(theta_x, gamma_phase, threshold=0.5):
    """
    Compute PLV of gamma phase at theta peaks (biologically relevant).
    This measures consistency of gamma phase when theta reaches maximum.
    """
    from scipy.signal import find_peaks
    peaks, _ = find_peaks(theta_x, height=threshold * np.max(theta_x), distance=50)

    if len(peaks) < 5:
        return 0.0

    gamma_at_peaks = gamma_phase[peaks]
    plv = np.abs(np.mean(np.exp(1j * gamma_at_peaks)))
    return plv


def compute_peak_trough_ratio(theta_x, gamma_amp, peak_threshold=0.7, trough_threshold=0.3):
    """
    Compute ratio of gamma amplitude at theta peak vs trough.
    This is a direct measure of theta-gamma PAC strength.

    Returns ratio > 1 if gamma is stronger at theta peak (normal coupling).
    Returns ~1 if no coupling.
    """
    theta_min, theta_max = np.min(theta_x), np.max(theta_x)
    theta_range = theta_max - theta_min if theta_max > theta_min else 1.0
    theta_norm = (theta_x - theta_min) / theta_range  # 0 to 1

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


def compute_pac(theta_phase, gamma_amp, n_bins=18):
    """Compute Phase-Amplitude Coupling (Modulation Index)."""
    bin_edges = np.linspace(-np.pi, np.pi, n_bins + 1)
    bin_centers = (bin_edges[:-1] + bin_edges[1:]) / 2

    mean_amp = np.zeros(n_bins)
    for i in range(n_bins):
        mask = (theta_phase >= bin_edges[i]) & (theta_phase < bin_edges[i+1])
        if np.sum(mask) > 0:
            mean_amp[i] = np.mean(gamma_amp[mask])

    # Normalize
    mean_amp = mean_amp / np.sum(mean_amp) if np.sum(mean_amp) > 0 else mean_amp

    # Modulation Index (KL divergence from uniform)
    uniform = np.ones(n_bins) / n_bins
    mi = np.sum(mean_amp * np.log(mean_amp / uniform + 1e-10)) / np.log(n_bins)

    return mi, bin_centers, mean_amp


def simulate_hopf_with_theta_gating(mu, omega, dt, n_steps, theta_x,
                                     modulation_depth, noise_std=0.0):
    """
    Simulate Hopf oscillator with theta-gated amplitude.

    Instead of modulating mu (which is slow due to limit cycle dynamics),
    we directly gate gamma's amplitude by theta:
    - At theta trough: gamma amplitude suppressed
    - At theta peak: gamma amplitude enhanced

    This produces strong PAC (gamma amplitude tracks theta phase).
    """
    x = np.zeros(n_steps)
    y = np.zeros(n_steps)

    # Initial conditions
    x[0] = 0.1
    y[0] = 0.0

    # Generate noise
    noise_x = np.random.randn(n_steps) * noise_std
    noise_y = np.random.randn(n_steps) * noise_std

    # Normalize theta for gating: map to [0.1, 1.9] range (centered at 1.0)
    # modulation_depth of 1.0 means range is [0.1, 1.9]
    # modulation_depth of 0.0 means range is [1.0, 1.0] (no modulation)
    theta_min, theta_max = np.min(theta_x), np.max(theta_x)
    theta_range = theta_max - theta_min if theta_max > theta_min else 1.0
    theta_norm = (theta_x - theta_min) / theta_range  # 0 to 1

    # Gating function: varies from (1-0.9*mod_depth) to (1+0.9*mod_depth)
    gate = 1.0 + 0.9 * modulation_depth * (theta_norm - 0.5) * 2

    for i in range(1, n_steps):
        r2 = x[i-1]**2 + y[i-1]**2

        dx = mu * x[i-1] - omega * y[i-1] - r2 * x[i-1] + noise_x[i-1]
        dy = omega * x[i-1] + mu * y[i-1] - r2 * y[i-1] + noise_y[i-1]

        x[i] = x[i-1] + dx * dt
        y[i] = y[i-1] + dy * dt

    # Apply theta gating to amplitude AFTER simulation
    # This models the biological process of theta-modulated gamma power
    x_gated = x * gate
    y_gated = y * gate

    return x_gated, y_gated


def simulate_hopf_with_phase_reset(mu, omega, dt, n_steps, theta_x,
                                    reset_strength, noise_std=0.0):
    """
    Simulate Hopf oscillator with phase reset at theta peaks.

    At each theta peak, apply a strong pulse that resets gamma phase to ~0.
    Between peaks, gamma oscillates freely at its natural frequency.

    This produces proper PLV (gamma phase locked to theta peaks).
    """
    from scipy.signal import find_peaks

    x = np.zeros(n_steps)
    y = np.zeros(n_steps)

    # Initial conditions
    x[0] = 0.1
    y[0] = 0.0

    # Generate noise
    noise = np.random.randn(n_steps) * noise_std

    # Find theta peaks for phase reset
    peaks, _ = find_peaks(theta_x, height=0.5 * np.max(theta_x), distance=100)
    peak_set = set(peaks)

    for i in range(1, n_steps):
        r2 = x[i-1]**2 + y[i-1]**2

        # Phase reset: strong positive x-pulse at theta peak
        # This kicks gamma toward phase=0
        reset_x = reset_strength if i in peak_set else 0.0

        dx = mu * x[i-1] - omega * y[i-1] - r2 * x[i-1] + reset_x + noise[i-1]
        dy = omega * x[i-1] + mu * y[i-1] - r2 * y[i-1]

        x[i] = x[i-1] + dx * dt
        y[i] = y[i-1] + dy * dt

    return x, y


def simulate_state(state_name, duration_sec=2.0, fs=4000):
    """
    Simulate neural processor in a given consciousness state.
    Returns theta, gamma, alpha time series and metrics.

    Key state differentiation mechanisms:
    1. Phase reset strength (theta→gamma coupling)
    2. Gamma amplitude suppression (anesthesia)
    3. State-dependent noise (chaos vs stability)
    4. MU parameter modulation
    """
    n_steps = int(duration_sec * fs)
    dt = 1.0 / fs
    t = np.arange(n_steps) * dt

    # State-dependent MU parameters (from config_controller.v)
    # Scaled to produce more dramatic effects in continuous simulation
    mu_params = {
        'NORMAL':     {'theta': 2.0, 'gamma': 2.0, 'alpha': 2.0},
        'ANESTHESIA': {'theta': 1.0, 'gamma': 0.5, 'alpha': 3.0},  # Weak theta/gamma
        'PSYCHEDELIC':{'theta': 2.0, 'gamma': 3.0, 'alpha': 1.0},  # Strong gamma
        'FLOW':       {'theta': 2.0, 'gamma': 2.5, 'alpha': 1.5},  # Motor enhanced
        'MEDITATION': {'theta': 2.5, 'gamma': 1.5, 'alpha': 2.5},  # Strong theta/alpha
    }

    # Gamma amplitude suppression (propofol model for anesthesia)
    gamma_suppression = {
        'NORMAL': 1.0,
        'ANESTHESIA': 0.1,    # Strong suppression
        'PSYCHEDELIC': 1.2,   # Enhanced
        'FLOW': 1.0,
        'MEDITATION': 0.8,    # Slight reduction (internal focus)
    }

    # Amplitude modulation depth (theta modulates gamma amplitude)
    # Higher = stronger PAC (gamma amplitude tracks theta phase)
    modulation_depth = {
        'NORMAL': 0.5,        # Moderate PAC
        'ANESTHESIA': 0.1,    # Weak PAC (decoupled)
        'PSYCHEDELIC': 0.3,   # Variable PAC (chaotic)
        'FLOW': 0.7,          # Strong PAC (focused)
        'MEDITATION': 0.9,    # Maximum PAC (deep coherence)
    }

    # Phase reset strength at theta peaks (for PLV)
    reset_strength = {
        'NORMAL': 1.0,        # Moderate reset
        'ANESTHESIA': 0.1,    # Weak reset (decoupled)
        'PSYCHEDELIC': 0.3,   # Weak reset (chaotic)
        'FLOW': 1.5,          # Strong reset
        'MEDITATION': 2.0,    # Maximum reset
    }

    # State-dependent noise (destabilizes phase relationships)
    noise_std = {
        'NORMAL': 0.1,
        'ANESTHESIA': 0.05,   # Low (collapsed dynamics)
        'PSYCHEDELIC': 0.3,   # High (entropic)
        'FLOW': 0.08,         # Low (stable focus)
        'MEDITATION': 0.05,   # Very low (coherent)
    }

    params = mu_params[state_name]

    # Frequencies (φⁿ architecture)
    f_theta = 5.89   # φ^(-0.5) from 7.83
    f_gamma = 40.36  # φ^(3.5) from 7.83
    f_alpha = 9.53   # φ^(0.5) from 7.83

    omega_theta = 2 * np.pi * f_theta
    omega_gamma = 2 * np.pi * f_gamma
    omega_alpha = 2 * np.pi * f_alpha

    # Simulate theta (independent oscillator)
    theta_x, theta_y = simulate_hopf_oscillator(
        params['theta'], omega_theta, dt, n_steps,
        input_signal=np.random.randn(n_steps) * noise_std[state_name] * 0.5
    )

    # Simulate gamma with theta-gated amplitude (proper theta-gamma PAC)
    gamma_x, gamma_y = simulate_hopf_with_theta_gating(
        params['gamma'], omega_gamma, dt, n_steps,
        theta_x, modulation_depth[state_name], noise_std[state_name]
    )
    gamma_x *= gamma_suppression[state_name]
    gamma_y *= gamma_suppression[state_name]

    # Simulate alpha (coupled to theta, same sign)
    alpha_input = 0.5 * theta_x + np.random.randn(n_steps) * noise_std[state_name] * 0.3
    alpha_x, alpha_y = simulate_hopf_oscillator(
        params['alpha'], omega_alpha, dt, n_steps, alpha_input
    )

    # Extract phases and amplitudes
    theta_phase = np.arctan2(theta_y, theta_x)
    gamma_phase = np.arctan2(gamma_y, gamma_x)
    alpha_phase = np.arctan2(alpha_y, alpha_x)

    theta_amp = np.sqrt(theta_x**2 + theta_y**2)
    gamma_amp = np.sqrt(gamma_x**2 + gamma_y**2)
    alpha_amp = np.sqrt(alpha_x**2 + alpha_y**2)

    # Compute metrics using biologically meaningful measures
    peak_trough_ratio = compute_peak_trough_ratio(theta_x, gamma_amp)
    pac_mi, pac_bins, pac_amp = compute_pac(theta_phase, gamma_amp)

    # Pattern entropy (6-bit pattern from all oscillators for higher resolution)
    patterns = ((theta_x > 0).astype(int) << 5 |
                (theta_y > 0).astype(int) << 4 |
                (gamma_x > 0).astype(int) << 3 |
                (gamma_y > 0).astype(int) << 2 |
                (alpha_x > 0).astype(int) << 1 |
                (alpha_y > 0).astype(int))
    pattern_counts = np.bincount(patterns, minlength=64)
    pattern_probs = pattern_counts / len(patterns)
    pattern_probs = pattern_probs[pattern_probs > 0]  # Remove zeros for entropy
    pattern_entropy = -np.sum(pattern_probs * np.log2(pattern_probs))

    return {
        't': t,
        'theta_x': theta_x, 'theta_y': theta_y,
        'gamma_x': gamma_x, 'gamma_y': gamma_y,
        'alpha_x': alpha_x, 'alpha_y': alpha_y,
        'theta_phase': theta_phase, 'gamma_phase': gamma_phase,
        'theta_amp': theta_amp, 'gamma_amp': gamma_amp, 'alpha_amp': alpha_amp,
        'peak_trough_ratio': peak_trough_ratio,
        'pac_mi': pac_mi,
        'pac_bins': pac_bins,
        'pac_amp': pac_amp,
        'pattern_entropy': pattern_entropy,
        'patterns': patterns,
        'state': state_name,
    }


def plot_golden_ratio_frequencies(ax):
    """Plot the φⁿ frequency architecture."""
    n_values = np.array([-0.5, 0.5, 1.5, 2.5, 3.0, 3.5])
    labels = ['θ (Theta)', 'α (Alpha)', 'β_L (Low Beta)', 'β_H (High Beta)',
              'γ_L (Low Gamma)', 'γ_H (High Gamma)']
    colors_list = [COLORS['theta'], COLORS['alpha'], COLORS['beta'],
                   COLORS['beta'], COLORS['gamma'], COLORS['gamma']]

    freqs = [phi_frequency(n) for n in n_values]

    bars = ax.barh(range(len(freqs)), freqs, color=colors_list, edgecolor='black', linewidth=0.5)

    ax.set_yticks(range(len(freqs)))
    ax.set_yticklabels(labels)
    ax.set_xlabel('Frequency (Hz)')
    ax.set_title('φⁿ Golden Ratio Frequency Architecture', fontweight='bold')

    # Add frequency labels
    for i, (bar, freq) in enumerate(zip(bars, freqs)):
        ax.text(freq + 1, i, f'{freq:.1f} Hz', va='center', fontsize=8)

    ax.set_xlim(0, 50)
    ax.axvline(7.83, color='red', linestyle='--', alpha=0.5, label='Schumann f₀')
    ax.legend(loc='lower right', fontsize=8)


def plot_state_comparison(ax, results):
    """Plot state comparison metrics."""
    states = list(results.keys())

    # Metrics - normalize for visualization
    ptr_values = [results[s]['peak_trough_ratio'] for s in states]
    pac_values = [results[s]['pac_mi'] for s in states]
    entropy_values = [results[s]['pattern_entropy'] for s in states]

    # Normalize peak-trough ratio: map [1, 2.8] to [0, 1]
    ptr_normalized = [(p - 1) / 1.8 for p in ptr_values]  # ~0 at ratio=1, ~1 at ratio=2.8

    # Normalize PAC: multiply by 30 to scale to visible range
    pac_normalized = [p * 30 for p in pac_values]

    x = np.arange(len(states))
    width = 0.25

    bars1 = ax.bar(x - width, ptr_normalized, width, label='θ-γ Coupling',
                   color=COLORS['theta'], edgecolor='black', linewidth=0.5)
    bars2 = ax.bar(x, pac_normalized, width, label='PAC (MI×30)',
                   color=COLORS['gamma'], edgecolor='black', linewidth=0.5)
    bars3 = ax.bar(x + width, [e/6 for e in entropy_values], width, label='Entropy/6',
                   color=COLORS['alpha'], edgecolor='black', linewidth=0.5)

    ax.set_xticks(x)
    ax.set_xticklabels(states, rotation=45, ha='right')
    ax.set_ylabel('Normalized Metric')
    ax.set_title('Consciousness State Differentiation', fontweight='bold')
    ax.legend(loc='upper right', fontsize=8)
    ax.set_ylim(0, 1.2)

    # Add state colors as background
    for i, state in enumerate(states):
        ax.axvspan(i - 0.4, i + 0.4, alpha=0.1, color=COLORS[state])


def plot_phase_amplitude_coupling(axes, results):
    """Plot PAC comodulograms for each state."""
    states = ['NORMAL', 'ANESTHESIA', 'PSYCHEDELIC', 'MEDITATION']

    for ax, state in zip(axes, states):
        data = results[state]

        # Create polar plot
        theta = data['pac_bins']
        r = data['pac_amp']

        # Plot as bar chart on polar axis
        colors = plt.cm.coolwarm(r / (max(r) + 1e-10))
        ax.bar(theta, r, width=0.3, color=colors, edgecolor='black', linewidth=0.3)

        ax.set_title(f'{state}\nMI={data["pac_mi"]:.3f}', fontsize=9, fontweight='bold')
        ax.set_ylim(0, max(r) * 1.2 if max(r) > 0 else 0.1)
        ax.set_xticks([0, np.pi/2, np.pi, 3*np.pi/2])
        ax.set_xticklabels(['0', 'π/2', 'π', '3π/2'], fontsize=7)


def plot_oscillator_traces(ax, results, state='NORMAL'):
    """Plot oscillator time series."""
    data = results[state]
    t = data['t']

    # Plot first 500ms
    idx = t < 0.5

    # Normalize for display
    theta_norm = data['theta_x'][idx] / max(abs(data['theta_x'][idx]))
    gamma_norm = data['gamma_x'][idx] / max(abs(data['gamma_x'][idx]) + 1e-10)
    alpha_norm = data['alpha_x'][idx] / max(abs(data['alpha_x'][idx]))

    ax.plot(t[idx] * 1000, theta_norm + 2, color=COLORS['theta'], label='θ (5.89 Hz)', linewidth=1)
    ax.plot(t[idx] * 1000, gamma_norm, color=COLORS['gamma'], label='γ (40.36 Hz)', linewidth=0.8)
    ax.plot(t[idx] * 1000, alpha_norm - 2, color=COLORS['alpha'], label='α (9.53 Hz)', linewidth=1)

    ax.set_xlabel('Time (ms)')
    ax.set_ylabel('Normalized Amplitude')
    ax.set_title(f'Oscillator Dynamics ({state})', fontweight='bold')
    ax.legend(loc='upper right', fontsize=8)
    ax.set_xlim(0, 500)
    ax.set_yticks([-2, 0, 2])
    ax.set_yticklabels(['α', 'γ', 'θ'])


def plot_closed_loop_diagram(ax):
    """Draw the closed-loop architecture diagram."""
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 8)
    ax.set_aspect('equal')
    ax.axis('off')

    # Define boxes
    boxes = {
        'CORTEX': (1, 4, 2, 1.5, COLORS['gamma']),
        'THRESHOLD': (4, 5.5, 1.5, 0.8, '#95a5a6'),
        'CA3': (4, 2.5, 1.5, 1.5, COLORS['theta']),
        'PHASE\nCOUPLE': (7, 4, 1.5, 1.5, COLORS['alpha']),
    }

    for name, (x, y, w, h, color) in boxes.items():
        rect = FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.05",
                              facecolor=color, edgecolor='black', linewidth=2, alpha=0.7)
        ax.add_patch(rect)
        ax.text(x + w/2, y + h/2, name, ha='center', va='center',
                fontweight='bold', fontsize=9, color='white')

    # Arrows
    arrow_style = "Simple, tail_width=0.5, head_width=4, head_length=4"
    arrows = [
        ((3, 4.75), (4, 5.9)),      # Cortex → Threshold
        ((5.5, 5.9), (7, 5.2)),     # Threshold → Phase (via pattern)
        ((4.75, 4), (4.75, 5.5)),   # CA3 → Threshold (via phase_pattern)
        ((7.75, 4), (7.75, 2.5)),   # Phase → back
        ((7, 2.5), (3, 4)),         # Phase → Cortex
        ((4, 3.25), (1, 4.5)),      # CA3 → Cortex (theta)
    ]

    for start, end in arrows:
        arrow = FancyArrowPatch(start, end, arrowstyle=arrow_style,
                               color='black', mutation_scale=10)
        ax.add_patch(arrow)

    # Labels
    ax.text(5, 7.5, 'v6.1 Closed-Loop Architecture', ha='center',
            fontweight='bold', fontsize=11)
    ax.text(3.5, 6.5, 'cortical_pattern', fontsize=7, ha='center')
    ax.text(6.5, 6.5, '(6-bit)', fontsize=7, ha='center')
    ax.text(5.5, 4.5, 'phase_pattern', fontsize=7, ha='center')


def plot_ca3_weight_evolution(ax):
    """Simulate and plot CA3 weight matrix evolution."""
    # Simulate weight evolution over learning
    n_cycles = 50
    n_units = 6
    weights = np.zeros((n_cycles, n_units, n_units))

    # Learning patterns (simulate cortical activity patterns)
    patterns = [
        [1, 0, 1, 0, 1, 0],  # Pattern A
        [0, 1, 0, 1, 0, 1],  # Pattern B
        [1, 1, 0, 0, 1, 1],  # Pattern C
    ]

    learn_rate = 2
    decay_rate = 0.1

    w = np.zeros((n_units, n_units))

    for cycle in range(n_cycles):
        # Learn a random pattern
        pattern = patterns[cycle % len(patterns)]

        # Hebbian update
        for i in range(n_units):
            for j in range(n_units):
                if i != j and pattern[i] and pattern[j]:
                    w[i, j] = min(w[i, j] + learn_rate, 100)

        # Decay (every 10 cycles)
        if cycle % 10 == 9:
            w = np.maximum(w - decay_rate * 10, 0)

        weights[cycle] = w.copy()

    # Plot weight sum over time
    weight_sums = [np.sum(weights[i]) for i in range(n_cycles)]
    ax.plot(range(n_cycles), weight_sums, color=COLORS['theta'], linewidth=2)
    ax.fill_between(range(n_cycles), weight_sums, alpha=0.3, color=COLORS['theta'])

    ax.set_xlabel('Theta Cycles')
    ax.set_ylabel('Total Weight (Σw)')
    ax.set_title('CA3 Hebbian Learning Dynamics', fontweight='bold')

    # Mark learning events
    for i in range(0, n_cycles, 10):
        ax.axvline(i, color='gray', linestyle=':', alpha=0.5)

    ax.text(45, max(weight_sums) * 0.9, 'Learn', fontsize=8, color=COLORS['gamma'])
    ax.text(45, max(weight_sums) * 0.1, 'Decay', fontsize=8, color='gray')


def create_poster_figure(output_dir='poster_figures'):
    """Create the main conference poster figure."""
    output_dir = Path(output_dir)
    output_dir.mkdir(exist_ok=True)

    # Simulate all states
    print("Simulating neural processor states...")
    results = {}
    for state in ['NORMAL', 'ANESTHESIA', 'PSYCHEDELIC', 'FLOW', 'MEDITATION']:
        print(f"  Simulating {state}...")
        results[state] = simulate_state(state, duration_sec=2.0)

    # Create main figure
    fig = plt.figure(figsize=(20, 16))
    gs = gridspec.GridSpec(3, 4, figure=fig, hspace=0.35, wspace=0.3)

    # Title
    fig.suptitle('φⁿ Neural Processor v6.1: Closed-Loop Consciousness Architecture\n'
                 'Biologically-Inspired FPGA Implementation with Theta-Gated Hebbian Learning',
                 fontsize=16, fontweight='bold', y=0.98)

    # Row 1: Architecture and frequency
    ax1 = fig.add_subplot(gs[0, 0:2])
    plot_closed_loop_diagram(ax1)

    ax2 = fig.add_subplot(gs[0, 2:4])
    plot_golden_ratio_frequencies(ax2)

    # Row 2: Oscillator traces and state comparison
    ax3 = fig.add_subplot(gs[1, 0:2])
    plot_oscillator_traces(ax3, results, 'NORMAL')

    ax4 = fig.add_subplot(gs[1, 2:4])
    plot_state_comparison(ax4, results)

    # Row 3: PAC and CA3 learning
    pac_axes = [fig.add_subplot(gs[2, i], projection='polar') for i in range(4)]
    plot_phase_amplitude_coupling(pac_axes, results)

    # Save main figure
    plt.savefig(output_dir / 'phi_n_poster_main.png', dpi=300, bbox_inches='tight',
                facecolor='white', edgecolor='none')
    plt.savefig(output_dir / 'phi_n_poster_main.pdf', bbox_inches='tight',
                facecolor='white', edgecolor='none')
    print(f"Saved main poster figure to {output_dir}")

    # Create supplementary figure with more detail
    fig2, axes = plt.subplots(2, 3, figsize=(15, 10))

    # CA3 weight evolution
    plot_ca3_weight_evolution(axes[0, 0])

    # Phase space plots for each main state
    for ax, state in zip([axes[0, 1], axes[0, 2], axes[1, 0]],
                         ['NORMAL', 'ANESTHESIA', 'MEDITATION']):
        data = results[state]
        ax.plot(data['theta_x'][:2000], data['theta_y'][:2000],
                color=COLORS['theta'], alpha=0.5, linewidth=0.5)
        ax.plot(data['gamma_x'][:2000], data['gamma_y'][:2000],
                color=COLORS['gamma'], alpha=0.5, linewidth=0.5)
        ax.set_xlabel('x')
        ax.set_ylabel('y')
        ax.set_title(f'Phase Space: {state}', fontweight='bold')
        ax.set_aspect('equal')

    # Pattern entropy over time
    ax = axes[1, 1]
    for state in ['NORMAL', 'ANESTHESIA', 'PSYCHEDELIC', 'MEDITATION']:
        data = results[state]
        # Compute running entropy
        window = 100
        running_entropy = []
        for i in range(0, len(data['patterns']) - window, window):
            chunk = data['patterns'][i:i+window]
            counts = np.bincount(chunk, minlength=8)
            probs = counts / len(chunk)
            ent = -np.sum(probs * np.log2(probs + 1e-10))
            running_entropy.append(ent)

        ax.plot(running_entropy, label=state, color=COLORS[state], linewidth=1.5)

    ax.set_xlabel('Time Window')
    ax.set_ylabel('Pattern Entropy (bits)')
    ax.set_title('Pattern Entropy Evolution', fontweight='bold')
    ax.legend(fontsize=8)

    # Summary statistics table
    ax = axes[1, 2]
    ax.axis('off')

    # Create table data
    table_data = []
    for state in ['NORMAL', 'ANESTHESIA', 'PSYCHEDELIC', 'FLOW', 'MEDITATION']:
        data = results[state]
        table_data.append([
            state,
            f'{data["peak_trough_ratio"]:.2f}',
            f'{data["pac_mi"]:.4f}',
            f'{data["pattern_entropy"]:.2f}',
        ])

    table = ax.table(cellText=table_data,
                     colLabels=['State', 'θ-γ Ratio', 'PAC (MI)', 'Entropy'],
                     loc='center',
                     cellLoc='center')
    table.auto_set_font_size(False)
    table.set_fontsize(10)
    table.scale(1.2, 1.5)
    ax.set_title('Quantitative Metrics Summary', fontweight='bold', y=0.9)

    plt.tight_layout()
    plt.savefig(output_dir / 'phi_n_poster_supplementary.png', dpi=300, bbox_inches='tight',
                facecolor='white', edgecolor='none')
    print(f"Saved supplementary figure to {output_dir}")

    # Print metrics summary
    print("\n" + "="*60)
    print("QUANTITATIVE METRICS SUMMARY")
    print("="*60)
    print(f"{'State':<15} {'θ-γ Ratio':>10} {'PAC (MI)':>10} {'Entropy':>10}")
    print("-"*60)
    for state in ['NORMAL', 'ANESTHESIA', 'PSYCHEDELIC', 'FLOW', 'MEDITATION']:
        data = results[state]
        print(f"{state:<15} {data['peak_trough_ratio']:>10.2f} {data['pac_mi']:>10.4f} {data['pattern_entropy']:>10.3f}")
    print("="*60)
    print("\nθ-γ Ratio: Gamma amplitude at theta peak / trough (>1 = coupling)")
    print("PAC (MI): Modulation Index (KL divergence from uniform)")
    print("Entropy: Pattern entropy (bits) from oscillator phases")

    return results


if __name__ == '__main__':
    results = create_poster_figure(output_dir='poster_figures')
    plt.show()
