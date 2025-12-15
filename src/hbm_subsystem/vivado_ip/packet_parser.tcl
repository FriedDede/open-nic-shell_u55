set prj_root [file normalize ..]
set p4_filepath ${prj_root}/src/hbm_subsystem

if {[info exists p4_dir]} {
  set p4file [glob -directory ${p4_dir} packet_parser.p4]
} else {
  set p4file [glob -directory ${p4_filepath} packet_parser.p4]
}

puts "p4file = ${p4file}"

create_ip -name vitis_net_p4 -vendor xilinx.com -library ip -module_name packet_parser -dir ${ip_build_dir}
set_property CONFIG.P4_FILE "${p4file}" [get_ips packet_parser]
set_property -dict { 
  CONFIG.AXIS_CLK_FREQ_MHZ {250} \
  CONFIG.CAM_MEM_CLK_FREQ_MHZ {250} \
  CONFIG.OUTPUT_METADATA_FOR_DROPPED_PKTS {true} \
  CONFIG.PKT_RATE {250} \
} [get_ips packet_parser]
