import metadata_pkg::*;

module hash_engine_pipe_simple # (
  parameter int NUM_FUNCTIONS  = 4,
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
  input  logic          [127:0] m_axi_rdata    [NUM_FUNCTIONS],
  input  logic            [3:0] m_axi_rid      [NUM_FUNCTIONS],
  input  logic                  m_axi_rlast    [NUM_FUNCTIONS],
  output logic                  m_axi_rready   [NUM_FUNCTIONS],
  input  logic            [1:0] m_axi_rresp    [NUM_FUNCTIONS],
  input  logic                  m_axi_rvalid   [NUM_FUNCTIONS],
  output logic          [127:0] m_axi_wdata    [NUM_FUNCTIONS],
  output logic                  m_axi_wlast    [NUM_FUNCTIONS],
  input  logic                  m_axi_wready   [NUM_FUNCTIONS],
  output logic           [31:0] m_axi_wstrb    [NUM_FUNCTIONS],
  output logic                  m_axi_wvalid   [NUM_FUNCTIONS]
);

  // -------------------------------------------------------------------------
  // Parameters & Config
  // -------------------------------------------------------------------------
  localparam int READ_FIFO_DEPTH     = 2 * BUCKET_SIZE * 8 / DATA_WIDTH;
  localparam int WRITE_FIFO_DEPTH    = 128 * BUCKET_SIZE * 8 / DATA_WIDTH;
  localparam int PIPELINE_FIFO_DEPTH = 256; 

  localparam int ADDRESS_SHIFT       = $clog2(BUCKET_SIZE);
  localparam logic [22:0] DM_BTT     = BUCKET_SIZE;

  // -------------------------------------------------------------------------
  // Pipeline Structs 
  // -------------------------------------------------------------------------
  typedef struct packed {
    st_metadata meta;
    logic [NUM_FUNCTIONS-1:0][HASH_WIDTH-1:0] addresses;
  } s1_data_t;

  typedef struct packed {
    st_metadata meta;
    logic [HASH_WIDTH-1:0] target_address;
    logic invalid_target;
  } s2_data_t;

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
    input  logic [HASH_WIDTH-1:0] current_addresses [NUM_FUNCTIONS],
    input  logic  [KEY_WIDTH-1:0] current_key,
    output logic [HASH_WIDTH-1:0] address
  );
    logic read_possible, write_possible;
    for (int i = 0; i < NUM_FUNCTIONS; i++) begin
      read_possible  = (stored_dirty[i] == VALID_TAG) && (stored_keys[i] == current_key);
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
  // Stage 0: Write payloads buffer, Read payloads buffer
  // -------------------------------------------------------------------------
  logic                  int_wr_tvalid, int_wr_tready, int_wr_tlast;
  logic [DATA_WIDTH-1:0] int_wr_tdata;
  logic [KEEP_WIDTH-1:0] int_wr_tkeep;

  logic                  int_rd_tvalid, int_rd_tready, int_rd_tlast;
  logic [DATA_WIDTH-1:0] int_rd_tdata;
  logic [KEEP_WIDTH-1:0] int_rd_tkeep;

  xpm_fifo_axis #(
    .ECC_MODE("no_ecc"), .FIFO_MEMORY_TYPE("auto"),
    .FIFO_DEPTH(WRITE_FIFO_DEPTH), .TDATA_WIDTH(DATA_WIDTH)
  ) write_fifo_inst (
    .m_aclk(clk), .s_aclk(clk), .s_aresetn(rstn),
    .s_axis_tvalid(s_axis_tvalid), .s_axis_tready(s_axis_tready),
    .s_axis_tdata(s_axis_tdata), .s_axis_tkeep(s_axis_tkeep),
    .s_axis_tlast(s_axis_tlast), .s_axis_tuser('0),
    .s_axis_tdest(1'b0), .s_axis_tid(1'b0), .s_axis_tstrb('0),
    .m_axis_tvalid(int_wr_tvalid), .m_axis_tready(int_wr_tready),
    .m_axis_tdata(int_wr_tdata), .m_axis_tkeep(int_wr_tkeep),
    .m_axis_tlast(int_wr_tlast), .m_axis_tuser(), .m_axis_tdest(), .m_axis_tid(), .m_axis_tstrb(),
    .injectsbiterr_axis(1'b0), .injectdbiterr_axis(1'b0)
  );

  xpm_fifo_axis #(
    .ECC_MODE("no_ecc"), .FIFO_MEMORY_TYPE("auto"),
    .FIFO_DEPTH(READ_FIFO_DEPTH), .TDATA_WIDTH(DATA_WIDTH)
  ) read_fifo_inst (
    .m_aclk(clk), .s_aclk(clk), .s_aresetn(rstn),
    .s_axis_tvalid(int_rd_tvalid), .s_axis_tready(int_rd_tready),
    .s_axis_tdata(int_rd_tdata), .s_axis_tkeep(int_rd_tkeep),
    .s_axis_tlast(int_rd_tlast), .s_axis_tuser(1'b0),
    .s_axis_tdest(1'b0), .s_axis_tid(1'b0), .s_axis_tstrb('0),
    .m_axis_tvalid(m_axis_tvalid), .m_axis_tready(m_axis_tready),
    .m_axis_tdata(m_axis_tdata), .m_axis_tkeep(m_axis_tkeep),
    .m_axis_tlast(m_axis_tlast), .m_axis_tuser(), .m_axis_tdest(), .m_axis_tid(), .m_axis_tstrb(),
    .injectsbiterr_axis(1'b0), .injectdbiterr_axis(1'b0)
  );

  // -------------------------------------------------------------------------
  // Stage 0: Metadata Input buffer
  // -------------------------------------------------------------------------
  logic s0_fifo_full, s0_fifo_wr_en;
  st_metadata s0_meta_buff_din;

  logic s0_fifo_empty, s0_fifo_rd_en, s0_data_valid;
  st_metadata s0_meta_buff_dout;

  assign metadata_in_ready = !s0_fifo_full;
  assign s0_meta_buff_din  = metadata_in;
  assign s0_fifo_wr_en     = metadata_in_valid;

  xpm_fifo_sync #(
    .DOUT_RESET_VALUE("0"), .ECC_MODE("no_ecc"), .FIFO_MEMORY_TYPE("auto"),
    .FIFO_READ_LATENCY(1), .FIFO_WRITE_DEPTH(PIPELINE_FIFO_DEPTH), 
    .WRITE_DATA_WIDTH($bits(st_metadata)), .READ_DATA_WIDTH($bits(st_metadata)), .READ_MODE("fwft")
  ) s0_fifo (
      .wr_clk(clk), .rst(!rstn), .din(s0_meta_buff_din), .wr_en(s0_fifo_wr_en), .full(s0_fifo_full),
      .dout(s0_meta_buff_dout), .rd_en(s0_fifo_rd_en), .data_valid(s0_data_valid), .empty(s0_fifo_empty)
  );

  // -------------------------------------------------------------------------
  // Stage 1: Hash Calculation & Key Read Issue
  // -------------------------------------------------------------------------
  logic s1_fifo_full, s1_fifo_wr_en;
  s1_data_t s1_buff_din;
  logic [NUM_FUNCTIONS-1:0] ar_valid_reg;

  logic s1_fifo_empty, s1_fifo_rd_en, s1_data_valid;
  s1_data_t s1_buff_dout;

  assign s0_fifo_rd_en = ~s1_fifo_full && ~(|ar_valid_reg);
  for (genvar i = 0; i < NUM_FUNCTIONS; i++) assign m_axi_arvalid[i] = ar_valid_reg[i];   

  always_ff @(posedge clk) begin : s1_ff
    if (!rstn) begin
      ar_valid_reg  <= '0;
      s1_fifo_wr_en <= 1'b0;
    end else begin
      s1_fifo_wr_en <= 1'b0; 
      
        if (!s0_fifo_empty && s0_fifo_rd_en) begin
            for (int i = 0; i < NUM_FUNCTIONS; i++) s1_buff_din.addresses[i] <= hash(s0_meta_buff_dout.key, HASH_MATRIX[i]);
            s1_buff_din.meta <= s0_meta_buff_dout;
            s1_fifo_wr_en    <= 1'b1; 

            for (int i = 0; i < NUM_FUNCTIONS; i++) begin
                m_axi_araddr[i]   <= hash(s0_meta_buff_dout.key, HASH_MATRIX[i]) << ADDRESS_SHIFT;
                ar_valid_reg[i]   <= '1;
                m_axi_arburst[i]  <= 2'b1; 
                m_axi_arcache[i]  <= 4'b0; 
                m_axi_arprot[i]   <= 3'b0;  
                m_axi_arid[i]     <= '1;   
                m_axi_arlen[i]    <= 4'b0; 
                m_axi_arlock[i]   <= 2'b0;    
                m_axi_arsize[i]   <= 3'b100;  
            end
        end else begin
            for (int i=0; i<NUM_FUNCTIONS; i++) if (m_axi_arready[i] && ar_valid_reg[i]) ar_valid_reg[i] <= 1'b0;
      end
    end
  end : s1_ff

  xpm_fifo_sync #(
    .DOUT_RESET_VALUE("0"), .ECC_MODE("no_ecc"), .FIFO_MEMORY_TYPE("auto"),
    .FIFO_READ_LATENCY(1), .FIFO_WRITE_DEPTH(PIPELINE_FIFO_DEPTH), 
    .WRITE_DATA_WIDTH($bits(s1_data_t)), .READ_DATA_WIDTH($bits(s1_data_t)), .READ_MODE("fwft")
  ) s1_fifo (
    .wr_clk(clk), .rst(!rstn), .din(s1_buff_din), .wr_en(s1_fifo_wr_en), .full(s1_fifo_full),
    .dout(s1_buff_dout), .rd_en(s1_fifo_rd_en), .data_valid(s1_data_valid), .empty(s1_fifo_empty)
  );

  // -------------------------------------------------------------------------
  // Stage 2: Key Read Response & Split into Read/Write paths
  // -------------------------------------------------------------------------
  logic [NUM_FUNCTIONS -1:0]  r_valid_reg ;
  logic [31:0]                r_dirty_reg [NUM_FUNCTIONS];
  logic [KEY_WIDTH-1:0]       r_keys_reg  [NUM_FUNCTIONS];
  logic [HASH_WIDTH-1:0]      current_addresses [NUM_FUNCTIONS];

  // Stage 2 READ Queue
  logic s2_rd_fifo_full, s2_rd_fifo_wr_en, s2_rd_fifo_empty, s2_rd_fifo_rd_en;
  s2_data_t s2_rd_buff_din, s2_rd_buff_dout;
  
  // Stage 2 WRITE Queue
  logic s2_wr_fifo_full, s2_wr_fifo_wr_en, s2_wr_fifo_empty, s2_wr_fifo_rd_en;
  s2_data_t s2_wr_buff_din, s2_wr_buff_dout;

  logic all_reads_returned;
  assign all_reads_returned = (&r_valid_reg);

  logic s2_read_op;
  logic [HASH_WIDTH-1:0] s2_target_addr;
  logic s2_collision;

  logic s2_target_full;
  assign s2_target_full = s2_read_op ? s2_rd_fifo_full : s2_wr_fifo_full;

  always_ff @(posedge clk) begin : s2_ff
    if (!rstn) begin
      r_valid_reg      <= '0; 
      s2_rd_fifo_wr_en <= 1'b0; 
      s2_wr_fifo_wr_en <= 1'b0;
      s1_fifo_rd_en    <= 1'b0;
    end else begin
      if (!all_reads_returned) begin
          for (int i = 0; i < NUM_FUNCTIONS; i++) begin
              if (m_axi_rvalid[i] && m_axi_rready[i]) begin
                r_valid_reg[i] <= 1'b1;
                r_dirty_reg[i] <= m_axi_rdata[i][31:0];
                r_keys_reg[i]  <= {<< 8 {m_axi_rdata[i][32+:KEY_WIDTH]}};
              end
          end
      end

      if (all_reads_returned) begin
          s1_fifo_rd_en <= 1'b1; 
          r_valid_reg   <= '0;
      end

      if (s1_fifo_rd_en && !s1_fifo_empty) begin
          s1_fifo_rd_en <= 1'b0;
          if (s2_read_op) begin
              s2_rd_buff_din.meta           <= s1_buff_dout.meta;
              s2_rd_buff_din.target_address <= s2_target_addr;
              s2_rd_buff_din.invalid_target <= s2_collision;
              s2_rd_fifo_wr_en              <= 1'b1;
          end else begin
              s2_wr_buff_din.meta           <= s1_buff_dout.meta;
              s2_wr_buff_din.target_address <= s2_target_addr;
              s2_wr_buff_din.invalid_target <= s2_collision;
              s2_wr_fifo_wr_en              <= 1'b1;
          end
      end
      
      if (s2_rd_fifo_wr_en && !s2_rd_fifo_full) s2_rd_fifo_wr_en <= 1'b0;
      if (s2_wr_fifo_wr_en && !s2_wr_fifo_full) s2_wr_fifo_wr_en <= 1'b0;
    end
  end : s2_ff

  always_comb begin : s2_comb
    s2_read_op = (s1_buff_dout.meta.opcode == metadata_pkg::READ);
    for (int i = 0; i < NUM_FUNCTIONS; i++) current_addresses[i] = s1_buff_dout.addresses[i];
    
    if (no_collisions(s2_read_op, r_dirty_reg, r_keys_reg, current_addresses, s1_buff_dout.meta.key, s2_target_addr)) begin
      s2_collision = 1'b0;
    end else begin
      s2_collision = 1'b1; 
      s2_target_addr = '0;
    end
  end : s2_comb
  
  always_comb begin : s2_rready
    for (int i = 0; i < NUM_FUNCTIONS; i++) m_axi_rready[i] = (all_reads_returned || s2_target_full) ? 1'b0 : 1'b1; 
  end : s2_rready

  // -------------------------------------------------------------------------
  // Inter-Stage Buffers (Stage 2 -> Stage 3)
  // -------------------------------------------------------------------------

  xpm_fifo_sync #(
    .DOUT_RESET_VALUE("0"), .ECC_MODE("no_ecc"), .FIFO_MEMORY_TYPE("auto"),
    .FIFO_READ_LATENCY(1), .FIFO_WRITE_DEPTH(PIPELINE_FIFO_DEPTH), 
    .WRITE_DATA_WIDTH($bits(s2_data_t)), .READ_DATA_WIDTH($bits(s2_data_t)), .READ_MODE("fwft")
  ) s2_rd_fifo (
    .wr_clk(clk), .rst(!rstn), .din(s2_rd_buff_din), .wr_en(s2_rd_fifo_wr_en), .full(s2_rd_fifo_full),
    .dout(s2_rd_buff_dout), .rd_en(s2_rd_fifo_rd_en), .empty(s2_rd_fifo_empty)
  );

  xpm_fifo_sync #(
    .DOUT_RESET_VALUE("0"), .ECC_MODE("no_ecc"), .FIFO_MEMORY_TYPE("auto"),
    .FIFO_READ_LATENCY(1), .FIFO_WRITE_DEPTH(PIPELINE_FIFO_DEPTH), 
    .WRITE_DATA_WIDTH($bits(s2_data_t)), .READ_DATA_WIDTH($bits(s2_data_t)), .READ_MODE("fwft")
  ) s2_wr_fifo (
    .wr_clk(clk), .rst(!rstn), .din(s2_wr_buff_din), .wr_en(s2_wr_fifo_wr_en), .full(s2_wr_fifo_full),
    .dout(s2_wr_buff_dout), .rd_en(s2_wr_fifo_rd_en), .empty(s2_wr_fifo_empty)
  );

  // -------------------------------------------------------------------------
  // Stage 3 READ ISSUE
  // -------------------------------------------------------------------------

  logic s3_rd_fifo_full, s3_rd_fifo_wr_en, s3_rd_fifo_empty, s3_rd_fifo_rd_en;
  s2_data_t s3_rd_buff_din, s3_rd_buff_dout;
  
  logic s3_wr_fifo_full, s3_wr_fifo_wr_en, s3_wr_fifo_empty, s3_wr_fifo_rd_en;
  s2_data_t s3_wr_buff_din, s3_wr_buff_dout;


  typedef enum logic [1:0] { S3_RD_IDLE, S3_RD_CMD, S3_RD_MISS_DONE } s3_rd_state_e;
  s3_rd_state_e s3_rd_state, s3_rd_state_next;
  s2_data_t s3_rd_op, s3_rd_op_next;

  logic s3_rd_meta_out_valid;
  logic s4_wr_meta_out_valid; // Forward declaration for arbiter
  logic s4_rd_meta_out_valid; // Forward declaration for arbiter

  always_ff @(posedge clk) begin : s3_rd_ff
    if (!rstn) begin
      s3_rd_state <= S3_RD_IDLE;
      s3_rd_op    <= '0;
    end else begin
      s3_rd_state <= s3_rd_state_next;
      s3_rd_op    <= s3_rd_op_next;
    end
  end : s3_rd_ff

  always_comb begin : s3_rd_fsm
    s3_rd_state_next          = s3_rd_state;
    s3_rd_op_next             = s3_rd_op;
    s2_rd_fifo_rd_en          = 1'b0;
    
    m_axis_dm_mm2s_cmd_tvalid = 1'b0;
    m_axis_dm_mm2s_cmd_tdata  = {8'b0, 6'b0, s3_rd_op.target_address, 10'h0, 1'b0, 1'b1, 6'b0, 1'b1, DM_BTT};
    
    s3_rd_fifo_wr_en          = 1'b0; 
    s3_rd_buff_din            = s3_rd_op;
    s3_rd_meta_out_valid      = 1'b0;

    case (s3_rd_state)
      S3_RD_IDLE: begin
        if (!s2_rd_fifo_empty) begin
          s3_rd_op_next    = s2_rd_buff_dout;
          s2_rd_fifo_rd_en = 1'b1;
          
          if (s2_rd_buff_dout.invalid_target) begin
             s3_rd_state_next = S3_RD_MISS_DONE; 
          end else begin
             s3_rd_state_next = S3_RD_CMD;
          end
        end
      end

      S3_RD_CMD: begin
        m_axis_dm_mm2s_cmd_tvalid = 1'b1;
        if (m_axis_dm_mm2s_cmd_tready && !s3_rd_fifo_full) begin
          s3_rd_fifo_wr_en  = 1'b1;
          s3_rd_state_next  = S3_RD_IDLE;
        end
      end

      S3_RD_MISS_DONE: begin
        // Yield priority to S4 outputting metadata
        if (!s4_wr_meta_out_valid && !s4_rd_meta_out_valid) begin
           s3_rd_meta_out_valid = 1'b1;
           s3_rd_state_next     = S3_RD_IDLE;
        end
      end
    endcase
  end : s3_rd_fsm

  // -------------------------------------------------------------------------
  // Stage 3 WRITE ISSUE
  // -------------------------------------------------------------------------
  typedef enum logic [1:0] { S3_WR_IDLE, S3_WR_CMD, S3_WR_SINK_CMD } s3_wr_state_e;
  s3_wr_state_e s3_wr_state, s3_wr_state_next;
  s2_data_t s3_wr_op, s3_wr_op_next;

  always_ff @(posedge clk) begin : s3_wr_ff
    if (!rstn) begin
      s3_wr_state <= S3_WR_IDLE;
      s3_wr_op    <= '0;
    end else begin
      s3_wr_state <= s3_wr_state_next;
      s3_wr_op    <= s3_wr_op_next;
    end
  end : s3_wr_ff
  always_comb begin : s3_wr_fsm
    s3_wr_state_next          = s3_wr_state;
    s3_wr_op_next             = s3_wr_op;
    s2_wr_fifo_rd_en          = 1'b0;
    
    m_axis_dm_s2mm_cmd_tvalid = 1'b0;
    m_axis_dm_s2mm_cmd_tdata  = {8'b0, 6'b0, s3_wr_op.target_address, 10'h0, 1'b0, 1'b1, 6'b0, 1'b1, DM_BTT};
    
    s3_wr_fifo_wr_en          = 1'b0; 
    s3_wr_buff_din            = s3_wr_op;

    case (s3_wr_state)
      S3_WR_IDLE: begin
        if (!s2_wr_fifo_empty) begin
          s3_wr_op_next    = s2_wr_buff_dout;
          s2_wr_fifo_rd_en = 1'b1;
          
          if (s2_wr_buff_dout.invalid_target) begin
             s3_wr_state_next = S3_WR_SINK_CMD;
          end else begin
             s3_wr_state_next = S3_WR_CMD;
          end
        end
      end

      S3_WR_CMD: begin
        m_axis_dm_s2mm_cmd_tvalid = 1'b1;
        if (m_axis_dm_s2mm_cmd_tready && !s3_wr_fifo_full) begin
          s3_wr_fifo_wr_en  = 1'b1;
          s3_wr_state_next  = S3_WR_IDLE;
        end
      end

      S3_WR_SINK_CMD: begin
        if (!s3_wr_fifo_full) begin
          s3_wr_fifo_wr_en  = 1'b1;
          s3_wr_state_next  = S3_WR_IDLE;
        end
      end
    endcase
  end : s3_wr_fsm

  // -------------------------------------------------------------------------
  // Inter-Stage Buffers (Stage 3 -> Stage 4)
  // -------------------------------------------------------------------------

  xpm_fifo_sync #(
    .FIFO_WRITE_DEPTH(PIPELINE_FIFO_DEPTH), 
    .WRITE_DATA_WIDTH($bits(s2_data_t)), 
    .READ_DATA_WIDTH($bits(s2_data_t)), 
    .READ_MODE("fwft")) s3_rd_fifo (
    .wr_clk(clk), .rst(!rstn), .din(s3_rd_buff_din), 
    .wr_en(s3_rd_fifo_wr_en), .full(s3_rd_fifo_full), 
    .dout(s3_rd_buff_dout), .rd_en(s3_rd_fifo_rd_en), 
    .empty(s3_rd_fifo_empty)
  );

  xpm_fifo_sync #(
    .FIFO_WRITE_DEPTH(PIPELINE_FIFO_DEPTH), 
    .WRITE_DATA_WIDTH($bits(s2_data_t)), 
    .READ_DATA_WIDTH($bits(s2_data_t)), 
    .READ_MODE("fwft")) s3_wr_fifo (
    .wr_clk(clk), .rst(!rstn), .din(s3_wr_buff_din), 
    .wr_en(s3_wr_fifo_wr_en), .full(s3_wr_fifo_full), 
    .dout(s3_wr_buff_dout), .rd_en(s3_wr_fifo_rd_en), 
    .empty(s3_wr_fifo_empty)
  );

  // -------------------------------------------------------------------------
  // Stage 4 Read FSM: DataMover Output -> Read Buffer
  // -------------------------------------------------------------------------
  typedef enum logic [1:0] { S4_RD_IDLE, S4_RD_DATA, S4_RD_DONE } stage4_rd_state_e;
  stage4_rd_state_e s4_rd_state, s4_rd_state_next;
  s2_data_t s4_rd_op, s4_rd_op_next;
  
  logic rd_stream_done, rd_stream_done_next;

  always_ff @(posedge clk) begin : s4_rd_ff
    if (!rstn) begin
      s4_rd_state    <= S4_RD_IDLE;
      s4_rd_op       <= '0;
      rd_stream_done <= 1'b0;
    end else begin
      s4_rd_state    <= s4_rd_state_next;
      s4_rd_op       <= s4_rd_op_next;
      rd_stream_done <= rd_stream_done_next;
    end
  end : s4_rd_ff

  always_comb begin : s4_rd_fsm
    s4_rd_state_next     = s4_rd_state;
    s4_rd_op_next        = s4_rd_op;
    rd_stream_done_next  = rd_stream_done;
    
    s4_rd_meta_out_valid = 1'b0;
    s3_rd_fifo_rd_en     = 1'b0;

    int_rd_tvalid    = 1'b0; 
    int_rd_tdata     = '0; 
    int_rd_tkeep     = '0; 
    int_rd_tlast     = 1'b0;
    s_axis_dm_tready = 1'b0;

    if (s4_rd_state == S4_RD_DATA) begin
      int_rd_tvalid    = s_axis_dm_tvalid; 
      int_rd_tdata     = s_axis_dm_tdata; 
      int_rd_tkeep     = s_axis_dm_tkeep; 
      int_rd_tlast     = s_axis_dm_tlast;
      s_axis_dm_tready = int_rd_tready;
    end

    case (s4_rd_state)
      S4_RD_IDLE: begin
        rd_stream_done_next = 1'b0;
        if (!s3_rd_fifo_empty) begin
            s4_rd_op_next    = s3_rd_buff_dout; // Store operation into register
            s3_rd_fifo_rd_en = 1'b1;            // Pop FIFO immediately
            s4_rd_state_next = S4_RD_DATA;
        end
      end

      S4_RD_DATA: begin
        if (s_axis_dm_tvalid && s_axis_dm_tready && s_axis_dm_tlast) rd_stream_done_next = 1'b1;

        if (rd_stream_done || (s_axis_dm_tvalid && s_axis_dm_tready && s_axis_dm_tlast)) begin
          s4_rd_state_next = S4_RD_DONE;
        end
      end

      S4_RD_DONE: begin
        // Yield priority to S4_WR if it is also outputting on this exact clock cycle
        if (!s4_wr_meta_out_valid) begin
           s4_rd_meta_out_valid = 1'b1;
           s4_rd_state_next     = S4_RD_IDLE;
        end
      end
    endcase
  end : s4_rd_fsm

  // -------------------------------------------------------------------------
  // Stage 4 Write/Sink FSM: Write Buffer -> DataMover 
  // -------------------------------------------------------------------------
  typedef enum logic [1:0] { S4_WR_IDLE, S4_WR_DATA, S4_WR_SINK, S4_WR_DONE } stage4_wr_state_e;
  stage4_wr_state_e s4_wr_state, s4_wr_state_next;
  s2_data_t s4_wr_op, s4_wr_op_next;

  always_ff @(posedge clk) begin : s4_wr_ff
    if (!rstn) begin
      s4_wr_state <= S4_WR_IDLE;
      s4_wr_op    <= '0;
    end else begin
      s4_wr_state <= s4_wr_state_next;
      s4_wr_op    <= s4_wr_op_next;
    end
  end : s4_wr_ff

  logic s4_wr_int_wr_tready;

  always_comb begin : s4_wr_fsm
    s4_wr_state_next     = s4_wr_state;
    s4_wr_op_next        = s4_wr_op;
    s4_wr_int_wr_tready  = 1'b0;
    
    s4_wr_meta_out_valid = 1'b0;
    s3_wr_fifo_rd_en     = 1'b0;

    m_axis_dm_tvalid = 1'b0; 
    m_axis_dm_tdata  = '0; 
    m_axis_dm_tkeep  = '0; 
    m_axis_dm_tlast  = 1'b0;

    if (s4_wr_state == S4_WR_DATA) begin
      m_axis_dm_tvalid    = int_wr_tvalid; 
      m_axis_dm_tdata     = int_wr_tdata; 
      m_axis_dm_tkeep     = int_wr_tkeep; 
      m_axis_dm_tlast     = int_wr_tlast;
      s4_wr_int_wr_tready = m_axis_dm_tready;
    end else if (s4_wr_state == S4_WR_SINK) begin
      s4_wr_int_wr_tready = 1'b1; // Sink
    end

    case (s4_wr_state)
      S4_WR_IDLE: begin
        if (!s3_wr_fifo_empty) begin
            s4_wr_op_next    = s3_wr_buff_dout; // Store operation into register
            s3_wr_fifo_rd_en = 1'b1;            // Pop FIFO immediately
            
            if (s3_wr_buff_dout.invalid_target) s4_wr_state_next = S4_WR_SINK;
            else s4_wr_state_next = S4_WR_DATA;
        end
      end

      S4_WR_DATA: begin
        if (int_wr_tvalid && m_axis_dm_tready && int_wr_tlast) s4_wr_state_next = S4_WR_DONE;
      end

      S4_WR_SINK: begin
        if (int_wr_tvalid && int_wr_tready && int_wr_tlast) s4_wr_state_next = S4_WR_DONE;
      end

      S4_WR_DONE: begin
        // S4_WR acts as Highest Priority on the metadata out bus
        s4_wr_meta_out_valid = 1'b1;
        s4_wr_state_next     = S4_WR_IDLE;
      end
    endcase
  end : s4_wr_fsm

  // -------------------------------------------------------------------------
  // Mux shared outputs from the parallel Stage 4 FSMs
  // -------------------------------------------------------------------------
  assign int_wr_tready      = s4_wr_int_wr_tready;
  assign metadata_out_valid = s4_wr_meta_out_valid | s4_rd_meta_out_valid | s3_rd_meta_out_valid;

  // Metadata Output Bus Arbiter 
  // Priority order: S4_WR > S4_RD > S3_RD_MISS
  always_comb begin : meta_out_arbiter
    metadata_out = '0;
    if (s4_wr_meta_out_valid) begin
        metadata_out = s4_wr_op.meta;
        if (s4_wr_op.invalid_target) metadata_out.opcode = OUT_OF_MEM;
    end else if (s4_rd_meta_out_valid) begin
        metadata_out = s4_rd_op.meta;
    end else if (s3_rd_meta_out_valid) begin
        metadata_out        = s3_rd_op.meta;
        metadata_out.opcode = READ_NOT_FOUND;
    end
  end : meta_out_arbiter

  `ifdef __simulation__

    // -------------------------------------------------------------------------
    // Pipeline Stage Debugging
    // -------------------------------------------------------------------------

    int s0_count, s1_count;
    int s2_rd_count, s2_wr_count;
    int s3_rd_count, s3_wr_count;
    int wr_fifo_count; 

    always @(posedge clk) begin
      if(!rstn) begin
        s0_count      <= 0;
        s1_count      <= 0;
        s2_rd_count   <= 0;
        s2_wr_count   <= 0;
        s3_rd_count   <= 0;
        s3_wr_count   <= 0;
        wr_fifo_count <= 0;
      end else begin
        if (metadata_in_valid && metadata_in_ready) s0_count++;
        if (!s0_fifo_empty && s0_fifo_rd_en) s0_count--;

        if (!s1_fifo_full && s1_fifo_wr_en) s1_count++;
        if (!s1_fifo_empty && s1_fifo_rd_en) s1_count--;

        if (!s2_rd_fifo_full && s2_rd_fifo_wr_en) s2_rd_count++;
        if (!s2_rd_fifo_empty && s2_rd_fifo_rd_en) s2_rd_count--;
        
        if (!s2_wr_fifo_full && s2_wr_fifo_wr_en) s2_wr_count++;
        if (!s2_wr_fifo_empty && s2_wr_fifo_rd_en) s2_wr_count--;

        if (!s3_rd_fifo_full && s3_rd_fifo_wr_en) s3_rd_count++;
        if (!s3_rd_fifo_empty && s3_rd_fifo_rd_en) s3_rd_count--;

        if (!s3_wr_fifo_full && s3_wr_fifo_wr_en) s3_wr_count++;
        if (!s3_wr_fifo_empty && s3_wr_fifo_rd_en) s3_wr_count--;

        if (s_axis_tvalid && s_axis_tready && s_axis_tlast) wr_fifo_count++;
        if (int_wr_tvalid && int_wr_tready && int_wr_tlast) wr_fifo_count--;
      end
    end

    initial begin
    $monitor(
      "Time=%0t | \n"                                      , $time,
      "--- INPUT BUFFERS ---\n"                            ,
      "wr_fifo_occupancy_counter=%d \n"                            , wr_fifo_count,
      "--- STAGE 1 ---\n"                                  ,
      "s0_occupancy_counter=%d \n"                         , s0_count,
      "s0_fifo_empty=%b s0_fifo_rd_en=%b s0_data_valid=%b s0_buff_dout=%p \n", s0_fifo_empty, s0_fifo_rd_en, s0_data_valid, s0_meta_buff_dout,
      "ar_valid_reg=%b \n"                                 , ar_valid_reg,
      "s1_fifo_full=%b s1_fifo_wr_en=%b s1_buff_din=%p \n" , s1_fifo_full, s1_fifo_wr_en, s1_buff_din,
      "--- STAGE 2 ---\n"                                  ,
      "s1_occupancy_counter=%d \n"                         , s1_count,
      "s1_fifo_empty=%b s1_fifo_rd_en=%b s1_data_valid=%b s1_buff_dout=%p \n", s1_fifo_empty, s1_fifo_rd_en, s1_data_valid, s1_buff_dout,
      "r_valid_reg=%b r_dirty_reg=%p r_keys_reg=%p \n"     , r_valid_reg, r_dirty_reg, r_keys_reg,
      "current_addresses=%p all_reads_returned=%b \n"      , current_addresses, all_reads_returned,
      "s2_read_op=%b s2_target_addr=%h s2_collision=%b \n" , s2_read_op, s2_target_addr, s2_collision,
      "--- STAGE 3 (Parallel Command Issuance) ---\n"      ,
      "s2_rd_count=%d s2_wr_count=%d \n"                   , s2_rd_count, s2_wr_count,                               
      "s3_rd_state=%p s3_wr_state=%p \n"                   , s3_rd_state, s3_wr_state,
      "mm2s_cmd_tvalid=%b s2mm_cmd_tvalid=%b \n"           , m_axis_dm_mm2s_cmd_tvalid, m_axis_dm_s2mm_cmd_tvalid,
      "--- STAGE 4 (Parallel Data Streams) ---\n"          ,
      "s3_rd_count=%d s3_wr_count=%d \n"                   , s3_rd_count, s3_wr_count,
      "s4_rd_state=%p s4_wr_state=%p \n"                   , s4_rd_state, s4_wr_state,
      "rd_stream_done=%b \n"                               , rd_stream_done,
      "int_wr_tready=%b int_rd_tvalid=%b \n"               , int_wr_tready, int_rd_tvalid,
      "m_axis_dm_tvalid=%b s_axis_dm_tready=%b \n"         , m_axis_dm_tvalid, s_axis_dm_tready,
      "metadata_out_valid=%b metadata_out=%p \n"           , metadata_out_valid, metadata_out
    );
    end

    always @(posedge clk) begin
      if (s1_fifo_wr_en && !s1_fifo_full) begin
        $display("[%t] CUCKOO [HT: %d] STAGE 1 IN : Opcode=%0d, Key=0x%h", 
                 $time, THREAD, s1_buff_din.meta.opcode, s1_buff_din.meta.key);
      end
    end

    always @(posedge clk) begin
      if (s2_rd_fifo_wr_en && !s2_rd_fifo_full) begin
        $display("[%t] CUCKOO [HT: %d] STAGE 2 READ IN: Opcode=%0d, Key=0x%h", 
                 $time, THREAD, s2_rd_buff_din.meta.opcode, s2_rd_buff_din.meta.key);
      end
      if (s2_wr_fifo_wr_en && !s2_wr_fifo_full) begin
        $display("[%t] CUCKOO [HT: %d] STAGE 2 WRITE IN: Opcode=%0d, Key=0x%h", 
                 $time, THREAD, s2_wr_buff_din.meta.opcode, s2_wr_buff_din.meta.key);
      end
    end

    always @(posedge clk) begin
      if (s3_rd_state == S3_RD_IDLE && s3_rd_state_next != S3_RD_IDLE) begin
        $display("[%t] CUCKOO [HT: %d] STAGE 3 READ CMD : Opcode=%0d, Key=0x%h, Miss=%b", 
                 $time, THREAD, s2_rd_buff_dout.meta.opcode, s2_rd_buff_dout.meta.key, s2_rd_buff_dout.invalid_target);
      end
      if (s3_wr_state == S3_WR_IDLE && s3_wr_state_next != S3_WR_IDLE) begin
        $display("[%t] CUCKOO [HT: %d] STAGE 3 WRITE CMD: Opcode=%0d, Key=0x%h, SINK=%b", 
                 $time, THREAD, s2_wr_buff_dout.meta.opcode, s2_wr_buff_dout.meta.key, s2_wr_buff_dout.invalid_target);
      end
    end

    always @(posedge clk) begin
      if (s4_rd_state == S4_RD_IDLE && s4_rd_state_next != S4_RD_IDLE) begin
        $display("[%t] CUCKOO [HT: %d] STAGE 4 STARTING READ DATA", $time, THREAD);
      end
      if (s4_wr_state == S4_WR_IDLE && s4_wr_state_next != S4_WR_IDLE) begin
        if (s4_wr_state_next == S4_WR_SINK)
            $display("[%t] CUCKOO [HT: %d] STAGE 4 STARTING WRITE SINK", $time, THREAD);
        else
            $display("[%t] CUCKOO [HT: %d] STAGE 4 STARTING WRITE DATA", $time, THREAD);
      end
    end

    // Monitor s_axis interface
    always @(posedge clk) begin
      if (s_axis_tvalid && s_axis_tready) begin
        $display("[%t] CUCKOO [HT: %d] S_AXIS: data=0x%h, keep=0x%h, last=%b", $time, THREAD, s_axis_tdata, s_axis_tkeep, s_axis_tlast);
      end
    end

    // Monitor m_axis interface
    always @(posedge clk) begin
      if (m_axis_tvalid && m_axis_tready) begin
        $display("[%t] CUCKOO [HT: %d] M_AXIS: data=0x%h, keep=0x%h, last=%b", $time, THREAD, m_axis_tdata, m_axis_tkeep, m_axis_tlast);
      end
    end

    // Monitor metadata in
    always @(posedge clk) begin
      if (metadata_in_valid && metadata_in_ready) begin
        $display("[%t] CUCKOO [HT: %d] META_IN: opcode=%0d, key=0x%h", $time, THREAD, metadata_in.opcode, metadata_in.key);
      end
    end

    // Monitor metadata out
    always @(posedge clk) begin
      if (metadata_out_valid) begin
        $display("[%t] CUCKOO [HT: %d] META_OUT: opcode=%0d, key=0x%h", $time, THREAD, metadata_out.opcode, metadata_out.key);
      end
    end

    // Monitor s_axis_dm interface
    always @(posedge clk) begin
      if (s_axis_dm_tvalid && s_axis_dm_tready) begin
        $display("[%t] CUCKOO [HT: %d] S_AXIS_DM: data=0x%h, keep=0x%h, last=%b", $time, THREAD, s_axis_dm_tdata, s_axis_dm_tkeep, s_axis_dm_tlast);
      end
    end

    // Monitor m_axis_dm interface
    always @(posedge clk) begin
      if (m_axis_dm_tvalid && m_axis_dm_tready) begin
        $display("[%t] CUCKOO [HT: %d] M_AXIS_DM: data=0x%h, keep=0x%h, last=%b", $time, THREAD, m_axis_dm_tdata, m_axis_dm_tkeep, m_axis_dm_tlast);
      end
    end

    // Monitor Commands & AXI
    always @(posedge clk) begin
      if (m_axis_dm_mm2s_cmd_tvalid && m_axis_dm_mm2s_cmd_tready)
        $display("[%t] CUCKOO [HT: %d] MM2S CMD: cmd=0x%h addr=0x%h", $time, THREAD, m_axis_dm_mm2s_cmd_tdata, {s3_rd_op.target_address, 10'h0});
      if (m_axis_dm_s2mm_cmd_tvalid && m_axis_dm_s2mm_cmd_tready)
        $display("[%t] CUCKOO [HT: %d] S2MM CMD: cmd=0x%h addr=0x%h", $time, THREAD, m_axis_dm_s2mm_cmd_tdata, {s3_wr_op.target_address, 10'h0});

      for (int j = 0; j < NUM_FUNCTIONS; j++) begin
        if (m_axi_arvalid[j] && m_axi_arready[j])
          $display("[%t] CUCKOO [HT: %d] AXI AR[%0d]: addr=0x%h, len=0x%h, burst=0x%h", $time, THREAD, j, m_axi_araddr[j], m_axi_arlen[j], m_axi_arburst[j]);
        if (m_axi_rvalid[j] && m_axi_rready[j])
          $display("[%t] CUCKOO [HT: %d] AXI R[%0d]: data=0x%h, resp=0x%h", $time, THREAD, j, m_axi_rdata[j], m_axi_rresp[j]);
        if (m_axi_awvalid[j] && m_axi_awready[j])
          $display("[%t] CUCKOO [HT: %d] AXI AW[%0d]: addr=0x%h", $time, THREAD, j, m_axi_awaddr[j]);
        if (m_axi_wvalid[j] && m_axi_wready[j])
          $display("[%t] CUCKOO [HT: %d] AXI W[%0d]: data=0x%h", $time, THREAD, j, m_axi_wdata[j]);
        if (m_axi_bvalid[j] && m_axi_bready[j])
          $display("[%t] CUCKOO [HT: %d] AXI B[%0d]: resp=0x%h", $time, THREAD, j, m_axi_bresp[j]);
      end
    end

  `endif
endmodule