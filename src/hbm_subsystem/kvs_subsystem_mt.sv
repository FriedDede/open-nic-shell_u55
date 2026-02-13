`timescale 1ns/1ps

`include "axi_assign.svh"
`include "axi_typedef.svh"
`include "axi_.svh"
`include "hbm_axi.svh"

module kvs_subsystem_mt 
import metadata_pkg::*;
import axi_pkg::*;
import kvs_pkg::*;
#(
  parameter int                     DATA_WIDTH      = 512,     
  parameter int                     MAX_NODES       = kvs_pkg::MAX_NODES,      
  parameter logic            [31:0] NODE_IP         = kvs_pkg::NODE_IP,        
  parameter logic            [47:0] NODE_MAC        = kvs_pkg::NODE_MAC,       

  parameter int                     BUCKET_SIZE     = kvs_pkg::BUCKET_SIZE,    
  parameter int                     TIMER_WIDTH     = kvs_pkg::TIMER_WIDTH,    
  parameter int                     USE_CONTROLLER  = kvs_pkg::USE_CONTROLLER, 
  parameter int                     SEED            = kvs_pkg::SEED,           
  // default mapping [mem 0x0000000400000000-0x00000007ffffffff]
  parameter logic [63:0]            BASE_HOST_MEM   = kvs_pkg::BASE_HOST_MEM,
  parameter logic [63:0]            MASK_HOST_MEM   = kvs_pkg::MASK_HOST_MEM,
  parameter logic [TIMER_WIDTH-1:0] TAP_MASK        = kvs_pkg::TAP_MASK,     
  parameter int                     N_THREADS      = 4
) (
  input          axis_aclk,
  input          axil_aclk,
  input          axi_rstn,
  input          hbm_ref_clk,

  // QDMA DMA Engine - AXI MM interface - slave
  input   [63:0] s_axi_araddr,
  input    [1:0] s_axi_arburst,
  input    [3:0] s_axi_arcache,
  input    [3:0] s_axi_arid,
  input    [7:0] s_axi_arlen,
  input    [0:0] s_axi_arlock,
  input    [2:0] s_axi_arprot,
  input    [3:0] s_axi_arqos,
  output         s_axi_arready,
  input    [2:0] s_axi_arsize,
  input   [31:0] s_axi_aruser,
  input          s_axi_arvalid,
  input   [63:0] s_axi_awaddr,
  input    [1:0] s_axi_awburst,
  input    [3:0] s_axi_awcache,
  input    [3:0] s_axi_awid,
  input    [7:0] s_axi_awlen,
  input    [0:0] s_axi_awlock,
  input    [2:0] s_axi_awprot,
  input    [3:0] s_axi_awqos,
  output         s_axi_awready,
  input    [2:0] s_axi_awsize,
  input   [31:0] s_axi_awuser,
  input          s_axi_awvalid,
  output   [3:0] s_axi_bid,
  input          s_axi_bready,
  output   [1:0] s_axi_bresp,
  output         s_axi_bvalid,
  output [511:0] s_axi_rdata,
  output   [3:0] s_axi_rid,
  output         s_axi_rlast,
  input          s_axi_rready,
  output   [1:0] s_axi_rresp,
  output         s_axi_rvalid,
  input  [511:0] s_axi_wdata,
  input          s_axi_wlast,
  output         s_axi_wready,
  input   [63:0] s_axi_wstrb,
  input   [63:0] s_axi_wuser,
  input          s_axi_wvalid,

  // QDMA DMA Engine - AXI BRIDGE MM interface - master
  input                          m_axi_sys_mem_awready,
  input                          m_axi_sys_mem_wready,
  input                  [3:0]   m_axi_sys_mem_bid,
  input                  [1:0]   m_axi_sys_mem_bresp,
  input                          m_axi_sys_mem_bvalid,
  input                          m_axi_sys_mem_arready,
  input                  [3:0]   m_axi_sys_mem_rid,
  input                  [511:0] m_axi_sys_mem_rdata,
  input                  [1:0]   m_axi_sys_mem_rresp,
  input                          m_axi_sys_mem_rlast,
  input                          m_axi_sys_mem_rvalid,
  output                 [3:0]   m_axi_sys_mem_awid,
  output                 [63:0]  m_axi_sys_mem_awaddr,
  output                 [31:0]  m_axi_sys_mem_awuser,
  output                 [7:0]   m_axi_sys_mem_awlen,
  output                 [2:0]   m_axi_sys_mem_awsize,
  output                 [1:0]   m_axi_sys_mem_awburst,
  output                 [2:0]   m_axi_sys_mem_awprot,
  output                         m_axi_sys_mem_awvalid,
  output                         m_axi_sys_mem_awlock,
  output                 [3:0]   m_axi_sys_mem_awcache,
  output                 [511:0] m_axi_sys_mem_wdata,
  output                 [63:0]  m_axi_sys_mem_wuser,
  output                 [63:0]  m_axi_sys_mem_wstrb,
  output                         m_axi_sys_mem_wlast,
  output                         m_axi_sys_mem_wvalid,
  output                         m_axi_sys_mem_bready,
  output                 [3:0]   m_axi_sys_mem_arid,
  output                 [63:0]  m_axi_sys_mem_araddr,
  output                 [31:0]  m_axi_sys_mem_aruser,
  output                 [7:0]   m_axi_sys_mem_arlen,
  output                 [2:0]   m_axi_sys_mem_arsize,
  output                 [1:0]   m_axi_sys_mem_arburst,
  output                 [2:0]   m_axi_sys_mem_arprot,
  output                         m_axi_sys_mem_arvalid,
  output                         m_axi_sys_mem_arlock,
  output                 [3:0]   m_axi_sys_mem_arcache,
  output                         m_axi_sys_mem_rready,

  input   [31:0] s_axil_awaddr,
  input          s_axil_awvalid,
  output         s_axil_awready,
  input   [31:0] s_axil_wdata,
  input          s_axil_wvalid,
  output         s_axil_wready,
  output   [1:0] s_axil_bresp,
  output         s_axil_bvalid,
  input          s_axil_bready,
  input   [31:0] s_axil_araddr,
  input          s_axil_arvalid,
  output         s_axil_arready,
  output  [31:0] s_axil_rdata,
  output   [1:0] s_axil_rresp,
  output         s_axil_rvalid,
  input          s_axil_rready,

  input          s_axis_qdma_h2c_tvalid,
  input  [511:0] s_axis_qdma_h2c_tdata,
  input   [63:0] s_axis_qdma_h2c_tkeep,
  input          s_axis_qdma_h2c_tlast,
  input   [15:0] s_axis_qdma_h2c_tuser_size,
  input   [15:0] s_axis_qdma_h2c_tuser_src,
  input   [15:0] s_axis_qdma_h2c_tuser_dst,
  output         s_axis_qdma_h2c_tready,

  output         m_axis_qdma_c2h_tvalid,
  output [511:0] m_axis_qdma_c2h_tdata,
  output  [63:0] m_axis_qdma_c2h_tkeep,
  output         m_axis_qdma_c2h_tlast,
  output  [15:0] m_axis_qdma_c2h_tuser_size,
  output  [15:0] m_axis_qdma_c2h_tuser_src,
  output  [15:0] m_axis_qdma_c2h_tuser_dst,
  input          m_axis_qdma_c2h_tready,

  output         m_axis_cmac_h2c_tvalid,
  output [511:0] m_axis_cmac_h2c_tdata,
  output  [63:0] m_axis_cmac_h2c_tkeep,
  output         m_axis_cmac_h2c_tlast,
  output  [15:0] m_axis_cmac_h2c_tuser_size,
  output  [15:0] m_axis_cmac_h2c_tuser_src,
  output  [15:0] m_axis_cmac_h2c_tuser_dst,
  input          m_axis_cmac_h2c_tready,

  input          s_axis_cmac_c2h_tvalid,
  input  [511:0] s_axis_cmac_c2h_tdata,
  input   [63:0] s_axis_cmac_c2h_tkeep,
  input          s_axis_cmac_c2h_tlast,
  input   [15:0] s_axis_cmac_c2h_tuser_size,
  input   [15:0] s_axis_cmac_c2h_tuser_src,
  input   [15:0] s_axis_cmac_c2h_tuser_dst,
  output         s_axis_cmac_c2h_tready
);

// RESET
// The reset waits until the HBM has finished initial configuration

logic apb_complete_0;
logic apb_complete_reg;
logic rstn;

assign rstn = axi_rstn && apb_complete_reg;

always_ff @(posedge axis_aclk) begin
  if(~axi_rstn)
    apb_complete_reg <= 1'b0;
  else
    apb_complete_reg <= apb_complete_0;
end


// ------------------------------------------------------------------------------------------------------
// AXIS SLICING
// ------------------------------------------------------------------------------------------------------

  logic           reg_axis_qdma_h2c_tvalid; 
  logic   [511:0] reg_axis_qdma_h2c_tdata; 
  logic    [63:0] reg_axis_qdma_h2c_tkeep; 
  logic           reg_axis_qdma_h2c_tlast; 
  logic    [15:0] reg_axis_qdma_h2c_tuser_size; 
  logic    [15:0] reg_axis_qdma_h2c_tuser_src; 
  logic    [15:0] reg_axis_qdma_h2c_tuser_dst; 
  logic           reg_axis_qdma_h2c_tready;

  logic           reg_axis_qdma_c2h_tvalid; 
  logic   [511:0] reg_axis_qdma_c2h_tdata; 
  logic    [63:0] reg_axis_qdma_c2h_tkeep; 
  logic           reg_axis_qdma_c2h_tlast; 
  logic    [15:0] reg_axis_qdma_c2h_tuser_size; 
  logic    [15:0] reg_axis_qdma_c2h_tuser_src; 
  logic    [15:0] reg_axis_qdma_c2h_tuser_dst; 
  logic           reg_axis_qdma_c2h_tready; 

  logic           reg_axis_cmac_h2c_tvalid; 
  logic   [511:0] reg_axis_cmac_h2c_tdata; 
  logic    [63:0] reg_axis_cmac_h2c_tkeep; 
  logic           reg_axis_cmac_h2c_tlast; 
  logic    [15:0] reg_axis_cmac_h2c_tuser_size; 
  logic    [15:0] reg_axis_cmac_h2c_tuser_src; 
  logic    [15:0] reg_axis_cmac_h2c_tuser_dst; 
  logic           reg_axis_cmac_h2c_tready; 

  logic           reg_axis_cmac_c2h_tvalid; 
  logic   [511:0] reg_axis_cmac_c2h_tdata; 
  logic    [63:0] reg_axis_cmac_c2h_tkeep; 
  logic           reg_axis_cmac_c2h_tlast; 
  logic    [15:0] reg_axis_cmac_c2h_tuser_size; 
  logic    [15:0] reg_axis_cmac_c2h_tuser_src; 
  logic    [15:0] reg_axis_cmac_c2h_tuser_dst; 
  logic           reg_axis_cmac_c2h_tready; 

// QDMA C2H SLICER
axi_stream_register_slice #(
  .TDATA_W  (512),
  .TID_W    (0),
  .TDEST_W  (0),
  .TUSER_W  (16 * 3),
  .MODE     ("full")
) axi_stream_register_slice_qdma_c2h (
  .s_axis_tvalid  (reg_axis_qdma_c2h_tvalid),
  .s_axis_tdata   (reg_axis_qdma_c2h_tdata),
  .s_axis_tkeep   (reg_axis_qdma_c2h_tkeep),
  .s_axis_tlast   (reg_axis_qdma_c2h_tlast),
  .s_axis_tid     (),
  .s_axis_tdest   (),
  .s_axis_tuser   ({reg_axis_qdma_c2h_tuser_size,reg_axis_qdma_c2h_tuser_src,reg_axis_qdma_c2h_tuser_dst}),
  .s_axis_tready  (reg_axis_qdma_c2h_tready),

  .m_axis_tvalid  (m_axis_qdma_c2h_tvalid),
  .m_axis_tdata   (m_axis_qdma_c2h_tdata),
  .m_axis_tkeep   (m_axis_qdma_c2h_tkeep),
  .m_axis_tlast   (m_axis_qdma_c2h_tlast),
  .m_axis_tid     (),
  .m_axis_tdest   (),
  .m_axis_tuser   ({m_axis_qdma_c2h_tuser_size,m_axis_qdma_c2h_tuser_src,m_axis_qdma_c2h_tuser_dst}),
  .m_axis_tready  (m_axis_qdma_c2h_tready),
  .aclk(axis_aclk),
  .aresetn(rstn)
);

// QDMA H2C SLICER
axi_stream_register_slice #(
  .TDATA_W  (512),
  .TID_W    (0),
  .TDEST_W  (0),
  .TUSER_W  (16 * 3),
  .MODE     ("full")
) axi_stream_register_slice_qdma_h2c (
  .s_axis_tvalid  (s_axis_qdma_h2c_tvalid),
  .s_axis_tdata   (s_axis_qdma_h2c_tdata),
  .s_axis_tkeep   (s_axis_qdma_h2c_tkeep),
  .s_axis_tlast   (s_axis_qdma_h2c_tlast),
  .s_axis_tid     (),
  .s_axis_tdest   (),
  .s_axis_tuser   ({s_axis_qdma_h2c_tuser_size,s_axis_qdma_h2c_tuser_src,s_axis_qdma_h2c_tuser_dst}),
  .s_axis_tready  (s_axis_qdma_h2c_tready),


  .m_axis_tvalid  (reg_axis_qdma_h2c_tvalid),
  .m_axis_tdata   (reg_axis_qdma_h2c_tdata),
  .m_axis_tkeep   (reg_axis_qdma_h2c_tkeep),
  .m_axis_tlast   (reg_axis_qdma_h2c_tlast),
  .m_axis_tid     (),
  .m_axis_tdest   (),
  .m_axis_tuser   ({reg_axis_qdma_h2c_tuser_size,reg_axis_qdma_h2c_tuser_src,reg_axis_qdma_h2c_tuser_dst}),
  .m_axis_tready  (reg_axis_qdma_h2c_tready),
  .aclk(axis_aclk),
  .aresetn(rstn)
);

// CMAC H2C SLICER
axi_stream_register_slice #(
  .TDATA_W  (512),
  .TID_W    (0),
  .TDEST_W  (0),
  .TUSER_W  (16 * 3),
  .MODE     ("full")
) axi_stream_register_slice_cmac_h2c (
  .s_axis_tvalid  (reg_axis_cmac_h2c_tvalid),
  .s_axis_tdata   (reg_axis_cmac_h2c_tdata),
  .s_axis_tkeep   (reg_axis_cmac_h2c_tkeep),
  .s_axis_tlast   (reg_axis_cmac_h2c_tlast),
  .s_axis_tid     (),
  .s_axis_tdest   (),
  .s_axis_tuser   ({reg_axis_cmac_h2c_tuser_size,reg_axis_cmac_h2c_tuser_src,reg_axis_cmac_h2c_tuser_dst}),
  .s_axis_tready  (reg_axis_cmac_h2c_tready),


  .m_axis_tvalid  (m_axis_cmac_h2c_tvalid),
  .m_axis_tdata   (m_axis_cmac_h2c_tdata),
  .m_axis_tkeep   (m_axis_cmac_h2c_tkeep),
  .m_axis_tlast   (m_axis_cmac_h2c_tlast),
  .m_axis_tid     (),
  .m_axis_tdest   (),
  .m_axis_tuser   ({m_axis_cmac_h2c_tuser_size,m_axis_cmac_h2c_tuser_src,m_axis_cmac_h2c_tuser_dst}),
  .m_axis_tready  (m_axis_cmac_h2c_tready),
  .aclk(axis_aclk),
  .aresetn(rstn)
);

// CMAC C2H SLICER
axi_stream_register_slice #(
  .TDATA_W  (512),
  .TID_W    (0),
  .TDEST_W  (0),
  .TUSER_W  (16 * 3),
  .MODE     ("full")
) axi_stream_register_slice_cmac_c2h (
  .s_axis_tvalid  (s_axis_cmac_c2h_tvalid),
  .s_axis_tdata   (s_axis_cmac_c2h_tdata),
  .s_axis_tkeep   (s_axis_cmac_c2h_tkeep),
  .s_axis_tlast   (s_axis_cmac_c2h_tlast),
  .s_axis_tid     (),
  .s_axis_tdest   (),
  .s_axis_tuser   ({s_axis_cmac_c2h_tuser_size,s_axis_cmac_c2h_tuser_src,s_axis_cmac_c2h_tuser_dst}),
  .s_axis_tready  (s_axis_cmac_c2h_tready),

  .m_axis_tvalid  (reg_axis_cmac_c2h_tvalid),
  .m_axis_tdata   (reg_axis_cmac_c2h_tdata),
  .m_axis_tkeep   (reg_axis_cmac_c2h_tkeep),
  .m_axis_tlast   (reg_axis_cmac_c2h_tlast),
  .m_axis_tid     (),
  .m_axis_tdest   (),
  .m_axis_tuser   ({reg_axis_cmac_c2h_tuser_size,reg_axis_cmac_c2h_tuser_src,reg_axis_cmac_c2h_tuser_dst}),
  .m_axis_tready  (reg_axis_cmac_c2h_tready),
  .aclk(axis_aclk),
  .aresetn(rstn)
);


AXI_BUS #(
  .AXI_ADDR_WIDTH(34),
  .AXI_DATA_WIDTH(512),
  .AXI_ID_WIDTH(4),
  .AXI_USER_WIDTH(0)
) axi_mm_pf_to_hbm[3:0] ();

logic [63:0]  m_axi_sys_mem_awaddr_internal;
logic [63:0]  m_axi_sys_mem_araddr_internal;

logic         axis_parser_to_filter_tvalid;
logic [511:0] axis_parser_to_filter_tdata;
logic  [63:0] axis_parser_to_filter_tkeep;
logic         axis_parser_to_filter_tlast;
logic  [47:0] axis_parser_to_filter_tuser;
logic         axis_parser_to_filter_tready;

logic         axis_filter_to_replication_tvalid;
logic [511:0] axis_filter_to_replication_tdata;
logic  [63:0] axis_filter_to_replication_tkeep;
logic         axis_filter_to_replication_tlast;
logic  [47:0] axis_filter_to_replication_tuser;
logic         axis_filter_to_replication_tready;

logic         axis_replication_to_deparser_tvalid [N_THREADS];
logic [511:0] axis_replication_to_deparser_tdata  [N_THREADS];
logic  [63:0] axis_replication_to_deparser_tkeep  [N_THREADS];
logic         axis_replication_to_deparser_tlast  [N_THREADS]; 
logic         axis_replication_to_deparser_tready [N_THREADS];

logic         axis_deparser_to_arbiter_tvalid	[N_THREADS];
logic [511:0] axis_deparser_to_arbiter_tdata 	[N_THREADS];
logic  [63:0] axis_deparser_to_arbiter_tkeep 	[N_THREADS];
logic         axis_deparser_to_arbiter_tlast 	[N_THREADS];
logic         axis_deparser_to_arbiter_tready	[N_THREADS];

st_metadata   parser_metadata;
logic         parser_metadata_valid;

st_metadata   replication_metadata       [N_THREADS];
logic         replication_metadata_valid [N_THREADS];


// The valid signal for the parser's incoming user metadata is raised only on the first beat
logic parser_metadata_in_valid;
logic parser_metadata_in_valid_toggle;

assign parser_metadata_in_valid = parser_metadata_in_valid_toggle && reg_axis_cmac_c2h_tvalid && reg_axis_cmac_c2h_tready;

always_ff @(posedge axis_aclk) begin
  if(~axi_rstn) begin
    parser_metadata_in_valid_toggle <= 1'b1;
  end
  else begin
    if (reg_axis_cmac_c2h_tvalid & reg_axis_cmac_c2h_tready && !reg_axis_cmac_c2h_tlast) 
      parser_metadata_in_valid_toggle <= 1'b0;  
    if (reg_axis_cmac_c2h_tvalid && reg_axis_cmac_c2h_tready && reg_axis_cmac_c2h_tlast)
      parser_metadata_in_valid_toggle <= 1'b1;
  end
end

// The filter signal from parser is stored until next value
logic is_replication;
logic is_replication_reg;

assign axis_parser_to_filter_tdest = parser_metadata_valid ? is_replication : is_replication_reg;

always_ff @(posedge axis_aclk) begin
  if(~axi_rstn)
    is_replication_reg <= 1'b0;
  else if (parser_metadata_valid)
    is_replication_reg <= is_replication;
end

// Split the QDMA's tuser into each part
logic [47:0] axis_qdma_c2h_tuser;
assign reg_axis_qdma_c2h_tuser_size = axis_qdma_c2h_tuser[47:32];
assign reg_axis_qdma_c2h_tuser_src  = axis_qdma_c2h_tuser[32:16];
assign reg_axis_qdma_c2h_tuser_dst  = axis_qdma_c2h_tuser[15:0];

packet_parser packet_parser_inst (
  .s_axis_tvalid           (reg_axis_cmac_c2h_tvalid), 
  .s_axis_tdata            (reg_axis_cmac_c2h_tdata), 
  .s_axis_tkeep            (reg_axis_cmac_c2h_tkeep), 
  .s_axis_tlast            (reg_axis_cmac_c2h_tlast),
  .s_axis_tuser            ({reg_axis_cmac_c2h_tuser_size, reg_axis_cmac_c2h_tuser_src, reg_axis_cmac_c2h_tuser_dst}),
  .s_axis_tready           (reg_axis_cmac_c2h_tready), 
  .user_metadata_in        ('0),
  .user_metadata_in_valid  (parser_metadata_in_valid),

  .m_axis_tvalid           (axis_parser_to_filter_tvalid), 
  .m_axis_tdata            (axis_parser_to_filter_tdata), 
  .m_axis_tkeep            (axis_parser_to_filter_tkeep), 
  .m_axis_tlast            (axis_parser_to_filter_tlast),
  .m_axis_tuser            (axis_parser_to_filter_tuser),
  .m_axis_tready           (axis_parser_to_filter_tready), 
  .user_metadata_out       ({parser_metadata, is_replication}),
  .user_metadata_out_valid (parser_metadata_valid),

  .s_axis_aclk             (axis_aclk),
  .s_axis_aresetn          (rstn)
);

packet_filter packet_filter_inst (
  .s_axis_tvalid           (axis_parser_to_filter_tvalid), 
  .s_axis_tdata            (axis_parser_to_filter_tdata),
  .s_axis_tkeep            (axis_parser_to_filter_tkeep),
  .s_axis_tlast            (axis_parser_to_filter_tlast),
  .s_axis_tuser            (axis_parser_to_filter_tuser),
  .s_axis_tdest            (axis_parser_to_filter_tdest),
  .s_axis_tready           (axis_parser_to_filter_tready),

  .m_axis_tvalid           ({axis_filter_to_replication_tvalid, reg_axis_qdma_c2h_tvalid}),
  .m_axis_tdata            ({axis_filter_to_replication_tdata,  reg_axis_qdma_c2h_tdata}),
  .m_axis_tkeep            ({axis_filter_to_replication_tkeep,  reg_axis_qdma_c2h_tkeep}),
  .m_axis_tlast            ({axis_filter_to_replication_tlast,  reg_axis_qdma_c2h_tlast}),
  .m_axis_tuser            ({axis_filter_to_replication_tuser,  axis_qdma_c2h_tuser}),
  .m_axis_tdest            (),
  .m_axis_tready           ({axis_filter_to_replication_tready, reg_axis_qdma_c2h_tready}),

  .aclk                    (axis_aclk),
  .aresetn                 (rstn)
);

replication_subsystem_mt #(
    .DATA_WIDTH		  (kvs_pkg::DATA_WIDTH),
    .NODE_IP		    (kvs_pkg::NODE_IP),
    .NODE_MAC		    (kvs_pkg::NODE_MAC),
    .MAX_NODES		  (kvs_pkg::MAX_NODES),
    .BUCKET_SIZE	  (kvs_pkg::BUCKET_SIZE),
    .NUM_HASHES		  (kvs_pkg::NUM_HASHES),
    .HASH_WIDTH		  (kvs_pkg::HASH_WIDTH),
    .TIMER_WIDTH	  (kvs_pkg::TIMER_WIDTH),
    .SEED			      (kvs_pkg::SEED),
    .USE_CONTROLLER	(kvs_pkg::USE_CONTROLLER),
    .TAP_MASK		    (kvs_pkg::TAP_MASK),
    .HASH_MATRIX	  (kvs_pkg::HASH_MATRIX),
    .N_THREADS		  (kvs_pkg::N_THREADS)
) replication_subsystem_mt_instance (
  
  .axis_aclk          (axis_aclk),
  .axil_aclk          (axil_aclk),
  .axi_rstn           (rstn),

  .s_axis_tvalid      (axis_filter_to_replication_tvalid),
  .s_axis_tdata       (axis_filter_to_replication_tdata),
  .s_axis_tkeep       (axis_filter_to_replication_tkeep),
  .s_axis_tlast       (axis_filter_to_replication_tlast),
  .s_axis_tready      (axis_filter_to_replication_tready),

  .metadata_in        (parser_metadata),
  .metadata_in_valid  (parser_metadata_valid && is_replication),

  .m_axis_tvalid      (axis_replication_to_deparser_tvalid),
  .m_axis_tdata       (axis_replication_to_deparser_tdata),
  .m_axis_tkeep       (axis_replication_to_deparser_tkeep),
  .m_axis_tlast       (axis_replication_to_deparser_tlast),
  .m_axis_tready      (axis_replication_to_deparser_tready),

  .metadata_out       (replication_metadata),
  .metadata_out_valid (replication_metadata_valid),

  // kvs engine to mem (4 channels)
  .m_axi_mem_araddr   ({axi_mm_pf_to_hbm[0].ar_addr,  axi_mm_pf_to_hbm[1].ar_addr,  axi_mm_pf_to_hbm[2].ar_addr,  axi_mm_pf_to_hbm[3].ar_addr }),
  .m_axi_mem_arburst  ({axi_mm_pf_to_hbm[0].ar_burst, axi_mm_pf_to_hbm[1].ar_burst, axi_mm_pf_to_hbm[2].ar_burst, axi_mm_pf_to_hbm[3].ar_burst }),
  .m_axi_mem_arcache  ({axi_mm_pf_to_hbm[0].ar_cache, axi_mm_pf_to_hbm[1].ar_cache, axi_mm_pf_to_hbm[2].ar_cache, axi_mm_pf_to_hbm[3].ar_cache }),
  .m_axi_mem_arlen    ({axi_mm_pf_to_hbm[0].ar_len,   axi_mm_pf_to_hbm[1].ar_len,   axi_mm_pf_to_hbm[2].ar_len,   axi_mm_pf_to_hbm[3].ar_len }),
  .m_axi_mem_arlock   ({axi_mm_pf_to_hbm[0].ar_lock,  axi_mm_pf_to_hbm[1].ar_lock,  axi_mm_pf_to_hbm[2].ar_lock,  axi_mm_pf_to_hbm[3].ar_lock }),
  .m_axi_mem_arprot   ({axi_mm_pf_to_hbm[0].ar_prot,  axi_mm_pf_to_hbm[1].ar_prot,  axi_mm_pf_to_hbm[2].ar_prot,  axi_mm_pf_to_hbm[3].ar_prot }),
  .m_axi_mem_arready  ({axi_mm_pf_to_hbm[0].ar_ready, axi_mm_pf_to_hbm[1].ar_ready, axi_mm_pf_to_hbm[2].ar_ready, axi_mm_pf_to_hbm[3].ar_ready }),
  .m_axi_mem_arsize   ({axi_mm_pf_to_hbm[0].ar_size,  axi_mm_pf_to_hbm[1].ar_size,  axi_mm_pf_to_hbm[2].ar_size,  axi_mm_pf_to_hbm[3].ar_size }),
  .m_axi_mem_arvalid  ({axi_mm_pf_to_hbm[0].ar_valid, axi_mm_pf_to_hbm[1].ar_valid, axi_mm_pf_to_hbm[2].ar_valid, axi_mm_pf_to_hbm[3].ar_valid }),	
  .m_axi_mem_awaddr   ({axi_mm_pf_to_hbm[0].aw_addr,  axi_mm_pf_to_hbm[1].aw_addr,  axi_mm_pf_to_hbm[2].aw_addr,  axi_mm_pf_to_hbm[3].aw_addr }),
  .m_axi_mem_awburst  ({axi_mm_pf_to_hbm[0].aw_burst, axi_mm_pf_to_hbm[1].aw_burst, axi_mm_pf_to_hbm[2].aw_burst, axi_mm_pf_to_hbm[3].aw_burst }),	
  .m_axi_mem_awcache  ({axi_mm_pf_to_hbm[0].aw_cache, axi_mm_pf_to_hbm[1].aw_cache, axi_mm_pf_to_hbm[2].aw_cache, axi_mm_pf_to_hbm[3].aw_cache }),	
  .m_axi_mem_awlen    ({axi_mm_pf_to_hbm[0].aw_len,   axi_mm_pf_to_hbm[1].aw_len,   axi_mm_pf_to_hbm[2].aw_len,   axi_mm_pf_to_hbm[3].aw_len }),
  .m_axi_mem_awlock   ({axi_mm_pf_to_hbm[0].aw_lock,  axi_mm_pf_to_hbm[1].aw_lock,  axi_mm_pf_to_hbm[2].aw_lock,  axi_mm_pf_to_hbm[3].aw_lock }),
  .m_axi_mem_awprot   ({axi_mm_pf_to_hbm[0].aw_prot,  axi_mm_pf_to_hbm[1].aw_prot,  axi_mm_pf_to_hbm[2].aw_prot,  axi_mm_pf_to_hbm[3].aw_prot }),
  .m_axi_mem_awready  ({axi_mm_pf_to_hbm[0].aw_ready, axi_mm_pf_to_hbm[1].aw_ready, axi_mm_pf_to_hbm[2].aw_ready, axi_mm_pf_to_hbm[3].aw_ready }),	
  .m_axi_mem_awsize   ({axi_mm_pf_to_hbm[0].aw_size,  axi_mm_pf_to_hbm[1].aw_size,  axi_mm_pf_to_hbm[2].aw_size,  axi_mm_pf_to_hbm[3].aw_size }),
  .m_axi_mem_awvalid  ({axi_mm_pf_to_hbm[0].aw_valid, axi_mm_pf_to_hbm[1].aw_valid, axi_mm_pf_to_hbm[2].aw_valid, axi_mm_pf_to_hbm[3].aw_valid }),
  .m_axi_mem_bready   ({axi_mm_pf_to_hbm[0].b_ready,  axi_mm_pf_to_hbm[1].b_ready,  axi_mm_pf_to_hbm[2].b_ready,  axi_mm_pf_to_hbm[3].b_ready }),
  .m_axi_mem_bresp    ({axi_mm_pf_to_hbm[0].b_resp,   axi_mm_pf_to_hbm[1].b_resp,   axi_mm_pf_to_hbm[2].b_resp,   axi_mm_pf_to_hbm[3].b_resp }),
  .m_axi_mem_bvalid   ({axi_mm_pf_to_hbm[0].b_valid,  axi_mm_pf_to_hbm[1].b_valid,  axi_mm_pf_to_hbm[2].b_valid,  axi_mm_pf_to_hbm[3].b_valid }),
  .m_axi_mem_rdata    ({axi_mm_pf_to_hbm[0].r_data,   axi_mm_pf_to_hbm[1].r_data,   axi_mm_pf_to_hbm[2].r_data,   axi_mm_pf_to_hbm[3].r_data }),
  .m_axi_mem_rlast    ({axi_mm_pf_to_hbm[0].r_last,   axi_mm_pf_to_hbm[1].r_last,   axi_mm_pf_to_hbm[2].r_last,   axi_mm_pf_to_hbm[3].r_last }),
  .m_axi_mem_rready   ({axi_mm_pf_to_hbm[0].r_ready,  axi_mm_pf_to_hbm[1].r_ready,  axi_mm_pf_to_hbm[2].r_ready,  axi_mm_pf_to_hbm[3].r_ready }),
  .m_axi_mem_rresp    ({axi_mm_pf_to_hbm[0].r_resp,   axi_mm_pf_to_hbm[1].r_resp,   axi_mm_pf_to_hbm[2].r_resp,   axi_mm_pf_to_hbm[3].r_resp }),
  .m_axi_mem_rvalid   ({axi_mm_pf_to_hbm[0].r_valid,  axi_mm_pf_to_hbm[1].r_valid,  axi_mm_pf_to_hbm[2].r_valid,  axi_mm_pf_to_hbm[3].r_valid }),
  .m_axi_mem_wdata    ({axi_mm_pf_to_hbm[0].w_data,   axi_mm_pf_to_hbm[1].w_data,   axi_mm_pf_to_hbm[2].w_data,   axi_mm_pf_to_hbm[3].w_data }),
  .m_axi_mem_wlast    ({axi_mm_pf_to_hbm[0].w_last,   axi_mm_pf_to_hbm[1].w_last,   axi_mm_pf_to_hbm[2].w_last,   axi_mm_pf_to_hbm[3].w_last }),
  .m_axi_mem_wready   ({axi_mm_pf_to_hbm[0].w_ready,  axi_mm_pf_to_hbm[1].w_ready,  axi_mm_pf_to_hbm[2].w_ready,  axi_mm_pf_to_hbm[3].w_ready }),
  .m_axi_mem_wstrb    ({axi_mm_pf_to_hbm[0].w_strb,   axi_mm_pf_to_hbm[1].w_strb,   axi_mm_pf_to_hbm[2].w_strb,   axi_mm_pf_to_hbm[3].w_strb }),
  .m_axi_mem_wvalid   ({axi_mm_pf_to_hbm[0].w_valid,  axi_mm_pf_to_hbm[1].w_valid,  axi_mm_pf_to_hbm[2].w_valid,  axi_mm_pf_to_hbm[3].w_valid }),

  // unused IDs
  .m_axi_mem_arid({axi_mm_pf_to_hbm[0].ar_id,axi_mm_pf_to_hbm[1].ar_id,axi_mm_pf_to_hbm[2].ar_id,axi_mm_pf_to_hbm[3].ar_id}),
  .m_axi_mem_awid({axi_mm_pf_to_hbm[0].aw_id,axi_mm_pf_to_hbm[1].aw_id,axi_mm_pf_to_hbm[2].aw_id,axi_mm_pf_to_hbm[3].aw_id}),
  .m_axi_mem_rid ({axi_mm_pf_to_hbm[0].r_id ,axi_mm_pf_to_hbm[1].r_id ,axi_mm_pf_to_hbm[2].r_id ,axi_mm_pf_to_hbm[3].r_id }),
  .m_axi_mem_bid ({axi_mm_pf_to_hbm[0].b_id ,axi_mm_pf_to_hbm[1].b_id ,axi_mm_pf_to_hbm[2].b_id ,axi_mm_pf_to_hbm[3].b_id }),

  // axi lite cfg
  .s_axil_awvalid     (s_axil_awvalid),
  .s_axil_awaddr      (s_axil_awaddr),
  .s_axil_awready     (s_axil_awready),
  .s_axil_wvalid      (s_axil_wvalid),
  .s_axil_wdata       (s_axil_wdata),
  .s_axil_wready      (s_axil_wready),
  .s_axil_bvalid      (s_axil_bvalid),
  .s_axil_bresp       (s_axil_bresp),
  .s_axil_bready      (s_axil_bready),
  .s_axil_arvalid     (s_axil_arvalid),
  .s_axil_araddr      (s_axil_araddr),
  .s_axil_arready     (s_axil_arready),
  .s_axil_rvalid      (s_axil_rvalid),
  .s_axil_rdata       (s_axil_rdata),
  .s_axil_rresp       (s_axil_rresp),
  .s_axil_rready      (s_axil_rready)
);

genvar i;
generate
  	for (i = 0; i < N_THREADS; i = i + 1) begin : block
  	  	packet_deparser packet_deparser_inst (
  	  		.s_axis_tvalid           (axis_replication_to_deparser_tvalid[i]), 
  	  		.s_axis_tdata            (axis_replication_to_deparser_tdata[i]), 
  	  		.s_axis_tkeep            (axis_replication_to_deparser_tkeep[i]), 
  	  		.s_axis_tlast            (axis_replication_to_deparser_tlast[i]), 
  	  		.s_axis_tready           (axis_replication_to_deparser_tready[i]), 
  	  		.user_metadata_in        ({replication_metadata[i], NODE_IP, NODE_MAC}),
  	  		.user_metadata_in_valid  (replication_metadata_valid[i]),

  	  		.m_axis_tvalid           (axis_deparser_to_arbiter_tvalid[i]), 
  	  		.m_axis_tdata            (axis_deparser_to_arbiter_tdata[i]), 
  	  		.m_axis_tkeep            (axis_deparser_to_arbiter_tkeep[i]), 
  	  		.m_axis_tlast            (axis_deparser_to_arbiter_tlast[i]), 
  	  		.m_axis_tready           (axis_deparser_to_arbiter_tready[i]), 
  	  		.user_metadata_out       (),
  	  		.user_metadata_out_valid (),

  	  		.s_axis_aclk             (axis_aclk),
  	  		.s_axis_aresetn          (rstn)
  	  	);
  	end
endgenerate


packet_arbiter_mt packet_arbiter_inst (
  .s_axis_tvalid           ({axis_deparser_to_arbiter_tvalid[3], axis_deparser_to_arbiter_tvalid[2], axis_deparser_to_arbiter_tvalid[1], axis_deparser_to_arbiter_tvalid[0], reg_axis_qdma_h2c_tvalid}), 
  .s_axis_tdata            ({axis_deparser_to_arbiter_tdata [3], axis_deparser_to_arbiter_tdata [2], axis_deparser_to_arbiter_tdata [1], axis_deparser_to_arbiter_tdata [0], reg_axis_qdma_h2c_tdata}),
  .s_axis_tkeep            ({axis_deparser_to_arbiter_tkeep [3], axis_deparser_to_arbiter_tkeep [2], axis_deparser_to_arbiter_tkeep [1], axis_deparser_to_arbiter_tkeep [0], reg_axis_qdma_h2c_tkeep}),
  .s_axis_tlast            ({axis_deparser_to_arbiter_tlast [3], axis_deparser_to_arbiter_tlast [2], axis_deparser_to_arbiter_tlast [1], axis_deparser_to_arbiter_tlast [0], reg_axis_qdma_h2c_tlast}),
  .s_axis_tuser            ({{16'h0, 16'h0, 16'h0040},{16'h0, 16'h0, 16'h0040},{16'h0, 16'h0, 16'h0040},{16'h0, 16'h0, 16'h0040}, {reg_axis_qdma_h2c_tuser_size, reg_axis_qdma_h2c_tuser_src, reg_axis_qdma_h2c_tuser_dst}}),
  .s_axis_tready           ({axis_deparser_to_arbiter_tready[3], axis_deparser_to_arbiter_tready[2], axis_deparser_to_arbiter_tready[1], axis_deparser_to_arbiter_tready[0],reg_axis_qdma_h2c_tready}),

  .m_axis_tvalid           (reg_axis_cmac_h2c_tvalid),
  .m_axis_tdata            (reg_axis_cmac_h2c_tdata),
  .m_axis_tkeep            (reg_axis_cmac_h2c_tkeep),
  .m_axis_tlast            (reg_axis_cmac_h2c_tlast),
  .m_axis_tuser            ({reg_axis_cmac_h2c_tuser_size, reg_axis_cmac_h2c_tuser_src, reg_axis_cmac_h2c_tuser_dst}),
  .m_axis_tready           (reg_axis_cmac_h2c_tready),

  .s_req_suppress          (2'b0),
  .aclk                    (axis_aclk),
  .aresetn                 (rstn)
);

// Host memory mapping
// confines host memory region, avoiding to spill into not reserved ram, wraps around a the end
assign m_axi_sys_mem_araddr = (m_axi_sys_mem_araddr_internal & MASK_HOST_MEM) | BASE_HOST_MEM;
assign m_axi_sys_mem_awaddr = (m_axi_sys_mem_awaddr_internal & MASK_HOST_MEM) | BASE_HOST_MEM;
assign m_axi_sys_mem_arid   = '0;
assign m_axi_sys_mem_awid   = '0;
assign m_axi_sys_mem_wuser  = '0;

hbm_interface_wrapper i_hbm(
    
    .QDMA_AXI_araddr (s_axi_araddr),
    .QDMA_AXI_arburst (s_axi_arburst),
    .QDMA_AXI_arcache (s_axi_arcache),
    .QDMA_AXI_arid (s_axi_arid),
    .QDMA_AXI_arlen (s_axi_arlen),
    .QDMA_AXI_arlock (s_axi_arlock),
    .QDMA_AXI_arprot (s_axi_arprot),
    .QDMA_AXI_arqos (s_axi_arqos),
    .QDMA_AXI_arready (s_axi_arready),
    .QDMA_AXI_arsize (s_axi_arsize),
    .QDMA_AXI_aruser (s_axi_aruser),
    .QDMA_AXI_arvalid (s_axi_arvalid),
    .QDMA_AXI_awaddr (s_axi_awaddr),
    .QDMA_AXI_awburst (s_axi_awburst),
    .QDMA_AXI_awcache (s_axi_awcache),
    .QDMA_AXI_awid (s_axi_awid),
    .QDMA_AXI_awlen (s_axi_awlen),
    .QDMA_AXI_awlock (s_axi_awlock),
    .QDMA_AXI_awprot (s_axi_awprot),
    .QDMA_AXI_awqos (s_axi_awqos),
    .QDMA_AXI_awready (s_axi_awready),
    .QDMA_AXI_awsize (s_axi_awsize),
    .QDMA_AXI_awuser (s_axi_awuser),
    .QDMA_AXI_awvalid (s_axi_awvalid),
    .QDMA_AXI_bid (s_axi_bid),
    .QDMA_AXI_bready (s_axi_bready),
    .QDMA_AXI_bresp (s_axi_bresp),
    .QDMA_AXI_bvalid (s_axi_bvalid),
    .QDMA_AXI_rdata (s_axi_rdata),
    .QDMA_AXI_rid (s_axi_rid),
    .QDMA_AXI_rlast (s_axi_rlast),
    .QDMA_AXI_rready (s_axi_rready),
    .QDMA_AXI_rresp (s_axi_rresp),
    .QDMA_AXI_rvalid (s_axi_rvalid),
    .QDMA_AXI_wdata (s_axi_wdata),
    .QDMA_AXI_wlast (s_axi_wlast),
    .QDMA_AXI_wready (s_axi_wready),
    .QDMA_AXI_wstrb (s_axi_wstrb),
    .QDMA_AXI_wuser (s_axi_wuser),
    .QDMA_AXI_wvalid (s_axi_wvalid),

    `AXI_ASSIGN_MASTER_BUS_TO_HBM(S00,axi_mm_pf_to_hbm[0])
    `AXI_ASSIGN_MASTER_BUS_TO_HBM(S01,axi_mm_pf_to_hbm[1])
    `AXI_ASSIGN_MASTER_BUS_TO_HBM(S02,axi_mm_pf_to_hbm[2])
    `AXI_ASSIGN_MASTER_BUS_TO_HBM(S03,axi_mm_pf_to_hbm[3])

    .aresetn_0 (axi_rstn),
    .axi_clk   (axis_aclk),

	  .apb_complete_0_0  (apb_complete_0),
	  .apb_complete_1_0  (),

    .HBM_REF_CLK_0_0 (hbm_ref_clk)
);

`ifdef __simulation__
  // --------------------------------------------------------------------------------
  // Debug Monitors
  // --------------------------------------------------------------------------------

  // 1. QDMA H2C Interface (from Host to Card)
  always @(posedge axis_aclk) begin
    if (s_axis_qdma_h2c_tvalid && s_axis_qdma_h2c_tready) begin
      $display("[%t] KVS_SUBSYS QDMA_H2C (IN):\n data=0x%h, keep=0x%h, last=%b, size=%d, src=%d, dst=%d", 
              $time, s_axis_qdma_h2c_tdata, s_axis_qdma_h2c_tkeep, s_axis_qdma_h2c_tlast, 
              s_axis_qdma_h2c_tuser_size, s_axis_qdma_h2c_tuser_src, s_axis_qdma_h2c_tuser_dst);
    end
  end

  // 2. QDMA C2H Interface (from Card to Host)
  always @(posedge axis_aclk) begin
    if (m_axis_qdma_c2h_tvalid && m_axis_qdma_c2h_tready) begin
      $display("[%t] KVS_SUBSYS QDMA_C2H (OUT):\n data=0x%h, keep=0x%h, last=%b, size=%d, src=%d, dst=%d", 
              $time, m_axis_qdma_c2h_tdata, m_axis_qdma_c2h_tkeep, m_axis_qdma_c2h_tlast,
              m_axis_qdma_c2h_tuser_size, m_axis_qdma_c2h_tuser_src, m_axis_qdma_c2h_tuser_dst);
    end
  end

  // 3. CMAC H2C Interface (from Network to Card - filtered output to shell if any)
  always @(posedge axis_aclk) begin
    if (reg_axis_cmac_h2c_tvalid && reg_axis_cmac_h2c_tready) begin
      $display("[%t] KVS_SUBSYS CMAC_H2C (OUT):\n data=0x%h, keep=0x%h, last=%b, size=%d, src=%d, dst=%d", 
              $time, reg_axis_cmac_h2c_tdata, reg_axis_cmac_h2c_tkeep, reg_axis_cmac_h2c_tlast,
              reg_axis_cmac_h2c_tuser_size, reg_axis_cmac_h2c_tuser_src, reg_axis_cmac_h2c_tuser_dst);
    end
  end

  // 4. CMAC C2H Interface (from Card to Network - incoming packets)
  always @(posedge axis_aclk) begin
    if (s_axis_cmac_c2h_tvalid && s_axis_cmac_c2h_tready) begin
      $display("[%t] KVS_SUBSYS CMAC_C2H (IN):\n data=0x%h, keep=0x%h, last=%b, size=%d, src=%d, dst=%d", 
              $time, s_axis_cmac_c2h_tdata, s_axis_cmac_c2h_tkeep, s_axis_cmac_c2h_tlast,
              s_axis_cmac_c2h_tuser_size, s_axis_cmac_c2h_tuser_src, s_axis_cmac_c2h_tuser_dst);
    end
  end


  // 7. Internal: Parser to Filter
  always @(posedge axis_aclk) begin
    if (axis_parser_to_filter_tvalid && axis_parser_to_filter_tready) begin
      $display("[%t] KVS_SUBSYS PARSER->FILTER:\n data=0x%h, keep=0x%h, last=%b, user=0x%h", 
              $time, 
              axis_parser_to_filter_tdata, 
              axis_parser_to_filter_tkeep, 
              axis_parser_to_filter_tlast, 
              axis_parser_to_filter_tuser
            );
    end
  end

  // 8. Internal: Filter to Replication
  always @(posedge axis_aclk) begin
    if (axis_filter_to_replication_tvalid && axis_filter_to_replication_tready) begin
      $display("[%t] KVS_SUBSYS FILTER->REPL:\n data=0x%h, keep=0x%h, last=%b, user=0x%h", 
              $time, 
              axis_filter_to_replication_tdata, 
              axis_filter_to_replication_tkeep, 
              axis_filter_to_replication_tlast, 
              axis_filter_to_replication_tuser
            );
    end
  end

  // 9. Internal: Replication to Deparser
  always @(posedge axis_aclk) begin
    for (int j = 0; j < N_THREADS; j++) begin
      if (axis_replication_to_deparser_tvalid[j] && axis_replication_to_deparser_tready[j]) begin
        $display("[%t] [HT: %d] KVS REPL->DEPARSER:\n data=0x%h, keep=0x%h, last=%b", 
                $time, 
                j,
                axis_replication_to_deparser_tdata[j], 
                axis_replication_to_deparser_tkeep[j], 
                axis_replication_to_deparser_tlast[j]
              );
      end
    end
  end

  // 10. Internal: Deparser to Arbiter
  always @(posedge axis_aclk) begin
    for (int j = 0; j < N_THREADS; j++) begin
      if (axis_deparser_to_arbiter_tvalid[j] && axis_deparser_to_arbiter_tready[j]) begin
        $display("[%t] [HT: %d] KVS DEPARSER->ARBITER:\n data=0x%h, keep=0x%h, last=%b", 
                $time,
                j, 
                axis_deparser_to_arbiter_tdata[j], 
                axis_deparser_to_arbiter_tkeep[j], 
                axis_deparser_to_arbiter_tlast[j]
              );
      end
    end
  end

  // Metadata Monitors
  always @(posedge axis_aclk) begin
    if (parser_metadata_valid) begin
      $display("[%t] KVS_SUBSYS PARSER_META:\n ip=0x%h, mac=0x%h, opcode=%d, index=%d, key=0x%h, is_repl=%b", 
              $time, 
              parser_metadata.ip, 
              parser_metadata.mac, 
              parser_metadata.opcode, 
              parser_metadata.index,
              parser_metadata.key,
              is_replication
            );
    end
  end

  always @(posedge axis_aclk) begin
    for (int j = 0; j < N_THREADS; j++) begin
      if (replication_metadata_valid[j]) begin
        $display("[%t] [HT: %d] KVS REPL_META:\n ip=0x%h, mac=0x%h, opcode=%d, index=%d, key=0x%h", 
                $time, 
                j,
                replication_metadata[j].ip, 
                replication_metadata[j].mac, 
                replication_metadata[j].opcode, 
                replication_metadata[j].index,
                replication_metadata[j].key
              );
      end
    end
  end

  // 11. HBM AXI Monitor (axi_mm_pf_to_hbm)
  // Loop over the 4 channels
  genvar k;
  generate
    for (k = 0; k < 4; k = k + 1) begin : axi_mon
      always @(posedge axis_aclk) begin
        // Write Address Channel
        if (axi_mm_pf_to_hbm[k].aw_valid && axi_mm_pf_to_hbm[k].aw_ready) begin
          $display("[%t] KVS_SUBSYS HBM_AXI[%0d]\n AW: addr=0x%h, len=%d, size=%d, burst=%d", 
                  $time, k, 
                  axi_mm_pf_to_hbm[k].aw_addr, 
                  axi_mm_pf_to_hbm[k].aw_len, 
                  axi_mm_pf_to_hbm[k].aw_size, 
                  axi_mm_pf_to_hbm[k].aw_burst);
        end
        // Write Data Channel
        if (axi_mm_pf_to_hbm[k].w_valid && axi_mm_pf_to_hbm[k].w_ready) begin
          $display("[%t] KVS_SUBSYS HBM_AXI[%0d]\n W: data=0x%h, last=%b, strb=0x%h", 
                  $time, k, 
                  axi_mm_pf_to_hbm[k].w_data, 
                  axi_mm_pf_to_hbm[k].w_last, 
                  axi_mm_pf_to_hbm[k].w_strb);
        end
        // Write Response Channel
        if (axi_mm_pf_to_hbm[k].b_valid && axi_mm_pf_to_hbm[k].b_ready) begin
          $display("[%t] KVS_SUBSYS HBM_AXI[%0d]\n B: resp=%d", 
                  $time, k, 
                  axi_mm_pf_to_hbm[k].b_resp);
        end
        // Read Address Channel
        if (axi_mm_pf_to_hbm[k].ar_valid && axi_mm_pf_to_hbm[k].ar_ready) begin
          $display("[%t] KVS_SUBSYS HBM_AXI[%0d]\n AR: addr=0x%h, len=%d, size=%d, burst=%d", 
                  $time, k, 
                  axi_mm_pf_to_hbm[k].ar_addr, 
                  axi_mm_pf_to_hbm[k].ar_len, 
                  axi_mm_pf_to_hbm[k].ar_size, 
                  axi_mm_pf_to_hbm[k].ar_burst);
        end
        // Read Data Channel
        if (axi_mm_pf_to_hbm[k].r_valid && axi_mm_pf_to_hbm[k].r_ready) begin
          $display("[%t] KVS_SUBSYS HBM_AXI[%0d]\n R: data=0x%h, last=%b, resp=%d", 
                  $time, k, 
                  axi_mm_pf_to_hbm[k].r_data, 
                  axi_mm_pf_to_hbm[k].r_last, 
                  axi_mm_pf_to_hbm[k].r_resp);
        end
      end
    end
  endgenerate

`endif

endmodule;