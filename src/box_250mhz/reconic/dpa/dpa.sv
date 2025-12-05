// *************************************************************************
//
// Copyright 2020 Xilinx, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// *************************************************************************
`timescale 1ns/1ps
module dpa 
  import axi_pkg::*;
  import dpa_pkg::*; #(
  parameter int MIN_PKT_LEN   = 64,
  parameter int MAX_PKT_LEN   = 1518,
  parameter int USE_PHYS_FUNC = 1,
  parameter int NUM_PHYS_FUNC = 1,
  parameter int NUM_QDMA      = 1,
  parameter int NUM_CMAC_PORT = 1
) (
  //input                          s_axil_awvalid,
  //input                   [31:0] s_axil_awaddr,
  //output                         s_axil_awready,
  //input                          s_axil_wvalid,
  //input                   [31:0] s_axil_wdata,
  //output                         s_axil_wready,
  //output                         s_axil_bvalid,
  //output                   [1:0] s_axil_bresp,
  //input                          s_axil_bready,
  //input                          s_axil_arvalid,
  //input                   [31:0] s_axil_araddr,
  //output                         s_axil_arready,
  //output                         s_axil_rvalid,
  //output                  [31:0] s_axil_rdata,
  //output                   [1:0] s_axil_rresp,
  //input                          s_axil_rready,

  // QDMA -> DPA
  input      [NUM_PHYS_FUNC*NUM_QDMA-1:0] s_axis_qdma2dpa_tx_tvalid,
  input  [512*NUM_PHYS_FUNC*NUM_QDMA-1:0] s_axis_qdma2dpa_tx_tdata,
  input   [64*NUM_PHYS_FUNC*NUM_QDMA-1:0] s_axis_qdma2dpa_tx_tkeep,
  input      [NUM_PHYS_FUNC*NUM_QDMA-1:0] s_axis_qdma2dpa_tx_tlast,
  input   [16*NUM_PHYS_FUNC*NUM_QDMA-1:0] s_axis_qdma2dpa_tx_tuser_size,
  input   [16*NUM_PHYS_FUNC*NUM_QDMA-1:0] s_axis_qdma2dpa_tx_tuser_src,
  input   [16*NUM_PHYS_FUNC*NUM_QDMA-1:0] s_axis_qdma2dpa_tx_tuser_dst,
  output     [NUM_PHYS_FUNC*NUM_QDMA-1:0] s_axis_qdma2dpa_tx_tready,

  // DPA -> QDMA
  output     [NUM_PHYS_FUNC*NUM_QDMA-1:0] m_axis_qdma2dpa_rx_tvalid,
  output [512*NUM_PHYS_FUNC*NUM_QDMA-1:0] m_axis_qdma2dpa_rx_tdata,
  output  [64*NUM_PHYS_FUNC*NUM_QDMA-1:0] m_axis_qdma2dpa_rx_tkeep,
  output     [NUM_PHYS_FUNC*NUM_QDMA-1:0] m_axis_qdma2dpa_rx_tlast,
  output  [16*NUM_PHYS_FUNC*NUM_QDMA-1:0] m_axis_qdma2dpa_rx_tuser_size,
  output  [16*NUM_PHYS_FUNC*NUM_QDMA-1:0] m_axis_qdma2dpa_rx_tuser_src,
  output  [16*NUM_PHYS_FUNC*NUM_QDMA-1:0] m_axis_qdma2dpa_rx_tuser_dst,
  input      [NUM_PHYS_FUNC*NUM_QDMA-1:0] m_axis_qdma2dpa_rx_tready,

  // 250BOX -> DPA
  input      [NUM_PHYS_FUNC*NUM_QDMA-1:0] s_axis_dpa2box_rx_tvalid,
  input  [512*NUM_PHYS_FUNC*NUM_QDMA-1:0] s_axis_dpa2box_rx_tdata,
  input   [64*NUM_PHYS_FUNC*NUM_QDMA-1:0] s_axis_dpa2box_rx_tkeep,
  input      [NUM_PHYS_FUNC*NUM_QDMA-1:0] s_axis_dpa2box_rx_tlast,
  input   [16*NUM_PHYS_FUNC*NUM_QDMA-1:0] s_axis_dpa2box_rx_tuser_size,
  input   [16*NUM_PHYS_FUNC*NUM_QDMA-1:0] s_axis_dpa2box_rx_tuser_src,
  input   [16*NUM_PHYS_FUNC*NUM_QDMA-1:0] s_axis_dpa2box_rx_tuser_dst,
  output     [NUM_PHYS_FUNC*NUM_QDMA-1:0] s_axis_dpa2box_rx_tready,

  // DPA -> 250BOX
  output     [NUM_PHYS_FUNC*NUM_QDMA-1:0] m_axis_dpa2box_tx_tvalid,
  output [512*NUM_PHYS_FUNC*NUM_QDMA-1:0] m_axis_dpa2box_tx_tdata,
  output  [64*NUM_PHYS_FUNC*NUM_QDMA-1:0] m_axis_dpa2box_tx_tkeep,
  output     [NUM_PHYS_FUNC*NUM_QDMA-1:0] m_axis_dpa2box_tx_tlast,
  output  [16*NUM_PHYS_FUNC*NUM_QDMA-1:0] m_axis_dpa2box_tx_tuser_size,
  output  [16*NUM_PHYS_FUNC*NUM_QDMA-1:0] m_axis_dpa2box_tx_tuser_src,
  output  [16*NUM_PHYS_FUNC*NUM_QDMA-1:0] m_axis_dpa2box_tx_tuser_dst,
  input      [NUM_PHYS_FUNC*NUM_QDMA-1:0] m_axis_dpa2box_tx_tready,

  // QDMA -> CE axi mm
  input           s_axim_qdma2dpa_clk,
  input    [63:0] s_axim_qdma2dpa_araddr,
  input    [1:0]  s_axim_qdma2dpa_arburst,
  input    [3:0]  s_axim_qdma2dpa_arcache,
  input    [3:0]  s_axim_qdma2dpa_arid,
  input    [7:0]  s_axim_qdma2dpa_arlen,
  input    [0:0]  s_axim_qdma2dpa_arlock,
  input    [2:0]  s_axim_qdma2dpa_arprot,
  output          s_axim_qdma2dpa_arready,
  input    [2:0]  s_axim_qdma2dpa_arsize,
  input    [31:0] s_axim_qdma2dpa_aruser,
  input           s_axim_qdma2dpa_arvalid,
  input    [63:0] s_axim_qdma2dpa_awaddr,
  input    [1:0]  s_axim_qdma2dpa_awburst,
  input    [3:0]  s_axim_qdma2dpa_awcache,
  input    [3:0]  s_axim_qdma2dpa_awid,
  input    [7:0]  s_axim_qdma2dpa_awlen,
  input    [0:0]  s_axim_qdma2dpa_awlock,
  input    [2:0]  s_axim_qdma2dpa_awprot,
  output          s_axim_qdma2dpa_awready,
  input    [2:0]  s_axim_qdma2dpa_awsize,
  input    [31:0] s_axim_qdma2dpa_awuser,
  input           s_axim_qdma2dpa_awvalid,
  output   [3:0]  s_axim_qdma2dpa_bid,
  input           s_axim_qdma2dpa_bready,
  output   [1:0]  s_axim_qdma2dpa_bresp,
  output          s_axim_qdma2dpa_bvalid,
  output   [511:0]s_axim_qdma2dpa_rdata,
  output   [3:0]  s_axim_qdma2dpa_rid,
  output          s_axim_qdma2dpa_rlast,
  input           s_axim_qdma2dpa_rready,
  output   [1:0]  s_axim_qdma2dpa_rresp,
  output          s_axim_qdma2dpa_rvalid,
  input    [511:0]s_axim_qdma2dpa_wdata,
  input           s_axim_qdma2dpa_wlast,
  output          s_axim_qdma2dpa_wready,
  input    [63:0] s_axim_qdma2dpa_wstrb,
  input    [63:0] s_axim_qdma2dpa_wuser,
  input           s_axim_qdma2dpa_wvalid,

  //input                   [15:0] mod_rstn,
  //output                  [15:0] mod_rst_done,

  input                          dpa_rstn,
  output                         dpa_rst_done,

  //input                          axil_aclk,

`ifdef __au55n__
  input                          ref_clk_100mhz,
