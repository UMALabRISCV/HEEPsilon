# Copyright EPFL contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0


# Makefile to generates heepsilon files and build the design with fusesoc

.PHONY: clean help clock-gen

TARGET 		?= sim
FPGA_BOARD 	?= pynq-z2
PORT		?= /dev/ttyUSB2

# 1 external domain for the CGRA
EXTERNAL_DOMAINS = 1
PROJECT ?= hello_world

#MEMORY_BANKS ?= 2 # Multiple of 2
#MEMORY_BANKS_IL ?= 4 # Power of 2

include clock_config.mk

HEEPSILON_CPU_CLK_KHZ := $(shell expr $(HEEPSILON_CPU_CLK_HZ) / 1000)
HEEPSILON_CGRA_CLK_KHZ := $(shell expr $(HEEPSILON_CGRA_CLK_HZ) / 1000)
  
export HEEP_DIR = hw/vendor/esl_epfl_x_heep/
include $(HEEP_DIR)Makefile.venv

# FUSESOC and Python values - support both venv and conda
ifndef CONDA_DEFAULT_ENV
$(info USING VENV)
FUSESOC = $(PWD)/$(VENV)/fusesoc
PYTHON  = $(PWD)/$(VENV)/python
else
$(info USING MINICONDA $(CONDA_DEFAULT_ENV))
FUSESOC := $(shell which fusesoc)
PYTHON  := $(shell which python)
endif

HEEPSILON_CFG  ?= heepsilon_cfg.hjson

clock-gen:
	@mkdir -p tb sw/device
	@printf '`ifndef HEEPSILON_CLOCK_CONFIG_SVH\n`define HEEPSILON_CLOCK_CONFIG_SVH\n`define HEEPSILON_CPU_CLK_HZ $(HEEPSILON_CPU_CLK_HZ)\n`define HEEPSILON_CPU_CLK_KHZ $(HEEPSILON_CPU_CLK_KHZ)\n`define HEEPSILON_CGRA_CLK_HZ $(HEEPSILON_CGRA_CLK_HZ)\n`define HEEPSILON_CGRA_CLK_KHZ $(HEEPSILON_CGRA_CLK_KHZ)\n`endif\n' > tb/heepsilon_clock_config.svh
	@printf '#ifndef HEEPSILON_CLOCK_CONFIG_HH\n#define HEEPSILON_CLOCK_CONFIG_HH\n#define HEEPSILON_CPU_CLK_HZ $(HEEPSILON_CPU_CLK_HZ)\n#define HEEPSILON_CPU_CLK_KHZ $(HEEPSILON_CPU_CLK_KHZ)\n#define HEEPSILON_CGRA_CLK_HZ $(HEEPSILON_CGRA_CLK_HZ)\n#define HEEPSILON_CGRA_CLK_KHZ $(HEEPSILON_CGRA_CLK_KHZ)\n#endif\n' > tb/heepsilon_clock_config.hh
	@printf '#ifndef HEEPSILON_CLOCK_CONFIG_H\n#define HEEPSILON_CLOCK_CONFIG_H\n#define HEEPSILON_CPU_CLK_HZ $(HEEPSILON_CPU_CLK_HZ)\n#define HEEPSILON_CGRA_CLK_HZ $(HEEPSILON_CGRA_CLK_HZ)\n#endif\n' > sw/device/heepsilon_clock_config.h

heepsilon-gen: clock-gen
	$(PYTHON) util/heepsilon_gen.py --cfg $(HEEPSILON_CFG) --outdir hw/vendor/esl_epfl_cgra/hw/rtl --pkg-sv hw/vendor/esl_epfl_cgra/hw/rtl/cgra_pkg.sv.tpl
	$(PYTHON) util/heepsilon_gen.py --cfg $(HEEPSILON_CFG) --outdir hw/vendor/esl_epfl_cgra/hw/rtl --tpl-sv hw/vendor/esl_epfl_cgra/hw/rtl/peripheral_regs.sv.tpl
	$(PYTHON) util/heepsilon_gen.py --cfg $(HEEPSILON_CFG) --outdir hw/vendor/esl_epfl_cgra/util --tpl-sv hw/vendor/esl_epfl_cgra/util/cgra_bitstream_gen.py.tpl
	$(PYTHON) util/heepsilon_gen.py --cfg $(HEEPSILON_CFG) --outdir hw/rtl --pkg-sv hw/rtl/heepsilon_pkg.sv.tpl
	$(PYTHON) util/heepsilon_gen.py --cfg $(HEEPSILON_CFG) --outdir sw/external/drivers/cgra --header-c sw/external/drivers/cgra/cgra.h.tpl
	$(PYTHON) util/heepsilon_gen.py --cfg $(HEEPSILON_CFG) --outdir hw/vendor/esl_epfl_cgra/data --pkg-sv hw/vendor/esl_epfl_cgra/data/cgra_regs.hjson.tpl
	bash -c "cd hw/vendor/esl_epfl_cgra/data; source cgra_reg_gen.sh; cd ../../../.."

