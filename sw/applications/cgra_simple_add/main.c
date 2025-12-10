/*
 * CGRA Simple Add - HEEPsilon CGRA Example
 * 
 * This example demonstrates how to:
 * 1. Create a CGRA kernel manually using CSV format
 * 2. Generate the bitstream with generate_bitstream.py
 * 3. Run the kernel and verify results against CPU
 * 
 * Kernel: result = a + b
 * - Column 0: Loads 'a', adds 'b' from Column 1, stores result
 * - Column 1: Loads 'b', sends to Column 0 via RCR
 */

#include <stdio.h>
#include <stdlib.h>

#include "csr.h"
#include "hart.h"
#include "handler.h"
#include "core_v_mini_mcu.h"
#include "rv_plic.h"
#include "rv_plic_regs.h"
#include "heepsilon.h"
#include "cgra.h"
#include "cgra_bitstream.h"

// Verify CGRA size
#if CGRA_N_COLS != 4 || CGRA_N_ROWS != 4
  #error This example requires a 4x4 CGRA
#endif

// Debug printing
// #define DEBUG
#ifdef DEBUG
  #define PRINTF(fmt, ...) printf(fmt, ## __VA_ARGS__)
#else
  #define PRINTF(...)
#endif

// Input/output dimensions
#define CGRA_IN_LEN  1
#define CGRA_OUT_LEN 1

// CGRA data buffers (aligned for DMA)
int32_t cgra_input[CGRA_N_COLS][CGRA_IN_LEN] __attribute__((aligned(4)));
int32_t cgra_output[CGRA_N_COLS][CGRA_OUT_LEN] __attribute__((aligned(4)));

// Interrupt flag
volatile int8_t cgra_intr_flag;

// Test data
int32_t value_a = 42;
int32_t value_b = 58;

// Interrupt handler for CGRA completion
void handler_irq_cgra(uint32_t id) {
    cgra_intr_flag = 1;
}

// Software reference implementation
int32_t cpu_compute(int32_t a, int32_t b) {
    return a + b;
}

int main(void) {
    int32_t errors = 0;
    
    printf("=== CGRA Simple Add ===\n");
    
    // Initialize CGRA context memory
    PRINTF("Initializing CGRA configuration memory...\n");
    cgra_cmem_init(cgra_cmem_bitstream, cgra_kmem_bitstream);
    PRINTF("Done.\n");
    
    // Initialize PLIC for CGRA interrupts
    plic_Init();
    plic_irq_set_priority(CGRA_INTR, 1);
    plic_irq_set_enabled(CGRA_INTR, kPlicToggleEnabled);
    plic_assign_external_irq_handler(CGRA_INTR, (void*)&handler_irq_cgra);
    
    // Enable machine-level interrupts
    CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);
    const uint32_t mask = 1 << 11;
    CSR_SET_BITS(CSR_REG_MIE, mask);
    cgra_intr_flag = 0;
    
    // Get CGRA handle
    cgra_t cgra;
    cgra.base_addr = mmio_region_from_addr((uintptr_t)CGRA_PERIPH_START_ADDRESS);
    
    // Prepare input data
    // Column 0: pointer to value_a
    // Column 1: pointer to value_b
    cgra_input[0][0] = (int32_t)&value_a;
    cgra_input[1][0] = (int32_t)&value_b;
    cgra_input[2][0] = 0;  // Unused
    cgra_input[3][0] = 0;  // Unused
    
    printf("Input: a = %ld, b = %ld\n", (long)value_a, (long)value_b);
    
    // Run CPU reference
    int32_t cpu_result = cpu_compute(value_a, value_b);
    printf("CPU result: %ld\n", (long)cpu_result);
    
    // Configure CGRA
    PRINTF("Configuring CGRA...\n");
    cgra_wait_ready(&cgra);
    cgra_perf_cnt_enable(&cgra, 1);
    
    // Set read pointer for column 0 to point directly to value_a (42)
    cgra_set_read_ptr(&cgra, (uint32_t)&value_a, 0);
    
    // Set read pointer for column 1 to point directly to value_b (58)
    cgra_set_read_ptr(&cgra, (uint32_t)&value_b, 1);
    
    // Set write pointer for column 0 (for SWD) - result goes to value_a
    cgra_set_write_ptr(&cgra, (uint32_t)&value_a, 0);
    
    // Launch kernel
    PRINTF("Launching CGRA kernel...\n");
    cgra_set_kernel(&cgra, CGRA_KERNEL);
    
    // Wait for completion
    cgra_intr_flag = 0;
    while (cgra_intr_flag == 0) {
        wait_for_interrupt();
    }
    PRINTF("CGRA kernel completed.\n");
    
    // Read CGRA result
    // The result is written back to value_a by the SWD instruction
    int32_t cgra_result = value_a;
    printf("CGRA result: %ld\n", (long)cgra_result);
    
    // Compare results
    if (cgra_result != cpu_result) {
        printf("ERROR: Mismatch! CPU=%ld, CGRA=%ld\n", 
               (long)cpu_result, (long)cgra_result);
        errors++;
    } else {
        printf("SUCCESS: Results match!\n");
    }
    
    printf("CGRA test finished with %ld errors\n", (long)errors);
    
    return errors ? EXIT_FAILURE : EXIT_SUCCESS;
}
