// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// HEEPsilon testharness - ported from x-heep testharness for proper simulation
// This version uses heepsilon_top which wraps x_heep_system + CGRA integration

module testharness #(
    parameter bit COREV_PULP                  = 0,
    parameter bit FPU                         = 0,
    parameter bit ZFINX                       = 1,
    parameter bit X_EXT                       = 0,
    parameter     JTAG_DPI                    = 0,
    parameter     CLK_FREQUENCY               = 'd100_000  //KHz
) (
`ifdef VERILATOR
    input  wire         clk_i,
    input  wire         rst_ni,
    input  wire         boot_select_i,
    input  wire         execute_from_flash_i,
    output wire         exit_valid_o,
`else
    inout  wire         clk_i,
    inout  wire         rst_ni,
    inout  wire         boot_select_i,
    inout  wire         execute_from_flash_i,
    inout  wire         exit_valid_o,
`endif
    output logic [31:0] exit_value_o,
    input  wire         jtag_tck_i,
    input  wire         jtag_tms_i,
    input  wire         jtag_trst_ni,
    input  wire         jtag_tdi_i,
    output wire         jtag_tdo_o
);

  `include "tb_util.svh"

  import obi_pkg::*;
  import reg_pkg::*;
  import core_v_mini_mcu_pkg::*;

  localparam SWITCH_ACK_LATENCY = 15;

  // Internal signals
  wire clk;
  wire rst_n;
  wire boot_select;
  wire execute_from_flash;
  wire exit_valid;

  // UART
  wire uart_rx;
  wire uart_tx;
  logic sim_jtag_enable = (JTAG_DPI == 1);

  // JTAG
  wire sim_jtag_tck;
  wire sim_jtag_tms;
  wire sim_jtag_tdi;
  wire sim_jtag_tdo;
  wire sim_jtag_trstn;
  wire mux_jtag_tck;
  wire mux_jtag_tms;
  wire mux_jtag_tdi;
  wire mux_jtag_tdo;
  wire mux_jtag_trstn;
  wire [31:0] gpio;

  // SPI
  wire [3:0] spi_flash_sd_io;
  wire [1:0] spi_flash_csb;
  wire spi_flash_sck;

  wire [3:0] spi_sd_io;
  wire [1:0] spi_csb;
  wire spi_sck;

  // Power switch emulation arrays - matching x-heep testharness exactly
  logic cpu_subsystem_powergate_switch_ack_n[SWITCH_ACK_LATENCY:0];
  logic peripheral_subsystem_powergate_switch_ack_n[SWITCH_ACK_LATENCY:0];

  // Powergate switch outputs from heepsilon_top
  wire cpu_subsystem_powergate_switch_n;
  wire peripheral_subsystem_powergate_switch_n;

  // Inout pins assignments for Verilator 5.X compatibility
  assign clk = clk_i;
  assign rst_n = rst_ni;
  assign boot_select = boot_select_i;
  assign execute_from_flash = execute_from_flash_i;
  assign exit_valid_o = exit_valid;

  // ------------------
  // HEEPSILON SYSTEM
  // ------------------
  heepsilon_top #(
      .COREV_PULP(COREV_PULP),
      .FPU(FPU),
      .ZFINX(ZFINX),
      .X_EXT(X_EXT)
  ) heepsilon_top_i (
      .clk_i(clk),
      .rst_ni(rst_n),
      .boot_select_i(boot_select),
      .execute_from_flash_i(execute_from_flash),
      .jtag_tck_i(mux_jtag_tck),
      .jtag_tms_i(mux_jtag_tms),
      .jtag_trst_ni(mux_jtag_trstn),
      .jtag_tdi_i(mux_jtag_tdi),
      .jtag_tdo_o(mux_jtag_tdo),
      .uart_rx_i(uart_rx),
      .uart_tx_o(uart_tx),
      .gpio_io(gpio[18:0]),
      .exit_value_o,
      .exit_valid_o(exit_valid),
      .spi_flash_sd_io(spi_flash_sd_io),
      .spi_flash_csb_o(spi_flash_csb[0]),
      .spi_flash_sck_o(spi_flash_sck),
      .spi_sd_io(spi_sd_io),
      .spi_csb_o(spi_csb[0]),
      .spi_sck_o(spi_sck),
      .spi2_csb_io(gpio[24:23]),
      .spi2_sck_o(gpio[25]),
      .spi2_sd_0_io(gpio[26]),
      .spi2_sd_1_io(gpio[27]),
      .spi2_sd_2_io(gpio[28]),
      .spi2_sd_3_io(gpio[29]),
      .i2c_scl_io(gpio[31]),
      .i2c_sda_io(gpio[30]),
      // Powergate ack inputs - from testharness delayed feedback
      .cpu_subsystem_powergate_switch_ack_ni(cpu_subsystem_powergate_switch_ack_n[SWITCH_ACK_LATENCY]),
      .peripheral_subsystem_powergate_switch_ack_ni(peripheral_subsystem_powergate_switch_ack_n[SWITCH_ACK_LATENCY]),
      // Powergate switch outputs - to testharness for delayed ack generation
      .cpu_subsystem_powergate_switch_no(cpu_subsystem_powergate_switch_n),
      .peripheral_subsystem_powergate_switch_no(peripheral_subsystem_powergate_switch_n)
  );

  // ---------------------------
  // Power switch emulation
  // ---------------------------
  // Exactly matching x-heep testharness implementation
  always_ff @(posedge clk_i) begin : power_switch_emu
    for (int unsigned i = 0; i <= SWITCH_ACK_LATENCY; i++) begin
      if (i == 0) begin
        cpu_subsystem_powergate_switch_ack_n[0] <= cpu_subsystem_powergate_switch_n;
        peripheral_subsystem_powergate_switch_ack_n[0] <= peripheral_subsystem_powergate_switch_n;
      end else begin
        cpu_subsystem_powergate_switch_ack_n[i] <= cpu_subsystem_powergate_switch_ack_n[i-1];
        peripheral_subsystem_powergate_switch_ack_n[i] <= peripheral_subsystem_powergate_switch_ack_n[i-1];
      end
    end
  end

  // ---------
  // UART DPI
  // ---------
  uartdpi #(
      .BAUD('d256000),
      .FREQ(CLK_FREQUENCY * 1000),  //Hz
      .NAME("uart0")
  ) i_uart0 (
      .clk_i,
      .rst_ni,
      .tx_o(uart_rx),
      .rx_i(uart_tx)
  );

  // ---------
  // JTAG DPI
  // ---------
  SimJTAG #(
      .TICK_DELAY(1),
      .PORT      (4567)
  ) i_sim_jtag (
      .clock(clk_i),
      .reset(~rst_ni),
      .enable(sim_jtag_enable),
      .init_done(rst_ni),
      .jtag_TCK(sim_jtag_tck),
      .jtag_TMS(sim_jtag_tms),
      .jtag_TDI(sim_jtag_tdi),
      .jtag_TRSTn(sim_jtag_trstn),
      .jtag_TDO_data(sim_jtag_tdo),
      .jtag_TDO_driven(1'b1),
      .exit()
  );

  assign mux_jtag_tck   = JTAG_DPI ? sim_jtag_tck : jtag_tck_i;
  assign mux_jtag_tms   = JTAG_DPI ? sim_jtag_tms : jtag_tms_i;
  assign mux_jtag_tdi   = JTAG_DPI ? sim_jtag_tdi : jtag_tdi_i;
  assign mux_jtag_trstn = JTAG_DPI ? sim_jtag_trstn : jtag_trst_ni;

  assign sim_jtag_tdo   = JTAG_DPI ? mux_jtag_tdo : '0;
  assign jtag_tdo_o     = !JTAG_DPI ? mux_jtag_tdo : '0;

  // ------------
  // SPI Flash
  // ------------
  // Flash used for booting (execute from flash or copy from flash)
  spiflash flash_boot_i (
      .csb(spi_flash_csb[0]),
      .clk(spi_flash_sck),
      .io0(spi_flash_sd_io[0]),  // MOSI
      .io1(spi_flash_sd_io[1]),  // MISO
      .io2(spi_flash_sd_io[2]),
      .io3(spi_flash_sd_io[3])
  );

endmodule  // testharness
