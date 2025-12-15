
#### IPs

set ipName xlnx_clk_gen_solo
create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name $ipName -dir ${ip_build_dir}

set_property -dict [list CONFIG.PRIM_IN_FREQ {250.000} \
                        CONFIG.NUM_OUT_CLKS {1} \
                        CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {50} \
                        CONFIG.CLKIN1_JITTER_PS {50.0} \
                       ] [get_ips $ipName]