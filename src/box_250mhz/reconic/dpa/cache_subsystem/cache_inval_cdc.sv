`timescale 1ns / 1ps

// Clock domain crossing for the external cache invalidation handshake:
// dm_control (src domain) -> cache_filter (dst domain).
//
// Request: the requester holds src_valid_i and the address range until it
// sees src_done_o. The range crosses through a cdc_4phase, whose dst spill
// register keeps dst_valid_o and the range stable until cache_filter's
// done pulse pops it - dst_valid_o drops the cycle after dst_done_i, as
// cache_filter's !invalid_done_reg guard expects. pending_q keeps the held
// request from being pushed into the crossing a second time.
//
// Done: cache_filter pulses dst_done_i for one cycle; done_pend_q holds it
// until the cdc_2phase back to the src domain accepts it, so the pulse is
// never dropped. src_done_o is again a one-cycle pulse.
//
// Same reset rules as cdc_fifo_gray: both resets must be asserted together.
module cache_inval_cdc #(
    parameter int unsigned ADDR_WIDTH = 32
)(
    input  logic                  src_clk_i,
    input  logic                  src_rst_ni,
    input  logic                  src_valid_i,
    input  logic [ADDR_WIDTH-1:0] src_start_i,
    input  logic [ADDR_WIDTH-1:0] src_end_i,
    output logic                  src_done_o,

    input  logic                  dst_clk_i,
    input  logic                  dst_rst_ni,
    output logic                  dst_valid_o,
    output logic [ADDR_WIDTH-1:0] dst_start_o,
    output logic [ADDR_WIDTH-1:0] dst_end_o,
    input  logic                  dst_done_i
);

    typedef struct packed {
        logic [ADDR_WIDTH-1:0] start_addr;
        logic [ADDR_WIDTH-1:0] end_addr;
    } range_t;

    range_t src_range, dst_range;
    logic   req_valid, req_ready, pending_q;
    logic   done_valid, done_ready, done_pend_q;

    // ---------------------------------------------------------
    // request: src -> dst
    // ---------------------------------------------------------
    assign src_range = '{start_addr: src_start_i, end_addr: src_end_i};
    assign req_valid = src_valid_i & ~pending_q;

    always_ff @(posedge src_clk_i or negedge src_rst_ni) begin
        if (!src_rst_ni)                pending_q <= 1'b0;
        else if (src_done_o)            pending_q <= 1'b0;
        else if (req_valid & req_ready) pending_q <= 1'b1;
    end

    cdc_4phase #(
        .T         (range_t),
        .DECOUPLED (1'b1)
    ) i_req_cdc (
        .src_rst_ni  (src_rst_ni),
        .src_clk_i   (src_clk_i),
        .src_data_i  (src_range),
        .src_valid_i (req_valid),
        .src_ready_o (req_ready),
        .dst_rst_ni  (dst_rst_ni),
        .dst_clk_i   (dst_clk_i),
        .dst_data_o  (dst_range),
        .dst_valid_o (dst_valid_o),
        .dst_ready_i (dst_done_i)
    );

    assign dst_start_o = dst_range.start_addr;
    assign dst_end_o   = dst_range.end_addr;

    // ---------------------------------------------------------
    // done: dst -> src
    // ---------------------------------------------------------
    assign done_valid = dst_done_i | done_pend_q;

    always_ff @(posedge dst_clk_i or negedge dst_rst_ni) begin
        if (!dst_rst_ni) done_pend_q <= 1'b0;
        else             done_pend_q <= done_valid & ~done_ready;
    end

    cdc_2phase #(
        .T (logic)
    ) i_done_cdc (
        .src_rst_ni  (dst_rst_ni),
        .src_clk_i   (dst_clk_i),
        .src_data_i  (1'b0),
        .src_valid_i (done_valid),
        .src_ready_o (done_ready),
        .dst_rst_ni  (src_rst_ni),
        .dst_clk_i   (src_clk_i),
        .dst_data_o  (),
        .dst_valid_o (src_done_o),
        .dst_ready_i (1'b1)
    );

endmodule
