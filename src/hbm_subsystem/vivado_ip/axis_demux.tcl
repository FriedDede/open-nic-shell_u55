create_ip -name axis_switch -vendor xilinx.com -library ip -version 1.1 -module_name axis_demux -dir ${ip_build_dir}
set_property -dict [
  CONFIG.HAS_TKEEP {1} \
  CONFIG.HAS_TLAST {1} \
  CONFIG.NUM_MI {4} \
  CONFIG.NUM_SI {1} \
  CONFIG.TDATA_NUM_BYTES {64} \
] [get_ips axis_demux]