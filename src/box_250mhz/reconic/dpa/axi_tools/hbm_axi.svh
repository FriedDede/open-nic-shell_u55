`ifndef AXI_ASSIGN_SVH_HBM
`define AXI_ASSIGN_SVH_HBM

//////////////////////////////////////////////////////////////
// assign an axi req resp pair to an hbm channel, using new pulp axi
// pat = "S00" or "S01" etc
`define AXI_ASSIGN_MASTER_TO_HBM(pat, req, rsp) \
  .``pat``_AXI_0_awvalid  (req.aw_valid)       ,  \
  .``pat``_AXI_0_awid     (req.aw.id)          ,  \
  .``pat``_AXI_0_awaddr   ({4'b00000, req.aw.addr[29:0]})  ,  \
  .``pat``_AXI_0_awlen    (req.aw.len)         ,  \
  .``pat``_AXI_0_awsize   (req.aw.size)        ,  \
  .``pat``_AXI_0_awburst  (req.aw.burst)       ,  \
  .``pat``_AXI_0_awlock   (req.aw.lock)        ,  \
  .``pat``_AXI_0_awcache  (req.aw.cache)       ,  \
  .``pat``_AXI_0_awprot   (req.aw.prot)        ,  \
  .``pat``_AXI_0_awqos    (req.aw.qos)         ,  \
//.``pat``_AXI_0_awregion (req.aw.region)      ,  \
//.``pat``_AXI_0_awuser   (req.aw.user)        ,  \
  .``pat``_AXI_0_wvalid   (req.w_valid)        ,  \
  .``pat``_AXI_0_wdata    (req.w.data)         ,  \
  .``pat``_AXI_0_wstrb    (req.w.strb)         ,  \
  .``pat``_AXI_0_wlast    (req.w.last)         ,  \
//.``pat``_AXI_0_wuser    (req.w.user)         ,  \
  .``pat``_AXI_0_bready   (req.b_ready)        ,  \
  .``pat``_AXI_0_arvalid  (req.ar_valid)       ,  \
  .``pat``_AXI_0_arid     (req.ar.id)          ,  \
  .``pat``_AXI_0_araddr   ({4'b00000, req.ar.addr[29:0]})  ,  \
  .``pat``_AXI_0_arlen    (req.ar.len)         ,  \
  .``pat``_AXI_0_arsize   (req.ar.size)        ,  \
  .``pat``_AXI_0_arburst  (req.ar.burst)       ,  \
  .``pat``_AXI_0_arlock   (req.ar.lock)        ,  \
  .``pat``_AXI_0_arcache  (req.ar.cache)       ,  \
  .``pat``_AXI_0_arprot   (req.ar.prot)        ,  \
  .``pat``_AXI_0_arqos    (req.ar.qos)         ,  \
//.``pat``_AXI_0_arregion (req.ar.region)      ,  \
//.``pat``_AXI_0_aruser   (req.ar.user)        ,  \
  .``pat``_AXI_0_rready   (req.r_ready)        ,  \
  .``pat``_AXI_0_awready (rsp.aw_ready)        ,  \
  .``pat``_AXI_0_arready (rsp.ar_ready)        ,  \
  .``pat``_AXI_0_wready  (rsp.w_ready )        ,  \
  .``pat``_AXI_0_bvalid  (rsp.b_valid )        ,  \
  .``pat``_AXI_0_bid     (rsp.b.id    )        ,  \
  .``pat``_AXI_0_bresp   (rsp.b.resp  )        ,  \
//.``pat``_AXI_0_buser   (rsp.b.user  )        ,  \
  .``pat``_AXI_0_rvalid  (rsp.r_valid )        ,  \
  .``pat``_AXI_0_rid     (rsp.r.id    )        ,  \
  .``pat``_AXI_0_rdata   (rsp.r.data  )        ,  \
  .``pat``_AXI_0_rresp   (rsp.r.resp  )        ,  \
  .``pat``_AXI_0_rlast   (rsp.r.last  )        
//.``pat``_AXI_0_ruser   (rsp.r.user  )  

`define AXI_ASSIGN_FLAT(pat, req, rsp) \
  assign ``pat``_awvalid  = req.aw_valid       ;  \
  assign ``pat``_awid     = req.aw.id          ;  \
  assign ``pat``_awaddr   = {4'b00000, req.aw.addr[29:0]}  ;  \
  assign ``pat``_awlen    = req.aw.len         ;  \
  assign ``pat``_awsize   = req.aw.size        ;  \
  assign ``pat``_awburst  = req.aw.burst       ;  \
  assign ``pat``_awlock   = req.aw.lock        ;  \
  assign ``pat``_awcache  = req.aw.cache       ;  \
  assign ``pat``_awprot   = req.aw.prot        ;  \
  assign ``pat``_awqos    = req.aw.qos         ;  \
//assign ``pat``_awregion = req.aw.region      ;  \
//assign ``pat``_awuser   = req.aw.user        ;  \
  assign ``pat``_wvalid   = req.w_valid        ;  \
  assign ``pat``_wdata    = req.w.data         ;  \
  assign ``pat``_wstrb    = req.w.strb         ;  \
  assign ``pat``_wlast    = req.w.last         ;  \
//assign ``pat``_wuser    = req.w.user         ;  \
  assign ``pat``_bready   = req.b_ready        ;  \
  assign ``pat``_arvalid  = req.ar_valid       ;  \
  assign ``pat``_arid     = req.ar.id          ;  \
  assign ``pat``_araddr   = {4'b00000, req.ar.addr[29:0]}  ;  \
  assign ``pat``_arlen    = req.ar.len         ;  \
  assign ``pat``_arsize   = req.ar.size        ;  \
  assign ``pat``_arburst  = req.ar.burst       ;  \
  assign ``pat``_arlock   = req.ar.lock        ;  \
  assign ``pat``_arcache  = req.ar.cache       ;  \
  assign ``pat``_arprot   = req.ar.prot        ;  \
  assign ``pat``_arqos    = req.ar.qos         ;  \
