# HEEPsilon Docker Development Environment

This directory contains Docker configuration for a fully pre-configured HEEPsilon development environment.

## Quick Start (3 steps!)

```bash
# 1. Clone the repository
git clone --recursive https://github.com/UMALabRISCV/HEEPsilon.git
cd HEEPsilon

# 2. Build the Docker image (first time only, ~5 min)
make -C util/docker docker-build

# 3. Start the container
make -C util/docker docker-run
```

Once inside the container:
```bash
# Generate MCU and build simulator (first time only)
mcu-gen && verilator-sim

# Run a test
run-hello
```

## What's Included

The Docker image is based on the official x-heep toolchain and includes:

- **RISC-V GCC & LLVM toolchains** (CORE-V with PULP extensions)
- **Verilator 5.040** for RTL simulation
- **Verible** for SystemVerilog formatting
- **Python environment** with all dependencies pre-installed

## Available Commands

| Command | Description |
|---------|-------------|
| `make -C util/docker docker-build` | Build the Docker image |
| `make -C util/docker docker-run` | Start interactive container |
| `make -C util/docker docker-shell` | Attach to running container |
| `make -C util/docker docker-clean` | Remove container and image |

## Inside the Container

Helpful aliases are pre-configured:

| Alias | Command |
|-------|---------|
| `mcu-gen` | Generate MCU configuration |
| `verilator-sim` | Build Verilator simulator |
| `run-hello` | Run hello_world application |
| `run-kernel-test` | Run CGRA kernel test |

## Requirements

- [Docker](https://docs.docker.com/engine/install/) installed on your system
- ~10GB disk space for the image
- Internet connection (for building the image)

## Troubleshooting

**Permission denied errors:**
If you get permission issues with mounted files, try:
```bash
docker run -it --rm -u $(id -u):$(id -g) ...
```

**Slow performance on macOS/Windows:**
Use Docker Desktop's file sharing settings or consider using a Linux VM.
