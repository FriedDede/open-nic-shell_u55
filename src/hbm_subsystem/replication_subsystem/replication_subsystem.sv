`timescale 1ns/1ps

import metadata_pkg::*;

module replication_subsystem #(
  parameter int                     DATA_WIDTH     = 512,
  parameter int                     KEEP_WIDTH     = DATA_WIDTH / 8,
  parameter int                     FIFO_DEPTH     = 16,
  parameter logic            [31:0] NODE_IP        = 0,
  parameter logic            [47:0] NODE_MAC       = 0,
  parameter int                     MAX_NODES      = 32,
  parameter int                     BUCKET_SIZE    = 1024,
  parameter int                     NUM_HASHES     = 4,
  parameter int                     HASH_WIDTH     = 24,
  parameter int                     TIMER_WIDTH    = 30,  // ~4.2 s
  parameter int                     SEED           = 32'hdeadbeef,
  parameter int                     USE_CONTROLLER = 1,
  parameter logic [TIMER_WIDTH-1:0] TAP_MASK       = 30'h60000000,
  parameter logic  [HASH_WIDTH-1:0] HASH_MATRIX [NUM_HASHES][KEY_WIDTH-1:0] = '{default: '0}
) (
  input  logic                  axis_aclk,
  input  logic                  axil_aclk,
  input  logic                  axi_rstn,

  input  logic                  s_axis_tvalid,
  input  logic [DATA_WIDTH-1:0] s_axis_tdata,
  input  logic [KEEP_WIDTH-1:0] s_axis_tkeep,
  input  logic                  s_axis_tlast,
  output logic                  s_axis_tready,

  input  st_metadata            parser2rep_meta,
  input  logic                  parser2rep_meta_valid,

  output logic                  m_axis_tvalid,
  output logic [DATA_WIDTH-1:0] m_axis_tdata,
  output logic [KEEP_WIDTH-1:0] m_axis_tkeep,
  output logic                  m_axis_tlast,
  input  logic                  m_axis_tready,

  output st_metadata            metadata_out,
  output logic                  metadata_out_valid,

  input  logic                  s_axis_dm_tvalid,
  input  logic [DATA_WIDTH-1:0] s_axis_dm_tdata,
  input  logic [KEEP_WIDTH-1:0] s_axis_dm_tkeep,
  input  logic                  s_axis_dm_tlast,
  output logic                  s_axis_dm_tready,

  output logic                  m_axis_dm_tvalid,
  output logic [DATA_WIDTH-1:0] m_axis_dm_tdata,
  output logic [KEEP_WIDTH-1:0] m_axis_dm_tkeep,
  output logic                  m_axis_dm_tlast,
  input  logic                  m_axis_dm_tready,

  output logic                  m_axis_dm_mm2s_cmd_tvalid,
  output logic           [79:0] m_axis_dm_mm2s_cmd_tdata,
  input  logic                  m_axis_dm_mm2s_cmd_tready,

  output logic                  m_axis_dm_s2mm_cmd_tvalid,
  output logic           [79:0] m_axis_dm_s2mm_cmd_tdata,
  input  logic                  m_axis_dm_s2mm_cmd_tready,

  output logic           [33:0] m_axi_araddr   [NUM_HASHES],
  output logic            [1:0] m_axi_arburst  [NUM_HASHES],
  output logic            [3:0] m_axi_arcache  [NUM_HASHES],
  output logic            [3:0] m_axi_arid     [NUM_HASHES],
  output logic            [3:0] m_axi_arlen    [NUM_HASHES],
  output logic            [1:0] m_axi_arlock   [NUM_HASHES],
  output logic            [2:0] m_axi_arprot   [NUM_HASHES],
  input  logic                  m_axi_arready  [NUM_HASHES],
  output logic            [2:0] m_axi_arsize   [NUM_HASHES],
  output logic                  m_axi_arvalid  [NUM_HASHES],
  output logic           [33:0] m_axi_awaddr   [NUM_HASHES],
  output logic            [1:0] m_axi_awburst  [NUM_HASHES],
  output logic            [3:0] m_axi_awcache  [NUM_HASHES],
  output logic            [3:0] m_axi_awid     [NUM_HASHES],
  output logic            [3:0] m_axi_awlen    [NUM_HASHES],
  output logic            [1:0] m_axi_awlock   [NUM_HASHES],
  output logic            [2:0] m_axi_awprot   [NUM_HASHES],
  input  logic                  m_axi_awready  [NUM_HASHES],
  output logic            [2:0] m_axi_awsize   [NUM_HASHES],
  output logic                  m_axi_awvalid  [NUM_HASHES],
  input  logic            [3:0] m_axi_bid      [NUM_HASHES],
  output logic                  m_axi_bready   [NUM_HASHES],
  input  logic            [1:0] m_axi_bresp    [NUM_HASHES],
  input  logic                  m_axi_bvalid   [NUM_HASHES],
  input  logic          [127:0] m_axi_rdata    [NUM_HASHES],
  input  logic            [3:0] m_axi_rid      [NUM_HASHES],
  input  logic                  m_axi_rlast    [NUM_HASHES],
  output logic                  m_axi_rready   [NUM_HASHES],
  input  logic            [1:0] m_axi_rresp    [NUM_HASHES],
  input  logic                  m_axi_rvalid   [NUM_HASHES],
  output logic          [127:0] m_axi_wdata    [NUM_HASHES],
  output logic                  m_axi_wlast    [NUM_HASHES],
  input  logic                  m_axi_wready   [NUM_HASHES],
  output logic           [31:0] m_axi_wstrb    [NUM_HASHES],
  output logic                  m_axi_wvalid   [NUM_HASHES],

  input  logic           [31:0] s_axil_awaddr,
  input  logic                  s_axil_awvalid,
  output logic                  s_axil_awready,
  input  logic           [31:0] s_axil_wdata,
  input  logic                  s_axil_wvalid,
  output logic                  s_axil_wready,
  output logic            [1:0] s_axil_bresp,
  output logic                  s_axil_bvalid,
  input  logic                  s_axil_bready,
  input  logic           [31:0] s_axil_araddr,
  input  logic                  s_axil_arvalid,
  output logic                  s_axil_arready,
  output logic           [31:0] s_axil_rdata,
  output logic            [1:0] s_axil_rresp,
  output logic                  s_axil_rvalid,
  input  logic                  s_axil_rready
);

logic         axis_engine_to_memory_tvalid;
logic [511:0] axis_engine_to_memory_tdata;
logic  [63:0] axis_engine_to_memory_tkeep;
logic         axis_engine_to_memory_tlast;
logic         axis_engine_to_memory_tready;

logic         axis_memory_to_engine_tvalid;
logic [511:0] axis_memory_to_engine_tdata;
logic  [63:0] axis_memory_to_engine_tkeep;
logic         axis_memory_to_engine_tlast;
logic         axis_memory_to_engine_tready;

logic         axis_engine_to_deparser_tvalid;
logic [511:0] axis_engine_to_deparser_tdata;
logic  [63:0] axis_engine_to_deparser_tkeep;
logic         axis_engine_to_deparser_tlast;
logic         axis_engine_to_deparser_tready;

st_metadata   replication_metadata_in;
logic         replication_metadata_in_valid;

st_metadata   rep2deparser_meta;
logic         rep2deparser_meta_valid;

st_metadata   election_metadata_in;
logic         election_metadata_in_valid;

st_metadata   election_metadata_out;
logic         election_metadata_out_valid;

st_metadata   rep2hash_meta;
logic         rep2hash_meta_valid;
logic         rep2hash_meta_ready;

st_metadata   hash2rep_meta;
logic         hash2rep_meta_valid;

logic is_leader;

// Arbiter between replication payload and frame padding
always_comb begin
  m_axis_tvalid = axis_engine_to_deparser_tvalid;
  m_axis_tdata  = axis_engine_to_deparser_tdata;
  m_axis_tkeep  = axis_engine_to_deparser_tkeep;
  m_axis_tlast  = axis_engine_to_deparser_tlast;
  axis_engine_to_deparser_tready = m_axis_tready; 
  if (metadata_out_valid) begin
    if (metadata_out.opcode != READ_RESULT && metadata_out.opcode != WRITE) begin
      m_axis_tvalid = 1'b1;
      m_axis_tdata  = '0;
      m_axis_tkeep  = 64'hfff;
      m_axis_tlast  = 1'b1;
    end
  end
end

// Buffer metadata arbiter inputs in FIFO
st_metadata election_metadata_out_reg;
logic       election_metadata_ready;
logic       election_metadata_empty;

/*
st_metadata replication_metadata_out_reg;
logic       replication_metadata_ready;
logic       replication_metadata_empty;
*/

// Arbiter between replication and leader election with priority to the former 
always_comb begin
  metadata_out_valid         = 1'b0;
  metadata_out               = '0;
  election_metadata_ready    = 1'b0;
  if (rep2deparser_meta_valid) begin
    metadata_out_valid         = 1'b1;
    metadata_out               = rep2deparser_meta;
  end
  else if (!election_metadata_empty && !axis_engine_to_deparser_tvalid) begin
    metadata_out_valid         = 1'b1;
    metadata_out               = election_metadata_out_reg;
    election_metadata_ready    = 1'b1;
  end
end

replication_engine #(
  .MAX_NODES                 (MAX_NODES),
  .DATA_WIDTH                (DATA_WIDTH),
  .FIFO_DEPTH                (FIFO_DEPTH)
) replication_engine_inst    (
  .axis_clk                  (axis_aclk),
  .axis_rstn                 (axi_rstn),

  .s_axis_tvalid             (s_axis_tvalid && s_axis_tkeep != 64'b0),
  .s_axis_tdata              (s_axis_tdata),
  .s_axis_tkeep              (s_axis_tkeep),
  .s_axis_tlast              (s_axis_tlast),
  .s_axis_tready             (s_axis_tready),

  .metadata_in               (parser2rep_meta),
  .metadata_in_valid         (parser2rep_meta_valid),

  .m_axis_tvalid             (axis_engine_to_deparser_tvalid),
  .m_axis_tdata              (axis_engine_to_deparser_tdata),
  .m_axis_tkeep              (axis_engine_to_deparser_tkeep),
  .m_axis_tlast              (axis_engine_to_deparser_tlast),
  .m_axis_tready             (axis_engine_to_deparser_tready),

  .metadata_out              (rep2deparser_meta),
  .metadata_out_valid        (rep2deparser_meta_valid),

  .s_axis_mem_tvalid         (axis_memory_to_engine_tvalid),
  .s_axis_mem_tdata          (axis_memory_to_engine_tdata),
  .s_axis_mem_tkeep          (axis_memory_to_engine_tkeep),
  .s_axis_mem_tlast          (axis_memory_to_engine_tlast),
  .s_axis_mem_tready         (axis_memory_to_engine_tready),

  .metadata_mem_in           (hash2rep_meta),
  .metadata_mem_in_valid     (hash2rep_meta_valid),

  .m_axis_mem_tvalid         (axis_engine_to_memory_tvalid),
  .m_axis_mem_tdata          (axis_engine_to_memory_tdata),
  .m_axis_mem_tkeep          (axis_engine_to_memory_tkeep),
  .m_axis_mem_tlast          (axis_engine_to_memory_tlast),
  .m_axis_mem_tready         (axis_engine_to_memory_tready),

  .metadata_mem_out          (rep2hash_meta),
  .metadata_mem_out_valid    (rep2hash_meta_valid),
  .metadata_mem_out_ready    (rep2hash_meta_ready),

  .is_leader                 (is_leader)
);

election_engine #(
  .MAX_NODES                 (MAX_NODES),
  .FIFO_DEPTH                (FIFO_DEPTH),
`ifdef __simulation__
  .TIMER_WIDTH               (10),
  .TAP_MASK                  (10'b1000000000),
`else
  .TIMER_WIDTH               (TIMER_WIDTH),
  .TAP_MASK                  (TAP_MASK),
`endif
  .SEED                      (SEED),
  .USE_CONTROLLER            (USE_CONTROLLER)
) election_engine_inst (
  .axis_aclk                 (axis_aclk),
  .axil_aclk                 (axil_aclk),
  .axi_rstn                  (axi_rstn),

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

  .metadata_in               (parser2rep_meta),
  .metadata_in_valid         (parser2rep_meta_valid),

  .metadata_out              (election_metadata_out),
  .metadata_out_valid        (election_metadata_out_valid),

  .is_leader                 (is_leader)
);

