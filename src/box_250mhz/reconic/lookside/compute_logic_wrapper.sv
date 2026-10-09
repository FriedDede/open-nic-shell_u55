//==============================================================================
// Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT
//
//==============================================================================
`timescale 1ns/1ps

module compute_logic_wrapper
  import axi_pkg::*;
  import dpa_pkg::*; 
# (
  parameter AXIL_ADDR_WIDTH  = 12,
  parameter AXIL_DATA_WIDTH  = 32,
  parameter AXIS_DATA_WIDTH  = 512,
  parameter AXIS_KEEP_WIDTH  = 64,
  // 1: CE reaches DRAM through the cache, 0: cache bypassed
  parameter bit ENABLE_CACHE = 1'b1
) (
  // register control interface
  input         s_axil_awvalid,
  input  [31:0] s_axil_awaddr,
  output        s_axil_awready,
  input         s_axil_wvalid,
  input  [31:0] s_axil_wdata,
  output        s_axil_wready,
  output        s_axil_bvalid,
  output  [1:0] s_axil_bresp,
  input         s_axil_bready,
  input         s_axil_arvalid,
  input  [31:0] s_axil_araddr,
  output        s_axil_arready,
  output        s_axil_rvalid,
  output [31:0] s_axil_rdata,
  output  [1:0] s_axil_rresp,
  input         s_axil_rready,
  
  // master AXI interface for device memory access
  output            m_axi_dram_awid,
  output   [63 : 0] m_axi_dram_awaddr,
  output    [3 : 0] m_axi_dram_awqos,
  output    [7 : 0] m_axi_dram_awlen,
  output    [2 : 0] m_axi_dram_awsize,
  output    [1 : 0] m_axi_dram_awburst,
  output    [3 : 0] m_axi_dram_awcache,
  output    [2 : 0] m_axi_dram_awprot,
  output            m_axi_dram_awvalid,
  input             m_axi_dram_awready,
  output  [511 : 0] m_axi_dram_wdata,
  output   [63 : 0] m_axi_dram_wstrb,
  output            m_axi_dram_wlast,
  output            m_axi_dram_wvalid,
  input             m_axi_dram_wready,
  output            m_axi_dram_awlock,
  input             m_axi_dram_bid,
  input     [1 : 0] m_axi_dram_bresp,
  input             m_axi_dram_bvalid,
  output            m_axi_dram_bready,
  output            m_axi_dram_arid,
  output   [63 : 0] m_axi_dram_araddr,
  output    [7 : 0] m_axi_dram_arlen,
  output    [2 : 0] m_axi_dram_arsize,
  output    [1 : 0] m_axi_dram_arburst,
  output    [3 : 0] m_axi_dram_arcache,
  output    [2 : 0] m_axi_dram_arprot,
  output            m_axi_dram_arvalid,
  input             m_axi_dram_arready,
  input             m_axi_dram_rid,
  input   [511 : 0] m_axi_dram_rdata,
  input     [1 : 0] m_axi_dram_rresp,
  input             m_axi_dram_rlast,
  input             m_axi_dram_rvalid,
  output            m_axi_dram_rready,
  output            m_axi_dram_arlock,
  output     [3:0]  m_axi_dram_arqos,
  output    [3 : 0] m_axi_dram_awregion,
  output    [3 : 0] m_axi_dram_arregion,
  output [cache_ss_pkg::UserWidth-1 : 0] m_axi_dram_awuser,
  output [cache_ss_pkg::UserWidth-1 : 0] m_axi_dram_wuser,
  output [cache_ss_pkg::UserWidth-1 : 0] m_axi_dram_aruser,
  input  [cache_ss_pkg::UserWidth-1 : 0] m_axi_dram_buser,
  input  [cache_ss_pkg::UserWidth-1 : 0] m_axi_dram_ruser,

  input          axil_aclk,
  input          axil_rstn,
  input          axis_aclk,
  input          axis_rstn
);

logic [1:0] m_axi_awlock_tmp;
logic [1:0] m_axi_arlock_tmp;

logic [31:0] ctl_cmd_fifo_dout;
logic        ctl_cmd_fifo_empty_n;
logic        ctl_cmd_fifo_rd_en;

logic [31:0] ker_status_fifo_din;
logic        ker_status_fifo_full_n;
logic        ker_status_fifo_wr_en;

logic cl_box_start;
logic cl_box_done;
logic cl_box_idle;
logic cl_box_ready;

logic [31:0] a_baseaddr;
logic        a_baseaddr_ap_vld;
logic [31:0] b_baseaddr;
logic        b_baseaddr_ap_vld;
logic [31:0] c_baseaddr;
logic        c_baseaddr_ap_vld;
logic [31:0] a_row;
logic        a_row_ap_vld;
logic [31:0] a_col;
logic        a_col_ap_vld;
logic [31:0] b_col;
logic        b_col_ap_vld;
logic [31:0] work_id;
logic        work_id_ap_vld;

logic ap_start;
logic ap_done;
logic ap_idle;
logic ap_ready;

logic [63:0] a_baseaddr_reg;
logic [63:0] b_baseaddr_reg;
logic [63:0] c_baseaddr_reg;
logic [31:0] a_row_reg;
logic [31:0] a_col_reg;
logic [31:0] b_col_reg;
logic [31:0] work_id_reg;

localparam COMPUTE_IDLE = 1'b0;
localparam COMPUTE_BUSY = 1'b1;

logic comp_state;
logic new_req;
logic new_req_reg;

// control command processor
// control_command_processor #(
//   .AXIL_ADDR_WIDTH (AXIL_ADDR_WIDTH),
//   .AXIL_DATA_WIDTH (AXIL_DATA_WIDTH)
// ) ctl_cmd_proc (
//   .s_axil_awvalid(s_axil_awvalid),
//   .s_axil_awaddr (s_axil_awaddr[AXIL_ADDR_WIDTH-1:0]),
//   .s_axil_awready(s_axil_awready),
//   .s_axil_wvalid (s_axil_wvalid ),
//   .s_axil_wdata  (s_axil_wdata  ),
//   .s_axil_wready (s_axil_wready ),
//   .s_axil_bvalid (s_axil_bvalid ),
//   .s_axil_bresp  (s_axil_bresp  ),
//   .s_axil_bready (s_axil_bready ),
//   .s_axil_arvalid(s_axil_arvalid),
//   .s_axil_araddr (s_axil_araddr[AXIL_ADDR_WIDTH-1:0]),
//   .s_axil_arready(s_axil_arready),
//   .s_axil_rvalid (s_axil_rvalid ),
//   .s_axil_rdata  (s_axil_rdata  ),
//   .s_axil_rresp  (s_axil_rresp  ),
//   .s_axil_rready (s_axil_rready ),
// 
//   .cl_box_idle         (cl_box_idle),
//   .cl_box_start        (cl_box_start),
//   .cl_box_done         (cl_box_done),
//   .cl_kernel_idle      (ap_idle),
//   .cl_kernel_done      (ap_done),
//   .ctl_cmd_fifo_dout   (ctl_cmd_fifo_dout),
//   .ctl_cmd_fifo_empty_n(ctl_cmd_fifo_empty_n),
//   .ctl_cmd_fifo_rd_en  (ctl_cmd_fifo_rd_en),
// 
//   .ker_status_fifo_din   (ker_status_fifo_din),
//   .ker_status_fifo_full_n(ker_status_fifo_full_n),
//   .ker_status_fifo_wr_en (ker_status_fifo_wr_en),
// 
//   .axil_aclk (axil_aclk),
//   .axil_arstn(axil_rstn),
//   .axis_aclk (axis_aclk),
//   .axis_arstn(axis_rstn)
// );
// 
// // Compute_Logic box
// cl_box cl_box_wrapper (
//   //.ap_local_block              (),
//   //.ap_local_deadlock           (),
//   .ap_clk                      (axis_aclk),
//   .ap_rst                      (~axis_rstn),
//   .ap_start                    (cl_box_start),
//   .ap_done                     (cl_box_done),
//   .ap_idle                     (cl_box_idle),
//   .ap_ready                    (cl_box_ready),
//   .ctl_cmd_stream_dout         (ctl_cmd_fifo_dout),
//   .ctl_cmd_stream_empty_n      (ctl_cmd_fifo_empty_n),
//   .ctl_cmd_stream_read         (ctl_cmd_fifo_rd_en),
//   .a_baseaddr                  (a_baseaddr),
//   .a_baseaddr_ap_vld           (a_baseaddr_ap_vld),
//   .b_baseaddr                  (b_baseaddr),
//   .b_baseaddr_ap_vld           (b_baseaddr_ap_vld),
//   .c_baseaddr                  (c_baseaddr),
//   .c_baseaddr_ap_vld           (c_baseaddr_ap_vld),
//   .a_row                       (a_row),
//   .a_row_ap_vld                (a_row_ap_vld),
//   .a_col                       (a_col),
//   .a_col_ap_vld                (a_col_ap_vld),
//   .b_col                       (b_col),
//   .b_col_ap_vld                (b_col_ap_vld),
//   .work_id                     (work_id),
//   .work_id_ap_vld              (work_id_ap_vld)
// );

AXI_BUS #(
    .AXI_ADDR_WIDTH ( dpa_pkg::ce_AddrWidth     ),
    .AXI_DATA_WIDTH ( dpa_pkg::ce_DataWidth     ),
    .AXI_ID_WIDTH   ( dpa_pkg::IdWidth          ),
    .AXI_USER_WIDTH ( dpa_pkg::ce_UserWidth     )
) axi_ctrl_to_desc ();

// ------------------------------------------------------------------
// Register control: s_axil reads/writes the descriptor memory directly
// (axil_aclk domain); the descriptor memory is shared by the host and all CEs
// ------------------------------------------------------------------
AXI_LITE #(
  .AXI_ADDR_WIDTH ( dpa_pkg::ce_AddrWidth ),
  .AXI_DATA_WIDTH ( AXIL_DATA_WIDTH       )
) axil_ctrl ();

AXI_BUS #(
  .AXI_ADDR_WIDTH ( dpa_pkg::ce_AddrWidth ),
  .AXI_DATA_WIDTH ( AXIL_DATA_WIDTH       ),
  .AXI_ID_WIDTH   ( dpa_pkg::IdWidth      ),
  .AXI_USER_WIDTH ( dpa_pkg::ce_UserWidth )
) axi_ctrl_narrow ();

assign axil_ctrl.aw_addr  = s_axil_awaddr;
assign axil_ctrl.aw_prot  = '0;
assign axil_ctrl.aw_valid = s_axil_awvalid;
assign s_axil_awready     = axil_ctrl.aw_ready;

assign axil_ctrl.w_data   = s_axil_wdata;
assign axil_ctrl.w_strb   = '1; // s_axil carries no wstrb: full-word writes
assign axil_ctrl.w_valid  = s_axil_wvalid;
assign s_axil_wready      = axil_ctrl.w_ready;

assign s_axil_bresp       = axil_ctrl.b_resp;
assign s_axil_bvalid      = axil_ctrl.b_valid;
assign axil_ctrl.b_ready  = s_axil_bready;

assign axil_ctrl.ar_addr  = s_axil_araddr;
assign axil_ctrl.ar_prot  = '0;
assign axil_ctrl.ar_valid = s_axil_arvalid;
assign s_axil_arready     = axil_ctrl.ar_ready;

assign s_axil_rdata       = axil_ctrl.r_data;
assign s_axil_rresp       = axil_ctrl.r_resp;
assign s_axil_rvalid      = axil_ctrl.r_valid;
assign axil_ctrl.r_ready  = s_axil_rready;

// AXI-Lite -> AXI4 (single-beat, ID 0)
axi_lite_to_axi_intf #(
  .AXI_DATA_WIDTH ( AXIL_DATA_WIDTH )
) i_ctrl_lite_to_axi (
  .in             ( axil_ctrl       ),
  .slv_aw_cache_i ( '0              ),
  .slv_ar_cache_i ( '0              ),
  .out            ( axi_ctrl_narrow )
);

// 32 -> 64 bit to match the descriptor memory data width
axi_dw_converter_intf #(
  .AXI_ID_WIDTH            ( dpa_pkg::IdWidth      ),
  .AXI_ADDR_WIDTH          ( dpa_pkg::ce_AddrWidth ),
  .AXI_SLV_PORT_DATA_WIDTH ( AXIL_DATA_WIDTH       ),
  .AXI_MST_PORT_DATA_WIDTH ( dpa_pkg::ce_DataWidth ),
  .AXI_USER_WIDTH          ( dpa_pkg::ce_UserWidth )
) i_ctrl_dw_upsize (
  .clk_i  ( axil_aclk           ),
  .rst_ni ( axil_rstn           ),
  .slv    ( axi_ctrl_narrow     ),
  .mst    ( axi_ctrl_to_desc    )
);

// mmult kernel_mmult (
  //   //.ap_local_block   (),
  //   //.ap_local_deadlock(),
  //   .ap_clk           (axis_aclk),
  //   .ap_rst_n         (axis_rstn),
  //   .ap_start         (ap_start),
  //   .ap_done          (ap_done),
  //   .ap_idle          (ap_idle),
  //   .ap_ready         (ap_ready),
  //   .m_axi_systolic_AWVALID (m_axi_awvalid),
  //   .m_axi_systolic_AWREADY (m_axi_awready),
  //   .m_axi_systolic_AWADDR  (m_axi_awaddr),
  //   .m_axi_systolic_AWID    (m_axi_awid),
  //   .m_axi_systolic_AWLEN   (m_axi_awlen),
  //   .m_axi_systolic_AWSIZE  (m_axi_awsize),
  //   .m_axi_systolic_AWBURST (m_axi_awburst),
  //   .m_axi_systolic_AWLOCK  (m_axi_awlock_tmp),
  //   .m_axi_systolic_AWCACHE (m_axi_awcache),
  //   .m_axi_systolic_AWPROT  (m_axi_awprot),
  //   .m_axi_systolic_AWQOS   (m_axi_awqos),
  //   .m_axi_systolic_AWREGION(),
  //   .m_axi_systolic_AWUSER  (),
  //   .m_axi_systolic_WVALID  (m_axi_wvalid),
  //   .m_axi_systolic_WREADY  (m_axi_wready),
  //   .m_axi_systolic_WDATA   (m_axi_wdata),
  //   .m_axi_systolic_WSTRB   (m_axi_wstrb),
  //   .m_axi_systolic_WLAST   (m_axi_wlast),
  //   .m_axi_systolic_WID     (),
  //   .m_axi_systolic_WUSER   (),
  //   .m_axi_systolic_ARVALID (m_axi_arvalid),
  //   .m_axi_systolic_ARREADY (m_axi_arready),
  //   .m_axi_systolic_ARADDR  (m_axi_araddr),
  //   .m_axi_systolic_ARID    (m_axi_arid),
  //   .m_axi_systolic_ARLEN   (m_axi_arlen),
  //   .m_axi_systolic_ARSIZE  (m_axi_arsize),
  //   .m_axi_systolic_ARBURST (m_axi_arburst),
  //   .m_axi_systolic_ARLOCK  (m_axi_arlock_tmp),
  //   .m_axi_systolic_ARCACHE (m_axi_arcache),
  //   .m_axi_systolic_ARPROT  (m_axi_arprot),
  //   .m_axi_systolic_ARQOS   (m_axi_arqos),
  //   .m_axi_systolic_ARREGION(),
  //   .m_axi_systolic_ARUSER  (),
  //   .m_axi_systolic_RVALID  (m_axi_rvalid),
  //   .m_axi_systolic_RREADY  (m_axi_rready),
  //   .m_axi_systolic_RDATA   (m_axi_rdata),
  //   .m_axi_systolic_RLAST   (m_axi_rlast),
  //   .m_axi_systolic_RID     (m_axi_rid),
  //   .m_axi_systolic_RUSER   (),
  //   .m_axi_systolic_RRESP   (m_axi_rresp),
  //   .m_axi_systolic_BVALID  (m_axi_bvalid),
  //   .m_axi_systolic_BREADY  (m_axi_bready),
  //   .m_axi_systolic_BRESP   (m_axi_bresp),
  //   .m_axi_systolic_BID     (m_axi_bid),
  //   .m_axi_systolic_BUSER   (),
  //   .work_id_out_stream_din   (ker_status_fifo_din),
  //   .work_id_out_stream_full_n(ker_status_fifo_full_n),
  //   .work_id_out_stream_write (ker_status_fifo_wr_en),
  //   .a             (a_baseaddr_reg),
  //   .b             (b_baseaddr_reg),
  //   .c             (c_baseaddr_reg),
  //   .a_row         (a_row_reg),
  //   .a_row_ap_vld  (new_req_reg),
  //   .a_col         (a_col_reg),
  //   .a_col_ap_vld  (new_req_reg),
  //   .b_col         (b_col_reg),
  //   .b_col_ap_vld  (new_req_reg),
  //   .work_id       (work_id_reg),
  //   .work_id_ap_vld(new_req_reg)
// );

// ------------------------------------------------------------------
// Compute subsystem
// ------------------------------------------------------------------
//`ifdef __synthesis__
`include "axi_assign.svh"
`include "axi_typedef.svh"
`include "hbm_axi.svh"
                          
logic ce_clk;
logic internal_ce_rstn;
logic internal_axis_rstn;
logic pll_locked;

assign internal_axis_rstn = axis_rstn;

// Compute engine clock domain
  // ce to descriptor ring
  dpa_pkg::axim64_core2mem_req_t [dpa_pkg::DRAM_CH_NUMBER-1 : 0] m_axim_ce2desc_req;
  dpa_pkg::axim64_core2mem_resp_t [dpa_pkg::DRAM_CH_NUMBER-1 : 0] m_axim_ce2desc_resp;
  // ce to cache
  dpa_pkg::axim64_core2mem_req_t [dpa_pkg::DRAM_CH_NUMBER-1 : 0] m_axim_ce2cache_req;
  dpa_pkg::axim64_core2mem_resp_t [dpa_pkg::DRAM_CH_NUMBER-1 : 0] m_axim_ce2cache_resp;

// dram clock domain
AXI_BUS #(
  .AXI_ADDR_WIDTH (cache_ss_pkg::AddrWidth),
  .AXI_DATA_WIDTH (cache_ss_pkg::DataWidth),
  .AXI_ID_WIDTH   (cache_ss_pkg::IdWidth),
  .AXI_USER_WIDTH (cache_ss_pkg::UserWidth)
) axim_dpa_to_dram[dpa_pkg::DRAM_CH_NUMBER-1:0]();

`AXI_ASSIGN_MASTER(m_axi_dram,axim_dpa_to_dram[0])

