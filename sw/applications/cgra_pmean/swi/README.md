# CGRA pMean Kernel (SWI Version)

This variation of the pMean kernel demonstrates how to use `SWI` (Store Word Indirect) for memory writes. Unlike `SWD` (Store Word Direct) which uses a hardware-managed write pointer, `SWI` requires the kernel to explicitly calculate and provide the absolute memory address for each write.

## Why SWI?

`SWI` allows for "scatter" operations where the destination address is not sequential or known at design time. However, it presents a challenge: the kernel does not inherently know the absolute physical address of the output buffer (`result` array), which is determined by the linker.

## Implementation Strategy: Address Injection

To solve the addressing challenge, we "inject" the base address of the `result` buffer as the **first element of the input data stream**.

### 1. `main.c` Modifications

*   **Input Data Structure:** The `input_data` array is modified to include the address of `result` at index 0.
    ```c
    int32_t input_data[] = { 0, 101, 110, -1 }; // 0 is placeholder
    // ... later in main() ...
    input_data[0] = (int32_t)result;
    ```

*   **Dual Read Pointers:** We configure **two** columns to read from `input_data`, but with different offsets:
    1.  **Column 1 (Address Loader):** Reads from `input_data` (index 0) to load the base address.
        ```c
        cgra_set_read_ptr(&cgra, (uint32_t)input_data, 1);
        ```
    2.  **Column 0 (Data Processor):** Reads from `input_data + 1` to process the actual data (101, 110...), skipping the address.
        ```c
        cgra_set_read_ptr(&cgra, (uint32_t)(input_data + 1), 0);
        ```

### 2. `instructions.csv` Kernel Logic

The kernel uses a multi-PE approach to handle data processing and address management in parallel.

*   **Address Management (Column 1, Row 0):**
    *   **Cycle 0:** `LWD R2` loads the base address from the input stream.
    *   **Cycle 1:** `SADD R0, 0, 4` initializes the offset increment.
    *   **Cycle X:** `SADD R0, R2, RCB` (where RCB comes from PE(3,1)) calculates the current write address (`Base + Offset`).

*   **Data Processing (Column 0):**
    *   Performs the standard EMA filter calculation (`Acc`, `Prev`, `Temp`).
    *   **Writes:** Uses `SWI RCT, RCR`.
        *   `RCT`: The data to write (from the calculation).
        *   `RCR`: The address to write to (received from Column 1).

## Execution Flow

1.  **Cycle 0:**
    *   Col 1 loads `&result` into `R2`.
    *   Col 0 initializes accumulators.
2.  **Cycle N (Loop):**
    *   Col 0 computes the new mean.
    *   Col 1 computes the next write address (`R2 + 4*N`).
    *   Col 0 executes `SWI Data, Address` using the address provided by Col 1 via the interconnect (`RCR`).

## Verification

The simulation compares the final output written to the `result` array against a CPU golden model.
```
CGRA Final Prev: 102, CPU Expected: 102
SUCCESS: Results match!
```
