create_ip -name axis_switch -vendor xilinx.com -library ip -module_name packet_arbiter -dir ${ip_build_dir}
set_property -dict { 
  CONFIG.ARB_ON_MAX_XFERS {0} \
  CONFIG.ARB_ON_TLAST {1} \
  CONFIG.HAS_TKEEP {1} \
  CONFIG.HAS_TLAST {1} \
  CONFIG.TDATA_NUM_BYTES {64} \
  CONFIG.TUSER_WIDTH {48} \
} [get_ips packet_arbiter]