# *************************************************************************
#
# Copyright 2021 Xilinx, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# *************************************************************************
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property BITSTREAM.CONFIG.CONFIGFALLBACK Enable [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 63.8 [current_design]
set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN disable [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullup [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR Yes [current_design]

# Manually connecting the Debug Hub clock pin to a valid clock source (100MHz reference clock in this case).
# Read AR72607 for details.

set_false_path -reset_path -from [get_clocks -of_objects [get_pins kvs_subsystem_inst/i_hbm/hbm_interface_i/clk_wiz_0/inst/plle4_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins {qdma_if[0].qdma_subsystem_inst/qdma_wrapper_inst/qdma_inst/inst/pcie4c_ip_i/inst/qdma_no_sriov_pcie4c_ip_gt_top_i/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_userclk/O}]]
set_false_path -from [get_clocks -of_objects [get_pins kvs_subsystem_inst/i_hbm/hbm_interface_i/clk_wiz_0/inst/plle4_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins {qdma_if[0].qdma_subsystem_inst/qdma_wrapper_inst/qdma_inst/inst/pcie4c_ip_i/inst/qdma_no_sriov_pcie4c_ip_gt_top_i/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_userclk/O}]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets ref_clk_100mhz]
