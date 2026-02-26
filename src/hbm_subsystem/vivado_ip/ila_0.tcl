create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name ila_0
set_property -dict [list \
  CONFIG.C_MONITOR_TYPE {AXI} \
  CONFIG.C_SLOT_0_AXI_ADDR_WIDTH {34} \
  CONFIG.C_SLOT_0_AXI_DATA_WIDTH {512} \
  CONFIG.C_SLOT_0_AXI_ID_WIDTH {4} \
] [get_ips ila_0]