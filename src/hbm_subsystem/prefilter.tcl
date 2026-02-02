
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
set design_name prefilter_bd

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
xilinx.com:ip:axi_datamover:5.1\
xilinx.com:ip:system_ila:1.1\
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

  set M00_AXI_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M00_AXI_0 ]
  set_property -dict [ list \
   CONFIG.ADDR_WIDTH {34} \
   CONFIG.DATA_WIDTH {512} \
   CONFIG.FREQ_HZ {250000000} \
   CONFIG.NUM_READ_OUTSTANDING {4} \
   CONFIG.NUM_WRITE_OUTSTANDING {4} \
   CONFIG.PROTOCOL {AXI4} \
   ] $M00_AXI_0

  set M_AXI_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI_0 ]
  set_property -dict [ list \
   CONFIG.ADDR_WIDTH {34} \
   CONFIG.DATA_WIDTH {512} \
   CONFIG.FREQ_HZ {250000000} \
   CONFIG.HAS_BURST {0} \
   CONFIG.HAS_LOCK {0} \
   CONFIG.HAS_QOS {0} \
   CONFIG.HAS_REGION {0} \
   CONFIG.NUM_READ_OUTSTANDING {2} \
   CONFIG.NUM_WRITE_OUTSTANDING {2} \
   CONFIG.PROTOCOL {AXI4} \
   ] $M_AXI_0


  # Create ports
  set axi_resetn [ create_bd_port -dir I axi_resetn ]
  set axi_clk [ create_bd_port -dir I -type clk -freq_hz 250000000 axi_clk ]
  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {s_axis_dm_s2mm:s_axis_dm_s2mm_cmd:s_axis_dm_mm2s_cmd:m_axis_dm_mm2s:m_axis_dm_s2mm_status:m_axis_dm_mm2s_status:s_axi_2:s_axi_1:s_axi_3:s_axi_0:M00_AXI_0:M_AXI_0} \
   CONFIG.CLK_DOMAIN {hbm_bd_0_0_axi_aclk} \
 ] $axi_clk

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
    CONFIG.c_single_interface {1} \
  ] $axi_datamover_0


  # Create instance: system_ila_0, and set properties
  set system_ila_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:1.1 system_ila_0 ]
  set_property -dict [list \
    CONFIG.C_DATA_DEPTH {1024} \
    CONFIG.C_NUM_MONITOR_SLOTS {2} \
    CONFIG.C_SLOT {1} \
    CONFIG.C_SLOT_0_MAX_RD_BURSTS {4} \
    CONFIG.C_SLOT_0_MAX_WR_BURSTS {4} \
  ] $system_ila_0


  # Create instance: axi_interconnect_0, and set properties
  set axi_interconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0 ]
  set_property -dict [list \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {4} \
    CONFIG.S00_HAS_DATA_FIFO {2} \
    CONFIG.S01_HAS_DATA_FIFO {2} \
    CONFIG.S02_HAS_DATA_FIFO {2} \
    CONFIG.S03_HAS_DATA_FIFO {2} \
    CONFIG.STRATEGY {2} \
  ] $axi_interconnect_0


  # Create interface connections
  connect_bd_intf_net -intf_net S_AXIS_MM2S_CMD_0_1 [get_bd_intf_ports s_axis_dm_mm2s_cmd] [get_bd_intf_pins axi_datamover_0/S_AXIS_MM2S_CMD]
  connect_bd_intf_net -intf_net S_AXIS_S2MM_0_1 [get_bd_intf_ports s_axis_dm_s2mm] [get_bd_intf_pins axi_datamover_0/S_AXIS_S2MM]
  connect_bd_intf_net -intf_net S_AXIS_S2MM_CMD_0_1 [get_bd_intf_ports s_axis_dm_s2mm_cmd] [get_bd_intf_pins axi_datamover_0/S_AXIS_S2MM_CMD]
  connect_bd_intf_net -intf_net axi_datamover_0_M_AXI [get_bd_intf_ports M_AXI_0] [get_bd_intf_pins axi_datamover_0/M_AXI]
