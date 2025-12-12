# CGRA Kernel Templates

This directory contains reference CSV files for creating OpenEdge CGRA kernels.

## CSV Format
The tools expect a specific **Block Format**:
- **Cycle Header:** A line containing just the cycle number (e.g., `0`).
- **Instruction Block:** The next lines define the instructions for the 4 rows of the CGRA for that cycle.
- **Columns:** Each line is a comma-separated list of instructions for Columns 0, 1, 2, 3.

**Example:**
```csv
0
"SADD R0, 0, 1",NOP,NOP,NOP    <-- Row 0 (Cols 0-3)
NOP,NOP,NOP,NOP                <-- Row 1
...
1
"LWD R0",...                   <-- Next cycle
```

## Available Templates

### `simple_increment.csv`
A basic single-column kernel.
- **Logic:** Loads a value, adds 1, stores it.
- **Purpose:** Testing basic streaming and arithmetic.

### `vector_mac.csv`
A complex multi-column kernel.
- **Logic:** `Result[i] = A[i] * B[i] + 5`
- **Features:** 
  - Uses `SADD`, `SMUL`, `LWD`, `SWD`.
  - Uses Neighbor communication (`RCL`).
  - Uses Control Flow (`BNE`).
- **Purpose:** Validating complex routing and multi-array inputs.