// Compute engine parameters are in dpa_pkg.sv
compute_engine compute_engine_instance (

  .clk(ce_clk),
  .core_areset_n(internal_ce_rstn),

  .m_axim_ce2mem_req(m_axim_ce2cache_req),
  .m_axim_ce2mem_resp(m_axim_ce2cache_resp),

  .m_axim_ce2cfu_req(m_axim_ce2desc_req),
  .m_axim_ce2cfu_resp(m_axim_ce2desc_resp)
);

// compute engine clock
xlnx_clk_gen i_xlnx_clk_gen (
    .clk_out1 ( ce_clk      ),  // Core 50 MHz
    .reset    ( ~axis_rstn  ),
    .locked   ( pll_locked  ),
    .clk_in1  ( axis_aclk   )   // 250 Mhz ref clk
);

rstgen i_rstgen_main (
      .clk_i        ( ce_clk                    ),
      .rst_ni       ( pll_locked & (axis_rstn)  ),
      .test_mode_i  ( '0                          ),
      .rst_no       ( internal_ce_rstn            ),
      .init_no      (                             ) // keep open
  );

// ------------------------------------------------
//  DESCRIPTOR/COMPLETION RING Memory
// ------------------------------------------------

// One 4 KB descriptor memory shared by the host (register control) and every
// CE. desc_mux prepends its slave-port index to the ID, so its master port is
// dpa_pkg::desc_bram_id_width wide. The full ID must reach axi_bram_desc
// (CONFIG.ID_WIDTH in vivado_ip/axi_bram_desc.tcl): dropping the port-select
// bits misroutes B/R responses between the masters.

localparam int unsigned DESC_MEM_ADDR_WIDTH = 12;                       // 4 KB
localparam int unsigned DESC_MUX_SLV_PORTS  = dpa_pkg::DRAM_CH_NUMBER + 1; // CEs + host
localparam int unsigned DESC_MUX_HOST_PORT  = dpa_pkg::DRAM_CH_NUMBER;

// descriptor memory clock domain
logic desc_mem_clk;
logic desc_mem_reset_n;

assign desc_mem_clk     = axis_aclk;
assign desc_mem_reset_n = internal_axis_rstn;

// desc_mux slave ports: [DRAM_CH_NUMBER-1:0] CEs, [DESC_MUX_HOST_PORT] host
AXI_BUS #(
    .AXI_ADDR_WIDTH ( dpa_pkg::ce_AddrWidth       ),
    .AXI_DATA_WIDTH ( dpa_pkg::ce_DataWidth       ),
    .AXI_ID_WIDTH   ( dpa_pkg::ce_IdWidthToUncore ),
    .AXI_USER_WIDTH ( dpa_pkg::ce_UserWidth       )
) axi_cdc2mux_desc [DESC_MUX_SLV_PORTS-1:0] ();

