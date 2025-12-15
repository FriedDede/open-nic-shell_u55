`include "axi_typedef.svh"

package dpa_pkg; import axi_pkg::*; import snitch_cluster_pkg::*;

// COMPUTE ENGINE PARAMETERS

localparam BOOT_ADDR            = 32'h0000_0000;
localparam CORE_NUMBER          = 1;
localparam CLUSTER_NUMBER       = 1;
localparam TOTAL_CORE_NUMBER    = CORE_NUMBER * CLUSTER_NUMBER;
localparam PERIF_NUMBER         = 3; // uart, timer, plic
localparam DRAM_CH_NUMBER       = CLUSTER_NUMBER; // snitch clusters
localparam ce_AddrWidth         = snitch_cluster_pkg::AddrWidth;            // 32
localparam ce_DataWidth         = snitch_cluster_pkg::NarrowDataWidth;      // 64
localparam ce_IdWidthCore       = snitch_cluster_pkg::NarrowIdWidthIn;      // 4 
localparam ce_IdWidthToUncore   = ce_IdWidthCore + $clog2(3 * CORE_NUMBER);  // 4 + 2 (each core exposes 3 channels)
localparam ce_IdWidthToPerifs   = ce_IdWidthToUncore + $clog2(CLUSTER_NUMBER); 
localparam ce_IdWidth_unif_dram   = ce_IdWidthToUncore + $clog2(CLUSTER_NUMBER); 
localparam ce_UserWidth         = snitch_cluster_pkg::NarrowUserWidth;


typedef logic [ce_AddrWidth-1:0]          ce2mem_addr_t;
typedef logic [ce_DataWidth-1:0]          ce2mem_data_t;
typedef logic [ce_DataWidth/8-1:0]        ce2mem_strb_t;
typedef logic [ce_IdWidthToUncore-1:0]    ce2mem_narrow_id_t;
typedef logic [ce_UserWidth-1:0]          ce2mem_user_t;

`AXI_TYPEDEF_ALL(axim64_core2mem, ce2mem_addr_t,  ce2mem_narrow_id_t,  ce2mem_data_t,  ce2mem_strb_t,  ce2mem_user_t)


// AXI STREAMING TO AXI MM 512 bit INTERFACE PARAMETERS

localparam int unsigned AddrWidth = 64;
localparam int unsigned DataWidth = 512;
localparam int unsigned IdWidth = 16;
localparam int unsigned UserWidth = 48;

typedef logic [AddrWidth-1:0]       addr_t;
typedef logic [DataWidth-1:0]       data_t;
typedef logic [DataWidth/8-1:0]     strb_t;
typedef logic [IdWidth-1:0]         narrow_id_t;
typedef logic [UserWidth-1:0]       user_t;

`AXI_TYPEDEF_ALL(axim512_dpa, addr_t, narrow_id_t, data_t, strb_t, user_t)

endpackage
