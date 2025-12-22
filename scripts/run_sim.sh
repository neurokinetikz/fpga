#!/bin/bash
# Quick simulation script using Icarus Verilog
# Usage: ./run_sim.sh [fast|full|hopf|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FPGA_DIR="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$FPGA_DIR/src"
TB_DIR="$FPGA_DIR/tb"
SIM_DIR="$FPGA_DIR/sim"

# Create sim directory if it doesn't exist
mkdir -p "$SIM_DIR"

# Check for iverilog
if ! command -v iverilog &> /dev/null; then
    echo "ERROR: Icarus Verilog (iverilog) not found!"
    echo "Install with: brew install icarus-verilog"
    exit 1
fi

run_fast() {
    echo "========================================"
    echo "Running Fast CA3/Theta Test"
    echo "========================================"

    iverilog -o "$SIM_DIR/tb_v55_fast.vvp" -s tb_v55_fast \
        "$SRC_DIR/hopf_oscillator.v" \
        "$SRC_DIR/ca3_phase_memory.v" \
        "$TB_DIR/tb_v55_fast.v"

    cd "$SIM_DIR" && vvp tb_v55_fast.vvp
    echo ""
    echo "Waveform saved to: $SIM_DIR/tb_v55_fast.vcd"
}

run_full() {
    echo "========================================"
    echo "Running Full System Test (Fast)"
    echo "========================================"

    iverilog -o "$SIM_DIR/tb_full_system_fast.vvp" -s tb_full_system_fast \
        "$SRC_DIR/hopf_oscillator.v" \
        "$SRC_DIR/ca3_phase_memory.v" \
        "$SRC_DIR/thalamus.v" \
        "$SRC_DIR/cortical_column.v" \
        "$SRC_DIR/config_controller.v" \
        "$SRC_DIR/pink_noise_generator.v" \
        "$SRC_DIR/output_mixer.v" \
        "$TB_DIR/tb_full_system_fast.v"

    cd "$SIM_DIR" && vvp tb_full_system_fast.vvp
    echo ""
    echo "Waveform saved to: $SIM_DIR/tb_full_system_fast.vcd"
}

run_hopf() {
    echo "========================================"
    echo "Running Hopf Oscillator Unit Test"
    echo "========================================"

    iverilog -o "$SIM_DIR/tb_hopf_oscillator.vvp" -s tb_hopf_oscillator \
        "$SRC_DIR/hopf_oscillator.v" \
        "$TB_DIR/tb_hopf_oscillator.v"

    cd "$SIM_DIR" && vvp tb_hopf_oscillator.vvp
    echo ""
    echo "Waveform saved to: $SIM_DIR/tb_hopf_oscillator.vcd"
}

case "${1:-all}" in
    fast)
        run_fast
        ;;
    full)
        run_full
        ;;
    hopf)
        run_hopf
        ;;
    all)
        run_hopf
        echo ""
        run_fast
        echo ""
        run_full
        ;;
    *)
        echo "Usage: $0 [fast|full|hopf|all]"
        echo ""
        echo "  fast - Run fast CA3/theta phase encoding test"
        echo "  full - Run full system test"
        echo "  hopf - Run Hopf oscillator unit test"
        echo "  all  - Run all tests (default)"
        exit 1
        ;;
esac

echo ""
echo "========================================"
echo "Simulation Complete"
echo "========================================"
