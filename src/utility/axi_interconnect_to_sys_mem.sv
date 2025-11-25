// *************************************************************************
//
// Copyright 2022 Xilinx, Inc.
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

module axi_interconnect_to_sys_mem #(
  parameter C_AXI_DATA_WIDTH = 512,
  parameter C_AXI_ADDR_WIDTH = 64
) (
  input             s_axi_rdma_get_wqe_awid,
  input    [63 : 0] s_axi_rdma_get_wqe_awaddr,
  input     [3 : 0] s_axi_rdma_get_wqe_awqos,
  input     [7 : 0] s_axi_rdma_get_wqe_awlen,
  input     [2 : 0] s_axi_rdma_get_wqe_awsize,
  input     [1 : 0] s_axi_rdma_get_wqe_awburst,
  input     [3 : 0] s_axi_rdma_get_wqe_awcache,
  input     [2 : 0] s_axi_rdma_get_wqe_awprot,
  input             s_axi_rdma_get_wqe_awvalid,
  output            s_axi_rdma_get_wqe_awready,
  input   [511 : 0] s_axi_rdma_get_wqe_wdata,
  input    [63 : 0] s_axi_rdma_get_wqe_wstrb,
  input             s_axi_rdma_get_wqe_wlast,
  input             s_axi_rdma_get_wqe_wvalid,
  output            s_axi_rdma_get_wqe_wready,
  input             s_axi_rdma_get_wqe_awlock,
  output            s_axi_rdma_get_wqe_bid,
  output    [1 : 0] s_axi_rdma_get_wqe_bresp,
  output            s_axi_rdma_get_wqe_bvalid,
  input             s_axi_rdma_get_wqe_bready,
  input             s_axi_rdma_get_wqe_arid,
  input    [63 : 0] s_axi_rdma_get_wqe_araddr,
  input     [7 : 0] s_axi_rdma_get_wqe_arlen,
  input     [2 : 0] s_axi_rdma_get_wqe_arsize,
  input     [1 : 0] s_axi_rdma_get_wqe_arburst,
  input     [3 : 0] s_axi_rdma_get_wqe_arcache,
  input     [2 : 0] s_axi_rdma_get_wqe_arprot,
  input             s_axi_rdma_get_wqe_arvalid,
  output            s_axi_rdma_get_wqe_arready,
  output            s_axi_rdma_get_wqe_rid,
  output  [511 : 0] s_axi_rdma_get_wqe_rdata,
  output    [1 : 0] s_axi_rdma_get_wqe_rresp,
  output            s_axi_rdma_get_wqe_rlast,
  output            s_axi_rdma_get_wqe_rvalid,
  input             s_axi_rdma_get_wqe_rready,
  input             s_axi_rdma_get_wqe_arlock,
  input       [3:0] s_axi_rdma_get_wqe_arqos,

  input     [3 : 0] s_axi_rdma_get_payload_awid,
  input    [63 : 0] s_axi_rdma_get_payload_awaddr,
  input     [3 : 0] s_axi_rdma_get_payload_awqos,
  input     [7 : 0] s_axi_rdma_get_payload_awlen,
  input     [2 : 0] s_axi_rdma_get_payload_awsize,
  input     [1 : 0] s_axi_rdma_get_payload_awburst,
  input     [3 : 0] s_axi_rdma_get_payload_awcache,
  input     [2 : 0] s_axi_rdma_get_payload_awprot,
  input             s_axi_rdma_get_payload_awvalid,
  output            s_axi_rdma_get_payload_awready,
  input   [511 : 0] s_axi_rdma_get_payload_wdata,
  input    [63 : 0] s_axi_rdma_get_payload_wstrb,
  input             s_axi_rdma_get_payload_wlast,
  input             s_axi_rdma_get_payload_wvalid,
  output            s_axi_rdma_get_payload_wready,
  input             s_axi_rdma_get_payload_awlock,
  output    [3 : 0] s_axi_rdma_get_payload_bid,
  output    [1 : 0] s_axi_rdma_get_payload_bresp,
  output            s_axi_rdma_get_payload_bvalid,
  input             s_axi_rdma_get_payload_bready,
  input     [3 : 0] s_axi_rdma_get_payload_arid,
  input    [63 : 0] s_axi_rdma_get_payload_araddr,
  input     [7 : 0] s_axi_rdma_get_payload_arlen,
  input     [2 : 0] s_axi_rdma_get_payload_arsize,
  input     [1 : 0] s_axi_rdma_get_payload_arburst,
  input     [3 : 0] s_axi_rdma_get_payload_arcache,
  input     [2 : 0] s_axi_rdma_get_payload_arprot,
  input             s_axi_rdma_get_payload_arvalid,
  output            s_axi_rdma_get_payload_arready,
  output    [3 : 0] s_axi_rdma_get_payload_rid,
  output  [511 : 0] s_axi_rdma_get_payload_rdata,
  output    [1 : 0] s_axi_rdma_get_payload_rresp,
  output            s_axi_rdma_get_payload_rlast,
  output            s_axi_rdma_get_payload_rvalid,
  input             s_axi_rdma_get_payload_rready,
  input             s_axi_rdma_get_payload_arlock,
  input       [3:0] s_axi_rdma_get_payload_arqos,

  input             s_axi_rdma_completion_awid,
  input    [63 : 0] s_axi_rdma_completion_awaddr,
  input     [3 : 0] s_axi_rdma_completion_awqos,
  input     [7 : 0] s_axi_rdma_completion_awlen,
  input     [2 : 0] s_axi_rdma_completion_awsize,
  input     [1 : 0] s_axi_rdma_completion_awburst,
  input     [3 : 0] s_axi_rdma_completion_awcache,
  input     [2 : 0] s_axi_rdma_completion_awprot,
  input             s_axi_rdma_completion_awvalid,
  output            s_axi_rdma_completion_awready,
  input   [511 : 0] s_axi_rdma_completion_wdata,
  input    [63 : 0] s_axi_rdma_completion_wstrb,
  input             s_axi_rdma_completion_wlast,
  input             s_axi_rdma_completion_wvalid,
  output            s_axi_rdma_completion_wready,
  input             s_axi_rdma_completion_awlock,
  output            s_axi_rdma_completion_bid,
  output    [1 : 0] s_axi_rdma_completion_bresp,
  output            s_axi_rdma_completion_bvalid,
  input             s_axi_rdma_completion_bready,
  input             s_axi_rdma_completion_arid,
  input    [63 : 0] s_axi_rdma_completion_araddr,
  input     [7 : 0] s_axi_rdma_completion_arlen,
  input     [2 : 0] s_axi_rdma_completion_arsize,
  input     [1 : 0] s_axi_rdma_completion_arburst,
  input     [3 : 0] s_axi_rdma_completion_arcache,
  input     [2 : 0] s_axi_rdma_completion_arprot,
  input             s_axi_rdma_completion_arvalid,
  output            s_axi_rdma_completion_arready,
  output            s_axi_rdma_completion_rid,
  output  [511 : 0] s_axi_rdma_completion_rdata,
  output    [1 : 0] s_axi_rdma_completion_rresp,
  output            s_axi_rdma_completion_rlast,
  output            s_axi_rdma_completion_rvalid,
  input             s_axi_rdma_completion_rready,
  input             s_axi_rdma_completion_arlock,
  input      [3:0]  s_axi_rdma_completion_arqos,

  output      [1:0] m_axi_sys_mem_awid,
  output     [63:0] m_axi_sys_mem_awaddr,
  output      [7:0] m_axi_sys_mem_awlen,
  output      [2:0] m_axi_sys_mem_awsize,
  output      [1:0] m_axi_sys_mem_awburst,
  output            m_axi_sys_mem_awlock,
  output      [3:0] m_axi_sys_mem_awqos,
  output      [3:0] m_axi_sys_mem_awregion,
  output      [3:0] m_axi_sys_mem_awcache,
  output      [2:0] m_axi_sys_mem_awprot,
  output            m_axi_sys_mem_awvalid,
  input             m_axi_sys_mem_awready,
  output    [511:0] m_axi_sys_mem_wdata,
  output     [63:0] m_axi_sys_mem_wstrb,
  output            m_axi_sys_mem_wlast,
  output            m_axi_sys_mem_wvalid,
  input             m_axi_sys_mem_wready,
  input       [1:0] m_axi_sys_mem_bid,
  input       [1:0] m_axi_sys_mem_bresp,
  input             m_axi_sys_mem_bvalid,
  output            m_axi_sys_mem_bready,
  output      [1:0] m_axi_sys_mem_arid,
  output     [63:0] m_axi_sys_mem_araddr,
  output      [7:0] m_axi_sys_mem_arlen,
  output      [2:0] m_axi_sys_mem_arsize,
  output      [1:0] m_axi_sys_mem_arburst,
  output            m_axi_sys_mem_arlock,
  output      [3:0] m_axi_sys_mem_arqos,
  output      [3:0] m_axi_sys_mem_arregion,
  output      [3:0] m_axi_sys_mem_arcache,
  output      [2:0] m_axi_sys_mem_arprot,
  output            m_axi_sys_mem_arvalid,
  input             m_axi_sys_mem_arready,
  input       [1:0] m_axi_sys_mem_rid,
  input     [511:0] m_axi_sys_mem_rdata,
  input       [1:0] m_axi_sys_mem_rresp,
  input             m_axi_sys_mem_rlast,
  input             m_axi_sys_mem_rvalid,
  output            m_axi_sys_mem_rready,

  input axis_aclk,
  input axis_arestn
);

