`timescale 1ns / 1ps

module axi_cache_controller #(
    parameter ADDR_WIDTH = 40,
    parameter DATA_WIDTH = 64, // Standard AXI width
    parameter ID_WIDTH   = 4
)(
    input  logic                    aclk,
    input  logic                    aresetn,

    // ---------------------------------------------------------
    // Read request input
    // ---------------------------------------------------------

    input  logic [ID_WIDTH-1:0]     s_axi_arid,
    input  logic [ADDR_WIDTH-1:0]   s_axi_araddr,
    input  logic [7:0]              s_axi_arlen,
    input  logic [2:0]              s_axi_arsize,
    input  logic [1:0]              s_axi_arburst,
    input  logic                    s_axi_arvalid,
    output logic                    s_axi_arready,

    output logic [ID_WIDTH-1:0]     s_axi_rid,
    output logic [DATA_WIDTH-1:0]   s_axi_rdata,
    output logic [1:0]              s_axi_rresp,
    output logic                    s_axi_rlast,
    output logic                    s_axi_rvalid,
    input  logic                    s_axi_rready,

    // ---------------------------------------------------------
    // Read forward to cache
    // ---------------------------------------------------------
    output logic [ID_WIDTH-1:0]     m_cache_arid,
    output logic [ADDR_WIDTH-1:0]   m_cache_araddr,
    output logic [7:0]              m_cache_arlen,
    output logic [2:0]              m_cache_arsize,
    output logic [1:0]              m_cache_arburst,
    output logic                    m_cache_arvalid,
    input  logic                    m_cache_arready,


    input   logic [ID_WIDTH-1:0]     m_cache_rid,
    input   logic [DATA_WIDTH-1:0]   m_cache_rdata,
    input   logic [1:0]              m_cache_rresp,
    input   logic                    m_cache_rlast,
    input   logic                    m_cache_rvalid,
    output  logic                    m_cache_rready,
    // (Write channels omitted for brevity in Read-Focus, but structure implies symmetry)

    // ---------------------------------------------------------
    // DMA like interface to data mover
    // ---------------------------------------------------------

    output  logic                    o_start_page_fetch,     
    output  logic [ADDR_WIDTH-1:0]   o_page_addr, 
    input   logic                    i_done,      
    input   logic                    i_idle      
);

    // ---------------------------------------------------------
    // Cache Parameters & Tag RAM
    // ---------------------------------------------------------
    localparam OFFSET_BITS = 21;   // 2 MB cache line
    localparam INDEX_BITS  = 13;   // 16GB HBM
    localparam TAG_BITS    = ADDR_WIDTH - OFFSET_BITS - INDEX_BITS; // 6 bits -> 40bit address
    localparam NUM_SETS    = 1 << INDEX_BITS; // 8192 sets

    typedef struct packed {
        logic                valid;
        logic [TAG_BITS-1:0] tag;
    } cache_tag_t;

    // Block RAM inference for Tags
    cache_tag_t tag_ram [NUM_SETS-1:0];

    // Address Decoding
    logic [OFFSET_BITS-1:0] req_offset;
    logic [INDEX_BITS-1:0] req_index;
    logic [TAG_BITS-1:0]   req_tag;
    
    assign req_offset = s_axi_araddr[0 +: OFFSET_BITS];
    assign req_index = s_axi_araddr[OFFSET_BITS +: INDEX_BITS];
    assign req_tag   = s_axi_araddr[ADDR_WIDTH-1 -: TAG_BITS];

    // ---------------------------------------------------------
    // State Machine
    // ---------------------------------------------------------
    typedef enum logic [2:0] {
        IDLE,
        CHECK_TAG,

        FECTH_PAGE,
        WAIT_MEM,

        ACCESS_CACHE,
        WAIT_CACHE
        
    } state_t;

    state_t state, next_state;

    // Registers to latch request
    logic [ADDR_WIDTH-1:0] latched_addr;
    logic                  latched_addr_valid;

    // Internal Hit/Miss signals
    logic is_hit;
    cache_tag_t current_line;

    // ---------------------------------------------------------
    // Control Path (FSM)
    // ---------------------------------------------------------
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state <= IDLE;
            latched_addr_valid <= 0;
            // Resetting RAM usually requires loop or specialized reset, 
            // omitted here for synthesis efficiency (assume INVALID on startup)
        end else begin
            state <= next_state;
            
            // Latch Address on handshake
            if (s_axi_arvalid && s_axi_arready) begin
                latched_addr <= s_axi_araddr;
                latched_addr_valid <= 1;
            end
            
            // Clear latch when transaction done
            if (s_axi_rlast && s_axi_rvalid && s_axi_rready) begin
                latched_addr_valid <= 0;
            end
        end
    end

    // Tag Read Logic (Synchronous Read recommended for BRAM)
    always_ff @(posedge aclk) begin
        if (state == IDLE && s_axi_arvalid) 
            current_line <= tag_ram[req_index];
    end

    // Hit Detection
    always_comb begin
        is_hit = (current_line.valid && (current_line.tag == req_tag));
    end

    // Next State Logic
    always_comb begin
        next_state = state;
        s_axi_arready = 0;

        case (state)
            IDLE: begin
                s_axi_arready = 1; // Ready to accept new address
                if (s_axi_arvalid) begin
                    next_state = CHECK_TAG;
                end
            end

            CHECK_TAG: begin
                // One cycle latency for BRAM read to settle
                if (is_hit) next_state = ACCESS_CACHE;
                else        next_state = FECTH_PAGE;
            end

            FECTH_PAGE: begin
                // fecth a new page in cache
                if (i_idle)
                    next_state = WAIT_MEM;
            end

            WAIT_MEM: begin
                if (i_done)
                    next_state = ACCESS_CACHE;
            end

            ACCESS_CACHE: begin
                // Wait for cache ar ready
                if (m_cache_arready)
                    next_state = WAIT_CACHE;
            end

            WAIT_CACHE: begin
                // Wait for Cache Master to finish transaction
                if (m_cache_rlast && m_cache_rvalid && m_cache_rready)
                    next_state = IDLE;
            end

        endcase
    end

    // ---------------------------------------------------------
    // Data Path Routing
    // ---------------------------------------------------------
    
    // Address Path MUX
    // Pass signals to Cache Master if State is ACCESS_CACHE
    assign m_cache_arvalid = (state == ACCESS_CACHE) ? latched_addr_valid : 0;
    // address requested to cache is index + offset
    assign m_cache_araddr  = { '0, req_index, req_offset};
    
    // Pass signals to Mem Master if State is ACCESS_MEM
    assign m_mem_arvalid   = (state == FECTH_PAGE) ? latched_addr_valid : 0;
    assign o_page_addr     = latched_addr;

    // Read Data Path MUX (Return data to Slave)
    always_comb begin

        // default forward

        m_cache_arid    = s_axi_arid;    
        m_cache_arlen   = s_axi_arlen;
        m_cache_arsize  = s_axi_arsize;
        m_cache_arburst = s_axi_arburst;
        m_cache_rready  = 0;

        s_axi_rdata    = '0;
        s_axi_rvalid   = '0;
        s_axi_rlast    = '0;
        s_axi_rid      = '0;
        s_axi_rresp    = '0;

        o_start_page_fetch = 0;

        if (state == ACCESS_CACHE) begin
            // Route Cache -> Slave
            s_axi_rdata  = m_cache_rdata;
            s_axi_rvalid = m_cache_rvalid;
            s_axi_rlast  = m_cache_rlast;
            s_axi_rid    = m_cache_rid;
            s_axi_rresp  = m_cache_rresp; 

            m_cache_rready = s_axi_rready;
            
        end 
        else if (state == FECTH_PAGE) begin
            // request page fetch to the data mover
            o_start_page_fetch = 1;
        end 

        else begin
            // Default safe state
            s_axi_rdata  = 0;
            s_axi_rvalid = 0;
            s_axi_rlast  = 0;
            m_cache_rready = 0;

        end
    end

    // Note: Write channels (AW, W, B) would follow similar MUX logic:
    // On Write Hit -> Route to Cache Master (Write-Through)
    // On Write Miss -> Route to Mem Master (Write-Around)

endmodule