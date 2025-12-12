/*
 * CGRA pMean - Partial Mean Calculation
 * 
 * Calculates the mean of input values stored in memory.
 * Uses a sentinel value (-1) to mark end of data.
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

#if CGRA_N_COLS != 4 || CGRA_N_ROWS != 4
  #error This example requires a 4x4 CGRA
#endif

volatile int8_t cgra_intr_flag;

// Input data (must match memory.csv)
int32_t input_data[] __attribute__((aligned(4))) = {
    101, 110, -1
};  // Sentinel

// Output array to capture all SWD writes (size = num inputs + margin)
#define MAX_OUTPUTS 16
int32_t result[MAX_OUTPUTS] __attribute__((aligned(4))) = {0};

void handler_irq_cgra(uint32_t id) {
    cgra_intr_flag = 1;
}

int32_t cpu_pmean(int32_t* data) {
    int32_t sum = 0;
    int32_t count = 0;
    while (*data != -1) {
        sum += *data;
        count++;
        data++;
    }
    if (count == 0) return 0;
    return sum / count;
}

int main(void) {
    int32_t errors = 0;
    
    printf("=== CGRA pMean ===\n");
    // Calculate expected EMA result (pMean)
    // Initial State
    int32_t acc = 518;
    int32_t prev = 106;
    
    int32_t step = 0;
    int32_t* ptr = input_data;
    
    printf("Initial State: Acc=%ld, Prev=%ld\n", (long)acc, (long)prev);
    
    while (*ptr != -1) {
        int32_t x = *ptr;
        int32_t temp = acc - prev;
        acc = temp + x;
        prev = temp >> 2;
        printf("Step %ld: In=%ld, Temp=%ld, Acc=%ld, New Prev=%ld\n", 
               (long)step, (long)x, (long)temp, (long)acc, (long)prev);
        ptr++;
        step++;
    }
    
    printf("CPU Final State: Acc=%ld, Prev=%ld\n", (long)acc, (long)prev);
    
    cgra_cmem_init(cgra_cmem_bitstream, cgra_kmem_bitstream);
    
    plic_Init();
    plic_irq_set_priority(CGRA_INTR, 1);
    plic_irq_set_enabled(CGRA_INTR, kPlicToggleEnabled);
    plic_assign_external_irq_handler(CGRA_INTR, (void*)&handler_irq_cgra);
    
    CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);
    const uint32_t mask = 1 << 11;
    CSR_SET_BITS(CSR_REG_MIE, mask);
    cgra_intr_flag = 0;
    
    cgra_t cgra;
    cgra.base_addr = mmio_region_from_addr((uintptr_t)CGRA_PERIPH_START_ADDRESS);
    
    cgra_wait_ready(&cgra);
    cgra_perf_cnt_enable(&cgra, 1);
    
    // Column 0 reads from input_data
    cgra_set_read_ptr(&cgra, (uint32_t)input_data, 0);
    // Column 0 writes to result array (captures all SWD writes)
    cgra_set_write_ptr(&cgra, (uint32_t)result, 0);
    
    printf("Launching CGRA kernel...\n");
    cgra_set_kernel(&cgra, CGRA_KERNEL);
    
    cgra_intr_flag = 0;
    while (cgra_intr_flag == 0) {
        wait_for_interrupt();
    }
    printf("CGRA kernel completed.\n");
    
    // Print all CGRA outputs
    printf("CGRA outputs:\n");
    for (int i = 0; i < MAX_OUTPUTS && result[i] != 0; i++) {
        printf("  [%d]: %ld\n", i, (long)result[i]);
    }
    
    // Compare last non-zero result with expected CPU Prev
    int last_idx = 0;
    for (int i = 0; i < MAX_OUTPUTS; i++) {
        if (result[i] != 0) last_idx = i;
    }
    int32_t cgra_final = result[last_idx];
    
    printf("CGRA Final Prev: %ld, CPU Expected: %ld\n", (long)cgra_final, (long)prev);
    
    if (cgra_final != prev) {
        printf("WARNING: Results differ!\n");
        errors++;
    } else {
        printf("SUCCESS: Results match!\n");
    }
    
    printf("pMean test finished with %ld errors\n", (long)errors);
    
    return errors ? EXIT_FAILURE : EXIT_SUCCESS;
}
