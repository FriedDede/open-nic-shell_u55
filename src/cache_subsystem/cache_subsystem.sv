`include "axi_assign.svh"
`include "axi_typedef.svh"
`include "axi_.svh"

module cache_subsystem 
    import cache_ss_pkg::*;
    import axi_pkg::*;
#(
    parameter ADDR_WIDTH    = 40,
    parameter DATA_WIDTH    = 512, // Standard AXI width
    parameter ID_WIDTH      = 4,
    parameter OFFSET_BITS   = 21,   // 2 MB cache line
    parameter INDEX_BITS    = 13,   // 16GB HBM

    parameter MAX_BURST_LEN = 256,
    parameter PAGE_SIZE     = 2*1024*1024
)
(
    input  logic                    aclk,
    input  logic                    aresetn,

    // ---------------------------------------------------------
    // SLAVE - user logic
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
    // MASTER - CACHE memory 
    // ---------------------------------------------------------

    output logic [ID_WIDTH-1:0]     m_axi_cache_arid,
    output logic [ADDR_WIDTH-1:0]   m_axi_cache_araddr,
    output logic [7:0]              m_axi_cache_arlen,   // Fixed to 255 (256 beats)
    output logic [2:0]              m_axi_cache_arsize,  // Fixed to 6 (64 bytes)
    output logic [1:0]              m_axi_cache_arburst, // INCR type
    output logic                    m_axi_cache_arvalid,
    input  logic                    m_axi_cache_arready,

    input logic [ID_WIDTH-1:0]      m_axi_cache_rid,
    input  logic [DATA_WIDTH-1:0]   m_axi_cache_rdata,
    input logic [1:0]               m_axi_cache_rresp,
    input  logic                    m_axi_cache_rvalid,
    output logic                    m_axi_cache_rready,
    input  logic                    m_axi_cache_rlast,

    output logic [ID_WIDTH-1:0]     m_axi_cache_awid,
    output logic [ADDR_WIDTH-1:0]   m_axi_cache_awaddr,
    output logic [7:0]              m_axi_cache_awlen,
    output logic [2:0]              m_axi_cache_awsize,
    output logic [1:0]              m_axi_cache_awburst,
    output logic                    m_axi_cache_awvalid,
    input  logic                    m_axi_cache_awready,

    output logic [DATA_WIDTH-1:0]   m_axi_cache_wdata,
    output logic                    m_axi_cache_wstrb, // All 1s (Write full width)
    output logic                    m_axi_cache_wlast,
    output logic                    m_axi_cache_wvalid,
    input  logic                    m_axi_cache_wready,

    input logic [ID_WIDTH-1:0]      m_axi_cache_bid,
    input  logic [1:0]              m_axi_cache_bresp,
    input  logic                    m_axi_cache_bvalid,
    output logic                    m_axi_cache_bready,

    // ---------------------------------------------------------
    // MASTER - CACHE memory 
    // ---------------------------------------------------------

    output logic [ID_WIDTH-1:0]     m_axi_pm_to_cache_arid,
    output logic [ADDR_WIDTH-1:0]   m_axi_pm_to_cache_araddr,
    output logic [7:0]              m_axi_pm_to_cache_arlen,   // Fixed to 255 (256 beats)
    output logic [2:0]              m_axi_pm_to_cache_arsize,  // Fixed to 6 (64 bytes)
    output logic [1:0]              m_axi_pm_to_cache_arburst, // INCR type
    output logic                    m_axi_pm_to_cache_arvalid,
    input  logic                    m_axi_pm_to_cache_arready,

    input logic [ID_WIDTH-1:0]      m_axi_pm_to_cache_rid,
    input  logic [DATA_WIDTH-1:0]   m_axi_pm_to_cache_rdata,
    input logic [1:0]               m_axi_pm_to_cache_rresp,
    input  logic                    m_axi_pm_to_cache_rvalid,
    output logic                    m_axi_pm_to_cache_rready,
    input  logic                    m_axi_pm_to_cache_rlast,

    output logic [ID_WIDTH-1:0]     m_axi_pm_to_cache_awid,
    output logic [ADDR_WIDTH-1:0]   m_axi_pm_to_cache_awaddr,
    output logic [7:0]              m_axi_pm_to_cache_awlen,
    output logic [2:0]              m_axi_pm_to_cache_awsize,
    output logic [1:0]              m_axi_pm_to_cache_awburst,
    output logic                    m_axi_pm_to_cache_awvalid,
    input  logic                    m_axi_pm_to_cache_awready,

    output logic [DATA_WIDTH-1:0]   m_axi_pm_to_cache_wdata,
    output logic                    m_axi_pm_to_cache_wstrb, // All 1s (Write full width)
    output logic                    m_axi_pm_to_cache_wlast,
    output logic                    m_axi_pm_to_cache_wvalid,
    input  logic                    m_axi_pm_to_cache_wready,
    
    input logic [ID_WIDTH-1:0]      m_axi_pm_to_cache_bid,
    input  logic [1:0]              m_axi_pm_to_cache_bresp,
    input  logic                    m_axi_pm_to_cache_bvalid,
    output logic                    m_axi_pm_to_cache_bready,

    // ---------------------------------------------------------
    // MASTER - BACKING memory
    // ---------------------------------------------------------

    output logic [ID_WIDTH-1:0]     m_axi_mem_arid,
    output logic [ADDR_WIDTH-1:0]   m_axi_mem_araddr,
    output logic [7:0]              m_axi_mem_arlen,   // Fixed to 255 (256 beats)
    output logic [2:0]              m_axi_mem_arsize,  // Fixed to 6 (64 bytes)
    output logic [1:0]              m_axi_mem_arburst, // INCR type
    output logic                    m_axi_mem_arvalid,
    input  logic                    m_axi_mem_arready,

    input  logic [ID_WIDTH-1:0]     m_axi_mem_rid,
    input  logic [DATA_WIDTH-1:0]   m_axi_mem_rdata,
    input  logic [1:0]              m_axi_mem_rresp,
    input  logic                    m_axi_mem_rvalid,
    output logic                    m_axi_mem_rready,
    input  logic                    m_axi_mem_rlast,

    output logic [ID_WIDTH-1:0]     m_axi_mem_awid,
    output logic [ADDR_WIDTH-1:0]   m_axi_mem_awaddr,
    output logic [7:0]              m_axi_mem_awlen,
    output logic [2:0]              m_axi_mem_awsize,
    output logic [1:0]              m_axi_mem_awburst,
    output logic                    m_axi_mem_awvalid,
    input  logic                    m_axi_mem_awready,

    output logic [DATA_WIDTH-1:0]   m_axi_mem_wdata,
    output logic                    m_axi_mem_wstrb, // All 1s (Write full width)
    output logic                    m_axi_mem_wlast,
    output logic                    m_axi_mem_wvalid,
    input  logic                    m_axi_mem_wready,

    input  logic [ID_WIDTH-1:0]     m_axi_mem_bid,
    input  logic [1:0]              m_axi_mem_bresp,
    input  logic                    m_axi_mem_bvalid,
    output logic                    m_axi_mem_bready

);

logic                    fetch_start;   
logic [ADDR_WIDTH-1:0]   fetch_src_addr;
logic [ADDR_WIDTH-1:0]   fetch_dst_addr;
logic                    fetch_done;    
logic                    fetch_idle;    

logic                    evict_start;   
logic [ADDR_WIDTH-1:0]   evict_src_addr;
logic [ADDR_WIDTH-1:0]   evict_dst_addr;
logic                    evict_done;    
logic                    evict_idle;    

AXI_BUS #(
    .AXI_ADDR_WIDTH(ADDR_WIDTH),
    .AXI_DATA_WIDTH(DATA_WIDTH),
    .AXI_ID_WIDTH(ID_WIDTH),
    .AXI_USER_WIDTH(0)
) m_pm_to_cache ();

AXI_BUS #(
    .AXI_ADDR_WIDTH(ADDR_WIDTH),
    .AXI_DATA_WIDTH(DATA_WIDTH),
    .AXI_ID_WIDTH(ID_WIDTH),
    .AXI_USER_WIDTH(0)
) m_cf_to_cache ();

//  AXI_BUS #(
//      .AXI_ADDR_WIDTH(ADDR_WIDTH),
//      .AXI_DATA_WIDTH(DATA_WIDTH),
//      .AXI_ID_WIDTH(ID_WIDTH + 1),
//      .AXI_USER_WIDTH(0)
//  ) mux_to_cache ();
//  
//  axi_mux_intf #(
//      .SLV_AXI_ID_WIDTH(ID_WIDTH),
//      .MST_AXI_ID_WIDTH(ID_WIDTH + 2),
//      .AXI_ADDR_WIDTH(ADDR_WIDTH),
//      .AXI_DATA_WIDTH(DATA_WIDTH),
//      .AXI_USER_WIDTH(0),
//      .NO_SLV_PORTS(3),
//      .MAX_W_TRANS(1),
//      .FALL_THROUGH(0),
//      .SPILL_AW (0),
//      .SPILL_W  (0),
//      .SPILL_B  (0),
//      .SPILL_AR (0),
//      .SPILL_R  (0)
//  ) axi_mux_intf_instance (
//      .clk_i(aclk),
//      .rst_ni(aresetn),
//      .test_i(0),
//      .slv({m_pm_to_cache,m_cf_to_cache}),
//      .mst(mux_to_cache)
//  );

`AXI_ASSIGN_BUS_MASTER_TO_FLAT(cache, m_cf_to_cache)
`AXI_ASSIGN_BUS_MASTER_TO_FLAT(pm_to_cache, m_pm_to_cache)

cache_filter #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .OFFSET_BITS(OFFSET_BITS),
    .INDEX_BITS(INDEX_BITS)
) cache_filter_instance (
    .aclk(aclk),
    .aresetn(aresetn),
 // user logic slave
    .s_axi_arid(s_axi_arid),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arlen(s_axi_arlen),
    .s_axi_arsize(s_axi_arsize),
    .s_axi_arburst(s_axi_arburst),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),

    .s_axi_rid(s_axi_rid),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rlast(s_axi_rlast),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),

    .s_axi_awid(s_axi_awid),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awlen(s_axi_awlen),
    .s_axi_awsize(s_axi_awsize),
    .s_axi_awburst(s_axi_awburst),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),

    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wlast(s_axi_wlast),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),

    .s_axi_bid(s_axi_bid),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),

// cache memory master
    .m_cache_arid   (m_cf_to_cache.ar_id),
    .m_cache_araddr (m_cf_to_cache.ar_addr),
    .m_cache_arlen  (m_cf_to_cache.ar_len),
    .m_cache_arsize (m_cf_to_cache.ar_size),
    .m_cache_arburst(m_cf_to_cache.ar_burst),
    .m_cache_arvalid(m_cf_to_cache.ar_valid),
    .m_cache_arready(m_cf_to_cache.ar_ready),

    .m_cache_rid    (m_cf_to_cache.r_id),
    .m_cache_rdata  (m_cf_to_cache.r_data),
    .m_cache_rresp  (m_cf_to_cache.r_resp),
    .m_cache_rlast  (m_cf_to_cache.r_last),
    .m_cache_rvalid (m_cf_to_cache.r_valid),
    .m_cache_rready (m_cf_to_cache.r_ready),

    .m_cache_awid   (m_cf_to_cache.aw_id),
    .m_cache_awaddr (m_cf_to_cache.aw_addr),
    .m_cache_awlen  (m_cf_to_cache.aw_len),
    .m_cache_awsize (m_cf_to_cache.aw_size),
    .m_cache_awburst(m_cf_to_cache.aw_burst),
    .m_cache_awvalid(m_cf_to_cache.aw_valid),
    .m_cache_awready(m_cf_to_cache.aw_ready),

    .m_cache_wdata  (m_cf_to_cache.w_data),
    .m_cache_wstrb  (m_cf_to_cache.w_strb),
    .m_cache_wlast  (m_cf_to_cache.w_last),
    .m_cache_wvalid (m_cf_to_cache.w_valid),
    .m_cache_wready (m_cf_to_cache.w_ready),

    .m_cache_bid    (m_cf_to_cache.b_id),
    .m_cache_bresp  (m_cf_to_cache.b_resp),
    .m_cache_bvalid (m_cf_to_cache.b_valid),
    .m_cache_bready (m_cf_to_cache.b_ready),
    
// fecth engine control master
    .o_start_page_fetch     (fetch_start),
    .o_page_addr_fetch      (fetch_src_addr),
    .o_cache_page_addr_fetch(fetch_dst_addr),
    .i_done_fetch           (fetch_done),
    .i_idle_fetch           (fetch_idle),
// evict engine control master
    .o_start_page_evict     (evict_start),
    .o_page_addr_evict      (evict_src_addr),
    .o_cache_page_addr_evict(evict_dst_addr),
    .i_done_evict           (evict_done),
    .i_idle_evict           (evict_idle)
);

// fecth page mover
// WRITE DIRECTION: CACHE
// READ  DIRECTION: MEM

page_mover #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .MAX_BURST_LEN(MAX_BURST_LEN),
    .PAGE_SIZE(PAGE_SIZE)
) i_pm_fetch (
    .aclk(aclk),
    .aresetn(aresetn),

    .i_start        (fetch_start),
    .i_src_addr     (fetch_src_addr),
    .i_dst_addr     (fetch_dst_addr),
    .o_done         (fetch_done),
    .o_idle         (fetch_idle),

    // fetcher reads from host memory and writes in cache
    .m_src_araddr   (m_axi_mem_araddr),
    .m_src_arlen    (m_axi_mem_arlen),
    .m_src_arsize   (m_axi_mem_arsize),
    .m_src_arburst  (m_axi_mem_arburst),
    .m_src_arvalid  (m_axi_mem_arvalid),
    .m_src_arready  (m_axi_mem_arready),

    .m_src_rdata    (m_axi_mem_rdata),
    .m_src_rvalid   (m_axi_mem_rvalid),
    .m_src_rready   (m_axi_mem_rready),
    .m_src_rlast    (m_axi_mem_rlast),

    .m_dst_awaddr   (m_pm_to_cache.aw_addr),
    .m_dst_awlen    (m_pm_to_cache.aw_len),
    .m_dst_awsize   (m_pm_to_cache.aw_size),
    .m_dst_awburst  (m_pm_to_cache.aw_burst),
    .m_dst_awvalid  (m_pm_to_cache.aw_valid),
    .m_dst_awready  (m_pm_to_cache.aw_ready),

    .m_dst_wdata    (m_pm_to_cache.w_data),
    .m_dst_wstrb    (m_pm_to_cache.w_strb),
    .m_dst_wlast    (m_pm_to_cache.w_last),
    .m_dst_wvalid   (m_pm_to_cache.w_valid),
    .m_dst_wready   (m_pm_to_cache.w_ready),

    .m_dst_bresp    (m_pm_to_cache.b_resp),
    .m_dst_bvalid   (m_pm_to_cache.b_valid),
    .m_dst_bready   (m_pm_to_cache.b_ready)
);

assign m_pm_to_cache.aw_id = 4'b0010;
assign m_axi_mem_arid = 4'b0010;
assign m_axi_mem_rid = 4'b0010;

// eviction page mover
// WRITE DIRECTION: MEM
// READ  DIRECTION: CACHE

page_mover #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .MAX_BURST_LEN(MAX_BURST_LEN),
    .PAGE_SIZE(PAGE_SIZE)
) i_pm_evict (

    .aclk(aclk),
    .aresetn(aresetn),

    .i_start        (evict_start),
    .i_src_addr     (evict_src_addr),
    .i_dst_addr     (evict_dst_addr),
    .o_done         (evict_done),
    .o_idle         (evict_idle),

    // evicter reads from cache and write in host memory
    .m_src_araddr   (m_pm_to_cache.ar_addr),
    .m_src_arlen    (m_pm_to_cache.ar_len),
    .m_src_arsize   (m_pm_to_cache.ar_size),
    .m_src_arburst  (m_pm_to_cache.ar_burst),
    .m_src_arvalid  (m_pm_to_cache.ar_valid),
    .m_src_arready  (m_pm_to_cache.ar_ready),

    .m_src_rdata    (m_pm_to_cache.r_data),
    .m_src_rvalid   (m_pm_to_cache.r_valid),
    .m_src_rready   (m_pm_to_cache.r_ready),
    .m_src_rlast    (m_pm_to_cache.r_last),

    .m_dst_awaddr   (m_axi_mem_awaddr),
    .m_dst_awlen    (m_axi_mem_awlen),
    .m_dst_awsize   (m_axi_mem_awsize),
    .m_dst_awburst  (m_axi_mem_awburst),
    .m_dst_awvalid  (m_axi_mem_awvalid),
    .m_dst_awready  (m_axi_mem_awready),

    .m_dst_wdata    (m_axi_mem_wdata),
    .m_dst_wstrb    (m_axi_mem_wstrb),
    .m_dst_wlast    (m_axi_mem_wlast),
    .m_dst_wvalid   (m_axi_mem_wvalid),
    .m_dst_wready   (m_axi_mem_wready),

    .m_dst_bresp    (m_axi_mem_bresp),
    .m_dst_bvalid   (m_axi_mem_bvalid),
    .m_dst_bready   (m_axi_mem_bready)
);

assign m_pm_to_cache.ar_id = 4'b0001;
assign m_axi_mem_awid      = 4'b0001;

initial begin
    assert (PAGE_SIZE == (1 << OFFSET_BITS))
    else $fatal(1, "PAGE_SIZE (%0d) must be equal to 2**OFFSET_BITS (2**%0d)", PAGE_SIZE, OFFSET_BITS);
end

endmodule