# Makefile for Phi-N Neural Processor v5.5
# Supports both Icarus Verilog (iverilog) and Vivado simulations

# Directories
SRC_DIR := src
TB_DIR := tb
SIM_DIR := sim
SCRIPTS_DIR := scripts

# Source files
SRCS := $(wildcard $(SRC_DIR)/*.v)
TBS := $(wildcard $(TB_DIR)/*.v)

# Default target
.PHONY: all
all: help

# Help
.PHONY: help
help:
	@echo "========================================"
	@echo "Phi-N Neural Processor v5.5 - Build System"
	@echo "========================================"
	@echo ""
	@echo "Icarus Verilog targets:"
	@echo "  make iverilog-fast    - Run fast CA3/theta test"
	@echo "  make iverilog-full    - Run full system test"
	@echo "  make iverilog-hopf    - Run Hopf oscillator unit test"
	@echo "  make iverilog-all     - Run all tests"
	@echo ""
	@echo "Vivado targets:"
	@echo "  make vivado-sim       - Run behavioral simulation"
	@echo "  make vivado-synth     - Run synthesis"
	@echo ""
	@echo "Utility targets:"
	@echo "  make clean            - Remove generated files"
	@echo "  make wave-fast        - Open fast test waveform"
	@echo "  make wave-full        - Open full system waveform"
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
iverilog-full: $(SIM_DIR)/tb_full_system.vvp
	@echo "Running full system test..."
	cd $(SIM_DIR) && vvp tb_full_system.vvp
	@echo "Waveform saved to $(SIM_DIR)/tb_full_system.vcd"

$(SIM_DIR)/tb_full_system.vvp: $(SRCS) $(TB_DIR)/tb_full_system.v
	@mkdir -p $(SIM_DIR)
	iverilog -o $@ -s tb_full_system \
		$(SRC_DIR)/clock_enable_generator.v \
		$(SRC_DIR)/hopf_oscillator.v \
		$(SRC_DIR)/ca3_phase_memory.v \
		$(SRC_DIR)/thalamus.v \
		$(SRC_DIR)/cortical_column.v \
		$(SRC_DIR)/config_controller.v \
		$(SRC_DIR)/pink_noise_generator.v \
		$(SRC_DIR)/output_mixer.v \
		$(SRC_DIR)/phi_n_neural_processor.v \
		$(TB_DIR)/tb_full_system.v

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

# Run all iverilog tests
.PHONY: iverilog-all
iverilog-all: iverilog-hopf iverilog-fast iverilog-full
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