// cuckoo_hash #(
 hash_engine_pipe_simple #(
  .DATA_WIDTH                (512),
  .BUCKET_SIZE               (BUCKET_SIZE),
  .NUM_FUNCTIONS             (NUM_HASHES),
  .HASH_MATRIX               (HASH_MATRIX)
) cuckoo_hash_inst (
  .m_axi_araddr              (m_axi_araddr),
  .m_axi_arburst             (m_axi_arburst),
  .m_axi_arcache             (m_axi_arcache),
  .m_axi_arid                (m_axi_arid),
  .m_axi_arlen               (m_axi_arlen),
  .m_axi_arlock              (m_axi_arlock),
  .m_axi_arprot              (m_axi_arprot),
  .m_axi_arready             (m_axi_arready),
  .m_axi_arsize              (m_axi_arsize),
  .m_axi_arvalid             (m_axi_arvalid),
  .m_axi_awaddr              (m_axi_awaddr),
  .m_axi_awburst             (m_axi_awburst),
  .m_axi_awcache             (m_axi_awcache),
  .m_axi_awid                (m_axi_awid),
  .m_axi_awlen               (m_axi_awlen),
  .m_axi_awlock              (m_axi_awlock),
  .m_axi_awprot              (m_axi_awprot),
  .m_axi_awready             (m_axi_awready),
  .m_axi_awsize              (m_axi_awsize),
  .m_axi_awvalid             (m_axi_awvalid),
  .m_axi_bid                 (m_axi_bid),
  .m_axi_bready              (m_axi_bready),
  .m_axi_bresp               (m_axi_bresp),
  .m_axi_bvalid              (m_axi_bvalid),
  .m_axi_rdata               (m_axi_rdata),
  .m_axi_rid                 (m_axi_rid),
  .m_axi_rlast               (m_axi_rlast),
  .m_axi_rready              (m_axi_rready),
  .m_axi_rresp               (m_axi_rresp),
  .m_axi_rvalid              (m_axi_rvalid),
  .m_axi_wdata               (m_axi_wdata),
  .m_axi_wlast               (m_axi_wlast),
  .m_axi_wready              (m_axi_wready),
  .m_axi_wstrb               (m_axi_wstrb),
  .m_axi_wvalid              (m_axi_wvalid),

  .s_axis_tready             (axis_engine_to_memory_tready),
  .s_axis_tdata              (axis_engine_to_memory_tdata),
  .s_axis_tkeep              (axis_engine_to_memory_tkeep),
  .s_axis_tlast              (axis_engine_to_memory_tlast),
  .s_axis_tvalid             (axis_engine_to_memory_tvalid),

  .metadata_in               (rep2hash_meta),
  .metadata_in_valid         (rep2hash_meta_valid),
  .metadata_in_ready         (rep2hash_meta_ready),

  .m_axis_tready             (axis_memory_to_engine_tready),
  .m_axis_tdata              (axis_memory_to_engine_tdata),
  .m_axis_tkeep              (axis_memory_to_engine_tkeep),
  .m_axis_tlast              (axis_memory_to_engine_tlast),
  .m_axis_tvalid             (axis_memory_to_engine_tvalid),

  .metadata_out              (hash2rep_meta),
  .metadata_out_valid        (hash2rep_meta_valid),

  .s_axis_dm_tvalid          (s_axis_dm_tvalid),
  .s_axis_dm_tdata           (s_axis_dm_tdata),
  .s_axis_dm_tkeep           (s_axis_dm_tkeep),
  .s_axis_dm_tlast           (s_axis_dm_tlast),
  .s_axis_dm_tready          (s_axis_dm_tready),

  .m_axis_dm_tvalid          (m_axis_dm_tvalid),
  .m_axis_dm_tdata           (m_axis_dm_tdata),
  .m_axis_dm_tkeep           (m_axis_dm_tkeep),
  .m_axis_dm_tlast           (m_axis_dm_tlast),
  .m_axis_dm_tready          (m_axis_dm_tready),

  .m_axis_dm_mm2s_cmd_tvalid (m_axis_dm_mm2s_cmd_tvalid),
  .m_axis_dm_mm2s_cmd_tdata  (m_axis_dm_mm2s_cmd_tdata),
  .m_axis_dm_mm2s_cmd_tready (m_axis_dm_mm2s_cmd_tready),

  .m_axis_dm_s2mm_cmd_tvalid (m_axis_dm_s2mm_cmd_tvalid),
  .m_axis_dm_s2mm_cmd_tdata  (m_axis_dm_s2mm_cmd_tdata),
  .m_axis_dm_s2mm_cmd_tready (m_axis_dm_s2mm_cmd_tready),

  .clk                       (axis_aclk),
  .rstn                      (axi_rstn)
);