localparam C_NUM_MASTERS = 3;

localparam C_RDMA_GET_WQE_IDX     = 0;
localparam C_RDMA_GET_PAYLOAD_IDX = 1;
localparam C_RDMA_COMPLETION_IDX  = 2;

logic   [C_NUM_MASTERS*2-1 : 0] axi_awid;
logic  [C_NUM_MASTERS*64-1 : 0] axi_awaddr;
logic   [C_NUM_MASTERS*8-1 : 0] axi_awlen;
logic   [C_NUM_MASTERS*3-1 : 0] axi_awsize;
logic   [C_NUM_MASTERS*2-1 : 0] axi_awburst;
logic     [C_NUM_MASTERS-1 : 0] axi_awlock;
logic   [C_NUM_MASTERS*4-1 : 0] axi_awcache;
logic   [C_NUM_MASTERS*3-1 : 0] axi_awprot;
logic   [C_NUM_MASTERS*4-1 : 0] axi_awqos;
logic     [C_NUM_MASTERS-1 : 0] axi_awvalid;
logic     [C_NUM_MASTERS-1 : 0] axi_awready;
logic [C_NUM_MASTERS*512-1 : 0] axi_wdata;
logic  [C_NUM_MASTERS*64-1 : 0] axi_wstrb;
logic     [C_NUM_MASTERS-1 : 0] axi_wlast;
logic     [C_NUM_MASTERS-1 : 0] axi_wvalid;
logic     [C_NUM_MASTERS-1 : 0] axi_wready;
logic   [C_NUM_MASTERS*2-1 : 0] axi_bid;
logic   [C_NUM_MASTERS*2-1 : 0] axi_bresp;
logic     [C_NUM_MASTERS-1 : 0] axi_bvalid;
logic     [C_NUM_MASTERS-1 : 0] axi_bready;
logic   [C_NUM_MASTERS*2-1 : 0] axi_arid;
logic  [C_NUM_MASTERS*64-1 : 0] axi_araddr;
logic   [C_NUM_MASTERS*8-1 : 0] axi_arlen;
logic   [C_NUM_MASTERS*3-1 : 0] axi_arsize;
logic   [C_NUM_MASTERS*2-1 : 0] axi_arburst;
logic     [C_NUM_MASTERS-1 : 0] axi_arlock;
logic   [C_NUM_MASTERS*4-1 : 0] axi_arcache;
logic   [C_NUM_MASTERS*3-1 : 0] axi_arprot;
logic   [C_NUM_MASTERS*4-1 : 0] axi_arqos;
logic     [C_NUM_MASTERS-1 : 0] axi_arvalid;
logic     [C_NUM_MASTERS-1 : 0] axi_arready;
logic   [C_NUM_MASTERS*2-1 : 0] axi_rid;
logic [C_NUM_MASTERS*512-1 : 0] axi_rdata;
logic   [C_NUM_MASTERS*2-1 : 0] axi_rresp;
logic     [C_NUM_MASTERS-1 : 0] axi_rlast;
logic     [C_NUM_MASTERS-1 : 0] axi_rvalid;
logic     [C_NUM_MASTERS-1 : 0] axi_rready;

