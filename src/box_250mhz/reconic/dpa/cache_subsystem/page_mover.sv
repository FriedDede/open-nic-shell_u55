`timescale 1ns / 1ps

module page_mover #(
    parameter ADDR_WIDTH    = 40,
    parameter DATA_WIDTH    = 512,
    parameter PAGE_SIZE     = 2*1024*1024,
    parameter MAX_BURST_LEN = 16            // max beats per AXI burst
)(
    input  logic                    aclk,
    input  logic                    aresetn,

    // ---------------------------------------------------------
    // Control Interface (from Cache Controller)
    // ---------------------------------------------------------
    input  logic                    i_start,      // Trigger copy
    input  logic [ADDR_WIDTH-1:0]   i_src_addr,  // 2MB aligned address
    input  logic [ADDR_WIDTH-1:0]   i_dst_addr,  // 2MB aligned address
    output logic                    o_done,       // Copy complete
    output logic                    o_idle,       // Module ready

    // ---------------------------------------------------------
    // AXI4 Master Read (Main Memory - Source)
    // ---------------------------------------------------------
    output logic [ADDR_WIDTH-1:0]   m_src_araddr,
    output logic [7:0]              m_src_arlen,   // Fixed to 255 (256 beats)
    output logic [2:0]              m_src_arsize,  // Fixed to 6 (64 bytes)
    output logic [1:0]              m_src_arburst, // INCR type
    output logic                    m_src_arvalid,
    input  logic                    m_src_arready,

    input  logic [DATA_WIDTH-1:0]   m_src_rdata,
    input  logic                    m_src_rvalid,
    output logic                    m_src_rready,
    input  logic                    m_src_rlast,

    // ---------------------------------------------------------
    // AXI4 Master Write (Cache Memory - Destination)
    // ---------------------------------------------------------
    output logic [ADDR_WIDTH-1:0]   m_dst_awaddr,
    output logic [7:0]              m_dst_awlen,
    output logic [2:0]              m_dst_awsize,
    output logic [1:0]              m_dst_awburst,
    output logic                    m_dst_awvalid,
    input  logic                    m_dst_awready,

    output logic [DATA_WIDTH-1:0]   m_dst_wdata,
    output logic [(DATA_WIDTH/8)-1:0]   m_dst_wstrb, // All 1s (Write full width)
    output logic                    m_dst_wlast,
    output logic                    m_dst_wvalid,
    input  logic                    m_dst_wready,

    input  logic [1:0]              m_dst_bresp,
    input  logic                    m_dst_bvalid,
    output logic                    m_dst_bready
);

    // Constants derived from 2MB page / 512-bit width
    localparam unsigned TOTAL_BEATS       = PAGE_SIZE / (DATA_WIDTH / 8);
    // A page wider than the data bus is moved as a burst: the whole page in
    // one burst when it fits MAX_BURST_LEN beats (e.g. 512B = 8 beats), else
    // in MAX_BURST_LEN-beat bursts. A 64B page is a single beat.
    localparam unsigned BURST_LEN         = (TOTAL_BEATS < MAX_BURST_LEN) ? TOTAL_BEATS : MAX_BURST_LEN;
    localparam unsigned TOTAL_BURSTS      = TOTAL_BEATS / BURST_LEN;
    localparam unsigned BYTES_PER_BURST   = BURST_LEN * (DATA_WIDTH/8);
    // FIFO holds one burst; at least 2 entries so the pointers stay >= 1 bit
    // wide and wrap onto the FIFO
    localparam unsigned FIFO_DEPTH        = (BURST_LEN < 2) ? 2 : BURST_LEN;
    localparam unsigned FIFO_PTR_WIDTH    = $clog2(FIFO_DEPTH);

    // ---------------------------------------------------------
    // Internal FIFO (Decoupler)
    // ---------------------------------------------------------
    // A simple FIFO to buffer data between Read and Write domains
    // Depth FIFO_DEPTH: pointers are log2(depth) wide so they wrap onto the
    // FIFO instead of indexing past it
    logic [DATA_WIDTH-1 :0]            fifo_data [FIFO_DEPTH -1 :0];
    logic [FIFO_PTR_WIDTH-1:0]         fifo_wr_ptr, fifo_rd_ptr;
    logic [$clog2(FIFO_DEPTH+1)-1:0]   fifo_count;
    logic                  fifo_full, fifo_empty;

    logic                  push, pop;
    logic                  w_load;   // move the FIFO head into the W output register
    logic [$clog2(FIFO_DEPTH+1)-1:0]   fifo_count_nxt;

    assign fifo_full  = (fifo_count == FIFO_DEPTH);
    assign fifo_empty = (fifo_count == 0);
    assign push       = m_src_rvalid && m_src_rready;
    assign pop        = w_load;   // FIFO head moves into the W output register

    // Occupancy after this cycle's push/pop, used to register RREADY
    always_comb begin
        fifo_count_nxt = fifo_count;
        if (push && !pop)      fifo_count_nxt = fifo_count + 1;
        else if (pop && !push) fifo_count_nxt = fifo_count - 1;
    end

    // FIFO storage: no reset, so aresetn stays out of the data registers'
    // enables (push needs m_src_rready, which is 0 during reset anyway)
    always_ff @(posedge aclk) begin
        if (push) fifo_data[fifo_wr_ptr] <= m_src_rdata;
    end

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            fifo_wr_ptr <= 0;
            fifo_rd_ptr <= 0;
            fifo_count  <= 0;
            m_src_rready <= 0;
        end else begin
            if (push) begin
                fifo_wr_ptr <= fifo_wr_ptr + 1;
            end
            if (pop) begin
                fifo_rd_ptr <= fifo_rd_ptr + 1;
            end
            
            fifo_count   <= fifo_count_nxt;
            // Registered RREADY: accept a beat next cycle only if the FIFO
            // will still have room for it
            m_src_rready <= (fifo_count_nxt != FIFO_DEPTH);
        end
    end

    // ---------------------------------------------------------
    // Main Control FSM
    // ---------------------------------------------------------
    // XFER covers the address and data phases of one burst together: AXI
    // forbids a master from waiting for AWREADY before asserting WVALID
    // (and axi_to_mem, behind the cache BRAM, only accepts AW together with
    // the first W beat), so AR, AW and W each complete independently.
    typedef enum logic [2:0] {
        IDLE,
        XFER,
        WAIT_BRESP,
        DONE
    } state_t;

    state_t state;
    
    // Counters
    logic unsigned [31:0]  burst_cnt;
    logic unsigned [31:0]  beat_cnt;  // beats of the current burst loaded into the W register
    logic unsigned [ADDR_WIDTH-1:0] current_src_addr;
    logic unsigned [ADDR_WIDTH-1:0] current_dst_addr;
    logic                  w_done;  // last W beat of the current burst sent
    logic                  w_loaded; // last beat of the current burst loaded into the W register
    logic                  aw_done_now, w_done_now;

    // ---------------------------------------------------------
    // AXI Assignments
    // ---------------------------------------------------------
    // Constant / Passthrough signals
    assign m_src_arlen      = BURST_LEN - 1; // AXI is Len-1
    assign m_src_arsize     = 3'b110;        // 64 Bytes (512 bits)
    assign m_src_arburst    = 2'b01;         // INCR
    assign m_dst_awlen      = BURST_LEN - 1;
    assign m_dst_awsize     = 3'b110;
    assign m_dst_awburst    = 2'b01;
    assign m_dst_wstrb      = '1;          // Simplified: assume full width valid

    // Address Outputs
    assign m_src_araddr    = current_src_addr;
    assign m_dst_awaddr    = current_dst_addr;

    // Write Path Control (Dest)
    // WDATA/WVALID/WLAST come from an output register fed by the FIFO. It is
    // (re)loaded when empty or when its beat is being accepted, so a beat per
    // cycle still goes out under back-to-back WREADY.
    assign w_load = (state == XFER) && !w_loaded && !fifo_empty &&
                    (!m_dst_wvalid || m_dst_wready);

    always_ff @(posedge aclk) begin
        if (w_load) m_dst_wdata <= fifo_data[fifo_rd_ptr];
    end

    // Burst completion terms: already done, or completing this cycle
    assign aw_done_now = !m_dst_awvalid || m_dst_awready;
    assign w_done_now  = w_done || (m_dst_wvalid && m_dst_wready && m_dst_wlast);

    // ---------------------------------------------------------
    // Logic
    // ---------------------------------------------------------
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state               <= IDLE;
            burst_cnt           <= 0;
            beat_cnt            <= 0;
            w_done              <= 0;
            w_loaded            <= 0;
            m_dst_wvalid        <= 0;
            m_dst_wlast         <= 0;
            current_src_addr    <= 0;
            current_dst_addr    <= 0;
            m_src_arvalid       <= 0;
            m_dst_awvalid       <= 0;
            m_dst_bready        <= 0;
            o_done              <= 0;
            o_idle              <= 1;
        end else begin
            case (state)
                IDLE: begin
                    o_done <= 0;
                    o_idle <= 1;
                    if (i_start) begin
                        current_src_addr    <= i_src_addr;
                        current_dst_addr    <= i_dst_addr;
                        burst_cnt           <= 0;
                        beat_cnt            <= 0;
                        w_done              <= 0;
                        w_loaded            <= 0;
                        o_idle              <= 0;

                        m_src_arvalid   <= 1;
                        m_dst_awvalid   <= 1;

                        state               <= XFER;
                    end
                end

                XFER: begin
                    if (m_src_arready)   m_src_arvalid <= 0;
                    if (m_dst_awready)   m_dst_awvalid <= 0;

                    // W output register: load the next beat, or drain it
                    // once accepted; WLAST marks the last beat of the burst
                    if (w_load) begin
                        m_dst_wvalid <= 1;
                        m_dst_wlast  <= (beat_cnt == BURST_LEN - 1);
                        if (beat_cnt == BURST_LEN - 1) w_loaded <= 1;
                        else                           beat_cnt <= beat_cnt + 1;
                    end else if (m_dst_wready) begin
                        m_dst_wvalid <= 0;
                        m_dst_wlast  <= 0;
                    end

                    if (m_dst_wvalid && m_dst_wready && m_dst_wlast) w_done <= 1;

                    // Burst done once AW is accepted and the last W beat is
                    // sent (AR is implied: W data comes from the read)
                    if (aw_done_now && w_done_now) begin
                        state        <= WAIT_BRESP;
                        m_dst_bready <= 1; // Ready to accept write response
                    end
                end

                WAIT_BRESP: begin
                    // Wait for Write Confirmation (BVALID)
                    if (m_dst_bvalid) begin
                        m_dst_bready <= 0; // Deassert ready
                        
                        // Check if we need more bursts
                        if (burst_cnt == TOTAL_BURSTS - 1) begin
                            state <= DONE;
                        end else begin
                            // Prepare for next burst
                            burst_cnt    <= burst_cnt + 1;
                            current_src_addr <= current_src_addr + BYTES_PER_BURST;
                            current_dst_addr <= current_dst_addr + BYTES_PER_BURST;
                            beat_cnt         <= 0;
                            w_done           <= 0;
                            w_loaded         <= 0;

                            m_src_arvalid   <= 1;
                            m_dst_awvalid   <= 1;
                            state        <= XFER;
                        end
                    end
                end

                DONE: begin
                    o_done <= 1;
                    state  <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    // ---------------------------------------------------------
    // Assertions
    // ---------------------------------------------------------
    initial begin
        if (TOTAL_BURSTS > (2**$bits(burst_cnt) - 1)) begin
            $fatal(1, "TOTAL_BURSTS (%0d) exceeds max value holdable by burst_cnt (%0d). Increase burst_cnt width.",
                TOTAL_BURSTS, (2**$bits(burst_cnt) - 1));
        end
        if (TOTAL_BEATS < 1 || (TOTAL_BEATS % BURST_LEN) != 0) begin
            $fatal(1, "PAGE_SIZE (%0d) must be a non-zero multiple of the burst size (%0d bytes).",
                PAGE_SIZE, BYTES_PER_BURST);
        end
        if ((FIFO_DEPTH & (FIFO_DEPTH - 1)) != 0) begin
            $fatal(1, "FIFO_DEPTH (%0d) must be a power of 2 (FIFO pointers wrap on it).", FIFO_DEPTH);
        end
        if (BURST_LEN > (2**$bits(beat_cnt) - 1)) begin
            $fatal(1, "BURST_LEN (%0d) exceeds max value holdable by beat_cnt (%0d). Increase beat_cnt width.",
                BURST_LEN, (2**$bits(beat_cnt) - 1));
        end
    end
endmodule