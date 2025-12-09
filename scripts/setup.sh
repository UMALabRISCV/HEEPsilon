#!/bin/bash
# Copyright 2025 University of Málaga (UMA) - Departamento de Arquitectura de Computadores
# SPDX-License-Identifier: Apache-2.0
#
# HEEPsilon Setup Script
# Installs all dependencies for development without Docker
# Supports: Linux (Debian/Ubuntu) and macOS
#
# Tested on:
#   - macOS Tahoe 26.1 (25B78) on Apple Silicon (arm64)
#   - Ubuntu 22.04+ on x86_64
#
# Author: Cristian Campos (UMA-DAC)
# Date: 2025
#
# Usage: ./scripts/setup.sh [--all|--deps|--verilator|--toolchain|--python]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Versions (matching x-heep Docker)
VERILATOR_VERSION="5.040"
VERIBLE_VERSION="v0.0-4023-gc1271a00"

# Determine script and project directories (before any cd commands)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Installation directories
TOOLS_DIR="${HOME}/tools"
RISCV_DIR="${TOOLS_DIR}/riscv"
VERILATOR_DIR="${TOOLS_DIR}/verilator/${VERILATOR_VERSION}"
VERIBLE_DIR="${TOOLS_DIR}/verible/${VERIBLE_VERSION}"

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        if [[ "$(uname -m)" == "arm64" ]]; then
            ARCH="arm64"
        else
            ARCH="x86_64"
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        ARCH="$(uname -m)"
    else
        echo "Unsupported operating system: $OSTYPE"
        exit 1
    fi
}

print_banner() {
    echo ""
    echo -e "${CYAN} █████   █████ ██████████ ██████████ ███████████           ███  ████${NC}                     "
    echo -e "${CYAN}░░███   ░░███ ░░███░░░░░█░░███░░░░░█░░███░░░░░███         ░░░  ░░███${NC}                     "
    echo -e "${CYAN} ░███    ░███  ░███  █ ░  ░███  █ ░  ░███    ░███  █████  ████  ░███   ██████  ████████${NC}  "
    echo -e "${CYAN} ░███████████  ░██████    ░██████    ░██████████  ███░░  ░░███  ░███  ███░░███░░███░░███${NC} "
    echo -e "${CYAN} ░███░░░░░███  ░███░░█    ░███░░█    ░███░░░░░░  ░░█████  ░███  ░███ ░███ ░███ ░███ ░███${NC} "
    echo -e "${CYAN} ░███    ░███  ░███ ░   █ ░███ ░   █ ░███         ░░░░███ ░███  ░███ ░███ ░███ ░███ ░███${NC} "
    echo -e "${CYAN} █████   █████ ██████████ ██████████ █████        ██████  █████ █████░░██████  ████ █████${NC}"
    echo -e "${CYAN}░░░░░   ░░░░░ ░░░░░░░░░░ ░░░░░░░░░░ ░░░░░        ░░░░░░  ░░░░░ ░░░░░  ░░░░░░  ░░░░ ░░░░░${NC} "
    echo ""
    echo -e "  ${GREEN}X-HEEP + CGRA Coarse-Grained Reconfigurable Array Extension${NC}"
    echo ""
    echo -e "  ${YELLOW}University of Málaga (UMA) - Departamento de Arquitectura de Computadores${NC}"
    echo -e "  ${YELLOW}Based on EPFL's X-HEEP and OpenEdgeCGRA${NC}"
    echo -e "  ${YELLOW}Detected: ${OS} (${ARCH})${NC}"
    echo ""
}

