`timescale 1ns/1ps

`include "axi_assign.svh"
`include "axi_typedef.svh"
`include "axi_.svh"
`include "hbm_axi.svh"

module kvs_subsystem_mt 
import metadata_pkg::*;
import axi_pkg::*;
#(
  parameter int                     DATA_WIDTH      = 512,
  parameter int                     MAX_NODES       = 32,
  parameter int                     BUCKET_SIZE     = 1024,
  parameter logic            [31:0] NODE_IP         = '0,
  parameter logic            [47:0] NODE_MAC        = '0,
  parameter int                     TIMER_WIDTH     = 30,  // ~4.2 s
  parameter int                     USE_CONTROLLER  = 1,
  parameter int                     SEED            = 32'hdeadbeef,
  // default mapping [mem 0x0000000400000000-0x00000007ffffffff]
  parameter logic [63:0]            BASE_HOST_MEM   = 64'h0000000400000000, // starts at 16GB by default
  parameter logic [63:0]            MASK_HOST_MEM   = 64'h00000003ffffffff, // 16GB by defaults
  parameter logic [TIMER_WIDTH-1:0] TAP_MASK        = 30'h60000000,
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

localparam NUM_HASHES    = 4;
localparam ADDRESS_WIDTH = 34;  // 16 GB
localparam HASH_WIDTH    = ADDRESS_WIDTH - $clog2(BUCKET_SIZE);

localparam logic [HASH_WIDTH-1:0] HASH_MATRIX [NUM_HASHES][KEY_WIDTH-1:0] = '{{
  24'hA3C5D1, 24'hD4F921, 24'h98B337, 24'h345678,
  24'hEAD00F, 24'hADC0DE, 24'h55AAAA, 24'hACE123,
  24'hF23456, 24'hBEEF12, 24'h0FFEE0, 24'hBADB07,
  24'hBCDEF0, 24'hBCDE12, 24'h4679BD, 24'h2468AC,
  24'hAAAAAA, 24'hBBBBBB, 24'hCCCCCC, 24'h234567,
  24'h654321, 24'hEDCBA9, 24'hACEACE, 24'hC001D0,
  24'hEADC0D, 24'hADD00D, 24'h0DEC0D, 24'hDCAFE,
  24'h3579BF, 24'h468ACE, 24'h579BDF, 24'h68ACED,
  24'h55AAAA, 24'h66BBBB, 24'h77CCCC, 24'h88DDDD,
  24'h99EEEE, 24'hAAFFFF, 24'hBBB111, 24'hCCC222,
  24'hDDD333, 24'hEEE444, 24'hFFF555, 24'h111222,
  24'h222333, 24'h333444, 24'h444555, 24'h555666,
  24'h666777, 24'h777888, 24'h888999, 24'h999AAA,
  24'hAAA111, 24'hBBB222, 24'hCCC333, 24'hDDD444,
  24'hEEE555, 24'hFFF666, 24'h2345AB, 24'hDC123,
  24'h4567CD, 24'h6789EF, 24'h89AB12, 24'hBCDEF3
}, {
  24'h123456, 24'h234567, 24'h345678, 24'h456789,
  24'h56789A, 24'h6789AB, 24'h789ABC, 24'h89ABCD,
  24'h9ABCDE, 24'hABCDE0, 24'hBCDEF1, 24'hCDEF12,
  24'hDEF123, 24'hEF1234, 24'hF12345, 24'h012345,
  24'h111111, 24'h222222, 24'h333333, 24'h444444,
  24'h555555, 24'h666666, 24'h777777, 24'h888888,
  24'h999999, 24'hAAAAAA, 24'hBBBBBB, 24'hCCCCCC,
  24'hDDDDDD, 24'hEEEEEE, 24'hFFFFFF, 24'h000000,
  24'h13579B, 24'h2468AC, 24'h3579BD, 24'h468ACE,
  24'h579BDF, 24'h68ACEF, 24'h79BDF0, 24'h8ACE01,
  24'h9BDF12, 24'hACEF23, 24'hBDF034, 24'hCEF145,
  24'hDF0256, 24'hEF1367, 24'hF02478, 24'h012589,
  24'h12369A, 24'h2347AB, 24'h3458BC, 24'h4569CD,
  24'h567ADE, 24'h678BEF, 24'h789C01, 24'h89AD12,
  24'h9ABE23, 24'hABCF34, 24'hBC0145, 24'hCD1256,
  24'hDE2367, 24'hEF3478, 24'hF04589, 24'h01269A
}, {
  24'hFACE01, 24'hDEAD02, 24'hBEEF03, 24'hCAFE04,
  24'hBABE05, 24'hFEED06, 24'hC0DE07, 24'hF00D08,
  24'h1CED09, 24'hBAD10A, 24'hC0010B, 24'hDAD10C,
  24'hACED0D, 24'hBA510E, 24'hD00D0F, 24'hFEED10,
  24'h111AAA, 24'h222BBB, 24'h333CCC, 24'h444DDD,
  24'h555EEE, 24'h666FFF, 24'h777000, 24'h888111,
  24'h999222, 24'hAAA333, 24'hBBB444, 24'hCCC555,
  24'hDDD666, 24'hEEE777, 24'hFFF888, 24'h000999,
  24'hAAAA01, 24'hBBBB02, 24'hCCCC03, 24'hDDDD04,
  24'hEEEE05, 24'hFFFF06, 24'h123407, 24'h234508,
  24'h345609, 24'h45670A, 24'h56780B, 24'h67890C,
  24'h789A0D, 24'h89AB0E, 24'h9ABC0F, 24'hABCD10,
  24'hBCDE11, 24'hCDEF12, 24'hDEF013, 24'hEF0114,
  24'hF01215, 24'h012316, 24'h123417, 24'h234518,
  24'h345619, 24'h45671A, 24'h56781B, 24'h67891C,
  24'h789A1D, 24'h89AB1E, 24'h9ABC1F, 24'hABCD20
}, {
  24'h102938, 24'h293847, 24'h384756, 24'h475665,
  24'h566574, 24'h665483, 24'h754392, 24'h843A01,
  24'h932B10, 24'hA21C20, 24'hB10D30, 24'hC00E40,
  24'hDF0F50, 24'hEE1060, 24'hFD1170, 24'h0C1280,
  24'h1B1390, 24'h2A14A0, 24'h3915B0, 24'h4816C0,
  24'h5717D0, 24'h6618E0, 24'h7519F0, 24'h842A00,
  24'h933B10, 24'hA24C20, 24'hB15D30, 24'hC06E40,
  24'hD17F50, 24'hE29060, 24'hF3A170, 24'h04B280,
  24'h15C390, 24'h26D4A0, 24'h37E5B0, 24'h48F6C0,
  24'h5907D0, 24'h6A18E0, 24'h7B29F0, 24'h8C3A00,
  24'h9D4B10, 24'hAE5C20, 24'hBF6D30, 24'hD07E40,
  24'hE18F50, 24'hF2A060, 24'h03B170, 24'h14C280,
  24'h25D390, 24'h36E4A0, 24'h47F5B0, 24'h5806C0,
  24'h6917D0, 24'h7A28E0, 24'h8B39F0, 24'h9C4A00,
  24'hAD5B10, 24'hBE6C20, 24'hCF7D30, 24'hD08E40,
  24'hE19F50, 24'hF2B060, 24'h03C170, 24'h14D280
}};



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

// The valid signal for the parser's incoming user metadata is raised only on the first beat
logic parser_metadata_in_valid;
logic parser_metadata_in_valid_toggle;

assign parser_metadata_in_valid = parser_metadata_in_valid_toggle && s_axis_cmac_c2h_tvalid && s_axis_cmac_c2h_tready;

always_ff @(posedge axis_aclk) begin
  if(~axi_rstn) begin
    parser_metadata_in_valid_toggle <= 1'b1;
  end
  else begin
    if (s_axis_cmac_c2h_tvalid && s_axis_cmac_c2h_tready && !s_axis_cmac_c2h_tlast) 
      parser_metadata_in_valid_toggle <= 1'b0;  
    if (s_axis_cmac_c2h_tvalid && s_axis_cmac_c2h_tready && s_axis_cmac_c2h_tlast)
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
assign m_axis_qdma_c2h_tuser_size = axis_qdma_c2h_tuser[47:32];
assign m_axis_qdma_c2h_tuser_src  = axis_qdma_c2h_tuser[32:16];
assign m_axis_qdma_c2h_tuser_dst  = axis_qdma_c2h_tuser[15:0];

packet_parser packet_parser_inst (
  .s_axis_tvalid           (s_axis_cmac_c2h_tvalid), 
  .s_axis_tdata            (s_axis_cmac_c2h_tdata), 
  .s_axis_tkeep            (s_axis_cmac_c2h_tkeep), 
  .s_axis_tlast            (s_axis_cmac_c2h_tlast),
  .s_axis_tuser            ({s_axis_cmac_c2h_tuser_size, s_axis_cmac_c2h_tuser_src, s_axis_cmac_c2h_tuser_dst}),
  .s_axis_tready           (s_axis_cmac_c2h_tready), 
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

  .m_axis_tvalid           ({axis_filter_to_replication_tvalid, m_axis_qdma_c2h_tvalid}),
  .m_axis_tdata            ({axis_filter_to_replication_tdata, m_axis_qdma_c2h_tdata}),
  .m_axis_tkeep            ({axis_filter_to_replication_tkeep, m_axis_qdma_c2h_tkeep}),
  .m_axis_tlast            ({axis_filter_to_replication_tlast, m_axis_qdma_c2h_tlast}),
  .m_axis_tuser            ({axis_filter_to_replication_tuser, axis_qdma_c2h_tuser}),
  .m_axis_tdest            (),
  .m_axis_tready           ({axis_filter_to_replication_tready, m_axis_qdma_c2h_tready}),

  .aclk                    (axis_aclk),
  .aresetn                 (rstn)
);

replication_subsystem_mt #(
    .DATA_WIDTH(DATA_WIDTH),
    .NODE_IP(NODE_IP),
    .NODE_MAC(NODE_MAC),
    .MAX_NODES(MAX_NODES),
    .BUCKET_SIZE(BUCKET_SIZE),
    .NUM_HASHES(NUM_HASHES),
    .HASH_WIDTH(HASH_WIDTH),
    .TIMER_WIDTH(TIMER_WIDTH),
    .SEED(SEED),
    .USE_CONTROLLER(USE_CONTROLLER),
    .TAP_MASK(TAP_MASK),
    .HASH_MATRIX(HASH_MATRIX),
    .N_THREADS(4)
) replication_subsystem_mt_instance (
  
  .axis_aclk          (axis_aclk),
  .axil_aclk          (axil_aclk),
  .axi_rstn           (axi_rstn),

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
  .s_axil_rready      (s_axil_rready),
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
  .s_axis_tvalid           ({axis_deparser_to_arbiter_tvalid[0], axis_deparser_to_arbiter_tvalid[1], axis_deparser_to_arbiter_tvalid[2], axis_deparser_to_arbiter_tvalid[3], s_axis_qdma_h2c_tvalid}), 
  .s_axis_tdata            ({axis_deparser_to_arbiter_tdata [0], axis_deparser_to_arbiter_tdata [1], axis_deparser_to_arbiter_tdata [2], axis_deparser_to_arbiter_tdata [3], s_axis_qdma_h2c_tdata}),
  .s_axis_tkeep            ({axis_deparser_to_arbiter_tkeep [0], axis_deparser_to_arbiter_tkeep [1], axis_deparser_to_arbiter_tkeep [2], axis_deparser_to_arbiter_tkeep [3], s_axis_qdma_h2c_tkeep}),
  .s_axis_tlast            ({axis_deparser_to_arbiter_tlast [0], axis_deparser_to_arbiter_tlast [1], axis_deparser_to_arbiter_tlast [2], axis_deparser_to_arbiter_tlast [3], s_axis_qdma_h2c_tlast}),
  .s_axis_tuser            ({{16'h0, 16'h0, 16'h0040}, {s_axis_qdma_h2c_tuser_size, s_axis_qdma_h2c_tuser_src, s_axis_qdma_h2c_tuser_dst}}),
  .s_axis_tready           ({axis_deparser_to_arbiter_tready[0], axis_deparser_to_arbiter_tready[1], axis_deparser_to_arbiter_tready[2], axis_deparser_to_arbiter_tready[3],s_axis_qdma_h2c_tready}),

  .m_axis_tvalid           (m_axis_cmac_h2c_tvalid),
  .m_axis_tdata            (m_axis_cmac_h2c_tdata),
  .m_axis_tkeep            (m_axis_cmac_h2c_tkeep),
  .m_axis_tlast            (m_axis_cmac_h2c_tlast),
  .m_axis_tuser            ({m_axis_cmac_h2c_tuser_size, m_axis_cmac_h2c_tuser_src, m_axis_cmac_h2c_tuser_dst}),
  .m_axis_tready           (m_axis_cmac_h2c_tready),

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
    .HBM_REF_CLK_0_0 (hbm_ref_clk),
    
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
    );

endmodule;