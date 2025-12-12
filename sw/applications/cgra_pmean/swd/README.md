# CGRA pMean Kernel (EMA Filter)

This kernel implements an **Exponential Moving Average (EMA)** filter, also known as a first-order IIR low-pass filter, on a sequence of input data.

## Algorithm

The filter implements the recursive equation:
$$y[n] = \alpha \cdot x[n] + (1 - \alpha) \cdot y[n-1]$$
where $\alpha = 0.25$.

To optimize hardware execution and avoid floating-point arithmetic, we use fixed-point arithmetic with shifts:

1.  **Maintain Scaled Accumulator ($S$):** $S \approx 4 \times \text{Mean}$.
2.  **Calculate Difference:** $Temp = S_{prev} - y_{prev}$
3.  **Update Accumulator:** $S_{new} = Temp + x_{new}$
4.  **Calculate New Mean:** $y_{new} = Temp >> 2$ (Division by 4)

Resulting in: $y[n] \approx 0.75 \cdot y[n-1] + 0.25 \cdot x[n]$.

## CGRA Implementation

The kernel uses a single PE (Column 0) to perform all calculations in a loop.

### Initial State (Registers)
At the start of the kernel, registers are initialized with pre-calculated values (for filter continuity):
*   `R0` (Accumulator $S$): 518
*   `R1` (Previous Mean $y$): 106

### Processing Loop
For each input data `x`:
1.  **Load:** `LWD` loads `x` into `R0`.
2.  **Check:** Checks if `x == -1` (sentinel). If true, it exits.
3.  **Compute:**
    *   `Temp (SELF) = Acc (R0) - Prev (R1)`
    *   `Acc (R0) = Temp (SELF) + x (R0)`
    *   `Prev (R1) = Temp (SELF) >> 2`
4.  **Store:** `SWD` stores the new `Prev` to memory.
5.  **Loop:** Jumps back to start.

### Memory Map
*   **Init:** Hardcoded configuration in instructions 0-2.
*   **Input:** `input_data` array in memory (terminated by -1).
*   **Output:** `result` array where the sequence of calculated means is written.

## Hardware Constraints Respected
*   **LWD Latency:** A one-cycle delay is expected after `LWD` before using data in `R0`.
*   **JUMP:** Uses `JUMP target` syntax for correct encoding (ALU `ZERO + IMM`).
*   **BNE:** Uses register `R3` with a loaded constant for comparison, avoiding the immediate limitation in branch instructions.

## Execution and Verification
The `main.c` file includes a software reference implementation (Golden Model) that exactly replicates the kernel's integer arithmetic. Final verification compares the last mean value calculated by both the CPU and the CGRA.