// clock domain conversion: riscv -> desc_mem, one per CE
for (genvar i = 0; i < dpa_pkg::DRAM_CH_NUMBER; i++) begin : ce_desc_cdc

  AXI_BUS #(
      .AXI_ADDR_WIDTH (dpa_pkg::ce_AddrWidth),
      .AXI_DATA_WIDTH (dpa_pkg::ce_DataWidth),
      .AXI_ID_WIDTH   (dpa_pkg::ce_IdWidthToUncore),
      .AXI_USER_WIDTH (dpa_pkg::ce_UserWidth)
  ) axi_ce2cdc_desc ();

  `AXI_ASSIGN_FROM_REQ (axi_ce2cdc_desc, m_axim_ce2desc_req[i])
  `AXI_ASSIGN_TO_RESP  (m_axim_ce2desc_resp[i], axi_ce2cdc_desc)

  axi_cdc_intf #(
      .AXI_ID_WIDTH   (dpa_pkg::ce_IdWidthToUncore),
      .AXI_ADDR_WIDTH (dpa_pkg::ce_AddrWidth),
      .AXI_DATA_WIDTH (dpa_pkg::ce_DataWidth),
      .AXI_USER_WIDTH (dpa_pkg::ce_UserWidth),
      .LOG_DEPTH(3),
      .SYNC_STAGES(2)
  ) axi_cdc_rv_desc (
      .src_clk_i  (ce_clk),
      .src_rst_ni (internal_ce_rstn),
      .src        (axi_ce2cdc_desc),

      .dst_clk_i  (desc_mem_clk),
      .dst_rst_ni (desc_mem_reset_n),
      .dst        (axi_cdc2mux_desc[i])
  );