connect_bd_intf_net -intf_net [get_bd_intf_nets axi_datamover_0_M_AXI] [get_bd_intf_ports M_AXI_0] [get_bd_intf_pins system_ila_0/SLOT_1_AXI]
  connect_bd_intf_net -intf_net axi_datamover_0_M_AXIS_MM2S [get_bd_intf_ports m_axis_dm_mm2s] [get_bd_intf_pins axi_datamover_0/M_AXIS_MM2S]
  connect_bd_intf_net -intf_net axi_datamover_0_M_AXIS_MM2S_STS [get_bd_intf_ports m_axis_dm_mm2s_status] [get_bd_intf_pins axi_datamover_0/M_AXIS_MM2S_STS]
  connect_bd_intf_net -intf_net axi_datamover_0_M_AXIS_S2MM_STS [get_bd_intf_ports m_axis_dm_s2mm_status] [get_bd_intf_pins axi_datamover_0/M_AXIS_S2MM_STS]
  connect_bd_intf_net -intf_net s_axi_0_1 [get_bd_intf_ports s_axi_0] [get_bd_intf_pins axi_interconnect_0/S00_AXI]
  connect_bd_intf_net -intf_net s_axi_1_1 [get_bd_intf_ports s_axi_1] [get_bd_intf_pins axi_interconnect_0/S01_AXI]
  connect_bd_intf_net -intf_net s_axi_2_1 [get_bd_intf_ports s_axi_2] [get_bd_intf_pins axi_interconnect_0/S03_AXI]
  connect_bd_intf_net -intf_net s_axi_3_1 [get_bd_intf_ports s_axi_3] [get_bd_intf_pins axi_interconnect_0/S02_AXI]
  connect_bd_intf_net -intf_net smartconnect_3_M00_AXI [get_bd_intf_ports M00_AXI_0] [get_bd_intf_pins axi_interconnect_0/M00_AXI]
connect_bd_intf_net -intf_net [get_bd_intf_nets smartconnect_3_M00_AXI] [get_bd_intf_ports M00_AXI_0] [get_bd_intf_pins system_ila_0/SLOT_0_AXI]

  # Create port connections
  connect_bd_net -net aclk_0_1  [get_bd_ports axi_clk] \
  [get_bd_pins axi_datamover_0/m_axi_mm2s_aclk] \
  [get_bd_pins axi_datamover_0/m_axis_mm2s_cmdsts_aclk] \
  [get_bd_pins axi_datamover_0/m_axi_s2mm_aclk] \
  [get_bd_pins axi_datamover_0/m_axis_s2mm_cmdsts_awclk] \
  [get_bd_pins system_ila_0/clk] \
  [get_bd_pins axi_interconnect_0/ACLK] \
  [get_bd_pins axi_interconnect_0/S00_ACLK] \
  [get_bd_pins axi_interconnect_0/M00_ACLK] \
  [get_bd_pins axi_interconnect_0/S01_ACLK] \
  [get_bd_pins axi_interconnect_0/S02_ACLK] \
  [get_bd_pins axi_interconnect_0/S03_ACLK]
  connect_bd_net -net axi_aresetn_0  [get_bd_ports axi_resetn] \
  [get_bd_pins axi_datamover_0/m_axi_mm2s_aresetn] \
  [get_bd_pins axi_datamover_0/m_axis_s2mm_cmdsts_aresetn] \
  [get_bd_pins axi_datamover_0/m_axi_s2mm_aresetn] \
  [get_bd_pins axi_datamover_0/m_axis_mm2s_cmdsts_aresetn] \
  [get_bd_pins system_ila_0/resetn] \
  [get_bd_pins axi_interconnect_0/S01_ARESETN] \
  [get_bd_pins axi_interconnect_0/S03_ARESETN] \
  [get_bd_pins axi_interconnect_0/S02_ARESETN] \
  [get_bd_pins axi_interconnect_0/M00_ARESETN] \
  [get_bd_pins axi_interconnect_0/S00_ARESETN] \
  [get_bd_pins axi_interconnect_0/ARESETN]

  # Create address segments
  assign_bd_address -offset 0x00000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces axi_datamover_0/Data] [get_bd_addr_segs M_AXI_0/Reg] -force
  assign_bd_address -offset 0x00000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces s_axi_0] [get_bd_addr_segs M00_AXI_0/Reg] -force
  assign_bd_address -offset 0x00000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces s_axi_1] [get_bd_addr_segs M00_AXI_0/Reg] -force
  assign_bd_address -offset 0x00000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces s_axi_2] [get_bd_addr_segs M00_AXI_0/Reg] -force
  assign_bd_address -offset 0x00000000 -range 0x000400000000 -target_address_space [get_bd_addr_spaces s_axi_3] [get_bd_addr_segs M00_AXI_0/Reg] -force


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


