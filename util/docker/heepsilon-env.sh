#!/bin/bash
# HEEPsilon environment setup - loaded automatically in Docker container

# Activate conda if not already active
if [ -z "$CONDA_DEFAULT_ENV" ] || [ "$CONDA_DEFAULT_ENV" = "base" ]; then
    source /opt/conda/etc/profile.d/conda.sh
    conda activate core-v-mini-mcu
fi

# Add tools to PATH
export PATH="${TOOL_PATH}:${PATH}"

# HEEPsilon-specific aliases
alias mcu-gen='make mcu-gen'
alias verilator-sim='make verilator-sim'
alias run-hello='make verilator-run-app PROJECT=hello_world'
alias run-kernel-test='make verilator-run-app PROJECT=kernel_test'

# Welcome message (only show once per session)
if [ -z "$HEEPSILON_WELCOME_SHOWN" ]; then
    export HEEPSILON_WELCOME_SHOWN=1
    echo ""
    echo " █████   █████ ██████████ ██████████ ███████████           ███  ████                     "
    echo "░░███   ░░███ ░░███░░░░░█░░███░░░░░█░░███░░░░░███         ░░░  ░░███                     "
    echo " ░███    ░███  ░███  █ ░  ░███  █ ░  ░███    ░███  █████  ████  ░███   ██████  ████████  "
    echo " ░███████████  ░██████    ░██████    ░██████████  ███░░  ░░███  ░███  ███░░███░░███░░███ "
    echo " ░███░░░░░███  ░███░░█    ░███░░█    ░███░░░░░░  ░░█████  ░███  ░███ ░███ ░███ ░███ ░███ "
    echo " ░███    ░███  ░███ ░   █ ░███ ░   █ ░███         ░░░░███ ░███  ░███ ░███ ░███ ░███ ░███ "
    echo " █████   █████ ██████████ ██████████ █████        ██████  █████ █████░░██████  ████ █████"
    echo "░░░░░   ░░░░░ ░░░░░░░░░░ ░░░░░░░░░░ ░░░░░        ░░░░░░  ░░░░░ ░░░░░  ░░░░░░  ░░░░ ░░░░░ "
    echo ""
    echo "  X-HEEP + CGRA Coarse-Grained Reconfigurable Array Extension"
    echo ""
    echo "  Quick commands:"
    echo "    mcu-gen          - Generate MCU configuration"
    echo "    verilator-sim    - Build Verilator simulator"
    echo "    run-hello        - Run hello_world test"
    echo "    run-kernel-test  - Run CGRA kernel test"
    echo ""
    echo "  First time setup: make mcu-gen && make verilator-sim"
    echo ""
fi