end : ce_desc_cdc

// clock domain conversion: axil_aclk (register control) -> desc_mem

AXI_BUS #(
  .AXI_ADDR_WIDTH (dpa_pkg::ce_AddrWidth),
  .AXI_DATA_WIDTH (dpa_pkg::ce_DataWidth),
  .AXI_ID_WIDTH   (dpa_pkg::IdWidth),
  .AXI_USER_WIDTH (dpa_pkg::ce_UserWidth)
) axi_ctrl_cdc2mem ();

axi_cdc_intf #(
  .AXI_ID_WIDTH   (dpa_pkg::IdWidth),
  .AXI_ADDR_WIDTH (dpa_pkg::ce_AddrWidth),
  .AXI_DATA_WIDTH (dpa_pkg::ce_DataWidth),
  .AXI_USER_WIDTH (dpa_pkg::ce_UserWidth),
  .LOG_DEPTH(3),
  .SYNC_STAGES(2)
) axi_cdc_ctrl_desc (
    .src_clk_i  (axil_aclk),
    .src_rst_ni (axil_rstn),
    .src        (axi_ctrl_to_desc),

    .dst_clk_i  (desc_mem_clk),
    .dst_rst_ni (desc_mem_reset_n),
    .dst        (axi_ctrl_cdc2mem)
);