// AXI slave signals for getting wqe from system memory
//assign axi_awid   [C_RDMA_GET_WQE_IDX *2 +: 2]         = {1'b0, s_axi_rdma_get_wqe_awid};
assign axi_awid   [C_RDMA_GET_WQE_IDX *2 +: 2]         = s_axi_rdma_get_wqe_awvalid ? 2'd0 : 2'd0;
assign axi_awaddr [C_RDMA_GET_WQE_IDX *64 +: 64]       = s_axi_rdma_get_wqe_awaddr;
assign axi_awqos  [C_RDMA_GET_WQE_IDX *4 +: 4]         = s_axi_rdma_get_wqe_awqos;
assign axi_awlen  [C_RDMA_GET_WQE_IDX *8 +: 8]         = s_axi_rdma_get_wqe_awlen;
assign axi_awsize [C_RDMA_GET_WQE_IDX *3 +: 3]         = s_axi_rdma_get_wqe_awsize;
assign axi_awburst[C_RDMA_GET_WQE_IDX *2 +: 2]         = s_axi_rdma_get_wqe_awburst;
assign axi_awcache[C_RDMA_GET_WQE_IDX *4 +: 4]         = s_axi_rdma_get_wqe_awcache;
assign axi_awprot [C_RDMA_GET_WQE_IDX *3 +: 3]         = s_axi_rdma_get_wqe_awprot;
assign axi_awvalid[C_RDMA_GET_WQE_IDX *1 +: 1]         = s_axi_rdma_get_wqe_awvalid;
assign s_axi_rdma_get_wqe_awready                      = axi_awready[C_RDMA_GET_WQE_IDX *1 +: 1];
assign axi_wdata  [C_RDMA_GET_WQE_IDX *512 +: 512]     = s_axi_rdma_get_wqe_wdata;
assign axi_wstrb  [C_RDMA_GET_WQE_IDX *64 +: 64]       = s_axi_rdma_get_wqe_wstrb;
assign axi_wlast  [C_RDMA_GET_WQE_IDX *1 +: 1]         = s_axi_rdma_get_wqe_wlast;
assign axi_wvalid [C_RDMA_GET_WQE_IDX *1 +: 1]         = s_axi_rdma_get_wqe_wvalid;
assign s_axi_rdma_get_wqe_wready                       = axi_wready[C_RDMA_GET_WQE_IDX *1 +: 1];
assign axi_awlock [C_RDMA_GET_WQE_IDX *1 +: 1]         = s_axi_rdma_get_wqe_awlock;
assign s_axi_rdma_get_wqe_bid                          = axi_bid[C_RDMA_GET_WQE_IDX *2 +: 1];
assign s_axi_rdma_get_wqe_bresp                        = axi_bresp[C_RDMA_GET_WQE_IDX *2 +: 2];
assign s_axi_rdma_get_wqe_bvalid                       = axi_bvalid[C_RDMA_GET_WQE_IDX *1 +: 1];
assign axi_bready [C_RDMA_GET_WQE_IDX *1 +: 1]         = s_axi_rdma_get_wqe_bready;
//assign axi_arid   [C_RDMA_GET_WQE_IDX *2 +: 2]         = {1'b0, s_axi_rdma_get_wqe_arid};
assign axi_arid   [C_RDMA_GET_WQE_IDX *2 +: 2]         = s_axi_rdma_get_wqe_arvalid ? 2'd0 : 2'd0;
assign axi_araddr [C_RDMA_GET_WQE_IDX *64 +: 64]       = s_axi_rdma_get_wqe_araddr;
assign axi_arlen  [C_RDMA_GET_WQE_IDX *8  +: 8]        = s_axi_rdma_get_wqe_arlen;
assign axi_arsize [C_RDMA_GET_WQE_IDX *3  +: 3]        = s_axi_rdma_get_wqe_arsize;
assign axi_arburst[C_RDMA_GET_WQE_IDX *2  +: 2]        = s_axi_rdma_get_wqe_arburst;
assign axi_arcache[C_RDMA_GET_WQE_IDX *4  +: 4]        = s_axi_rdma_get_wqe_arcache;
assign axi_arprot [C_RDMA_GET_WQE_IDX *3  +: 3]        = s_axi_rdma_get_wqe_arprot;
assign axi_arvalid[C_RDMA_GET_WQE_IDX *1  +: 1]        = s_axi_rdma_get_wqe_arvalid;
assign s_axi_rdma_get_wqe_arready                      = axi_arready[C_RDMA_GET_WQE_IDX *1 +: 1];
assign s_axi_rdma_get_wqe_rid                          = axi_rid[C_RDMA_GET_WQE_IDX *2 +: 1];
assign s_axi_rdma_get_wqe_rdata                        = axi_rdata[C_RDMA_GET_WQE_IDX *512 +: 512];
assign s_axi_rdma_get_wqe_rresp                        = axi_rresp[C_RDMA_GET_WQE_IDX *2 +: 2];
assign s_axi_rdma_get_wqe_rlast                        = axi_rlast[C_RDMA_GET_WQE_IDX *1 +: 1];
assign s_axi_rdma_get_wqe_rvalid                       = axi_rvalid[C_RDMA_GET_WQE_IDX *1 +: 1];
assign axi_rready [C_RDMA_GET_WQE_IDX *1 +: 1]         = s_axi_rdma_get_wqe_rready;
assign axi_arlock [C_RDMA_GET_WQE_IDX *1 +: 1]         = s_axi_rdma_get_wqe_arlock;
assign axi_arqos  [C_RDMA_GET_WQE_IDX *4 +: 4]         = s_axi_rdma_get_wqe_arqos;

