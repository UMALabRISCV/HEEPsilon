// Frequency check application for HEEPsilon.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "core_v_mini_mcu.h"
#include "soc_ctrl.h"
#include "x-heep.h"

int main(void) {
  soc_ctrl_t soc_ctrl;
  soc_ctrl.base_addr = mmio_region_from_addr((uintptr_t)SOC_CTRL_START_ADDRESS);

  uint32_t freq_hz = soc_ctrl_get_frequency(&soc_ctrl);

  printf("SOC_CTRL frequency: %u Hz\n", (unsigned int)freq_hz);
  printf("REFERENCE_CLOCK_Hz: %u Hz\n", (unsigned int)REFERENCE_CLOCK_Hz);

  if (freq_hz != (uint32_t)REFERENCE_CLOCK_Hz) {
    printf("FREQ_MISMATCH\n");
    return EXIT_FAILURE;
  }

  printf("FREQ_OK\n");
  return EXIT_SUCCESS;
}
