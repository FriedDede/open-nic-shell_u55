# *************************************************************************
#
# Copyright 2023 Xilinx, Inc.
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
set_property LOC MMCM_X0Y2 [get_cells ddr4_inst/inst/u_ddr4_infrastructure/gen_mmcme4.u_mmcme_adv_inst]
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_pins ddr4_inst/inst/u_ddr4_infrastructure/gen_mmcme4.u_mmcme_adv_inst/CLKIN1]
set_property INTERNAL_VREF 0.84 [get_iobanks 63]
set_property INTERNAL_VREF 0.84 [get_iobanks 62]
set_property INTERNAL_VREF 0.84 [get_iobanks 61]
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property BITSTREAM.CONFIG.CONFIGFALLBACK Enable [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 72.9 [current_design]
set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN disable [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullup [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR Yes [current_design]