
`include "axi_assign.svh"
`include "axi_typedef.svh"

module axi_timer#(
    parameter int unsigned AxiAddrWidth = 0,  // The address width.
    parameter int unsigned AxiDataWidth = 0,  // The data width.
    parameter int unsigned AxiIdWidth = 0,  // The ID width.
    parameter int unsigned AxiUserWidth = 0,  // The user data width.
    parameter int unsigned TimerCount = 0
) (
    input clk_i,
    input rst_ni,
    AXI_BUS.Slave timer,
    // overflow and cmp interrupt
    output logic [(TimerCount * 2) - 1 : 0] timer_irq
);

        
    logic         timer_penable;
    logic         timer_pwrite;
    logic [31:0]  timer_paddr;
    logic         timer_psel;
    logic [31:0]  timer_pwdata;
    logic [31:0]  timer_prdata;
    logic         timer_pready;
    logic         timer_pslverr;
    axi2apb_64_32 #(
    .AXI4_ADDRESS_WIDTH ( AxiAddrWidth ),
    .AXI4_RDATA_WIDTH   ( AxiDataWidth ),
    .AXI4_WDATA_WIDTH   ( AxiDataWidth ),
    .AXI4_ID_WIDTH      ( AxiIdWidth   ),
    .AXI4_USER_WIDTH    ( AxiUserWidth ),
    .BUFF_DEPTH_SLAVE   ( 2            ),
    .APB_ADDR_WIDTH     ( 12           )
    ) i_axi2apb_64_32_uart (
        .ACLK      ( clk_i          ),
        .ARESETn   ( rst_ni         ),
        .test_en_i ( 1'b0           ),
        .AWID_i    ( timer.aw_id     ),
        .AWADDR_i  ( timer.aw_addr[12:0]),
        .AWLEN_i   ( timer.aw_len    ),
        .AWSIZE_i  ( timer.aw_size   ),
        .AWBURST_i ( timer.aw_burst  ),
        .AWLOCK_i  ( timer.aw_lock   ),
        .AWCACHE_i ( timer.aw_cache  ),
        .AWPROT_i  ( timer.aw_prot   ),
        .AWREGION_i( timer.aw_region ),
        .AWUSER_i  ( timer.aw_user   ),
        .AWQOS_i   ( timer.aw_qos    ),
        .AWVALID_i ( timer.aw_valid  ),
        .AWREADY_o ( timer.aw_ready  ),
        .WDATA_i   ( timer.w_data    ),
        .WSTRB_i   ( timer.w_strb    ),
        .WLAST_i   ( timer.w_last    ),
        .WUSER_i   ( timer.w_user    ),
        .WVALID_i  ( timer.w_valid   ),
        .WREADY_o  ( timer.w_ready   ),
        .BID_o     ( timer.b_id      ),
        .BRESP_o   ( timer.b_resp    ),
        .BVALID_o  ( timer.b_valid   ),
        .BUSER_o   ( timer.b_user    ),
        .BREADY_i  ( timer.b_ready   ),
        .ARID_i    ( timer.ar_id     ),
        .ARADDR_i  ( timer.ar_addr[12:0]),
        .ARLEN_i   ( timer.ar_len    ),
        .ARSIZE_i  ( timer.ar_size   ),
        .ARBURST_i ( timer.ar_burst  ),
        .ARLOCK_i  ( timer.ar_lock   ),
        .ARCACHE_i ( timer.ar_cache  ),
        .ARPROT_i  ( timer.ar_prot   ),
        .ARREGION_i( timer.ar_region ),
        .ARUSER_i  ( timer.ar_user   ),
        .ARQOS_i   ( timer.ar_qos    ),
        .ARVALID_i ( timer.ar_valid  ),
        .ARREADY_o ( timer.ar_ready  ),
        .RID_o     ( timer.r_id      ),
        .RDATA_o   ( timer.r_data    ),
        .RRESP_o   ( timer.r_resp    ),
        .RLAST_o   ( timer.r_last    ),
        .RUSER_o   ( timer.r_user    ),
        .RVALID_o  ( timer.r_valid   ),
        .RREADY_i  ( timer.r_ready   ),
        .PENABLE   ( timer_penable   ),
        .PWRITE    ( timer_pwrite    ),
        .PADDR     ( timer_paddr     ),
        .PSEL      ( timer_psel      ),
        .PWDATA    ( timer_pwdata    ),
        .PRDATA    ( timer_prdata    ),
        .PREADY    ( timer_pready    ),
        .PSLVERR   ( timer_pslverr   )
    );

    apb_timer #(
        .APB_ADDR_WIDTH ( 12 ),
        .TIMER_CNT      ( TimerCount )
    ) i_timer (
        .HCLK    ( clk_i            ),
        .HRESETn ( rst_ni           ),
        .PSEL    ( timer_psel       ),
        .PENABLE ( timer_penable    ),
        .PWRITE  ( timer_pwrite     ),
        .PADDR   ( timer_paddr      ),
        .PWDATA  ( timer_pwdata     ),
        .PRDATA  ( timer_prdata     ),
        .PREADY  ( timer_pready     ),
        .PSLVERR ( timer_pslverr    ),
        .irq_o   ( timer_irq        )
    );

endmodule : axi_timer
