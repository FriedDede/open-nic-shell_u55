`timescale 1ns / 1ps

module tb_page_mover();

    // ---------------------------------------------------------
    // Parameters (Scaled down for simulation speed)
    // ---------------------------------------------------------
    parameter ADDR_WIDTH = 34;
    parameter DATA_WIDTH = 512;
    parameter MAX_BURST_LEN = 16;
    // Scale down: 4 bursts of 256 beats (64 bytes/beat) = 64KB page instead of 2MB
    parameter PAGE_SIZE = 2 * 1024 * 1024; 

    // ---------------------------------------------------------
    // Signals
    // ---------------------------------------------------------
    logic aclk = 0;
    logic aresetn = 0;

    // Control
    logic i_start = 0;
    logic [ADDR_WIDTH-1:0] i_src_addr = 40'h1000_0000;
    logic [ADDR_WIDTH-1:0] i_dst_addr = 40'h2000_0000;
    logic o_done, o_idle;

    // Source AXI (Read Only)
    logic [ADDR_WIDTH-1:0] m_src_araddr;
    logic [7:0] m_src_arlen;
    logic m_src_arvalid;
    logic m_src_arready;
    logic [DATA_WIDTH-1:0] m_src_rdata;
    logic m_src_rvalid;
    logic m_src_rready;
    logic m_src_rlast;

    // Dest AXI (Write Only)
    logic [ADDR_WIDTH-1:0] m_dst_awaddr;
    logic [7:0] m_dst_awlen;
    logic m_dst_awvalid;
    logic m_dst_awready;
    logic [DATA_WIDTH-1:0] m_dst_wdata;
    logic m_dst_wvalid;
    logic m_dst_wready;
    logic m_dst_wlast;
    logic [1:0] m_dst_bresp;
    logic m_dst_bvalid;
    logic m_dst_bready;

    // ---------------------------------------------------------
    // Clock & Reset
    // ---------------------------------------------------------
    always #5 aclk = ~aclk; // 100MHz clock

    initial begin
        aresetn = 0;
        #50 aresetn = 1;
    end

    // ---------------------------------------------------------
    // DUT Instantiation
    // ---------------------------------------------------------
    page_mover #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .PAGE_SIZE(PAGE_SIZE)
    ) dut (
        .aclk(aclk), 
        .aresetn(aresetn),
        
        .i_start(i_start), 
        .i_src_addr(i_src_addr), 
        .i_dst_addr(i_dst_addr),

        .o_done(o_done), 
        .o_idle(o_idle),

        .m_src_araddr(m_src_araddr), 
        .m_src_arlen(m_src_arlen), 
        .m_src_arsize(), 
        .m_src_arburst(), // Ignored in simple TB
        .m_src_arvalid(m_src_arvalid), 
        .m_src_arready(m_src_arready),
        .m_src_rdata(m_src_rdata), 
        .m_src_rvalid(m_src_rvalid),
        .m_src_rready(m_src_rready), 
        .m_src_rlast(m_src_rlast),

        .m_dst_awaddr(m_dst_awaddr), 
        .m_dst_awlen(m_dst_awlen),
        .m_dst_awsize(), 
        .m_dst_awburst(),
        .m_dst_awvalid(m_dst_awvalid), 
        .m_dst_awready(m_dst_awready),
        .m_dst_wdata(m_dst_wdata), 
        .m_dst_wstrb(), 
        .m_dst_wlast(m_dst_wlast), 
        .m_dst_wvalid(m_dst_wvalid),
        .m_dst_wready(m_dst_wready),
        .m_dst_bresp(m_dst_bresp), 
        .m_dst_bvalid(m_dst_bvalid),
        .m_dst_bready(m_dst_bready)
    );

    // ---------------------------------------------------------
    // Mock Source Memory (Responds to AR with R data)
    // ---------------------------------------------------------
    initial begin
        m_src_arready = 0;
        m_src_rvalid = 0;
        m_src_rdata = 0;
        m_src_rlast = 0;

        forever begin
            @(posedge aclk);
            m_src_arready <= 1; // Always ready for address

            if (m_src_arvalid && m_src_arready) begin
                $display("Fetching addr:  0x%0h...", m_src_araddr);
                m_src_arready <= 0;
                
                // Serve burst
                for (int i = 0; i <= m_src_arlen; i++) begin
                    m_src_rvalid <= 1;
                    m_src_rdata  <= {16{32'(i)}}; // Fill with counter data
                    m_src_rlast  <= (i == m_src_arlen);
                    
                    @(posedge aclk);
                    while (!m_src_rready) @(posedge aclk); // Wait if Mover isn't ready
                end
                
                m_src_rvalid <= 0;
                m_src_rlast  <= 0;
            end
        end
    end

    // ---------------------------------------------------------
    // Mock Dest Memory (Responds to AW/W with B)
    // ---------------------------------------------------------
    initial begin
        m_dst_awready = 0;
        m_dst_wready  = 0;
        m_dst_bvalid  = 0;
        m_dst_bresp   = 2'b00; // OKAY

        forever begin
            @(posedge aclk);
            m_dst_awready <= 1;
            m_dst_wready  <= 1; // Can add random stalls here to test FIFO

            if (m_dst_awvalid) begin
                 $display("Caching to addr:  0x%0h...", m_dst_awaddr);
            end

            if (m_dst_wvalid && m_dst_wready && m_dst_wlast) begin
                // End of burst, send response
                @(posedge aclk);
                m_dst_bvalid <= 1;
                @(posedge aclk);
                while (!m_dst_bready) @(posedge aclk);
                m_dst_bvalid <= 0;
            end
        end
    end

    // ---------------------------------------------------------
    // Main Test Stimulus
    // ---------------------------------------------------------
    initial begin
        $display("Starting Page Mover Test...");
        
        wait(aresetn == 1);
        @(posedge aclk);
        
        // Trigger transfer
        i_start = 1;
        @(posedge aclk);
        i_start = 0;

        // Wait for completion
        wait(o_done == 1);
        @(posedge aclk);
        
        $display("Page Mover Test Completed Successfully!");
        $finish;
    end

endmodule