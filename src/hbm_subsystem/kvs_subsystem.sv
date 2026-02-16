`timescale 1ns/1ps

`include "axi_assign.svh"
`include "axi_typedef.svh"
`include "axi_.svh"
`include "hbm_axi.svh"



module kvs_subsystem 
import metadata_pkg::*;
import axi_pkg::*;
import kvs_pkg::*;
#(
  parameter int                     DATA_WIDTH      = kvs_pkg::DATA_WIDTH,     
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
  parameter logic [TIMER_WIDTH-1:0] TAP_MASK        = kvs_pkg::TAP_MASK
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
  
  always_ff @(posedge axis_aclk) begin
     if(~axi_rstn)
       apb_complete_reg <= 1'b0;
     else
       apb_complete_reg <= apb_complete_0;
  end

  assign rstn = axi_rstn && apb_complete_reg;

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

// ------------------------------------------------------------------------------------------------------
// INTERNAL LOGIC
// ------------------------------------------------------------------------------------------------------

logic                 [63:0]  m_axi_sys_mem_awaddr_internal;
logic                 [63:0]  m_axi_sys_mem_araddr_internal;

logic  [33:0] axi_araddr   [kvs_pkg::NUM_HASHES];
logic   [1:0] axi_arburst  [kvs_pkg::NUM_HASHES];
logic   [3:0] axi_arcache  [kvs_pkg::NUM_HASHES];
logic   [3:0] axi_arid     [kvs_pkg::NUM_HASHES];
logic   [3:0] axi_arlen    [kvs_pkg::NUM_HASHES];
logic   [1:0] axi_arlock   [kvs_pkg::NUM_HASHES];
logic   [2:0] axi_arprot   [kvs_pkg::NUM_HASHES];
logic         axi_arready  [kvs_pkg::NUM_HASHES];
logic   [2:0] axi_arsize   [kvs_pkg::NUM_HASHES];
logic         axi_arvalid  [kvs_pkg::NUM_HASHES];
logic  [33:0] axi_awaddr   [kvs_pkg::NUM_HASHES];
logic   [1:0] axi_awburst  [kvs_pkg::NUM_HASHES];
logic   [3:0] axi_awcache  [kvs_pkg::NUM_HASHES];
logic   [3:0] axi_awid     [kvs_pkg::NUM_HASHES];
logic   [3:0] axi_awlen    [kvs_pkg::NUM_HASHES];
logic   [1:0] axi_awlock   [kvs_pkg::NUM_HASHES];
logic   [2:0] axi_awprot   [kvs_pkg::NUM_HASHES];
logic         axi_awready  [kvs_pkg::NUM_HASHES];
logic   [2:0] axi_awsize   [kvs_pkg::NUM_HASHES];
logic         axi_awvalid  [kvs_pkg::NUM_HASHES];
logic   [3:0] axi_bid      [kvs_pkg::NUM_HASHES];
logic         axi_bready   [kvs_pkg::NUM_HASHES];
logic   [1:0] axi_bresp    [kvs_pkg::NUM_HASHES];
logic         axi_bvalid   [kvs_pkg::NUM_HASHES];
logic [255:0] axi_rdata    [kvs_pkg::NUM_HASHES];
logic   [3:0] axi_rid      [kvs_pkg::NUM_HASHES];
logic         axi_rlast    [kvs_pkg::NUM_HASHES];
logic         axi_rready   [kvs_pkg::NUM_HASHES];
logic   [1:0] axi_rresp    [kvs_pkg::NUM_HASHES];
logic         axi_rvalid   [kvs_pkg::NUM_HASHES];
logic [255:0] axi_wdata    [kvs_pkg::NUM_HASHES];
logic         axi_wlast    [kvs_pkg::NUM_HASHES];
logic         axi_wready   [kvs_pkg::NUM_HASHES];
logic  [31:0] axi_wstrb    [kvs_pkg::NUM_HASHES];
logic         axi_wvalid   [kvs_pkg::NUM_HASHES];

logic         axis_dm_write_tvalid;
logic [511:0] axis_dm_write_tdata;
logic  [63:0] axis_dm_write_tkeep;
logic         axis_dm_write_tlast;
logic         axis_dm_write_tready;

logic         axis_dm_read_tvalid;
logic [511:0] axis_dm_read_tdata;
logic  [63:0] axis_dm_read_tkeep;
logic         axis_dm_read_tlast;
logic         axis_dm_read_tready;

logic         axis_dm_write_cmd_tvalid;
logic  [79:0] axis_dm_write_cmd_tdata;
logic         axis_dm_write_cmd_tready;

logic         axis_dm_read_cmd_tvalid;
logic  [79:0] axis_dm_read_cmd_tdata;
logic         axis_dm_read_cmd_tready;

logic   [7:0] axis_dm_write_sts_tdata;
logic         axis_dm_write_sts_tkeep;
logic         axis_dm_write_sts_tlast;
logic         axis_dm_write_sts_tvalid;
logic         axis_dm_write_sts_tready;

logic   [7:0] axis_dm_read_sts_tdata;
logic         axis_dm_read_sts_tkeep;
logic         axis_dm_read_sts_tlast;
logic         axis_dm_read_sts_tvalid;
logic         axis_dm_read_sts_tready;

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

logic         axis_replication_to_deparser_tvalid;
logic [511:0] axis_replication_to_deparser_tdata;
logic  [63:0] axis_replication_to_deparser_tkeep;
logic         axis_replication_to_deparser_tlast;
logic         axis_replication_to_deparser_tready;

logic         axis_deparser_to_arbiter_tvalid;
logic [511:0] axis_deparser_to_arbiter_tdata;
logic  [63:0] axis_deparser_to_arbiter_tkeep;
logic         axis_deparser_to_arbiter_tlast;
logic         axis_deparser_to_arbiter_tready;

st_metadata   parser_metadata;
logic         parser_metadata_valid;
st_metadata   replication_metadata;
logic         replication_metadata_valid;

assign axis_dm_write_sts_tready = 1'b1;
assign axis_dm_read_sts_tready  = 1'b1;


// The valid signal for the parser's incoming user metadata is raised only on the first beat
logic parser_metadata_in_valid;
logic parser_metadata_in_valid_toggle;

assign parser_metadata_in_valid = parser_metadata_in_valid_toggle && reg_axis_cmac_c2h_tvalid && reg_axis_cmac_c2h_tready;

always_ff @(posedge axis_aclk) begin
  if(~axi_rstn) begin
    parser_metadata_in_valid_toggle <= 1'b1;
  end
  else begin
    if (reg_axis_cmac_c2h_tvalid && reg_axis_cmac_c2h_tready && !reg_axis_cmac_c2h_tlast) 
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

replication_subsystem #(
  .DATA_WIDTH                (DATA_WIDTH),
  .FIFO_DEPTH                (16),
  .NODE_IP                   (kvs_pkg::NODE_IP),
  .NODE_MAC                  (kvs_pkg::NODE_MAC),
  .MAX_NODES                 (kvs_pkg::MAX_NODES),
  .BUCKET_SIZE               (kvs_pkg::BUCKET_SIZE),
  .NUM_HASHES                (kvs_pkg::NUM_HASHES),
  .HASH_WIDTH                (kvs_pkg::HASH_WIDTH),
  .TIMER_WIDTH               (kvs_pkg::TIMER_WIDTH),
  .SEED                      (kvs_pkg::SEED),
  .TAP_MASK                  (kvs_pkg::TAP_MASK),
  .USE_CONTROLLER            (kvs_pkg::USE_CONTROLLER),
  .HASH_MATRIX               (kvs_pkg::HASH_MATRIX)
) replication_subsystem_inst (
  .axis_aclk                 (axis_aclk),
  .axil_aclk                 (axil_aclk),
  .axi_rstn                  (rstn),

  .s_axil_awvalid            (s_axil_awvalid),
  .s_axil_awaddr             (s_axil_awaddr),
  .s_axil_awready            (s_axil_awready),
  .s_axil_wvalid             (s_axil_wvalid),
  .s_axil_wdata              (s_axil_wdata),
  .s_axil_wready             (s_axil_wready),
  .s_axil_bvalid             (s_axil_bvalid),
  .s_axil_bresp              (s_axil_bresp),
  .s_axil_bready             (s_axil_bready),
  .s_axil_arvalid            (s_axil_arvalid),
  .s_axil_araddr             (s_axil_araddr),
  .s_axil_arready            (s_axil_arready),
  .s_axil_rvalid             (s_axil_rvalid),
  .s_axil_rdata              (s_axil_rdata),
  .s_axil_rresp              (s_axil_rresp),
  .s_axil_rready             (s_axil_rready),

  .s_axis_tvalid             (axis_filter_to_replication_tvalid),
  .s_axis_tdata              (axis_filter_to_replication_tdata),
  .s_axis_tkeep              (axis_filter_to_replication_tkeep),
  .s_axis_tlast              (axis_filter_to_replication_tlast),
  .s_axis_tready             (axis_filter_to_replication_tready),
  .metadata_in               (parser_metadata),
  .metadata_in_valid         (parser_metadata_valid && is_replication),
   
  .m_axis_tvalid             (axis_replication_to_deparser_tvalid),
  .m_axis_tdata              (axis_replication_to_deparser_tdata),
  .m_axis_tkeep              (axis_replication_to_deparser_tkeep),
  .m_axis_tlast              (axis_replication_to_deparser_tlast),
  .m_axis_tready             (axis_replication_to_deparser_tready),
  .metadata_out              (replication_metadata),
  .metadata_out_valid        (replication_metadata_valid),

  .s_axis_dm_tvalid          (axis_dm_read_tvalid),
  .s_axis_dm_tdata           (axis_dm_read_tdata),
  .s_axis_dm_tkeep           (axis_dm_read_tkeep),
  .s_axis_dm_tlast           (axis_dm_read_tlast),
  .s_axis_dm_tready          (axis_dm_read_tready),

  .m_axis_dm_tvalid          (axis_dm_write_tvalid),
  .m_axis_dm_tdata           (axis_dm_write_tdata),
  .m_axis_dm_tkeep           (axis_dm_write_tkeep),
  .m_axis_dm_tlast           (axis_dm_write_tlast),
  .m_axis_dm_tready          (axis_dm_write_tready),

  .m_axis_dm_mm2s_cmd_tvalid (axis_dm_read_cmd_tvalid),
  .m_axis_dm_mm2s_cmd_tdata  (axis_dm_read_cmd_tdata),
  .m_axis_dm_mm2s_cmd_tready (axis_dm_read_cmd_tready),

  .m_axis_dm_s2mm_cmd_tvalid (axis_dm_write_cmd_tvalid),
  .m_axis_dm_s2mm_cmd_tdata  (axis_dm_write_cmd_tdata),
  .m_axis_dm_s2mm_cmd_tready (axis_dm_write_cmd_tready),

  .m_axi_araddr              (axi_araddr),
  .m_axi_arburst             (axi_arburst),
  .m_axi_arid                (axi_arid),
  .m_axi_arlen               (axi_arlen),
  .m_axi_arready             (axi_arready),
  .m_axi_arsize              (axi_arsize),
  .m_axi_arvalid             (axi_arvalid),
  .m_axi_awaddr              (axi_awaddr),
  .m_axi_awburst             (axi_awburst),
  .m_axi_awid                (axi_awid),
  .m_axi_awlen               (axi_awlen),
  .m_axi_awready             (axi_awready),
  .m_axi_awsize              (axi_awsize),
  .m_axi_awvalid             (axi_awvalid),
  .m_axi_bid                 (axi_bid),
  .m_axi_bready              (axi_bready),
  .m_axi_bresp               (axi_bresp),
  .m_axi_bvalid              (axi_bvalid),
  .m_axi_rdata               (axi_rdata),
  .m_axi_rid                 (axi_rid),
  .m_axi_rlast               (axi_rlast),
  .m_axi_rready              (axi_rready),
  .m_axi_rresp               (axi_rresp),
  .m_axi_rvalid              (axi_rvalid),
  .m_axi_wdata               (axi_wdata),
  .m_axi_wlast               (axi_wlast),
  .m_axi_wready              (axi_wready),
  .m_axi_wstrb               (axi_wstrb),
  .m_axi_wvalid              (axi_wvalid)
);


packet_deparser packet_deparser_inst (
  .s_axis_tvalid           (axis_replication_to_deparser_tvalid), 
  .s_axis_tdata            (axis_replication_to_deparser_tdata), 
  .s_axis_tkeep            (axis_replication_to_deparser_tkeep), 
  .s_axis_tlast            (axis_replication_to_deparser_tlast), 
  .s_axis_tready           (axis_replication_to_deparser_tready), 
  .user_metadata_in        ({replication_metadata, NODE_IP, NODE_MAC}),
  .user_metadata_in_valid  (replication_metadata_valid),

  .m_axis_tvalid           (axis_deparser_to_arbiter_tvalid), 
  .m_axis_tdata            (axis_deparser_to_arbiter_tdata), 
  .m_axis_tkeep            (axis_deparser_to_arbiter_tkeep), 
  .m_axis_tlast            (axis_deparser_to_arbiter_tlast), 
  .m_axis_tready           (axis_deparser_to_arbiter_tready), 
  .user_metadata_out       (),
  .user_metadata_out_valid (),

  .s_axis_aclk             (axis_aclk),
  .s_axis_aresetn          (rstn)
);

packet_arbiter packet_arbiter_inst (
  .s_axis_tvalid           ({axis_deparser_to_arbiter_tvalid, reg_axis_qdma_h2c_tvalid}), 
  .s_axis_tdata            ({axis_deparser_to_arbiter_tdata,  reg_axis_qdma_h2c_tdata}),
  .s_axis_tkeep            ({axis_deparser_to_arbiter_tkeep,  reg_axis_qdma_h2c_tkeep}),
  .s_axis_tlast            ({axis_deparser_to_arbiter_tlast,  reg_axis_qdma_h2c_tlast}),
  .s_axis_tuser            ({{16'h0, 16'h0, 16'h0040}, {reg_axis_qdma_h2c_tuser_size, reg_axis_qdma_h2c_tuser_src, reg_axis_qdma_h2c_tuser_dst}}),
  .s_axis_tready           ({axis_deparser_to_arbiter_tready, reg_axis_qdma_h2c_tready}),

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

AXI_BUS #(
  .AXI_ADDR_WIDTH (cache_ss_pkg::AddrWidth),
  .AXI_DATA_WIDTH (cache_ss_pkg::DataWidth),
  .AXI_ID_WIDTH   (cache_ss_pkg::IdWidth),
  .AXI_USER_WIDTH (0)
) axi_mm_cache_to_hbm[3:0]();

AXI_BUS #(
  .AXI_ADDR_WIDTH (cache_ss_pkg::AddrWidth),
  .AXI_DATA_WIDTH (cache_ss_pkg::DataWidth),
  .AXI_ID_WIDTH   (cache_ss_pkg::IdWidth),
  .AXI_USER_WIDTH (0)
) axi_mm_pf_to_cache();


prefilter_bd_wrapper i_pf(
    .M00_AXI_0_araddr		(axi_mm_pf_to_cache.ar_addr),
    .M00_AXI_0_arburst	(axi_mm_pf_to_cache.ar_burst),	
    .M00_AXI_0_arcache	(axi_mm_pf_to_cache.ar_cache),	
    .M00_AXI_0_arlen 		(axi_mm_pf_to_cache.ar_len),
    .M00_AXI_0_arlock		(axi_mm_pf_to_cache.ar_lock),
    .M00_AXI_0_arprot		(axi_mm_pf_to_cache.ar_prot),
    .M00_AXI_0_arqos 		(axi_mm_pf_to_cache.ar_qos),
    .M00_AXI_0_arready	(axi_mm_pf_to_cache.ar_ready),	
    .M00_AXI_0_arsize		(axi_mm_pf_to_cache.ar_size),
    .M00_AXI_0_aruser		(axi_mm_pf_to_cache.ar_user),
    .M00_AXI_0_arvalid	(axi_mm_pf_to_cache.ar_valid),	
    .M00_AXI_0_awaddr		(axi_mm_pf_to_cache.aw_addr),
    .M00_AXI_0_awburst	(axi_mm_pf_to_cache.aw_burst),	
    .M00_AXI_0_awcache	(axi_mm_pf_to_cache.aw_cache),	
    .M00_AXI_0_awlen 		(axi_mm_pf_to_cache.aw_len),
    .M00_AXI_0_awlock		(axi_mm_pf_to_cache.aw_lock),
    .M00_AXI_0_awprot		(axi_mm_pf_to_cache.aw_prot),
    .M00_AXI_0_awqos 		(axi_mm_pf_to_cache.aw_qos),
    .M00_AXI_0_awready	(axi_mm_pf_to_cache.aw_ready),	
    .M00_AXI_0_awsize		(axi_mm_pf_to_cache.aw_size),
    .M00_AXI_0_awuser		(axi_mm_pf_to_cache.aw_user),
    .M00_AXI_0_awvalid	(axi_mm_pf_to_cache.aw_valid),	
    .M00_AXI_0_bready		(axi_mm_pf_to_cache.b_ready),
    .M00_AXI_0_bresp 		(axi_mm_pf_to_cache.b_resp),
    .M00_AXI_0_bvalid		(axi_mm_pf_to_cache.b_valid),
    .M00_AXI_0_rdata 		(axi_mm_pf_to_cache.r_data),
    .M00_AXI_0_rlast 		(axi_mm_pf_to_cache.r_last),
    .M00_AXI_0_rready		(axi_mm_pf_to_cache.r_ready),
    .M00_AXI_0_rresp 		(axi_mm_pf_to_cache.r_resp),
    .M00_AXI_0_rvalid		(axi_mm_pf_to_cache.r_valid),
    .M00_AXI_0_wdata 		(axi_mm_pf_to_cache.w_data),
    .M00_AXI_0_wlast 		(axi_mm_pf_to_cache.w_last),
    .M00_AXI_0_wready		(axi_mm_pf_to_cache.w_ready),
    .M00_AXI_0_wstrb 		(axi_mm_pf_to_cache.w_strb),
    .M00_AXI_0_wvalid		(axi_mm_pf_to_cache.w_valid),

    .axi_clk(axis_aclk),
    .axi_resetn (rstn),

    .s_axis_dm_s2mm_tvalid           (axis_dm_write_tvalid),
    .s_axis_dm_s2mm_tdata            (axis_dm_write_tdata),
    .s_axis_dm_s2mm_tkeep            (axis_dm_write_tkeep),
    .s_axis_dm_s2mm_tlast            (axis_dm_write_tlast),
    .s_axis_dm_s2mm_tready           (axis_dm_write_tready),

    .m_axis_dm_mm2s_tvalid           (axis_dm_read_tvalid),
    .m_axis_dm_mm2s_tdata            (axis_dm_read_tdata),
    .m_axis_dm_mm2s_tkeep            (axis_dm_read_tkeep),
    .m_axis_dm_mm2s_tlast            (axis_dm_read_tlast),
    .m_axis_dm_mm2s_tready           (axis_dm_read_tready),

    .s_axis_dm_s2mm_cmd_tvalid       (axis_dm_write_cmd_tvalid),
    .s_axis_dm_s2mm_cmd_tdata        (axis_dm_write_cmd_tdata),
    .s_axis_dm_s2mm_cmd_tready       (axis_dm_write_cmd_tready),
    
    .s_axis_dm_mm2s_cmd_tvalid       (axis_dm_read_cmd_tvalid),
    .s_axis_dm_mm2s_cmd_tdata        (axis_dm_read_cmd_tdata),
    .s_axis_dm_mm2s_cmd_tready       (axis_dm_read_cmd_tready),

    .m_axis_dm_s2mm_status_tdata     (axis_dm_write_sts_tdata),
    .m_axis_dm_s2mm_status_tkeep     (axis_dm_write_sts_tkeep),
    .m_axis_dm_s2mm_status_tlast     (axis_dm_write_sts_tlast),
    .m_axis_dm_s2mm_status_tvalid    (axis_dm_write_sts_tvalid),
    .m_axis_dm_s2mm_status_tready    (axis_dm_write_sts_tready),

    .m_axis_dm_mm2s_status_tdata     (axis_dm_read_sts_tdata),
    .m_axis_dm_mm2s_status_tkeep     (axis_dm_read_sts_tkeep),
    .m_axis_dm_mm2s_status_tlast     (axis_dm_read_sts_tlast),
    .m_axis_dm_mm2s_status_tvalid    (axis_dm_read_sts_tvalid),
    .m_axis_dm_mm2s_status_tready    (axis_dm_read_sts_tready),

    

  .s_axi_0_araddr                  (axi_araddr[0]),
  .s_axi_0_arburst                 (axi_arburst[0]),
  .s_axi_0_arid                    (axi_arid[0]),
  .s_axi_0_arlen                   (axi_arlen[0]),
  .s_axi_0_arready                 (axi_arready[0]),
  .s_axi_0_arsize                  (axi_arsize[0]),
  .s_axi_0_arvalid                 (axi_arvalid[0]),
  .s_axi_0_awaddr                  (axi_awaddr[0]),
  .s_axi_0_awburst                 (axi_awburst[0]),
  .s_axi_0_awid                    (axi_awid[0]),
  .s_axi_0_awlen                   (axi_awlen[0]),
  .s_axi_0_awready                 (axi_awready[0]),
  .s_axi_0_awsize                  (axi_awsize[0]),
  .s_axi_0_awvalid                 (axi_awvalid[0]),
  .s_axi_0_bid                     (axi_bid[0]),
  .s_axi_0_bready                  (axi_bready[0]),
  .s_axi_0_bresp                   (axi_bresp[0]),
  .s_axi_0_bvalid                  (axi_bvalid[0]),
  .s_axi_0_rdata                   (axi_rdata[0]),
  .s_axi_0_rid                     (axi_rid[0]),
  .s_axi_0_rlast                   (axi_rlast[0]),
  .s_axi_0_rready                  (axi_rready[0]),
  .s_axi_0_rresp                   (axi_rresp[0]),
  .s_axi_0_rvalid                  (axi_rvalid[0]),
  .s_axi_0_wdata                   (axi_wdata[0]),
  .s_axi_0_wlast                   (axi_wlast[0]),
  .s_axi_0_wready                  (axi_wready[0]),
  .s_axi_0_wstrb                   (axi_wstrb[0]),
  .s_axi_0_wvalid                  (axi_wvalid[0]),


  .s_axi_1_araddr                  (axi_araddr[1]),
  .s_axi_1_arburst                 (axi_arburst[1]),
  .s_axi_1_arid                    (axi_arid[1]),
  .s_axi_1_arlen                   (axi_arlen[1]),
  .s_axi_1_arready                 (axi_arready[1]),
  .s_axi_1_arsize                  (axi_arsize[1]),
  .s_axi_1_arvalid                 (axi_arvalid[1]),
  .s_axi_1_awaddr                  (axi_awaddr[1]),
  .s_axi_1_awburst                 (axi_awburst[1]),
  .s_axi_1_awid                    (axi_awid[1]),
  .s_axi_1_awlen                   (axi_awlen[1]),
  .s_axi_1_awready                 (axi_awready[1]),
  .s_axi_1_awsize                  (axi_awsize[1]),
  .s_axi_1_awvalid                 (axi_awvalid[1]),
  .s_axi_1_bid                     (axi_bid[1]),
  .s_axi_1_bready                  (axi_bready[1]),
  .s_axi_1_bresp                   (axi_bresp[1]),
  .s_axi_1_bvalid                  (axi_bvalid[1]),
  .s_axi_1_rdata                   (axi_rdata[1]),
  .s_axi_1_rid                     (axi_rid[1]),
  .s_axi_1_rlast                   (axi_rlast[1]),
  .s_axi_1_rready                  (axi_rready[1]),
  .s_axi_1_rresp                   (axi_rresp[1]),
  .s_axi_1_rvalid                  (axi_rvalid[1]),
  .s_axi_1_wdata                   (axi_wdata[1]),
  .s_axi_1_wlast                   (axi_wlast[1]),
  .s_axi_1_wready                  (axi_wready[1]),
  .s_axi_1_wstrb                   (axi_wstrb[1]),
  .s_axi_1_wvalid                  (axi_wvalid[1]),


  .s_axi_2_araddr                  (axi_araddr[2]),
  .s_axi_2_arburst                 (axi_arburst[2]),
  .s_axi_2_arid                    (axi_arid[2]),
  .s_axi_2_arlen                   (axi_arlen[2]),
  .s_axi_2_arready                 (axi_arready[2]),
  .s_axi_2_arsize                  (axi_arsize[2]),
  .s_axi_2_arvalid                 (axi_arvalid[2]),
  .s_axi_2_awaddr                  (axi_awaddr[2]),
  .s_axi_2_awburst                 (axi_awburst[2]),
  .s_axi_2_awid                    (axi_awid[2]),
  .s_axi_2_awlen                   (axi_awlen[2]),
  .s_axi_2_awready                 (axi_awready[2]),
  .s_axi_2_awsize                  (axi_awsize[2]),
  .s_axi_2_awvalid                 (axi_awvalid[2]),
  .s_axi_2_bid                     (axi_bid[2]),
  .s_axi_2_bready                  (axi_bready[2]),
  .s_axi_2_bresp                   (axi_bresp[2]),
  .s_axi_2_bvalid                  (axi_bvalid[2]),
  .s_axi_2_rdata                   (axi_rdata[2]),
  .s_axi_2_rid                     (axi_rid[2]),
  .s_axi_2_rlast                   (axi_rlast[2]),
  .s_axi_2_rready                  (axi_rready[2]),
  .s_axi_2_rresp                   (axi_rresp[2]),
  .s_axi_2_rvalid                  (axi_rvalid[2]),
  .s_axi_2_wdata                   (axi_wdata[2]),
  .s_axi_2_wlast                   (axi_wlast[2]),
  .s_axi_2_wready                  (axi_wready[2]),
  .s_axi_2_wstrb                   (axi_wstrb[2]),
  .s_axi_2_wvalid                  (axi_wvalid[2]),


  .s_axi_3_araddr                  (axi_araddr[3]),
  .s_axi_3_arburst                 (axi_arburst[3]),
  .s_axi_3_arid                    (axi_arid[3]),
  .s_axi_3_arlen                   (axi_arlen[3]),
  .s_axi_3_arready                 (axi_arready[3]),
  .s_axi_3_arsize                  (axi_arsize[3]),
  .s_axi_3_arvalid                 (axi_arvalid[3]),
  .s_axi_3_awaddr                  (axi_awaddr[3]),
  .s_axi_3_awburst                 (axi_awburst[3]),
  .s_axi_3_awid                    (axi_awid[3]),
  .s_axi_3_awlen                   (axi_awlen[3]),
  .s_axi_3_awready                 (axi_awready[3]),
  .s_axi_3_awsize                  (axi_awsize[3]),
  .s_axi_3_awvalid                 (axi_awvalid[3]),
  .s_axi_3_bid                     (axi_bid[3]),
  .s_axi_3_bready                  (axi_bready[3]),
  .s_axi_3_bresp                   (axi_bresp[3]),
  .s_axi_3_bvalid                  (axi_bvalid[3]),
  .s_axi_3_rdata                   (axi_rdata[3]),
  .s_axi_3_rid                     (axi_rid[3]),
  .s_axi_3_rlast                   (axi_rlast[3]),
  .s_axi_3_rready                  (axi_rready[3]),
  .s_axi_3_rresp                   (axi_rresp[3]),
  .s_axi_3_rvalid                  (axi_rvalid[3]),
  .s_axi_3_wdata                   (axi_wdata[3]),
  .s_axi_3_wlast                   (axi_wlast[3]),
  .s_axi_3_wready                  (axi_wready[3]),
  .s_axi_3_wstrb                   (axi_wstrb[3]),
  .s_axi_3_wvalid                  (axi_wvalid[3])
);

cache_subsystem #(
  .ADDR_WIDTH   (cache_ss_pkg::AddrWidth),
  .DATA_WIDTH   (cache_ss_pkg::DataWidth),
  .ID_WIDTH     (cache_ss_pkg::IdWidth),
  .OFFSET_BITS  (cache_ss_pkg::OFFSET_BITS),
  .INDEX_BITS   (11),
  .MAX_BURST_LEN(16),
  .PAGE_SIZE    (2*1024*1024)
) cache_subsystem_instance (
  .aclk(axis_aclk),
  .aresetn(rstn),

  .s_axi_arid       (axi_mm_pf_to_cache.ar_id),
  .s_axi_araddr     (axi_mm_pf_to_cache.ar_addr),
  .s_axi_arlen      (axi_mm_pf_to_cache.ar_len),
  .s_axi_arsize     (axi_mm_pf_to_cache.ar_size),
  .s_axi_arburst    (axi_mm_pf_to_cache.ar_burst),
  .s_axi_arvalid    (axi_mm_pf_to_cache.ar_valid),
  .s_axi_arready    (axi_mm_pf_to_cache.ar_ready),
  .s_axi_rid        (axi_mm_pf_to_cache.r_id),
  .s_axi_rdata      (axi_mm_pf_to_cache.r_data),
  .s_axi_rresp      (axi_mm_pf_to_cache.r_resp),
  .s_axi_rlast      (axi_mm_pf_to_cache.r_last),
  .s_axi_rvalid     (axi_mm_pf_to_cache.r_valid),
  .s_axi_rready     (axi_mm_pf_to_cache.r_ready),
  .s_axi_awid       (axi_mm_pf_to_cache.aw_id),
  .s_axi_awaddr     (axi_mm_pf_to_cache.aw_addr),
  .s_axi_awlen      (axi_mm_pf_to_cache.aw_len),
  .s_axi_awsize     (axi_mm_pf_to_cache.aw_size),
  .s_axi_awburst    (axi_mm_pf_to_cache.aw_burst),
  .s_axi_awvalid    (axi_mm_pf_to_cache.aw_valid),
  .s_axi_awready    (axi_mm_pf_to_cache.aw_ready),
  .s_axi_wdata      (axi_mm_pf_to_cache.w_data),
  .s_axi_wstrb      (axi_mm_pf_to_cache.w_strb),
  .s_axi_wlast      (axi_mm_pf_to_cache.w_last),
  .s_axi_wvalid     (axi_mm_pf_to_cache.w_valid),
  .s_axi_wready     (axi_mm_pf_to_cache.w_ready),
  .s_axi_bid        (axi_mm_pf_to_cache.b_id),
  .s_axi_bresp      (axi_mm_pf_to_cache.b_resp),
  .s_axi_bvalid     (axi_mm_pf_to_cache.b_valid),
  .s_axi_bready     (axi_mm_pf_to_cache.b_ready),

  .m_axi_cache_arid       (axi_mm_cache_to_hbm[0].ar_id),
  .m_axi_cache_araddr     (axi_mm_cache_to_hbm[0].ar_addr),
  .m_axi_cache_arlen      (axi_mm_cache_to_hbm[0].ar_len),
  .m_axi_cache_arsize     (axi_mm_cache_to_hbm[0].ar_size),
  .m_axi_cache_arburst    (axi_mm_cache_to_hbm[0].ar_burst),
  .m_axi_cache_arvalid    (axi_mm_cache_to_hbm[0].ar_valid),
  .m_axi_cache_arready    (axi_mm_cache_to_hbm[0].ar_ready),
  .m_axi_cache_rid        (axi_mm_cache_to_hbm[0].r_id),
  .m_axi_cache_rdata      (axi_mm_cache_to_hbm[0].r_data),
  .m_axi_cache_rresp      (axi_mm_cache_to_hbm[0].r_resp),
  .m_axi_cache_rvalid     (axi_mm_cache_to_hbm[0].r_valid),
  .m_axi_cache_rready     (axi_mm_cache_to_hbm[0].r_ready),
  .m_axi_cache_rlast      (axi_mm_cache_to_hbm[0].r_last),
  .m_axi_cache_awid       (axi_mm_cache_to_hbm[0].aw_id),
  .m_axi_cache_awaddr     (axi_mm_cache_to_hbm[0].aw_addr),
  .m_axi_cache_awlen      (axi_mm_cache_to_hbm[0].aw_len),
  .m_axi_cache_awsize     (axi_mm_cache_to_hbm[0].aw_size),
  .m_axi_cache_awburst    (axi_mm_cache_to_hbm[0].aw_burst),
  .m_axi_cache_awvalid    (axi_mm_cache_to_hbm[0].aw_valid),
  .m_axi_cache_awready    (axi_mm_cache_to_hbm[0].aw_ready),
  .m_axi_cache_wdata      (axi_mm_cache_to_hbm[0].w_data),
  .m_axi_cache_wstrb      (axi_mm_cache_to_hbm[0].w_strb),
  .m_axi_cache_wlast      (axi_mm_cache_to_hbm[0].w_last),
  .m_axi_cache_wvalid     (axi_mm_cache_to_hbm[0].w_valid),
  .m_axi_cache_wready     (axi_mm_cache_to_hbm[0].w_ready),
  .m_axi_cache_bid        (axi_mm_cache_to_hbm[0].b_id),
  .m_axi_cache_bresp      (axi_mm_cache_to_hbm[0].b_resp),
  .m_axi_cache_bvalid     (axi_mm_cache_to_hbm[0].b_valid),
  .m_axi_cache_bready     (axi_mm_cache_to_hbm[0].b_ready),

  .m_axi_pm_to_cache_arid       (axi_mm_cache_to_hbm[1].ar_id),
  .m_axi_pm_to_cache_araddr     (axi_mm_cache_to_hbm[1].ar_addr),
  .m_axi_pm_to_cache_arlen      (axi_mm_cache_to_hbm[1].ar_len),
  .m_axi_pm_to_cache_arsize     (axi_mm_cache_to_hbm[1].ar_size),
  .m_axi_pm_to_cache_arburst    (axi_mm_cache_to_hbm[1].ar_burst),
  .m_axi_pm_to_cache_arvalid    (axi_mm_cache_to_hbm[1].ar_valid),
  .m_axi_pm_to_cache_arready    (axi_mm_cache_to_hbm[1].ar_ready),
  .m_axi_pm_to_cache_rid        (axi_mm_cache_to_hbm[1].r_id),
  .m_axi_pm_to_cache_rdata      (axi_mm_cache_to_hbm[1].r_data),
  .m_axi_pm_to_cache_rresp      (axi_mm_cache_to_hbm[1].r_resp),
  .m_axi_pm_to_cache_rvalid     (axi_mm_cache_to_hbm[1].r_valid),
  .m_axi_pm_to_cache_rready     (axi_mm_cache_to_hbm[1].r_ready),
  .m_axi_pm_to_cache_rlast      (axi_mm_cache_to_hbm[1].r_last),
  .m_axi_pm_to_cache_awid       (axi_mm_cache_to_hbm[1].aw_id),
  .m_axi_pm_to_cache_awaddr     (axi_mm_cache_to_hbm[1].aw_addr),
  .m_axi_pm_to_cache_awlen      (axi_mm_cache_to_hbm[1].aw_len),
  .m_axi_pm_to_cache_awsize     (axi_mm_cache_to_hbm[1].aw_size),
  .m_axi_pm_to_cache_awburst    (axi_mm_cache_to_hbm[1].aw_burst),
  .m_axi_pm_to_cache_awvalid    (axi_mm_cache_to_hbm[1].aw_valid),
  .m_axi_pm_to_cache_awready    (axi_mm_cache_to_hbm[1].aw_ready),
  .m_axi_pm_to_cache_wdata      (axi_mm_cache_to_hbm[1].w_data),
  .m_axi_pm_to_cache_wstrb      (axi_mm_cache_to_hbm[1].w_strb),
  .m_axi_pm_to_cache_wlast      (axi_mm_cache_to_hbm[1].w_last),
  .m_axi_pm_to_cache_wvalid     (axi_mm_cache_to_hbm[1].w_valid),
  .m_axi_pm_to_cache_wready     (axi_mm_cache_to_hbm[1].w_ready),
  .m_axi_pm_to_cache_bid        (axi_mm_cache_to_hbm[1].b_id),
  .m_axi_pm_to_cache_bresp      (axi_mm_cache_to_hbm[1].b_resp),
  .m_axi_pm_to_cache_bvalid     (axi_mm_cache_to_hbm[1].b_valid),
  .m_axi_pm_to_cache_bready     (axi_mm_cache_to_hbm[1].b_ready),

  .m_axi_mem_arid         (),
  .m_axi_mem_araddr       (m_axi_sys_mem_araddr_internal),
  .m_axi_mem_arlen        (m_axi_sys_mem_arlen),
  .m_axi_mem_arsize       (m_axi_sys_mem_arsize),
  .m_axi_mem_arburst      (m_axi_sys_mem_arburst),
  .m_axi_mem_arvalid      (m_axi_sys_mem_arvalid),
  .m_axi_mem_arready      (m_axi_sys_mem_arready),
  .m_axi_mem_rid          (m_axi_sys_mem_rid),
  .m_axi_mem_rdata        (m_axi_sys_mem_rdata),
  .m_axi_mem_rresp        (m_axi_sys_mem_rresp),
  .m_axi_mem_rvalid       (m_axi_sys_mem_rvalid),
  .m_axi_mem_rready       (m_axi_sys_mem_rready),
  .m_axi_mem_rlast        (m_axi_sys_mem_rlast),
  .m_axi_mem_awid         (),
  .m_axi_mem_awaddr       (m_axi_sys_mem_awaddr_internal),
  .m_axi_mem_awlen        (m_axi_sys_mem_awlen),
  .m_axi_mem_awsize       (m_axi_sys_mem_awsize),
  .m_axi_mem_awburst      (m_axi_sys_mem_awburst),
  .m_axi_mem_awvalid      (m_axi_sys_mem_awvalid),
  .m_axi_mem_awready      (m_axi_sys_mem_awready),
  .m_axi_mem_wdata        (m_axi_sys_mem_wdata),
  .m_axi_mem_wstrb        (m_axi_sys_mem_wstrb),
  .m_axi_mem_wlast        (m_axi_sys_mem_wlast),
  .m_axi_mem_wvalid       (m_axi_sys_mem_wvalid),
  .m_axi_mem_wready       (m_axi_sys_mem_wready),
  .m_axi_mem_bid          (m_axi_sys_mem_bid),
  .m_axi_mem_bresp        (m_axi_sys_mem_bresp),
  .m_axi_mem_bvalid       (m_axi_sys_mem_bvalid),
  .m_axi_mem_bready       (m_axi_sys_mem_bready)
);

hbm_interface_wrapper i_hbm(
    
    .QDMA_AXI_araddr  (s_axi_araddr),
    .QDMA_AXI_arburst (s_axi_arburst),
    .QDMA_AXI_arcache (s_axi_arcache),
    .QDMA_AXI_arid    (s_axi_arid),
    .QDMA_AXI_arlen   (s_axi_arlen),
    .QDMA_AXI_arlock  (s_axi_arlock),
    .QDMA_AXI_arprot  (s_axi_arprot),
    .QDMA_AXI_arqos   (s_axi_arqos),
    .QDMA_AXI_arready (s_axi_arready),
    .QDMA_AXI_arsize  (s_axi_arsize),
    .QDMA_AXI_aruser  (s_axi_aruser),
    .QDMA_AXI_arvalid (s_axi_arvalid),
    .QDMA_AXI_awaddr  (s_axi_awaddr),
    .QDMA_AXI_awburst (s_axi_awburst),
    .QDMA_AXI_awcache (s_axi_awcache),
    .QDMA_AXI_awid    (s_axi_awid),
    .QDMA_AXI_awlen   (s_axi_awlen),
    .QDMA_AXI_awlock  (s_axi_awlock),
    .QDMA_AXI_awprot  (s_axi_awprot),
    .QDMA_AXI_awqos   (s_axi_awqos),
    .QDMA_AXI_awready (s_axi_awready),
    .QDMA_AXI_awsize  (s_axi_awsize),
    .QDMA_AXI_awuser  (s_axi_awuser),
    .QDMA_AXI_awvalid (s_axi_awvalid),
    .QDMA_AXI_bid     (s_axi_bid),
    .QDMA_AXI_bready  (s_axi_bready),
    .QDMA_AXI_bresp   (s_axi_bresp),
    .QDMA_AXI_bvalid  (s_axi_bvalid),
    .QDMA_AXI_rdata   (s_axi_rdata),
    .QDMA_AXI_rid     (s_axi_rid),
    .QDMA_AXI_rlast   (s_axi_rlast),
    .QDMA_AXI_rready  (s_axi_rready),
    .QDMA_AXI_rresp   (s_axi_rresp),
    .QDMA_AXI_rvalid  (s_axi_rvalid),
    .QDMA_AXI_wdata   (s_axi_wdata),
    .QDMA_AXI_wlast   (s_axi_wlast),
    .QDMA_AXI_wready  (s_axi_wready),
    .QDMA_AXI_wstrb   (s_axi_wstrb),
    .QDMA_AXI_wuser   (s_axi_wuser),
    .QDMA_AXI_wvalid  (s_axi_wvalid),

    `AXI_ASSIGN_MASTER_BUS_TO_HBM(S00,axi_mm_cache_to_hbm[0])
    `AXI_ASSIGN_MASTER_BUS_TO_HBM(S01,axi_mm_cache_to_hbm[1])
    `AXI_ASSIGN_MASTER_BUS_TO_HBM(S02,axi_mm_cache_to_hbm[2])
    `AXI_ASSIGN_MASTER_BUS_TO_HBM(S03,axi_mm_cache_to_hbm[3])

    .apb_complete_0_0  (apb_complete_0),
    .apb_complete_1_0  (),

    .aresetn_0 (axi_rstn),
    .axi_clk   (axis_aclk),

    .HBM_REF_CLK_0_0 (hbm_ref_clk)
);

`ifdef __simulation__
  // --------------------------------------------------------------------------------
  // Debug Monitors
  // --------------------------------------------------------------------------------

  // 1. QDMA H2C Interface (from Host to Card)
  always @(posedge axis_aclk) begin
    if (s_axis_qdma_h2c_tvalid && s_axis_qdma_h2c_tready) begin
      $strobe("[%t] KVS_SUBSYS QDMA_H2C (IN): data=0x%h, keep=0x%h, last=%b, size=%d, src=%d, dst=%d", 
              $time, s_axis_qdma_h2c_tdata, s_axis_qdma_h2c_tkeep, s_axis_qdma_h2c_tlast, 
              s_axis_qdma_h2c_tuser_size, s_axis_qdma_h2c_tuser_src, s_axis_qdma_h2c_tuser_dst);
    end
  end

  // 2. QDMA C2H Interface (from Card to Host)
  always @(posedge axis_aclk) begin
    if (m_axis_qdma_c2h_tvalid && m_axis_qdma_c2h_tready) begin
      $strobe("[%t] KVS_SUBSYS QDMA_C2H (OUT): data=0x%h, keep=0x%h, last=%b, size=%d, src=%d, dst=%d", 
              $time, m_axis_qdma_c2h_tdata, m_axis_qdma_c2h_tkeep, m_axis_qdma_c2h_tlast,
              m_axis_qdma_c2h_tuser_size, m_axis_qdma_c2h_tuser_src, m_axis_qdma_c2h_tuser_dst);
    end
  end

  // 3. CMAC H2C Interface (from Network to Card - filtered output to shell if any)
  always @(posedge axis_aclk) begin
    if (m_axis_cmac_h2c_tvalid && m_axis_cmac_h2c_tready) begin
      $strobe("[%t] KVS_SUBSYS CMAC_H2C (OUT): data=0x%h, keep=0x%h, last=%b, size=%d, src=%d, dst=%d", 
              $time, m_axis_cmac_h2c_tdata, m_axis_cmac_h2c_tkeep, m_axis_cmac_h2c_tlast,
              m_axis_cmac_h2c_tuser_size, m_axis_cmac_h2c_tuser_src, m_axis_cmac_h2c_tuser_dst);
    end
  end

  // 4. CMAC C2H Interface (from Card to Network - incoming packets)
  always @(posedge axis_aclk) begin
    if (s_axis_cmac_c2h_tvalid && s_axis_cmac_c2h_tready) begin
      $strobe("[%t] KVS_SUBSYS CMAC_C2H (IN): data=0x%h, keep=0x%h, last=%b, size=%d, src=%d, dst=%d", 
              $time, s_axis_cmac_c2h_tdata, s_axis_cmac_c2h_tkeep, s_axis_cmac_c2h_tlast,
              s_axis_cmac_c2h_tuser_size, s_axis_cmac_c2h_tuser_src, s_axis_cmac_c2h_tuser_dst);
    end
  end

  // 4. CMAC C2H REG Interface (from Card to Network - incoming packets)
  always @(posedge axis_aclk) begin
    if (reg_axis_cmac_c2h_tvalid && reg_axis_cmac_c2h_tready) begin
      $strobe("[%t] KVS_SUBSYS REG_C2H (IN): data=0x%h, keep=0x%h, last=%b, size=%d, src=%d, dst=%d", 
              $time, reg_axis_cmac_c2h_tdata, reg_axis_cmac_c2h_tkeep, reg_axis_cmac_c2h_tlast,
              reg_axis_cmac_c2h_tuser_size, reg_axis_cmac_c2h_tuser_src, reg_axis_cmac_c2h_tuser_dst);
    end
  end

  // 5. DataMover Read Interface (from HBM via datamover)
  always @(posedge axis_aclk) begin
    if (axis_dm_read_tvalid && axis_dm_read_tready) begin
      $strobe("[%t] KVS_SUBSYS DM_READ (MM2S): data=0x%h, keep=0x%h, last=%b", 
              $time, axis_dm_read_tdata, axis_dm_read_tkeep, axis_dm_read_tlast);
    end
  end

  // 6. DataMover Write Interface (to HBM via datamover)
  always @(posedge axis_aclk) begin
    if (axis_dm_write_tvalid && axis_dm_write_tready) begin
      $strobe("[%t] KVS_SUBSYS DM_WRITE (S2MM): data=0x%h, keep=0x%h, last=%b", 
              $time, axis_dm_write_tdata, axis_dm_write_tkeep, axis_dm_write_tlast);
    end
  end

  // 7. Internal: Parser to Filter
  always @(posedge axis_aclk) begin
    if (axis_parser_to_filter_tvalid && axis_parser_to_filter_tready) begin
      $strobe("[%t] KVS_SUBSYS PARSER->FILTER: data=0x%h, keep=0x%h, last=%b, user=0x%h", 
              $time, axis_parser_to_filter_tdata, axis_parser_to_filter_tkeep, axis_parser_to_filter_tlast, axis_parser_to_filter_tuser);
    end
  end

  // 8. Internal: Filter to Replication
  always @(posedge axis_aclk) begin
    if (axis_filter_to_replication_tvalid && axis_filter_to_replication_tready) begin
      $strobe("[%t] KVS_SUBSYS FILTER->REPL: data=0x%h, keep=0x%h, last=%b, user=0x%h", 
              $time, axis_filter_to_replication_tdata, axis_filter_to_replication_tkeep, axis_filter_to_replication_tlast, axis_filter_to_replication_tuser);
    end
  end

  // 9. Internal: Replication to Deparser
  always @(posedge axis_aclk) begin
    if (axis_replication_to_deparser_tvalid && axis_replication_to_deparser_tready) begin
      $strobe("[%t] KVS_SUBSYS REPL->DEPARSER: data=0x%h, keep=0x%h, last=%b", 
              $time, axis_replication_to_deparser_tdata, axis_replication_to_deparser_tkeep, axis_replication_to_deparser_tlast);
    end
  end

  // 10. Internal: Deparser to Arbiter
  always @(posedge axis_aclk) begin
    if (axis_deparser_to_arbiter_tvalid && axis_deparser_to_arbiter_tready) begin
      $strobe("[%t] KVS_SUBSYS DEPARSER->ARBITER: data=0x%h, keep=0x%h, last=%b", 
              $time, axis_deparser_to_arbiter_tdata, axis_deparser_to_arbiter_tkeep, axis_deparser_to_arbiter_tlast);
    end
  end

  // Metadata Monitors
  always @(posedge axis_aclk) begin
    if (parser_metadata_valid) begin
      $strobe("[%t] KVS_SUBSYS PARSER_META: ip=0x%h, mac=0x%h, opcode=%d, index=%d, key=0x%h, is_repl=%b", 
              $time, 
              parser_metadata.ip, 
              parser_metadata.mac, 
              parser_metadata.opcode, 
              parser_metadata.index,
              parser_metadata.key,
              is_replication);
    end
  end

  always @(posedge axis_aclk) begin
    if (replication_metadata_valid) begin
      $strobe("[%t] KVS_SUBSYS REPL_META: ip=0x%h, mac=0x%h, opcode=%d, index=%d, key=0x%h", 
              $time, 
              replication_metadata.ip, 
              replication_metadata.mac, 
              replication_metadata.opcode, 
              replication_metadata.index,
              replication_metadata.key);
    end
  end

`endif

endmodule;