xpm_fifo_sync #(
  .DOUT_RESET_VALUE    ("0"),
  .ECC_MODE            ("no_ecc"),
  .FIFO_MEMORY_TYPE    ("auto"),
  .FIFO_READ_LATENCY   (1),
  .FIFO_WRITE_DEPTH    (FIFO_DEPTH),
  .PROG_FULL_THRESH    (FIFO_DEPTH-5),
  .READ_DATA_WIDTH     (METADATA_WIDTH),
  .READ_MODE           ("fwft"),
  .WRITE_DATA_WIDTH    (METADATA_WIDTH)
) election_metadata (
  .wr_en               (election_metadata_out_valid),
  .din                 (election_metadata_out),
  .wr_ack              (),
  .rd_en               (election_metadata_ready),
  .data_valid          (),
  .dout                (election_metadata_out_reg),
  .wr_data_count       (),
  .rd_data_count       (),
  .empty               (election_metadata_empty),
  .full                (),
  .almost_empty        (),
  .almost_full         (),
  .overflow            (),
  .underflow           (),
  .prog_empty          (),
  .prog_full           (),
  .sleep               (1'b0),
  .sbiterr             (),
  .dbiterr             (),
  .injectsbiterr       (1'b0),
  .injectdbiterr       (1'b0),
  .wr_clk              (axis_aclk),
  .rst                 (~axi_rstn),
  .rd_rst_busy         (),
  .wr_rst_busy         ()
);

// xpm_fifo_sync #(
//   .DOUT_RESET_VALUE    ("0"),
//   .ECC_MODE            ("no_ecc"),
//   .FIFO_MEMORY_TYPE    ("auto"),
//   .FIFO_READ_LATENCY   (1),
//   .FIFO_WRITE_DEPTH    (FIFO_DEPTH),
//   .PROG_FULL_THRESH    (FIFO_DEPTH-5),
//   .READ_DATA_WIDTH     (METADATA_WIDTH),
//   .READ_MODE           ("fwft"),
//   .WRITE_DATA_WIDTH    (METADATA_WIDTH)
// ) replication_metadata (
//   .wr_en               (replication_metadata_out_valid),
//   .din                 (replication_metadata_out),
//   .wr_ack              (),
//   .rd_en               (replication_metadata_ready),
//   .data_valid          (),
//   .dout                (replication_metadata_out_reg),
//   .wr_data_count       (),
//   .rd_data_count       (),
//   .empty               (replication_metadata_empty),
//   .full                (),
//   .almost_empty        (),
//   .almost_full         (),
//   .overflow            (),
//   .underflow           (),
//   .prog_empty          (),
//   .prog_full           (),
//   .sleep               (1'b0),
//   .sbiterr             (),
//   .dbiterr             (),
//   .injectsbiterr       (1'b0),
//   .injectdbiterr       (1'b0),
//   .wr_clk              (axis_aclk),
//   .rst                 (~axi_rstn),
//   .rd_rst_busy         (),
//   .wr_rst_busy         ()
// );

endmodule