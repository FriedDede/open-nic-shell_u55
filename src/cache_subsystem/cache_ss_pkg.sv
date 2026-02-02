package cache_ss_pkg;

    // AXI to mem

    localparam int unsigned AddrWidth = 34;
    localparam int unsigned DataWidth = 64;
    localparam int unsigned IdWidth   = 4;
    localparam int unsigned UserWidth = 0;

    typedef logic [AddrWidth-1:0]   addr_t;
    typedef logic [DataWidth-1:0]   data_t;
    typedef logic [DataWidth/8-1:0] strb_t;
    typedef logic [IdWidth-1:0]     id_t;
    typedef logic [UserWidth-1:0]   user_t;

    `AXI_TYPEDEF_ALL(axi_cache, addr_t, id_t, data_t, strb_t, user_t)

endpackage