print_header() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  $1${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_step() {
    echo -e "${YELLOW}[*]${NC} $1"
}

print_done() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if running as root (Linux only)
check_sudo() {
    if [ "$OS" == "linux" ]; then
        if [ "$EUID" -eq 0 ]; then
            SUDO=""
        else
            SUDO="sudo"
        fi
    else
        SUDO=""  # macOS uses brew without sudo
    fi
}

# Check Homebrew installation (macOS)
check_homebrew() {
    if ! command -v brew &> /dev/null; then
        print_error "Homebrew is not installed."
        echo ""
        echo "Install Homebrew first:"
        echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        exit 1
    fi
}

install_system_deps_linux() {
    if ! command -v apt-get &> /dev/null; then
        print_error "apt-get not found. This script only supports Debian/Ubuntu."
        echo "For other distributions, please install dependencies manually."
        exit 1
    fi
    
    print_step "Updating package lists..."
    $SUDO apt-get update
    
    print_step "Installing required packages..."
    $SUDO apt-get install -y --no-install-recommends \
        autoconf automake autotools-dev curl python3 python3-pip python3-venv python3-dev \
        libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex \
        texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev ninja-build \
        git cmake libglib2.0-dev libslirp-dev help2man perl make g++ \
        ccache mold libgoogle-perftools-dev numactl libelf-dev wget libyaml-dev
    
    # Workaround for Python 3.13+ ruamel.yaml compilation issue
    PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    PYTHON_INCLUDE="/usr/include/python${PYTHON_VERSION}"
    if [ -f "${PYTHON_INCLUDE}/cpython/longintrepr.h" ] && [ ! -f "${PYTHON_INCLUDE}/longintrepr.h" ]; then
        print_step "Applying Python ${PYTHON_VERSION} header workaround..."
        $SUDO ln -sf "${PYTHON_INCLUDE}/cpython/longintrepr.h" "${PYTHON_INCLUDE}/longintrepr.h"
    fi
}

install_system_deps_macos() {
    check_homebrew
    
    print_step "Installing packages via Homebrew..."
    brew install \
        autoconf automake libtool python@3 gmp mpfr libmpc \
        bison flex gawk texinfo wget cmake ninja \
        ccache zlib expat libelf help2man coreutils

    print_step "Configuring Python..."
    if ! command -v python3 &> /dev/null; then
        echo "Please ensure Python 3 from Homebrew is in your PATH"
    fi
}

install_system_deps() {
    print_header "Installing System Dependencies"
    
    if [ "$OS" == "linux" ]; then
        install_system_deps_linux
    elif [ "$OS" == "macos" ]; then
        install_system_deps_macos
    fi
    
    print_done "System dependencies installed"
}

install_verilator() {
    print_header "Installing Verilator"
    
    if [ "$OS" == "macos" ]; then
        # macOS: Use Homebrew (compiling from source fails with newer clang)
        if command -v verilator &> /dev/null; then
            INSTALLED_VER=$(verilator --version | head -1 | awk '{print $2}')
            print_done "Verilator ${INSTALLED_VER} already installed via Homebrew"
            return
        fi
        
        print_step "Installing Verilator via Homebrew..."
        brew install verilator
        
        INSTALLED_VER=$(verilator --version | head -1 | awk '{print $2}')
        print_done "Verilator ${INSTALLED_VER} installed via Homebrew"
    else
        # Linux: Compile from source for specific version
        if [ -f "${VERILATOR_DIR}/bin/verilator" ]; then
            print_done "Verilator already installed at ${VERILATOR_DIR}"
            return
        fi
        
        local ORIG_DIR=$(pwd)
        
        print_step "Cloning Verilator repository..."
        rm -rf /tmp/verilator
        git clone https://github.com/verilator/verilator.git /tmp/verilator
        cd /tmp/verilator
        git checkout v${VERILATOR_VERSION}
        
        print_step "Building Verilator ${VERILATOR_VERSION} (this may take a while)..."
        autoconf
        ./configure --prefix=${VERILATOR_DIR}
        make -j$(nproc)
        make install
        
        print_step "Cleaning up..."
        cd "$ORIG_DIR"
        rm -rf /tmp/verilator
        
        print_done "Verilator installed to ${VERILATOR_DIR}"
    fi
}

install_verible() {
    print_header "Installing Verible ${VERIBLE_VERSION}"
    
    if [ -f "${VERIBLE_DIR}/bin/verible-verilog-format" ]; then
        print_done "Verible already installed at ${VERIBLE_DIR}"
        return
    fi
    
    print_step "Downloading Verible..."
    
    if [ "$OS" == "macos" ]; then
        VERIBLE_URL="https://github.com/chipsalliance/verible/releases/download/${VERIBLE_VERSION}/verible-${VERIBLE_VERSION}-macOS.tar.gz"
    else
        VERIBLE_URL="https://github.com/chipsalliance/verible/releases/download/${VERIBLE_VERSION}/verible-${VERIBLE_VERSION}-linux-static-x86_64.tar.gz"
    fi
    
    wget -q "$VERIBLE_URL" -O /tmp/verible.tar.gz
    
    print_step "Extracting..."
    mkdir -p ${TOOLS_DIR}/verible
    tar -xf /tmp/verible.tar.gz -C ${TOOLS_DIR}/verible/
    mv ${TOOLS_DIR}/verible/verible-${VERIBLE_VERSION}* ${VERIBLE_DIR}
    rm /tmp/verible.tar.gz
    
    print_done "Verible installed to ${VERIBLE_DIR}"
}

install_riscv_toolchain() {
    print_header "Installing RISC-V CORE-V Toolchain"
    
    if [ -f "${RISCV_DIR}/bin/riscv32-corev-elf-gcc" ]; then
        print_done "CORE-V toolchain already installed at ${RISCV_DIR}"
        return
    fi
    
    mkdir -p ${RISCV_DIR}
    
    if [ "$OS" == "macos" ]; then
        # macOS uses DMG format
        if [ "$ARCH" == "arm64" ]; then
            TOOLCHAIN_URL="https://buildbot.embecosm.com/job/corev-gcc-macos-arm64/8/artifact/corev-openhw-gcc-macos-20240530.dmg"
            print_step "Downloading ARM64 toolchain..."
        else
            TOOLCHAIN_URL="https://buildbot.embecosm.com/job/corev-gcc-macos/48/artifact/corev-openhw-gcc-macos-20240530.dmg"
            print_step "Downloading Intel toolchain..."
        fi
        
        wget -q "$TOOLCHAIN_URL" -O /tmp/corev-toolchain.dmg
        
        print_step "Mounting DMG..."
        hdiutil attach /tmp/corev-toolchain.dmg -mountpoint /tmp/corev-mount -nobrowse -quiet
        
        print_step "Extracting toolchain..."
        cp -R /tmp/corev-mount/corev-openhw-gcc-macos*/* ${RISCV_DIR}/
        
        print_step "Unmounting DMG..."
        hdiutil detach /tmp/corev-mount -quiet
        rm /tmp/corev-toolchain.dmg
    else
        # Linux (Ubuntu/Debian)
        TOOLCHAIN_URL="https://buildbot.embecosm.com/job/corev-gcc-ubuntu2204/47/artifact/corev-openhw-gcc-ubuntu2204-20240530.tar.gz"
        
        print_step "Downloading CORE-V GCC toolchain..."
        wget -qO- "$TOOLCHAIN_URL" | tar -xz -C ${RISCV_DIR} --strip-components=1
    fi
    
    print_done "CORE-V toolchain installed to ${RISCV_DIR}"
}

install_python_deps() {
    print_header "Setting up Python Environment"
    
    cd "$PROJECT_DIR"
    
    if [ -d ".venv" ]; then
        print_done "Python venv already exists"
    else
        print_step "Creating Python virtual environment..."
        python3 -m venv .venv
    fi
    
    print_step "Activating venv and installing dependencies..."
    source .venv/bin/activate
    pip install --upgrade pip setuptools
    
    # Python 3.10+ workaround: force binary wheels for ruamel.yaml
    PYTHON_MINOR=$(python3 -c 'import sys; print(sys.version_info.minor)')
    if [ "$PYTHON_MINOR" -ge 10 ]; then
        print_step "Python 3.10+ detected - configuring pip for compatibility..."
        export PIP_ONLY_BINARY="ruamel.yaml,ruamel.yaml.clib"
        # Pre-install a newer version of ruamel.yaml that supports Python 3.10+
        # This helps avoid building the old incompatible 0.15.100 version
        pip install "ruamel.yaml>=0.17.21" || true
    fi
    
    # CMake 4.x workaround: pylibfst has outdated CMakeLists.txt
    export CMAKE_POLICY_VERSION_MINIMUM=3.5
    
    pip install -r hw/vendor/esl_epfl_x_heep/util/python-requirements.txt
    
    print_done "Python dependencies installed"
}

init_submodules() {
    print_header "Initializing Git Submodules"
    
    cd "$PROJECT_DIR"
    
    print_step "Updating submodules..."
    git submodule update --init --recursive
    
    print_done "Submodules initialized"
}

print_env_setup() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Setup Complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Detect shell config file
    if [ -n "$ZSH_VERSION" ] || [ -f "${HOME}/.zshrc" ]; then
        SHELL_RC="${HOME}/.zshrc"
        SHELL_RC_SHORT="~/.zshrc"
    else
        SHELL_RC="${HOME}/.bashrc"
        SHELL_RC_SHORT="~/.bashrc"
    fi
    
    if [ "$OS" == "macos" ]; then
        # macOS: Verilator is in Homebrew path, need libelf flags and GNU coreutils
        LIBELF_PREFIX=$(brew --prefix libelf)
        COREUTILS_PREFIX=$(brew --prefix coreutils)
        ENV_CONFIG="
# HEEPsilon Development Environment (added by setup.sh)
export RISCV_XHEEP=${RISCV_DIR}
export PATH=${COREUTILS_PREFIX}/libexec/gnubin:${VERIBLE_DIR}/bin:\${RISCV_XHEEP}/bin:\$PATH

# libelf for Verilator simulation linking
export LDFLAGS=\"-L${LIBELF_PREFIX}/lib \$LDFLAGS\"
export CPPFLAGS=\"-I${LIBELF_PREFIX}/include \$CPPFLAGS\""
    else
        ENV_CONFIG="
# HEEPsilon Development Environment (added by setup.sh)
export RISCV_XHEEP=${RISCV_DIR}
export PATH=${VERILATOR_DIR}/bin:${VERIBLE_DIR}/bin:\${RISCV_XHEEP}/bin:\$PATH"
    fi

    # Check if already configured
    if grep -q "RISCV_XHEEP" "$SHELL_RC" 2>/dev/null; then
        print_done "Environment already configured in ${SHELL_RC_SHORT}"
    else
        echo -e -n "${YELLOW}  Add environment variables to ${SHELL_RC_SHORT}? [Y/n]: ${NC}"
        read -r response
        
        if [ -z "$response" ] || [ "$response" = "y" ] || [ "$response" = "Y" ]; then
            echo "$ENV_CONFIG" >> "$SHELL_RC"
            print_done "Environment added to ${SHELL_RC_SHORT}"
        else
            echo ""
            echo -e "${YELLOW}  Add these lines manually to your shell config:${NC}"
            echo -e "${CYAN}${ENV_CONFIG}${NC}"
        fi
    fi
    
    echo ""
    echo -e "${YELLOW}  Quick start:${NC}"
    echo -e "    ${CYAN}source ${SHELL_RC_SHORT}${NC}"
    echo -e "    ${CYAN}cd ${PROJECT_DIR}${NC}"
    echo -e "    ${CYAN}source .venv/bin/activate${NC}"
    echo -e "    ${CYAN}make mcu-gen && make verilator-sim${NC}"
    echo ""
}

show_help() {
    echo "HEEPsilon Setup Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Supports: Linux (Debian/Ubuntu) and macOS"
    echo ""
    echo "Options:"
    echo "  --all         Install everything (default)"
    echo "  --deps        Install system dependencies only"
    echo "  --verilator   Install Verilator only"
    echo "  --verible     Install Verible only"
    echo "  --toolchain   Install RISC-V toolchain only"
    echo "  --python      Setup Python environment only"
    echo "  --submodules  Initialize git submodules only"
    echo "  --help        Show this help message"
}

# Main
detect_os
check_sudo

case "${1:-}" in
    --deps)
        install_system_deps
        ;;
    --verilator)
        install_verilator
        ;;
    --verible)
        install_verible
        ;;
    --toolchain)
        install_riscv_toolchain
        ;;
    --python)
        install_python_deps
        ;;
    --submodules)
        init_submodules
        ;;
    --help|-h)
        show_help
        exit 0
        ;;
    --all|"")
        print_banner
        install_system_deps
        install_verilator
        install_verible
        install_riscv_toolchain
        init_submodules
        install_python_deps
        print_env_setup
        ;;
    *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
esac