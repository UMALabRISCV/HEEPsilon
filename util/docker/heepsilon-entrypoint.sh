#!/bin/bash
# HEEPsilon Docker entrypoint
# Professional setup that uses conda (same as x-heep Docker)

set -e

cd /workspace/heepsilon

# Initialize conda
source /opt/conda/etc/profile.d/conda.sh
conda activate core-v-mini-mcu

# Export conda environment path for Makefile compatibility
export CONDA_DEFAULT_ENV=core-v-mini-mcu

# Get system info
CPUS=$(nproc)

# Print header
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  HEEPsilon Docker Environment"
echo "  CPUs: $CPUS | Conda: $CONDA_DEFAULT_ENV"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if submodules are initialized
if [ ! -f "hw/vendor/esl_epfl_x_heep/Makefile" ]; then
    echo ""
    echo "  [*] Initializing git submodules (first run only)..."
    git submodule update --init --recursive
fi

# Collect status messages
echo ""
echo "  Status:"

if [ ! -f "hw/rtl/ext_xbar.sv" ]; then
    echo "    [ ] MCU not generated         -> make mcu-gen"
else
    echo "    [x] MCU generated"
fi

if [ ! -f "build/eslepfl_systems_heepsilon_0/sim-verilator/Vtestharness" ]; then
    echo "    [ ] Verilator not built       -> make verilator-sim"
else
    echo "    [x] Verilator simulator ready"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Execute the command passed to docker run
exec "$@"
