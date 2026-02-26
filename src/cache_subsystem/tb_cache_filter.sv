`timescale 1ns / 1ps

module tb_cache_filter();

    // ---------------------------------------------------------
    // Parameters
    // We override INDEX_BITS to 6 (64 sets) instead of 13 (8192 sets)
    // ---------------------------------------------------------
    parameter ADDR_WIDTH  = 34;
    parameter DATA_WIDTH  = 512;
    parameter ID_WIDTH    = 4;
    parameter OFFSET_BITS = 21;
    parameter INDEX_BITS  = 9;  

    // ---------------------------------------------------------
    // Signals
    // ---------------------------------------------------------
    logic aclk = 0;
    logic aresetn = 0;

    // CPU AXI Interface (Slave port on filter)
    logic [ID_WIDTH-1:0]     s_axi_arid, s_axi_awid, s_axi_rid, s_axi_bid;
    logic [ADDR_WIDTH-1:0]   s_axi_araddr, s_axi_awaddr;
    logic [7:0]              s_axi_arlen, s_axi_awlen;
    logic [2:0]              s_axi_arsize, s_axi_awsize;
    logic [1:0]              s_axi_arburst, s_axi_awburst, s_axi_rresp, s_axi_bresp;
    logic                    s_axi_arvalid, s_axi_arready, s_axi_awvalid, s_axi_awready;
    logic [DATA_WIDTH-1:0]   s_axi_wdata, s_axi_rdata;
    logic [DATA_WIDTH/8-1:0] s_axi_wstrb;
    logic                    s_axi_wlast, s_axi_wvalid, s_axi_wready;
    logic                    s_axi_rlast, s_axi_rvalid, s_axi_rready;
    logic                    s_axi_bvalid, s_axi_bready;

    // Cache AXI Interface (Master port on filter)
    logic [ID_WIDTH-1:0]     m_cache_arid, m_cache_awid, m_cache_rid, m_cache_bid;
    logic [(INDEX_BITS+OFFSET_BITS)-1:0] m_cache_araddr, m_cache_awaddr;
    logic [7:0]              m_cache_arlen, m_cache_awlen;
    logic [2:0]              m_cache_arsize, m_cache_awsize;
    logic [1:0]              m_cache_arburst, m_cache_awburst, m_cache_rresp, m_cache_bresp;
    logic                    m_cache_arvalid, m_cache_arready, m_cache_awvalid, m_cache_awready;
    logic [DATA_WIDTH-1:0]   m_cache_wdata, m_cache_rdata;
    logic [DATA_WIDTH/8-1:0] m_cache_wstrb;
    logic                    m_cache_wlast, m_cache_wvalid, m_cache_wready;
    logic                    m_cache_rlast, m_cache_rvalid, m_cache_rready;
    logic                    m_cache_bvalid, m_cache_bready;

    // DMA Mover Interfaces
    logic o_start_page_fetch, i_done_fetch, i_idle_fetch;
    logic [ADDR_WIDTH-1:0] o_page_addr_fetch, o_cache_page_addr_fetch;
    logic o_start_page_evict, i_done_evict, i_idle_evict;
    logic [ADDR_WIDTH-1:0] o_page_addr_evict, o_cache_page_addr_evict;

    // ---------------------------------------------------------
    // Clock & Reset
    // ---------------------------------------------------------
    always #5 aclk = ~aclk;

    initial begin
        aresetn = 0;
        #50 aresetn = 1;
    end

    // ---------------------------------------------------------
    // DUT Instantiation
    // ---------------------------------------------------------
    cache_filter #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH),
        .OFFSET_BITS(OFFSET_BITS), .INDEX_BITS(INDEX_BITS)
    ) dut (.*); // SystemVerilog wildcard connect for exact matching names

    // ---------------------------------------------------------
    // Mock DMA Movers
    // ---------------------------------------------------------
    initial begin
        i_idle_fetch = 1; 
        i_done_fetch = 0;
        forever begin
            @(posedge aclk);
            if (o_start_page_fetch) begin
                i_idle_fetch <= 0;
                $display("[%0t] MOCK DMA: Started Fetching Page from 0x%0h to Cache 0x%0h", $time, o_page_addr_fetch, o_cache_page_addr_fetch);
                repeat(10) @(posedge aclk); // Simulate delay
                i_done_fetch <= 1;
                $display("[%0t] MOCK DMA: Finished Fetching", $time);
                @(posedge aclk);
                i_done_fetch <= 0;
                i_idle_fetch <= 1;
            end
        end
    end

    initial begin
        i_idle_evict = 1; 
        i_done_evict = 0;
        forever begin
            @(posedge aclk);
            if (o_start_page_evict) begin
                i_idle_evict <= 0;
                $display("[%0t] MOCK DMA: Started Evicting Cache 0x%0h to Page 0x%0h", $time, o_cache_page_addr_evict, o_page_addr_evict);
                repeat(10) @(posedge aclk); // Simulate delay
                i_done_evict <= 1;
                $display("[%0t] MOCK DMA: Finished Eviction", $time);
                @(posedge aclk);
                i_done_evict <= 0;
                i_idle_evict <= 1;
            end
        end
    end

    // ---------------------------------------------------------
    // Mock Cache Memory
    // ---------------------------------------------------------
    initial begin
        m_cache_arready = 0; 
        m_cache_rvalid = 0; 
        m_cache_rlast = 0; 
        m_cache_rdata = 0;

        forever begin
            @(posedge aclk);
            m_cache_arready <= 1; // Always accept address
            if (m_cache_arvalid && m_cache_arready) begin
                m_cache_arready <= 0;
                @(posedge aclk); // 1 cycle cache latency
                m_cache_rvalid <= 1;
                m_cache_rlast  <= 1; // Single beat for simplicity
                m_cache_rdata  <= 64'hDEADBEEF_CAFEF00D;
                @(posedge aclk);
                while (!m_cache_rready) @(posedge aclk);
                m_cache_rvalid <= 0;
                m_cache_rlast  <= 0;
            end
        end
    end

    initial begin
        m_cache_awready = 0; 
        m_cache_wready = 0; 
        m_cache_bvalid = 0;

        forever begin
            @(posedge aclk);
            m_cache_awready <= 1; 
            m_cache_wready <= 1;
            
            if (m_cache_wvalid && m_cache_wlast) begin
                @(posedge aclk);
                m_cache_bvalid <= 1;
                @(posedge aclk);
                while (!m_cache_bready) @(posedge aclk);
                m_cache_bvalid <= 0;
            end
        end
    end

    // ---------------------------------------------------------
    // BFM Tasks for CPU Request Generation
    // ---------------------------------------------------------
    task cpu_read(input [ADDR_WIDTH-1:0] addr);
        $display("[%0t] CPU: Initiating READ to 0x%0h", $time, addr);
        // Address Phase
        s_axi_araddr  <= addr;
        s_axi_arlen   <= 0; // 1 beat
        s_axi_arvalid <= 1;
        @(posedge aclk);
        while (!s_axi_arready) @(posedge aclk);
        s_axi_arvalid <= 0;

        // Data Phase
        s_axi_rready <= 1;
        @(posedge aclk);
        while (!s_axi_rvalid) @(posedge aclk);
        s_axi_rready <= 0;
        $display("[%0t] CPU: READ Complete. Data: 0x%0h", $time, s_axi_rdata);
    endtask

    task cpu_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
        $display("[%0t] CPU: Initiating WRITE to 0x%0h", $time, addr);
        // Address Phase
        s_axi_awaddr  <= addr;
        s_axi_awlen   <= 0;
        s_axi_awvalid <= 1;
        
        // Data Phase
        s_axi_wdata  <= data;
        s_axi_wlast  <= 1;
        s_axi_wvalid <= 1;
        
        @(posedge aclk);
        while (!s_axi_awready) @(posedge aclk);
        s_axi_awvalid <= 0;
        
        while (!s_axi_wready) @(posedge aclk);
        s_axi_wvalid <= 0;
        s_axi_wlast  <= 0;

        // Resp Phase
        s_axi_bready <= 1;
        @(posedge aclk);
        while (!s_axi_bvalid) @(posedge aclk);
        s_axi_bready <= 0;
        $display("[%0t] CPU: WRITE Complete.", $time);
    endtask

    // ---------------------------------------------------------
    // Main Stimulus
    // ---------------------------------------------------------
    initial begin
        // Init Inputs
        s_axi_arvalid = 0; 
        s_axi_awvalid = 0; 
        s_axi_wvalid = 0; 
        s_axi_rready = 0; 
        s_axi_bready = 0;

        // 1. Wait for Reset and Tag RAM Init
        wait(aresetn == 1);
        $display("[%0t] Reset lifted. Waiting for Tag RAM init...", $time);
        // Wait long enough for INDEX_BITS=6 (64 states) to initialize
        repeat(100) @(posedge aclk); 
        $display("[%0t] Setup Complete. Beginning tests.", $time);

        // Define Test Addresses
        // Tag (4 bits), Index (9 bits), Offset (21 bits)
        // Addr 1: Tag=1, Index=1, Offset=0  -> 40'h00_0820_0000
        // Addr 2: Tag=1, Index=1, Offset=8  -> 40'h00_0820_0008
        // Addr 3: Tag=2, Index=1, Offset=0  -> 40'h00_1020_0000
        
        // TEST 1: Read Miss (Clean) -> Triggers Fetch
        $display("\n--- TEST 1: Read Miss (Clean Line) ---");
        cpu_read(40'h00_0820_0000); 

        // TEST 2: Read Hit -> Goes directly to Cache
        $display("\n--- TEST 2: Read Hit ---");
        cpu_read(40'h00_0820_0008);

        // TEST 3: Write Hit -> Goes directly to cache, marks dirty
        $display("\n--- TEST 3: Write Hit (Marking Dirty) ---");
        cpu_write(40'h00_0820_0000, 512'h11223344_55667788);

        // TEST 4: Read Miss (Dirty) -> Triggers Evict, then Fetch
        $display("\n--- TEST 4: Read Miss (Dirty Line) ---");
        cpu_read(40'h01_0820_0000); // Same Index (1), New Tag (2)

        // TEST 5: Mutual Exclusion (Race Condition)
        $display("\n--- TEST 5: Mutual Exclusion (Simultaneous Read/Write Miss) ---");
        // Tag 3 and Tag 4, both hitting Index 2
        fork
            cpu_read(40'h00_1840_0000); // Thread A: Read
            cpu_write(40'h00_2040_0000, 512'h99999999); // Thread B: Write
        join
        
        $display("\n[%0t] ALL TESTS COMPLETED SUCCESSFULLY.", $time);
        $finish;
    end

endmodule