# Generates mcu files. First the mcu-gen from X-HEEP is called.
# This is needed to be done after the X-HEEP mcu-gen because the test-bench to be used is the one from heepsilon, not the one from X-HEEP.
mcu-gen: heepsilon-gen
	$(MAKE) -f $(XHEEP_MAKE) EXTERNAL_DOMAINS=${EXTERNAL_DOMAINS} MEMORY_BANKS=${MEMORY_BANKS} $(MAKECMDGOALS)
	cd hw/vendor/esl_epfl_x_heep &&\
	$(PYTHON) util/mcu_gen.py --cached_path build/xheep_config_cache.pickle --cached --outtpl ../../../tb/tb_util.svh.tpl

## Builds (synthesis and implementation) the bitstream for the FPGA version using Vivado
## @param FPGA_BOARD=nexys-a7-100t,pynq-z2
## @param FUSESOC_FLAGS=--flag=<flagname>
vivado-fpga: clock-gen |venv
	$(FUSESOC) --cores-root . run --no-export --target=$(FPGA_BOARD) $(FUSESOC_FLAGS) --setup --build eslepfl:systems:heepsilon 2>&1 | tee buildvivado.log


# Runs verible formating
verible:
	util/format-verible;

# Simulation
# Build directories (following x-heep pattern)
BUILD_DIR         = build
FUSESOC_BUILD_DIR = $(shell find $(BUILD_DIR) -maxdepth 1 -type d -name 'eslepfl_systems_heepsilon_*' 2>/dev/null | sort -V | head -n 1)
VERILATOR_DIR     = $(FUSESOC_BUILD_DIR)/sim-verilator
QUESTASIM_DIR     = $(FUSESOC_BUILD_DIR)/sim-modelsim

# SIM_ARGS: Additional simulation arguments (following x-heep pattern)
# - MAX_SIM_TIME: Maximum simulation time in clock cycles (unlimited if not provided)
SIM_ARGS += $(if $(MAX_SIM_TIME),+max_sim_time=$(MAX_SIM_TIME))

## @section Simulation

## Verilator simulation build
verilator-build: clock-gen |venv
	$(FUSESOC) --cores-root . run --no-export --target=sim --tool=verilator $(FUSESOC_FLAGS) --setup --build eslepfl:systems:heepsilon $(FUSESOC_PARAM) 2>&1 | tee buildsim.log

## First builds the app and then uses Verilator to simulate the HW model and run the FW
## @param PROJECT=hello_world(default),cgra_func_test,...
verilator-run-app:
	$(MAKE) clean-app
	$(MAKE) app PROJECT=$(PROJECT) TARGET=sim
	cd $(VERILATOR_DIR); \
	./Vtestharness +firmware=../../../sw/build/main.hex $(SIM_ARGS); \
	cat uart0.log

## Launches the RTL simulation with the compiled firmware using the Verilator model
## @param MAX_SIM_TIME=<cycles> (optional)
verilator-run:
	cd $(VERILATOR_DIR); \
	./Vtestharness +firmware=../../../sw/build/main.hex $(SIM_ARGS); \
	cat uart0.log

## Opens gtkwave to view the waveform generated by the last verilator simulation
verilator-waves:
	gtkwave $(VERILATOR_DIR)/waveform.fst

## Questasim simulation build
questasim-build: clock-gen |venv
	$(FUSESOC) --cores-root . run --no-export --target=sim --tool=modelsim $(FUSESOC_FLAGS) --setup --build eslepfl:systems:heepsilon $(FUSESOC_PARAM) 2>&1 | tee buildsim.log

## Questasim simulation with HDL optimized compilation
questasim-build-opt: questasim-build
	$(MAKE) -C $(QUESTASIM_DIR) opt

## VCS simulation build
vcs-build: clock-gen |venv
	$(FUSESOC) --cores-root . run --no-export --target=sim --tool=vcs $(FUSESOC_FLAGS) --setup --build eslepfl:systems:heepsilon $(FUSESOC_PARAM) 2>&1 | tee buildsim.log

# Legacy aliases (for backwards compatibility with old HEEPsilon targets)
# Note: .PHONY prevents external.mk wildcard from passing these to x-heep
.PHONY: verilator-sim questasim-sim questasim-sim-opt vcs-sim
verilator-sim: verilator-build
questasim-sim: questasim-build
questasim-sim-opt: questasim-build-opt
vcs-sim: vcs-build
run-verilator: 
	$(MAKE) app PROJECT=$(PROJECT) TARGET=sim
	$(MAKE) verilator-run

