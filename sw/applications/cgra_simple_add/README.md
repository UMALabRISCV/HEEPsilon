# CGRA Simple Add

A minimal example demonstrating how to create and run a CGRA kernel manually using CSV instructions, without the SAT-MapIt compiler.

## Overview

This example implements a simple addition kernel: `result = a + b`

- **Column 0**: Loads value `a`, adds value from Column 1, stores result
- **Column 1**: Loads value `b`, sends to Column 0 via RCR (Right-to-Left communication)

## Files

| File | Description |
|------|-------------|
| `instructions.csv` | CGRA kernel definition in CSV format |
| `main.c` | Test application that runs the kernel and verifies results |
| `cgra_bitstream.h` | Generated bitstream (output of generate_bitstream.py) |
| `utils/generate_bitstream.py` | Tool to convert CSV to CGRA bitstream |

## Kernel Definition (instructions.csv)

```csv
0,,,
"LWD R0","LWD R0",NOP,NOP
...
1,,,
"SADD R0, R0, RCR",NOP,NOP,NOP
...
2,,,
"SWD R0",NOP,NOP,NOP
...
3,,,
"EXIT",NOP,NOP,NOP
...
```

### Instruction Format

Each row represents one cycle. Columns represent CGRA columns (0-3).

**Supported instructions:**
- `LWD Rx` - Load Word Direct (from read pointer to register)
- `SWD Rx` - Store Word Direct (from register to write pointer)
- `SADD Rd, Rs1, Rs2` - Signed Add (Rd = Rs1 + Rs2)
- `SADD Rd, Rs, IMM` - Signed Add with immediate
- `NOP` - No operation
- `EXIT` - End kernel execution

**Communication:**
- `RCR` - Receive from Right neighbor (Column N reads from Column N+1)
- `RCL` - Receive from Left neighbor
- `RCT` - Receive from Top neighbor
- `RCB` - Receive from Bottom neighbor

## Usage

### 1. Generate Bitstream

```bash
cd sw/applications/cgra_simple_add
python3 utils/generate_bitstream.py instructions.csv -o cgra_bitstream.h
```

### 2. Build and Run

```bash
# From HEEPsilon root
make clean-app
make app PROJECT=cgra_simple_add TARGET=sim
make verilator-sim
cd build/eslepfl_systems_heepsilon_0/sim-verilator
./Vtestharness +firmware=../../../sw/build/main.hex
cat uart0.log
```

### Expected Output

```
=== CSV Example: CGRA vs CPU Addition ===
Input: a = 42, b = 58
CPU result: 100
CGRA result: 100
SUCCESS: Results match!
CGRA test finished with 0 errors
```

## Key Concepts

### Pointer Configuration

The CGRA uses separate read and write pointers per column:

```c
// Column 0 reads from value_a, writes result back to value_a
cgra_set_read_ptr(&cgra, (uint32_t)&value_a, 0);
cgra_set_write_ptr(&cgra, (uint32_t)&value_a, 0);

// Column 1 reads from value_b
cgra_set_read_ptr(&cgra, (uint32_t)&value_b, 1);
```

### Memory Latency

The CGRA hardware handles memory latency automatically (stalls if data not ready). You don't need to insert NOPs between LWD and the instruction that uses the loaded value.

### Inter-Column Communication

Use `RCR`, `RCL`, `RCT`, `RCB` to read neighbor's output register. Communication is immediate (no latency penalty).

## Creating Your Own Kernel

1. Copy this folder as a template
2. Edit `instructions.csv` with your kernel logic
3. Update `main.c` to set up correct input/output pointers
4. Run `generate_bitstream.py` to create the bitstream
5. Build and test with Verilator

## License

Apache-2.0 (same as HEEPsilon)
