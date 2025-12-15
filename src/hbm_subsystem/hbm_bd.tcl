
################################################################
# This is a generated script based on design: hbm_bd
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2024.2
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   if { [string compare $scripts_vivado_version $current_vivado_version] > 0 } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2042 -severity "ERROR" " This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Sourcing the script failed since it was created with a future version of Vivado."}

   } else {
     catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   }

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source hbm_bd_script.tcl

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xcu55c-fsvh2892-2L-e
   set_property BOARD_PART xilinx.com:au55c:part0:1.0 [current_project]
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name hbm_bd

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_gid_msg -ssname BD::TCL -id 2001 -severity "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_gid_msg -ssname BD::TCL -id 2002 -severity "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_gid_msg -ssname BD::TCL -id 2003 -severity "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_gid_msg -ssname BD::TCL -id 2004 -severity "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_gid_msg -ssname BD::TCL -id 2005 -severity "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2006 -severity "ERROR" $errMsg}
   return $nRet
}

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
xilinx.com:ip:hbm:1.0\
xilinx.com:ip:clk_wiz:6.0\
xilinx.com:ip:proc_sys_reset:5.0\
xilinx.com:ip:axi_datamover:5.1\
xilinx.com:ip:smartconnect:1.0\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################



# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set s_axi_hbm [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi_hbm ]
  set_property -dict [ list \
   CONFIG.ADDR_WIDTH {64} \
   CONFIG.ARUSER_WIDTH {32} \
   CONFIG.AWUSER_WIDTH {32} \
   CONFIG.BUSER_WIDTH {0} \
   CONFIG.DATA_WIDTH {512} \
   CONFIG.FREQ_HZ {250000000} \
   CONFIG.HAS_BRESP {1} \
   CONFIG.HAS_BURST {0} \
   CONFIG.HAS_CACHE {1} \
   CONFIG.HAS_LOCK {1} \
   CONFIG.HAS_PROT {1} \
   CONFIG.HAS_QOS {0} \
   CONFIG.HAS_REGION {0} \
   CONFIG.HAS_RRESP {1} \
   CONFIG.HAS_WSTRB {1} \
   CONFIG.ID_WIDTH {4} \
   CONFIG.MAX_BURST_LENGTH {256} \
   CONFIG.NUM_READ_OUTSTANDING {32} \
   CONFIG.NUM_READ_THREADS {1} \
   CONFIG.NUM_WRITE_OUTSTANDING {32} \
   CONFIG.NUM_WRITE_THREADS {1} \
   CONFIG.PROTOCOL {AXI4} \
   CONFIG.READ_WRITE_MODE {READ_WRITE} \
   CONFIG.RUSER_BITS_PER_BYTE {0} \
   CONFIG.RUSER_WIDTH {0} \
   CONFIG.SUPPORTS_NARROW_BURST {0} \
   CONFIG.WUSER_BITS_PER_BYTE {0} \
   CONFIG.WUSER_WIDTH {64} \
   ] $s_axi_hbm

  set s_axis_dm_s2mm [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_dm_s2mm ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {64} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $s_axis_dm_s2mm

  set s_axis_dm_s2mm_cmd [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_dm_s2mm_cmd ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
   CONFIG.HAS_TKEEP {0} \
   CONFIG.HAS_TLAST {0} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {10} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $s_axis_dm_s2mm_cmd

  set s_axis_dm_mm2s_cmd [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_dm_mm2s_cmd ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
   CONFIG.HAS_TKEEP {0} \
   CONFIG.HAS_TLAST {0} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.TDATA_NUM_BYTES {10} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {0} \
   ] $s_axis_dm_mm2s_cmd

  set m_axis_dm_mm2s [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_dm_mm2s ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
   ] $m_axis_dm_mm2s

  set m_axis_dm_s2mm_status [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_dm_s2mm_status ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
   ] $m_axis_dm_s2mm_status

  set m_axis_dm_mm2s_status [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_dm_mm2s_status ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {250000000} \
   ] $m_axis_dm_mm2s_status

  set s_axi_2 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi_2 ]
  set_property -dict [ list \
   CONFIG.ADDR_WIDTH {34} \
   CONFIG.ARUSER_WIDTH {0} \
   CONFIG.AWUSER_WIDTH {0} \
   CONFIG.BUSER_WIDTH {0} \
   CONFIG.DATA_WIDTH {256} \
   CONFIG.FREQ_HZ {250000000} \
   CONFIG.HAS_BRESP {1} \
   CONFIG.HAS_BURST {1} \
   CONFIG.HAS_CACHE {0} \
   CONFIG.HAS_LOCK {0} \
   CONFIG.HAS_PROT {0} \
   CONFIG.HAS_QOS {0} \
   CONFIG.HAS_REGION {0} \
   CONFIG.HAS_RRESP {1} \
   CONFIG.HAS_WSTRB {1} \
   CONFIG.ID_WIDTH {6} \
   CONFIG.MAX_BURST_LENGTH {16} \
   CONFIG.NUM_READ_OUTSTANDING {2} \
   CONFIG.NUM_READ_THREADS {1} \
   CONFIG.NUM_WRITE_OUTSTANDING {2} \
   CONFIG.NUM_WRITE_THREADS {1} \
   CONFIG.PROTOCOL {AXI3} \
   CONFIG.READ_WRITE_MODE {READ_WRITE} \
   CONFIG.RUSER_BITS_PER_BYTE {0} \
   CONFIG.RUSER_WIDTH {0} \
   CONFIG.SUPPORTS_NARROW_BURST {1} \
   CONFIG.WUSER_BITS_PER_BYTE {0} \
   CONFIG.WUSER_WIDTH {0} \
   ] $s_axi_2

  set s_axi_1 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi_1 ]
  set_property -dict [ list \
   CONFIG.ADDR_WIDTH {34} \
   CONFIG.ARUSER_WIDTH {0} \
   CONFIG.AWUSER_WIDTH {0} \
   CONFIG.BUSER_WIDTH {0} \
   CONFIG.DATA_WIDTH {256} \
   CONFIG.FREQ_HZ {250000000} \
   CONFIG.HAS_BRESP {1} \
   CONFIG.HAS_BURST {1} \
   CONFIG.HAS_CACHE {0} \
   CONFIG.HAS_LOCK {0} \
   CONFIG.HAS_PROT {0} \
   CONFIG.HAS_QOS {0} \
   CONFIG.HAS_REGION {0} \
   CONFIG.HAS_RRESP {1} \
   CONFIG.HAS_WSTRB {1} \
   CONFIG.ID_WIDTH {6} \
   CONFIG.MAX_BURST_LENGTH {16} \
   CONFIG.NUM_READ_OUTSTANDING {2} \
   CONFIG.NUM_READ_THREADS {1} \
   CONFIG.NUM_WRITE_OUTSTANDING {2} \
   CONFIG.NUM_WRITE_THREADS {1} \
   CONFIG.PROTOCOL {AXI3} \
   CONFIG.READ_WRITE_MODE {READ_WRITE} \
   CONFIG.RUSER_BITS_PER_BYTE {0} \
   CONFIG.RUSER_WIDTH {0} \
   CONFIG.SUPPORTS_NARROW_BURST {1} \
   CONFIG.WUSER_BITS_PER_BYTE {0} \
   CONFIG.WUSER_WIDTH {0} \
   ] $s_axi_1

  set s_axi_3 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi_3 ]
  set_property -dict [ list \
   CONFIG.ADDR_WIDTH {34} \
   CONFIG.ARUSER_WIDTH {0} \
   CONFIG.AWUSER_WIDTH {0} \
   CONFIG.BUSER_WIDTH {0} \
   CONFIG.DATA_WIDTH {256} \
   CONFIG.FREQ_HZ {250000000} \
   CONFIG.HAS_BRESP {1} \
   CONFIG.HAS_BURST {1} \
   CONFIG.HAS_CACHE {0} \
   CONFIG.HAS_LOCK {0} \
   CONFIG.HAS_PROT {0} \
   CONFIG.HAS_QOS {0} \
   CONFIG.HAS_REGION {0} \
   CONFIG.HAS_RRESP {1} \
   CONFIG.HAS_WSTRB {1} \
   CONFIG.ID_WIDTH {6} \
   CONFIG.MAX_BURST_LENGTH {16} \
   CONFIG.NUM_READ_OUTSTANDING {2} \
   CONFIG.NUM_READ_THREADS {1} \
   CONFIG.NUM_WRITE_OUTSTANDING {2} \
   CONFIG.NUM_WRITE_THREADS {1} \
   CONFIG.PROTOCOL {AXI3} \
   CONFIG.READ_WRITE_MODE {READ_WRITE} \
   CONFIG.RUSER_BITS_PER_BYTE {0} \
   CONFIG.RUSER_WIDTH {0} \
   CONFIG.SUPPORTS_NARROW_BURST {1} \
   CONFIG.WUSER_BITS_PER_BYTE {0} \
   CONFIG.WUSER_WIDTH {0} \
   ] $s_axi_3

  set s_axi_0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi_0 ]
  set_property -dict [ list \
   CONFIG.ADDR_WIDTH {34} \
   CONFIG.ARUSER_WIDTH {0} \
   CONFIG.AWUSER_WIDTH {0} \
   CONFIG.BUSER_WIDTH {0} \
   CONFIG.DATA_WIDTH {256} \
   CONFIG.FREQ_HZ {250000000} \
   CONFIG.HAS_BRESP {1} \
   CONFIG.HAS_BURST {1} \
   CONFIG.HAS_CACHE {0} \
   CONFIG.HAS_LOCK {0} \
   CONFIG.HAS_PROT {0} \
   CONFIG.HAS_QOS {0} \
   CONFIG.HAS_REGION {0} \
   CONFIG.HAS_RRESP {1} \
   CONFIG.HAS_WSTRB {1} \
   CONFIG.ID_WIDTH {6} \
   CONFIG.MAX_BURST_LENGTH {16} \
   CONFIG.NUM_READ_OUTSTANDING {2} \
   CONFIG.NUM_READ_THREADS {1} \
   CONFIG.NUM_WRITE_OUTSTANDING {2} \
   CONFIG.NUM_WRITE_THREADS {1} \
   CONFIG.PROTOCOL {AXI3} \
   CONFIG.READ_WRITE_MODE {READ_WRITE} \
   CONFIG.RUSER_BITS_PER_BYTE {0} \
   CONFIG.RUSER_WIDTH {0} \
   CONFIG.SUPPORTS_NARROW_BURST {1} \
   CONFIG.WUSER_BITS_PER_BYTE {0} \
   CONFIG.WUSER_WIDTH {0} \
   ] $s_axi_0


  # Create ports
  set axi_resetn [ create_bd_port -dir I axi_resetn ]
  set hbm_ref_clk [ create_bd_port -dir I -type clk -freq_hz 100000000 hbm_ref_clk ]
  set axi_clk [ create_bd_port -dir I -type clk -freq_hz 250000000 axi_clk ]
  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {s_axi_hbm:s_axis_dm_s2mm:s_axis_dm_s2mm_cmd:s_axis_dm_mm2s_cmd:m_axis_dm_mm2s:m_axis_dm_s2mm_status:m_axis_dm_mm2s_status:s_axi_2:s_axi_1:s_axi_3:s_axi_0} \
   CONFIG.CLK_DOMAIN {hbm_bd_0_0_axi_aclk} \
 ] $axi_clk
  set apb_complete_0 [ create_bd_port -dir O apb_complete_0 ]
  set apb_complete_1 [ create_bd_port -dir O apb_complete_1 ]

  # Create instance: hbm_0, and set properties
  set hbm_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:hbm:1.0 hbm_0 ]
  set_property -dict [list \
    CONFIG.USER_APB_EN {false} \
    CONFIG.USER_AXI_INPUT_CLK1_FREQ {250} \
    CONFIG.USER_AXI_INPUT_CLK_FREQ {250} \
    CONFIG.USER_HBM_DENSITY {16GB} \
    CONFIG.USER_MC0_REORDER_EN {false} \
    CONFIG.USER_MC0_USER_PARITY_EN {false} \
    CONFIG.USER_SAXI_00 {false} \
    CONFIG.USER_SAXI_01 {false} \
    CONFIG.USER_SAXI_02 {false} \
    CONFIG.USER_SAXI_03 {false} \
    CONFIG.USER_SAXI_04 {false} \
    CONFIG.USER_SAXI_05 {false} \
    CONFIG.USER_SAXI_06 {false} \
    CONFIG.USER_SAXI_07 {false} \
    CONFIG.USER_SAXI_08 {false} \
    CONFIG.USER_SAXI_09 {false} \
    CONFIG.USER_SAXI_10 {false} \
    CONFIG.USER_SAXI_11 {false} \
    CONFIG.USER_SAXI_12 {true} \
    CONFIG.USER_SAXI_13 {true} \
    CONFIG.USER_SAXI_14 {true} \
    CONFIG.USER_SAXI_16 {true} \
    CONFIG.USER_SAXI_17 {true} \
    CONFIG.USER_SAXI_18 {true} \
    CONFIG.USER_SAXI_19 {false} \
    CONFIG.USER_SAXI_20 {false} \
    CONFIG.USER_SAXI_21 {false} \
    CONFIG.USER_SAXI_22 {false} \
    CONFIG.USER_SAXI_23 {false} \
    CONFIG.USER_SAXI_24 {false} \
    CONFIG.USER_SAXI_25 {false} \
    CONFIG.USER_SAXI_26 {false} \
    CONFIG.USER_SAXI_27 {false} \
    CONFIG.USER_SAXI_28 {false} \
    CONFIG.USER_SAXI_29 {false} \
    CONFIG.USER_SAXI_30 {false} \
    CONFIG.USER_SAXI_31 {false} \
  ] $hbm_0


  # Create instance: clk_wiz_0, and set properties
  set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0 ]
  set_property -dict [list \
    CONFIG.CLKIN1_JITTER_PS {100.0} \
    CONFIG.CLKOUT1_JITTER {115.831} \
    CONFIG.CLKOUT1_PHASE_ERROR {87.180} \
    CONFIG.CLK_IN1_BOARD_INTERFACE {Custom} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {12.000} \
    CONFIG.MMCM_CLKIN1_PERIOD {10.000} \
    CONFIG.MMCM_CLKIN2_PERIOD {10.000} \
    CONFIG.MMCM_DIVCLK_DIVIDE {1} \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.RESET_PORT {resetn} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
  ] $clk_wiz_0


  # Create instance: proc_sys_reset_0, and set properties
  set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0 ]

  # Create instance: axi_datamover_0, and set properties
  set axi_datamover_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_datamover:5.1 axi_datamover_0 ]
  set_property -dict [list \
    CONFIG.c_addr_width {34} \
    CONFIG.c_dummy {1} \
    CONFIG.c_enable_cache_user {false} \
    CONFIG.c_include_mm2s_dre {false} \
    CONFIG.c_include_s2mm_dre {false} \
    CONFIG.c_m_axi_mm2s_data_width {512} \
    CONFIG.c_m_axi_mm2s_id_width {0} \
    CONFIG.c_m_axi_s2mm_data_width {512} \
    CONFIG.c_m_axi_s2mm_id_width {0} \
    CONFIG.c_m_axis_mm2s_tdata_width {512} \
    CONFIG.c_mm2s_btt_used {23} \
    CONFIG.c_mm2s_burst_size {64} \
    CONFIG.c_mm2s_include_sf {true} \
    CONFIG.c_s2mm_btt_used {23} \
    CONFIG.c_s2mm_burst_size {64} \
    CONFIG.c_s2mm_support_indet_btt {false} \
    CONFIG.c_s_axis_s2mm_tdata_width {512} \
    CONFIG.c_single_interface {0} \
  ] $axi_datamover_0


  # Create instance: smartconnect_1, and set properties
  set smartconnect_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_1 ]
  set_property -dict [list \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {1} \
  ] $smartconnect_1


  # Create instance: smartconnect_0, and set properties
  set smartconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_0 ]
  set_property -dict [list \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {1} \
  ] $smartconnect_0


  # Create instance: smartconnect_2, and set properties
  set smartconnect_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_2 ]
  set_property CONFIG.NUM_SI {1} $smartconnect_2


  # Create interface connections
  connect_bd_intf_net -intf_net S00_AXI_0_1 [get_bd_intf_ports s_axi_hbm] [get_bd_intf_pins smartconnect_0/S00_AXI]
  connect_bd_intf_net -intf_net S_AXIS_MM2S_CMD_0_1 [get_bd_intf_ports s_axis_dm_mm2s_cmd] [get_bd_intf_pins axi_datamover_0/S_AXIS_MM2S_CMD]
  connect_bd_intf_net -intf_net S_AXIS_S2MM_0_1 [get_bd_intf_ports s_axis_dm_s2mm] [get_bd_intf_pins axi_datamover_0/S_AXIS_S2MM]
  connect_bd_intf_net -intf_net S_AXIS_S2MM_CMD_0_1 [get_bd_intf_ports s_axis_dm_s2mm_cmd] [get_bd_intf_pins axi_datamover_0/S_AXIS_S2MM_CMD]
  connect_bd_intf_net -intf_net axi_datamover_0_M_AXIS_MM2S [get_bd_intf_ports m_axis_dm_mm2s] [get_bd_intf_pins axi_datamover_0/M_AXIS_MM2S]
  connect_bd_intf_net -intf_net axi_datamover_0_M_AXIS_MM2S_STS [get_bd_intf_ports m_axis_dm_mm2s_status] [get_bd_intf_pins axi_datamover_0/M_AXIS_MM2S_STS]
  connect_bd_intf_net -intf_net axi_datamover_0_M_AXIS_S2MM_STS [get_bd_intf_ports m_axis_dm_s2mm_status] [get_bd_intf_pins axi_datamover_0/M_AXIS_S2MM_STS]
  connect_bd_intf_net -intf_net axi_datamover_0_M_AXI_MM2S [get_bd_intf_pins axi_datamover_0/M_AXI_MM2S] [get_bd_intf_pins smartconnect_2/S00_AXI]
  connect_bd_intf_net -intf_net axi_datamover_0_M_AXI_S2MM [get_bd_intf_pins axi_datamover_0/M_AXI_S2MM] [get_bd_intf_pins smartconnect_1/S00_AXI]
  connect_bd_intf_net -intf_net s_axi_0_1 [get_bd_intf_ports s_axi_0] [get_bd_intf_pins hbm_0/SAXI_14_8HI]
  connect_bd_intf_net -intf_net s_axi_1_1 [get_bd_intf_ports s_axi_1] [get_bd_intf_pins hbm_0/SAXI_15_8HI]
  connect_bd_intf_net -intf_net s_axi_2_1 [get_bd_intf_ports s_axi_2] [get_bd_intf_pins hbm_0/SAXI_17_8HI]
  connect_bd_intf_net -intf_net s_axi_3_1 [get_bd_intf_ports s_axi_3] [get_bd_intf_pins hbm_0/SAXI_16_8HI]
  connect_bd_intf_net -intf_net smartconnect_0_M00_AXI [get_bd_intf_pins smartconnect_0/M00_AXI] [get_bd_intf_pins hbm_0/SAXI_12_8HI]
  connect_bd_intf_net -intf_net smartconnect_1_M00_AXI [get_bd_intf_pins smartconnect_1/M00_AXI] [get_bd_intf_pins hbm_0/SAXI_18_8HI]
  connect_bd_intf_net -intf_net smartconnect_2_M00_AXI [get_bd_intf_pins smartconnect_2/M00_AXI] [get_bd_intf_pins hbm_0/SAXI_13_8HI]

  # Create port connections
  connect_bd_net -net aclk_0_1  [get_bd_ports axi_clk] \
  [get_bd_pins hbm_0/AXI_15_ACLK] \
  [get_bd_pins smartconnect_1/aclk] \
  [get_bd_pins axi_datamover_0/m_axi_mm2s_aclk] \
  [get_bd_pins axi_datamover_0/m_axis_mm2s_cmdsts_aclk] \
  [get_bd_pins axi_datamover_0/m_axi_s2mm_aclk] \
  [get_bd_pins axi_datamover_0/m_axis_s2mm_cmdsts_awclk] \
  [get_bd_pins hbm_0/AXI_16_ACLK] \
  [get_bd_pins smartconnect_0/aclk] \
  [get_bd_pins hbm_0/AXI_13_ACLK] \
  [get_bd_pins hbm_0/AXI_14_ACLK] \
  [get_bd_pins hbm_0/AXI_17_ACLK] \
  [get_bd_pins hbm_0/AXI_18_ACLK] \
  [get_bd_pins smartconnect_2/aclk] \
  [get_bd_pins hbm_0/AXI_12_ACLK]
  connect_bd_net -net axi_aresetn_0  [get_bd_ports axi_resetn] \
  [get_bd_pins hbm_0/AXI_15_ARESET_N] \
  [get_bd_pins clk_wiz_0/resetn] \
  [get_bd_pins proc_sys_reset_0/ext_reset_in] \
  [get_bd_pins hbm_0/AXI_16_ARESET_N] \
  [get_bd_pins smartconnect_1/aresetn] \
  [get_bd_pins axi_datamover_0/m_axi_mm2s_aresetn] \
  [get_bd_pins axi_datamover_0/m_axis_s2mm_cmdsts_aresetn] \
  [get_bd_pins axi_datamover_0/m_axi_s2mm_aresetn] \
  [get_bd_pins axi_datamover_0/m_axis_mm2s_cmdsts_aresetn] \
  [get_bd_pins smartconnect_0/aresetn] \
  [get_bd_pins hbm_0/AXI_17_ARESET_N] \
  [get_bd_pins hbm_0/AXI_18_ARESET_N] \
  [get_bd_pins hbm_0/AXI_14_ARESET_N] \
  [get_bd_pins hbm_0/AXI_13_ARESET_N] \
  [get_bd_pins smartconnect_2/aresetn] \
  [get_bd_pins hbm_0/AXI_12_ARESET_N]
  connect_bd_net -net clk_in1_0_1  [get_bd_ports hbm_ref_clk] \
  [get_bd_pins clk_wiz_0/clk_in1]
  connect_bd_net -net clk_wiz_0_clk_out1  [get_bd_pins clk_wiz_0/clk_out1] \
  [get_bd_pins hbm_0/HBM_REF_CLK_0] \
  [get_bd_pins hbm_0/HBM_REF_CLK_1] \
  [get_bd_pins hbm_0/APB_0_PCLK] \
  [get_bd_pins hbm_0/APB_1_PCLK] \
  [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
  connect_bd_net -net clk_wiz_0_locked  [get_bd_pins clk_wiz_0/locked] \
  [get_bd_pins proc_sys_reset_0/dcm_locked]
  connect_bd_net -net hbm_0_apb_complete_0  [get_bd_pins hbm_0/apb_complete_0] \
  [get_bd_ports apb_complete_0]
  connect_bd_net -net hbm_0_apb_complete_1  [get_bd_pins hbm_0/apb_complete_1] \
  [get_bd_ports apb_complete_1]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn  [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
  [get_bd_pins hbm_0/APB_0_PRESET_N] \
  [get_bd_pins hbm_0/APB_1_PRESET_N]

  # Create address segments
  assign_bd_address -offset 0x00000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM00] -force
  assign_bd_address -offset 0x20000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM01] -force
  assign_bd_address -offset 0x40000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM02] -force
  assign_bd_address -offset 0x60000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM03] -force
  assign_bd_address -offset 0x80000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM04] -force
  assign_bd_address -offset 0xA0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM05] -force
  assign_bd_address -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM06] -force
  assign_bd_address -offset 0xE0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM07] -force
  assign_bd_address -offset 0x000100000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM08] -force
  assign_bd_address -offset 0x000120000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM09] -force
  assign_bd_address -offset 0x000140000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM10] -force
  assign_bd_address -offset 0x000160000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM11] -force
  assign_bd_address -offset 0x000180000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM12] -force
  assign_bd_address -offset 0x0001A0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM13] -force
  assign_bd_address -offset 0x0001C0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM14] -force
  assign_bd_address -offset 0x0001E0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM15] -force
  assign_bd_address -offset 0x000200000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM16] -force
  assign_bd_address -offset 0x000220000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM17] -force
  assign_bd_address -offset 0x000240000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM18] -force
  assign_bd_address -offset 0x000260000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM19] -force
  assign_bd_address -offset 0x000280000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM20] -force
  assign_bd_address -offset 0x0002A0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM21] -force
  assign_bd_address -offset 0x0002C0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM22] -force
  assign_bd_address -offset 0x0002E0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM23] -force
  assign_bd_address -offset 0x000300000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM24] -force
  assign_bd_address -offset 0x000320000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM25] -force
  assign_bd_address -offset 0x000340000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM26] -force
  assign_bd_address -offset 0x000360000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM27] -force
  assign_bd_address -offset 0x000380000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM28] -force
  assign_bd_address -offset 0x0003A0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM29] -force
  assign_bd_address -offset 0x0003C0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM30] -force
  assign_bd_address -offset 0x0003E0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs hbm_0/SAXI_13_8HI/HBM_MEM31] -force
  assign_bd_address -offset 0x00000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM00] -force
  assign_bd_address -offset 0x20000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM01] -force
  assign_bd_address -offset 0x40000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM02] -force
  assign_bd_address -offset 0x60000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM03] -force
  assign_bd_address -offset 0x80000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM04] -force
  assign_bd_address -offset 0xA0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM05] -force
  assign_bd_address -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM06] -force
  assign_bd_address -offset 0xE0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM07] -force
  assign_bd_address -offset 0x000100000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM08] -force
  assign_bd_address -offset 0x000120000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM09] -force
  assign_bd_address -offset 0x000140000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM10] -force
  assign_bd_address -offset 0x000160000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM11] -force
  assign_bd_address -offset 0x000180000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM12] -force
  assign_bd_address -offset 0x0001A0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM13] -force
  assign_bd_address -offset 0x0001C0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM14] -force
  assign_bd_address -offset 0x0001E0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM15] -force
  assign_bd_address -offset 0x000200000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM16] -force
  assign_bd_address -offset 0x000220000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM17] -force
  assign_bd_address -offset 0x000240000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM18] -force
  assign_bd_address -offset 0x000260000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM19] -force
  assign_bd_address -offset 0x000280000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM20] -force
  assign_bd_address -offset 0x0002A0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM21] -force
  assign_bd_address -offset 0x0002C0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM22] -force
  assign_bd_address -offset 0x0002E0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM23] -force
  assign_bd_address -offset 0x000300000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM24] -force
  assign_bd_address -offset 0x000320000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM25] -force
  assign_bd_address -offset 0x000340000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM26] -force
  assign_bd_address -offset 0x000360000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM27] -force
  assign_bd_address -offset 0x000380000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM28] -force
  assign_bd_address -offset 0x0003A0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM29] -force
  assign_bd_address -offset 0x0003C0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM30] -force
  assign_bd_address -offset 0x0003E0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs hbm_0/SAXI_18_8HI/HBM_MEM31] -force
  assign_bd_address -offset 0x00000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM00] -force
  assign_bd_address -offset 0x20000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM01] -force
  assign_bd_address -offset 0x40000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM02] -force
  assign_bd_address -offset 0x60000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM03] -force
  assign_bd_address -offset 0x80000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM04] -force
  assign_bd_address -offset 0xA0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM05] -force
  assign_bd_address -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM06] -force
  assign_bd_address -offset 0xE0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM07] -force
  assign_bd_address -offset 0x000100000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM08] -force
  assign_bd_address -offset 0x000120000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM09] -force
  assign_bd_address -offset 0x000140000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM10] -force
  assign_bd_address -offset 0x000160000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM11] -force
  assign_bd_address -offset 0x000180000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM12] -force
  assign_bd_address -offset 0x0001A0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM13] -force
  assign_bd_address -offset 0x0001C0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM14] -force
  assign_bd_address -offset 0x0001E0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM15] -force
  assign_bd_address -offset 0x000200000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM16] -force
  assign_bd_address -offset 0x000220000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM17] -force
  assign_bd_address -offset 0x000240000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM18] -force
  assign_bd_address -offset 0x000260000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM19] -force
  assign_bd_address -offset 0x000280000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM20] -force
  assign_bd_address -offset 0x0002A0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM21] -force
  assign_bd_address -offset 0x0002C0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM22] -force
  assign_bd_address -offset 0x0002E0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM23] -force
  assign_bd_address -offset 0x000300000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM24] -force
  assign_bd_address -offset 0x000320000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM25] -force
  assign_bd_address -offset 0x000340000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM26] -force
  assign_bd_address -offset 0x000360000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM27] -force
  assign_bd_address -offset 0x000380000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM28] -force
  assign_bd_address -offset 0x0003A0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM29] -force
  assign_bd_address -offset 0x0003C0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM30] -force
  assign_bd_address -offset 0x0003E0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs hbm_0/SAXI_14_8HI/HBM_MEM31] -force
  assign_bd_address -offset 0x00000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM00] -force
  assign_bd_address -offset 0x20000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM01] -force
  assign_bd_address -offset 0x40000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM02] -force
  assign_bd_address -offset 0x60000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM03] -force
  assign_bd_address -offset 0x80000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM04] -force
  assign_bd_address -offset 0xA0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM05] -force
  assign_bd_address -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM06] -force
  assign_bd_address -offset 0xE0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM07] -force
  assign_bd_address -offset 0x000100000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM08] -force
  assign_bd_address -offset 0x000120000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM09] -force
  assign_bd_address -offset 0x000140000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM10] -force
  assign_bd_address -offset 0x000160000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM11] -force
  assign_bd_address -offset 0x000180000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM12] -force
  assign_bd_address -offset 0x0001A0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM13] -force
  assign_bd_address -offset 0x0001C0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM14] -force
  assign_bd_address -offset 0x0001E0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM15] -force
  assign_bd_address -offset 0x000200000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM16] -force
  assign_bd_address -offset 0x000220000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM17] -force
  assign_bd_address -offset 0x000240000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM18] -force
  assign_bd_address -offset 0x000260000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM19] -force
  assign_bd_address -offset 0x000280000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM20] -force
  assign_bd_address -offset 0x0002A0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM21] -force
  assign_bd_address -offset 0x0002C0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM22] -force
  assign_bd_address -offset 0x0002E0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM23] -force
  assign_bd_address -offset 0x000300000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM24] -force
  assign_bd_address -offset 0x000320000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM25] -force
  assign_bd_address -offset 0x000340000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM26] -force
  assign_bd_address -offset 0x000360000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM27] -force
  assign_bd_address -offset 0x000380000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM28] -force
  assign_bd_address -offset 0x0003A0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM29] -force
  assign_bd_address -offset 0x0003C0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM30] -force
  assign_bd_address -offset 0x0003E0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs hbm_0/SAXI_15_8HI/HBM_MEM31] -force
  assign_bd_address -offset 0x00000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM00] -force
  assign_bd_address -offset 0x20000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM01] -force
  assign_bd_address -offset 0x40000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM02] -force
  assign_bd_address -offset 0x60000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM03] -force
  assign_bd_address -offset 0x80000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM04] -force
  assign_bd_address -offset 0xA0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM05] -force
  assign_bd_address -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM06] -force
  assign_bd_address -offset 0xE0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM07] -force
  assign_bd_address -offset 0x000100000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM08] -force
  assign_bd_address -offset 0x000120000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM09] -force
  assign_bd_address -offset 0x000140000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM10] -force
  assign_bd_address -offset 0x000160000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM11] -force
  assign_bd_address -offset 0x000180000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM12] -force
  assign_bd_address -offset 0x0001A0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM13] -force
  assign_bd_address -offset 0x0001C0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM14] -force
  assign_bd_address -offset 0x0001E0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM15] -force
  assign_bd_address -offset 0x000200000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM16] -force
  assign_bd_address -offset 0x000220000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM17] -force
  assign_bd_address -offset 0x000240000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM18] -force
  assign_bd_address -offset 0x000260000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM19] -force
  assign_bd_address -offset 0x000280000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM20] -force
  assign_bd_address -offset 0x0002A0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM21] -force
  assign_bd_address -offset 0x0002C0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM22] -force
  assign_bd_address -offset 0x0002E0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM23] -force
  assign_bd_address -offset 0x000300000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM24] -force
  assign_bd_address -offset 0x000320000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM25] -force
  assign_bd_address -offset 0x000340000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM26] -force
  assign_bd_address -offset 0x000360000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM27] -force
  assign_bd_address -offset 0x000380000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM28] -force
  assign_bd_address -offset 0x0003A0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM29] -force
  assign_bd_address -offset 0x0003C0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM30] -force
  assign_bd_address -offset 0x0003E0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs hbm_0/SAXI_17_8HI/HBM_MEM31] -force
  assign_bd_address -offset 0x00000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM00] -force
  assign_bd_address -offset 0x20000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM01] -force
  assign_bd_address -offset 0x40000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM02] -force
  assign_bd_address -offset 0x60000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM03] -force
  assign_bd_address -offset 0x80000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM04] -force
  assign_bd_address -offset 0xA0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM05] -force
  assign_bd_address -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM06] -force
  assign_bd_address -offset 0xE0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM07] -force
  assign_bd_address -offset 0x000100000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM08] -force
  assign_bd_address -offset 0x000120000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM09] -force
  assign_bd_address -offset 0x000140000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM10] -force
  assign_bd_address -offset 0x000160000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM11] -force
  assign_bd_address -offset 0x000180000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM12] -force
  assign_bd_address -offset 0x0001A0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM13] -force
  assign_bd_address -offset 0x0001C0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM14] -force
  assign_bd_address -offset 0x0001E0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM15] -force
  assign_bd_address -offset 0x000200000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM16] -force
  assign_bd_address -offset 0x000220000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM17] -force
  assign_bd_address -offset 0x000240000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM18] -force
  assign_bd_address -offset 0x000260000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM19] -force
  assign_bd_address -offset 0x000280000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM20] -force
  assign_bd_address -offset 0x0002A0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM21] -force
  assign_bd_address -offset 0x0002C0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM22] -force
  assign_bd_address -offset 0x0002E0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM23] -force
  assign_bd_address -offset 0x000300000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM24] -force
  assign_bd_address -offset 0x000320000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM25] -force
  assign_bd_address -offset 0x000340000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM26] -force
  assign_bd_address -offset 0x000360000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM27] -force
  assign_bd_address -offset 0x000380000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM28] -force
  assign_bd_address -offset 0x0003A0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM29] -force
  assign_bd_address -offset 0x0003C0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM30] -force
  assign_bd_address -offset 0x0003E0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs hbm_0/SAXI_16_8HI/HBM_MEM31] -force
  assign_bd_address -offset 0x00000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM00] -force
  assign_bd_address -offset 0x20000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM01] -force
  assign_bd_address -offset 0x40000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM02] -force
  assign_bd_address -offset 0x60000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM03] -force
  assign_bd_address -offset 0x80000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM04] -force
  assign_bd_address -offset 0xA0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM05] -force
  assign_bd_address -offset 0xC0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM06] -force
  assign_bd_address -offset 0xE0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM07] -force
  assign_bd_address -offset 0x000100000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM08] -force
  assign_bd_address -offset 0x000120000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM09] -force
  assign_bd_address -offset 0x000140000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM10] -force
  assign_bd_address -offset 0x000160000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM11] -force
  assign_bd_address -offset 0x000180000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM12] -force
  assign_bd_address -offset 0x0001A0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM13] -force
  assign_bd_address -offset 0x0001C0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM14] -force
  assign_bd_address -offset 0x0001E0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM15] -force
  assign_bd_address -offset 0x000200000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM16] -force
  assign_bd_address -offset 0x000220000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM17] -force
  assign_bd_address -offset 0x000240000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM18] -force
  assign_bd_address -offset 0x000260000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM19] -force
  assign_bd_address -offset 0x000280000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM20] -force
  assign_bd_address -offset 0x0002A0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM21] -force
  assign_bd_address -offset 0x0002C0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM22] -force
  assign_bd_address -offset 0x0002E0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM23] -force
  assign_bd_address -offset 0x000300000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM24] -force
  assign_bd_address -offset 0x000320000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM25] -force
  assign_bd_address -offset 0x000340000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM26] -force
  assign_bd_address -offset 0x000360000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM27] -force
  assign_bd_address -offset 0x000380000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM28] -force
  assign_bd_address -offset 0x0003A0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM29] -force
  assign_bd_address -offset 0x0003C0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM30] -force
  assign_bd_address -offset 0x0003E0000000 -range 0x20000000 -target_address_space [get_bd_addr_spaces s_axi_hbm] [get_bd_addr_segs hbm_0/SAXI_12_8HI/HBM_MEM31] -force


  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


