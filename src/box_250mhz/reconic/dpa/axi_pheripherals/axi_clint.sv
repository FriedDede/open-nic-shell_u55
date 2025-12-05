`include "axi_assign.svh"
`include "axi_typedef.svh"

module axi_clint#(
    parameter int unsigned AddrWidth = 64,
    parameter int unsigned DataWidth = 64,
    parameter int unsigned IdWidthIn = 10,
    parameter int unsigned UserWidth = 10,
    // Number of cores therefore also the number of timecmp registers and timer interrupts
    parameter int unsigned NR_CORES  = 1
)(
    input clk_i,
    input rst_ni,
    input  logic                testmode_i,
    AXI_BUS.Slave               clint,
    input  logic                rtc_i,      
    output logic [NR_CORES-1:0] timer_irq_o,
    output logic [NR_CORES-1:0] ipi_o       
);
    typedef logic [AddrWidth-1:0]       addr_t;
    typedef logic [DataWidth-1:0]       data_t;
    typedef logic [DataWidth/8-1:0]     strb_t;
    typedef logic [IdWidthIn-1:0]      id_slv_t;
    typedef logic [UserWidth-1:0]       user_t;

    `AXI_TYPEDEF_ALL(axi_slv, addr_t, id_slv_t, data_t, strb_t, user_t)
    axi_slv_req_t clint_req;
    axi_slv_resp_t clint_resp; 

    `AXI_ASSIGN_TO_REQ(clint_req, clint)
    `AXI_ASSIGN_FROM_RESP(clint, clint_resp)

clint #(
    .AXI_ADDR_WIDTH(AddrWidth), //4k device
    .AXI_DATA_WIDTH(DataWidth),
    .AXI_ID_WIDTH(IdWidthIn),
    .NR_CORES(NR_CORES),
    .axi_lite_req_t(axi_slv_req_t),
    .axi_lite_resp_t(axi_slv_resp_t)
) clint_instance(
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .testmode_i(testmode_i),
    .axi_req_i(clint_req),
    .axi_resp_o(clint_resp),
    .rtc_i(rtc_i),
    .timer_irq_o(timer_irq_o),
    .ipi_o(ipi_o)
);
    
endmodule : axi_clint
