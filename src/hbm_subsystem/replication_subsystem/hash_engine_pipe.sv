import metadata_pkg::*;
`include "open_nic_shell_macros.vh"

module hash_engine_pipe # (
  parameter int NUM_FUNCTIONS  = 4,
  parameter int MAX_KICKS      = 4,
  parameter int BUCKET_SIZE    = 1024,
  parameter int DATA_WIDTH     = 512,
  parameter int KEEP_WIDTH     = DATA_WIDTH / 8,
  parameter int HASH_WIDTH     = 34 - $clog2(BUCKET_SIZE),
  parameter int CMD_WIDTH      = 80,
  parameter logic [HASH_WIDTH-1:0] HASH_MATRIX [NUM_FUNCTIONS][KEY_WIDTH-1:0] = '{default: '0},
  parameter int          THREAD     = 0
) (
  input  logic clk,
  input  logic rstn,

  // Write Data from User
  input  logic                  s_axis_tvalid,
  input  logic [DATA_WIDTH-1:0] s_axis_tdata,
  input  logic [KEEP_WIDTH-1:0] s_axis_tkeep,
  input  logic                  s_axis_tuser,
  input  logic                  s_axis_tlast,
  output logic                  s_axis_tready,

  // Metadata In
  input  st_metadata            metadata_in,
  input  logic                  metadata_in_valid,
  output logic                  metadata_in_ready,

  // Read Data to User
  output logic                  m_axis_tvalid,
  output logic [DATA_WIDTH-1:0] m_axis_tdata,
  output logic [KEEP_WIDTH-1:0] m_axis_tkeep,
  output logic                  m_axis_tuser,
  output logic                  m_axis_tlast,
  input  logic                  m_axis_tready,

  // Metadata Out
  output st_metadata            metadata_out,
  output logic                  metadata_out_valid,

  // Read Data from DataMover
  input  logic                  s_axis_dm_tvalid,
  input  logic [DATA_WIDTH-1:0] s_axis_dm_tdata,
  input  logic [KEEP_WIDTH-1:0] s_axis_dm_tkeep,
  input  logic                  s_axis_dm_tlast,
  output logic                  s_axis_dm_tready,

  // Write Data to DataMover
  output logic                  m_axis_dm_tvalid,
  output logic [DATA_WIDTH-1:0] m_axis_dm_tdata,
  output logic [KEEP_WIDTH-1:0] m_axis_dm_tkeep,
  output logic                  m_axis_dm_tlast,
  input  logic                  m_axis_dm_tready,

  // DataMover Commands
  output logic                  m_axis_dm_mm2s_cmd_tvalid,
  output logic  [CMD_WIDTH-1:0] m_axis_dm_mm2s_cmd_tdata,
  input  logic                  m_axis_dm_mm2s_cmd_tready,

  output logic                  m_axis_dm_s2mm_cmd_tvalid,
  output logic  [CMD_WIDTH-1:0] m_axis_dm_s2mm_cmd_tdata,
  input  logic                  m_axis_dm_s2mm_cmd_tready,

  // AXI HBM Interfaces
  output logic           [33:0] m_axi_araddr   [NUM_FUNCTIONS],
  output logic            [1:0] m_axi_arburst  [NUM_FUNCTIONS],
  output logic            [3:0] m_axi_arcache  [NUM_FUNCTIONS],
  output logic            [3:0] m_axi_arid     [NUM_FUNCTIONS],
  output logic            [3:0] m_axi_arlen    [NUM_FUNCTIONS],
  output logic            [1:0] m_axi_arlock   [NUM_FUNCTIONS],
  output logic            [2:0] m_axi_arprot   [NUM_FUNCTIONS],
  input  logic                  m_axi_arready  [NUM_FUNCTIONS],
  output logic            [2:0] m_axi_arsize   [NUM_FUNCTIONS],
  output logic                  m_axi_arvalid  [NUM_FUNCTIONS],
  output logic           [33:0] m_axi_awaddr   [NUM_FUNCTIONS],
  output logic            [1:0] m_axi_awburst  [NUM_FUNCTIONS],
  output logic            [3:0] m_axi_awcache  [NUM_FUNCTIONS],
  output logic            [3:0] m_axi_awid     [NUM_FUNCTIONS],
  output logic            [3:0] m_axi_awlen    [NUM_FUNCTIONS],
  output logic            [1:0] m_axi_awlock   [NUM_FUNCTIONS],
  output logic            [2:0] m_axi_awprot   [NUM_FUNCTIONS],
  input  logic                  m_axi_awready  [NUM_FUNCTIONS],
  output logic            [2:0] m_axi_awsize   [NUM_FUNCTIONS],
  output logic                  m_axi_awvalid  [NUM_FUNCTIONS],
  input  logic            [3:0] m_axi_bid      [NUM_FUNCTIONS],
  output logic                  m_axi_bready   [NUM_FUNCTIONS],
  input  logic            [1:0] m_axi_bresp    [NUM_FUNCTIONS],
  input  logic                  m_axi_bvalid   [NUM_FUNCTIONS],
  input  logic          [255:0] m_axi_rdata    [NUM_FUNCTIONS],
  input  logic            [3:0] m_axi_rid      [NUM_FUNCTIONS],
  input  logic                  m_axi_rlast    [NUM_FUNCTIONS],
  output logic                  m_axi_rready   [NUM_FUNCTIONS],
  input  logic            [1:0] m_axi_rresp    [NUM_FUNCTIONS],
  input  logic                  m_axi_rvalid   [NUM_FUNCTIONS],
  output logic          [255:0] m_axi_wdata    [NUM_FUNCTIONS],
  output logic                  m_axi_wlast    [NUM_FUNCTIONS],
  input  logic                  m_axi_wready   [NUM_FUNCTIONS],
  output logic           [31:0] m_axi_wstrb    [NUM_FUNCTIONS],
  output logic                  m_axi_wvalid   [NUM_FUNCTIONS]
);

  // -------------------------------------------------------------------------
  // Parameters & Config
  // -------------------------------------------------------------------------
  localparam int READ_FIFO_DEPTH     = 2 * BUCKET_SIZE * 8 / DATA_WIDTH;
  localparam int WRITE_FIFO_DEPTH    = 64 * BUCKET_SIZE * 8 / DATA_WIDTH;
  localparam int PIPELINE_FIFO_DEPTH = 64; 
  localparam int DL_FIFO_DEPTH       = MAX_KICKS * BUCKET_SIZE * 8 / DATA_WIDTH;

  localparam int ADDRESS_SHIFT       = $clog2(BUCKET_SIZE);
  localparam int KICK_COUNT_WIDTH    = $clog2(MAX_KICKS);
  localparam logic [22:0] DM_BTT     = BUCKET_SIZE;

  // -------------------------------------------------------------------------
  // Pipeline Structs
  // -------------------------------------------------------------------------
  typedef struct packed {
    st_metadata meta;
    logic [KICK_COUNT_WIDTH-1:0] kick_count;
  } pipe_meta_t;

  typedef struct packed{
    pipe_meta_t request;
    logic [HASH_WIDTH-1:0][NUM_FUNCTIONS] addresses;
  } stage1_data_t;

  typedef struct packed {
    pipe_meta_t request;
    logic [HASH_WIDTH-1:0] target_address;
    logic [KEY_WIDTH-1:0]  kicked_key;
    logic collision;
  } stage2_data_t;

  // -------------------------------------------------------------------------
  // Functions
  // -------------------------------------------------------------------------
  function automatic logic [HASH_WIDTH-1:0] hash (
    input logic  [KEY_WIDTH-1:0] key,
    input logic [HASH_WIDTH-1:0] matrix [KEY_WIDTH-1:0]
  );
    logic [HASH_WIDTH-1:0] accumulator = '0;
    for (int i = 0; i < KEY_WIDTH; i = i + 1)
        if (key[i]) accumulator ^= matrix[i];
    return accumulator;
  endfunction

  function automatic logic no_collisions (
    input  logic                  read_op,
    input  logic           [31:0] stored_dirty [NUM_FUNCTIONS],
    input  logic  [KEY_WIDTH-1:0] stored_keys [NUM_FUNCTIONS],
    input  logic [HASH_WIDTH-1:0] [NUM_FUNCTIONS] current_addresses ,
    input  logic  [KEY_WIDTH-1:0] current_key,
    output logic [HASH_WIDTH-1:0] address
  );
    logic read_possible, write_possible;
    for (int i = 0; i < NUM_FUNCTIONS; i++) begin
      read_possible = (stored_dirty[i] == VALID_TAG) && (stored_keys[i] == current_key);
      write_possible = (stored_dirty[i] != VALID_TAG) || (stored_keys[i] == current_key);
      if ((read_op && read_possible) || (!read_op && write_possible)) begin
        address = current_addresses[i];
        return 1'b1;
      end
    end
    address = '0;
    return 1'b0;
  endfunction

  // -------------------------------------------------------------------------
  // Buffers (External Data to Internal Stream)
  // -------------------------------------------------------------------------
  logic                  int_wr_tvalid, int_wr_tready, int_wr_tlast;
  logic [DATA_WIDTH-1:0] int_wr_tdata;
  logic [KEEP_WIDTH-1:0] int_wr_tkeep;

  logic                  int_rd_tvalid, int_rd_tready, int_rd_tlast;
  logic [DATA_WIDTH-1:0] int_rd_tdata;
  logic [KEEP_WIDTH-1:0] int_rd_tkeep;

  xpm_fifo_axis #(
    .FIFO_DEPTH(WRITE_FIFO_DEPTH), 
    .TDATA_WIDTH(DATA_WIDTH)
  ) write_fifo_inst (
    .m_aclk(clk), .s_aclk(clk), .s_aresetn(rstn),
    .s_axis_tvalid(s_axis_tvalid), .s_axis_tready(s_axis_tready),
    .s_axis_tdata(s_axis_tdata), .s_axis_tkeep(s_axis_tkeep),
    .s_axis_tlast(s_axis_tlast), .s_axis_tuser(s_axis_tuser),
    .s_axis_tdest(1'b0), .s_axis_tid(1'b0), .s_axis_tstrb('0),
    .m_axis_tvalid(int_wr_tvalid), .m_axis_tready(int_wr_tready),
    .m_axis_tdata(int_wr_tdata), .m_axis_tkeep(int_wr_tkeep),
    .m_axis_tlast(int_wr_tlast), .m_axis_tuser(), .m_axis_tdest(), .m_axis_tid(), .m_axis_tstrb(),
    .injectsbiterr_axis(1'b0), .injectdbiterr_axis(1'b0)
  );

  xpm_fifo_axis #(
    .FIFO_DEPTH(READ_FIFO_DEPTH), 
    .TDATA_WIDTH(DATA_WIDTH)
  ) read_fifo_inst (
    .m_aclk(clk), .s_aclk(clk), .s_aresetn(rstn),
    .s_axis_tvalid(int_rd_tvalid), .s_axis_tready(int_rd_tready),
    .s_axis_tdata(int_rd_tdata), .s_axis_tkeep(int_rd_tkeep),
    .s_axis_tlast(int_rd_tlast), .s_axis_tuser(1'b0),
    .s_axis_tdest(1'b0), .s_axis_tid(1'b0), .s_axis_tstrb('0),
    .m_axis_tvalid(m_axis_tvalid), .m_axis_tready(m_axis_tready),
    .m_axis_tdata(m_axis_tdata), .m_axis_tkeep(m_axis_tkeep),
    .m_axis_tlast(m_axis_tlast), .m_axis_tuser(m_axis_tuser), .m_axis_tdest(), .m_axis_tid(), .m_axis_tstrb(),
    .injectsbiterr_axis(1'b0), .injectdbiterr_axis(1'b0)
  );

  // -------------------------------------------------------------------------
  // Control Loopback FIFO (Metadata)
  // -------------------------------------------------------------------------
  logic loopback_fifo_full, loopback_fifo_empty;
  logic loopback_fifo_wr_en, loopback_fifo_rd_en;
  pipe_meta_t loopback_din, loopback_dout;

  xpm_fifo_sync #(
    .DOUT_RESET_VALUE    ("0"),
    .ECC_MODE            ("no_ecc"),
    .FIFO_MEMORY_TYPE    ("auto"),
    .FIFO_WRITE_DEPTH(PIPELINE_FIFO_DEPTH), 
    .WRITE_DATA_WIDTH($bits(pipe_meta_t)), 
    .READ_DATA_WIDTH($bits(pipe_meta_t)), 
    .READ_MODE("fwft")
  ) loopback_fifo (
    .wr_clk(clk), .rst(!rstn),
    .din(loopback_din), 
    .wr_en(loopback_fifo_wr_en), 
    .full(loopback_fifo_full),
    .dout(loopback_dout), 
    .rd_en(loopback_fifo_rd_en), 
    .empty(loopback_fifo_empty)
  );

  // -------------------------------------------------------------------------
  // Data Loopback FIFO (Payloads)
  // -------------------------------------------------------------------------
  logic                  dl_in_tvalid,  dl_out_tvalid;
  logic [DATA_WIDTH-1:0] dl_in_tdata,   dl_out_tdata;
  logic [KEEP_WIDTH-1:0] dl_in_tkeep,   dl_out_tkeep;
  logic                  dl_in_tlast,   dl_out_tlast;
  logic                  dl_in_tready,  dl_out_tready;

  xpm_fifo_axis #(
    .FIFO_DEPTH(DL_FIFO_DEPTH), 
    .TDATA_WIDTH(DATA_WIDTH)
  ) data_loopback_fifo (
    .m_aclk(clk), 
    .s_aclk(clk), 
    .s_aresetn(rstn),
    .s_axis_tvalid(dl_in_tvalid), 
    .s_axis_tready(dl_in_tready),
    .s_axis_tdata(dl_in_tdata), 
    .s_axis_tkeep(dl_in_tkeep), 
    .s_axis_tlast(dl_in_tlast),
    .s_axis_tuser(1'b0), 
    .s_axis_tdest(1'b0), 
    .s_axis_tid(1'b0), 
    .s_axis_tstrb('0),
    .m_axis_tvalid(dl_out_tvalid), 
    .m_axis_tready(dl_out_tready),
    .m_axis_tdata(dl_out_tdata), 
    .m_axis_tkeep(dl_out_tkeep), 
    .m_axis_tlast(dl_out_tlast),
    .m_axis_tuser(), 
    .m_axis_tdest(), 
    .m_axis_tid(), 
    .m_axis_tstrb(),
    .injectsbiterr_axis(1'b0), 
    .injectdbiterr_axis(1'b0)
  );

  // -------------------------------------------------------------------------
  // Pipeline Stage 1: Arbiter, Hash Calculation & HBM Read Issue
  // -------------------------------------------------------------------------
  logic stage1_fifo_full, stage1_fifo_wr_en;
  stage1_data_t stage1_din;
  logic [NUM_FUNCTIONS] ar_valid_reg;
  logic stage1_ready;
  
  logic process_loopback, process_new;
  pipe_meta_t active_request;

  assign process_loopback = !loopback_fifo_empty;
  assign process_new      = !process_loopback && metadata_in_valid;
  
  assign stage1_ready      = ~stage1_fifo_full && ~(|ar_valid_reg);
  assign metadata_in_ready = process_new && stage1_ready;

    always_comb begin
        if (process_loopback) begin
            active_request = loopback_dout;
        end else begin
            active_request.meta       = metadata_in;
            active_request.kick_count = '0;
        end
    end

    always_ff @(posedge clk) begin
        if (!rstn) begin
            ar_valid_reg        <= '0;
            stage1_fifo_wr_en   <= 1'b0;
            loopback_fifo_rd_en <= 1'b0;
        end else begin
            stage1_fifo_wr_en   <= 1'b0; 
            loopback_fifo_rd_en <= 1'b0;

            if (process_new && stage1_ready) begin
                for (int i = 0; i < NUM_FUNCTIONS; i++) begin
                    stage1_din.addresses[`getvec(HASH_WIDTH,i)] <= hash(active_request.meta.key, HASH_MATRIX[i]);
                    stage1_din.request  <= active_request;
                    stage1_fifo_wr_en   <= 1'b1; 
                end
                for (int i = 0; i < NUM_FUNCTIONS; i++) begin
                    m_axi_araddr[i]   <= hash(active_request.meta.key, HASH_MATRIX[i]) << ADDRESS_SHIFT;
                    ar_valid_reg[i]   <= '1;
                    m_axi_arburst[i]  <= 2'b1;    
                    m_axi_arcache[i]  <= 4'b0;    
                    m_axi_arprot[i]   <= 3'b0;    
                    m_axi_arid[i]     <= i;
                    m_axi_arlen[i]    <= 4'b0;    
                    m_axi_arlock[i]   <= 2'b0;    
                    m_axi_arsize[i]   <= 3'b100;  
                end
            end else begin
                for (int i=0; i<NUM_FUNCTIONS; i++) begin
                    if (m_axi_arready[i] && ar_valid_reg[i]) 
                        ar_valid_reg[i] <= 1'b0;
                end
            end
        end
    end

    for (genvar i = 0; i < NUM_FUNCTIONS; i++) generate
      assign m_axi_arvalid[i] = ar_valid_reg[i];   
    endgenerate
  
  logic stage1_fifo_empty, stage1_fifo_rd_en;
  stage1_data_t stage1_dout;

  xpm_fifo_sync #(
    .DOUT_RESET_VALUE    ("0"),
    .ECC_MODE            ("no_ecc"),
    .FIFO_MEMORY_TYPE    ("auto"),
    .FIFO_READ_LATENCY   (1),
    .FIFO_WRITE_DEPTH(PIPELINE_FIFO_DEPTH), 
    .WRITE_DATA_WIDTH($bits(stage1_data_t)), 
    .READ_DATA_WIDTH($bits(stage1_data_t)), 
    .READ_MODE("fwft")
  ) stage1_fifo (
    .wr_clk(clk), .rst(!rstn),
    .din(stage1_din), 
    .wr_en(stage1_fifo_wr_en), 
    .full(stage1_fifo_full),
    .dout(stage1_dout), 
    .rd_en(stage1_fifo_rd_en), 
    .empty(stage1_fifo_empty)
  );

  // -------------------------------------------------------------------------
  // Pipeline Stage 2: HBM Read Response & Collision Resolution
  // -------------------------------------------------------------------------
  logic [NUM_FUNCTIONS-1:0] r_valid_reg;
  logic [31:0]              r_dirty_reg [NUM_FUNCTIONS-1:0];
  logic [KEY_WIDTH-1:0]     r_keys_reg  [NUM_FUNCTIONS-1:0];

  logic stage2_fifo_full, stage2_fifo_wr_en;
  stage2_data_t stage2_din;

  logic all_reads_returned;
  assign all_reads_returned = (&r_valid_reg);

  always_ff @(posedge clk) begin
    if (!rstn) begin
      r_valid_reg       <= '0;
      stage2_fifo_wr_en <= 1'b0;
      stage1_fifo_rd_en <= 1'b0;
    end else begin
      stage2_fifo_wr_en <= 1'b0;
      stage1_fifo_rd_en <= 1'b0;

      for (int i = 0; i < NUM_FUNCTIONS; i++) begin
        if (m_axi_rvalid[i]) begin
          r_valid_reg[i] <= 1'b1;
          r_dirty_reg[i] <= m_axi_rdata[i][31:0];
          r_keys_reg[i]  <= {<< 8 {m_axi_rdata[i][32+:KEY_WIDTH]}};
        end
      end

      if (all_reads_returned && !stage1_fifo_empty && !stage2_fifo_full) begin
        logic read_op;
        logic [HASH_WIDTH-1:0] target_addr;
        logic [KEY_WIDTH-1:0]  evicted_key;
        logic collision;

        read_op = (stage1_dout.request.meta.opcode == metadata_pkg::READ);
        
        if (no_collisions(read_op, r_dirty_reg, r_keys_reg, stage1_dout.addresses, stage1_dout.request.meta.key, target_addr)) begin
          collision   = 1'b0;
          evicted_key = '0;
        end else begin
          collision   = 1'b1;
          target_addr = stage1_dout.addresses[`getvec(HASH_WIDTH,stage1_dout.request.kick_count)];
          evicted_key = r_keys_reg[stage1_dout.request.kick_count];
        end

        stage2_din.request        = stage1_dout.request;
        stage2_din.target_address = target_addr;
        stage2_din.kicked_key     = evicted_key;
        stage2_din.collision      = collision;
        stage2_fifo_wr_en         = 1'b1;
        
        stage1_fifo_rd_en <= 1'b1;
        r_valid_reg       <= '0;
      end
    end
  end

  always_comb begin
    for (int i = 0; i < NUM_FUNCTIONS; i++) begin
      m_axi_rready[i] = 1'b1; 
    end
  end

  logic stage2_fifo_empty, stage2_fifo_rd_en;
  stage2_data_t stage2_dout;

  xpm_fifo_sync #(
    .DOUT_RESET_VALUE    ("0"),
    .ECC_MODE            ("no_ecc"),
    .FIFO_MEMORY_TYPE    ("auto"),
    .FIFO_READ_LATENCY   (1),
    .FIFO_WRITE_DEPTH(PIPELINE_FIFO_DEPTH), 
    .WRITE_DATA_WIDTH($bits(stage2_data_t)), 
    .READ_DATA_WIDTH($bits(stage2_data_t)), 
    .READ_MODE("fwft")
  ) stage2_fifo (
    .wr_clk(clk), 
    .rst(!rstn),
    .din(stage2_din), 
    .wr_en(stage2_fifo_wr_en), 
    .full(stage2_fifo_full),
    .dout(stage2_dout), 
    .rd_en(stage2_fifo_rd_en), 
    .empty(stage2_fifo_empty)
  );

  // -------------------------------------------------------------------------
  // Stage 3 FSM & Crossbar: Datamover & Feedback logic
  // -------------------------------------------------------------------------
  typedef enum logic [3:0] {
    S3_IDLE, S3_READ_CMD, S3_READ_DATA_AND_FLUSH, S3_WRITE_CMD, 
    S3_WRITE_DATA, S3_SWAP_CMD_READ, S3_SWAP_READ_DATA, 
    S3_SWAP_CMD_WRITE, S3_SWAP_WRITE_DATA, S3_DONE
  } stage3_state_e;

  stage3_state_e stage3_state, stage3_state_next;
  logic read_stream_done, read_stream_done_next;
  logic flush_stream_done, flush_stream_done_next;

  logic is_kick_op;
  assign is_kick_op = (stage2_dout.request.kick_count > 0);

  always_ff @(posedge clk) begin
    if (!rstn) begin
      stage3_state      <= S3_IDLE;
      read_stream_done  <= 1'b0;
      flush_stream_done <= 1'b0;
    end else begin
      stage3_state      <= stage3_state_next;
      read_stream_done  <= read_stream_done_next;
      flush_stream_done <= flush_stream_done_next;
    end
  end

  // Combinational Crossbar & FSM Control
  always_comb begin
    stage3_state_next          = stage3_state;
    read_stream_done_next      = read_stream_done;
    flush_stream_done_next     = flush_stream_done;
    
    stage2_fifo_rd_en          = 1'b0;
    loopback_fifo_wr_en        = 1'b0;
    loopback_din               = '0;

    metadata_out_valid         = 1'b0;
    metadata_out               = stage2_dout.request.meta;
    
    m_axis_dm_mm2s_cmd_tvalid  = 1'b0;
    m_axis_dm_s2mm_cmd_tvalid  = 1'b0;
    m_axis_dm_mm2s_cmd_tdata   = {8'b0, 6'b0, stage2_dout.target_address, 10'h0, 1'b0, 1'b1, 6'b0, 1'b1, DM_BTT};
    m_axis_dm_s2mm_cmd_tdata   = {8'b0, 6'b0, stage2_dout.target_address, 10'h0, 1'b0, 1'b1, 6'b0, 1'b1, DM_BTT};

    // Default Crossbar state
    m_axis_dm_tvalid    = 1'b0; 
    m_axis_dm_tdata     = '0; 
    m_axis_dm_tkeep     = '0; 
    m_axis_dm_tlast     = 1'b0;

    int_wr_tready       = 1'b0; 
    dl_out_tready       = 1'b0;

    int_rd_tvalid       = 1'b0; 
    int_rd_tdata        = '0; 
    int_rd_tkeep        = '0; 
    int_rd_tlast        = 1'b0;

    dl_in_tvalid        = 1'b0; 
    dl_in_tdata         = '0; 
    dl_in_tkeep         = '0; 
    dl_in_tlast         = 1'b0;

    s_axis_dm_tready    = 1'b0;

    // Stream Routing
    if (stage3_state == S3_WRITE_DATA || stage3_state == S3_SWAP_WRITE_DATA) begin
        if (is_kick_op) begin
            m_axis_dm_tvalid    = dl_out_tvalid; 
            m_axis_dm_tdata     = dl_out_tdata; 
            m_axis_dm_tkeep     = dl_out_tkeep; 
            m_axis_dm_tlast     = dl_out_tlast;
            dl_out_tready       = m_axis_dm_tready;
        end else begin
            m_axis_dm_tvalid    = int_wr_tvalid; 
            m_axis_dm_tdata     = int_wr_tdata; 
            m_axis_dm_tkeep     = int_wr_tkeep; 
            m_axis_dm_tlast     = int_wr_tlast;
            int_wr_tready       = m_axis_dm_tready;
        end
    end

    if (stage3_state == S3_READ_DATA_AND_FLUSH) begin
        int_rd_tvalid       = s_axis_dm_tvalid; 
        int_rd_tdata        = s_axis_dm_tdata; 
        int_rd_tkeep        = s_axis_dm_tkeep; 
        int_rd_tlast        = s_axis_dm_tlast;
        s_axis_dm_tready    = int_rd_tready;
        if (!is_kick_op && !flush_stream_done) int_wr_tready = 1'b1;
    end else if (stage3_state == S3_SWAP_READ_DATA) begin
        dl_in_tvalid        = s_axis_dm_tvalid; 
        dl_in_tdata         = s_axis_dm_tdata; 
        dl_in_tkeep         = s_axis_dm_tkeep; 
        dl_in_tlast         = s_axis_dm_tlast;
        s_axis_dm_tready    = dl_in_tready;
    end

    // FSM State transitions
    case (stage3_state)
      S3_IDLE: begin
        read_stream_done_next  = 1'b0;
        flush_stream_done_next = 1'b0;
        if (!stage2_fifo_empty) begin
          if (stage2_dout.request.meta.opcode == metadata_pkg::READ) begin
            stage3_state_next = stage2_dout.collision ? S3_DONE : S3_READ_CMD;
          end else begin
            stage3_state_next = stage2_dout.collision ? S3_SWAP_CMD_READ : S3_WRITE_CMD;
          end
        end
      end

      S3_READ_CMD: begin
        m_axis_dm_mm2s_cmd_tvalid = 1'b1;
        if (m_axis_dm_mm2s_cmd_tready) stage3_state_next = S3_READ_DATA_AND_FLUSH;
      end

      S3_READ_DATA_AND_FLUSH: begin
        if (s_axis_dm_tvalid && s_axis_dm_tready && s_axis_dm_tlast) read_stream_done_next = 1'b1;
        if (int_wr_tvalid && int_wr_tready && int_wr_tlast) flush_stream_done_next = 1'b1;

        if ((read_stream_done || (s_axis_dm_tvalid && s_axis_dm_tready && s_axis_dm_tlast)) &&
            (is_kick_op || flush_stream_done || (int_wr_tvalid && int_wr_tready && int_wr_tlast))) begin
          stage3_state_next = S3_DONE;
        end
      end

      S3_WRITE_CMD: begin
        m_axis_dm_s2mm_cmd_tvalid = 1'b1;
        if (m_axis_dm_s2mm_cmd_tready) stage3_state_next = S3_WRITE_DATA;
      end

      S3_WRITE_DATA: begin
        if ((is_kick_op ? dl_out_tvalid : int_wr_tvalid) && m_axis_dm_tready && (is_kick_op ? dl_out_tlast : int_wr_tlast)) begin
          stage3_state_next = S3_DONE;
        end
      end

      S3_SWAP_CMD_READ: begin
        m_axis_dm_mm2s_cmd_tvalid = 1'b1;
        if (m_axis_dm_mm2s_cmd_tready) stage3_state_next = S3_SWAP_READ_DATA;
      end

      S3_SWAP_READ_DATA: begin
        if (s_axis_dm_tvalid && s_axis_dm_tready && s_axis_dm_tlast) stage3_state_next = S3_SWAP_CMD_WRITE;
      end

      S3_SWAP_CMD_WRITE: begin
        m_axis_dm_s2mm_cmd_tvalid = 1'b1;
        if (m_axis_dm_s2mm_cmd_tready) stage3_state_next = S3_SWAP_WRITE_DATA;
      end

      S3_SWAP_WRITE_DATA: begin
        if ((is_kick_op ? dl_out_tvalid : int_wr_tvalid) && m_axis_dm_tready && (is_kick_op ? dl_out_tlast : int_wr_tlast)) begin
          if (stage2_dout.request.kick_count == (MAX_KICKS - 1)) begin
            stage2_fifo_rd_en   = 1'b1;
            metadata_out_valid  = 1'b1;
            metadata_out.opcode = OUT_OF_MEM; 
            stage3_state_next   = S3_IDLE;
          end else begin
            loopback_din.meta       = stage2_dout.request.meta;
            loopback_din.meta.key   = stage2_dout.kicked_key; 
            loopback_din.kick_count = stage2_dout.request.kick_count + 1;
            loopback_fifo_wr_en     = 1'b1;
            stage2_fifo_rd_en       = 1'b1;
            stage3_state_next       = S3_IDLE;
          end
        end
      end

      S3_DONE: begin
        stage2_fifo_rd_en  = 1'b1;
        if (!is_kick_op) begin // Only output to user if it's the original request concluding
            metadata_out_valid = 1'b1;
            if (stage2_dout.request.meta.opcode == metadata_pkg::READ && stage2_dout.collision) begin
              metadata_out.opcode = READ_NOT_FOUND;
            end
        end
        stage3_state_next = S3_IDLE;
      end
    endcase
  end


`ifdef __simulation__

  // Monitor s_axis_dm interface (Data from DataMover)
  always @(posedge clk) begin
    if (s_axis_dm_tvalid && s_axis_dm_tready) begin
      $display("[%t] CUCKOO [HT: %d] S_AXIS_DM: data=0x%h, keep=0x%h, last=%b", $time, THREAD, s_axis_dm_tdata, s_axis_dm_tkeep, s_axis_dm_tlast);
    end
  end

  // Monitor m_axis_dm interface (Data to DataMover)
  always @(posedge clk) begin
    if (m_axis_dm_tvalid && m_axis_dm_tready) begin
      $display("[%t] CUCKOO [HT: %d] M_AXIS_DM: data=0x%h, keep=0x%h, last=%b", $time, THREAD, m_axis_dm_tdata, m_axis_dm_tkeep, m_axis_dm_tlast);
    end
  end

  // Monitor MM2S Command interface
  always @(posedge clk) begin
    if (m_axis_dm_mm2s_cmd_tvalid && m_axis_dm_mm2s_cmd_tready) begin
      $display("[%t] CUCKOO [HT: %d] MM2S CMD: data=0x%h", $time, THREAD, m_axis_dm_mm2s_cmd_tdata);
    end
  end

  // Monitor S2MM Command interface
  always @(posedge clk) begin
    if (m_axis_dm_s2mm_cmd_tvalid && m_axis_dm_s2mm_cmd_tready) begin
      $display("[%t] CUCKOO [HT: %d] S2MM CMD: data=0x%h", $time, THREAD, m_axis_dm_s2mm_cmd_tdata);
    end
  end

  // Monitor AXI interfaces
  always @(posedge clk) begin
    for (int j = 0; j < NUM_FUNCTIONS; j++) begin
      if (m_axi_arvalid[j] && m_axi_arready[j])
        $display("[%t] CUCKOO [HT: %d] AXI AR[%0d]: addr=0x%h, len=0x%h, burst=0x%h", $time, THREAD, j, m_axi_araddr[j], m_axi_arlen[j], m_axi_arburst[j]);
      if (m_axi_rvalid[j] && m_axi_rready[j])
        $display("[%t] CUCKOO [HT: %d] AXI R[%0d]: data=0x%h, resp=0x%h", $time, THREAD, j, m_axi_rdata[j], m_axi_rresp[j]);
    end
  end

  // --- Optional: New Pipeline Debugging ---
  // You might find it helpful to add this block to watch the loopback mechanism in action!
  always @(posedge clk) begin
    if (loopback_fifo_wr_en) begin
      $display("[%t] CUCKOO [HT: %d] PIPELINE KICK: Evicting key 0x%h, Kick Count -> %0d", 
               $time, THREAD, loopback_din.meta.key, loopback_din.kick_count);
    end
  end

  // -------------------------------------------------------------------------
  // Pipeline Stage Debugging
  // -------------------------------------------------------------------------

  // Stage 1 Input: Arbiter / Hash Calculation
  always @(posedge clk) begin
    if (stage1_fifo_wr_en) begin
      $display("[%t] CUCKOO [HT: %d] STAGE 1 IN : Opcode=%0d, Key=0x%h, KickCount=%0d", 
               $time, THREAD, stage1_din.request.meta.opcode, stage1_din.request.meta.key, stage1_din.request.kick_count);
      for (int k = 0; k < NUM_FUNCTIONS; k++) begin
        $display("[%t] CUCKOO [HT: %d] STAGE 1 HASH: Func[%0d] Addr=0x%h", 
                 $time, THREAD, k, stage1_din.addresses[`getvec(HASH_WIDTH,k)]);
      end
    end
  end

  // Stage 2 Input: Collision Resolution (Fires when all HBM reads return)
  always @(posedge clk) begin
    if (stage2_fifo_wr_en) begin
      $display("[%t] CUCKOO [HT: %d] STAGE 2 IN : Opcode=%0d, Key=0x%h, KickCount=%0d", 
               $time, THREAD, stage2_din.request.meta.opcode, stage2_din.request.meta.key, stage2_din.request.kick_count);
      $display("[%t] CUCKOO [HT: %d] STAGE 2 RES: Collision=%b, TargetAddr=0x%h, KickedKey=0x%h", 
               $time, THREAD, stage2_din.collision, stage2_din.target_address, stage2_din.kicked_key);
    end
  end

  // Stage 3 Input: Datamover FSM (Fires when picking up a new packet from Stage 2 FIFO)
  always @(posedge clk) begin
    if (stage3_state == S3_IDLE && stage3_state_next != S3_IDLE) begin
      $display("[%t] CUCKOO [HT: %d] STAGE 3 IN : Opcode=%0d, Key=0x%h, KickCount=%0d, Collision=%b, TargetAddr=0x%h", 
               $time, THREAD, stage2_dout.request.meta.opcode, stage2_dout.request.meta.key, 
               stage2_dout.request.kick_count, stage2_dout.collision, stage2_dout.target_address);
    end
  end

  // Loopback Input: Fired when an eviction forces a re-insert
  always @(posedge clk) begin
    if (loopback_fifo_wr_en) begin
      $display("[%t] CUCKOO [HT: %d] LOOPBACK IN: OriginalOp=%0d, EvictedKey=0x%h, NewKickCount=%0d", 
               $time, THREAD, loopback_din.meta.opcode, loopback_din.meta.key, loopback_din.kick_count);
    end
  end

  `endif
endmodule