`elsif __au55c__
  input                          ref_clk_100mhz,
`elsif __au50__
  input                          ref_clk_100mhz,
`elsif __au280__
  input                          ref_clk_100mhz,
`endif
  input                          axis_aclk,
  input  logic                   uart_rx,
  output logic                   uart_tx
);


localparam int AXI_ADDR_WIDTH = 64;
localparam int AXI_DATA_WIDTH = 512;
localparam int AXI_ID_WIDTH   = 16;
localparam int AXI_USER_WIDTH = 48;

AXI_BUS #(
  .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
  .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
  .AXI_ID_WIDTH(AXI_ID_WIDTH),
  .AXI_USER_WIDTH(AXI_USER_WIDTH)
) axim_rx [(NUM_QDMA*NUM_PHYS_FUNC)-1 : 0] ();

AXI_BUS #(
  .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
  .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
  .AXI_ID_WIDTH(AXI_ID_WIDTH),
  .AXI_USER_WIDTH(AXI_USER_WIDTH)
) axim_tx[(NUM_QDMA*NUM_PHYS_FUNC)-1 : 0] ();

AXI_BUS #(
    .AXI_ADDR_WIDTH ( ce_AddrWidth     ),
    .AXI_DATA_WIDTH ( ce_DataWidth     ),
    .AXI_ID_WIDTH   ( ce_IdWidthToUncore ),
    .AXI_USER_WIDTH ( ce_UserWidth     )
) axim_ce2dram[(12-1):0]();

