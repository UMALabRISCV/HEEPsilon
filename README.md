<p align="left"><img src="docs/HEEPsilon_logo.png" width="500"></p>

HEEPsilon is a versatile computing platform targeting ultra low power processing of biological and environmental signals. It is built over the [X-HEEP](https://github.com/esl-epfl/x-heep) platform and extends it with [openEdgeCGRA](https://github.com/esl-epfl/OpenEdgeCGRA) a design-time resizable and run-time reprogrammable Coarse Grained Reconfigurable Array (CGRA).
For a brief insight on HEEPsilon please refer to our abstract:

📄 [An Open-Hardware Coarse-Grained Reconfigurable Array for Edge Computing](https://dl.acm.org/doi/10.1145/3587135.3591437).

As an X-HEEP spinoff, HEEPsilon keeps all X-HEEP functionalities, from RTL simulation on Verilator, VCS and Questasim to implementation on the [PYNQ-Z2 FPGA](https://www.xilinx.com/support/university/xup-boards/XUPPYNQ-Z2.html). Our cousin HEEPocrates was recently taped-out in TSMC 65nm process and is currently undertaking tests successfully.

In addition to all the tools available for X-HEEP, HEEPsilon is building a toolchain to simplify the C-code→CGRA process.

---

> [!NOTE]
> **Fork Information**: This repository is a fork maintained by the [University of Málaga (UMA)](https://www.uma.es/) - Departamento de Arquitectura de Computadores (DAC). It includes bug fixes and updates for compatibility with **X-HEEP v1.0.4**.

## Version Compatibility

| Component | Version | Notes |
|-----------|---------|-------|
| X-HEEP | v1.0.4 | Vendorized in `hw/vendor/esl_epfl_x_heep` |
| OpenEdgeCGRA | 4a179fc | Vendorized in `hw/vendor/esl_epfl_cgra` |
| Verilator | 5.x | Tested with v5.040 |

---

# Getting started

## Prerequisites

1. **RISC-V Toolchain**: Install `riscv32-corev-elf-*` toolchain
2. **Python 3.8+**: With pip and venv support
3. **Verilator 5.x**: For RTL simulation
4. **FuseSoC**: Installed via pip

## Quick Setup

```bash
# Clone the repository
git clone https://github.com/UMALabRISCV/HEEPsilon.git
cd HEEPsilon

# Create and activate Python virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install Python dependencies
pip install -r hw/vendor/esl_epfl_x_heep/python-requirements.txt

# Generate MCU configuration (256KB memory, 8 banks)
make mcu-gen CPU=cv32e20 BUS=NtoM MEMORY_BANKS=8
```

## Docker Quick Start (Recommended)

A pre-configured Docker environment with all dependencies is available:

```bash
# Clone the repository
git clone --recursive https://github.com/UMALabRISCV/HEEPsilon.git
cd HEEPsilon

# Build the Docker image (first time only)
make -C util/docker docker-build

# Start the container
make -C util/docker docker-run
```

Inside the container, all tools are ready:
```bash
make mcu-gen && make verilator-sim   # First time setup
make verilator-run-app PROJECT=hello_world
```

See [`util/docker/README.md`](util/docker/README.md) for more details.

## Building and Running Simulations

These commands follow the [X-HEEP simulation workflow](hw/vendor/esl_epfl_x_heep/docs/source/How_to/Simulate.md).

### 1. Build Verilator Simulation Model

```bash
source .venv/bin/activate
make verilator-build
```

### 2. Compile and Run an Application

**Option A: Step by step**
```bash
make app PROJECT=hello_world TARGET=sim
make verilator-run
```

**Option B: All in one** (recommended)
```bash
make verilator-run-app PROJECT=cgra_func_test
```

Available test applications:
- `hello_world` - Basic UART test
- `cgra_func_test` - CGRA functionality verification

### 3. Simulation Parameters

You can pass additional parameters via `SIM_ARGS`:
```bash
make verilator-run SIM_ARGS="+max_sim_time=100000"
```

UART output is saved to `uart0.log`.

### Complete Example (CGRA Test)

```bash
source .venv/bin/activate
make mcu-gen CPU=cv32e20 BUS=NtoM MEMORY_BANKS=8
make verilator-build
make verilator-run-app PROJECT=cgra_func_test
# Expected: "CGRA functionality check finished with 0 errors"
```

---

# Technical Changes (UMA-DAC Fork)

This fork includes the following fixes for X-HEEP v1.0.4 compatibility:

### 1. Custom External Crossbar (`hw/rtl/ext_xbar.sv`)

The original X-HEEP testbench `ext_xbar.sv` contains NAPOT (Next Address Power Of Two) logic designed for interleaved slow memory access. This logic assumes slave index 0 is always `SLOW_MEMORY`, but in HEEPsilon, index 0 is the **CGRA context memory**.

**Problem**: When the CPU accessed CGRA memory at `0xF0000000`, the NAPOT logic incorrectly modified addresses, causing bus hangs.

**Solution**: Created a HEEPsilon-specific `ext_xbar.sv` that removes the NAPOT logic while maintaining full crossbar functionality.

### 2. Testharness Refactoring (`tb/testharness.sv`)

Ported the X-HEEP v1.0.4 testharness architecture:
- Updated powergate signal handling for `cpu_subsystem` and `peripheral_subsystem`
- Added DPI components for UART, JTAG, and SPI Flash
- Proper power switch emulation matching X-HEEP patterns

### 3. FuseSoC Configuration Updates

- Added SPI Flash model (`spiflash.core`) for Verilator
- Updated Verilator waivers for vendor code compatibility
- Configured `heepsilon.core` to use local `ext_xbar.sv`

---

# Behavioural simulations

The CGRA used in HEEPsilon can be simulated with CGRA-instruction accuracy using the [ESL-CGRA simulator](https://github.com/esl-epfl/ESL-CGRA-simulator).
This allows for fast and easy-to-debug design of kernels for the CGRA. Once you are happy with your design you can compile the assembly and get the bitstream to load into the CGRA.

# SAT-MapIt Compiler

Your kernel is too complex to be mapped manually? Try using the [SAT-MapIt mapper and compiler](https://github.com/CristianTirelli/SAT-MapIt). Properly label your C-code and let SAT-MapIt find an efficient mapping you can test in the simulator and deploy in the CGRA.

# Testing a kernel

Once you have tested your setup with the `cgra_func_test` application you can start trying out different kernels. HEEPsilon provides a set of tools to easily go from C-code to CGRA bitstreams. All kernels are converted into a standard C source and header file pair which you can use with the `kernel_test` application to measure the speed-up of your CGRA implementation as well as see stochastical variations.

# Adding a complex environment to your platform

If you application requires some hardcore input-output management, maybe you want to try out the [X-HEEP FEMU](https://github.com/simone-machetti/x-heep-femu). Connect your PYNQ-Z2 FPGA via SSH and start deploying different hardware versions of X-HEEP or HEEPsilon, test different software applications and interface with the hardware from the comfort of Python scripts or Jupyter notebooks.

# Wanna collaborate?

HEEPsilon is a newborn project that already brings together dozens of researchers from 4 universities across Switzerland, Spain and Italy. There is plenty of cool work to be done for and with HEEPsilon, join us!

Pending work includes:
* Development of new kernels for the CGRA and validation in real applications.
* Integration of the different compilation tools into a single workflow.
* Extracting variable information from the LLVM pass during C-code → CGRA assembly process.
* Characterizing the CGRA hardware for cycle and energy-accurate simulation.

# Contact us

**Original Project (EPFL):**
Have some questions? Don't hesitate to contact: juan.sapriza@epfl.ch

**UMA-DAC Fork:**
Maintainer: Cristian Campos - cricamfe@ac.uma.es
