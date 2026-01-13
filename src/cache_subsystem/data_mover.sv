`timescale 1ns / 1ps

module memory_mover #(
    parameter ADDR_WIDTH = 40,
    parameter DATA_WIDTH = 512
)(
    input  logic                    aclk,
    input  logic                    aresetn,

    // ---------------------------------------------------------
    // Control Interface (from Cache Controller)
    // ---------------------------------------------------------
    input  logic                    i_start,      // Trigger copy
    input  logic [ADDR_WIDTH-1:0]   i_page_addr,  // 2MB aligned address
    output logic                    o_done,       // Copy complete
    output logic                    o_idle,       // Module ready

    // ---------------------------------------------------------
    // AXI4 Master Read (Main Memory - Source)
    // ---------------------------------------------------------
    output logic [ADDR_WIDTH-1:0]   m_mem_araddr,
    output logic [7:0]              m_mem_arlen,   // Fixed to 255 (256 beats)
    output logic [2:0]              m_mem_arsize,  // Fixed to 6 (64 bytes)
    output logic [1:0]              m_mem_arburst, // INCR type
    output logic                    m_mem_arvalid,
    input  logic                    m_mem_arready,

    input  logic [DATA_WIDTH-1:0]   m_mem_rdata,
    input  logic                    m_mem_rvalid,
    output logic                    m_mem_rready,
    input  logic                    m_mem_rlast,

    // ---------------------------------------------------------
    // AXI4 Master Write (Cache Memory - Destination)
    // ---------------------------------------------------------
    output logic [ADDR_WIDTH-1:0]   m_cache_awaddr,
    output logic [7:0]              m_cache_awlen,
    output logic [2:0]              m_cache_awsize,
    output logic [1:0]              m_cache_awburst,
    output logic                    m_cache_awvalid,
    input  logic                    m_cache_awready,

    output logic [DATA_WIDTH-1:0]   m_cache_wdata,
    output logic                    m_cache_wstrb, // All 1s (Write full width)
    output logic                    m_cache_wlast,
    output logic                    m_cache_wvalid,
    input  logic                    m_cache_wready,

    input  logic [1:0]              m_cache_bresp,
    input  logic                    m_cache_bvalid,
    output logic                    m_cache_bready
);

    // Constants derived from 2MB page / 512-bit width
    localparam TOTAL_BEATS       = 32768; // 2MB / 64 Bytes
    localparam BURST_LEN         = 256;   // Max AXI burst
    localparam TOTAL_BURSTS      = TOTAL_BEATS / BURST_LEN; // 128
    localparam BYTES_PER_BURST   = BURST_LEN * (DATA_WIDTH/8); // 16KB

    // ---------------------------------------------------------
    // Internal FIFO (Decoupler)
    // ---------------------------------------------------------
    // A simple FIFO to buffer data between Read and Write domains
    logic [DATA_WIDTH-1:0] fifo_data [15:0]; // Depth 16
    logic [3:0]            fifo_wr_ptr, fifo_rd_ptr;
    logic [4:0]            fifo_count;
    logic                  fifo_full, fifo_empty;

    logic                  push, pop;
    
    assign fifo_full  = (fifo_count == 16);
    assign fifo_empty = (fifo_count == 0);
    assign push       = m_mem_rvalid && m_mem_rready;
    assign pop        = m_cache_wvalid && m_cache_wready;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            fifo_wr_ptr <= 0;
            fifo_rd_ptr <= 0;
            fifo_count  <= 0;
        end else begin
            if (push) begin
                fifo_data[fifo_wr_ptr] <= m_mem_rdata;
                fifo_wr_ptr <= fifo_wr_ptr + 1;
            end
            if (pop) begin
                fifo_rd_ptr <= fifo_rd_ptr + 1;
            end
            
            // Count logic
            if (push && !pop) fifo_count <= fifo_count + 1;
            else if (pop && !push) fifo_count <= fifo_count - 1;
        end
    end

    // ---------------------------------------------------------
    // Main Control FSM
    // ---------------------------------------------------------
    typedef enum logic [2:0] {
        IDLE,
        ADDR_PHASE,
        DATA_PHASE,
        WAIT_BRESP,
        DONE
    } state_t;

    state_t state;
    
    // Counters
    logic [7:0]  burst_cnt;      // Counts up to 128 bursts
    logic [8:0]  beat_cnt;       // Counts up to 256 beats within a burst
    logic [ADDR_WIDTH-1:0] current_addr;

    // ---------------------------------------------------------
    // AXI Assignments
    // ---------------------------------------------------------
    // Constant / Passthrough signals
    assign m_mem_arlen     = BURST_LEN - 1; // 255 (AXI is Len-1)
    assign m_mem_arsize    = 3'b110;        // 64 Bytes (512 bits)
    assign m_mem_arburst   = 2'b01;         // INCR
    assign m_cache_awlen   = BURST_LEN - 1;
    assign m_cache_awsize  = 3'b110;
    assign m_cache_awburst = 2'b01;
    assign m_cache_wstrb   = 1'b1;          // Simplified: assume full width valid

    // Address Outputs
    assign m_mem_araddr    = current_addr;
    assign m_cache_awaddr  = current_addr; //FIX

    // Read Path Control (Source)
    // Read only when FIFO has space and we are in active transfer
    assign m_mem_rready    = ~fifo_full; 
    
    // Write Path Control (Dest)
    // Write only when FIFO has data
    assign m_cache_wdata   = fifo_data[fifo_rd_ptr];
    assign m_cache_wvalid  = ~fifo_empty && (state == DATA_PHASE);
    
    // Generate WLAST on the 256th beat
    assign m_cache_wlast   = (beat_cnt == BURST_LEN - 1);


    // ---------------------------------------------------------
    // Logic
    // ---------------------------------------------------------
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state           <= IDLE;
            burst_cnt       <= 0;
            beat_cnt        <= 0;
            current_addr    <= 0;
            m_mem_arvalid   <= 0;
            m_cache_awvalid <= 0;
            m_cache_bready  <= 0;
            o_done          <= 0;
            o_idle          <= 1;
        end else begin
            case (state)
                IDLE: begin
                    o_done <= 0;
                    o_idle <= 1;
                    if (i_start) begin
                        current_addr <= i_page_addr;
                        burst_cnt    <= 0;
                        o_idle       <= 0;
                        state        <= ADDR_PHASE;
                    end
                end

                ADDR_PHASE: begin
                    // Issue Read and Write Addresses simultaneously
                    // Simple logic: Assert both until accepted
                    if (!m_mem_arvalid && !m_cache_awvalid) begin
                        m_mem_arvalid   <= 1;
                        m_cache_awvalid <= 1;
                    end
                    
                    if (m_mem_arready)   m_mem_arvalid   <= 0;
                    if (m_cache_awready) m_cache_awvalid <= 0;

                    // Move to data phase once both addresses accepted
                    if ((m_mem_arready || !m_mem_arvalid) && 
                        (m_cache_awready || !m_cache_awvalid)) begin
                        beat_cnt <= 0;
                        state    <= DATA_PHASE;
                    end
                end

                DATA_PHASE: begin
                    // Count beats sent to Write Master
                    if (m_cache_wvalid && m_cache_wready) begin
                        if (beat_cnt == BURST_LEN - 1) begin
                            state <= WAIT_BRESP;
                            m_cache_bready <= 1; // Ready to accept write response
                        end else begin
                            beat_cnt <= beat_cnt + 1;
                        end
                    end
                end

                WAIT_BRESP: begin
                    // Wait for Write Confirmation (BVALID)
                    if (m_cache_bvalid) begin
                        m_cache_bready <= 0; // Deassert ready
                        
                        // Check if we need more bursts
                        if (burst_cnt == TOTAL_BURSTS - 1) begin
                            state <= DONE;
                        end else begin
                            // Prepare for next burst
                            burst_cnt    <= burst_cnt + 1;
                            current_addr <= current_addr + BYTES_PER_BURST;
                            state        <= ADDR_PHASE;
                        end
                    end
                end

                DONE: begin
                    o_done <= 1;
                    state  <= IDLE;
                end
            endcase
        end
    end

endmodule