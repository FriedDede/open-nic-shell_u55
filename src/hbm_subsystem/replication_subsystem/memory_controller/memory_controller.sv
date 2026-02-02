`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/01/2025 10:21:43 AM
// Design Name: 
// Module Name: Memory_Controller
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision: 
// Revision 0.02 - File Created  
// Additional Comments: 
// 
//////////////////////////////////////////////////////////////////////////////////


module memory_controller #(
    parameter  int BUCKET_SIZE       = 1024,
    parameter  int CMD_WIDTH         = 80,
    parameter  int CMD_STATUS_WIDTH  = 8,
    parameter  int DATA_WIDTH        = 512,
    parameter  int TKEEP_WIDTH       = DATA_WIDTH/8,
    parameter  int TUSER_WIDTH       = 16,
    parameter  int CMD_FIFO_DEPTH    = 32,
    parameter  int STREAM_FIFO_DEPTH = 64,
    parameter  int KEY_WIDTH         = 64,
    localparam int HASH_WIDTH        = 34 - $clog2(BUCKET_SIZE)
)(
    
    // 250Mhz Memory Controller Clock & Reset.
    input logic                         aclk,
    input logic                         aresetn,
    
    // HBM Stack Interface complete (FSM Starters)
    input logic                         abp_complete0,

    // Master AXI-Stream signals [To Replication Engine]
    input  logic                        m_axis_tready,
    output logic [DATA_WIDTH-1:0]       m_axis_tdata,
    output logic [TKEEP_WIDTH-1:0]      m_axis_tkeep,
    output logic                        m_axis_tlast,
    output logic                        m_axis_tvalid,

    // Master AXI-Stream signals [From DataMover]
    output logic                        s_dm_axis_tready,
    input  logic [DATA_WIDTH-1:0]       s_dm_axis_tdata,
    input  logic [TKEEP_WIDTH-1:0]      s_dm_axis_tkeep,
    input  logic                        s_dm_axis_tlast,
    input  logic                        s_dm_axis_tvalid,

    // Slave AXI-Stream signals [From Replication Engine]
    output logic                        s_axis_tready,
    input  logic [DATA_WIDTH-1:0]       s_axis_tdata,
    input  logic [TKEEP_WIDTH-1:0]      s_axis_tkeep,
    input  logic                        s_axis_tlast,
    input  logic                        s_axis_tvalid,

    // Slave AXI-Stream signals [To DataMover]
    input  logic                        m_dm_axis_tready,
    output logic [DATA_WIDTH-1:0]       m_dm_axis_tdata,
    output logic [TKEEP_WIDTH-1:0]      m_dm_axis_tkeep,
    output logic                        m_dm_axis_tlast,
    output logic                        m_dm_axis_tvalid,
    
    // Metadata mem_in
    input  st_metadata                  metadata_mem_in,
    input  logic                        metadata_mem_in_valid,

    // Metadata mem_out
    output st_metadata                  metadata_mem_out,
    output logic                        metadata_mem_out_valid,

    // Bvalid in
    input  logic [1:0]                  s_bresp,
    input  logic                        s_bvalid,
    input  logic                        s_bready,

    // MM2S Commands
    input  logic                        mm2s_cmd_tready,
    output logic [CMD_WIDTH-1:0]        mm2s_cmd_tdata,
    output logic                        mm2s_cmd_tvalid,

    // S2MM Commands
    input  logic                        s2mm_cmd_tready,
    output logic [CMD_WIDTH-1:0]        s2mm_cmd_tdata,
    output logic                        s2mm_cmd_tvalid,

    // MM2S Status
    input  logic [CMD_STATUS_WIDTH-1:0] s_axis_mm2s_sts_tdata,
    input  logic                        s_axis_mm2s_sts_tkeep,
    input  logic                        s_axis_mm2s_sts_tlast,
    input  logic                        s_axis_mm2s_sts_tvalid,
    output logic                        s_axis_mm2s_sts_tready,

    // S2MM Status
    input  logic [CMD_STATUS_WIDTH-1:0] s_axis_s2mm_sts_tdata,
    input  logic                        s_axis_s2mm_sts_tkeep,
    input  logic                        s_axis_s2mm_sts_tlast,
    input  logic                        s_axis_s2mm_sts_tvalid,
    output logic                        s_axis_s2mm_sts_tready

    );


    // BTT
    localparam logic [22:0] BTT = 23'h400;


    //////////////////////////////////////////////////////////////////
    // Hash Mechanism
    //////////////////////////////////////////////////////////////////

    // Precomputed pseudo-random 34-bit constants
    localparam logic [HASH_WIDTH-1:0] HASH_MATRIX [KEY_WIDTH-1:0] = '{
        24'hA3C5D1, 24'hD4F921, 24'h98B337, 24'h345678,
        24'hEAD00F, 24'hADC0DE, 24'h55AAAA, 24'hACE123,
        24'hF23456, 24'hBEEF12, 24'h0FFEE0, 24'hBADB07,
        24'hBCDEF0, 24'hBCDE12, 24'h4679BD, 24'h2468AC,
        24'hAAAAAA, 24'hBBBBBB, 24'hCCCCCC, 24'h234567,
        24'h654321, 24'hEDCBA9, 24'hACEACE, 24'hC001D0,
        24'hEADC0D, 24'hADD00D, 24'h0DEC0D, 24'hDCAFE,
        24'h3579BF, 24'h468ACE, 24'h579BDF, 24'h68ACED,
        24'h55AAAA, 24'h66BBBB, 24'h77CCCC, 24'h88DDDD,
        24'h99EEEE, 24'hAAFFFF, 24'hBBB111, 24'hCCC222,
        24'hDDD333, 24'hEEE444, 24'hFFF555, 24'h111222,
        24'h222333, 24'h333444, 24'h444555, 24'h555666,
        24'h666777, 24'h777888, 24'h888999, 24'h999AAA,
        24'hAAA111, 24'hBBB222, 24'hCCC333, 24'hDDD444,
        24'hEEE555, 24'hFFF666, 24'h2345AB, 24'hDC123,
        24'h4567CD, 24'h6789EF, 24'h89AB12, 24'hBCDEF3
    };

    //Hash function
    function automatic logic [HASH_WIDTH-1:0] hash (
        input logic  [KEY_WIDTH-1:0] key,
        input logic [HASH_WIDTH-1:0] matrix [KEY_WIDTH-1:0]
    );
        logic [HASH_WIDTH-1:0] accumulator = '0;
        for (int i = 0; i < KEY_WIDTH; i = i + 1)
            if (key[i])
                accumulator ^= matrix[i];
        return accumulator;
    endfunction

    //////////////////////////////////////////////////////////////////
    // B VALID Buffers
    //////////////////////////////////////////////////////////////////

    // Global Bvalid Buffer signals
    logic         m_bvalid_buff;
    logic         m_bresp_buff;
    logic         m_bready_buff;

    bvalid_buffer #(
        .DEPTH(CMD_FIFO_DEPTH)
    ) bvalid_in_buffer (
        .aclk               (aclk),
        .aresetn            (aresetn),

        .s_bvalid           (s_bvalid),
        .s_bresp            (s_bready),

        .m_bvalid           (m_bvalid_buff),
        .m_bresp            (m_bresp_buff),
        .m_bready           (m_bready_buff)
    );

    //////////////////////////////////////////////////////////////////
    // Metadata Buffers
    //////////////////////////////////////////////////////////////////

    // Global Metadata Buffer signals
    st_metadata metadata_tdata_buff;
    logic       metadata_tvalid_buff;
    logic       metadata_tready_buff;

    metadata_buffer #(
        .DEPTH(CMD_FIFO_DEPTH)
    ) metadata_in_buffer (
        .aclk               (aclk),
        .aresetn            (aresetn),

        .s_valid            (metadata_mem_in_valid),
        .s_data             (metadata_mem_in),

        .m_valid            (metadata_tvalid_buff),
        .m_data             (metadata_tdata_buff),
        .m_ready            (metadata_tready_buff)
    );

    // Write Metadata Buffer signals
    st_metadata s2mm_wr_meta_tdata;
    logic       s2mm_wr_meta_tvalid;

    st_metadata s2mm_rd_meta_tdata;
    logic       s2mm_rd_meta_tvalid;
    logic       s2mm_rd_meta_tready;

    metadata_buffer #(
        .DEPTH(CMD_FIFO_DEPTH/2)
    ) wr_metadata_buffer (
        .aclk               (aclk),
        .aresetn            (aresetn),

        .s_valid            (s2mm_wr_meta_tvalid),
        .s_data             (s2mm_wr_meta_tdata),

        .m_valid            (s2mm_rd_meta_tvalid),
        .m_data             (s2mm_rd_meta_tdata),
        .m_ready            (s2mm_rd_meta_tready)
    );

    // Read Metadata Buffer signals
    st_metadata mm2s_wr_meta_tdata;
    logic       mm2s_wr_meta_tvalid;

    st_metadata mm2s_rd_meta_tdata;
    logic       mm2s_rd_meta_tvalid;
    logic       mm2s_rd_meta_tready;

    metadata_buffer #(
        .DEPTH(CMD_FIFO_DEPTH/2)
    ) rd_metadata_buffer (
        .aclk               (aclk),
        .aresetn            (aresetn),

        .s_valid            (mm2s_wr_meta_tvalid),
        .s_data             (mm2s_wr_meta_tdata),

        .m_valid            (mm2s_rd_meta_tvalid),
        .m_data             (mm2s_rd_meta_tdata),
        .m_ready            (mm2s_rd_meta_tready)
    );

    //////////////////////////////////////////////////////////////////
    // AXI-Stream Buffer [Write]
    //////////////////////////////////////////////////////////////////

    // Stream Buffer signals
    logic [DATA_WIDTH-1:0]  s_tdata_buff;
    logic [TKEEP_WIDTH-1:0] s_tkeep_buff;
    logic                   s_tvalid_buff;
    logic                   s_tlast_buff;
    logic                   s_tready_buff;

    // stream_buffer #(
    //     .DATA_WIDTH (DATA_WIDTH),
    //     .KEEP_WIDTH (TKEEP_WIDTH),
    //     .DEPTH      (STREAM_FIFO_DEPTH)
    // ) s2mm_stream_buffer_inst (
    //     .aclk               (aclk),
    //     .aresetn            (aresetn),
    //     //Slave
    //     .s_axis_tdata       (s_axis_tdata),
    //     .s_axis_tkeep       (s_axis_tkeep),
    //     .s_axis_tvalid      (s_axis_tvalid),
    //     .s_axis_tlast       (s_axis_tlast),
    //     .s_axis_tready      (s_axis_tready),
    //     //Master
    //     .m_axis_tdata       (s_tdata_buff),
    //     .m_axis_tkeep       (s_tkeep_buff),
    //     .m_axis_tvalid      (s_tvalid_buff),
    //     .m_axis_tlast       (s_tlast_buff),
    //     .m_axis_tready      (s_tready_buff)
    // );

    logic s2mm_stream_buffer_full;
    logic s2mm_stream_buffer_empty;

    assign s_axis_tready = !s2mm_stream_buffer_full;
    assign s_tvalid_buff = !s2mm_stream_buffer_empty;

    xpm_fifo_sync #(
        .DOUT_RESET_VALUE    ("0"),
        .ECC_MODE            ("no_ecc"),
        .FIFO_MEMORY_TYPE    ("auto"),
        .FIFO_READ_LATENCY   (1),
        .FIFO_WRITE_DEPTH    (STREAM_FIFO_DEPTH),
        .PROG_FULL_THRESH    (STREAM_FIFO_DEPTH-5),
        .READ_DATA_WIDTH     (DATA_WIDTH + TKEEP_WIDTH + 1),
        .READ_MODE           ("fwft"),
        .WRITE_DATA_WIDTH    (DATA_WIDTH + TKEEP_WIDTH + 1)
    ) s2mm_stream_buffer_inst (
        .wr_en               (s_axis_tvalid),
        .din                 ({s_axis_tdata, s_axis_tkeep, s_axis_tlast}),
        .wr_ack              (),
        .rd_en               (s_tready_buff),
        .data_valid          (),
        .dout                ({s_tdata_buff, s_tkeep_buff, s_tlast_buff}),
        .wr_data_count       (),
        .rd_data_count       (),
        .empty               (s2mm_stream_buffer_empty),
        .full                (s2mm_stream_buffer_full),
        .almost_empty        (),
        .almost_full         (),
        .overflow            (),
        .underflow           (),
        .prog_empty          (),
        .prog_full           (),
        .sleep               (1'b0),
        .sbiterr             (),
        .dbiterr             (),
        .injectsbiterr       (1'b0),
        .injectdbiterr       (1'b0),
        .wr_clk              (aclk),
        .rst                 (~aresetn),
        .rd_rst_busy         (),
        .wr_rst_busy         ()
        );

    //////////////////////////////////////////////////////////////////
    // Synchronization [Write]
    //////////////////////////////////////////////////////////////////

    // Synchronizer signals
    logic command_sent;
    logic stream_sent;
    logic stream_enable;

    synchronizer #(
        .N(16)
    ) synchronizer_inst (
        .aclk               (aclk),
        .aresetn            (aresetn),

        .s2mm_cmd_start     (abp_complete0),

        .command_sent       (command_sent),
        .stream_sent        (stream_sent),
        .stream_enable      (stream_enable)
    );

    //////////////////////////////////////////////////////////////////
    // AXI-Stream Buffer [Write Ack]
    //////////////////////////////////////////////////////////////////

    // Ack Stream Buffer signals
    logic [DATA_WIDTH-1:0]  s_ack_tdata_buff;
    logic [TKEEP_WIDTH-1:0] s_ack_tkeep_buff;
    logic                   s_ack_tvalid_buff;
    logic                   s_ack_tlast_buff;
    logic                   s_ack_tready_buff;

    logic [DATA_WIDTH-1:0]  m_ack_tdata_buff;
    logic [TKEEP_WIDTH-1:0] m_ack_tkeep_buff;
    logic                   m_ack_tvalid_buff;
    logic                   m_ack_tlast_buff;
    logic                   m_ack_tready_buff;

    // stream_buffer #(
    //     .DATA_WIDTH (DATA_WIDTH),
    //     .KEEP_WIDTH (TKEEP_WIDTH),
    //     .DEPTH      (STREAM_FIFO_DEPTH/2)
    // ) writeack_stream_buffer_inst (
    //     .aclk               (aclk),
    //     .aresetn            (aresetn),
    //     //Slave
    //     .s_axis_tdata       (s_ack_tdata_buff),
    //     .s_axis_tkeep       (s_ack_tkeep_buff),
    //     .s_axis_tvalid      (s_ack_tvalid_buff),
    //     .s_axis_tlast       (s_ack_tlast_buff),
    //     .s_axis_tready      (s_ack_tready_buff),
    //     //Master
    //     .m_axis_tdata       (m_ack_tdata_buff),
    //     .m_axis_tkeep       (m_ack_tkeep_buff),
    //     .m_axis_tvalid      (m_ack_tvalid_buff),
    //     .m_axis_tlast       (m_ack_tlast_buff),
    //     .m_axis_tready      (m_ack_tready_buff)
    // );

    logic wa_stream_buffer_full;
    logic wa_stream_buffer_empty;

    assign s_ack_tready_buff = !wa_stream_buffer_full;
    assign m_ack_tvalid_buff = !wa_stream_buffer_empty;

    xpm_fifo_sync #(
        .DOUT_RESET_VALUE    ("0"),
        .ECC_MODE            ("no_ecc"),
        .FIFO_MEMORY_TYPE    ("auto"),
        .FIFO_READ_LATENCY   (1),
        .FIFO_WRITE_DEPTH    (STREAM_FIFO_DEPTH),
        .PROG_FULL_THRESH    (STREAM_FIFO_DEPTH-5),
        .READ_DATA_WIDTH     (DATA_WIDTH + TKEEP_WIDTH + 1),
        .READ_MODE           ("fwft"),
        .WRITE_DATA_WIDTH    (DATA_WIDTH + TKEEP_WIDTH + 1)
    ) wa_stream_buffer_inst (
        .wr_en               (s_ack_tvalid_buff),
        .din                 ({s_ack_tdata_buff, s_ack_tkeep_buff, s_ack_tlast_buff}),
        .wr_ack              (),
        .rd_en               (m_ack_tready_buff),
        .data_valid          (),
        .dout                ({m_ack_tdata_buff, m_ack_tkeep_buff, m_ack_tlast_buff}),
        .wr_data_count       (),
        .rd_data_count       (),
        .empty               (wa_stream_buffer_empty),
        .full                (wa_stream_buffer_full),
        .almost_empty        (),
        .almost_full         (),
        .overflow            (),
        .underflow           (),
        .prog_empty          (),
        .prog_full           (),
        .sleep               (1'b0),
        .sbiterr             (),
        .dbiterr             (),
        .injectsbiterr       (1'b0),
        .injectdbiterr       (1'b0),
        .wr_clk              (aclk),
        .rst                 (~aresetn),
        .rd_rst_busy         (),
        .wr_rst_busy         ()
    );

    //////////////////////////////////////////////////////////////////
    // AXI-Stream Buffer [Read]
    //////////////////////////////////////////////////////////////////

    // Stream Buffer signals
    logic [DATA_WIDTH-1:0]  m_tdata_buff;
    logic [TKEEP_WIDTH-1:0] m_tkeep_buff;
    logic                   m_tvalid_buff;
    logic                   m_tlast_buff;
    logic                   m_tready_buff;

    // stream_buffer #(
    //     .DATA_WIDTH (DATA_WIDTH),
    //     .KEEP_WIDTH (TKEEP_WIDTH),
    //     .DEPTH      (STREAM_FIFO_DEPTH*2)
    // ) mm2s_stream_buffer_inst (
    //     .aclk             (aclk),
    //     .aresetn          (aresetn),
    //     //Slave
    //     .s_axis_tdata     (s_dm_axis_tdata),
    //     .s_axis_tkeep     (s_dm_axis_tkeep),
    //     .s_axis_tvalid    (s_dm_axis_tvalid),
    //     .s_axis_tlast     (s_dm_axis_tlast),
    //     .s_axis_tready    (s_dm_axis_tready),
    //     //Master
    //     .m_axis_tdata     (m_tdata_buff),
    //     .m_axis_tkeep     (m_tkeep_buff),
    //     .m_axis_tvalid    (m_tvalid_buff),
    //     .m_axis_tlast     (m_tlast_buff),
    //     .m_axis_tready    (m_tready_buff)
    // );

    logic mm2s_stream_buffer_full;
    logic mm2s_stream_buffer_empty;

    assign s_dm_axis_tready = !mm2s_stream_buffer_full;
    assign m_tvalid_buff    = !mm2s_stream_buffer_empty;

    xpm_fifo_sync #(
        .DOUT_RESET_VALUE    ("0"),
        .ECC_MODE            ("no_ecc"),
        .FIFO_MEMORY_TYPE    ("auto"),
        .FIFO_READ_LATENCY   (1),
        .FIFO_WRITE_DEPTH    (STREAM_FIFO_DEPTH),
        .PROG_FULL_THRESH    (STREAM_FIFO_DEPTH-5),
        .READ_DATA_WIDTH     (DATA_WIDTH + TKEEP_WIDTH + 1),
        .READ_MODE           ("fwft"),
        .WRITE_DATA_WIDTH    (DATA_WIDTH + TKEEP_WIDTH + 1)
    ) mm2s_stream_buffer_inst (
        .wr_en               (s_dm_axis_tvalid),
        .din                 ({s_dm_axis_tdata, s_dm_axis_tkeep, s_dm_axis_tlast}),
        .wr_ack              (),
        .rd_en               (m_tready_buff),
        .data_valid          (),
        .dout                ({m_tdata_buff, m_tkeep_buff, m_tlast_buff}),
        .wr_data_count       (),
        .rd_data_count       (),
        .empty               (mm2s_stream_buffer_empty),
        .full                (mm2s_stream_buffer_full),
        .almost_empty        (),
        .almost_full         (),
        .overflow            (),
        .underflow           (),
        .prog_empty          (),
        .prog_full           (),
        .sleep               (1'b0),
        .sbiterr             (),
        .dbiterr             (),
        .injectsbiterr       (1'b0),
        .injectdbiterr       (1'b0),
        .wr_clk              (aclk),
        .rst                 (~aresetn),
        .rd_rst_busy         (),
        .wr_rst_busy         ()
    );


    //////////////////////////////////////////////////////////////////
    // Controller state machine S2MM & MM2S
    //////////////////////////////////////////////////////////////////

    //******************************************
    //        Memory Mapped Command FSM
    //******************************************

    typedef enum logic [1:0] {
        READ,
        WRITE,
        READ_RESULT,
        WRITE_ACK
    } opcode_t;

    // Command FSM states
    typedef enum {C_IDLE,C_START,C_VALID,C_READY} state_c;
    
    state_c cmd_reg, cmd_next;
    
    logic [HASH_WIDTH-1:0] cmd_address;

    always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin // Boot up the FSM.
        cmd_reg         <= C_IDLE;
    end else begin
        cmd_reg         <= cmd_next;
    end
    end

    // Memory Mapped Command FSM
    always_comb begin
        cmd_next = cmd_reg;

        metadata_tready_buff = 1'b0;
        
        command_sent = 1'b0;
        cmd_address = '0;

        // MM2S
        mm2s_cmd_tdata = '0;
        mm2s_cmd_tvalid = 1'b0;

        mm2s_wr_meta_tdata = '0;
        mm2s_wr_meta_tvalid = 1'b0;

        // S2MM
        s2mm_cmd_tdata = '0;
        s2mm_cmd_tvalid = 1'b0;

        s2mm_wr_meta_tdata = '0;
        s2mm_wr_meta_tvalid = 1'b0;

        // Ack Stream signals
        s_ack_tdata_buff = '0;
        s_ack_tkeep_buff = '0;
        s_ack_tvalid_buff = 1'b0;
        s_ack_tlast_buff = 1'b0;

        case(cmd_reg)

        //CMD IDLE state
        C_IDLE: begin 
            if(abp_complete0)
                cmd_next = C_START;
            else
                cmd_next = C_IDLE;
        end

        //CMD START state
        C_START: begin 
            cmd_next = C_VALID;
        end

        //CMD VALID state
        C_VALID: begin
            metadata_tready_buff = 1'b1;
            if(metadata_tvalid_buff) begin //**SLAVE-SIDE.
                
                cmd_address = hash(metadata_tdata_buff.key, HASH_MATRIX);
                case (metadata_tdata_buff.opcode)
                    8'h00: begin
                            mm2s_wr_meta_tvalid = 1'b1;
                            mm2s_wr_meta_tdata = metadata_tdata_buff;
                            mm2s_cmd_tvalid = 1'b1;
                            mm2s_cmd_tdata = {8'h00, 6'b0,cmd_address,10'b0 ,1'b0,1'b1,6'b000000,1'b1,BTT};                    
                    end 
                    8'h01: begin
                            s2mm_wr_meta_tvalid = 1'b1;
                            s2mm_wr_meta_tdata = metadata_tdata_buff; 
                            s2mm_cmd_tvalid = 1'b1;    
                            s2mm_cmd_tdata = {8'h00, 6'b0,cmd_address,10'b0 ,1'b0,1'b1,6'b000000,1'b1,BTT};  
                            command_sent = 1'b1;
                            s_ack_tdata_buff = '0;
                            s_ack_tkeep_buff = '0;
                            s_ack_tvalid_buff = 1'b1;
                            s_ack_tlast_buff = 1'b1;
                    end
                    default:;
                endcase    
                cmd_next = C_READY;
            end else
                cmd_next = C_VALID;
        end
        

        //CMD READY state
        C_READY: begin
            
            case (metadata_tdata_buff.opcode)
                8'h00: begin
                    if(mm2s_cmd_tready) begin  //**MASTER-SIDE.
                        mm2s_wr_meta_tvalid = 1'b1;
                        mm2s_wr_meta_tdata = metadata_tdata_buff;
                        mm2s_cmd_tvalid = 1'b1;
                        mm2s_cmd_tdata = {8'h00, 6'b0,cmd_address,10'b0 ,1'b0,1'b1,6'b000000,1'b1,BTT};
                        cmd_next = C_VALID;                    
                    end
                end 
                8'h01: begin
                    if(s2mm_cmd_tready && s_ack_tready_buff)begin  //**MASTER-SIDE. 
                        s2mm_wr_meta_tvalid = 1'b1;
                        s2mm_wr_meta_tdata = metadata_tdata_buff; 
                        s2mm_cmd_tvalid = 1'b1;    
                        s2mm_cmd_tdata = {8'h00, 6'b0,cmd_address,10'b0 ,1'b0,1'b1,6'b000000,1'b1,BTT};  
                        command_sent = 1'b1;
                        s_ack_tdata_buff = '0;
                        s_ack_tkeep_buff = '0;
                        s_ack_tvalid_buff = 1'b1;
                        s_ack_tlast_buff = 1'b1;
                        cmd_next = C_VALID;
                    end
                end
                default:;
            endcase


        end
        default:;
        endcase
    end

    //************************************************
    //             AXI-Stream FSM [Write]
    //************************************************

    // S2MM FSM states
    typedef enum {S2MM_IDLE,S2MM_START,S2MM_VALID,S2MM_READY} state_t;
    
    state_t s2mm_reg, s2mm_next; 

    always_ff@(posedge aclk, negedge aresetn) begin
        if(!aresetn) // Boot up the FSM.
            s2mm_reg <= S2MM_IDLE;
        else 
            s2mm_reg <= s2mm_next; 
    end

    // Axi Stream FSM [Write]
    always_comb begin
        
        s2mm_next = s2mm_reg;

        s_tready_buff = 1'b0;

        m_dm_axis_tvalid = 1'b0;
        m_dm_axis_tdata = '0;
        m_dm_axis_tkeep = '0;
        m_dm_axis_tlast = 1'b0;

        stream_sent = 1'b0;
        
        case(s2mm_reg)

        //AXI IDLE state
        S2MM_IDLE: begin 
            if(abp_complete0)
                s2mm_next = S2MM_START;
            else
                s2mm_next = S2MM_IDLE;
        end

        //AXI START state
        S2MM_START: begin 
            if(stream_enable) begin
                s2mm_next = S2MM_VALID;
            end
            else
                s2mm_next = S2MM_START;
        end

        //AXI VALID state
        S2MM_VALID: begin
            if(s_tvalid_buff && stream_enable) begin//**SLAVE-SIDE.
                s_tready_buff = 1'b1;
                m_dm_axis_tvalid = 1'b1;
                m_dm_axis_tdata = s_tlast_buff ? {4'hF, s_tdata_buff[507:0]} : s_tdata_buff;
                m_dm_axis_tkeep = s_tlast_buff ? {4'hF, s_tkeep_buff[59:0]}   : s_tkeep_buff;
                m_dm_axis_tlast = s_tlast_buff;
                s2mm_next = S2MM_READY;
            end else
                s2mm_next = S2MM_VALID;
        end

        //AXI READY state
        S2MM_READY: begin
            if(s_tvalid_buff && m_dm_axis_tready) begin //**MASTER-SIDE.
                s_tready_buff = 1'b1;
                m_dm_axis_tvalid = 1'b1;
                m_dm_axis_tdata = s_tlast_buff ? {4'hF, s_tdata_buff[507:0]} : s_tdata_buff;
                m_dm_axis_tkeep = s_tlast_buff ? {4'hF, s_tkeep_buff[59:0]}   : s_tkeep_buff;
                m_dm_axis_tlast = s_tlast_buff;
                if(s_tlast_buff) begin
                    s2mm_next = S2MM_VALID;
                    stream_sent = 1'b1;
                end else
                    s2mm_next = S2MM_READY;
            end
            else
                s2mm_next = S2MM_READY;
        end
        default:;
        endcase
    end

    //************************************************
    //         Write-ack/Read Arbitrer FSM
    //************************************************
 
    // Arbitrer FSM states
    typedef enum logic [1:0] {RET_IDLE, RET_TYPE, RET_ACK, RET_READ} sel_t;
    sel_t sel, sel_n;

    logic sent_first_read;

    always_comb begin
        sel_n = sel;

        // m_axi
        m_axis_tvalid = 1'b0;
        m_axis_tdata  = '0;
        m_axis_tkeep  = '0;
        m_axis_tlast  = 1'b0;

        //MM2S Buffer tready
        m_tready_buff = 1'b0;
        //Write Ack Buffer tready
        m_ack_tready_buff = 1'b0;
        //Bvalid Buffer tready
        m_bready_buff = 1'b0;

        metadata_mem_out = '0;
        metadata_mem_out_valid = 1'b0;

        //S2MM metadata buffer
        s2mm_rd_meta_tready = 0;
        //MM2S metadata buffer
        mm2s_rd_meta_tready= 0;

        case (sel)
    
        //Arbitrer IDLE state
        RET_IDLE: begin 
            if(abp_complete0)
                sel_n = RET_TYPE;
            else
                sel_n= RET_IDLE;
        end
        

        //Arbitrer TYPE state
        RET_TYPE: begin
        if (m_ack_tvalid_buff && s2mm_rd_meta_tvalid && m_bvalid_buff) begin
            m_bready_buff = 1'b1;
            m_axis_tvalid = 1'b1;
            m_ack_tready_buff = 1'b1;
            m_axis_tdata = m_ack_tdata_buff;
            m_axis_tkeep = m_ack_tkeep_buff;
            m_axis_tlast = m_ack_tlast_buff;
            s2mm_rd_meta_tready = 1'b1;
            metadata_mem_out_valid = 1'b1;
            metadata_mem_out = s2mm_rd_meta_tdata;
            sel_n = RET_ACK;
        end
        else if (m_tvalid_buff && mm2s_rd_meta_tvalid) begin

            m_axis_tvalid = 1'b1;
            m_tready_buff = 1'b1;
            m_axis_tdata  = m_tlast_buff ? {4'h0, m_tdata_buff[507:0]} : m_tdata_buff;
            m_axis_tkeep  = m_tlast_buff ? {4'h0, m_tkeep_buff[59:0]}  : m_tkeep_buff;
            m_axis_tlast  = m_tlast_buff;
            if (!sent_first_read) begin
                mm2s_rd_meta_tready = 1'b1;
                metadata_mem_out_valid = 1'b1;
                metadata_mem_out = mm2s_rd_meta_tdata;
            end

            sel_n = RET_READ;

        end
        else
            sel_n = RET_TYPE;
        end
        //Arbitrer ACK state
        RET_ACK: begin
            m_bready_buff = 1'b1;
            m_axis_tvalid = 1'b1;
            m_ack_tready_buff = 1'b1;
            m_axis_tdata = m_ack_tdata_buff;
            m_axis_tkeep = m_ack_tkeep_buff;
            m_axis_tlast = m_ack_tlast_buff;
            s2mm_rd_meta_tready = 1'b1;
            metadata_mem_out_valid = 1'b1;
            metadata_mem_out = s2mm_rd_meta_tdata;

            if (m_axis_tready) begin
                sel_n = RET_TYPE;
            end
        end

        //Arbitrer READ state
        RET_READ: begin

            m_axis_tvalid = 1'b1;
            m_tready_buff = 1'b1;
            m_axis_tdata  = m_tlast_buff ? {4'h0, m_tdata_buff[507:0]} : m_tdata_buff;
            m_axis_tkeep  = m_tlast_buff ? {4'h0, m_tkeep_buff[59:0]}  : m_tkeep_buff;
            m_axis_tlast  = m_tlast_buff;
            if (!sent_first_read) begin
                mm2s_rd_meta_tready = 1'b1;
                metadata_mem_out_valid = 1'b1;
                metadata_mem_out = mm2s_rd_meta_tdata;
            end

            if (m_axis_tready) begin            
                if(m_tlast_buff) begin
                    sel_n = RET_TYPE;
                end else 
                    sel_n = RET_READ;
            end else begin
                sel_n = RET_READ;
            end
        end
        default:;
        endcase
    end

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
        sel             <= RET_IDLE;
        sent_first_read <= 0;
        end 
        else begin
        sel <= sel_n;

            if (sel == RET_READ) begin
                if (!sent_first_read && m_tvalid_buff && m_axis_tready)
                    sent_first_read <= 1;
                if (m_tvalid_buff && m_axis_tready && m_tlast_buff)
                    sent_first_read <= 0;
                end 
            else begin
                sent_first_read <= 0;
            end
        end
    end

    

    //******************************************
    //         AXI-Stream Status Hardware 
    //******************************************
    /*Clearing the status signals (needed for datamover stable functionality)*/

    // MM2S
    always_ff@(posedge aclk, negedge aresetn) begin
        if(!aresetn || !abp_complete0) // Boot up the STS Hardware.
            s_axis_mm2s_sts_tready <= 1'b0;
        else if (s_axis_mm2s_sts_tvalid)
            s_axis_mm2s_sts_tready <= 1'b1; 
        else
            s_axis_mm2s_sts_tready <= 1'b0;
    end


    // S2MM
    always_ff@(posedge aclk, negedge aresetn) begin
        if(!aresetn || !abp_complete0) // Boot up the STS Hardware.
            s_axis_s2mm_sts_tready <= 1'b0;
        else if (s_axis_s2mm_sts_tvalid)
            s_axis_s2mm_sts_tready <= 1'b1; 
        else
            s_axis_s2mm_sts_tready <= 1'b0;
    end

endmodule