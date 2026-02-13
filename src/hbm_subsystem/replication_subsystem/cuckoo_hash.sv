import metadata_pkg::*;

module cuckoo_hash # (
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

  input  logic                  s_axis_tvalid,
  input  logic [DATA_WIDTH-1:0] s_axis_tdata,
  input  logic [KEEP_WIDTH-1:0] s_axis_tkeep,
  input  logic                  s_axis_tuser,
  input  logic                  s_axis_tlast,
  output logic                  s_axis_tready,

  input  st_metadata            metadata_in,
  input  logic                  metadata_in_valid,

  output logic                  m_axis_tvalid,
  output logic [DATA_WIDTH-1:0] m_axis_tdata,
  output logic [KEEP_WIDTH-1:0] m_axis_tkeep,
  output logic                  m_axis_tuser,
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
  output logic  [CMD_WIDTH-1:0] m_axis_dm_mm2s_cmd_tdata,
  input  logic                  m_axis_dm_mm2s_cmd_tready,

  output logic                  m_axis_dm_s2mm_cmd_tvalid,
  output logic  [CMD_WIDTH-1:0] m_axis_dm_s2mm_cmd_tdata,
  input  logic                  m_axis_dm_s2mm_cmd_tready,

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
  localparam int FIFO_DEPTH       = 2 * BUCKET_SIZE * 8 / DATA_WIDTH;
  localparam int ADDRESS_SHIFT    = $clog2(BUCKET_SIZE);
  localparam int HASH_COUNT_WIDTH = $clog2(NUM_FUNCTIONS);
  localparam int KICK_COUNT_WIDTH = $clog2(MAX_KICKS);
  localparam logic [22:0] DM_BTT  = BUCKET_SIZE;

  logic                  axis_buffer_in_tvalid;
  logic [DATA_WIDTH-1:0] axis_buffer_in_tdata;
  logic [KEEP_WIDTH-1:0] axis_buffer_in_tkeep;
  logic                  axis_buffer_in_tlast;
  logic                  axis_buffer_in_tready;

  logic                  axis_buffer_out_tvalid;
  logic [DATA_WIDTH-1:0] axis_buffer_out_tdata;
  logic [KEEP_WIDTH-1:0] axis_buffer_out_tkeep;
  logic                  axis_buffer_out_tlast;
  logic                  axis_buffer_out_tready;

  xpm_fifo_axis #(
    .FIFO_DEPTH               (FIFO_DEPTH),
    .TDATA_WIDTH              (DATA_WIDTH)
  ) xpm_fifo_axis_inst (
    .m_axis_tvalid            (axis_buffer_out_tvalid),
    .m_axis_tready            (axis_buffer_out_tready),
    .m_axis_tdata             (axis_buffer_out_tdata),
    .m_axis_tkeep             (axis_buffer_out_tkeep),
    .m_axis_tdest             (),
    .m_axis_tid               (),
    .m_axis_tstrb             (),
    .m_axis_tuser             (),
    .m_axis_tlast             (axis_buffer_out_tlast),

    .s_axis_tvalid            (axis_buffer_in_tvalid),
    .s_axis_tready            (axis_buffer_in_tready),
    .s_axis_tdata             (axis_buffer_in_tdata),
    .s_axis_tkeep             (axis_buffer_in_tkeep),
    .s_axis_tdest             (1'b0),
    .s_axis_tid               (1'b0),
    .s_axis_tstrb             ('0),
    .s_axis_tuser             (1'b0),
    .s_axis_tlast             (axis_buffer_in_tlast),

    .injectsbiterr_axis       (1'b0),
    .injectdbiterr_axis       (1'b0),
    .m_aclk                   (clk),
    .s_aclk                   (clk),
    .s_aresetn                (rstn)
  );

  typedef enum logic [2:0] {IDLE, CHECK_READ, CHECK_WRITE, READ, WRITE, SWAP, RECHECK, ERROR} state_e;
  typedef enum logic [2:0] {BUF_IN_IDLE, BUF_IN_FILL, BUF_IN_FILL_FROM_DM, BUF_IN_DONE} buf_in_state_e;
  typedef enum logic [2:0] {BUF_OUT_IDLE, BUF_OUT_EMPTY, BUF_OUT_EMPTY_READ_CMD, BUF_OUT_EMPTY_TO_DM, BUF_OUT_DONE} buf_out_state_e;
  typedef enum logic [2:0] {DM_IDLE, DM_CMD_READ, DM_READ, DM_CMD_WRITE, DM_WRITE, DM_DONE} dm_state_e;
  typedef enum logic [2:0] {HBM_READ_IDLE, HBM_READ_ADDRESS, HBM_READ, HBM_READ_DONE} hbm_read_state_e;
  typedef enum logic [2:0] {HBM_WRITE_IDLE, HBM_WRITE_ADDRESS, HBM_WRITE, HBM_WRITE_DONE} hbm_write_state_e;

  state_e                       state,                              state_next;
  buf_in_state_e                buf_in_state,                       buf_in_state_next;
  buf_out_state_e               buf_out_state,                      buf_out_state_next;
  dm_state_e                    dm_state,                           dm_state_next;
  hbm_read_state_e              hbm_read_state [NUM_FUNCTIONS],     hbm_read_state_next [NUM_FUNCTIONS];
  hbm_write_state_e             hbm_write_state [NUM_FUNCTIONS],    hbm_write_state_next [NUM_FUNCTIONS];
  logic                  [31:0] stored_dirty [NUM_FUNCTIONS],       stored_dirty_next [NUM_FUNCTIONS];
  logic         [KEY_WIDTH-1:0] stored_keys [NUM_FUNCTIONS],        stored_keys_next [NUM_FUNCTIONS];
  logic        [HASH_WIDTH-1:0] current_addresses [NUM_FUNCTIONS],  current_addresses_next [NUM_FUNCTIONS];
  logic         [KEY_WIDTH-1:0] current_key,                        current_key_next;
  logic        [HASH_WIDTH-1:0] address,                            address_next;
  logic  [KICK_COUNT_WIDTH-1:0] kick_count,                         kick_count_next;

  logic start_hbm_read;
  logic start_hbm_write;
  logic start_dm_read;
  logic start_dm_write;
  logic start_dm_swap;
  logic start_buf_in;
  logic start_buf_in_from_dm;
  logic start_buf_out;
  logic start_buf_out_read_cmd;
  logic start_buf_out_to_dm;
  logic stop_hbm_read;
  logic stop_hbm_write;
  logic stop_dm;
  logic stop_buf_in;
  logic stop_buf_out;

  st_metadata metadata_buf, metadata_buf_next;

  function automatic logic [HASH_WIDTH-1:0] hash (
    input logic  [KEY_WIDTH-1:0] key,
    input logic [HASH_WIDTH-1:0] matrix [KEY_WIDTH-1:0]
  );
    logic [HASH_WIDTH-1:0] accumulator = '0;
    for (int i = 0; i < KEY_WIDTH; i = i + 1)
        if (key[i])
            accumulator ^= matrix[i];
    return accumulator;
  endfunction

  function automatic logic hbm_read_done (
    input hbm_read_state_e state [NUM_FUNCTIONS]
  );
    for (int i = 0; i < NUM_FUNCTIONS; i++)
      if (state[i] != HBM_READ_DONE)
        return 1'b0;
    return 1'b1;
  endfunction

  function automatic logic hbm_write_done (
    input hbm_write_state_e state [NUM_FUNCTIONS]
  );
    for (int i = 0; i < NUM_FUNCTIONS; i++)
      if (state[i] != HBM_WRITE_DONE)
        return 1'b0;
    return 1'b1;
  endfunction

  function automatic logic no_collisions (
    input  logic                  read,
    input  logic           [31:0] stored_dirty [NUM_FUNCTIONS],
    input  logic  [KEY_WIDTH-1:0] stored_keys [NUM_FUNCTIONS],
    input  logic [HASH_WIDTH-1:0] current_addresses [NUM_FUNCTIONS],
    input  logic  [KEY_WIDTH-1:0] current_key,
    output logic [HASH_WIDTH-1:0] address
  );
    logic read_possible;
    logic write_possible;
    for (int i = 0; i < NUM_FUNCTIONS; i++) begin
      read_possible = stored_dirty[i] == VALID_TAG && stored_keys[i] == current_key;
      write_possible = stored_dirty[i] != VALID_TAG || stored_keys[i] == current_key;
      if (read && read_possible || !read && write_possible) begin
        address = current_addresses[i];
        return 1'b1;
      end
    end
    address = '0;
    return 1'b0;
  endfunction

  always_ff @(posedge clk) begin :registers
    if (!rstn) begin
      state         <= IDLE;
      buf_in_state  <= BUF_IN_IDLE;
      buf_out_state <= BUF_OUT_IDLE;
      dm_state      <= DM_IDLE;
      current_key   <= '0;
      address       <= '0;
      kick_count    <= '0;
      metadata_buf  <= '0;
      for (int i = 0; i < NUM_FUNCTIONS; i++) begin
        hbm_read_state[i]     <= HBM_READ_IDLE;
        hbm_write_state[i]    <= HBM_WRITE_IDLE;
        stored_dirty[i]       <= '0;
        stored_keys[i]        <= '0;
        current_addresses[i]  <= '0;
      end
    end
    else begin
      state         <= state_next;
      buf_in_state  <= buf_in_state_next;
      buf_out_state <= buf_out_state_next;
      dm_state      <= dm_state_next;
      current_key   <= current_key_next;
      address       <= address_next;
      kick_count    <= kick_count_next;
      metadata_buf  <= metadata_buf_next;
      for (int i = 0; i < NUM_FUNCTIONS; i++) begin
        hbm_read_state[i]     <= hbm_read_state_next[i];
        hbm_write_state[i]    <= hbm_write_state_next[i];
        stored_dirty[i]       <= stored_dirty_next[i];
        stored_keys[i]        <= stored_keys_next[i];
        current_addresses[i]  <= current_addresses_next[i];
      end
    end
  end

  // Main state machine
  always_comb begin : main_fsm
    start_hbm_read          = 1'b0;
    start_hbm_write         = 1'b0;
    start_dm_read           = 1'b0;
    start_dm_write          = 1'b0;
    start_dm_swap           = 1'b0;
    start_buf_in            = 1'b0;
    start_buf_out           = 1'b0;
    start_buf_out_read_cmd  = 1'b0;
    stop_hbm_read           = 1'b0;
    stop_hbm_write          = 1'b0;
    stop_dm                 = 1'b0;
    stop_buf_in             = 1'b0;
    stop_buf_out            = 1'b0;
    state_next              = state;
    current_key_next        = current_key;
    current_addresses_next  = current_addresses;
    address_next            = address;
    kick_count_next         = kick_count;
    metadata_buf_next       = metadata_buf;
    metadata_out_valid      = 1'b0;
    metadata_out            = '0;
    for (int i = 0; i < NUM_FUNCTIONS; i++) begin
      current_addresses_next[i] = current_addresses_next[i];
    end
    case (state)
      IDLE: begin
        start_buf_in   = 1'b1;
        stop_buf_out   = 1'b1;
        stop_hbm_read  = 1'b1;
        stop_hbm_write = 1'b1;
        stop_dm        = 1'b1;
        if (metadata_in_valid) begin
          metadata_buf_next = metadata_in;
          if (metadata_in.opcode == metadata_pkg::READ)
            state_next = CHECK_READ;
          else
            state_next = CHECK_WRITE;
          current_key_next = metadata_in.key;
          for (int i = 0; i < NUM_FUNCTIONS; i++)
            current_addresses_next[i] = hash(current_key_next, HASH_MATRIX[i]);
        end
      end
      CHECK_READ: begin
        stop_buf_in            = 1'b1;
        start_buf_out_read_cmd = 1'b1;
        start_hbm_read         = 1'b1;
        if (hbm_read_done(hbm_read_state)) begin
          stop_buf_out = 1'b1;
          if (no_collisions(1'b1, stored_dirty, stored_keys, current_addresses, current_key, address_next))
            state_next = READ;
          else
            state_next = ERROR;
        end
      end
      CHECK_WRITE: begin
        start_hbm_read = 1'b1;
        if (hbm_read_done(hbm_read_state) && buf_in_state == BUF_IN_DONE)
          if (no_collisions(1'b0, stored_dirty, stored_keys, current_addresses, current_key, address_next))
            state_next = WRITE;
          else
            state_next = SWAP;
      end
      READ: begin
        stop_hbm_read         = 1'b1;
        stop_buf_in           = 1'b1;
        start_buf_out         = 1'b1;
        start_dm_read         = 1'b1;
        if (dm_state == DM_DONE) begin
          state_next = IDLE;
          // Assume meta fifo is not full
          metadata_out_valid = 1'b1;
          metadata_out       = metadata_buf;
        end
      end
      WRITE: begin
        stop_hbm_read         = 1'b1;
        stop_buf_in           = 1'b1;
        start_dm_write        = 1'b1;
        //start_hbm_write       = 1'b1;
        if (dm_state == DM_DONE/* && hbm_write_done(hbm_write_state)*/) begin
          state_next = IDLE;
          // Assume meta fifo is not full
          metadata_out_valid = 1'b1;
          metadata_out       = metadata_buf;
        end
      end
      SWAP: begin
        stop_hbm_read         = 1'b1;
        stop_buf_in           = 1'b1;
        start_dm_swap         = 1'b1;
        if (dm_state == DM_DONE) begin
          state_next       = RECHECK;
          kick_count_next  = kick_count + 1;
          current_key_next = stored_keys[kick_count];
          for (int i = 0; i < NUM_FUNCTIONS; i++)
            current_addresses_next[i] = hash(current_key_next, HASH_MATRIX[i]);
        end
      end
      RECHECK: begin
        stop_dm        = 1'b1;
        stop_buf_in    = 1'b1;
        stop_buf_out   = 1'b1;
        start_hbm_read = 1'b1;
        if (hbm_read_done(hbm_read_state))
          if (no_collisions(1'b0, stored_dirty, stored_keys, current_addresses, current_key, address_next))
            state_next = WRITE;
          else
            if (kick_count == MAX_KICKS - 1)
              state_next = ERROR;
            else
              state_next = SWAP;
      end
      ERROR: begin
        state_next = IDLE;
        // Assume meta fifo is not full
        metadata_out_valid  = 1'b1;
        metadata_out        = metadata_buf;
        metadata_out.opcode = READ_NOT_FOUND;
      end
    endcase
  end

  // Buffer state machine
  always_comb begin : xpm_fifo_fsm
    buf_in_state_next      = buf_in_state;
    buf_out_state_next     = buf_out_state;
    axis_buffer_in_tvalid  = 1'b0;
    axis_buffer_in_tdata   =   '0;
    axis_buffer_in_tkeep   =   '0;
    axis_buffer_in_tlast   = 1'b0;
    axis_buffer_out_tready = 1'b0;
    m_axis_tvalid          = 1'b0;
    m_axis_tdata           =   '0;
    m_axis_tkeep           =   '0;
    m_axis_tuser           = 1'b0;
    m_axis_tlast           = 1'b0;
    s_axis_tready          = 1'b0;
    m_axis_dm_tvalid       = 1'b0;
    m_axis_dm_tdata        =   '0;
    m_axis_dm_tkeep        =   '0;
    m_axis_dm_tlast        = 1'b0;
    s_axis_dm_tready       = 1'b0;
    case (buf_in_state)
      BUF_IN_IDLE: begin
        if (start_buf_in)
          buf_in_state_next = BUF_IN_FILL;
        if (start_buf_in_from_dm)
          buf_in_state_next = BUF_IN_FILL_FROM_DM;
      end
      BUF_IN_FILL: begin
        axis_buffer_in_tvalid = s_axis_tvalid;
        axis_buffer_in_tdata  = s_axis_tdata;
        axis_buffer_in_tkeep  = s_axis_tkeep;
        axis_buffer_in_tlast  = s_axis_tlast;
        s_axis_tready         = axis_buffer_in_tready;
        if (s_axis_tlast && s_axis_tvalid && s_axis_tready)
          buf_in_state_next = BUF_IN_DONE;
      end
      BUF_IN_FILL_FROM_DM: begin
        axis_buffer_in_tvalid = s_axis_dm_tvalid;
        axis_buffer_in_tdata  = s_axis_dm_tdata;
        axis_buffer_in_tkeep  = s_axis_dm_tkeep;
        axis_buffer_in_tlast  = s_axis_dm_tlast;
        s_axis_dm_tready      = axis_buffer_in_tready;
        if (s_axis_dm_tlast && s_axis_dm_tvalid && s_axis_dm_tready)
          buf_in_state_next = BUF_IN_DONE;
      end
      BUF_IN_DONE: begin
        if (stop_buf_in)
          buf_in_state_next = BUF_IN_IDLE;
      end
    endcase
    case (buf_out_state)
      BUF_OUT_IDLE: begin
        if (start_buf_out)
          buf_out_state_next = BUF_OUT_EMPTY;
        if (start_buf_out_read_cmd)
          buf_out_state_next = BUF_OUT_EMPTY_READ_CMD;
        if (start_buf_out_to_dm)
          buf_out_state_next = BUF_OUT_EMPTY_TO_DM;
      end
      BUF_OUT_EMPTY: begin
        m_axis_tvalid           = axis_buffer_out_tvalid;
        m_axis_tdata            = axis_buffer_out_tdata;
        m_axis_tkeep            = axis_buffer_out_tkeep;
        m_axis_tlast            = axis_buffer_out_tlast;
        axis_buffer_out_tready  = m_axis_tready;
        if (axis_buffer_out_tlast && axis_buffer_out_tvalid && axis_buffer_out_tready)
          buf_out_state_next = BUF_OUT_DONE;
      end
      // Used to remove the read request packet from the buffer
      BUF_OUT_EMPTY_READ_CMD: begin
        axis_buffer_out_tready  = 1'b1;
        if (axis_buffer_out_tlast && axis_buffer_out_tvalid && axis_buffer_out_tready)
          buf_out_state_next = BUF_OUT_DONE;
      end
      BUF_OUT_EMPTY_TO_DM: begin
        m_axis_dm_tvalid        = axis_buffer_out_tvalid;
        m_axis_dm_tdata         = axis_buffer_out_tdata;
        m_axis_dm_tkeep         = axis_buffer_out_tkeep;
        m_axis_dm_tlast         = axis_buffer_out_tlast;
        axis_buffer_out_tready  = m_axis_dm_tready;
        if (axis_buffer_out_tlast && axis_buffer_out_tvalid && axis_buffer_out_tready)
          buf_out_state_next = BUF_OUT_DONE;
      end
      BUF_OUT_DONE: begin
        if (stop_buf_out)
          buf_out_state_next = BUF_OUT_IDLE;
      end
    endcase
  end

  // Datamover state machine
  always_comb begin :datamover_fsm
    dm_state_next             = dm_state;
    start_buf_in_from_dm      = 1'b0;
    start_buf_out_to_dm       = 1'b0;
    m_axis_dm_s2mm_cmd_tvalid = 1'b0;
    m_axis_dm_s2mm_cmd_tdata  =   '0;
    m_axis_dm_mm2s_cmd_tvalid = 1'b0;
    m_axis_dm_mm2s_cmd_tdata  =   '0;
    case (dm_state)
      DM_IDLE: begin
        if (start_dm_read || start_dm_swap)
          dm_state_next = DM_CMD_READ;
        else if (start_dm_write)
          dm_state_next = DM_CMD_WRITE;
      end
      DM_CMD_READ: begin
        start_buf_in_from_dm = 1'b1;
        m_axis_dm_mm2s_cmd_tdata  = {8'b0, 6'b0, address, 10'h0, 1'b0, 1'b1, 6'b0, 1'b1, DM_BTT};
        m_axis_dm_mm2s_cmd_tvalid = 1'b1;
        if (m_axis_dm_mm2s_cmd_tready)
          if (start_dm_swap)
            dm_state_next = DM_CMD_WRITE;
          else
            dm_state_next = DM_READ;
      end
      DM_READ: begin
        if (buf_out_state == BUF_OUT_DONE)
          dm_state_next = DM_DONE;
      end
      DM_CMD_WRITE: begin
        start_buf_out_to_dm = 1'b1;
        m_axis_dm_s2mm_cmd_tdata  = {8'b0, 6'b0, address, 10'h0, 1'b0, 1'b1, 6'b0, 1'b1, DM_BTT};
        m_axis_dm_s2mm_cmd_tvalid = 1'b1;
        if (m_axis_dm_s2mm_cmd_tready)
          dm_state_next = DM_WRITE;
      end
      DM_WRITE: begin
        if (buf_out_state == BUF_OUT_DONE)
          if (start_dm_swap)
            dm_state_next = DM_READ;
          else
            dm_state_next = DM_DONE;
      end
      DM_DONE: begin
        if (stop_dm)
          dm_state_next = DM_IDLE;
      end
    endcase
  end

  // HBM state machine
  genvar i;
  generate
    for (i = 0; i < NUM_FUNCTIONS; i++) begin : hbm_parallel_fsm
      always_comb begin
        hbm_read_state_next[i]  = hbm_read_state[i];
        hbm_write_state_next[i] = hbm_write_state[i];
        stored_dirty_next[i]    = stored_dirty[i];
        stored_keys_next[i]     = stored_keys[i];
        m_axi_araddr[i]         =  64'b0;
        m_axi_arburst[i]        =   2'b1;    // Incrementing burst
        m_axi_arcache[i]        =   4'b0;    // Non-bufferable non-cacheable
        m_axi_arprot[i]         =   3'b0;    // Unpriviliged secure data
        m_axi_arid[i]           =   i;
        m_axi_arlen[i]          =   4'b0;    // 1 beat transfer
        m_axi_arlock[i]         =   2'b0;    // Normal accesses
        m_axi_arsize[i]         =   3'b100;  // 16 bytes transfer
        m_axi_arvalid[i]        =   1'b0;
        m_axi_awaddr[i]         =  64'b0;
        m_axi_awburst[i]        =   2'b1;    // Incrementing burst
        m_axi_awcache[i]        =   4'b0;    // Non-bufferable non-cacheable
        m_axi_awprot[i]         =   3'b0;    // Unpriviliged secure data
        m_axi_awid[i]           =   i;
        m_axi_awlen[i]          =   4'b0;    // 1 beat transfer
        m_axi_awlock[i]         =   2'b0;    // Normal accesses
        m_axi_awsize[i]         =   3'b010;  // 4 bytes transfer
        m_axi_awvalid[i]        =   1'b0;
        m_axi_bready[i]         =   1'b1;
        m_axi_rready[i]         =   1'b0;
        m_axi_wdata[i]          = 256'b0;
        m_axi_wlast[i]          =   1'b1;
        m_axi_wstrb[i]          =  32'b1;
        m_axi_wvalid[i]         =   1'b0;
        case (hbm_read_state[i])
          HBM_READ_IDLE: begin
            if (start_hbm_read)
              hbm_read_state_next[i] = HBM_READ_ADDRESS;
          end
          HBM_READ_ADDRESS: begin
            m_axi_araddr[i]   = current_addresses[i] << ADDRESS_SHIFT;
            m_axi_arvalid[i]  = 1'b1;
            if (m_axi_arready[i])
              hbm_read_state_next[i] = HBM_READ;
          end
          HBM_READ: begin
            m_axi_rready[i]   = 1'b1;
            if (m_axi_rvalid[i]) begin
              hbm_read_state_next[i]  = HBM_READ_DONE;
              stored_dirty_next[i]    = m_axi_rdata[i][31:0];
              stored_keys_next[i]     = {<< 8 {m_axi_rdata[i][32+:KEY_WIDTH]}};
            end
          end
          HBM_READ_DONE: begin
            if (stop_hbm_read)
              hbm_read_state_next[i] = HBM_READ_IDLE;
          end
        endcase
        case (hbm_write_state[i])
          // We only intend to write the dirty byte to the correct address
          HBM_WRITE_IDLE: begin
            if (start_hbm_write)
              if (address == current_addresses[i])
                hbm_write_state_next[i] = HBM_WRITE_ADDRESS;
              else
                hbm_write_state_next[i] = HBM_WRITE_DONE;
          end
          HBM_WRITE_ADDRESS: begin
            m_axi_awaddr[i]   = current_addresses[i] << ADDRESS_SHIFT;
            m_axi_awvalid[i]  = 1'b1;
            m_axi_wdata[i][0] = 1'b1;
            m_axi_wvalid[i]   = 1'b1;
            if (m_axi_awready[i]) begin
              hbm_write_state_next[i] = HBM_WRITE;
              if (m_axi_wready[i])
                hbm_write_state_next[i] = HBM_WRITE_DONE;
            end
          end
          HBM_WRITE: begin
            m_axi_wdata[i][0] = 1'b1;
            m_axi_wvalid[i]   = 1'b1;
            if (m_axi_wready[i])
              hbm_write_state_next[i] = HBM_WRITE_DONE;
          end
          HBM_WRITE_DONE: begin
            if (stop_hbm_write)
              hbm_write_state_next[i] = HBM_WRITE_IDLE;
          end
        endcase
      end
    end
  endgenerate

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
      if (m_axi_awvalid[j] && m_axi_awready[j])
        $display("[%t] CUCKOO [HT: %d] AXI AW[%0d]: addr=0x%h, len=0x%h, burst=0x%h", $time, THREAD, j, m_axi_awaddr[j], m_axi_awlen[j], m_axi_awburst[j]);
      if (m_axi_wvalid[j] && m_axi_wready[j])
        $display("[%t] CUCKOO [HT: %d] AXI W[%0d]: data=0x%h, strb=0x%h", $time, THREAD, j, m_axi_wdata[j], m_axi_wstrb[j]);
      if (m_axi_bvalid[j] && m_axi_bready[j])
        $display("[%t] CUCKOO [HT: %d] AXI B[%0d]: resp=0x%h", $time, THREAD, j, m_axi_bresp[j]);
    end
  end

`endif
endmodule