//assign ``pat``_arregion = req.ar.region      ;  \
//assign ``pat``_aruser   = req.ar.user        ;  \
  assign ``pat``_rready   = req.r_ready        ;  \
  assign ``pat``_awready  = rsp.aw_ready        ;  \
  assign ``pat``_arready  = rsp.ar_ready        ;  \
  assign ``pat``_wready   = rsp.w_ready         ;  \
  assign ``pat``_bvalid   = rsp.b_valid         ;  \
  assign ``pat``_bid      = rsp.b.id            ;  \
  assign ``pat``_bresp    = rsp.b.resp          ;  \
//assign ``pat``_buser    = rsp.b.user          ;  \
  assign ``pat``_rvalid   = rsp.r_valid         ;  \
  assign ``pat``_rid      = rsp.r.id            ;  \
  assign ``pat``_rdata    = rsp.r.data          ;  \
  assign ``pat``_rresp    = rsp.r.resp          ;  \
  assign ``pat``_rlast    = rsp.r.last  ;        
//assign ``pat``_ruser    = rsp.r.user    

// adapter between snitch new axi interface and ariane old one
`define AXI_ASSIGN_MASTER_TO_ARIANE_AXI_INT(slave, req, rsp) \
  assign slave.aw_valid  = req.aw_valid;  \
  assign slave.aw_id     = req.aw.id;     \
  assign slave.aw_addr   = req.aw.addr[30:0];   \
  assign slave.aw_len    = req.aw.len;    \
  assign slave.aw_size   = req.aw.size;   \
  assign slave.aw_burst  = req.aw.burst;  \
  assign slave.aw_lock   = req.aw.lock;   \
  assign slave.aw_cache  = req.aw.cache;  \
  assign slave.aw_prot   = req.aw.prot;   \
  assign slave.aw_qos    = req.aw.qos;    \
  assign slave.aw_region = req.aw.region; \
  assign slave.aw_user   = req.aw.user;   \
                                    \
  assign slave.w_valid   = req.w_valid;   \
  assign slave.w_data    = req.w.data;    \
  assign slave.w_strb    = req.w.strb;    \
  assign slave.w_last    = req.w.last;    \
  assign slave.w_user    = req.w.user;    \
                                   \
  assign slave.b_ready   = req.b_ready;   \
                                   \
  assign slave.ar_valid  = req.ar_valid;  \
  assign slave.ar_id     = req.ar.id;     \
  assign slave.ar_addr   = req.ar.addr[30:0];   \
  assign slave.ar_len    = req.ar.len;    \
  assign slave.ar_size   = req.ar.size;   \
  assign slave.ar_burst  = req.ar.burst;  \
  assign slave.ar_lock   = req.ar.lock;   \
  assign slave.ar_cache  = req.ar.cache;  \
  assign slave.ar_prot   = req.ar.prot;   \
  assign slave.ar_qos    = req.ar.qos;    \
  assign slave.ar_region = req.ar.region; \
  assign slave.ar_user   = req.ar.user;   \
                                            \
  assign slave.r_ready   = req.r_ready;   \
                                                 \
  assign rsp.aw_ready = slave.aw_ready;   \
  assign rsp.ar_ready = slave.ar_ready;   \
  assign rsp.w_ready  = slave.w_ready;    \
                                    \
  assign rsp.b_valid  = slave.b_valid;    \
  assign rsp.b.id     = slave.b_id;       \
  assign rsp.b.resp   = slave.b_resp;     \
  assign rsp.b.user   = slave.b_user;     \
                                    \
  assign rsp.r_valid  = slave.r_valid;    \
  assign rsp.r.id     = slave.r_id;       \
  assign rsp.r.data   = slave.r_data;     \
  assign rsp.r.resp   = slave.r_resp;     \
  assign rsp.r.last   = slave.r_last;     \
  assign rsp.r.user   = slave.r_user;     

//////////////////////////////////////////////////////////////
// assign an axi req resp pair to an hbm channel, using old ariane axi
// pat = "S00" or "S01" etc
`define AXI_ASSIGN_MASTER_TO_HBM_ARIANE(pat, bus) \
  assign pat``_AXI_0_awvalid  = bus.aw_valid;  \
  assign pat``_AXI_0_awid     = bus.aw_id;     \
  assign pat``_AXI_0_awaddr   = bus.aw_addr[30:0]; \
  assign pat``_AXI_0_awlen    = bus.aw_len;    \
  assign pat``_AXI_0_awsize   = bus.aw_size;   \
  assign pat``_AXI_0_awburst  = bus.aw_burst;  \
  assign pat``_AXI_0_awlock   = bus.aw_lock;   \
  assign pat``_AXI_0_awcache  = bus.aw_cache;  \
  assign pat``_AXI_0_awprot   = bus.aw_prot;   \
  assign pat``_AXI_0_awqos    = bus.aw_qos;    \
  assign pat``_AXI_0_awregion = bus.aw_region; \
  assign pat``_AXI_0_awuser   = bus.aw_user;   \
                                        \
  assign pat``_AXI_0_wvalid   = bus.w_valid;   \
  assign pat``_AXI_0_wdata    = bus.w_data;    \
  assign pat``_AXI_0_wstrb    = bus.w_strb;    \
  assign pat``_AXI_0_wlast    = bus.w_last;    \
  assign pat``_AXI_0_wuser    = bus.w_user;    \
                                        \
  assign pat``_AXI_0_bready   = bus.b_ready;   \
                                        \
  assign pat``_AXI_0_arvalid  = bus.ar_valid;  \
  assign pat``_AXI_0_arid     = bus.ar_id;     \
  assign pat``_AXI_0_araddr   = bus.ar_addr[30:0];\
  assign pat``_AXI_0_arlen    = bus.ar_len;    \
  assign pat``_AXI_0_arsize   = bus.ar_size;   \
  assign pat``_AXI_0_arburst  = bus.ar_burst;  \
  assign pat``_AXI_0_arlock   = bus.ar_lock;   \
  assign pat``_AXI_0_arcache  = bus.ar_cache;  \
  assign pat``_AXI_0_arprot   = bus.ar_prot;   \
  assign pat``_AXI_0_arqos    = bus.ar_qos;    \
  assign pat``_AXI_0_arregion = bus.ar_region; \
  assign pat``_AXI_0_aruser   = bus.ar_user;   \
                                          \
  assign pat``_AXI_0_rready   = req.r_ready;   \
                                                 \
  assign bus.aw_ready = pat``_AXI_0_awready;   \
  assign bus.ar_ready = pat``_AXI_0_arready;   \
  assign bus.w_ready  = pat``_AXI_0_wready;    \
                                         \
  assign bus.b_valid  = pat``_AXI_0_bvalid;    \
  assign bus.b_id     = pat``_AXI_0_bid;       \
  assign bus.b_resp   = pat``_AXI_0_bresp;     \
  assign bus.b_user   = pat``_AXI_0_buser;     \
                                         \
  assign bus.r_valid  = pat``_AXI_0_rvalid;    \
  assign bus.r_id     = pat``_AXI_0_rid;       \
  assign bus.r_data   = pat``_AXI_0_rdata;     \
  assign bus.r_resp   = pat``_AXI_0_rresp;     \
  assign bus.r_last   = pat``_AXI_0_rlast;     \
  assign bus.r_user   = pat``_AXI_0_ruser;     