// AXI slave signals for getting payload from system memory
//assign axi_awid   [C_RDMA_GET_PAYLOAD_IDX*2 +: 2]      = {1'b0, s_axi_rdma_get_payload_awid};
assign axi_awid   [C_RDMA_GET_PAYLOAD_IDX*2 +: 2]      = s_axi_rdma_get_payload_awvalid ? 2'd1 : 2'd0;
assign axi_awaddr [C_RDMA_GET_PAYLOAD_IDX *64 +: 64]   = s_axi_rdma_get_payload_awaddr;
assign axi_awqos  [C_RDMA_GET_PAYLOAD_IDX *4 +: 4]     = s_axi_rdma_get_payload_awqos;
assign axi_awlen  [C_RDMA_GET_PAYLOAD_IDX *8 +: 8]     = s_axi_rdma_get_payload_awlen;
assign axi_awsize [C_RDMA_GET_PAYLOAD_IDX *3 +: 3]     = s_axi_rdma_get_payload_awsize;
assign axi_awburst[C_RDMA_GET_PAYLOAD_IDX *2 +: 2]     = s_axi_rdma_get_payload_awburst;
assign axi_awcache[C_RDMA_GET_PAYLOAD_IDX *4 +: 4]     = s_axi_rdma_get_payload_awcache;
assign axi_awprot [C_RDMA_GET_PAYLOAD_IDX *3 +: 3]     = s_axi_rdma_get_payload_awprot;
assign axi_awvalid[C_RDMA_GET_PAYLOAD_IDX *1 +: 1]     = s_axi_rdma_get_payload_awvalid;
assign s_axi_rdma_get_payload_awready                  = axi_awready[C_RDMA_GET_PAYLOAD_IDX *1 +: 1];
assign axi_wdata  [C_RDMA_GET_PAYLOAD_IDX *512 +: 512] = s_axi_rdma_get_payload_wdata;
assign axi_wstrb  [C_RDMA_GET_PAYLOAD_IDX *64 +: 64]   = s_axi_rdma_get_payload_wstrb;
assign axi_wlast  [C_RDMA_GET_PAYLOAD_IDX *1 +: 1]     = s_axi_rdma_get_payload_wlast;
assign axi_wvalid [C_RDMA_GET_PAYLOAD_IDX *1 +: 1]     = s_axi_rdma_get_payload_wvalid;
assign s_axi_rdma_get_payload_wready                   = axi_wready[C_RDMA_GET_PAYLOAD_IDX *1 +: 1];
assign axi_awlock [C_RDMA_GET_PAYLOAD_IDX *1 +: 1]     = s_axi_rdma_get_payload_awlock;
assign s_axi_rdma_get_payload_bid                      = axi_bid[C_RDMA_GET_PAYLOAD_IDX *2 +: 1];
assign s_axi_rdma_get_payload_bresp                    = axi_bresp[C_RDMA_GET_PAYLOAD_IDX *2 +: 2];
assign s_axi_rdma_get_payload_bvalid                   = axi_bvalid[C_RDMA_GET_PAYLOAD_IDX *1 +: 1];
assign axi_bready [C_RDMA_GET_PAYLOAD_IDX *1 +: 1]     = s_axi_rdma_get_payload_bready;
//assign axi_arid   [C_RDMA_GET_PAYLOAD_IDX *2 +: 2]     = {1'b0, s_axi_rdma_get_payload_arid};
assign axi_arid   [C_RDMA_GET_PAYLOAD_IDX *2 +: 2]     = s_axi_rdma_get_payload_arvalid ? 2'd1: 2'd0;
assign axi_araddr [C_RDMA_GET_PAYLOAD_IDX *64 +: 64]   = s_axi_rdma_get_payload_araddr;
assign axi_arlen  [C_RDMA_GET_PAYLOAD_IDX *8  +: 8]    = s_axi_rdma_get_payload_arlen;
assign axi_arsize [C_RDMA_GET_PAYLOAD_IDX *3  +: 3]    = s_axi_rdma_get_payload_arsize;
assign axi_arburst[C_RDMA_GET_PAYLOAD_IDX *2  +: 2]    = s_axi_rdma_get_payload_arburst;
assign axi_arcache[C_RDMA_GET_PAYLOAD_IDX *4  +: 4]    = s_axi_rdma_get_payload_arcache;
assign axi_arprot [C_RDMA_GET_PAYLOAD_IDX *3  +: 3]    = s_axi_rdma_get_payload_arprot;
assign axi_arvalid[C_RDMA_GET_PAYLOAD_IDX *1  +: 1]    = s_axi_rdma_get_payload_arvalid;
assign s_axi_rdma_get_payload_arready                  = axi_arready[C_RDMA_GET_PAYLOAD_IDX *1 +: 1];
assign s_axi_rdma_get_payload_rid                      = axi_rid[C_RDMA_GET_PAYLOAD_IDX *2 +: 1];
assign s_axi_rdma_get_payload_rdata                    = axi_rdata[C_RDMA_GET_PAYLOAD_IDX *512 +: 512];
assign s_axi_rdma_get_payload_rresp                    = axi_rresp[C_RDMA_GET_PAYLOAD_IDX *2 +: 2];
assign s_axi_rdma_get_payload_rlast                    = axi_rlast[C_RDMA_GET_PAYLOAD_IDX *1 +: 1];
assign s_axi_rdma_get_payload_rvalid                   = axi_rvalid[C_RDMA_GET_PAYLOAD_IDX *1 +: 1];
assign axi_rready [C_RDMA_GET_PAYLOAD_IDX *1 +: 1]     = s_axi_rdma_get_payload_rready;
assign axi_arlock [C_RDMA_GET_PAYLOAD_IDX *1 +: 1]     = s_axi_rdma_get_payload_arlock;
assign axi_arqos  [C_RDMA_GET_PAYLOAD_IDX *4 +: 4]     = s_axi_rdma_get_payload_arqos;

