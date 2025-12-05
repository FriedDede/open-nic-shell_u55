
`include "common_cells_assertions.svh"
`include "common_cells_registers.svh"
`include "snitch_vm_typedef.svh"
`include "axi_assign.svh"
`include "axi_typedef.svh"
`include "register_interface_assign.svh"
`include "register_interface_typedef.svh"

module snitch_core_axi import snitch_pkg::*; import fpnew_pkg::*; import riscv_instr::*; #(
  /// Address width of the buses
  parameter int unsigned AddrWidth          = 64,
  /// Data width of the buses.
  parameter int unsigned DataWidth          = 64,
  /// AXI: id width in.
  parameter int unsigned IdWidthIn          = 4,
  parameter int unsigned IdWidthAcc         = 5,
  /// AXI: user width.
  parameter int unsigned UserWidth          = 1,
  /// Boot address of core.
  parameter logic [31:0] BootAddr           = 32'h0000_0000,
  /// Reduced-register extension
  parameter bit          RVE                = 0,
  /// Enable F and D Extension
  parameter bit          RVF                = 1,
  parameter bit          RVD                = 1,
  parameter bit          XDivSqrt           = 1,
  parameter bit          XF8                = 0,
  parameter bit          XF8ALT             = 0,
  parameter bit          XF16               = 0,
  parameter bit          XF16ALT            = 0,
  parameter bit          XFVEC              = 0,
  parameter bit          XFDOTP             = 0,
  /// Enable Snitch DMA
  parameter bit          Xdma               = 0,
  /// Has `frep` support.
  parameter bit          Xfrep              = 0,
  /// Has `SSR` support.
  parameter bit          Xssr               = 0,
  /// Has `IPU` support.
  parameter bit          Xipu               = 0,
  /// Has virtual memory support.
  parameter bit          VMSupport          = 0,

  parameter int unsigned NumIntOutstandingLoads = 16,
  parameter int unsigned NumIntOutstandingMem = 16,

  parameter int unsigned NumDTLBEntries = 0,
  parameter int unsigned NumITLBEntries = 0,
  /// Width of a single icache line.
  parameter int unsigned ICacheLineWidth    = 64,
  /// Number of icache lines per set.
  parameter int unsigned ICacheLineCount    = 128,
  /// Number of icache sets.
  parameter int unsigned ICacheSets         = 4,
  /// Add isochronous clock-domain crossings e.g.,
  parameter bit          IsoCrossing        = 1,
  /// Timing Parameters
  parameter snitch_pma_pkg::snitch_pma_t SnitchPMACfg = '{default: 0},
  /// Consistency Address Queue (CAQ) parameters.
  parameter int unsigned CaqDepth     = 8,
  parameter int unsigned CaqTagWidth  = 16,
  /// Enable debug support.
  parameter bit          DebugSupport = 0
) 
(
  input   logic                                   clk_i,
  input   logic                                   rst_ni,
  input   logic [31:0]                            hart_id_i,
  input   snitch_pkg::interrupts_t                irq_i,            

  output  snitch_cluster_pkg::narrow_out_req_t    inst_out_req_o,
  input   snitch_cluster_pkg::narrow_out_resp_t   inst_out_resp_i,

  output  snitch_cluster_pkg::narrow_out_req_t    data_core_out_req_o,
  input   snitch_cluster_pkg::narrow_out_resp_t   data_core_out_resp_i,

  output  snitch_cluster_pkg::narrow_out_req_t    data_fpu_out_req_o,
  input   snitch_cluster_pkg::narrow_out_resp_t   data_fpu_out_resp_i
);

  // FPU CONFIG
    localparam int unsigned NumFPOutstandingLoads = 16;
    localparam int unsigned NumFPOutstandingMem = 16;
    localparam int unsigned NumFPUSequencerInstr = 0;
    localparam fpnew_pkg::fpu_implementation_t FPUImplementation = fpnew_pkg::CUSTOM_SNITCH;
    localparam bit XFauxMerged  = (FPUImplementation.UnitTypes[3] == fpnew_pkg::MERGED);
    localparam bit FPEn = RVF | RVD | XF16 | XF16ALT | XF8 | XF8ALT | XFVEC | XFauxMerged | XFDOTP;
    localparam int unsigned FLEN =  RVD     ? 64 : // D ext.
                                    RVF     ? 32 : // F ext.
                                    XF16    ? 16 : // Xf16 ext.
                                    XF16ALT ? 16 : // Xf16alt ext.
                                    XF8     ? 8 : // Xf8 ext.
                                    XF8ALT  ? 8 : // Xf8alt ext.
                                    0; // Unused in case of no FP
  
  // BUS DATATYPES AND STRUCTS
    typedef logic [AddrWidth-1:0]       addr_t;
    typedef logic [DataWidth-1:0]       data_t;
    typedef logic [DataWidth/8-1:0]     strb_t;
    typedef logic [IdWidthIn-1:0]       id_mst_t;
    typedef logic [IdWidthIn-1:0]      id_slv_t;
    typedef logic [UserWidth-1:0]       user_t;
    typedef struct packed {
      snitch_pkg::acc_addr_e   addr;
      logic [IdWidthAcc - 1:0] id;
      logic [31:0]             data_op;
      data_t                   data_arga;
      data_t                   data_argb;
      data_t                   data_argc;
    } acc_req_t;
    typedef struct packed {
      logic [IdWidthAcc - 1:0] id;
      logic       error;
      data_t      data;
    } acc_resp_t;

    `AXI_TYPEDEF_ALL(axi_mst, addr_t, id_mst_t, data_t, strb_t, user_t)
    `AXI_TYPEDEF_ALL(axi_slv, addr_t, id_slv_t, data_t, strb_t, user_t)
    `REQRSP_TYPEDEF_ALL(reqrsp, addr_t, data_t, strb_t)
    `REG_BUS_TYPEDEF_REQ(reg_req_t, addr_t, data_t, strb_t)
    `REG_BUS_TYPEDEF_RSP(reg_rsp_t, data_t)

  // snitch perf counter
  snitch_pkg::core_events_t snitch_events;
  snitch_pkg::core_events_t fpu_events;
  // pragma translate_off
  snitch_pkg::fpu_trace_port_t fpu_trace;
  snitch_pkg::fpu_sequencer_trace_port_t fpu_ss_trace;
  // pragma translate_on

  // core <-> cache 
  addr_t         inst_addr_o;
  logic          inst_cacheable_o;
  logic [31:0]   inst_data_i;
  logic          inst_valid_o;
  logic          inst_ready_i;
  logic          flush_i_valid_o;
  logic          flush_i_ready_i;
  reqrsp_req_t   data_req_o;
  reqrsp_rsp_t   data_rsp_i;

  // core <-> acc 
  logic          caq_valid_i;
  logic          acc_qvalid_o;
  logic          acc_qready_i;
  logic          acc_pvalid_i;
  logic          acc_pready_o;
  acc_req_t      acc_req_o;
  acc_resp_t     acc_resp_i;
  // spill register
  acc_resp_t     acc_resp_reg;
  logic          acc_pvalid_reg;
  logic          acc_pready_reg;
  // fpu
  logic          acc_fpu_qvalid;
  logic          acc_fpu_qready;
  logic          acc_fpu_pvalid;
  logic          acc_fpu_pready;
  acc_resp_t     acc_fpu_resp;
  // muldiv
  logic          acc_muldiv_qvalid;
  logic          acc_muldiv_qready;
  logic          acc_muldiv_qvalid_reg;
  logic          acc_muldiv_qready_reg;
  logic          acc_muldiv_pvalid;
  logic          acc_muldiv_pready;
  acc_resp_t     acc_muldiv_resp;
  acc_req_t      acc_muldiv_req;

