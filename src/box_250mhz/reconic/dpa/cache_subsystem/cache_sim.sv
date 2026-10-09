`include "axi_assign.svh"
`include "axi_typedef.svh"
`include "axi_.svh"

module cache_sim 
    import cache_ss_pkg::*;
    import axi_pkg::*;
#(
    parameter ADDR_WIDTH      = 40,
    parameter DATA_WIDTH      = 512, // Standard AXI width
    parameter ID_WIDTH        = 4,
    // Simulation-only parameters
    parameter int MISS_PERCENTAGE = 10,   // Percentage of requests that are "misses" (0-100)
    parameter int unsigned STALL_CYCLES = 800   // 3.2 us at 250 MHz (3200 ns / 4 ns)
)
(
    input  logic                      aclk,
    input  logic                      aresetn,

    // ---------------------------------------------------------
    // SLAVE - user logic
    // ---------------------------------------------------------
    input  logic [ID_WIDTH-1:0]      s_axi_arid,
    input  logic [ADDR_WIDTH-1:0]    s_axi_araddr,
    input  logic [7:0]               s_axi_arlen,
    input  logic [2:0]               s_axi_arsize,
    input  logic [1:0]               s_axi_arburst,
    input  logic                     s_axi_arvalid,
    output logic                     s_axi_arready,

    output logic [ID_WIDTH-1:0]      s_axi_rid,
    output logic [DATA_WIDTH-1:0]    s_axi_rdata,
    output logic [1:0]               s_axi_rresp,
    output logic                     s_axi_rlast,
    output logic                     s_axi_rvalid,
    input  logic                     s_axi_rready,

    input  logic [ID_WIDTH-1:0]      s_axi_awid,
    input  logic [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  logic [7:0]               s_axi_awlen,
    input  logic [2:0]               s_axi_awsize,
    input  logic [1:0]               s_axi_awburst,
    input  logic                     s_axi_awvalid,
    output logic                     s_axi_awready,

    input  logic [DATA_WIDTH-1:0]    s_axi_wdata,
    input  logic [DATA_WIDTH/8-1:0]  s_axi_wstrb,
    input  logic                     s_axi_wlast,
    input  logic                     s_axi_wvalid,
    output logic                     s_axi_wready,

    output logic [ID_WIDTH-1:0]      s_axi_bid,
    output logic [1:0]               s_axi_bresp,
    output logic                     s_axi_bvalid,
    input  logic                     s_axi_bready,

    // ---------------------------------------------------------
    // MASTER - CACHE memory 
    // ---------------------------------------------------------
    output logic [ID_WIDTH-1:0]      m_axi_mem_arid,
    output logic [ADDR_WIDTH-1:0]    m_axi_mem_araddr,
    output logic [7:0]               m_axi_mem_arlen,   
    output logic [2:0]               m_axi_mem_arsize,  
    output logic [1:0]               m_axi_mem_arburst, 
    output logic                     m_axi_mem_arvalid,
    input  logic                     m_axi_mem_arready,

    input  logic [ID_WIDTH-1:0]      m_axi_mem_rid,
    input  logic [DATA_WIDTH-1:0]    m_axi_mem_rdata,
    input  logic [1:0]               m_axi_mem_rresp,
    input  logic                     m_axi_mem_rvalid,
    output logic                     m_axi_mem_rready,
    input  logic                     m_axi_mem_rlast,

    output logic [ID_WIDTH-1:0]      m_axi_mem_awid,
    output logic [ADDR_WIDTH-1:0]    m_axi_mem_awaddr,
    output logic [7:0]               m_axi_mem_awlen,
    output logic [2:0]               m_axi_mem_awsize,
    output logic [1:0]               m_axi_mem_awburst,
    output logic                     m_axi_mem_awvalid,
    input  logic                     m_axi_mem_awready,

    output logic [DATA_WIDTH-1:0]    m_axi_mem_wdata,
    output logic [DATA_WIDTH/8-1:0]  m_axi_mem_wstrb, 
    output logic                     m_axi_mem_wlast,
    output logic                     m_axi_mem_wvalid,
    input  logic                     m_axi_mem_wready,

    input  logic [ID_WIDTH-1:0]      m_axi_mem_bid,
    input  logic [1:0]               m_axi_mem_bresp,
    input  logic                     m_axi_mem_bvalid,
    output logic                     m_axi_mem_bready
);

    // ---------------------------------------------------------
    // Simulation Initialization Log
    // ---------------------------------------------------------
    initial begin
        real avg_transactions;
        if (MISS_PERCENTAGE > 0) begin
            avg_transactions = 100.0 / real'(MISS_PERCENTAGE);
            $display("[CACHE_SUBSYSTEM] Latched Simulation Model Initialized:");
            $display("[CACHE_SUBSYSTEM]   - Miss Rate: %0d%%", MISS_PERCENTAGE);
            $display("[CACHE_SUBSYSTEM]   - Avg Transactions Between Misses: %0.2f", avg_transactions);
            $display("[CACHE_SUBSYSTEM]   - Stall Penalty: %0d cycles", STALL_CYCLES);
        end else begin
            $display("[CACHE_SUBSYSTEM] Latched Simulation Model Initialized: 0% Miss Rate (1-cycle hit latency)");
        end
    end

    typedef enum logic [1:0] {
        ST_IDLE    = 2'b00,
        ST_STALL   = 2'b01,
        ST_FORWARD = 2'b10
    } state_t;

    // ---------------------------------------------------------
    // Read Channel (AR) Latch & Stall Logic
    // ---------------------------------------------------------
    state_t ar_state;
    int unsigned ar_stall_counter; // 32-bit unsigned to prevent truncation
    
    // AR Latches
    logic [ID_WIDTH-1:0]   ar_id_latch;
    logic [ADDR_WIDTH-1:0] ar_addr_latch;
    logic [7:0]            ar_len_latch;
    logic [2:0]            ar_size_latch;
    logic [1:0]            ar_burst_latch;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            ar_state         <= ST_IDLE;
            ar_stall_counter <= '0;
        end else begin
            case (ar_state)
                ST_IDLE: begin
                    if (s_axi_arvalid) begin
                        // 1. Accept transaction and latch all signals
                        ar_id_latch    <= s_axi_arid;
                        ar_addr_latch  <= s_axi_araddr;
                        ar_len_latch   <= s_axi_arlen;
                        ar_size_latch  <= s_axi_arsize;
                        ar_burst_latch <= s_axi_arburst;

                        // 2. Decide if it's a hit or miss
                        if (MISS_PERCENTAGE > 0 && ($urandom_range(0, 99) < MISS_PERCENTAGE)) begin
                            ar_state         <= ST_STALL;
                            ar_stall_counter <= (STALL_CYCLES > 0) ? STALL_CYCLES - 1 : 0;
                            `ifndef SYNTHESIS
                            $display("[%0t] [CACHE_SIM] AR MISS! Latching ARADDR %h, stalling for %0d cycles.", $time, s_axi_araddr, STALL_CYCLES);
                            `endif
                        end else begin
                            ar_state         <= ST_FORWARD;
                        end
                    end
                end
                ST_STALL: begin
                    // 3. Wait for the miss penalty to expire
                    if (ar_stall_counter > 0) begin
                        ar_stall_counter <= ar_stall_counter - 1;
                    end else begin
                        ar_state <= ST_FORWARD;
                        `ifndef SYNTHESIS
                        $display("[%0t] [CACHE_SIM] AR STALL COMPLETE! Forwarding ARADDR %h to memory.", $time, ar_addr_latch);
                        `endif
                    end
                end
                ST_FORWARD: begin
                    // 4. Present to slave and wait for acceptance
                    if (m_axi_mem_arready) begin
                        ar_state <= ST_IDLE;
                        `ifndef SYNTHESIS
                        $display("[%0t] [CACHE_SIM] AR TRANSACTION ACCEPTED by memory.", $time);
                        `endif
                    end
                end
            endcase
        end
    end

    // AR Outputs
    assign s_axi_arready       = (ar_state == ST_IDLE);
    assign m_axi_mem_arvalid   = (ar_state == ST_FORWARD);
    
    assign m_axi_mem_arid      = ar_id_latch;
    assign m_axi_mem_araddr    = ar_addr_latch;
    assign m_axi_mem_arlen     = ar_len_latch;
    assign m_axi_mem_arsize    = ar_size_latch;
    assign m_axi_mem_arburst   = ar_burst_latch;

    // ---------------------------------------------------------
    // Write Channel (AW) Latch & Stall Logic
    // ---------------------------------------------------------
    state_t aw_state;
    int unsigned aw_stall_counter;
    
    // AW Latches
    logic [ID_WIDTH-1:0]   aw_id_latch;
    logic [ADDR_WIDTH-1:0] aw_addr_latch;
    logic [7:0]            aw_len_latch;
    logic [2:0]            aw_size_latch;
    logic [1:0]            aw_burst_latch;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            aw_state         <= ST_IDLE;
            aw_stall_counter <= '0;
        end else begin
            case (aw_state)
                ST_IDLE: begin
                    if (s_axi_awvalid) begin
                        aw_id_latch    <= s_axi_awid;
                        aw_addr_latch  <= s_axi_awaddr;
                        aw_len_latch   <= s_axi_awlen;
                        aw_size_latch  <= s_axi_awsize;
                        aw_burst_latch <= s_axi_awburst;

                        if (MISS_PERCENTAGE > 0 && ($urandom_range(0, 99) < MISS_PERCENTAGE)) begin
                            aw_state         <= ST_STALL;
                            aw_stall_counter <= (STALL_CYCLES > 0) ? STALL_CYCLES - 1 : 0;
                            `ifndef SYNTHESIS
                            $display("[%0t] [CACHE_SIM] AW MISS! Latching AWADDR %h, stalling for %0d cycles.", $time, s_axi_awaddr, STALL_CYCLES);
                            `endif
                        end else begin
                            aw_state         <= ST_FORWARD;
                        end
                    end
                end
                ST_STALL: begin
                    if (aw_stall_counter > 0) begin
                        aw_stall_counter <= aw_stall_counter - 1;
                    end else begin
                        aw_state <= ST_FORWARD;
                        `ifndef SYNTHESIS
                        $display("[%0t] [CACHE_SIM] AW STALL COMPLETE! Forwarding AWADDR %h to memory.", $time, aw_addr_latch);
                        `endif
                    end
                end
                ST_FORWARD: begin
                    if (m_axi_mem_awready) begin
                        aw_state <= ST_IDLE;
                        `ifndef SYNTHESIS
                        $display("[%0t] [CACHE_SIM] AW TRANSACTION ACCEPTED by memory.", $time);
                        `endif
                    end
                end
            endcase
        end
    end

    // AW Outputs
    assign s_axi_awready       = (aw_state == ST_IDLE);
    assign m_axi_mem_awvalid   = (aw_state == ST_FORWARD);
    
    assign m_axi_mem_awid      = aw_id_latch;
    assign m_axi_mem_awaddr    = aw_addr_latch;
    assign m_axi_mem_awlen     = aw_len_latch;
    assign m_axi_mem_awsize    = aw_size_latch;
    assign m_axi_mem_awburst   = aw_burst_latch;

    // ---------------------------------------------------------
    // Transparent Pass-Through for Data & Response Signals
    // ---------------------------------------------------------
    
    // Read Data Channel (Slave to Master)
    assign s_axi_rid         = m_axi_mem_rid;
    assign s_axi_rdata       = m_axi_mem_rdata;
    assign s_axi_rresp       = m_axi_mem_rresp;
    assign s_axi_rlast       = m_axi_mem_rlast;
    assign s_axi_rvalid      = m_axi_mem_rvalid;
    assign m_axi_mem_rready  = s_axi_rready;

    // Write Data Channel (Master to Slave)
    assign m_axi_mem_wdata   = s_axi_wdata;
    assign m_axi_mem_wstrb   = s_axi_wstrb;
    assign m_axi_mem_wlast   = s_axi_wlast;
    assign m_axi_mem_wvalid  = s_axi_wvalid;
    assign s_axi_wready      = m_axi_mem_wready;

    // Write Response Channel (Slave to Master)
    assign s_axi_bid         = m_axi_mem_bid;
    assign s_axi_bresp       = m_axi_mem_bresp;
    assign s_axi_bvalid      = m_axi_mem_bvalid;
    assign m_axi_mem_bready  = s_axi_bready;

endmodule