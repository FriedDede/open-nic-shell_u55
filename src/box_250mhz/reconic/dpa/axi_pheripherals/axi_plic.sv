
`include "axi_assign.svh"
`include "axi_typedef.svh"

module axi_plic#(
    parameter int unsigned AxiAddrWidth = 0,  // The address width.
    parameter int unsigned AxiDataWidth = 0,  // The data width.
    parameter int unsigned AxiIdWidth = 0,  // The ID width.
    parameter int unsigned AxiUserWidth = 0,  // The user data width.
    parameter int unsigned NIrqSrcs = 0,
    parameter int unsigned NHARTS = 0
) (
    input clk_i,
    input rst_ni,
    AXI_BUS.Slave plic,
    // overflow and cmp interrupt
    input  logic [NIrqSrcs - 1 : 0] plic_irq_i,
    output logic [(NHARTS * 2) - 1 : 0] plic_irq_o
);

    logic         plic_penable;
    logic         plic_pwrite;
    logic [31:0]  plic_paddr;
    logic         plic_psel;
    logic [31:0]  plic_pwdata;
    logic [31:0]  plic_prdata;
    logic         plic_pready;
    logic         plic_pslverr;
    axi2apb_64_32 #(
    .AXI4_ADDRESS_WIDTH ( AxiAddrWidth ),
    .AXI4_RDATA_WIDTH   ( AxiDataWidth ),
    .AXI4_WDATA_WIDTH   ( AxiDataWidth ),
    .AXI4_ID_WIDTH      ( AxiIdWidth   ),
    .AXI4_USER_WIDTH    ( AxiUserWidth ),
    .BUFF_DEPTH_SLAVE   ( 2            ),
    .APB_ADDR_WIDTH     ( 27           )
    ) i_axi2apb_64_32_uart (
        .ACLK      ( clk_i          ),
        .ARESETn   ( rst_ni         ),
        .test_en_i ( 1'b0           ),
        .AWID_i    ( plic.aw_id     ),
        .AWADDR_i  ( plic.aw_addr   ),
        .AWLEN_i   ( plic.aw_len    ),
        .AWSIZE_i  ( plic.aw_size   ),
        .AWBURST_i ( plic.aw_burst  ),
        .AWLOCK_i  ( plic.aw_lock   ),
        .AWCACHE_i ( plic.aw_cache  ),
        .AWPROT_i  ( plic.aw_prot   ),
        .AWREGION_i( plic.aw_region ),
        .AWUSER_i  ( plic.aw_user   ),
        .AWQOS_i   ( plic.aw_qos    ),
        .AWVALID_i ( plic.aw_valid  ),
        .AWREADY_o ( plic.aw_ready  ),
        .WDATA_i   ( plic.w_data    ),
        .WSTRB_i   ( plic.w_strb    ),
        .WLAST_i   ( plic.w_last    ),
        .WUSER_i   ( plic.w_user    ),
        .WVALID_i  ( plic.w_valid   ),
        .WREADY_o  ( plic.w_ready   ),
        .BID_o     ( plic.b_id      ),
        .BRESP_o   ( plic.b_resp    ),
        .BVALID_o  ( plic.b_valid   ),
        .BUSER_o   ( plic.b_user    ),
        .BREADY_i  ( plic.b_ready   ),
        .ARID_i    ( plic.ar_id     ),
        .ARADDR_i  ( plic.ar_addr   ),
        .ARLEN_i   ( plic.ar_len    ),
        .ARSIZE_i  ( plic.ar_size   ),
        .ARBURST_i ( plic.ar_burst  ),
        .ARLOCK_i  ( plic.ar_lock   ),
        .ARCACHE_i ( plic.ar_cache  ),
        .ARPROT_i  ( plic.ar_prot   ),
        .ARREGION_i( plic.ar_region ),
        .ARUSER_i  ( plic.ar_user   ),
        .ARQOS_i   ( plic.ar_qos    ),
        .ARVALID_i ( plic.ar_valid  ),
        .ARREADY_o ( plic.ar_ready  ),
        .RID_o     ( plic.r_id      ),
        .RDATA_o   ( plic.r_data    ),
        .RRESP_o   ( plic.r_resp    ),
        .RLAST_o   ( plic.r_last    ),
        .RUSER_o   ( plic.r_user    ),
        .RVALID_o  ( plic.r_valid   ),
        .RREADY_i  ( plic.r_ready   ),
        .PENABLE   ( plic_penable   ),
        .PWRITE    ( plic_pwrite    ),
        .PADDR     ( plic_paddr     ),
        .PSEL      ( plic_psel      ),
        .PWDATA    ( plic_pwdata    ),
        .PRDATA    ( plic_prdata    ),
        .PREADY    ( plic_pready    ),
        .PSLVERR   ( plic_pslverr   )
    );

    riscv_plic_wrap #(
        .NHARTS(NHARTS),
        .NIRQ_SRCS(NIrqSrcs)
    ) riscv_plic_wrap_instance(
        .clk            (clk_i),
        .rstn           (rst_ni),
        .irq_sources    (plic_irq_i),
        .irq            (plic_irq_o),
        .plic_penable   (plic_penable),
        .plic_pwrite    (plic_pwrite),
        .plic_paddr     (plic_paddr),
        .plic_psel      (plic_psel),
        .plic_pwdata    (plic_pwdata),
        .plic_prdata    (plic_prdata),
        .plic_pready    (plic_pready),
        .plic_pslverr   (plic_pslverr)
    );

endmodule : axi_plic