// AXI slave signals for data access from qdma mm channel
//assign axi_awid   [C_RDMA_COMPLETION_IDX*2 +: 2]       = {1'b0, s_axi_rdma_completion_awid};
assign axi_awid   [C_RDMA_COMPLETION_IDX*2 +: 2]       = s_axi_rdma_completion_awvalid ? 2'd2 : 2'd0;
assign axi_awaddr [C_RDMA_COMPLETION_IDX *64 +: 64]    = s_axi_rdma_completion_awaddr;
assign axi_awqos  [C_RDMA_COMPLETION_IDX *4 +: 4]      = s_axi_rdma_completion_awqos;
assign axi_awlen  [C_RDMA_COMPLETION_IDX *8 +: 8]      = s_axi_rdma_completion_awlen;
assign axi_awsize [C_RDMA_COMPLETION_IDX *3 +: 3]      = s_axi_rdma_completion_awsize;
assign axi_awburst[C_RDMA_COMPLETION_IDX *2 +: 2]      = s_axi_rdma_completion_awburst;
assign axi_awcache[C_RDMA_COMPLETION_IDX *4 +: 4]      = s_axi_rdma_completion_awcache;
assign axi_awprot [C_RDMA_COMPLETION_IDX *3 +: 3]      = s_axi_rdma_completion_awprot;
assign axi_awvalid[C_RDMA_COMPLETION_IDX *1 +: 1]      = s_axi_rdma_completion_awvalid;
assign s_axi_rdma_completion_awready                   = axi_awready[C_RDMA_COMPLETION_IDX *1 +: 1];
assign axi_wdata  [C_RDMA_COMPLETION_IDX *512 +: 512]  = s_axi_rdma_completion_wdata;
assign axi_wstrb  [C_RDMA_COMPLETION_IDX *64 +: 64]    = s_axi_rdma_completion_wstrb;
assign axi_wlast  [C_RDMA_COMPLETION_IDX *1 +: 1]      = s_axi_rdma_completion_wlast;
assign axi_wvalid [C_RDMA_COMPLETION_IDX *1 +: 1]      = s_axi_rdma_completion_wvalid;
assign s_axi_rdma_completion_wready                    = axi_wready[C_RDMA_COMPLETION_IDX *1 +: 1];
assign axi_awlock [C_RDMA_COMPLETION_IDX *1 +: 1]      = s_axi_rdma_completion_awlock;
assign s_axi_rdma_completion_bid                       = axi_bid[C_RDMA_COMPLETION_IDX *2 +: 1];
assign s_axi_rdma_completion_bresp                     = axi_bresp[C_RDMA_COMPLETION_IDX *2 +: 2];
assign s_axi_rdma_completion_bvalid                    = axi_bvalid[C_RDMA_COMPLETION_IDX *1 +: 1];
assign axi_bready [C_RDMA_COMPLETION_IDX *1 +: 1]      = s_axi_rdma_completion_bready;
//assign axi_arid   [C_RDMA_COMPLETION_IDX *2 +: 2]      = {1'b0, s_axi_rdma_completion_arid};
assign axi_arid   [C_RDMA_COMPLETION_IDX *2 +: 2]      = s_axi_rdma_completion_arvalid ? 2'd2 : 2'd0;
assign axi_araddr [C_RDMA_COMPLETION_IDX *64 +: 64]    = s_axi_rdma_completion_araddr;
assign axi_arlen  [C_RDMA_COMPLETION_IDX *8  +: 8]     = s_axi_rdma_completion_arlen;
assign axi_arsize [C_RDMA_COMPLETION_IDX *3  +: 3]     = s_axi_rdma_completion_arsize;
assign axi_arburst[C_RDMA_COMPLETION_IDX *2  +: 2]     = s_axi_rdma_completion_arburst;
assign axi_arcache[C_RDMA_COMPLETION_IDX *4  +: 4]     = s_axi_rdma_completion_arcache;
assign axi_arprot [C_RDMA_COMPLETION_IDX *3  +: 3]     = s_axi_rdma_completion_arprot;
assign axi_arvalid[C_RDMA_COMPLETION_IDX *1  +: 1]     = s_axi_rdma_completion_arvalid;
assign s_axi_rdma_completion_arready                   = axi_arready[C_RDMA_COMPLETION_IDX *1 +: 1];
assign s_axi_rdma_completion_rid                       = axi_rid[C_RDMA_COMPLETION_IDX *2 +: 1];
assign s_axi_rdma_completion_rdata                     = axi_rdata[C_RDMA_COMPLETION_IDX *512 +: 512];
assign s_axi_rdma_completion_rresp                     = axi_rresp[C_RDMA_COMPLETION_IDX *2 +: 2];
assign s_axi_rdma_completion_rlast                     = axi_rlast[C_RDMA_COMPLETION_IDX *1 +: 1];
assign s_axi_rdma_completion_rvalid                    = axi_rvalid[C_RDMA_COMPLETION_IDX *1 +: 1];
assign axi_rready [C_RDMA_COMPLETION_IDX *1 +: 1]      = s_axi_rdma_completion_rready;
assign axi_arlock [C_RDMA_COMPLETION_IDX *1 +: 1]      = s_axi_rdma_completion_arlock;
assign axi_arqos  [C_RDMA_COMPLETION_IDX *4 +: 4]      = s_axi_rdma_completion_arqos;

