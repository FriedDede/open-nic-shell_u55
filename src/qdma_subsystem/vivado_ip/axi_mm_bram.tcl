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
set axi_mm_mem axi_mm_bram
create_ip -name axi_bram_ctrl -vendor xilinx.com -library ip -version 4.1 -module_name $axi_mm_mem -dir ${ip_build_dir}
set_property -dict {
    CONFIG.DATA_WIDTH {512}
    CONFIG.SUPPORTS_NARROW_BURST {1}
    CONFIG.SINGLE_PORT_BRAM {0}
    CONFIG.ECC_TYPE {0}
    CONFIG.Component_Name {$axi_mm_mem}
    CONFIG.BMG_INSTANCE {INTERNAL}
    CONFIG.MEM_DEPTH {8192}
    CONFIG.ID_WIDTH {5}
    CONFIG.RD_CMD_OPTIMIZATION {0}
} [get_ips $axi_mm_mem]