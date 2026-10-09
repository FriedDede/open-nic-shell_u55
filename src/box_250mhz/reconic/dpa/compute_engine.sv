`include "axi_typedef.svh"
`include "common_cells_assertions.svh"
`include "common_cells_registers.svh"
`include "snitch_vm_typedef.svh"
`include "axi_assign.svh"
`include "axi_typedef.svh"
`include "register_interface_assign.svh"
`include "register_interface_typedef.svh"

// Compute engine wrapper:
// @ input: clk / rst
// @ output: 64-bit AXI channels to the hbm memory, one per memory channel
// @ output: uart ? TODO: evaluate if needed
// This module self-contains the RISC-V compute engine and all associated peripherals

module compute_engine 
    import snitch_cluster_pkg::*;
    import dpa_pkg::* ;  
(
    input clk,
    input core_areset_n,

    output  axim64_core2mem_req_t [dpa_pkg::DRAM_CH_NUMBER-1 : 0] m_axim_ce2mem_req,
    input   axim64_core2mem_resp_t [dpa_pkg::DRAM_CH_NUMBER-1 : 0] m_axim_ce2mem_resp,

    output  axim64_core2mem_req_t  [dpa_pkg::DRAM_CH_NUMBER-1 : 0]  m_axim_ce2cfu_req,
    input   axim64_core2mem_resp_t  [dpa_pkg::DRAM_CH_NUMBER-1 : 0] m_axim_ce2cfu_resp

    //input  logic          uart_rx         ,
    //output logic          uart_tx
);

localparam BOOT_ADDR            = dpa_pkg::BOOT_ADDR         ;
localparam CORE_NUMBER          = dpa_pkg::CORE_NUMBER       ;
localparam CLUSTER_NUMBER       = dpa_pkg::CLUSTER_NUMBER    ;
localparam TOTAL_CORE_NUMBER    = dpa_pkg::TOTAL_CORE_NUMBER ;
localparam DRAM_CH_NUMBER       = dpa_pkg::DRAM_CH_NUMBER    ;
localparam AxiAddrWidth         = dpa_pkg::ce_AddrWidth      ;
localparam AxiDataWidth         = dpa_pkg::ce_DataWidth      ;
localparam AxiIdWidthCore       = dpa_pkg::ce_IdWidthCore    ;
localparam AxiIdWidthToUncore   = dpa_pkg::ce_IdWidthToUncore;
localparam AxiUserWidth         = dpa_pkg::ce_UserWidth      ;

// xbar config
localparam axi_pkg::xbar_cfg_t xbar_cfg = '{
    NoSlvPorts:         3*CORE_NUMBER,
    NoMstPorts:         4,
    MaxMstTrans:        16,
    MaxSlvTrans:        16,
    FallThrough:        1'b0,
    LatencyMode:        axi_pkg::CUT_ALL_PORTS,
    PipelineStages:     1,
    AxiIdWidthSlvPorts: AxiIdWidthCore,
    AxiIdUsedSlvPorts:  AxiIdWidthCore,
    UniqueIds:          '0,
    AxiAddrWidth:       AxiAddrWidth,
    AxiDataWidth:       AxiDataWidth,
    NoAddrRules:        4
};

// generate the address map
typedef axi_pkg::xbar_rule_32_t  rule_t;
function rule_t [3:0] addr_map_gen ();
    // rom address 0x0 -> 0xffff
    addr_map_gen[0] = rule_t'{
        idx:        unsigned'(0),
        start_addr: 32'h0000_0000,
        end_addr:   32'h0001_0000,
        default:    '0
    };
    // dram address 0x8000000 -> 0x8000000 + clog2(size)
    addr_map_gen[1] = rule_t'{
        idx:        unsigned'(1),
        start_addr: 32'h8000_0000,
        end_addr:   32'h8000_0000 + 32'h8000_0000, // 2GB per cluster here
        default:    '0
    };
    // DESC BRAM
    addr_map_gen[2] = rule_t'{
        idx:        unsigned'(2),
        start_addr: 32'h1000_0000,
        end_addr:   32'h2000_0000, // 256MB aperture
        default:    '0
    };
    // CLINT (Pulp Specs RISC-V privilege spec 1.11 compatible CLINT )
    addr_map_gen[3] = rule_t'{
        idx:        unsigned'(3),
        start_addr: 32'h0200_0000,
        end_addr:   32'h0200_C000,
        default:    '0
    };