// core <-> fpu control 
  fpnew_pkg::roundmode_e fpu_rnd_mode;
  fpnew_pkg::fmt_mode_t  fpu_fmt_mode;
  fpnew_pkg::status_t    fpu_status;

// snitch integer core
  snitch #(
    .AddrWidth (AddrWidth),
    .DataWidth (DataWidth),
    .acc_req_t (acc_req_t),
    .acc_resp_t (acc_resp_t),
    .dreq_t (reqrsp_req_t),
    .drsp_t (reqrsp_rsp_t),
    .pa_t (),
    .l0_pte_t (snitch_l0_tlb_tb_pkg::l0_pte_t),
    .BootAddr (BootAddr),
    .SnitchPMACfg (SnitchPMACfg),
    .NumIntOutstandingLoads (NumIntOutstandingLoads),
    .NumIntOutstandingMem (NumIntOutstandingMem),
    .VMSupport (VMSupport),
    .NumDTLBEntries (NumDTLBEntries),
    .NumITLBEntries (NumITLBEntries),
    .RVE (RVE),
    .FP_EN (FPEn),
    .Xdma (Xdma),
    .Xssr (Xssr),
    .RVF (RVF),
    .RVD (RVD),
    .XDivSqrt (XDivSqrt),
    .XF16 (XF16),
    .XF16ALT (XF16ALT),
    .XF8 (XF8),
    .XF8ALT (XF8ALT),
    .XFVEC (XFVEC),
    .XFDOTP (XFDOTP),
    .XFAUX (XFauxMerged),
    .FLEN (FLEN),
    .CaqDepth (CaqDepth),
    .CaqTagWidth (CaqTagWidth),
    .DebugSupport (DebugSupport)
  ) i_snitch (
    .clk_i            (clk_i),
    .rst_i            (~rst_ni ),
    .hart_id_i        (hart_id_i),
    .irq_i            (irq_i),
    // to instruction cache
    .flush_i_valid_o  (flush_i_valid_o),
    .flush_i_ready_i  (flush_i_ready_i),
    .inst_addr_o      (inst_addr_o),
    .inst_cacheable_o (inst_cacheable_o),
    .inst_data_i      (inst_data_i),
    .inst_valid_o     (inst_valid_o),
    .inst_ready_i     (inst_ready_i),
    // we don't use any accelerator, only the integer core
    .acc_qreq_o       (acc_req_o),
    .acc_qvalid_o     (acc_qvalid_o),
    .acc_qready_i     (acc_qready_i),
    .acc_prsp_i       (acc_resp_i),
    .acc_pvalid_i     (acc_pvalid_i),
    .acc_pready_o     (acc_pready_o),
    .caq_pvalid_i     (caq_valid_i),
    // data req_rsp channel
    .data_req_o       (data_req_o),
    .data_rsp_i       (data_rsp_i),
    // we don't use address translaction
    .ptw_valid_o      (),
    .ptw_ready_i      ('0),
    .ptw_va_o         (),
    .ptw_ppn_o        (),
    .ptw_pte_i        ('0),
    .ptw_is_4mega_i   ('0),
    // we don't use fpu at the moment
    .fpu_rnd_mode_o   (fpu_rnd_mode),
    .fpu_fmt_mode_o   (fpu_fmt_mode),
    .fpu_status_i     (fpu_status),
    // core events for perf counters
    .core_events_o    (snitch_events),
    // we don't use hw barriers
    .barrier_o        (),
    .barrier_i        ('0)
  );

// core side spill register (maybe is not necessary ?)
  isochronous_spill_register #(
    .T (acc_resp_t),
    .Bypass ('1)
  ) i_spill_register_acc_demux_resp (
    .src_clk_i   ( clk_i          ),
    .src_rst_ni  ( rst_ni         ),
    .src_valid_i ( acc_pvalid_reg ),
    .src_ready_o ( acc_pready_reg ),
    .src_data_i  ( acc_resp_reg   ),
    .dst_clk_i   ( clk_i          ),
    .dst_rst_ni  ( rst_ni         ),
    .dst_valid_o ( acc_pvalid_i   ),
    .dst_ready_i ( acc_pready_o   ),
    .dst_data_o  ( acc_resp_i     )
  );
// instruction LO cache
  snitch_cluster_pkg::narrow_out_req_t axi_inst_to_cut_req;
  snitch_cluster_pkg::narrow_out_resp_t axi_inst_to_cut_rsp;
  snitch_cluster_pkg::sram_cfgs_t sram_cfgs_i = snitch_cluster_pkg::sram_cfgs_t'('0);
  snitch_icache #(
    .NR_FETCH_PORTS     ( 1                ),
    .L0_LINE_COUNT      ( 8                ),
    .LINE_WIDTH         ( ICacheLineWidth  ),
    .LINE_COUNT         ( ICacheLineCount  ),
    .SET_COUNT          ( ICacheSets       ),
    .FETCH_AW           ( AddrWidth        ),
    .FETCH_DW           ( 32               ),
    .FILL_AW            ( AddrWidth        ),
    .FILL_DW            ( DataWidth        ),
    .SERIAL_LOOKUP      ( 0                ),
    .L1_TAG_SCM         ( 0                ),
    .NUM_AXI_OUTSTANDING( 1                ),
    .EARLY_LATCH        ( 0                ),
    .L0_EARLY_TAG_WIDTH ( snitch_pkg::PageShift - $clog2(ICacheLineWidth/8) ),
    .ISO_CROSSING       ( IsoCrossing     ),
    .sram_cfg_tag_t     ( snitch_cluster_pkg::sram_cfg_t ),
    .sram_cfg_data_t    ( snitch_cluster_pkg::sram_cfgs_t ),
    .axi_req_t          ( snitch_cluster_pkg::narrow_out_req_t ),
    .axi_rsp_t          ( snitch_cluster_pkg::narrow_out_resp_t )
  ) i_snitch_icache (
    .clk_i (clk_i),
    .clk_d2_i (clk_i),
    .rst_ni (rst_ni),
    .enable_prefetching_i ('1),
    .icache_events_o  (),
    .flush_valid_i    ( flush_i_valid_o  ),
    .flush_ready_o    ( flush_i_ready_i  ),
    .inst_addr_i      ( inst_addr_o      ),
    .inst_cacheable_i ( inst_cacheable_o ),
    .inst_data_o      ( inst_data_i      ),
    .inst_valid_i     ( inst_valid_o     ),
    .inst_ready_o     ( inst_ready_i     ),
    .inst_error_o     ( ),
    .sram_cfg_tag_i   ( sram_cfgs_i.icache_tag  ),
    .sram_cfg_data_i  ( sram_cfgs_i.icache_data ),
    .axi_req_o        ( axi_inst_to_cut_req),
    .axi_rsp_i        ( axi_inst_to_cut_rsp)
  );

// Acc port demux to fpu and muldiv and resp stream arbiter
  stream_demux #(
  .N_OUP ( 2 )
  ) i_stream_demux_offload (
    .inp_valid_i  ( acc_qvalid_o  ),
    .inp_ready_o  ( acc_qready_i  ),
    .oup_sel_i    ( acc_req_o.addr[$clog2(2)-1:0]        ),
    .oup_valid_o  ( { acc_muldiv_qvalid, acc_fpu_qvalid} ),
    .oup_ready_i  ( { acc_muldiv_qready, acc_fpu_qready} )
  );
  stream_arbiter #(
    .DATA_T      ( acc_resp_t ),
    .N_INP       ( 2          )
  ) i_stream_arbiter_offload (
    .clk_i       ( clk_i                              ),
    .rst_ni      ( rst_ni                             ),
    .inp_data_i  ( {acc_muldiv_resp,   acc_fpu_resp   } ),
    .inp_valid_i ( {acc_muldiv_pvalid, acc_fpu_pvalid } ),
    .inp_ready_o ( {acc_muldiv_pready, acc_fpu_pready } ),
    .oup_data_o  ( acc_resp_reg                      ),
    .oup_valid_o ( acc_pvalid_reg                ),
    .oup_ready_i ( acc_pready_reg                )
  );
// Snitch FPU sequencer and FPU instance
  reqrsp_req_t   data_fpu_req_o;
  reqrsp_rsp_t   data_fpu_rsp_i;
  // if necessary we can run the fpu at a different clock, will need to resync the axi channels in this case

  
 logic fpu_clk;
clk_int_div_static #(
  .DIV_VALUE (2),
  .ENABLE_CLOCK_IN_RESET ('1)
)i_clk_div(
  .clk_i,
  .rst_ni,
  .en_i ('1),
  .test_mode_en_i ('0),
  .clk_o(fpu_clk)
);
snitch_fp_ss #(
  .DataWidth  (DataWidth),
  .AddrWidth  (AddrWidth),
  .NumFPOutstandingLoads (NumFPOutstandingLoads),
  .NumFPOutstandingMem (NumFPOutstandingMem),
  .NumFPUSequencerInstr (NumFPUSequencerInstr),
  .dreq_t (reqrsp_req_t),
  .drsp_t (reqrsp_rsp_t),
  .acc_req_t (acc_req_t),
  .acc_resp_t (acc_resp_t),
  .Xssr (Xssr),
  .Xfrep (Xfrep),
  .RVF (RVF),
  .RVD (RVD),
  .XF16 (XF16),
  .XF16ALT (XF16ALT),
  .XF8 (XF8),
  .XF8ALT (XF8ALT),
  .XFVEC (XFVEC),
  .FPUImplementation(FPUImplementation)
) i_snitch_fp_ss (
  .clk_i                      (clk_i),
  .rst_i                      (~rst_ni),
  // pragma translate_off
  .trace_port_o               (fpu_trace),
  .sequencer_tracer_port_o    (fpu_ss_trace),
  // pragma translate_on
  .hart_id_i                  (hart_id_i),
  // aac inteface - fpu side  
  .acc_req_i                  (acc_req_o),
  .acc_req_valid_i            (acc_fpu_qvalid),
  .acc_req_ready_o            (acc_fpu_qready),
  .acc_resp_o                 (acc_fpu_resp),
  .acc_resp_valid_o           (acc_fpu_pvalid),
  .acc_resp_ready_i           (acc_fpu_pready),
  // fpu lsu        
  .data_req_o                 (data_fpu_req_o),
  .data_rsp_i                 (data_fpu_rsp_i),
  // fpu channel        
  .fpu_rnd_mode_i             (fpu_rnd_mode),
  .fpu_fmt_mode_i             (fpu_fmt_mode),
  .fpu_status_o               (fpu_status),
  // ssr        
  .ssr_raddr_o                (),
  .ssr_rdata_i                ('0),
  .ssr_rvalid_o               (),
  .ssr_rready_i               ('0),
  .ssr_rdone_o                (),
  .ssr_waddr_o                (),
  .ssr_wdata_o                (),
  .ssr_wvalid_o               (),
  .ssr_wready_i               ('0),
  .ssr_wdone_o                (),
  // ssr control        
  .streamctl_done_i           ('0),
  .streamctl_valid_i          ('0),
  .streamctl_ready_o          (),
  // caqq       
  .caq_pvalid_o               (caq_valid_i),
  .core_events_o              (fpu_events)
);

// muldiv unit and req spill register
  spill_register  #(
    .T      ( acc_req_t  ),
    .Bypass ( 1'b1       )
  ) i_spill_register_muldiv (
    .clk_i   ,
    .rst_ni  ( rst_ni              ),
    .valid_i ( acc_muldiv_qvalid   ),
    .ready_o ( acc_muldiv_qready   ),
    .data_i  ( acc_req_o           ),
    .valid_o ( acc_muldiv_qvalid_reg ),
    .ready_i ( acc_muldiv_qready_reg ),
    .data_o  ( acc_muldiv_req      )
  );
  snitch_shared_muldiv #(
    .DataWidth (DataWidth),
    .IdWidth   (IdWidthAcc)
  ) i_snitch_shared_muldiv (
    .clk_i            ( clk_i                ),
    .rst_ni           ( rst_ni               ),
    .acc_qaddr_i      ( acc_muldiv_req.addr       ),
    .acc_qid_i        ( acc_muldiv_req.id         ),
    .acc_qdata_op_i   ( acc_muldiv_req.data_op    ),
    .acc_qdata_arga_i ( acc_muldiv_req.data_arga  ),
    .acc_qdata_argb_i ( acc_muldiv_req.data_argb  ),
    .acc_qdata_argc_i ( acc_muldiv_req.data_argc  ),
    .acc_qvalid_i     ( acc_muldiv_qvalid_reg),
    .acc_qready_o     ( acc_muldiv_qready_reg),
    .acc_pdata_o      ( acc_muldiv_resp.data ),
    .acc_pid_o        ( acc_muldiv_resp.id   ),
    .acc_perror_o     ( acc_muldiv_resp.error),
    .acc_pvalid_o     ( acc_muldiv_pvalid    ),
    .acc_pready_i     ( acc_muldiv_pready    )
  );

// convert CORE reqrsp data channel to an AXI channel
  snitch_cluster_pkg::narrow_out_req_t axi_core_data_to_cut_req;
  snitch_cluster_pkg::narrow_out_resp_t axi_core_data_to_cut_rsp;
  reqrsp_to_axi #(
    .DataWidth  (DataWidth),
    .UserWidth  (UserWidth),
    .reqrsp_req_t (reqrsp_req_t),
    .reqrsp_rsp_t (reqrsp_rsp_t),
    .axi_req_t  (snitch_cluster_pkg::narrow_out_req_t),
    .axi_rsp_t  (snitch_cluster_pkg::narrow_out_resp_t)
  ) d_reqrsp_to_axi_out (
    .clk_i,
    .rst_ni,
    .user_i ('0),
    .reqrsp_req_i (data_req_o),
    .reqrsp_rsp_o (data_rsp_i),
    .axi_req_o    (axi_core_data_to_cut_req),
    .axi_rsp_i    (axi_core_data_to_cut_rsp)
  );

// convert FPU reqrsp data channel to an AXI channel
  snitch_cluster_pkg::narrow_out_req_t axi_fpu_data_to_cut_req;
  snitch_cluster_pkg::narrow_out_resp_t axi_fpu_data_to_cut_rsp;
  reqrsp_to_axi #(
    .DataWidth  (DataWidth),
    .UserWidth  (UserWidth),
    .reqrsp_req_t (reqrsp_req_t),
    .reqrsp_rsp_t (reqrsp_rsp_t),
    .axi_req_t  (snitch_cluster_pkg::narrow_out_req_t),
    .axi_rsp_t  (snitch_cluster_pkg::narrow_out_resp_t)
  ) d_fpu_reqrsp_to_axi_out (
    .clk_i,
    .rst_ni,
    .user_i ('0),
    .reqrsp_req_i (data_fpu_req_o),
    .reqrsp_rsp_o (data_fpu_rsp_i),
    .axi_req_o    (axi_fpu_data_to_cut_req),
    .axi_rsp_i    (axi_fpu_data_to_cut_rsp)
  );

// decouple CORE data AXI output port
  axi_cut #(
    .Bypass     ( '1 ),
    .aw_chan_t  ( axi_slv_aw_chan_t ),
    .w_chan_t   ( axi_slv_w_chan_t ),
    .b_chan_t   ( axi_slv_b_chan_t ),
    .ar_chan_t  ( axi_slv_ar_chan_t ),
    .r_chan_t   ( axi_slv_r_chan_t ),
    .axi_req_t  ( snitch_cluster_pkg::narrow_out_req_t ),
    .axi_resp_t ( snitch_cluster_pkg::narrow_out_resp_t )
  ) i_core_cut_ext_data_mst (
    .clk_i      ( clk_i           ),
    .rst_ni     ( rst_ni          ),
    .slv_req_i  ( axi_core_data_to_cut_req),
    .slv_resp_o ( axi_core_data_to_cut_rsp),
    .mst_req_o  ( data_core_out_req_o   ),
    .mst_resp_i ( data_core_out_resp_i   )
  );

// decouple FPU data AXI output port
  axi_cut #(
    .Bypass     ( '1 ),
    .aw_chan_t  ( axi_slv_aw_chan_t ),
    .w_chan_t   ( axi_slv_w_chan_t ),
    .b_chan_t   ( axi_slv_b_chan_t ),
    .ar_chan_t  ( axi_slv_ar_chan_t ),
    .r_chan_t   ( axi_slv_r_chan_t ),
    .axi_req_t  ( snitch_cluster_pkg::narrow_out_req_t ),
    .axi_resp_t ( snitch_cluster_pkg::narrow_out_resp_t )
  ) i_fpu_cut_ext_data_mst (
    .clk_i      ( clk_i           ),
    .rst_ni     ( rst_ni          ),
    .slv_req_i  ( axi_fpu_data_to_cut_req),
    .slv_resp_o ( axi_fpu_data_to_cut_rsp),
    .mst_req_o  ( data_fpu_out_req_o   ),
    .mst_resp_i ( data_fpu_out_resp_i   )
  );

// decouple inst AXI output port
  axi_cut #(
    .Bypass     ( '1 ),
    .aw_chan_t  ( axi_slv_aw_chan_t ),
    .w_chan_t   ( axi_slv_w_chan_t ),
    .b_chan_t   ( axi_slv_b_chan_t ),
    .ar_chan_t  ( axi_slv_ar_chan_t ),
    .r_chan_t   ( axi_slv_r_chan_t ),
    .axi_req_t  ( snitch_cluster_pkg::narrow_out_req_t ),
    .axi_resp_t ( snitch_cluster_pkg::narrow_out_resp_t )
  ) i_cut_ext_inst_mst (
    .clk_i      ( clk_i           ),
    .rst_ni     ( rst_ni          ),
    .slv_req_i  ( axi_inst_to_cut_req),
    .slv_resp_o ( axi_inst_to_cut_rsp),
    .mst_req_o  ( inst_out_req_o   ),
    .mst_resp_i ( inst_out_resp_i   )
  );

endmodule