dev_mem_axi_crossbar dev_mem_axi_crossbar_inst (
  .m_axi_awaddr    (m_axi_sys_mem_awaddr),
  .m_axi_awprot    (m_axi_sys_mem_awprot),
  .m_axi_awvalid   (m_axi_sys_mem_awvalid),
  .m_axi_awready   (m_axi_sys_mem_awready),
  .m_axi_awsize    (m_axi_sys_mem_awsize),
  .m_axi_awburst   (m_axi_sys_mem_awburst),
  .m_axi_awcache   (m_axi_sys_mem_awcache),
  .m_axi_awlen     (m_axi_sys_mem_awlen),
  .m_axi_awlock    (m_axi_sys_mem_awlock),
  .m_axi_awqos     (m_axi_sys_mem_awqos),
  .m_axi_awregion  (m_axi_sys_mem_awregion),
  .m_axi_awid      (m_axi_sys_mem_awid),
  .m_axi_wdata     (m_axi_sys_mem_wdata),
  .m_axi_wstrb     (m_axi_sys_mem_wstrb),
  .m_axi_wvalid    (m_axi_sys_mem_wvalid),
  .m_axi_wready    (m_axi_sys_mem_wready),
  .m_axi_wlast     (m_axi_sys_mem_wlast),
  .m_axi_bresp     (m_axi_sys_mem_bresp),
  .m_axi_bvalid    (m_axi_sys_mem_bvalid),
  .m_axi_bready    (m_axi_sys_mem_bready),
  .m_axi_bid       (m_axi_sys_mem_bid),
  .m_axi_araddr    (m_axi_sys_mem_araddr),
  .m_axi_arprot    (m_axi_sys_mem_arprot),
  .m_axi_arvalid   (m_axi_sys_mem_arvalid),
  .m_axi_arready   (m_axi_sys_mem_arready),
  .m_axi_arsize    (m_axi_sys_mem_arsize),
  .m_axi_arburst   (m_axi_sys_mem_arburst),
  .m_axi_arcache   (m_axi_sys_mem_arcache),
  .m_axi_arlock    (m_axi_sys_mem_arlock),
  .m_axi_arlen     (m_axi_sys_mem_arlen),
  .m_axi_arqos     (m_axi_sys_mem_arqos),
  .m_axi_arregion  (m_axi_sys_mem_arregion),
  .m_axi_arid      (m_axi_sys_mem_arid),
  .m_axi_rdata     (m_axi_sys_mem_rdata),
  .m_axi_rresp     (m_axi_sys_mem_rresp),
  .m_axi_rvalid    (m_axi_sys_mem_rvalid),
  .m_axi_rready    (m_axi_sys_mem_rready),
  .m_axi_rlast     (m_axi_sys_mem_rlast),
  .m_axi_rid       (m_axi_sys_mem_rid),

  .s_axi_awid      (axi_awid),
  .s_axi_awaddr    (axi_awaddr),
  .s_axi_awqos     (axi_awqos),
  .s_axi_awlen     (axi_awlen),
  .s_axi_awsize    (axi_awsize),
  .s_axi_awburst   (axi_awburst),
  .s_axi_awcache   (axi_awcache),
  .s_axi_awprot    (axi_awprot),
  .s_axi_awvalid   (axi_awvalid),
  .s_axi_awready   (axi_awready),
  .s_axi_wdata     (axi_wdata),
  .s_axi_wstrb     (axi_wstrb),
  .s_axi_wlast     (axi_wlast),
  .s_axi_wvalid    (axi_wvalid),
  .s_axi_wready    (axi_wready),
  .s_axi_awlock    (axi_awlock),
  .s_axi_bid       (axi_bid),
  .s_axi_bresp     (axi_bresp),
  .s_axi_bvalid    (axi_bvalid),
  .s_axi_bready    (axi_bready),
  .s_axi_arid      (axi_arid),
  .s_axi_araddr    (axi_araddr),
  .s_axi_arlen     (axi_arlen),
  .s_axi_arsize    (axi_arsize),
  .s_axi_arburst   (axi_arburst),
  .s_axi_arcache   (axi_arcache),
  .s_axi_arprot    (axi_arprot),
  .s_axi_arvalid   (axi_arvalid),
  .s_axi_arready   (axi_arready),
  .s_axi_rid       (axi_rid),
  .s_axi_rdata     (axi_rdata),
  .s_axi_rresp     (axi_rresp),
  .s_axi_rlast     (axi_rlast),
  .s_axi_rvalid    (axi_rvalid),
  .s_axi_rready    (axi_rready),
  .s_axi_arlock    (axi_arlock),
  .s_axi_arqos     (axi_arqos),

  .aclk   (axis_aclk),
  .aresetn(axis_arestn)
);

endmodule: axi_interconnect_to_sys_mem