<p align="center"><img src="docs/HEEPsilon_logo.png" width="500"></p>

<p align="center">
  <strong>Ultra Low Power Computing Platform with CGRA Acceleration</strong>
</p>

<p align="center">
  <a href="#getting-started">Getting Started</a> •
  <a href="#documentation">Documentation</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#contact">Contact</a>
</p>

---

## Overview

**HEEPsilon** is a versatile computing platform targeting ultra-low-power processing of biological and environmental signals. Built on top of [X-HEEP](https://github.com/esl-epfl/x-heep), it extends the platform with [OpenEdgeCGRA](https://github.com/esl-epfl/OpenEdgeCGRA) — a design-time resizable and run-time reprogrammable **Coarse Grained Reconfigurable Array (CGRA)**.

📄 **Publication**: [An Open-Hardware Coarse-Grained Reconfigurable Array for Edge Computing](https://dl.acm.org/doi/10.1145/3587135.3591437)

### Key Features

- **X-HEEP Compatible**: All X-HEEP functionalities including RTL simulation (Verilator, VCS, Questasim) and FPGA implementation
- **CGRA Acceleration**: Programmable hardware acceleration for compute-intensive tasks
- **Silicon-Proven**: Our cousin HEEPocrates was taped-out in TSMC 65nm and is running successfully
- **FPGA Ready**: Supports [PYNQ-Z2](https://www.xilinx.com/support/university/xup-boards/XUPPYNQ-Z2.html) out of the box

> [!NOTE]
> **Fork Information**: This repository is maintained by the [University of Málaga (UMA)](https://www.uma.es/) - Departamento de Arquitectura de Computadores. It includes bug fixes and updates for **X-HEEP v1.0.4** compatibility.

---

## Version Compatibility

| Component | Version | Notes |
|-----------|---------|-------|
| X-HEEP | v1.0.4 | Vendorized in `hw/vendor/esl_epfl_x_heep` |
| OpenEdgeCGRA | 4a179fc | Vendorized in `hw/vendor/esl_epfl_cgra` |
| Verilator | 5.x | Tested with v5.040 |

---

## Getting Started

Choose one of three setup methods:

| Method | Best For | Time |
|--------|----------|------|
| 🐳 **Docker** | Quick start, CI/CD, reproducibility | ~5 min |
| 📜 **Setup Script** | Native development on Ubuntu/Debian | ~20 min |
| 📖 **Manual** | Custom environments, other distros | Varies |

### Option 1: Docker (Recommended)

The fastest way to get started with a pre-configured environment:

```bash
# Clone the repository
git clone --recursive https://github.com/UMALabRISCV/HEEPsilon.git
cd HEEPsilon

# Build and run the container
make -C util/docker docker-build   # First time only (~5 min)
make -C util/docker docker-run
```

Inside the container:
```bash
make mcu-gen && make verilator-sim         # Build simulation model
make verilator-run-app PROJECT=hello_world  # Run test application
```

> See [`util/docker/README.md`](util/docker/README.md) for advanced Docker usage.

---

### Option 2: Automatic Setup Script

For native development on **Ubuntu/Debian** systems:

```bash
# Clone the repository
git clone --recursive https://github.com/UMALabRISCV/HEEPsilon.git
cd HEEPsilon

# Run the setup script
./scripts/setup.sh
```

The script automatically installs:
- ✅ System dependencies (build tools, libraries)
- ✅ Verilator 5.040
- ✅ Verible (SystemVerilog formatter/linter)
- ✅ RISC-V CORE-V GCC toolchain
- ✅ Python virtual environment with all dependencies

**Selective Installation:**
```bash
./scripts/setup.sh --deps       # System dependencies only
./scripts/setup.sh --verilator  # Verilator only
./scripts/setup.sh --toolchain  # RISC-V toolchain only
./scripts/setup.sh --python     # Python environment only
./scripts/setup.sh --help       # Show all options
```

---

### Option 3: Manual Setup

For other Linux distributions or custom setups, follow the [X-HEEP Setup Documentation](hw/vendor/esl_epfl_x_heep/docs/source/GettingStarted/Setup.md).

---

## Building and Running Simulations

### Quick Start

```bash
source .venv/bin/activate
make mcu-gen                                # Generate MCU configuration
make verilator-sim                          # Build Verilator model
make verilator-run-app PROJECT=hello_world  # Compile & run application
```

### Step-by-Step Workflow

1. **Generate MCU Configuration**
   ```bash
   make mcu-gen CPU=cv32e20 BUS=NtoM MEMORY_BANKS=8
   ```

2. **Build Simulation Model**
   ```bash
   make verilator-sim
   ```

3. **Compile Application**
   ```bash
   make app PROJECT=cgra_func_test TARGET=sim
   ```

4. **Run Simulation**
   ```bash
   make verilator-run
   ```

### Available Test Applications

| Application | Description |
|-------------|-------------|
| `hello_world` | Basic UART output test |
| `cgra_func_test` | CGRA functionality verification |
| `kernel_test` | CGRA kernel benchmarking |

### Simulation Parameters

```bash
# Set maximum simulation time
make verilator-run SIM_ARGS="+max_sim_time=100000"

# UART output is saved to uart0.log
cat uart0.log
```

---

## Clock Configuration (CPU/CGRA)

HEEPsilon runs the CPU and CGRA from the same system clock. The default frequency is **100 MHz**.

### Quick Frequency Change

Use the automated targets to change frequency:

```bash
# View current frequency configuration
make clock-show

# Change to 50 MHz (updates config and cleans build)
make set-freq FREQ=50000000

# Change frequency AND rebuild Verilator in one step
make verilator-set-freq FREQ=50000000

# Verify the frequency is correctly applied
make freq-verify
```

### Manual Configuration

For more control, you can manually edit `clock_config.mk`:

```makefile
HEEPSILON_CPU_CLK_HZ ?= 50000000
HEEPSILON_CGRA_CLK_HZ ?= $(HEEPSILON_CPU_CLK_HZ)
```

Then rebuild:
```bash
rm -rf build                    # Required: frequency is baked into RTL
make verilator-build            # Rebuild simulation model
make verilator-run-app PROJECT=freq_check  # Verify
```

### How It Works

Changing the frequency regenerates these files:
- `tb/heepsilon_clock_config.svh` — SystemVerilog defines for testbench
- `tb/heepsilon_clock_config.hh` — C++ defines for Verilator driver
- `sw/device/heepsilon_clock_config.h` — C defines for firmware (`REFERENCE_CLOCK_Hz`)

The testbench (`tb/testharness.sv`) reads `HEEPSILON_CPU_CLK_KHZ` to configure:
- Clock period for simulation timing
- UART baudrate calculation (so output remains readable at any frequency)

> **Important**: Changing frequency requires a **full rebuild** (`rm -rf build`) because values are elaborated into the RTL at compile time.

### Verified Frequencies

| Frequency | Status | Notes |
|-----------|--------|-------|
| 50 MHz | ✅ Tested | CGRA kernels work correctly |
| 100 MHz | ✅ Tested | Default configuration |
| 250 MHz | ✅ Tested | High-performance mode |

> For FPGA targets, ensure the Vivado clock wizard output matches the configured frequency (see `hw/fpga_cgra/scripts/*/xilinx_generate_clk_wizard.tcl`).

---

## Documentation

### CGRA Development Tools

| Tool | Description |
|------|-------------|
| [ESL-CGRA Simulator](https://github.com/esl-epfl/ESL-CGRA-simulator) | Cycle-accurate CGRA behavioral simulation |
| [SAT-MapIt](https://github.com/CristianTirelli/SAT-MapIt) | Automatic kernel mapping compiler |
| [X-HEEP FEMU](https://github.com/simone-machetti/x-heep-femu) | FPGA emulation framework |

### Kernel Development

1. **Design**: Create your kernel using the ESL-CGRA simulator
2. **Map**: Use SAT-MapIt for automatic mapping of complex kernels
3. **Test**: Validate with `kernel_test` application
4. **Deploy**: Run on FPGA or silicon

---

## Technical Details (UMA-DAC Fork)

This fork includes fixes for X-HEEP v1.0.4 compatibility:

<details>
<summary><strong>1. Custom External Crossbar</strong></summary>

**File**: `hw/rtl/ext_xbar.sv`

The original X-HEEP testbench contains NAPOT logic for interleaved slow memory, assuming slave index 0 is `SLOW_MEMORY`. In HEEPsilon, index 0 is the CGRA context memory.

**Problem**: CPU access to CGRA memory at `0xF0000000` caused bus hangs due to incorrect address modification.

**Solution**: HEEPsilon-specific `ext_xbar.sv` without NAPOT logic.
</details>

<details>
<summary><strong>2. Testharness Refactoring</strong></summary>

**File**: `tb/testharness.sv`

- Updated powergate signal handling
- Added DPI components (UART, JTAG, SPI Flash)
- Proper power switch emulation
</details>

<details>
<summary><strong>3. FuseSoC Updates</strong></summary>

- Added SPI Flash model for Verilator
- Updated Verilator waivers
- Configured local `ext_xbar.sv`
</details>

---

## Contributing

HEEPsilon brings together researchers from universities across Switzerland, Spain, and Italy. We welcome contributions!

### Areas of Interest

- 🔧 New CGRA kernels and validation
- 🔗 Unified compilation toolchain
- 📊 Cycle and energy-accurate characterization
- 📝 Documentation improvements

---

## Contact

**Original Project (EPFL)**  
Juan Sapriza — juan.sapriza@epfl.ch

**UMA-DAC Fork**  
Cristian Campos — cricamfe@ac.uma.es

---

<p align="center">
  <sub>Built with ❤️ by <a href="https://www.epfl.ch/labs/esl/">EPFL ESL</a> and <a href="https://www.uma.es/">UMA-DAC</a></sub>
</p>
