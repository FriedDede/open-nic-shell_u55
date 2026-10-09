`timescale 1ns / 1ps

`include "axi_assign.svh"
`include "axi_typedef.svh"

// AXI4 slave backed by a single-cycle-latency inferred Block RAM.
// The AXI protocol handling (bursts, IDs, responses) is delegated to
// axi_to_mem_intf (open-nic-shell/src/axi_pulp/src/axi_to_mem.sv); this
// module only has to implement the plain memory array behind it.
module cache_bram #(
    parameter ADDR_WIDTH       = 40,  // width of the connected AXI_BUS address
    parameter CACHE_ADDR_WIDTH = 34,  // OFFSET_BITS + INDEX_BITS: the only
                                       // address bits actually backed by
                                       // storage. Bits above this (the cache
                                       // filter's tag) are never driven
                                       // non-zero by cache_filter/page_mover
                                       // and are ignored here.
    parameter DATA_WIDTH       = 512,
    parameter ID_WIDTH         = 4
)(
    input  logic aclk,
    input  logic aresetn,

    AXI_BUS.Slave slv
);

    localparam int BANK_BYTES    = DATA_WIDTH/8;
    localparam int BANK_ADDR_LSB = $clog2(BANK_BYTES);
    localparam int NUM_WORDS     = 1 << (CACHE_ADDR_WIDTH - BANK_ADDR_LSB);

    logic                  mem_req, mem_gnt, mem_we, mem_rvalid;
    logic [ADDR_WIDTH-1:0] mem_addr;
    logic [DATA_WIDTH-1:0] mem_wdata, mem_rdata;
    logic [BANK_BYTES-1:0] mem_strb;

    axi_to_mem_intf #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .ID_WIDTH   (ID_WIDTH),
        .USER_WIDTH (1),
        .NUM_BANKS  (1),
        .BUF_DEPTH  (1)  // matches the 1-cycle read latency of the BRAM below
    ) axi_to_mem_instance (
        .clk_i        (aclk),
        .rst_ni       (aresetn),
        .busy_o       (),
        .slv          (slv),
        .mem_req_o    (mem_req),
        .mem_gnt_i    (mem_gnt),
        .mem_addr_o   (mem_addr),
        .mem_wdata_o  (mem_wdata),
        .mem_strb_o   (mem_strb),
        .mem_atop_o   (),
        .mem_we_o     (mem_we),
        .mem_rvalid_i (mem_rvalid),
        .mem_rdata_i  (mem_rdata)
    );

    // A plain single-port BRAM never stalls a request.
    assign mem_gnt = 1'b1;

    (* ram_style = "block" *) logic [DATA_WIDTH-1:0] mem [NUM_WORDS-1:0];
    logic [CACHE_ADDR_WIDTH-BANK_ADDR_LSB-1:0] mem_word_addr;
    assign mem_word_addr = mem_addr[CACHE_ADDR_WIDTH-1:BANK_ADDR_LSB];

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            mem_rvalid <= 1'b0;
        end else begin
            // mem_gnt is always 1, so every request completes next cycle
            mem_rvalid <= mem_req;
        end
    end

    // Storage and read port: no reset, so the array maps to block RAM with
    // aresetn out of its enables (axi_to_mem issues no request in reset)
    always_ff @(posedge aclk) begin
        if (mem_req && mem_we) begin
            for (int i = 0; i < BANK_BYTES; i++) begin
                if (mem_strb[i]) mem[mem_word_addr][8*i +: 8] <= mem_wdata[8*i +: 8];
            end
        end else if (mem_req) begin
            mem_rdata <= mem[mem_word_addr];
        end
    end

endmodule