// we need to switch reset polarity for core reset
logic clock_reset;
logic pll_locked;
assign clock_reset = ~dpa_rstn;
wire internal_dpa_rstn;
wire internal_axis_rstn;
wire dpa_axis_rst_done;

// ------------------------------------------------------------------
// DPA input packet routers
// ------------------------------------------------------------------

for (genvar i = 0; i < NUM_QDMA*NUM_PHYS_FUNC; i++) begin : rx_switch
    dpa_iconn dpa_iconn_rx(
      .aclk_0                 (axis_aclk),
      .aresetn_0              (internal_axis_rstn),
      .iconn_err_out          (),
      
      // axi stream input in the iconn
      // Tdest = 0 routes the stream to the axi stream output
      // Tdest = 1 routes the stream to the mm axi output
      .s_axis_iconn_in_tdata  (s_axis_dpa2box_rx_tdata[i*512 +: 512]),
      .s_axis_iconn_in_tdest  ('0),
      .s_axis_iconn_in_tkeep  (s_axis_dpa2box_rx_tkeep[i*64 +: 64]),
      .s_axis_iconn_in_tlast  (s_axis_dpa2box_rx_tlast[i]),
      .s_axis_iconn_in_tready (s_axis_dpa2box_rx_tready[i]),
      // Tuser is used to pass the size, src and dst of the packet
      .s_axis_iconn_in_tuser  ({
        s_axis_dpa2box_rx_tuser_dst[i*16 +: 16],
        s_axis_dpa2box_rx_tuser_src[i*16 +: 16],
        s_axis_dpa2box_rx_tuser_size[i*16 +: 16]
      }),
      .s_axis_iconn_in_tvalid (s_axis_dpa2box_rx_tvalid[i]),

      // axi stream output in the iconn
      .m_axis_iconn_out_tdata (m_axis_qdma2dpa_rx_tdata[i*512 +: 512]),
      .m_axis_iconn_out_tdest (),
      .m_axis_iconn_out_tkeep (m_axis_qdma2dpa_rx_tkeep[i*64 +: 64]),
      .m_axis_iconn_out_tlast (m_axis_qdma2dpa_rx_tlast[i]),
      .m_axis_iconn_out_tready(m_axis_qdma2dpa_rx_tready[i]),
      .m_axis_iconn_out_tuser({m_axis_qdma2dpa_rx_tuser_dst[i*16 +: 16],
                               m_axis_qdma2dpa_rx_tuser_src[i*16 +: 16],
                               m_axis_qdma2dpa_rx_tuser_size[i*16 +: 16]}),
      .m_axis_iconn_out_tvalid(m_axis_qdma2dpa_rx_tvalid[i]),

      // axim output in the iconn
      .m_axim_out_awaddr      (axim_rx[i].aw_addr),
      .m_axim_out_awburst     (axim_rx[i].aw_burst),
      .m_axim_out_awcache     (axim_rx[i].aw_cache),
      .m_axim_out_awid        (axim_rx[i].aw_id),
      .m_axim_out_awlen       (axim_rx[i].aw_len),
      .m_axim_out_awprot      (axim_rx[i].aw_prot),
      .m_axim_out_awready     (axim_rx[i].aw_ready),
      .m_axim_out_awsize      (axim_rx[i].aw_size),
      .m_axim_out_awuser      (axim_rx[i].aw_user),
      .m_axim_out_awvalid     (axim_rx[i].aw_valid),
      .m_axim_out_bready      (axim_rx[i].b_ready),
      .m_axim_out_bresp       (axim_rx[i].b_resp),
      .m_axim_out_bvalid      (axim_rx[i].b_valid),
      .m_axim_out_wdata       (axim_rx[i].w_data),
      .m_axim_out_wlast       (axim_rx[i].w_last),
      .m_axim_out_wready      (axim_rx[i].w_ready),
      .m_axim_out_wstrb       (axim_rx[i].w_strb),
      .m_axim_out_wvalid      (axim_rx[i].w_valid),

      .m_axis_sts_tdata       (),
      .m_axis_sts_tkeep       (),
      .m_axis_sts_tlast       (),
      .m_axis_sts_tready      (),
      .m_axis_sts_tvalid      (),
      // tdata provides the starting address to the axis -> axim converter
      // https://docs.amd.com/r/en-US/pg022_axi_datamover/Command-Interface
      // the stream is written to the axim channel as N byte burst from the starting
      // address upward.
      .s_axis_cmd_tdata       (),
      .s_axis_cmd_tready      (),
      .s_axis_cmd_tvalid      ()
    );
end : rx_switch

for (genvar i = 0; i < NUM_QDMA*NUM_PHYS_FUNC; i++) begin : tx_switch
    dpa_iconn dpa_iconn_tx(
      .aclk_0                 (axis_aclk),
      .aresetn_0              (internal_axis_rstn),
      .iconn_err_out          (),
      
      // axi stream input in the iconn
      // Tdest = 0 routes the stream to the axi stream output
      // Tdest = 1 routes the stream to the mm axi output
      .s_axis_iconn_in_tdata  (s_axis_qdma2dpa_tx_tdata[i*512 +: 512]),
      .s_axis_iconn_in_tdest  ('0),
      .s_axis_iconn_in_tkeep  (s_axis_qdma2dpa_tx_tkeep[i*64 +: 64]),
      .s_axis_iconn_in_tlast  (s_axis_qdma2dpa_tx_tlast[i]),
      .s_axis_iconn_in_tready (s_axis_qdma2dpa_tx_tready[i]),
      // Tuser is used to pass the size, src and dst of the packet
      .s_axis_iconn_in_tuser  ({
        s_axis_qdma2dpa_tx_tuser_dst[i*16 +: 16],
        s_axis_qdma2dpa_tx_tuser_src[i*16 +: 16],
        s_axis_qdma2dpa_tx_tuser_size[i*16 +: 16]
      }),
      .s_axis_iconn_in_tvalid (s_axis_qdma2dpa_tx_tvalid[i]),

      // axi stream output in the iconn
      .m_axis_iconn_out_tdata (m_axis_dpa2box_tx_tdata[i*512 +: 512]),
      .m_axis_iconn_out_tdest (),
      .m_axis_iconn_out_tkeep (m_axis_dpa2box_tx_tkeep[i*64 +: 64]),
      .m_axis_iconn_out_tlast (m_axis_dpa2box_tx_tlast[i]),
      .m_axis_iconn_out_tready(m_axis_dpa2box_tx_tready[i]),
      .m_axis_iconn_out_tuser ({m_axis_dpa2box_tx_tuser_dst[i*16 +: 16],
                               m_axis_dpa2box_tx_tuser_src[i*16 +: 16],
                               m_axis_dpa2box_tx_tuser_size[i*16 +: 16]}),
      .m_axis_iconn_out_tvalid(m_axis_dpa2box_tx_tvalid[i]),

      // axim output in the iconn
      .m_axim_out_awaddr      (axim_tx[i].aw_addr),
      .m_axim_out_awburst     (axim_tx[i].aw_burst),
      .m_axim_out_awcache     (axim_tx[i].aw_cache),
      .m_axim_out_awid        (axim_tx[i].aw_id),
      .m_axim_out_awlen       (axim_tx[i].aw_len),
      .m_axim_out_awprot      (axim_tx[i].aw_prot),
      .m_axim_out_awready     (axim_tx[i].aw_ready),
      .m_axim_out_awsize      (axim_tx[i].aw_size),
      .m_axim_out_awuser      (axim_tx[i].aw_user),
      .m_axim_out_awvalid     (axim_tx[i].aw_valid),
      .m_axim_out_bready      (axim_tx[i].b_ready),
      .m_axim_out_bresp       (axim_tx[i].b_resp),
      .m_axim_out_bvalid      (axim_tx[i].b_valid),
      .m_axim_out_wdata       (axim_tx[i].w_data),
      .m_axim_out_wlast       (axim_tx[i].w_last),
      .m_axim_out_wready      (axim_tx[i].w_ready),
      .m_axim_out_wstrb       (axim_tx[i].w_strb),
      .m_axim_out_wvalid      (axim_tx[i].w_valid),

      .m_axis_sts_tdata       (),
      .m_axis_sts_tkeep       (),
      .m_axis_sts_tlast       (),
      .m_axis_sts_tready      (),
      .m_axis_sts_tvalid      (),
      // tdata provides the starting address to the axis -> axim converter
      // https://docs.amd.com/r/en-US/pg022_axi_datamover/Command-Interface
      // the stream is written to the axim channel as N byte burst from the starting
      // address upward.
      .s_axis_cmd_tdata       (),
      .s_axis_cmd_tready      (),
      .s_axis_cmd_tvalid      ()
    );
end : tx_switch

// ------------------------------------------------------------------
// DPA output packet routers
// ------------------------------------------------------------------



// ------------------------------------------------------------------
// Compute subsystem
// ------------------------------------------------------------------
//`ifdef __synthesis__
`include "axi_assign.svh"
`include "axi_typedef.svh"

logic ce_clk;
logic internal_ce_rstn;

dpa_pkg::axim64_core2mem_req_t [dpa_pkg::DRAM_CH_NUMBER-1 : 0] m_axim_ce2mem_req;
dpa_pkg::axim64_core2mem_resp_t [dpa_pkg::DRAM_CH_NUMBER-1 : 0] m_axim_ce2mem_resp;

compute_engine compute_engine_i (
  .clk(ce_clk),
  .core_areset_n(internal_ce_rstn),
  .m_axim_ce2mem_req(m_axim_ce2mem_req),
  .m_axim_ce2mem_resp(m_axim_ce2mem_resp),
  .uart_rx (uart_rx),
  .uart_tx (uart_tx)
);

for (genvar i = 0; i < dpa_pkg::DRAM_CH_NUMBER; i++) begin : dram_channels
    `AXI_ASSIGN_FROM_REQ (axim_ce2dram[i], m_axim_ce2mem_req[i])
    `AXI_ASSIGN_TO_RESP  (m_axim_ce2mem_resp[i], axim_ce2dram[i])
end : dram_channels

// ------------------------------------------------------------------
// HBM subsystem
// ------------------------------------------------------------------
`include "hbm_axi.svh"

//`ifdef __au55c__

hbm_interface hbm_interface_i (

    // HBM interface reference clock and rst
    .HBM_REF_CLK_0_0 (ref_clk_100mhz),
    .sys_rst_n_0 (dpa_rstn),
    // Compute Engine HBM channels
    .axi_clk_ariane_0(ce_clk),
    `AXI_ASSIGN_MASTER_TO_HBM(S00, m_axim_ce2mem_req[0], m_axim_ce2mem_resp[0]) ,
    `AXI_ASSIGN_MASTER_TO_HBM(S01, m_axim_ce2mem_req[1], m_axim_ce2mem_resp[1]) ,
    `AXI_ASSIGN_MASTER_TO_HBM(S02, m_axim_ce2mem_req[2], m_axim_ce2mem_resp[2]) ,
    `AXI_ASSIGN_MASTER_TO_HBM(S03, m_axim_ce2mem_req[3], m_axim_ce2mem_resp[3]) ,
    `AXI_ASSIGN_MASTER_TO_HBM(S04, m_axim_ce2mem_req[4], m_axim_ce2mem_resp[4]) ,
    `AXI_ASSIGN_MASTER_TO_HBM(S05, m_axim_ce2mem_req[5], m_axim_ce2mem_resp[5]) ,
    `AXI_ASSIGN_MASTER_TO_HBM(S06, m_axim_ce2mem_req[6], m_axim_ce2mem_resp[6]) ,
    `AXI_ASSIGN_MASTER_TO_HBM(S07, m_axim_ce2mem_req[7], m_axim_ce2mem_resp[7]) ,
    `AXI_ASSIGN_MASTER_TO_HBM(S08, m_axim_ce2mem_req[8], m_axim_ce2mem_resp[8]) ,
    `AXI_ASSIGN_MASTER_TO_HBM(S09, m_axim_ce2mem_req[9], m_axim_ce2mem_resp[9]) ,
    `AXI_ASSIGN_MASTER_TO_HBM(S10, m_axim_ce2mem_req[10], m_axim_ce2mem_resp[10]) ,
    `AXI_ASSIGN_MASTER_TO_HBM(S11, m_axim_ce2mem_req[11], m_axim_ce2mem_resp[11]) ,
    // QDMA MM channel
    .axim_qdma_aclk(s_axim_qdma2dpa_clk),
    .axim_qdma_aresetn(internal_axis_rstn),
    .s_axim_qdma2dpa_araddr       (s_axim_qdma2dpa_araddr ),
    .s_axim_qdma2dpa_arburst      (s_axim_qdma2dpa_arburst),
    .s_axim_qdma2dpa_arcache      (s_axim_qdma2dpa_arcache),
    .s_axim_qdma2dpa_arid         (s_axim_qdma2dpa_arid   ),
    .s_axim_qdma2dpa_arlen        (s_axim_qdma2dpa_arlen  ),
    .s_axim_qdma2dpa_arlock       (s_axim_qdma2dpa_arlock ),
    .s_axim_qdma2dpa_arprot       (s_axim_qdma2dpa_arprot ),
    .s_axim_qdma2dpa_arready      (s_axim_qdma2dpa_arready),
    .s_axim_qdma2dpa_arsize       (s_axim_qdma2dpa_arsize ),
    .s_axim_qdma2dpa_aruser       (s_axim_qdma2dpa_aruser ),
    .s_axim_qdma2dpa_arvalid      (s_axim_qdma2dpa_arvalid),
    .s_axim_qdma2dpa_awaddr       (s_axim_qdma2dpa_awaddr ),
    .s_axim_qdma2dpa_awburst      (s_axim_qdma2dpa_awburst),
    .s_axim_qdma2dpa_awcache      (s_axim_qdma2dpa_awcache),
    .s_axim_qdma2dpa_awid         (s_axim_qdma2dpa_awid   ),
    .s_axim_qdma2dpa_awlen        (s_axim_qdma2dpa_awlen  ),
    .s_axim_qdma2dpa_awlock       (s_axim_qdma2dpa_awlock ),
    .s_axim_qdma2dpa_awprot       (s_axim_qdma2dpa_awprot ),
    .s_axim_qdma2dpa_awready      (s_axim_qdma2dpa_awready),
    .s_axim_qdma2dpa_awsize       (s_axim_qdma2dpa_awsize ),
    .s_axim_qdma2dpa_awuser       (s_axim_qdma2dpa_awuser ),
    .s_axim_qdma2dpa_awvalid      (s_axim_qdma2dpa_awvalid),
    .s_axim_qdma2dpa_bid          (s_axim_qdma2dpa_bid    ),
    .s_axim_qdma2dpa_bready       (s_axim_qdma2dpa_bready ),
    .s_axim_qdma2dpa_bresp        (s_axim_qdma2dpa_bresp  ),
    .s_axim_qdma2dpa_bvalid       (s_axim_qdma2dpa_bvalid ),
    .s_axim_qdma2dpa_rdata        (s_axim_qdma2dpa_rdata  ),
    .s_axim_qdma2dpa_rid          (s_axim_qdma2dpa_rid    ),
    .s_axim_qdma2dpa_rlast        (s_axim_qdma2dpa_rlast  ),
    .s_axim_qdma2dpa_rready       (s_axim_qdma2dpa_rready ),
    .s_axim_qdma2dpa_rresp        (s_axim_qdma2dpa_rresp  ),
    .s_axim_qdma2dpa_rvalid       (s_axim_qdma2dpa_rvalid ),
    .s_axim_qdma2dpa_wdata        (s_axim_qdma2dpa_wdata  ),
    .s_axim_qdma2dpa_wlast        (s_axim_qdma2dpa_wlast  ),
    .s_axim_qdma2dpa_wready       (s_axim_qdma2dpa_wready ),
    .s_axim_qdma2dpa_wstrb        (s_axim_qdma2dpa_wstrb  ),
    .s_axim_qdma2dpa_wuser        (s_axim_qdma2dpa_wuser  ),
    .s_axim_qdma2dpa_wvalid       (s_axim_qdma2dpa_wvalid )
    );

//  `endif

// `endif

// -------------------------
// Clocking system and RESET
// -------------------------

// compute engine clock
  xlnx_clk_gen_solo i_xlnx_clk_gen (
    .clk_out1 ( ce_clk      ), // Core 50 MHz
    .reset    ( clock_reset   ),
    .locked   ( pll_locked    ),
    .clk_in1  ( ref_clk_100mhz ) // 100 Mhz ref clk
  );


// axis switches reset
  generic_reset #(
    .NUM_INPUT_CLK  (1),
    .RESET_DURATION (100)
  ) reset_axis (
    .mod_rstn     (dpa_rstn),
    .mod_rst_done (dpa_axis_rst_done),
    .clk          (axis_aclk),
    .rstn         (internal_axis_rstn)
  );

// compute engine reset
// Generates core_arestn from the reset command from the qdma
  logic reset_core;
  axi4_boot_check #(
    .DATA_WIDTH(512),
    .ADDR_WIDTH(64),
    .ID_WIDTH(0)
  ) axi4_boot_check_instance (
    .aclk(s_axim_qdma2dpa_clk),
    .aresetn(internal_axis_rstn),
    .s_axi_awaddr(s_axim_qdma2dpa_awaddr),
    .s_axi_wdata(s_axim_qdma2dpa_wdata),
    .s_axi_wvalid(s_axim_qdma2dpa_wvalid),
    .start_o(reset_core)
  );
// core_areset_n is driven high when pll locks and the board releases his external reset
// then the logic can be resetted from the hbm_xdma_interface
  rstgen i_rstgen_main (
      .clk_i        ( ce_clk                    ),
      .rst_ni       ( pll_locked & (!reset_core)  ),
      .test_mode_i  ( '0                          ),
      .rst_no       ( internal_ce_rstn            ),
      .init_no      (                             ) // keep open
  );

// -----------------------------------------------
//  END
// -----------------------------------------------

initial begin
    if (DRAM_CH_NUMBER > 12) begin
        $fatal(1, "DRAM_CH_NUMBER (%0d) > 12 is not supported", DRAM_CH_NUMBER);
    end
end
    
endmodule: dpa
