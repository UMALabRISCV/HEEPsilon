# HEEPsilon clock configuration (Hz).
# Edit this file or override variables on the make command line.
# CPU and CGRA share the same system clock in the current design; keep them equal.
# Use values divisible by 1000 (simulation uses kHz internally).
HEEPSILON_CPU_CLK_HZ ?= 100000000
HEEPSILON_CGRA_CLK_HZ ?= $(HEEPSILON_CPU_CLK_HZ)
