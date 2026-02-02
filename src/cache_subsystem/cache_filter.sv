`timescale 1ns / 1ps

module cache_filter #(
    parameter ADDR_WIDTH = 40,
    parameter DATA_WIDTH = 512, // Standard AXI width
    parameter ID_WIDTH   = 4,
    parameter OFFSET_BITS = 21,   // 2 MB cache line
    parameter INDEX_BITS  = 13   // 16GB HBM
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
    // Write request input
    // ---------------------------------------------------------
    input  logic [ID_WIDTH-1:0]     s_axi_awid,
    input  logic [ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  logic [7:0]              s_axi_awlen,
    input  logic [2:0]              s_axi_awsize,
    input  logic [1:0]              s_axi_awburst,
    input  logic                    s_axi_awvalid,
    output logic                    s_axi_awready,

    input  logic [DATA_WIDTH-1:0]   s_axi_wdata,
    input  logic [DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  logic                    s_axi_wlast,
    input  logic                    s_axi_wvalid,
    output logic                    s_axi_wready,

    output logic [ID_WIDTH-1:0]     s_axi_bid,
    output logic [1:0]              s_axi_bresp,
    output logic                    s_axi_bvalid,
    input  logic                    s_axi_bready,

    // ---------------------------------------------------------
    // Read forward to cache
    // ---------------------------------------------------------
    output logic [ID_WIDTH-1:0]                     m_cache_arid,
    output logic [(INDEX_BITS + OFFSET_BITS)-1:0]   m_cache_araddr,
    output logic [7:0]                              m_cache_arlen,
    output logic [2:0]                              m_cache_arsize,
    output logic [1:0]                              m_cache_arburst,
    output logic                                    m_cache_arvalid,
    input  logic                                    m_cache_arready,


    input   logic [ID_WIDTH-1:0]                    m_cache_rid,
    input   logic [DATA_WIDTH-1:0]                  m_cache_rdata,
    input   logic [1:0]                             m_cache_rresp,
    input   logic                                   m_cache_rlast,
    input   logic                                   m_cache_rvalid,
    output  logic                                   m_cache_rready,

    // ---------------------------------------------------------
    // Write forward to cache
    // ---------------------------------------------------------
    output logic [ID_WIDTH-1:0]     m_cache_awid,
    output logic [(INDEX_BITS + OFFSET_BITS)-1:0]   m_cache_awaddr,
    output logic [7:0]              m_cache_awlen,
    output logic [2:0]              m_cache_awsize,
    output logic [1:0]              m_cache_awburst,
    output logic                    m_cache_awvalid,
    input  logic                    m_cache_awready,

    output logic [DATA_WIDTH-1:0]   m_cache_wdata,
    output logic [DATA_WIDTH/8-1:0] m_cache_wstrb,
    output logic                    m_cache_wlast,
    output logic                    m_cache_wvalid,
    input  logic                    m_cache_wready,

    input  logic [ID_WIDTH-1:0]     m_cache_bid,
    input  logic [1:0]              m_cache_bresp,
    input  logic                    m_cache_bvalid,
    output logic                    m_cache_bready,


    // ---------------------------------------------------------
    // DMA like interface to page fetcher
    // ---------------------------------------------------------

    output  logic                    o_start_page_fetch,     
    output  logic [ADDR_WIDTH-1:0]   o_page_addr_fetch, 
    output  logic [ADDR_WIDTH-1:0]   o_cache_page_addr_fetch, 
    input   logic                    i_done_fetch,      
    input   logic                    i_idle_fetch,      


    // ---------------------------------------------------------
    // DMA like interface to page evicter
    // ---------------------------------------------------------
    output  logic                    o_start_page_evict,     
    output  logic [ADDR_WIDTH-1:0]   o_page_addr_evict, 
    output  logic [ADDR_WIDTH-1:0]   o_cache_page_addr_evict,
    input   logic                    i_done_evict,      
    input   logic                    i_idle_evict      

);

    // ---------------------------------------------------------
    // Cache Parameters & Tag RAM
    // ---------------------------------------------------------
    
    localparam TAG_BITS    = ADDR_WIDTH - OFFSET_BITS - INDEX_BITS; // 6 bits -> 40bit address
    localparam NUM_SETS    = 1 << INDEX_BITS; // 8192 sets
    
    typedef struct packed {
        logic                valid;
        logic                dirty;
        logic [TAG_BITS-1:0] tag;
    } cache_tag_t;

    // Block RAM inference for Tags
    cache_tag_t tag_ram [NUM_SETS-1:0];

    
    logic [OFFSET_BITS-1:0] read_req_offset , write_req_offset;
    logic [INDEX_BITS-1:0]  read_req_index , write_req_index;
    logic [TAG_BITS-1:0]    read_req_tag , write_req_tag;

    typedef enum logic [2:0] {
        IDLE,
        CHECK_TAG,

        EVICT_OLD_PAGE,
        WAIT_EVICT,

        FETCH_PAGE,
        WAIT_MEM,

        ACCESS_CACHE,
        WAIT_CACHE
        
    } state_t;

    typedef enum logic [0] {
        RESET,
        READY
    } tag_ram_state_t;

    // tag ram reset fsm
    tag_ram_state_t tag_ram_state;
    logic [INDEX_BITS-1:0] tag_ram_reset_i;

    state_t r_state, r_next_state;
    state_t w_state, w_next_state;

    // update tags
    logic r_update_tag, w_update_tag;
    logic r_invalid_tag, w_invalid_tag;
    logic w_tag_as_dirty;

    // Registers to latch request
    logic [ADDR_WIDTH-1:0] r_latched_addr, w_latched_addr;
    logic                  r_latched_addr_valid, w_latched_addr_valid;

    // Internal Hit/Miss signals
    logic read_is_hit, write_is_hit;
    cache_tag_t read_current_line, write_current_line;


    // READ Address Decoding
    assign read_req_offset = r_latched_addr[0 +: OFFSET_BITS];
    assign read_req_index  = r_latched_addr[OFFSET_BITS +: INDEX_BITS];
    assign read_req_tag    = r_latched_addr[ADDR_WIDTH-1 -: TAG_BITS];
    // WRITE Address Decoding
    assign write_req_offset = w_latched_addr[0 +: OFFSET_BITS];
    assign write_req_index  = w_latched_addr[OFFSET_BITS +: INDEX_BITS];
    assign write_req_tag    = w_latched_addr[ADDR_WIDTH-1 -: TAG_BITS];

// ---------------------------------------------------------
// TAG RAM UPDATE & RESET LOGIC
// ---------------------------------------------------------
    
    // Clocked FSM because synch BRAM must be writte in syncronus process
    always_ff @(posedge aclk) begin : tag_update_logic
        if (!aresetn) begin
            tag_ram_state   <= RESET;
            tag_ram_reset_i <= '0;
        end else begin
            // --- RESET FSM ---
            case (tag_ram_state)
                RESET: begin
                    // Clear one line per cycle
                    tag_ram[tag_ram_reset_i].valid <= 0;
                    tag_ram[tag_ram_reset_i].dirty <= 0;
                    tag_ram[tag_ram_reset_i].tag   <= '0;

                    if (tag_ram_reset_i == NUM_SETS[INDEX_BITS-1:0] - 1) begin
                        tag_ram_state <= READY;
                    end else begin
                        tag_ram_reset_i <= tag_ram_reset_i + 1;
                    end
                end
                READY: begin
                    // READ FSM Updates
                    if (r_invalid_tag) begin 
                        tag_ram[read_req_index].valid <= 0;
                    end
                    if (r_update_tag) begin
                        tag_ram[read_req_index].tag   <= read_req_tag;
                        tag_ram[read_req_index].valid <= 1;
                        tag_ram[read_req_index].dirty <= 0;
                    end

                    // WRITE FSM Updates
                    if (w_invalid_tag) begin 
                        tag_ram[write_req_index].valid <= 0;
                    end
                    if (w_update_tag) begin
                        tag_ram[write_req_index].tag   <= write_req_tag;
                        tag_ram[write_req_index].valid <= 1;
                        tag_ram[write_req_index].dirty <= 0;
                    end
                    if (w_tag_as_dirty) begin
                        tag_ram[write_req_index].dirty <= 1;
                    end
                end

                default: begin

                end
            endcase
        end
    end
    
// ------------------------------------------------------------------------------------------------------------------
// READ CACHE
// ------------------------------------------------------------------------------------------------------------------
    
    always_ff @(posedge aclk or negedge aresetn) begin : read_control_fsm
        if (!aresetn) begin
            r_state <= IDLE;
            r_latched_addr_valid <= 0;
            
            // Resetting RAM usually requires loop or specialized reset, 
            // omitted here for synthesis efficiency (assume INVALID on startup)
        end else begin
            r_state <= r_next_state;
            
            // Latch Address on handshake
            if (s_axi_arvalid && s_axi_arready) begin
                r_latched_addr <= s_axi_araddr;
                r_latched_addr_valid <= 1;
            end
            
            // Clear latch when transaction done
            if (s_axi_rlast && s_axi_rvalid && s_axi_rready) begin
                r_latched_addr_valid <= 0;
            end
        end
    end : read_control_fsm

    always_ff @(posedge aclk) begin : r_tag_read
        // Only read from RAM when we have a valid request in IDLE
        if (r_state == IDLE && s_axi_arvalid) 
            read_current_line <= tag_ram[s_axi_araddr[OFFSET_BITS +: INDEX_BITS]];
    end

    // Hit Detection read
    always_comb begin : r_tag_is_hit
        read_is_hit = (read_current_line.valid && (read_current_line.tag == read_req_tag));
    end

    // read fsm
    always_comb begin : read_cache_fsm
        r_next_state = r_state;
        s_axi_arready = 0;
        r_invalid_tag = 0;
        r_update_tag = 0;

        case (r_state)

            // TODO: possible to combine IDLE and CHECK_TAG
            
            IDLE: begin
                if (w_state == IDLE && tag_ram_state == READY) begin
                    s_axi_arready = 1; // Ready to accept new address
                    if (s_axi_arvalid) begin
                        r_next_state = CHECK_TAG;
                    end else begin
                        r_next_state = IDLE;
                    end
                end
            end

            CHECK_TAG: begin
                // One cycle latency for BRAM read to settle
                if (read_is_hit) r_next_state = ACCESS_CACHE;
                else  begin
                    r_invalid_tag = 1;
                    if (read_current_line.dirty) begin
                        r_next_state = EVICT_OLD_PAGE;
                    end else begin
                        r_next_state = FETCH_PAGE;
                    end
                end      
            end

            EVICT_OLD_PAGE : begin
                if (i_idle_evict)
                    r_next_state = WAIT_EVICT;
            end

            WAIT_EVICT: begin
                if (i_done_evict)
                    r_next_state = FETCH_PAGE;
            end      

            FETCH_PAGE: begin
                // fecth a new page in cache
                if (i_idle_fetch)
                    r_next_state = WAIT_MEM;
            end

            WAIT_MEM: begin
                if (i_done_fetch)
                    r_update_tag = 1;
                    r_next_state = ACCESS_CACHE;
            end

            ACCESS_CACHE: begin
                // Wait for cache ar ready
                if (m_cache_arready)
                    r_next_state = WAIT_CACHE;
            end

            WAIT_CACHE: begin
                // Wait for Cache Master to finish transaction
                if (m_cache_rlast && m_cache_rvalid && m_cache_rready)
                    r_next_state = IDLE;
            end

            default: begin
                r_next_state = IDLE;
            end

        endcase
    end

// ------------------------------------------------------------------------------------------------------------------
// WRITE CACHE
// ------------------------------------------------------------------------------------------------------------------
    
    always_ff @(posedge aclk or negedge aresetn) begin : write_control_fsm
        if (!aresetn) begin
            w_state <= IDLE;
            w_latched_addr_valid <= 0;
            
            // Resetting RAM usually requires loop or specialized reset, 
            // omitted here for synthesis efficiency (assume INVALID on startup)
        end else begin
            w_state <= w_next_state;
            
            // Latch Address on handshake
            if (s_axi_awvalid && s_axi_awready) begin
                w_latched_addr <= s_axi_araddr;
                w_latched_addr_valid <= 1;
            end
            
            // Clear latch when transaction done
            if (s_axi_wlast && s_axi_wvalid && s_axi_wready) begin
                w_latched_addr_valid <= 0;
            end
        end
    end : write_control_fsm

    always_ff @(posedge aclk) begin : w_tag_read
        // Only read from RAM when we have a valid request in IDLE
        if (w_state == IDLE && s_axi_awvalid) 
            write_current_line <= tag_ram[s_axi_awaddr[OFFSET_BITS +: INDEX_BITS]];
    end

    // Hit Detection write
    always_comb begin : w_tag_is_hit
        write_is_hit = (write_current_line.valid && (write_current_line.tag == write_req_tag));
    end

    // write fsm
    always_comb begin : write_cache_fsm
        w_next_state = w_state;
        s_axi_awready = 0;
        w_invalid_tag = 0;
        w_update_tag = 0;
        w_tag_as_dirty = 0;

        case (w_state)
            IDLE: begin
                if (r_state == IDLE && tag_ram_state == READY) begin
                    // Ready to accept new aw address
                    s_axi_awready = 1; 
                    if (s_axi_awvalid) begin
                        w_next_state = CHECK_TAG;
                    end else begin
                        w_next_state = IDLE;
                    end
                end   
            end

            CHECK_TAG: begin
                // One cycle latency for BRAM read to settle
                if (write_is_hit) w_next_state = ACCESS_CACHE;
                else  begin
                    w_invalid_tag = 1;
                    if (write_current_line.dirty) begin
                        w_next_state = EVICT_OLD_PAGE;
                    end else begin
                        w_next_state = FETCH_PAGE;
                    end
                end      
            end

            EVICT_OLD_PAGE : begin
                // Stall if Read FSM is currently evicting
                if (i_idle_evict && r_state != EVICT_OLD_PAGE && r_state != WAIT_EVICT)
                    w_next_state = WAIT_EVICT;
                else
                    w_next_state = EVICT_OLD_PAGE;
            end
        
            WAIT_EVICT: begin
                if (i_done_evict)
                    w_next_state = FETCH_PAGE;
            end 

            FETCH_PAGE: begin
                // Stall if Read FSM is currently fetching
                if (i_idle_fetch && r_state != FETCH_PAGE && r_state != WAIT_MEM) 
                    w_next_state = WAIT_MEM;
                else 
                    w_next_state = FETCH_PAGE;
            end

            WAIT_MEM: begin
                w_update_tag = 1;
                if (i_done_fetch)
                    w_next_state = ACCESS_CACHE;
            end

            ACCESS_CACHE: begin
                // Wait for cache aw ready
                if (m_cache_awready)
                    w_tag_as_dirty = 1;
                    w_next_state = WAIT_CACHE;
            end

            WAIT_CACHE: begin
                // Wait for Cache Master to finish transaction
                if (m_cache_bvalid && s_axi_bready)
                    w_next_state = IDLE;
            end

            default: begin
                w_next_state = IDLE;
            end

        endcase
    end

// ------------------------------------------------------------------------------------------------------------------
// PAGE MOVER
// ------------------------------------------------------------------------------------------------------------------

    // always start data movement form the base of the target page
    localparam [ADDR_WIDTH-1:0] PAGE_MASK = { {(ADDR_WIDTH-OFFSET_BITS){1'b1}}, {OFFSET_BITS{1'b0}} };

    always_comb begin

        o_page_addr_evict = '0;
        o_page_addr_fetch = '0;

        o_cache_page_addr_evict = '0;
        o_cache_page_addr_fetch = '0;

        o_start_page_evict = 0;
        o_start_page_fetch = 0;

        // read has precedence in page moving operations
        if (r_state == EVICT_OLD_PAGE) begin
            // retrieve memory location of ached page from tag memory
            o_page_addr_evict = {read_current_line.tag, read_req_index, {OFFSET_BITS{1'b0}}};
            o_cache_page_addr_evict[OFFSET_BITS +: INDEX_BITS] = read_req_index ;
            o_start_page_evict = 1;

        end else if (w_state == EVICT_OLD_PAGE) begin
            o_page_addr_evict = {write_current_line.tag, write_req_index, {OFFSET_BITS{1'b0}}};
            o_cache_page_addr_evict[OFFSET_BITS +: INDEX_BITS] = write_req_index ;
            o_start_page_evict = 1;
        end

        if (r_state == FETCH_PAGE) begin
            o_page_addr_fetch = r_latched_addr & PAGE_MASK;
            o_cache_page_addr_fetch[OFFSET_BITS +: INDEX_BITS] = read_req_index ;
            o_start_page_fetch = 1;
        end else if (w_state == FETCH_PAGE) begin
            o_page_addr_fetch = w_latched_addr & PAGE_MASK;
            o_cache_page_addr_fetch[OFFSET_BITS +: INDEX_BITS] = write_req_index ;
            o_start_page_fetch = 1;
        end

    end

// ------------------------------------------------------------------------------------------------------------------
// Data Path Routing
// ------------------------------------------------------------------------------------------------------------------
    
// Read Data Path MUX (Return data to Slave)
    always_comb begin
    
        // READ
        // AR
        m_cache_araddr[0 +: OFFSET_BITS]          = read_req_offset;
        m_cache_araddr[OFFSET_BITS +: INDEX_BITS] = read_req_index ;
        m_cache_arvalid = 0;
        m_cache_arid    = s_axi_arid;    
        m_cache_arlen   = s_axi_arlen;
        m_cache_arsize  = s_axi_arsize;
        m_cache_arburst = s_axi_arburst;
        // R
        m_cache_rready  = 0;
        s_axi_rdata     = m_cache_rdata;
        s_axi_rvalid    = 0;
        s_axi_rlast     = m_cache_rlast;
        s_axi_rid       = m_cache_rid;
        s_axi_rresp     = m_cache_rresp; 
        
        if (r_state == ACCESS_CACHE) begin
            // AR
            m_cache_arvalid = r_latched_addr_valid;   
        end else if (r_state == WAIT_CACHE) begin
            // R
            s_axi_rvalid = m_cache_rvalid;
            m_cache_rready = s_axi_rready;
        end 
    
        // WRITE
        // AW
        m_cache_awaddr[0 +: OFFSET_BITS]          = write_req_offset;
        m_cache_awaddr[OFFSET_BITS +: INDEX_BITS] = write_req_index ;
        m_cache_awvalid = 0;
        m_cache_awid    = s_axi_awid;    
        m_cache_awlen   = s_axi_awlen;
        m_cache_awsize  = s_axi_awsize;
        m_cache_awburst = s_axi_awburst;
        // W
        m_cache_wdata = s_axi_wdata;
        m_cache_wstrb = s_axi_wstrb;
        m_cache_wlast = s_axi_wlast;
        // B
        s_axi_bid  = m_cache_bid;
        s_axi_bresp  = m_cache_bresp;
            
        if (w_state == ACCESS_CACHE) begin
            // AW
            m_cache_awvalid = w_latched_addr_valid;

        end else if (w_state == WAIT_CACHE) begin
            // W
            s_axi_wready = m_cache_wready;
            m_cache_wvalid = s_axi_wvalid;
            // B
            s_axi_bvalid = m_cache_bvalid;
            m_cache_bready = s_axi_bready;
        end
    
    end

endmodule