`timescale 1ns/1ps

import metadata_pkg::*;

module replication_subsystem_mt #(
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
  parameter logic  [HASH_WIDTH-1:0] HASH_MATRIX [NUM_HASHES][KEY_WIDTH-1:0] = '{default: '0},
  parameter int                     N_THREADS      = 4
) (
  input  logic                  axis_aclk,
  input  logic                  axil_aclk,
  input  logic                  axi_rstn,

  input  logic                  s_axis_tvalid ,
  input  logic [DATA_WIDTH-1:0] s_axis_tdata  ,
  input  logic [KEEP_WIDTH-1:0] s_axis_tkeep  ,
  input  logic                  s_axis_tlast  ,
  output logic                  s_axis_tready ,

  input  st_metadata            metadata_in,
  input  logic                  metadata_in_valid,

  output logic                  m_axis_tvalid [N_THREADS] ,
  output logic [DATA_WIDTH-1:0] m_axis_tdata  [N_THREADS] ,
  output logic [KEEP_WIDTH-1:0] m_axis_tkeep  [N_THREADS] ,
  output logic                  m_axis_tlast  [N_THREADS] ,
  input  logic                  m_axis_tready [N_THREADS] ,

  output st_metadata            metadata_out       [N_THREADS],
  output logic                  metadata_out_valid [N_THREADS],

  output logic           [33:0] m_axi_mem_araddr   [N_THREADS],
  output logic            [1:0] m_axi_mem_arburst  [N_THREADS],
  output logic            [3:0] m_axi_mem_arcache  [N_THREADS],
  output logic            [3:0] m_axi_mem_arid     [N_THREADS],
  output logic            [7:0] m_axi_mem_arlen    [N_THREADS],
  output logic            [1:0] m_axi_mem_arlock   [N_THREADS],
  output logic            [2:0] m_axi_mem_arprot   [N_THREADS],
  input  logic                  m_axi_mem_arready  [N_THREADS],
  output logic            [2:0] m_axi_mem_arsize   [N_THREADS],
  output logic                  m_axi_mem_arvalid  [N_THREADS],
  output logic           [33:0] m_axi_mem_awaddr   [N_THREADS],
  output logic            [1:0] m_axi_mem_awburst  [N_THREADS],
  output logic            [3:0] m_axi_mem_awcache  [N_THREADS],
  output logic            [3:0] m_axi_mem_awid     [N_THREADS],
  output logic            [7:0] m_axi_mem_awlen    [N_THREADS],
  output logic            [1:0] m_axi_mem_awlock   [N_THREADS],
  output logic            [2:0] m_axi_mem_awprot   [N_THREADS],
  input  logic                  m_axi_mem_awready  [N_THREADS],
  output logic            [2:0] m_axi_mem_awsize   [N_THREADS],
  output logic                  m_axi_mem_awvalid  [N_THREADS],
  input  logic            [3:0] m_axi_mem_bid      [N_THREADS],
  output logic                  m_axi_mem_bready   [N_THREADS],
  input  logic            [1:0] m_axi_mem_bresp    [N_THREADS],
  input  logic                  m_axi_mem_bvalid   [N_THREADS],
  input  logic[DATA_WIDTH -1:0] m_axi_mem_rdata    [N_THREADS],
  input  logic            [3:0] m_axi_mem_rid      [N_THREADS],
  input  logic                  m_axi_mem_rlast    [N_THREADS],
  output logic                  m_axi_mem_rready   [N_THREADS],
  input  logic            [1:0] m_axi_mem_rresp    [N_THREADS],
  input  logic                  m_axi_mem_rvalid   [N_THREADS],
  output logic[DATA_WIDTH -1:0] m_axi_mem_wdata    [N_THREADS],
  output logic                  m_axi_mem_wlast    [N_THREADS],
  input  logic                  m_axi_mem_wready   [N_THREADS],
  output logic[(DATA_WIDTH/8)-1:0] m_axi_mem_wstrb [N_THREADS],
  output logic                  m_axi_mem_wvalid   [N_THREADS],

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


// ----------------------------------------------------------------------------------------------------------
//              ELECTION ENGINE
// ----------------------------------------------------------------------------------------------------------

logic is_leader;
// Buffer metadata arbiter inputs in FIFO
st_metadata     election_metadata_out_reg;
logic           [N_THREADS-1 :0] election_metadata_ready;
logic           election_metadata_ready_any;
logic           election_metadata_empty;
st_metadata     election_metadata_out;
logic           election_metadata_out_valid;

assign election_metadata_ready_any = (election_metadata_ready == '0) ? 1'b0 : 1'b1;

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

    .metadata_in               (metadata_in),
    .metadata_in_valid         (metadata_in_valid),

    .metadata_out              (election_metadata_out),
    .metadata_out_valid        (election_metadata_out_valid),

    .is_leader                 (is_leader)
);

// Election Engine Metadata buffer
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
    .rd_en               (election_metadata_ready_any),
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

// ----------------------------------------------------------------------------------------------------------
//              KVS ENGINE DEMUX
// ----------------------------------------------------------------------------------------------------------

logic                  axis_rep_input_tvalid [N_THREADS -1 : 0];
logic [DATA_WIDTH-1:0] axis_rep_input_tdata  [N_THREADS -1 : 0];
logic [KEEP_WIDTH-1:0] axis_rep_input_tkeep  [N_THREADS -1 : 0];
logic                  axis_rep_input_tlast  [N_THREADS -1 : 0];
logic                  axis_rep_input_tready [N_THREADS -1 : 0];

st_metadata            metadata_in_mt        [N_THREADS -1 : 0];   
logic                  metadata_in_valid_mt  [N_THREADS -1 : 0];   

logic [1:0]            tdest;

always_ff @(posedge axis_aclk) begin
    if (!axi_rstn) tdest <= '0;
    else if (s_axis_tlast && s_axis_tvalid && s_axis_tready) begin
        if (tdest == 2'b11) tdest <= 2'b00;
        else tdest <= tdest + 1;
    end
end

// Round Robin AXIS Demux

axis_demux i_repl_demux (
  .s_axis_tvalid           (s_axis_tvalid), 
  .s_axis_tdata            (s_axis_tdata),
  .s_axis_tkeep            (s_axis_tkeep),
  .s_axis_tlast            (s_axis_tlast),
  .s_axis_tdest            (tdest),
  .s_axis_tready           (s_axis_tready),

  .m_axis_tvalid           ({axis_rep_input_tvalid[3],axis_rep_input_tvalid[2],axis_rep_input_tvalid[1],axis_rep_input_tvalid[0]}),
  .m_axis_tdata            ({axis_rep_input_tdata [3],axis_rep_input_tdata [2] ,axis_rep_input_tdata[1] ,axis_rep_input_tdata[0] } ),
  .m_axis_tkeep            ({axis_rep_input_tkeep [3],axis_rep_input_tkeep [2] ,axis_rep_input_tkeep[1] ,axis_rep_input_tkeep[0] } ),
  .m_axis_tlast            ({axis_rep_input_tlast [3],axis_rep_input_tlast [2] ,axis_rep_input_tlast[1] ,axis_rep_input_tlast[0] } ),
  .m_axis_tdest            (),
  .m_axis_tready           ({axis_rep_input_tready[3],axis_rep_input_tready[2],axis_rep_input_tready[1],axis_rep_input_tready[0]}),

  .s_decode_err            (),
  .aclk                    (axis_aclk),
  .aresetn                 (axi_rstn)
);

// Round Robin Metadata Demux

always_ff @(posedge axis_aclk) begin
    if (!axi_rstn) begin
        for (int i = 0; i < N_THREADS; i = i +1) begin
            metadata_in_mt       [i] <= 0;
            metadata_in_valid_mt [i] <= 0;
        end
    end else begin
            metadata_in_mt      [tdest] <= metadata_in;
            metadata_in_valid_mt [tdest] <= metadata_in_valid;
    end
end

// ----------------------------------------------------------------------------------------------------------
//              MULTI THREADED KVS ENGINE
// ----------------------------------------------------------------------------------------------------------
genvar i;
generate
    for (i = 0; i < N_THREADS; i = i + 1) begin : mt_kvs

        // CUCKOO HASH multihashing master to memory
        logic           [33:0] axi_araddr   [NUM_HASHES];
        logic            [1:0] axi_arburst  [NUM_HASHES];
        logic            [3:0] axi_arcache  [NUM_HASHES];
        logic            [3:0] axi_arid     [NUM_HASHES];
        logic            [3:0] axi_arlen    [NUM_HASHES];
        logic            [1:0] axi_arlock   [NUM_HASHES];
        logic            [2:0] axi_arprot   [NUM_HASHES];
        logic                  axi_arready  [NUM_HASHES];
        logic            [2:0] axi_arsize   [NUM_HASHES];
        logic                  axi_arvalid  [NUM_HASHES];
        logic           [33:0] axi_awaddr   [NUM_HASHES];
        logic            [1:0] axi_awburst  [NUM_HASHES];
        logic            [3:0] axi_awcache  [NUM_HASHES];
        logic            [3:0] axi_awid     [NUM_HASHES];
        logic            [3:0] axi_awlen    [NUM_HASHES];
        logic            [1:0] axi_awlock   [NUM_HASHES];
        logic            [2:0] axi_awprot   [NUM_HASHES];
        logic                  axi_awready  [NUM_HASHES];
        logic            [2:0] axi_awsize   [NUM_HASHES];
        logic                  axi_awvalid  [NUM_HASHES];
        logic            [3:0] axi_bid      [NUM_HASHES];
        logic                  axi_bready   [NUM_HASHES];
        logic            [1:0] axi_bresp    [NUM_HASHES];
        logic                  axi_bvalid   [NUM_HASHES];
        logic          [255:0] axi_rdata    [NUM_HASHES];
        logic            [3:0] axi_rid      [NUM_HASHES];
        logic                  axi_rlast    [NUM_HASHES];
        logic                  axi_rready   [NUM_HASHES];
        logic            [1:0] axi_rresp    [NUM_HASHES];
        logic                  axi_rvalid   [NUM_HASHES];
        logic          [255:0] axi_wdata    [NUM_HASHES];
        logic                  axi_wlast    [NUM_HASHES];
        logic                  axi_wready   [NUM_HASHES];
        logic           [31:0] axi_wstrb    [NUM_HASHES];
        logic                  axi_wvalid   [NUM_HASHES];
     
        // rep engine <-> memory strem
        logic                   axis_engine_to_memory_tvalid;
        logic [DATA_WIDTH-1:0]  axis_engine_to_memory_tdata;
        logic [KEEP_WIDTH-1:0]  axis_engine_to_memory_tkeep;
        logic                   axis_engine_to_memory_tlast;
        logic                   axis_engine_to_memory_tready;

        logic                   axis_memory_to_engine_tvalid;
        logic [DATA_WIDTH-1:0]  axis_memory_to_engine_tdata;
        logic [KEEP_WIDTH-1:0]  axis_memory_to_engine_tkeep;
        logic                   axis_memory_to_engine_tlast;
        logic                   axis_memory_to_engine_tready;

        logic                   axis_engine_to_deparser_tvalid;
        logic [DATA_WIDTH-1:0]  axis_engine_to_deparser_tdata;
        logic [KEEP_WIDTH-1:0]  axis_engine_to_deparser_tkeep;
        logic                   axis_engine_to_deparser_tlast;
        logic                   axis_engine_to_deparser_tready;

        // data mover <-> engine data
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

        // data mover control command
        logic                  axis_dm_mm2s_cmd_tvalid;
        logic           [79:0] axis_dm_mm2s_cmd_tdata;
        logic                  axis_dm_mm2s_cmd_tready;

        logic                  axis_dm_s2mm_cmd_tvalid;
        logic           [79:0] axis_dm_s2mm_cmd_tdata;
        logic                  axis_dm_s2mm_cmd_tready;

        // data mover status for debug
        logic   [7:0] axis_dm_write_sts_tdata;
        logic         axis_dm_write_sts_tkeep;
        logic         axis_dm_write_sts_tlast;
        logic         axis_dm_write_sts_tvalid;
        logic         axis_dm_write_sts_tready;
        assign        axis_dm_write_sts_tready = 1'b1;
        
        logic   [7:0] axis_dm_read_sts_tdata;
        logic         axis_dm_read_sts_tkeep;
        logic         axis_dm_read_sts_tlast;
        logic         axis_dm_read_sts_tvalid;
        logic         axis_dm_read_sts_tready;
        assign        axis_dm_read_sts_tready  = 1'b1;

        st_metadata   memory_metadata_in;
        logic         memory_metadata_in_valid;
        st_metadata   memory_metadata_out;
        logic         memory_metadata_out_valid;

        // Arbiter between replication payload and frame padding
        always_comb begin
            m_axis_tvalid[i] = axis_engine_to_deparser_tvalid;
            m_axis_tdata [i] = axis_engine_to_deparser_tdata;
            m_axis_tkeep [i] = axis_engine_to_deparser_tkeep;
            m_axis_tlast [i] = axis_engine_to_deparser_tlast;
            axis_engine_to_deparser_tready = m_axis_tready[i]; 
            if (metadata_out_valid[i]) begin
                if (metadata_out[i].opcode != READ_RESULT && metadata_out[i].opcode != WRITE) begin
                    m_axis_tvalid[i] = 1'b1;
                    m_axis_tdata [i] = '0;
                    m_axis_tkeep [i] = 64'hfff;
                    m_axis_tlast [i] = 1'b1;
                end
            end
        end

        // Arbiter between replication and leader election with priority to the former 
        // metadata signals
        st_metadata   replication_metadata_out      ;
        logic         replication_metadata_out_valid;
    
        always_comb begin
            metadata_out_valid[i]     = 1'b0;
            metadata_out[i]           = '0;
            election_metadata_ready[i]   = 1'b0;
            
            if (replication_metadata_out_valid) begin
                metadata_out_valid[i]   = 1'b1;
                metadata_out[i]         = replication_metadata_out;
            end
            else if (!election_metadata_empty && !axis_engine_to_deparser_tvalid) begin
                metadata_out_valid[i]   = 1'b1;
                metadata_out[i]         = election_metadata_out_reg;
                election_metadata_ready[i] = 1'b1;
            end
        end

        replication_engine #(
          .MAX_NODES                 (MAX_NODES),
          .DATA_WIDTH                (DATA_WIDTH),
          .FIFO_DEPTH                (FIFO_DEPTH),
          .THREAD                    (i)
        ) replication_engine_inst    (
          .axis_clk                  (axis_aclk),
          .axis_rstn                 (axi_rstn),

          .s_axis_tvalid             (axis_rep_input_tvalid[i] && axis_rep_input_tkeep[i] != 64'b0),
          .s_axis_tdata              (axis_rep_input_tdata[i]),
          .s_axis_tkeep              (axis_rep_input_tkeep[i]),
          .s_axis_tlast              (axis_rep_input_tlast[i]),
          .s_axis_tready             (axis_rep_input_tready[i]),

          .metadata_in               (metadata_in_mt[i]),
          .metadata_in_valid         (metadata_in_valid_mt[i]),

          .m_axis_tvalid             (axis_engine_to_deparser_tvalid),
          .m_axis_tdata              (axis_engine_to_deparser_tdata),
          .m_axis_tkeep              (axis_engine_to_deparser_tkeep),
          .m_axis_tlast              (axis_engine_to_deparser_tlast),
          .m_axis_tready             (axis_engine_to_deparser_tready),

          .metadata_out              (replication_metadata_out),
          .metadata_out_valid        (replication_metadata_out_valid),

          .s_axis_mem_tvalid         (axis_memory_to_engine_tvalid),
          .s_axis_mem_tdata          (axis_memory_to_engine_tdata),
          .s_axis_mem_tkeep          (axis_memory_to_engine_tkeep),
          .s_axis_mem_tlast          (axis_memory_to_engine_tlast),
          .s_axis_mem_tready         (axis_memory_to_engine_tready),

          .metadata_mem_in           (memory_metadata_out),
          .metadata_mem_in_valid     (memory_metadata_out_valid),

          .m_axis_mem_tvalid         (axis_engine_to_memory_tvalid),
          .m_axis_mem_tdata          (axis_engine_to_memory_tdata),
          .m_axis_mem_tkeep          (axis_engine_to_memory_tkeep),
          .m_axis_mem_tlast          (axis_engine_to_memory_tlast),
          .m_axis_mem_tready         (axis_engine_to_memory_tready),

          .metadata_mem_out          (memory_metadata_in),
          .metadata_mem_out_valid    (memory_metadata_in_valid),

          .is_leader                 (is_leader)
        );

        cuckoo_hash #(
          .DATA_WIDTH                (DATA_WIDTH),
          .BUCKET_SIZE               (BUCKET_SIZE),
          .NUM_FUNCTIONS             (NUM_HASHES),
          .MAX_KICKS                 (4),
          .HASH_MATRIX               (HASH_MATRIX),
          .THREAD (i)
        ) cuckoo_hash_inst (
          .m_axi_araddr              (axi_araddr),
          .m_axi_arburst             (axi_arburst),
          .m_axi_arcache             (axi_arcache),
          .m_axi_arid                (axi_arid),
          .m_axi_arlen               (axi_arlen),
          .m_axi_arlock              (axi_arlock),
          .m_axi_arprot              (axi_arprot),
          .m_axi_arready             (axi_arready),
          .m_axi_arsize              (axi_arsize),
          .m_axi_arvalid             (axi_arvalid),
          .m_axi_awaddr              (axi_awaddr),
          .m_axi_awburst             (axi_awburst),
          .m_axi_awcache             (axi_awcache),
          .m_axi_awid                (axi_awid),
          .m_axi_awlen               (axi_awlen),
          .m_axi_awlock              (axi_awlock),
          .m_axi_awprot              (axi_awprot),
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
          .m_axi_wvalid              (axi_wvalid),

          .s_axis_tready             (axis_engine_to_memory_tready),
          .s_axis_tdata              (axis_engine_to_memory_tdata),
          .s_axis_tkeep              (axis_engine_to_memory_tkeep),
          .s_axis_tlast              (axis_engine_to_memory_tlast),
          .s_axis_tvalid             (axis_engine_to_memory_tvalid),

          .metadata_in               (memory_metadata_in),
          .metadata_in_valid         (memory_metadata_in_valid),

          .m_axis_tready             (axis_memory_to_engine_tready),
          .m_axis_tdata              (axis_memory_to_engine_tdata),
          .m_axis_tkeep              (axis_memory_to_engine_tkeep),
          .m_axis_tlast              (axis_memory_to_engine_tlast),
          .m_axis_tvalid             (axis_memory_to_engine_tvalid),

          .metadata_out              (memory_metadata_out),
          .metadata_out_valid        (memory_metadata_out_valid),

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

          .m_axis_dm_mm2s_cmd_tvalid (axis_dm_mm2s_cmd_tvalid),
          .m_axis_dm_mm2s_cmd_tdata  (axis_dm_mm2s_cmd_tdata),
          .m_axis_dm_mm2s_cmd_tready (axis_dm_mm2s_cmd_tready),

          .m_axis_dm_s2mm_cmd_tvalid (axis_dm_s2mm_cmd_tvalid),
          .m_axis_dm_s2mm_cmd_tdata  (axis_dm_s2mm_cmd_tdata),
          .m_axis_dm_s2mm_cmd_tready (axis_dm_s2mm_cmd_tready),

          .clk                       (axis_aclk),
          .rstn                      (axi_rstn)
        );

        assign m_axi_mem_arid[i] = i;
        assign m_axi_mem_awid[i] = i;
        prefilter_bd_wrapper i_pf(
            .M00_AXI_0_araddr		(m_axi_mem_araddr[i]),
            .M00_AXI_0_arburst	    (m_axi_mem_arburst[i]),	
            .M00_AXI_0_arcache	    (m_axi_mem_arcache[i]),	
            .M00_AXI_0_arlen 		(m_axi_mem_arlen[i]),
            .M00_AXI_0_arlock		(m_axi_mem_arlock[i]),
            .M00_AXI_0_arprot		(m_axi_mem_arprot[i]),
            .M00_AXI_0_arqos 		(),
            .M00_AXI_0_arready	    (m_axi_mem_arready[i]),	
            .M00_AXI_0_arsize		(m_axi_mem_arsize[i]),
            .M00_AXI_0_aruser		(),
            .M00_AXI_0_arvalid	    (m_axi_mem_arvalid[i]),	
            .M00_AXI_0_awaddr		(m_axi_mem_awaddr[i]),
            .M00_AXI_0_awburst	    (m_axi_mem_awburst[i]),	
            .M00_AXI_0_awcache	    (m_axi_mem_awcache[i]),	
            .M00_AXI_0_awlen 		(m_axi_mem_awlen[i]),
            .M00_AXI_0_awlock		(m_axi_mem_awlock[i]),
            .M00_AXI_0_awprot		(m_axi_mem_awprot[i]),
            .M00_AXI_0_awqos 		(),
            .M00_AXI_0_awready	    (m_axi_mem_awready[i]),	
            .M00_AXI_0_awsize		(m_axi_mem_awsize[i]),
            .M00_AXI_0_awuser		(),
            .M00_AXI_0_awvalid	    (m_axi_mem_awvalid[i]),	
            .M00_AXI_0_bready		(m_axi_mem_bready[i]),
            .M00_AXI_0_bresp 		(m_axi_mem_bresp[i]),
            .M00_AXI_0_bvalid		(m_axi_mem_bvalid[i]),
            .M00_AXI_0_rdata 		(m_axi_mem_rdata[i]),
            .M00_AXI_0_rlast 		(m_axi_mem_rlast[i]),
            .M00_AXI_0_rready		(m_axi_mem_rready[i]),
            .M00_AXI_0_rresp 		(m_axi_mem_rresp[i]),
            .M00_AXI_0_rvalid		(m_axi_mem_rvalid[i]),
            .M00_AXI_0_wdata 		(m_axi_mem_wdata[i]),
            .M00_AXI_0_wlast 		(m_axi_mem_wlast[i]),
            .M00_AXI_0_wready		(m_axi_mem_wready[i]),
            .M00_AXI_0_wstrb 		(m_axi_mem_wstrb[i]),
            .M00_AXI_0_wvalid		(m_axi_mem_wvalid[i]),


            .axi_clk(axis_aclk),
            .axi_resetn (axi_rstn),


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

            .s_axis_dm_s2mm_cmd_tvalid       (axis_dm_s2mm_cmd_tvalid),
            .s_axis_dm_s2mm_cmd_tdata        (axis_dm_s2mm_cmd_tdata),
            .s_axis_dm_s2mm_cmd_tready       (axis_dm_s2mm_cmd_tready),

            .s_axis_dm_mm2s_cmd_tvalid       (axis_dm_mm2s_cmd_tvalid),
            .s_axis_dm_mm2s_cmd_tdata        (axis_dm_mm2s_cmd_tdata),
            .s_axis_dm_mm2s_cmd_tready       (axis_dm_mm2s_cmd_tready),

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
    end
endgenerate

    `ifdef __simulation__
        // Monitor AXI interfaces
        always @(posedge axis_aclk) begin
          for (int j = 0; j < N_THREADS; j++) begin
            if (m_axi_mem_arvalid[j] && m_axi_mem_arready[j])
              $display("[%t] PF OUT [HT: %d] AXI AR: addr=0x%h, len=0x%h, burst=0x%h", $time, j, m_axi_mem_araddr[j], m_axi_mem_arlen[j], m_axi_mem_arburst[j]);
            if (m_axi_mem_rvalid[j] && m_axi_mem_rready[j])
              $display("[%t] PF OUT [HT: %d] AXI R: data=0x%h, resp=0x%h", $time, j, m_axi_mem_rdata[j], m_axi_mem_rresp[j]);
            if (m_axi_mem_awvalid[j] && m_axi_mem_awready[j])
              $display("[%t] PF OUT [HT: %d] AXI AW: addr=0x%h, len=0x%h, burst=0x%h", $time, j, m_axi_mem_awaddr[j], m_axi_mem_awlen[j], m_axi_mem_awburst[j]);
            if (m_axi_mem_wvalid[j] && m_axi_mem_wready[j])
              $display("[%t] PF OUT [HT: %d] AXI W: data=0x%h, strb=0x%h", $time, j, m_axi_mem_wdata[j], m_axi_mem_wstrb[j]);
            if (m_axi_mem_bvalid[j] && m_axi_mem_bready[j])
              $display("[%t] PF OUT [HT: %d] AXI B: resp=0x%h", $time, j, m_axi_mem_bresp[j]);
          end
        end
    `endif

endmodule