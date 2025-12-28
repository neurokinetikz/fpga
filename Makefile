# Makefile for Phi-N Neural Processor v9.5
# Supports both Icarus Verilog (iverilog) and Vivado simulations

# Directories
SRC_DIR := src
TB_DIR := tb
SIM_DIR := sim
SCRIPTS_DIR := scripts

# Source files
SRCS := $(wildcard $(SRC_DIR)/*.v)
TBS := $(wildcard $(TB_DIR)/*.v)

# Common source files for full system tests (v9.5)
COMMON_SRCS := \
	$(SRC_DIR)/clock_enable_generator.v \
	$(SRC_DIR)/hopf_oscillator.v \
	$(SRC_DIR)/hopf_oscillator_stochastic.v \
	$(SRC_DIR)/ca3_phase_memory.v \
	$(SRC_DIR)/thalamus.v \
	$(SRC_DIR)/cortical_column.v \
	$(SRC_DIR)/config_controller.v \
	$(SRC_DIR)/pink_noise_generator.v \
	$(SRC_DIR)/output_mixer.v \
	$(SRC_DIR)/phi_n_neural_processor.v \
	$(SRC_DIR)/sr_harmonic_bank.v \
	$(SRC_DIR)/sr_noise_generator.v \
	$(SRC_DIR)/sr_frequency_drift.v \
	$(SRC_DIR)/layer1_minimal.v \
	$(SRC_DIR)/pv_interneuron.v \
	$(SRC_DIR)/dendritic_compartment.v

# Default target
.PHONY: all
all: help

# Help
.PHONY: help
help:
	@echo "========================================"
	@echo "Phi-N Neural Processor v9.5 - Build System"
	@echo "========================================"
	@echo ""
	@echo "Icarus Verilog targets:"
	@echo "  make iverilog-fast       - Run fast CA3/theta test"
	@echo "  make iverilog-full       - Run full system test (15 tests)"
	@echo "  make iverilog-hopf       - Run Hopf oscillator unit test"
	@echo "  make iverilog-learning   - Run CA3 learning test (8 tests)"
	@echo ""
	@echo "  v8.0+ tests:"
	@echo "  make iverilog-theta      - Theta phase multiplexing (19 tests)"
	@echo "  make iverilog-scaffold   - Scaffold architecture (14 tests)"
	@echo "  make iverilog-gamma      - Gamma-theta nesting (7 tests)"
	@echo "  make iverilog-sr-drift   - SR frequency drift (30 tests)"
	@echo "  make iverilog-canonical  - Canonical microcircuit (20 tests)"
	@echo "  make iverilog-multi-sr   - Multi-harmonic SR (17 tests)"
	@echo "  make iverilog-sr-couple  - SR coupling (12 tests)"
	@echo ""
	@echo "  v8.7+ tests:"
	@echo "  make iverilog-layer1     - Layer 1 minimal (10 tests)"
	@echo "  make iverilog-l6         - L6 connectivity (10 tests)"
	@echo ""
	@echo "  Data export:"
	@echo "  make iverilog-eeg        - Export all oscillators for EEG comparison"
	@echo ""
	@echo "  make iverilog-all        - Run all tests (~168 tests)"
	@echo ""
	@echo "Vivado targets:"
	@echo "  make vivado-sim          - Run behavioral simulation"
	@echo "  make vivado-synth        - Run synthesis"
	@echo ""
	@echo "Utility targets:"
	@echo "  make clean               - Remove generated files"
	@echo "  make wave-fast           - Open fast test waveform"
	@echo "  make wave-full           - Open full system waveform"
	@echo ""

# ============================================================================
# Icarus Verilog Targets
# ============================================================================

# Fast CA3 test
.PHONY: iverilog-fast
iverilog-fast: $(SIM_DIR)/tb_v55_fast.vvp
	@echo "Running fast CA3/theta test..."
	cd $(SIM_DIR) && vvp tb_v55_fast.vvp
	@echo "Waveform saved to $(SIM_DIR)/tb_v55_fast.vcd"

$(SIM_DIR)/tb_v55_fast.vvp: $(SRCS) $(TB_DIR)/tb_v55_fast.v
	@mkdir -p $(SIM_DIR)
	iverilog -o $@ -s tb_v55_fast \
		$(SRC_DIR)/hopf_oscillator.v \
		$(SRC_DIR)/ca3_phase_memory.v \
		$(TB_DIR)/tb_v55_fast.v

# Full system test
.PHONY: iverilog-full
iverilog-full: $(SIM_DIR)/tb_full_system_fast.vvp
	@echo "Running full system test..."
	cd $(SIM_DIR) && vvp tb_full_system_fast.vvp

$(SIM_DIR)/tb_full_system_fast.vvp: $(SRCS) $(TB_DIR)/tb_full_system_fast.v
	@mkdir -p $(SIM_DIR)
	iverilog -o $@ -s tb_full_system_fast \
		$(COMMON_SRCS) \
		$(TB_DIR)/tb_full_system_fast.v

# Hopf oscillator unit test
.PHONY: iverilog-hopf
iverilog-hopf: $(SIM_DIR)/tb_hopf_oscillator.vvp
	@echo "Running Hopf oscillator test..."
	cd $(SIM_DIR) && vvp tb_hopf_oscillator.vvp
	@echo "Waveform saved to $(SIM_DIR)/tb_hopf_oscillator.vcd"

$(SIM_DIR)/tb_hopf_oscillator.vvp: $(SRC_DIR)/hopf_oscillator.v $(TB_DIR)/tb_hopf_oscillator.v
	@mkdir -p $(SIM_DIR)
	iverilog -o $@ -s tb_hopf_oscillator \
		$(SRC_DIR)/hopf_oscillator.v \
		$(TB_DIR)/tb_hopf_oscillator.v

# CA3 Learning test
.PHONY: iverilog-learning
iverilog-learning: $(SIM_DIR)/tb_learning_fast.vvp
	@echo "Running CA3 learning test..."
	cd $(SIM_DIR) && vvp tb_learning_fast.vvp

$(SIM_DIR)/tb_learning_fast.vvp: $(SRCS) $(TB_DIR)/tb_learning_fast.v
	@mkdir -p $(SIM_DIR)
	iverilog -o $@ -s tb_learning_fast \
		$(COMMON_SRCS) \
		$(TB_DIR)/tb_learning_fast.v

# v8.3: Theta phase multiplexing test
.PHONY: iverilog-theta
iverilog-theta: $(SIM_DIR)/tb_theta_phase_multiplexing.vvp
	@echo "Running theta phase multiplexing test..."
	cd $(SIM_DIR) && vvp tb_theta_phase_multiplexing.vvp

$(SIM_DIR)/tb_theta_phase_multiplexing.vvp: $(SRCS) $(TB_DIR)/tb_theta_phase_multiplexing.v
	@mkdir -p $(SIM_DIR)
	iverilog -o $@ -s tb_theta_phase_multiplexing \
		$(COMMON_SRCS) \
		$(TB_DIR)/tb_theta_phase_multiplexing.v

# v8.0: Scaffold architecture test
.PHONY: iverilog-scaffold
iverilog-scaffold: $(SIM_DIR)/tb_scaffold_architecture.vvp
	@echo "Running scaffold architecture test..."
	cd $(SIM_DIR) && vvp tb_scaffold_architecture.vvp

$(SIM_DIR)/tb_scaffold_architecture.vvp: $(SRCS) $(TB_DIR)/tb_scaffold_architecture.v
	@mkdir -p $(SIM_DIR)
	iverilog -o $@ -s tb_scaffold_architecture \
		$(COMMON_SRCS) \
		$(TB_DIR)/tb_scaffold_architecture.v

# v8.4: Gamma-theta nesting test
.PHONY: iverilog-gamma
iverilog-gamma: $(SIM_DIR)/tb_gamma_theta_nesting.vvp
	@echo "Running gamma-theta nesting test..."
	cd $(SIM_DIR) && vvp tb_gamma_theta_nesting.vvp

$(SIM_DIR)/tb_gamma_theta_nesting.vvp: $(SRCS) $(TB_DIR)/tb_gamma_theta_nesting.v
	@mkdir -p $(SIM_DIR)
	iverilog -o $@ -s tb_gamma_theta_nesting \
		$(COMMON_SRCS) \
		$(TB_DIR)/tb_gamma_theta_nesting.v

# v8.5: SR frequency drift test
.PHONY: iverilog-sr-drift
iverilog-sr-drift: $(SIM_DIR)/tb_sr_frequency_drift.vvp
	@echo "Running SR frequency drift test..."
	cd $(SIM_DIR) && vvp tb_sr_frequency_drift.vvp

$(SIM_DIR)/tb_sr_frequency_drift.vvp: $(SRCS) $(TB_DIR)/tb_sr_frequency_drift.v
	@mkdir -p $(SIM_DIR)
	iverilog -o $@ -s tb_sr_frequency_drift \
		$(COMMON_SRCS) \
		$(TB_DIR)/tb_sr_frequency_drift.v

# v8.6: Canonical microcircuit test
.PHONY: iverilog-canonical
iverilog-canonical: $(SIM_DIR)/tb_canonical_microcircuit.vvp
	@echo "Running canonical microcircuit test..."
	cd $(SIM_DIR) && vvp tb_canonical_microcircuit.vvp

$(SIM_DIR)/tb_canonical_microcircuit.vvp: $(SRCS) $(TB_DIR)/tb_canonical_microcircuit.v
	@mkdir -p $(SIM_DIR)
	iverilog -o $@ -s tb_canonical_microcircuit \
		$(COMMON_SRCS) \
		$(TB_DIR)/tb_canonical_microcircuit.v

# Multi-harmonic SR test
.PHONY: iverilog-multi-sr
iverilog-multi-sr: $(SIM_DIR)/tb_multi_harmonic_sr.vvp
	@echo "Running multi-harmonic SR test..."
	cd $(SIM_DIR) && vvp tb_multi_harmonic_sr.vvp

$(SIM_DIR)/tb_multi_harmonic_sr.vvp: $(SRCS) $(TB_DIR)/tb_multi_harmonic_sr.v
	@mkdir -p $(SIM_DIR)
	iverilog -o $@ -s tb_multi_harmonic_sr \
		$(COMMON_SRCS) \
		$(TB_DIR)/tb_multi_harmonic_sr.v

# SR coupling test
.PHONY: iverilog-sr-couple
iverilog-sr-couple: $(SIM_DIR)/tb_sr_coupling.vvp
	@echo "Running SR coupling test..."
	cd $(SIM_DIR) && vvp tb_sr_coupling.vvp

$(SIM_DIR)/tb_sr_coupling.vvp: $(SRCS) $(TB_DIR)/tb_sr_coupling.v
	@mkdir -p $(SIM_DIR)
	iverilog -o $@ -s tb_sr_coupling \
		$(COMMON_SRCS) \
		$(TB_DIR)/tb_sr_coupling.v

# v8.7: Layer 1 minimal test
.PHONY: iverilog-layer1
iverilog-layer1: $(SIM_DIR)/tb_layer1_minimal.vvp
	@echo "Running Layer 1 minimal test..."
	cd $(SIM_DIR) && vvp tb_layer1_minimal.vvp

$(SIM_DIR)/tb_layer1_minimal.vvp: $(SRCS) $(TB_DIR)/tb_layer1_minimal.v
	@mkdir -p $(SIM_DIR)
	iverilog -o $@ -s tb_layer1_minimal \
		$(COMMON_SRCS) \
		$(TB_DIR)/tb_layer1_minimal.v

# v8.8: L6 connectivity test
.PHONY: iverilog-l6
iverilog-l6: $(SIM_DIR)/tb_l6_connectivity.vvp
	@echo "Running L6 connectivity test..."
	cd $(SIM_DIR) && vvp tb_l6_connectivity.vvp

$(SIM_DIR)/tb_l6_connectivity.vvp: $(SRCS) $(TB_DIR)/tb_l6_connectivity.v
	@mkdir -p $(SIM_DIR)
	iverilog -o $@ -s tb_l6_connectivity \
		$(COMMON_SRCS) \
		$(TB_DIR)/tb_l6_connectivity.v

# EEG Export: Generate oscillator data for spectral/PAC analysis
.PHONY: iverilog-eeg
iverilog-eeg: $(SIM_DIR)/tb_eeg_export.vvp
	@echo "Running EEG export (60 seconds of oscillator data)..."
	@echo "This may take a few minutes..."
	cd $(SIM_DIR) && vvp tb_eeg_export.vvp
	@echo ""
	@echo "Analyze with: python3 scripts/analyze_eeg_comparison.py $(SIM_DIR)/oscillator_eeg_export.csv"

$(SIM_DIR)/tb_eeg_export.vvp: $(SRCS) $(TB_DIR)/tb_eeg_export.v
	@mkdir -p $(SIM_DIR)
	iverilog -o $@ -s tb_eeg_export \
		$(COMMON_SRCS) \
		$(TB_DIR)/tb_eeg_export.v

# Run all iverilog tests
.PHONY: iverilog-all
iverilog-all: iverilog-hopf iverilog-fast iverilog-full iverilog-learning \
              iverilog-theta iverilog-scaffold iverilog-gamma iverilog-sr-drift \
              iverilog-canonical iverilog-multi-sr iverilog-sr-couple \
              iverilog-layer1 iverilog-l6
	@echo "========================================"
	@echo "All Icarus Verilog tests complete"
	@echo "========================================"

# ============================================================================
# Vivado Targets
# ============================================================================

.PHONY: vivado-sim
vivado-sim:
	@echo "Running Vivado behavioral simulation..."
	cd $(SCRIPTS_DIR) && vivado -mode batch -source run_vivado_sim.tcl

.PHONY: vivado-synth
vivado-synth:
	@echo "Running Vivado synthesis..."
	cd $(SCRIPTS_DIR) && vivado -mode batch -source run_vivado_synth.tcl

# ============================================================================
# Waveform Viewers
# ============================================================================

.PHONY: wave-fast
wave-fast:
	@if command -v gtkwave >/dev/null 2>&1; then \
		gtkwave $(SIM_DIR)/tb_v55_fast.vcd &; \
	else \
		echo "GTKWave not found. Install with: brew install gtkwave"; \
	fi

.PHONY: wave-full
wave-full:
	@if command -v gtkwave >/dev/null 2>&1; then \
		gtkwave $(SIM_DIR)/tb_full_system.vcd &; \
	else \
		echo "GTKWave not found. Install with: brew install gtkwave"; \
	fi

.PHONY: wave-hopf
wave-hopf:
	@if command -v gtkwave >/dev/null 2>&1; then \
		gtkwave $(SIM_DIR)/tb_hopf_oscillator.vcd &; \
	else \
		echo "GTKWave not found. Install with: brew install gtkwave"; \
	fi

# ============================================================================
# Clean
# ============================================================================

.PHONY: clean
clean:
	rm -rf $(SIM_DIR)/*.vvp $(SIM_DIR)/*.vcd
	rm -rf $(SCRIPTS_DIR)/vivado_project
	rm -rf $(SCRIPTS_DIR)/*.jou $(SCRIPTS_DIR)/*.log
	rm -rf .Xil
	@echo "Cleaned generated files"

.PHONY: clean-all
clean-all: clean
	rm -rf $(SIM_DIR)
	@echo "Cleaned all simulation files"