// host ID (dpa_pkg::IdWidth) zero-extended to the CE ID width on the way in,
// truncated back on B/R: the mux returns the ID it was given, so nothing is lost
`AXI_ASSIGN(axi_cdc2mux_desc[DESC_MUX_HOST_PORT], axi_ctrl_cdc2mem)

// host + CEs -> descriptor memory access mux

AXI_BUS #(
    .AXI_ADDR_WIDTH ( dpa_pkg::ce_AddrWidth       ),
    .AXI_DATA_WIDTH ( dpa_pkg::ce_DataWidth       ),
    .AXI_ID_WIDTH   ( dpa_pkg::desc_bram_id_width ),
    .AXI_USER_WIDTH ( dpa_pkg::ce_UserWidth       )
) axi_cdc2desc_mem();

axi_mux_intf #(
    .SLV_AXI_ID_WIDTH (dpa_pkg::ce_IdWidthToUncore),
    .MST_AXI_ID_WIDTH (dpa_pkg::desc_bram_id_width),
    .AXI_ADDR_WIDTH   (dpa_pkg::ce_AddrWidth       ),
    .AXI_DATA_WIDTH   (dpa_pkg::ce_DataWidth       ),
    .AXI_USER_WIDTH   (dpa_pkg::ce_UserWidth       ),
    .NO_SLV_PORTS     (DESC_MUX_SLV_PORTS),
    .MAX_W_TRANS      (1),
    .FALL_THROUGH     (0),
    .SPILL_AW (1), .SPILL_W (1), .SPILL_B (1),
    .SPILL_AR (1), .SPILL_R (1)
  ) desc_mux (
    .clk_i  (desc_mem_clk),
    .rst_ni (desc_mem_reset_n),
    .test_i ('0),
    .slv    (axi_cdc2mux_desc),
    .mst    (axi_cdc2desc_mem)
  );

// Descriptor memory
axi_bram_desc desc_mem (
    .s_axi_aclk     (desc_mem_clk),
    .s_axi_aresetn  (desc_mem_reset_n),
    .s_axi_awid     ( axi_cdc2desc_mem.aw_id     ),
    .s_axi_awaddr   ( axi_cdc2desc_mem.aw_addr[DESC_MEM_ADDR_WIDTH-1:0] ),
    .s_axi_awlen    ( axi_cdc2desc_mem.aw_len    ),
    .s_axi_awsize   ( axi_cdc2desc_mem.aw_size   ),
    .s_axi_awburst  ( axi_cdc2desc_mem.aw_burst  ),
    .s_axi_awlock   ( axi_cdc2desc_mem.aw_lock   ),
    .s_axi_awcache  ( axi_cdc2desc_mem.aw_cache  ),
    .s_axi_awprot   ( axi_cdc2desc_mem.aw_prot   ),
    .s_axi_awvalid  ( axi_cdc2desc_mem.aw_valid  ),
    .s_axi_awready  ( axi_cdc2desc_mem.aw_ready  ),
    .s_axi_wdata    ( axi_cdc2desc_mem.w_data    ),
    .s_axi_wstrb    ( axi_cdc2desc_mem.w_strb    ),
    .s_axi_wlast    ( axi_cdc2desc_mem.w_last    ),
    .s_axi_wvalid   ( axi_cdc2desc_mem.w_valid   ),
    .s_axi_wready   ( axi_cdc2desc_mem.w_ready   ),
    .s_axi_bid      ( axi_cdc2desc_mem.b_id      ),
    .s_axi_bresp    ( axi_cdc2desc_mem.b_resp    ),
    .s_axi_bvalid   ( axi_cdc2desc_mem.b_valid   ),
    .s_axi_bready   ( axi_cdc2desc_mem.b_ready   ),
    .s_axi_arid     ( axi_cdc2desc_mem.ar_id     ),
    .s_axi_araddr   ( axi_cdc2desc_mem.ar_addr[DESC_MEM_ADDR_WIDTH-1:0] ),
    .s_axi_arlen    ( axi_cdc2desc_mem.ar_len    ),
    .s_axi_arsize   ( axi_cdc2desc_mem.ar_size   ),
    .s_axi_arburst  ( axi_cdc2desc_mem.ar_burst  ),
    .s_axi_arlock   ( axi_cdc2desc_mem.ar_lock   ),
    .s_axi_arcache  ( axi_cdc2desc_mem.ar_cache  ),
    .s_axi_arprot   ( axi_cdc2desc_mem.ar_prot   ),
    .s_axi_arvalid  ( axi_cdc2desc_mem.ar_valid  ),
    .s_axi_arready  ( axi_cdc2desc_mem.ar_ready  ),
    .s_axi_rid      ( axi_cdc2desc_mem.r_id      ),
    .s_axi_rdata    ( axi_cdc2desc_mem.r_data    ),
    .s_axi_rresp    ( axi_cdc2desc_mem.r_resp    ),
    .s_axi_rlast    ( axi_cdc2desc_mem.r_last    ),
    .s_axi_rvalid   ( axi_cdc2desc_mem.r_valid   ),
    .s_axi_rready   ( axi_cdc2desc_mem.r_ready   )
);

assign axi_cdc2desc_mem.b_user = '0;
assign axi_cdc2desc_mem.r_user = '0;

logic cache_arstn;
logic cache_aclk;
logic cache_pu_rstn [dpa_pkg::DRAM_CH_NUMBER];

for (genvar i = 0; i < dpa_pkg::DRAM_CH_NUMBER; i++) begin : cache_pu_rst
  logic [1:0] rst_q;
  (* MAX_FANOUT = 256 *) logic rstn_q;

  always_ff @(posedge cache_aclk or negedge cache_arstn) begin
    if (!cache_arstn) begin
      rst_q  <= 2'b00;
      rstn_q <= 1'b0;
    end else begin
      rst_q  <= {rst_q[0], 1'b1};
      rstn_q <= rst_q[1];
    end
  end

  assign cache_pu_rstn[i] = rstn_q;
end : cache_pu_rst


AXI_BUS #(
  .AXI_ADDR_WIDTH (cache_ss_pkg::AddrWidth),
  .AXI_DATA_WIDTH (cache_ss_pkg::DataWidth),
  .AXI_ID_WIDTH   (cache_ss_pkg::IdWidth),
  .AXI_USER_WIDTH (cache_ss_pkg::UserWidth)
) axim_ce_to_cache[dpa_pkg::DRAM_CH_NUMBER-1:0]();

for (genvar i = 0; i < dpa_pkg::DRAM_CH_NUMBER; i++) begin : cdc_ce_cache

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( dpa_pkg::ce_AddrWidth       ),
        .AXI_DATA_WIDTH ( dpa_pkg::ce_DataWidth       ),
        .AXI_ID_WIDTH   ( dpa_pkg::ce_IdWidthToUncore ),
        .AXI_USER_WIDTH ( dpa_pkg::ce_UserWidth       )
    ) axim_ce2cdc ();

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( dpa_pkg::ce_AddrWidth       ),
        .AXI_DATA_WIDTH ( dpa_pkg::ce_DataWidth       ),
        .AXI_ID_WIDTH   ( dpa_pkg::ce_IdWidthToUncore ),
        .AXI_USER_WIDTH ( dpa_pkg::ce_UserWidth       )
    ) axim_cdc2dw ();


    `AXI_ASSIGN_FROM_REQ (axim_ce2cdc, m_axim_ce2cache_req[i])
    `AXI_ASSIGN_TO_RESP  (m_axim_ce2cache_resp[i], axim_ce2cdc)

    // clock domain conversion: riscv -> cache
    axi_cdc_intf #(
        .AXI_ID_WIDTH   (dpa_pkg::ce_IdWidthToUncore),
        .AXI_ADDR_WIDTH (dpa_pkg::ce_AddrWidth),
        .AXI_DATA_WIDTH (dpa_pkg::ce_DataWidth),
        .AXI_USER_WIDTH (dpa_pkg::ce_UserWidth),
        .LOG_DEPTH      (3),
        .SYNC_STAGES    (2)
    ) axi_cdc_ce_cache (
        .src_clk_i  (ce_clk),
        .src_rst_ni (internal_ce_rstn),
        .src        (axim_ce2cdc),

        .dst_clk_i  (cache_aclk),
        .dst_rst_ni (cache_pu_rstn[i]),
        .dst        (axim_cdc2dw)
    );

    axi_dw_converter_intf #(
      .AXI_ID_WIDTH            (dpa_pkg::ce_IdWidthToUncore),
      .AXI_ADDR_WIDTH          (dpa_pkg::ce_AddrWidth),
      .AXI_SLV_PORT_DATA_WIDTH (dpa_pkg::ce_DataWidth),

      .AXI_MST_PORT_DATA_WIDTH (cache_ss_pkg::DataWidth),
      .AXI_USER_WIDTH          (dpa_pkg::ce_UserWidth)
    ) i_ce_dw_upsize (
      .clk_i  (cache_aclk),
      .rst_ni (cache_pu_rstn[i]),

      .slv    (axim_cdc2dw),
      .mst    (axim_ce_to_cache[i])
    );

end : cdc_ce_cache


for (genvar i = 0; i < dpa_pkg::DRAM_CH_NUMBER; i++) begin : rx_cache
  if (ENABLE_CACHE) begin : gen_cache
    cache_axi_wrapper #(
    .ADDR_WIDTH(cache_ss_pkg::AddrWidth),
    .DATA_WIDTH(cache_ss_pkg::DataWidth),
    .ID_WIDTH(cache_ss_pkg::IdWidth),
    .CACHE_BLOCK_SIZE(cache_ss_pkg::CACHE_BLOCK_SIZE),
    .CACHE_SIZE(cache_ss_pkg::CACHE_SIZE)
  ) cache_axi_wrapper_instance (
    .aclk(cache_aclk),
    .aresetn(cache_pu_rstn[i]),

    .s_axi(axim_ce_to_cache[i]),

    .m_axi_mem(axim_dpa_to_dram[i]),

    .invalid_valid        ('0),
    .invalid_address_start('0),
    .invalid_address_end  ('0),
    .invalid_done         ()
  );
  end : gen_cache
  else begin : gen_no_cache
    // cache bypassed: upsized CE bus goes to DRAM (same bus params)
    `AXI_ASSIGN(axim_dpa_to_dram[i], axim_ce_to_cache[i])
  end : gen_no_cache
