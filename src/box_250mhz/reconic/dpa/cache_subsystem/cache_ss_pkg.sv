
`include "axi_typedef.svh"


package cache_ss_pkg; 

    // cache size:
    localparam int unsigned CACHE_BLOCK_SIZE = 128;
    localparam int unsigned CACHE_BLOCK_SIZE_SIM = 256;

    localparam int unsigned CACHE_SIZE       = 32 * 1024;
    localparam int unsigned CACHE_SIZE_SIM   = 32 * 1024;
    // AXI to mem

    localparam int unsigned AddrWidth = 32;
    localparam int unsigned DataWidth = 512;
    localparam int unsigned IdWidth   = 6;
    localparam int unsigned UserWidth = 1;

    typedef logic [AddrWidth-1:0]   addr_t;
    typedef logic [DataWidth-1:0]   data_t;
    typedef logic [DataWidth/8-1:0] strb_t;
    typedef logic [IdWidth-1:0]     id_t;
    typedef logic [UserWidth-1:0]   user_t;

    `AXI_TYPEDEF_ALL(axi_cache, addr_t, id_t, data_t, strb_t, user_t)

    // CE + DM -> cache arbitration (dpa.sv): both masters are normalized to
    // CE's native id/user width, and the 2:1 mux adds one port-select id bit
    // must equal dpa_pkg::ce_IdWidthToUncore / ce_UserWidth (checked in dpa.sv)
    localparam int unsigned CACHE_ARB_ID_WIDTH     = 5; // CE id: 1 + $clog2(3 * 4 cores), must be >= IdWidth (4)
    localparam int unsigned CACHE_ARB_MUX_ID_WIDTH = CACHE_ARB_ID_WIDTH + 1;      // +$clog2(2 slave ports)

endpackage