endfunction


localparam rule_t [3:0] AddrMapUncore = addr_map_gen();

AXI_BUS #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_ID_WIDTH   ( AxiIdWidthToUncore ),
    .AXI_USER_WIDTH ( AxiUserWidth     )
) axi_dram[DRAM_CH_NUMBER-1:0]();
AXI_BUS #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
    .AXI_DATA_WIDTH ( AxiDataWidth     ),
    .AXI_ID_WIDTH   ( AxiIdWidthToUncore ),
    .AXI_USER_WIDTH ( AxiUserWidth     )
) axi_cfu[CLUSTER_NUMBER-1:0]();


// interrupt handling bus
snitch_pkg::interrupts_t [TOTAL_CORE_NUMBER - 1 : 0] core_irq_i;

// clocking and reset declaration

logic uncore_areset_n;
assign uncore_areset_n = core_areset_n;

// ---------------
// Core
// ---------------

for ( genvar i=0; i<CLUSTER_NUMBER; ++i) begin  : snitch_cluster_gen
    
    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
        .AXI_DATA_WIDTH ( AxiDataWidth     ),
        .AXI_ID_WIDTH   ( AxiIdWidthCore ),
        .AXI_USER_WIDTH ( AxiUserWidth     )
    ) axi_snitch2mux[(3*CORE_NUMBER) - 1 : 0]();
    
    for ( genvar j=0; j<CORE_NUMBER; ++j) begin  : core_gen
        snitch_cluster_pkg::narrow_out_req_t    axi_icache_snitch_req;
        snitch_cluster_pkg::narrow_out_resp_t   axi_icache_snitch_resp;
        snitch_cluster_pkg::narrow_out_req_t    [1:0]axi_data_snitch_req;
        snitch_cluster_pkg::narrow_out_resp_t   [1:0]axi_data_snitch_resp;
        snitch_core_axi #(
        .AddrWidth          (AxiAddrWidth),
        .DataWidth          (AxiDataWidth),
        .IdWidthIn          (AxiIdWidthCore),
        .BootAddr           (BOOT_ADDR),
        .SnitchPMACfg       (snitch_cluster_pkg::SnitchPMACfg)    
        ) i_snitch(
            .clk_i                  (clk),
            .rst_ni                 (core_areset_n),
            .hart_id_i              ((j)), // id unique only in the cluster
            .irq_i                  ('0),
            // icache
            .inst_out_req_o         (axi_icache_snitch_req     ),
            .inst_out_resp_i        (axi_icache_snitch_resp    ),
            // integer core
            .data_core_out_req_o    (axi_data_snitch_req    [0]),
            .data_core_out_resp_i   (axi_data_snitch_resp   [0]),
            // fpu
            .data_fpu_out_req_o     (axi_data_snitch_req    [1]),
            .data_fpu_out_resp_i    (axi_data_snitch_resp   [1])
        );
        // integer core lsu
        `AXI_ASSIGN_FROM_REQ (axi_snitch2mux[0 + (3*j)], axi_data_snitch_req[0])
        `AXI_ASSIGN_TO_RESP  (axi_data_snitch_resp[0], axi_snitch2mux[0 + (3*j)])
        // fpu lsu
        `AXI_ASSIGN_FROM_REQ (axi_snitch2mux[1 + (3*j)], axi_data_snitch_req[1])
        `AXI_ASSIGN_TO_RESP  (axi_data_snitch_resp[1], axi_snitch2mux[1 + (3*j)])
        // icache 
        `AXI_ASSIGN_FROM_REQ (axi_snitch2mux[2 + (3*j)], axi_icache_snitch_req)
        `AXI_ASSIGN_TO_RESP  (axi_icache_snitch_resp, axi_snitch2mux[2 + (3*j)])
    end
    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
        .AXI_DATA_WIDTH ( AxiDataWidth     ),
        .AXI_ID_WIDTH   ( AxiIdWidthToUncore),
        .AXI_USER_WIDTH ( AxiUserWidth     )
    ) axi_xbar2uncore[3:0]();
    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
        .AXI_DATA_WIDTH ( AxiDataWidth     ),
        .AXI_ID_WIDTH   ( AxiIdWidthToUncore ),
        .AXI_USER_WIDTH ( AxiUserWidth     )
    ) axi_rom();
    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AxiAddrWidth     ),
        .AXI_DATA_WIDTH ( AxiDataWidth     ),
        .AXI_ID_WIDTH   ( AxiIdWidthToUncore ),
        .AXI_USER_WIDTH ( AxiUserWidth     )
    ) axi_clint();
    axi_xbar_intf #(
        .AXI_USER_WIDTH(AxiUserWidth),
        .Cfg(xbar_cfg),
        .rule_t(rule_t)
    ) i_axi_xbar_intf (
        .clk_i(clk),
        .rst_ni(core_areset_n),
        .test_i('0),
        .slv_ports(axi_snitch2mux),
        .mst_ports(axi_xbar2uncore),
        .addr_map_i(AddrMapUncore),
        .en_default_mst_port_i('0),
        .default_mst_port_i('0)
    );

    // to hbm
    `AXI_ASSIGN(axi_dram[i], axi_xbar2uncore[1])
    `AXI_ASSIGN_TO_REQ(m_axim_ce2mem_req[i], axi_dram[i])
    `AXI_ASSIGN_FROM_RESP(axi_dram[i], m_axim_ce2mem_resp[i])
    // to cfu
    `AXI_ASSIGN(axi_cfu[i], axi_xbar2uncore[2])
    `AXI_ASSIGN_TO_REQ(m_axim_ce2cfu_req[i], axi_cfu[i])
    `AXI_ASSIGN_FROM_RESP(axi_cfu[i], m_axim_ce2cfu_resp[i])
    // to uncore
    `AXI_ASSIGN(axi_rom, axi_xbar2uncore[0])
    `AXI_ASSIGN(axi_clint, axi_xbar2uncore[3])
    // clint logic
    logic rtc;
    always_ff @(posedge clk or negedge uncore_areset_n) begin
        if (~uncore_areset_n) begin
            rtc <= 0;
        end else begin
            rtc <= rtc ^ 1'b1;
        end
    end
    axi_clint #(
        .AddrWidth(AxiAddrWidth),
        .DataWidth(AxiDataWidth),
        .IdWidthIn(AxiIdWidthToUncore),
        .UserWidth(AxiUserWidth),
        .NR_CORES(1)
    ) axi_clint_instance(
        .clk_i(clk),
        .rst_ni(uncore_areset_n),
        .testmode_i('0),
        .clint(axi_clint),
        .rtc_i(rtc),
        .timer_irq_o(core_irq_i[i].mtip),
        .ipi_o(core_irq_i[i].msip)
    );
    // ROM
    logic                    rom_req;
    logic [AxiAddrWidth-1:0] rom_addr;
    logic [AxiDataWidth-1:0] rom_rdata;
    logic                    rom_rvalid;
    axi_to_mem_intf #(
        .ADDR_WIDTH ( AxiAddrWidth),
        .DATA_WIDTH ( AxiDataWidth),
        .ID_WIDTH   ( AxiIdWidthToUncore),
        .USER_WIDTH ( AxiUserWidth),
        .NUM_BANKS  ( 1)
    ) i_axi_to_mem (
        .clk_i       ( clk),
        .rst_ni      ( core_areset_n),
        .busy_o      ( ),
        .slv         ( axi_rom),
        .mem_req_o   ( rom_req),
        .mem_gnt_i   ( '1),
        .mem_addr_o  ( rom_addr),
        .mem_wdata_o ( ),
        .mem_strb_o  ( ),
        .mem_atop_o  ( ),
        .mem_we_o    ( ),
        .mem_rvalid_i( rom_rvalid),
        .mem_rdata_i ( rom_rdata)
    );
    bootrom i_bootrom (
        .clk_i      ( clk       ),
        .req_i      ( rom_req   ),
        .addr_i     ( rom_addr  ),
        .rdata_o    ( rom_rdata ),
        .rvalid_o   ( rom_rvalid)
    );
    // tie unused signal in bram channel to 0
    // assign axi_dram[i].b_user = '0;
    // assign axi_dram[i].r_user = '0;
end

// -----------------
// END
// -----------------

endmodule
