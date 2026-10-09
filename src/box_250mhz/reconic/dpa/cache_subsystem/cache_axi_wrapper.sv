`timescale 1ns / 1ps

`include "axi_assign.svh"
`include "axi_typedef.svh"
`include "axi_.svh"

// AXI_BUS wrapper around cache_subsystem: exposes the user-facing slave
// port and the backing-memory master port as AXI_BUS interfaces (instead
// of cache_subsystem's flattened Vivado-style ports), and internally hosts
// the cache's on-chip storage (cache_bram) plus the axi_mux_intf that
// arbitrates cache_subsystem's two cache-facing masters - m_axi_cache (the
// tag/miss path) and m_axi_pm_to_cache (the page fetch/evict movers) - down
// onto that single BRAM. The backing-memory master is registered through an
// axi_cut before reaching m_axi_mem.
module cache_axi_wrapper
    import axi_pkg::*;
#(
    parameter ADDR_WIDTH    = 32,
    parameter DATA_WIDTH    = 64,
    parameter ID_WIDTH      = 4,
    parameter MAX_BURST_LEN        = 16,

    parameter CACHE_SIZE           = 32*1024,
    parameter CACHE_BLOCK_SIZE     = 512
    
)(
    input  logic aclk,
    input  logic aresetn,

    // ---------------------------------------------------------
    // SLAVE - user logic
    // ---------------------------------------------------------
    AXI_BUS.Slave  s_axi,

    // ---------------------------------------------------------
    // MASTER - backing memory
    // ---------------------------------------------------------
    AXI_BUS.Master m_axi_mem,

    input   logic                    invalid_valid,
    input   logic [ADDR_WIDTH-1:0]   invalid_address_start,
    input   logic [ADDR_WIDTH-1:0]   invalid_address_end,
    output  logic                    invalid_done
);

    localparam OFFSET_BITS = $clog2(CACHE_BLOCK_SIZE);
    localparam INDEX_BITS  = $clog2(CACHE_SIZE) - OFFSET_BITS;
    
    
    // ---------------------------------------------------------
    // cache_subsystem's two cache-facing masters, and the mux'd bus that
    // reaches the actual cache storage
    // ---------------------------------------------------------
    localparam MUX_ID_WIDTH = ID_WIDTH + 1; // $clog2(NO_SLV_PORTS=2)

    AXI_BUS #(
        .AXI_ADDR_WIDTH(ADDR_WIDTH),
        .AXI_DATA_WIDTH(DATA_WIDTH),
        .AXI_ID_WIDTH(ID_WIDTH),
        .AXI_USER_WIDTH(0)
    ) m_cache ();

    AXI_BUS #(
        .AXI_ADDR_WIDTH(ADDR_WIDTH),
        .AXI_DATA_WIDTH(DATA_WIDTH),
        .AXI_ID_WIDTH(ID_WIDTH),
        .AXI_USER_WIDTH(0)
    ) m_pm_to_cache ();

    AXI_BUS #(
        .AXI_ADDR_WIDTH(ADDR_WIDTH),
        .AXI_DATA_WIDTH(DATA_WIDTH),
        .AXI_ID_WIDTH(MUX_ID_WIDTH),
        .AXI_USER_WIDTH(0)
    ) mux_to_cache ();

    // cache_subsystem's backing-memory master, before the axi_cut to m_axi_mem
    // (1-bit user tied to 0, so it maps onto the split_* channel types)
    AXI_BUS #(
        .AXI_ADDR_WIDTH(ADDR_WIDTH),
        .AXI_DATA_WIDTH(DATA_WIDTH),
        .AXI_ID_WIDTH(ID_WIDTH),
        .AXI_USER_WIDTH(1)
    ) m_mem ();

    // mux_to_cache after the clock crossing to the BRAM: keeps the mux's
    // port-select ID bit, which routes B/R back to the right master
    AXI_BUS #(
    .AXI_ADDR_WIDTH(ADDR_WIDTH),
    .AXI_DATA_WIDTH(DATA_WIDTH),
    .AXI_ID_WIDTH(MUX_ID_WIDTH),
    .AXI_USER_WIDTH(0)
    ) mux_to_cache_cdc ();

    // AX attributes cache_subsystem does not drive
    assign m_mem.aw_lock   = 1'b0;
    assign m_mem.aw_cache  = '0;
    assign m_mem.aw_prot   = '0;
    assign m_mem.aw_qos    = '0;
    assign m_mem.aw_region = '0;
    assign m_mem.aw_atop   = '0;
    assign m_mem.ar_lock   = 1'b0;
    assign m_mem.ar_cache  = '0;
    assign m_mem.ar_prot   = '0;
    assign m_mem.ar_qos    = '0;
    assign m_mem.ar_region = '0;
    assign m_mem.aw_user   = '0;
    assign m_mem.w_user    = '0;
    assign m_mem.ar_user   = '0;

    // ---------------------------------------------------------
    // No burst reaching the cache may cross a cache block: cache_filter
    // looks up / updates one tag per burst. axi_burst_splitter turns every
    // burst into single-beat transactions, and one beat never crosses a
    // block (CACHE_BLOCK_SIZE >= DATA_WIDTH/8).
    // ---------------------------------------------------------
    typedef logic [ADDR_WIDTH-1:0]   split_addr_t;
    typedef logic [DATA_WIDTH-1:0]   split_data_t;
    typedef logic [DATA_WIDTH/8-1:0] split_strb_t;
    typedef logic [ID_WIDTH-1:0]     split_id_t;
    typedef logic                    split_user_t;
    `AXI_TYPEDEF_ALL(split, split_addr_t, split_id_t, split_data_t, split_strb_t, split_user_t)

    split_req_t  s_axi_req_raw, s_axi_req, split_req;
    split_resp_t s_axi_resp, split_resp;

    `AXI_ASSIGN_TO_REQ(s_axi_req_raw, s_axi)
    `AXI_ASSIGN_FROM_RESP(s_axi, s_axi_resp)

    // The cache is the endpoint of these transactions, so mark them
    // modifiable: axi_burst_splitter only splits (or even passes) modifiable
    // transactions and answers non-modifiable ones <= 16 beats with SLVERR.
    always_comb begin
        s_axi_req          = s_axi_req_raw;
        s_axi_req.aw.cache = s_axi_req_raw.aw.cache | axi_pkg::CACHE_MODIFIABLE;
        s_axi_req.ar.cache = s_axi_req_raw.ar.cache | axi_pkg::CACHE_MODIFIABLE;
    end

    axi_burst_splitter #(
        .MaxReadTxns  (2),
        .MaxWriteTxns (2),
        .FullBW       (1'b0),
        .AddrWidth    (ADDR_WIDTH),
        .DataWidth    (DATA_WIDTH),
        .IdWidth      (ID_WIDTH),
        .UserWidth    (1),
        .axi_req_t    (split_req_t),
        .axi_resp_t   (split_resp_t)
    ) i_burst_splitter (
        .clk_i      (aclk),
        .rst_ni     (aresetn),
        .slv_req_i  (s_axi_req),
        .slv_resp_o (s_axi_resp),
        .mst_req_o  (split_req),
        .mst_resp_i (split_resp)
    );

    AXI_BUS #(
        .AXI_ADDR_WIDTH(ADDR_WIDTH),
        .AXI_DATA_WIDTH(DATA_WIDTH),
        .AXI_ID_WIDTH(ID_WIDTH),
        .AXI_USER_WIDTH(1)
    ) s_split ();

    `AXI_ASSIGN_FROM_REQ(s_split, split_req)
    `AXI_ASSIGN_TO_RESP(split_resp, s_split)

    initial begin
        assert (CACHE_BLOCK_SIZE >= DATA_WIDTH/8)
            else $fatal(1, "CACHE_BLOCK_SIZE (%0d) must be >= one data beat (%0d bytes)", CACHE_BLOCK_SIZE, DATA_WIDTH/8);
    end

    cache_subsystem #(
        .ADDR_WIDTH    (ADDR_WIDTH),
        .DATA_WIDTH    (DATA_WIDTH),
        .ID_WIDTH      (ID_WIDTH),
        .OFFSET_BITS   (OFFSET_BITS),
        .INDEX_BITS    (INDEX_BITS),
        .MAX_BURST_LEN (MAX_BURST_LEN),
        .PAGE_SIZE     (CACHE_BLOCK_SIZE)
    ) cache_subsystem_instance (
        .aclk(aclk),
        .aresetn(aresetn),

        // user logic slave
        .s_axi_arid    (s_split.ar_id),
        .s_axi_araddr  (s_split.ar_addr),
        .s_axi_arlen   (s_split.ar_len),
        .s_axi_arsize  (s_split.ar_size),
        .s_axi_arburst (s_split.ar_burst),
        .s_axi_arvalid (s_split.ar_valid),
        .s_axi_arready (s_split.ar_ready),

        .s_axi_rid     (s_split.r_id),
        .s_axi_rdata   (s_split.r_data),
        .s_axi_rresp   (s_split.r_resp),
        .s_axi_rlast   (s_split.r_last),
        .s_axi_rvalid  (s_split.r_valid),
        .s_axi_rready  (s_split.r_ready),

        .s_axi_awid    (s_split.aw_id),
        .s_axi_awaddr  (s_split.aw_addr),
        .s_axi_awlen   (s_split.aw_len),
        .s_axi_awsize  (s_split.aw_size),
        .s_axi_awburst (s_split.aw_burst),
        .s_axi_awvalid (s_split.aw_valid),
        .s_axi_awready (s_split.aw_ready),

        .s_axi_wdata   (s_split.w_data),
        .s_axi_wstrb   (s_split.w_strb),
        .s_axi_wlast   (s_split.w_last),
        .s_axi_wvalid  (s_split.w_valid),
        .s_axi_wready  (s_split.w_ready),

        .s_axi_bid     (s_split.b_id),
        .s_axi_bresp   (s_split.b_resp),
        .s_axi_bvalid  (s_split.b_valid),
        .s_axi_bready  (s_split.b_ready),

        // cache memory master (tag/miss path) -> m_cache
        .m_axi_cache_arid    (m_cache.ar_id),
        .m_axi_cache_araddr  (m_cache.ar_addr),
        .m_axi_cache_arlen   (m_cache.ar_len),
        .m_axi_cache_arsize  (m_cache.ar_size),
        .m_axi_cache_arburst (m_cache.ar_burst),
        .m_axi_cache_arvalid (m_cache.ar_valid),
        .m_axi_cache_arready (m_cache.ar_ready),

        .m_axi_cache_rid     (m_cache.r_id),
        .m_axi_cache_rdata   (m_cache.r_data),
        .m_axi_cache_rresp   (m_cache.r_resp),
        .m_axi_cache_rvalid  (m_cache.r_valid),
        .m_axi_cache_rready  (m_cache.r_ready),
        .m_axi_cache_rlast   (m_cache.r_last),

        .m_axi_cache_awid    (m_cache.aw_id),
        .m_axi_cache_awaddr  (m_cache.aw_addr),
        .m_axi_cache_awlen   (m_cache.aw_len),
        .m_axi_cache_awsize  (m_cache.aw_size),
        .m_axi_cache_awburst (m_cache.aw_burst),
        .m_axi_cache_awvalid (m_cache.aw_valid),
        .m_axi_cache_awready (m_cache.aw_ready),

        .m_axi_cache_wdata   (m_cache.w_data),
        .m_axi_cache_wstrb   (m_cache.w_strb),
        .m_axi_cache_wlast   (m_cache.w_last),
        .m_axi_cache_wvalid  (m_cache.w_valid),
        .m_axi_cache_wready  (m_cache.w_ready),

        .m_axi_cache_bid     (m_cache.b_id),
        .m_axi_cache_bresp   (m_cache.b_resp),
        .m_axi_cache_bvalid  (m_cache.b_valid),
        .m_axi_cache_bready  (m_cache.b_ready),

        // cache memory master (page fetch/evict movers) -> m_pm_to_cache
        .m_axi_pm_to_cache_arid    (m_pm_to_cache.ar_id),
        .m_axi_pm_to_cache_araddr  (m_pm_to_cache.ar_addr),
        .m_axi_pm_to_cache_arlen   (m_pm_to_cache.ar_len),
        .m_axi_pm_to_cache_arsize  (m_pm_to_cache.ar_size),
        .m_axi_pm_to_cache_arburst (m_pm_to_cache.ar_burst),
        .m_axi_pm_to_cache_arvalid (m_pm_to_cache.ar_valid),
        .m_axi_pm_to_cache_arready (m_pm_to_cache.ar_ready),

        .m_axi_pm_to_cache_rid     (m_pm_to_cache.r_id),
        .m_axi_pm_to_cache_rdata   (m_pm_to_cache.r_data),
        .m_axi_pm_to_cache_rresp   (m_pm_to_cache.r_resp),
        .m_axi_pm_to_cache_rvalid  (m_pm_to_cache.r_valid),
        .m_axi_pm_to_cache_rready  (m_pm_to_cache.r_ready),
        .m_axi_pm_to_cache_rlast   (m_pm_to_cache.r_last),

        .m_axi_pm_to_cache_awid    (m_pm_to_cache.aw_id),
        .m_axi_pm_to_cache_awaddr  (m_pm_to_cache.aw_addr),
        .m_axi_pm_to_cache_awlen   (m_pm_to_cache.aw_len),
        .m_axi_pm_to_cache_awsize  (m_pm_to_cache.aw_size),
        .m_axi_pm_to_cache_awburst (m_pm_to_cache.aw_burst),
        .m_axi_pm_to_cache_awvalid (m_pm_to_cache.aw_valid),
        .m_axi_pm_to_cache_awready (m_pm_to_cache.aw_ready),

        .m_axi_pm_to_cache_wdata   (m_pm_to_cache.w_data),
        .m_axi_pm_to_cache_wstrb   (m_pm_to_cache.w_strb),
        .m_axi_pm_to_cache_wlast   (m_pm_to_cache.w_last),
        .m_axi_pm_to_cache_wvalid  (m_pm_to_cache.w_valid),
        .m_axi_pm_to_cache_wready  (m_pm_to_cache.w_ready),

        .m_axi_pm_to_cache_bid     (m_pm_to_cache.b_id),
        .m_axi_pm_to_cache_bresp   (m_pm_to_cache.b_resp),
        .m_axi_pm_to_cache_bvalid  (m_pm_to_cache.b_valid),
        .m_axi_pm_to_cache_bready  (m_pm_to_cache.b_ready),

        // backing memory master -> m_mem, spill-registered onto m_axi_mem
        .m_axi_mem_arid    (m_mem.ar_id),
        .m_axi_mem_araddr  (m_mem.ar_addr),
        .m_axi_mem_arlen   (m_mem.ar_len),
        .m_axi_mem_arsize  (m_mem.ar_size),
        .m_axi_mem_arburst (m_mem.ar_burst),
        .m_axi_mem_arvalid (m_mem.ar_valid),
        .m_axi_mem_arready (m_mem.ar_ready),

        .m_axi_mem_rid     (m_mem.r_id),
        .m_axi_mem_rdata   (m_mem.r_data),
        .m_axi_mem_rresp   (m_mem.r_resp),
        .m_axi_mem_rvalid  (m_mem.r_valid),
        .m_axi_mem_rready  (m_mem.r_ready),
        .m_axi_mem_rlast   (m_mem.r_last),

        .m_axi_mem_awid    (m_mem.aw_id),
        .m_axi_mem_awaddr  (m_mem.aw_addr),
        .m_axi_mem_awlen   (m_mem.aw_len),
        .m_axi_mem_awsize  (m_mem.aw_size),
        .m_axi_mem_awburst (m_mem.aw_burst),
        .m_axi_mem_awvalid (m_mem.aw_valid),
        .m_axi_mem_awready (m_mem.aw_ready),

        .m_axi_mem_wdata   (m_mem.w_data),
        .m_axi_mem_wstrb   (m_mem.w_strb),
        .m_axi_mem_wlast   (m_mem.w_last),
        .m_axi_mem_wvalid  (m_mem.w_valid),
        .m_axi_mem_wready  (m_mem.w_ready),

        .m_axi_mem_bid     (m_mem.b_id),
        .m_axi_mem_bresp   (m_mem.b_resp),
        .m_axi_mem_bvalid  (m_mem.b_valid),
        .m_axi_mem_bready  (m_mem.b_ready),

        .invalid_valid,
        .invalid_address_start,
        .invalid_address_end,
        .invalid_done
    );

    // ---------------------------------------------------------
    // Spill register on every channel of the backing-memory master: breaks
    // the combinational paths between cache_subsystem and the memory side
    // ---------------------------------------------------------
    // Struct-based axi_cut: axi_cut_intf requires identical in/out widths,
    // while m_axi_mem has a narrower ID and no user bits. The narrowing
    // happens in the assigns below, as the direct port connection did (the
    // backing-memory IDs are constants that fit m_axi_mem).
    split_req_t  mem_cut_in_req,  mem_cut_out_req;
    split_resp_t mem_cut_in_resp, mem_cut_out_resp;

    `AXI_ASSIGN_TO_REQ(mem_cut_in_req, m_mem)
    `AXI_ASSIGN_FROM_RESP(m_mem, mem_cut_in_resp)

    axi_cut #(
        .Bypass     (1'b0),
        .aw_chan_t  (split_aw_chan_t),
        .w_chan_t   (split_w_chan_t),
        .b_chan_t   (split_b_chan_t),
        .ar_chan_t  (split_ar_chan_t),
        .r_chan_t   (split_r_chan_t),
        .axi_req_t  (split_req_t),
        .axi_resp_t (split_resp_t)
    ) i_mem_cut (
        .clk_i      (aclk),
        .rst_ni     (aresetn),
        .slv_req_i  (mem_cut_in_req),
        .slv_resp_o (mem_cut_in_resp),
        .mst_req_o  (mem_cut_out_req),
        .mst_resp_i (mem_cut_out_resp)
    );

    `AXI_ASSIGN_FROM_REQ(m_axi_mem, mem_cut_out_req)
    `AXI_ASSIGN_TO_RESP(mem_cut_out_resp, m_axi_mem)

    // ---------------------------------------------------------
    // Arbitrate the two cache-facing masters onto the single cache BRAM
    // ---------------------------------------------------------
    axi_mux_intf #(
        .SLV_AXI_ID_WIDTH (ID_WIDTH),
        .MST_AXI_ID_WIDTH (MUX_ID_WIDTH),
        .AXI_ADDR_WIDTH   (ADDR_WIDTH),
        .AXI_DATA_WIDTH   (DATA_WIDTH),
        .AXI_USER_WIDTH   (0),
        .NO_SLV_PORTS     (2),
        .MAX_W_TRANS      (1),
        .FALL_THROUGH     (0),
        .SPILL_AW (1), .SPILL_W (1), .SPILL_B (1),
        .SPILL_AR (1), .SPILL_R (1)
    ) axi_mux_instance (
        .clk_i  (aclk),
        .rst_ni (aresetn),
        .test_i (1'b0),
        .slv    ({m_pm_to_cache, m_cache}),
        .mst    (mux_to_cache)
    );

    logic bram_aclk;

    BUFGCE_DIV #(
    .BUFGCE_DIVIDE ( 2 )
    ) i_bufgce_div_cache (
      .O   ( bram_aclk ), // CACHE 125 MHz
      .CE  ( 1'b1       ),
      .CLR ( 1'b0       ),
      .I   ( aclk  )  // 250 MHz
    );

    // BRAM-domain reset: asserted with aresetn, released on bram_aclk.
    // Plain synchronizer instead of rstgen: on FPGA rstgen's test-mode bypass
    // (tc_clk_mux2) is a BUFGMUX, and aresetn already comes out of one, so a
    // second rstgen here forms an unplaceable BUFG->BUFG cascade.
    (* ASYNC_REG = "TRUE" *) logic [1:0] bram_rst_q;
    logic bram_arstn;

    always_ff @(posedge bram_aclk or negedge aresetn) begin
        if (!aresetn) bram_rst_q <= 2'b00;
        else          bram_rst_q <= {bram_rst_q[0], 1'b1};
    end

    assign bram_arstn = bram_rst_q[1];

    axi_cdc_intf #(
        .AXI_ID_WIDTH(MUX_ID_WIDTH),
        .AXI_ADDR_WIDTH(ADDR_WIDTH),
        .AXI_DATA_WIDTH(DATA_WIDTH),
        .AXI_USER_WIDTH(0),
        .LOG_DEPTH(3),
        .SYNC_STAGES(2)
    ) axi_cdc_intf_instance (

        .src_clk_i(aclk),
        .src_rst_ni(aresetn),
        .src(mux_to_cache),

        .dst_clk_i(bram_aclk),
        .dst_rst_ni(bram_arstn),
        .dst(mux_to_cache_cdc)
    );
    // ---------------------------------------------------------
    // On-chip cache storage
    // ---------------------------------------------------------
    cache_bram #(
        .ADDR_WIDTH       (ADDR_WIDTH),
        .CACHE_ADDR_WIDTH (OFFSET_BITS + INDEX_BITS),
        .DATA_WIDTH       (DATA_WIDTH),
        .ID_WIDTH         (MUX_ID_WIDTH)
    ) cache_bram_instance (
        .aclk    (bram_aclk),
        .aresetn (bram_arstn),
        .slv     (mux_to_cache_cdc)
    );

endmodule