`endif
//////////////////////////////////////////////////////////////
// HBM axi channel port macro
//`define AXI_HBM_CHANNEL(tag)  \
//  .tag``_AXI_0_araddr   ,   \  
//  .tag``_AXI_0_arburst  ,   \
//  .tag``_AXI_0_arcache  ,   \
//  .tag``_AXI_0_arid     ,   \
//  .tag``_AXI_0_arlen    ,   \
//  .tag``_AXI_0_arlock   ,   \
//  .tag``_AXI_0_arprot   ,   \
//  .tag``_AXI_0_arqos    ,   \
//  .tag``_AXI_0_arready  ,   \
//  .tag``_AXI_0_arsize   ,   \
//  .tag``_AXI_0_arvalid  ,   \
//  .tag``_AXI_0_awaddr   ,   \  
//  .tag``_AXI_0_awburst  ,   \
//  .tag``_AXI_0_awcache  ,   \
//  .tag``_AXI_0_awid     ,   \
//  .tag``_AXI_0_awlen    ,   \
//  .tag``_AXI_0_awlock   ,   \
//  .tag``_AXI_0_awprot   ,   \
//  .tag``_AXI_0_awqos    ,   \
//  .tag``_AXI_0_awready  ,   \
//  .tag``_AXI_0_awsize   ,   \
//  .tag``_AXI_0_awvalid  ,   \
//  .tag``_AXI_0_bid      ,   \
//  .tag``_AXI_0_bready   ,   \
//  .tag``_AXI_0_bresp    ,   \
//  .tag``_AXI_0_bvalid   ,   \
//  .tag``_AXI_0_rdata    ,   \
//  .tag``_AXI_0_rid      ,   \
//  .tag``_AXI_0_rlast    ,   \
//  .tag``_AXI_0_rready   ,   \
//  .tag``_AXI_0_rresp    ,   \
//  .tag``_AXI_0_rvalid   ,   \
//  .tag``_AXI_0_wdata    ,   \
//  .tag``_AXI_0_wlast    ,   \
//  .tag``_AXI_0_wready   ,   \
//  .tag``_AXI_0_wstrb    ,   \
//  .tag``_AXI_0_wvalid      
//`endif