end: rx_cache

assign cache_aclk = axis_aclk;

rstgen i_rstgen_cache (
    .clk_i        ( cache_aclk                  ),
    .rst_ni       ( internal_axis_rstn          ),
    .test_mode_i  ( '0                          ),
    .rst_no       ( cache_arstn                 ),
    .init_no      (                             ) // keep open
);


// assign new_req = cl_box_done;
// 
// always_ff @(posedge axis_aclk) begin
//   if(!axis_rstn) begin
//     a_baseaddr_reg <= 64'd0;
//     b_baseaddr_reg <= 64'd0;
//     c_baseaddr_reg <= 64'd0;
//     a_row_reg      <= 32'd0;
//     a_col_reg      <= 32'd0;
//     b_col_reg      <= 32'd0;
//     work_id_reg    <= 32'd0;
// 
//     ap_start    <= 1'b0;
//     new_req_reg <= 1'b0;
//     comp_state  <= COMPUTE_IDLE;
//   end
//   else begin
//     ap_start <= 1'b0;
//     a_baseaddr_reg <= a_baseaddr_ap_vld ? {32'd0, a_baseaddr} : a_baseaddr_reg;
//     b_baseaddr_reg <= b_baseaddr_ap_vld ? {32'd0, b_baseaddr} : b_baseaddr_reg;
//     c_baseaddr_reg <= c_baseaddr_ap_vld ? {32'd0, c_baseaddr} : c_baseaddr_reg;
// 
//     a_row_reg     <= a_row_ap_vld ? a_row : a_row_reg;
//     a_col_reg     <= a_col_ap_vld ? a_col : a_col_reg;
//     b_col_reg     <= b_col_ap_vld ? b_col : b_col_reg;
// 
//     work_id_reg   <= work_id_ap_vld ? work_id : work_id_reg;
// 
//     new_req_reg <= new_req;
// 
//     case(comp_state)
//     COMPUTE_IDLE: begin
//       if(ap_idle) begin
//         if(new_req) begin
//           ap_start <= 1'b1;
//           comp_state <= COMPUTE_BUSY;
//         end
//         else begin
//           comp_state <= COMPUTE_IDLE;
//         end
//       end
//     end
//     COMPUTE_BUSY: begin
//       ap_start   <= ap_ready ? 1'b0 : 1'b1;
//       comp_state <= ap_done ? COMPUTE_IDLE : COMPUTE_BUSY;
//     end
//     endcase
//   end
// end

// ------------------------------------------------------------------
// DESIGN CONSTRAINT COMPLIANCE
// ------------------------------------------------------------------

// single channel memory 
// TODO: Multi channel support
initial begin
  if (dpa_pkg::DRAM_CH_NUMBER != 1) begin
    $fatal(1, "DRAM_CH_NUMBER must be equal to 1, as multichannel is not yet supported. Current value: %0d", dpa_pkg::DRAM_CH_NUMBER);
  end
end

// CE -> cache path has no ID width converter: the cache must take the CE's
// full ID, or the crossbar port-select bits are lost and responses misroute
initial begin
  assert (cache_ss_pkg::IdWidth == dpa_pkg::ce_IdWidthToUncore)
    else $fatal(1, "cache_ss_pkg::IdWidth (%0d) must equal dpa_pkg::ce_IdWidthToUncore (%0d)", cache_ss_pkg::IdWidth, dpa_pkg::ce_IdWidthToUncore);
end


endmodule: compute_logic_wrapper
