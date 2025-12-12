# HEEPsilon CGRA Utilities

This directory contains the core toolchain for developing CGRA applications on HEEPsilon.

## Tools

### 1. `cgra_create_app.py`
The main scaffolding tool. It automates the entire process of creating a new application.

**Features:**
- **Scaffolding:** Creates the directory structure (`sw/applications/<name>`).
- **C Generation:** Generates `main.c` with automatic pointer configuration.
- **Bitstream:** Calls the generator to compile CSV to `cgra_bitstream.h`.
- **Visualization:** Generates a Graphviz (`.dot`) visualization of the kernel.

**Usage:**
```bash
python3 sw/utils/cgra_create_app.py <instruction.csv> <app_name> [options]
```

**Options:**
- `--inputs "10,20,30"`: Custom input data.
- `--offsets "0:0, 1:4"`: Memory offsets for valid signal (Input Muxing).
- `--split-inputs`: Create separate C arrays for each column.
- `--visualize`: Generate `kernel.dot`.
- `--memory-file <file.csv>`: Initialize explicit memory.
- `--load-addrs/--store-addrs`: Use absolute addresses for pointers.

---

### 2. `visualize_kernel.py`
Standalone script to visualize the data flow of a kernel.

**Usage:**
```bash
python3 sw/utils/visualize_kernel.py <instructions.csv> <output.dot>
```
Produces a Graphviz DOT file showing temporal (Registers) and spatial (Neighbors) dependencies.

---

### 3. `generate_bitstream.py` (Template)
The core logic for encoding CSV instructions into the 32-bit CGRA ISA.
*Note: This script is central and used by `cgra_create_app.py`.*

## Typical Workflow

1.  Create a kernel CSV (see `templates/`).
2.  Run scaffolding:
    ```bash
    python3 sw/utils/cgra_create_app.py sw/utils/templates/my_kernel.csv my_app --visualize
    ```
3.  Compile and Run:
    ```bash
    make verilator-run-app PROJECT=my_app
    ```
