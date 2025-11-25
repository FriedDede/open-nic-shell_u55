# *************************************************************************
#
# Copyright 2020 Xilinx, Inc.
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
set cmac_usplus cmac_usplus_0

create_ip -name cmac_usplus -vendor xilinx.com -library ip -version 3.1 -module_name $cmac_usplus -dir ${ip_build_dir}
set_property -dict [list \
  CONFIG.CMAC_CAUI4_MODE {1} \
  CONFIG.GT_REF_CLK_FREQ {161.1328125} \
  CONFIG.DIFFCLK_BOARD_INTERFACE {qsfp0_refclk0} \
  CONFIG.ENABLE_AXI_INTERFACE {1} \
  CONFIG.ETHERNET_BOARD_INTERFACE {qsfp0_4x} \
  CONFIG.GT_DRP_CLK {125.00} \
  CONFIG.INCLUDE_RS_FEC {1} \
  CONFIG.INS_LOSS_NYQ {20} \
  CONFIG.USER_INTERFACE {AXIS} \
] [get_ips  $cmac_usplus]

set_property CONFIG.RX_MIN_PACKET_LEN $min_pkt_len [get_ips $cmac_usplus]
set_property CONFIG.RX_MAX_PACKET_LEN $max_pkt_len [get_ips $cmac_usplus]