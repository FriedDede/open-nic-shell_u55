# ==============================================================================
# AXI BRAM Controller IP for the ACE core's capability memory (axi_bram_cap)
# ==============================================================================
# Instantiated directly in RTL as "axi_bram_cap" (see hw/ACE/ace_core.sv,
# ace_rgm_fu_tb.sv, ace_rw_fu_tb.sv). Parameters below match ace_pkg::cap_AxiDataWidth
# (256), the 21-bit truncated cap_mem_addr_width (2MB / 65536 x 256b depth), and
# the capability request/response channel ID width (8 bits).
# ==============================================================================

create_ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 -module_name axi_bram_desc -dir ${ip_build_dir}
# 4 KB: MEM_DEPTH x DATA_WIDTH/8 = 512 x 8 B (DESC_MEM_ADDR_WIDTH = 12 in compute_logic_wrapper.sv)
# CONFIG.ID_WIDTH must equal dpa_pkg::desc_bram_id_width
# (ce_IdWidthToUncore + $clog2(DRAM_CH_NUMBER + 1)): 7 for 1 CE, 9 for 4 CEs
set_property -dict [list \
    CONFIG.PROTOCOL             {AXI4} \
    CONFIG.DATA_WIDTH           {64} \
    CONFIG.MEM_DEPTH            {512} \
    CONFIG.ID_WIDTH             {9} \
    CONFIG.SUPPORTS_NARROW_BURST {1} \
    CONFIG.READ_LATENCY         {1} \
    CONFIG.RD_CMD_OPTIMIZATION  {0} \
    CONFIG.BMG_INSTANCE         {INTERNAL} \
    CONFIG.SINGLE_PORT_BRAM     {0} \
    CONFIG.USE_ECC              {0} \
] [get_ips axi_bram_desc]
generate_target all [get_ips axi_bram_desc]
