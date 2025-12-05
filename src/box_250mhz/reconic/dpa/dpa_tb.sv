`timescale 1ns/1ps

module tb_dpa;

  // ------------------------------------------------------------
  // Parameters
  // ------------------------------------------------------------
  localparam int MIN_PKT_LEN   = 64;
  localparam int MAX_PKT_LEN   = 1518;
  localparam int USE_PHYS_FUNC = 1;
  localparam int NUM_PHYS_FUNC = 1;
  localparam int NUM_QDMA      = 1;
  localparam int NUM_CMAC_PORT = 1;

  // ------------------------------------------------------------
  // Clock & Reset
  // ------------------------------------------------------------
  logic axis_aclk;
  logic ref_clk_100mhz;
  logic s_axim_qdma2dpa_clk;
  logic dpa_rstn;

  initial begin
    axis_aclk = 0;
    forever #2.0 axis_aclk = ~axis_aclk;   // 250 MHz
  end

  initial begin
    ref_clk_100mhz = 0;
    forever #5.0 ref_clk_100mhz = ~ref_clk_100mhz; // 100 MHz
  end

  initial begin
    s_axim_qdma2dpa_clk = 0;
    forever #2 s_axim_qdma2dpa_clk = ~s_axim_qdma2dpa_clk; // ~250 MHz
  end

  initial begin
    dpa_rstn = 0;
    #100;
    dpa_rstn = 1;
  end

  // ------------------------------------------------------------
  // Packet type
  // ------------------------------------------------------------
  typedef struct packed {
    logic [511:0] data;
    logic [63:0]  keep;
    logic         last;
    logic [15:0]  size;
    logic [15:0]  src;
    logic [15:0]  dst;
  } packet_t;

  // Scoreboards (queues of expected packets)
  packet_t exp_qdma2dpa[$]; // expected on DPA->QDMA
  packet_t exp_dpa2box[$];  // expected on DPA->BOX

  // ------------------------------------------------------------
  // QDMA -> DPA stimulus signals
  // ------------------------------------------------------------
  logic        s_axis_qdma2dpa_tx_tvalid;
  logic [511:0]s_axis_qdma2dpa_tx_tdata;
  logic [63:0] s_axis_qdma2dpa_tx_tkeep;
  logic        s_axis_qdma2dpa_tx_tlast;
  logic [15:0] s_axis_qdma2dpa_tx_tuser_size;
  logic [15:0] s_axis_qdma2dpa_tx_tuser_src;
  logic [15:0] s_axis_qdma2dpa_tx_tuser_dst;
  logic        s_axis_qdma2dpa_tx_tready;

  // ------------------------------------------------------------
  // 250BOX -> DPA stimulus signals
  // ------------------------------------------------------------
  logic        s_axis_dpa2box_rx_tvalid;
  logic [511:0]s_axis_dpa2box_rx_tdata;
  logic [63:0] s_axis_dpa2box_rx_tkeep;
  logic        s_axis_dpa2box_rx_tlast;
  logic [15:0] s_axis_dpa2box_rx_tuser_size;
  logic [15:0] s_axis_dpa2box_rx_tuser_src;
  logic [15:0] s_axis_dpa2box_rx_tuser_dst;
  logic        s_axis_dpa2box_rx_tready;

  // ------------------------------------------------------------
  // Monitored interfaces
  // ------------------------------------------------------------
  wire        m_axis_qdma2dpa_rx_tvalid;
  wire [511:0]m_axis_qdma2dpa_rx_tdata;
  wire [63:0] m_axis_qdma2dpa_rx_tkeep;
  wire        m_axis_qdma2dpa_rx_tlast;
  wire [15:0] m_axis_qdma2dpa_rx_tuser_size;
  wire [15:0] m_axis_qdma2dpa_rx_tuser_src;
  wire [15:0] m_axis_qdma2dpa_rx_tuser_dst;
  logic       m_axis_qdma2dpa_rx_tready = 1;

  wire        m_axis_dpa2box_tx_tvalid;
  wire [511:0]m_axis_dpa2box_tx_tdata;
  wire [63:0] m_axis_dpa2box_tx_tkeep;
  wire        m_axis_dpa2box_tx_tlast;
  wire [15:0] m_axis_dpa2box_tx_tuser_size;
  wire [15:0] m_axis_dpa2box_tx_tuser_src;
  wire [15:0] m_axis_dpa2box_tx_tuser_dst;
  logic       m_axis_dpa2box_tx_tready = 1;

  // ------------------------------------------------------------
  // Tasks to send packets
  // ------------------------------------------------------------
  task automatic send_qdma2dpa(input packet_t pkt);
    @(posedge axis_aclk);
    s_axis_qdma2dpa_tx_tdata      <= pkt.data;
    s_axis_qdma2dpa_tx_tkeep      <= pkt.keep;
    s_axis_qdma2dpa_tx_tlast      <= pkt.last;
    s_axis_qdma2dpa_tx_tuser_size <= pkt.size;
    s_axis_qdma2dpa_tx_tuser_src  <= pkt.src;
    s_axis_qdma2dpa_tx_tuser_dst  <= pkt.dst;
    s_axis_qdma2dpa_tx_tvalid     <= 1;
    @(posedge axis_aclk);
    while (!s_axis_qdma2dpa_tx_tready) @(posedge axis_aclk);
    s_axis_qdma2dpa_tx_tvalid     <= 0;

    exp_qdma2dpa.push_back(pkt);
  endtask

  task automatic send_box2dpa(input packet_t pkt);
    @(posedge axis_aclk);
    s_axis_dpa2box_rx_tdata      <= pkt.data;
    s_axis_dpa2box_rx_tkeep      <= pkt.keep;
    s_axis_dpa2box_rx_tlast      <= pkt.last;
    s_axis_dpa2box_rx_tuser_size <= pkt.size;
    s_axis_dpa2box_rx_tuser_src  <= pkt.src;
    s_axis_dpa2box_rx_tuser_dst  <= pkt.dst;
    s_axis_dpa2box_rx_tvalid     <= 1;
    @(posedge axis_aclk);
    while (!s_axis_dpa2box_rx_tready) @(posedge axis_aclk);
    s_axis_dpa2box_rx_tvalid     <= 0;

    exp_dpa2box.push_back(pkt);
  endtask

  // ------------------------------------------------------------
  // Monitors with scoreboard check
  // ------------------------------------------------------------
  always @(posedge axis_aclk) begin
    if (m_axis_qdma2dpa_rx_tvalid && m_axis_qdma2dpa_rx_tready) begin
      packet_t got;
      got.data = m_axis_qdma2dpa_rx_tdata;
      got.keep = m_axis_qdma2dpa_rx_tkeep;
      got.last = m_axis_qdma2dpa_rx_tlast;
      got.size = m_axis_qdma2dpa_rx_tuser_size;
      got.src  = m_axis_qdma2dpa_rx_tuser_src;
      got.dst  = m_axis_qdma2dpa_rx_tuser_dst;
      if (exp_qdma2dpa.size() == 0) begin
        $error("[%0t] Unexpected packet on DPA->QDMA!", $time);
      end else begin
        packet_t exp = exp_qdma2dpa.pop_front();
        if (got !== exp)
          $error("[%0t] Mismatch on DPA->QDMA. Got=%p Exp=%p", $time, got, exp);
        else
          $display("[%0t] PASS DPA->QDMA: %p", $time, got);
      end
    end
  end

  always @(posedge axis_aclk) begin
    if (m_axis_dpa2box_tx_tvalid && m_axis_dpa2box_tx_tready) begin
      packet_t got;
      got.data = m_axis_dpa2box_tx_tdata;
      got.keep = m_axis_dpa2box_tx_tkeep;
      got.last = m_axis_dpa2box_tx_tlast;
      got.size = m_axis_dpa2box_tx_tuser_size;
      got.src  = m_axis_dpa2box_tx_tuser_src;
      got.dst  = m_axis_dpa2box_tx_tuser_dst;
      if (exp_dpa2box.size() == 0) begin
        $error("[%0t] Unexpected packet on DPA->BOX!", $time);
      end else begin
        packet_t exp = exp_dpa2box.pop_front();
        if (got !== exp)
          $error("[%0t] Mismatch on DPA->BOX. Got=%p Exp=%p", $time, got, exp);
        else
          $display("[%0t] PASS DPA->BOX: %p", $time, got);
      end
    end
  end

  // ------------------------------------------------------------
  // Randomization helper
  // ------------------------------------------------------------
  function automatic packet_t gen_random_pkt(input logic [15:0] src, input logic [15:0] dst);
    packet_t pkt;
    pkt.size = $urandom_range(MIN_PKT_LEN, MAX_PKT_LEN); // random size
    pkt.data = {$random, $random, $random, $random, $random, $random, $random, $random,
                $random, $random, $random, $random, $random, $random, $random, $random};
    pkt.keep = '1;    // assume all bytes valid (simplify)
    pkt.last = 1;
    pkt.src  = src;
    pkt.dst  = dst;
    return pkt;
  endfunction

  // ------------------------------------------------------------
  // Test sequence
  // ------------------------------------------------------------
  initial begin
    // Reset stimulus signals
    s_axis_qdma2dpa_tx_tvalid = 0;
    s_axis_qdma2dpa_tx_tdata  = '0;
    s_axis_qdma2dpa_tx_tkeep  = '0;
    s_axis_qdma2dpa_tx_tlast  = 0;
    s_axis_qdma2dpa_tx_tuser_size = '0;
    s_axis_qdma2dpa_tx_tuser_src  = '0;
    s_axis_qdma2dpa_tx_tuser_dst  = '0;

    s_axis_dpa2box_rx_tvalid = 0;
    s_axis_dpa2box_rx_tdata  = '0;
    s_axis_dpa2box_rx_tkeep  = '0;
    s_axis_dpa2box_rx_tlast  = 0;
    s_axis_dpa2box_rx_tuser_size = '0;
    s_axis_dpa2box_rx_tuser_src  = '0;
    s_axis_dpa2box_rx_tuser_dst  = '0;

    @(posedge dpa_rstn);
    repeat (10) @(posedge axis_aclk);

    // Generate and send 1024 packets
    for (int i = 0; i < 1024; i++) begin
      packet_t pkt1 = gen_random_pkt(16'h1, 16'h2); // QDMA -> DPA
      packet_t pkt2 = gen_random_pkt(16'h3, 16'h4); // BOX -> DPA

      send_qdma2dpa(pkt1);
      send_box2dpa(pkt2);

      // Insert small random delay to mix traffic
      repeat ($urandom_range(0,5)) @(posedge axis_aclk);
    end

    // Wait for scoreboard to drain
    wait (exp_qdma2dpa.size() == 0 && exp_dpa2box.size() == 0);
    $display("[%0t] All 1024 packets PASSED!", $time);
    $finish;
  end

  // ------------------------------------------------------------
  // DUT instantiation
  // ------------------------------------------------------------
  dpa #(
    .MIN_PKT_LEN   (MIN_PKT_LEN),
    .MAX_PKT_LEN   (MAX_PKT_LEN),
    .USE_PHYS_FUNC (USE_PHYS_FUNC),
    .NUM_PHYS_FUNC (NUM_PHYS_FUNC),
    .NUM_QDMA      (NUM_QDMA),
    .NUM_CMAC_PORT (NUM_CMAC_PORT)
  ) dut_dpa (
    // QDMA -> DPA
    .s_axis_qdma2dpa_tx_tvalid (s_axis_qdma2dpa_tx_tvalid),
    .s_axis_qdma2dpa_tx_tdata  (s_axis_qdma2dpa_tx_tdata),
    .s_axis_qdma2dpa_tx_tkeep  (s_axis_qdma2dpa_tx_tkeep),
    .s_axis_qdma2dpa_tx_tlast  (s_axis_qdma2dpa_tx_tlast),
    .s_axis_qdma2dpa_tx_tuser_size (s_axis_qdma2dpa_tx_tuser_size),
    .s_axis_qdma2dpa_tx_tuser_src  (s_axis_qdma2dpa_tx_tuser_src),
    .s_axis_qdma2dpa_tx_tuser_dst  (s_axis_qdma2dpa_tx_tuser_dst),
    .s_axis_qdma2dpa_tx_tready (s_axis_qdma2dpa_tx_tready),

    // DPA -> QDMA
    .m_axis_qdma2dpa_rx_tvalid (m_axis_qdma2dpa_rx_tvalid),
    .m_axis_qdma2dpa_rx_tdata  (m_axis_qdma2dpa_rx_tdata),
    .m_axis_qdma2dpa_rx_tkeep  (m_axis_qdma2dpa_rx_tkeep),
    .m_axis_qdma2dpa_rx_tlast  (m_axis_qdma2dpa_rx_tlast),
    .m_axis_qdma2dpa_rx_tuser_size (m_axis_qdma2dpa_rx_tuser_size),
    .m_axis_qdma2dpa_rx_tuser_src  (m_axis_qdma2dpa_rx_tuser_src),
    .m_axis_qdma2dpa_rx_tuser_dst  (m_axis_qdma2dpa_rx_tuser_dst),
    .m_axis_qdma2dpa_rx_tready (m_axis_qdma2dpa_rx_tready),

    // 250BOX -> DPA
    .s_axis_dpa2box_rx_tvalid (s_axis_dpa2box_rx_tvalid),
    .s_axis_dpa2box_rx_tdata  (s_axis_dpa2box_rx_tdata),
    .s_axis_dpa2box_rx_tkeep  (s_axis_dpa2box_rx_tkeep),
    .s_axis_dpa2box_rx_tlast  (s_axis_dpa2box_rx_tlast),
    .s_axis_dpa2box_rx_tuser_size (s_axis_dpa2box_rx_tuser_size),
    .s_axis_dpa2box_rx_tuser_src  (s_axis_dpa2box_rx_tuser_src),
    .s_axis_dpa2box_rx_tuser_dst  (s_axis_dpa2box_rx_tuser_dst),
    .s_axis_dpa2box_rx_tready (s_axis_dpa2box_rx_tready),

    // DPA -> 250BOX
    .m_axis_dpa2box_tx_tvalid (m_axis_dpa2box_tx_tvalid),
    .m_axis_dpa2box_tx_tdata  (m_axis_dpa2box_tx_tdata),
    .m_axis_dpa2box_tx_tkeep  (m_axis_dpa2box_tx_tkeep),
    .m_axis_dpa2box_tx_tlast  (m_axis_dpa2box_tx_tlast),
    .m_axis_dpa2box_tx_tuser_size (m_axis_dpa2box_tx_tuser_size),
    .m_axis_dpa2box_tx_tuser_src  (m_axis_dpa2box_tx_tuser_src),
    .m_axis_dpa2box_tx_tuser_dst  (m_axis_dpa2box_tx_tuser_dst),
    .m_axis_dpa2box_tx_tready (m_axis_dpa2box_tx_tready),

    // Resets & clocks
    .dpa_rstn        (dpa_rstn),
    .dpa_rst_done    (), // ignore
    `ifdef __au55c__
    .ref_clk_100mhz  (ref_clk_100mhz),
    `endif
    .axis_aclk       (axis_aclk),

    // AXI-MM unconnected
    .s_axim_qdma2dpa_clk (),

    .s_axim_qdma2dpa_araddr(),
    .s_axim_qdma2dpa_arburst(),
    .s_axim_qdma2dpa_arcache(),
    .s_axim_qdma2dpa_arid(),
    .s_axim_qdma2dpa_arlen(),
    .s_axim_qdma2dpa_arlock(),
    .s_axim_qdma2dpa_arprot(),
    .s_axim_qdma2dpa_arqos(),
    .s_axim_qdma2dpa_arready(),
    .s_axim_qdma2dpa_arsize(),
    .s_axim_qdma2dpa_aruser(),
    .s_axim_qdma2dpa_arvalid(),
    .s_axim_qdma2dpa_awaddr(),
    .s_axim_qdma2dpa_awburst(),
    .s_axim_qdma2dpa_awcache(),
    .s_axim_qdma2dpa_awid(),
    .s_axim_qdma2dpa_awlen(),
    .s_axim_qdma2dpa_awlock(),
    .s_axim_qdma2dpa_awprot(),
    .s_axim_qdma2dpa_awqos(),
    .s_axim_qdma2dpa_awready(),
    .s_axim_qdma2dpa_awsize(),
    .s_axim_qdma2dpa_awuser(),
    .s_axim_qdma2dpa_awvalid(),
    .s_axim_qdma2dpa_bid(),
    .s_axim_qdma2dpa_bready(),
    .s_axim_qdma2dpa_bresp(),
    .s_axim_qdma2dpa_bvalid(),
    .s_axim_qdma2dpa_rdata(),
    .s_axim_qdma2dpa_rid(),
    .s_axim_qdma2dpa_rlast(),
    .s_axim_qdma2dpa_rready(),
    .s_axim_qdma2dpa_rresp(),
    .s_axim_qdma2dpa_rvalid(),
    .s_axim_qdma2dpa_wdata(),
    .s_axim_qdma2dpa_wlast(),
    .s_axim_qdma2dpa_wready(),
    .s_axim_qdma2dpa_wstrb(),
    .s_axim_qdma2dpa_wuser(),
    .s_axim_qdma2dpa_wvalid()
  );

endmodule