## Generates the build output for a given application
## Uses questasim to simulate the HW model and run the FW
## UART Dumping in uart0.log to show recollected results
run-questasim:
	$(MAKE) app PROJECT=$(PROJECT)
	cd ./build/eslepfl_systems_heepsilon_0/sim-modelsim; \
	make run PLUSARGS="c firmware=../../../sw/build/main.hex"; \
	cat uart0.log; \
	cd ../../..;


# Builds the program and uses flash-load to run on the FPGA
run-fpga:
	$(MAKE) app PROJECT=$(PROJECT) LINKER=flash_load TARGET=pynq-z2
	( cd hw/vendor/esl_epfl_x_heep/sw/vendor/yosyshq_icestorm/iceprog && make clean && make all ) ;\
	$(MAKE) flash-prog ;\

# Builds the program and uses flash-load to run on the FPGA.
# Additionally opens picocom (if available) to see the output.
run-fpga-com:
	$(MAKE) app PROJECT=$(PROJECT) LINKER=flash_load TARGET=pynq-z2
	( cd hw/vendor/esl_epfl_x_heep/sw/vendor/yosyshq_icestorm/iceprog && make clean && make all ) ;\
	$(MAKE) flash-prog ;\
	picocom -b 115200 -r -l --imap lfcrlf $(PORT)

XHEEP_MAKE = $(HEEP_DIR)/external.mk
include $(XHEEP_MAKE)

# Add a dependency on the existing app target of XHEEP to create a link to the build folder
app: clock-gen link_build

clean-app: link_rm

link_build:
	ln -sf ../hw/vendor/esl_epfl_x_heep/sw/build sw/build

link_rm:
	rm -f sw/build

clean:
	rm -rf build buildsim.log

## @section Clock Configuration

## Show current clock configuration
clock-show:
	@echo "Current clock configuration:"
	@echo "  CPU Clock:  $(HEEPSILON_CPU_CLK_HZ) Hz ($(HEEPSILON_CPU_CLK_KHZ) kHz)"
	@echo "  CGRA Clock: $(HEEPSILON_CGRA_CLK_HZ) Hz ($(HEEPSILON_CGRA_CLK_KHZ) kHz)"
	@echo ""
	@echo "To change frequency, use:"
	@echo "  make set-freq FREQ=50000000    # Set to 50MHz"
	@echo "  make set-freq FREQ=100000000   # Set to 100MHz"

## Change clock frequency and rebuild simulation model
## @param FREQ=<frequency_in_hz> (e.g., FREQ=50000000 for 50MHz)
.PHONY: set-freq
set-freq:
ifndef FREQ
	$(error FREQ is not set. Usage: make set-freq FREQ=50000000)
endif
	@echo "Setting clock frequency to $(FREQ) Hz..."
	@echo "# HEEPsilon clock configuration (Hz)." > clock_config.mk
	@echo "# Edit this file or override variables on the make command line." >> clock_config.mk
	@echo "# CPU and CGRA share the same system clock in the current design; keep them equal." >> clock_config.mk
	@echo "# Use values divisible by 1000 (simulation uses kHz internally)." >> clock_config.mk
	@echo "HEEPSILON_CPU_CLK_HZ ?= $(FREQ)" >> clock_config.mk
	@echo 'HEEPSILON_CGRA_CLK_HZ ?= $$(HEEPSILON_CPU_CLK_HZ)' >> clock_config.mk
	@echo ""
	@echo "Cleaning build directory..."
	rm -rf build
	@echo "Regenerating clock configuration files..."
	$(MAKE) clock-gen HEEPSILON_CPU_CLK_HZ=$(FREQ)
	@echo ""
	@echo "Frequency updated to $(FREQ) Hz! Now run:"
	@echo "  make verilator-build   # Rebuild simulation model"
	@echo "  make verilator-run-app PROJECT=freq_check  # Verify frequency"

## Change frequency and rebuild Verilator model in one step
## @param FREQ=<frequency_in_hz> (e.g., FREQ=50000000 for 50MHz)
.PHONY: verilator-set-freq
verilator-set-freq: set-freq verilator-build
	@echo ""
	@echo "Verilator model rebuilt with $(FREQ) Hz clock"

## Verify current frequency configuration with freq_check application
.PHONY: freq-verify
freq-verify:
	@rm -rf hw/vendor/esl_epfl_x_heep/sw/build
	@rm -f sw/build
	$(MAKE) verilator-run-app PROJECT=freq_check

