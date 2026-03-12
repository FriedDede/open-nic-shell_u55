`timescale 1ns/1ps

import metadata_pkg::*;

module replication_engine #(
  parameter int          MAX_NODES  = 32,
  parameter int          DATA_WIDTH = 512,
  parameter int          KEEP_WIDTH = DATA_WIDTH / 8,
  parameter int          FIFO_DEPTH = 16,
  parameter int          THREAD     = 0
) (
  input  logic axis_clk,
  input  logic axis_rstn,

  // Replication packet input
  input  logic                  s_axis_tvalid,
  input  logic [DATA_WIDTH-1:0] s_axis_tdata,
  input  logic [KEEP_WIDTH-1:0] s_axis_tkeep,
  input  logic                  s_axis_tlast,
  output logic                  s_axis_tready,

  input  st_metadata            metadata_in,
  input  logic                  metadata_in_valid,

  // Replication packet output
  output logic                  m_axis_tvalid,
  output logic [DATA_WIDTH-1:0] m_axis_tdata,
  output logic [KEEP_WIDTH-1:0] m_axis_tkeep,
  output logic                  m_axis_tlast,
  input  logic                  m_axis_tready,

  output st_metadata            metadata_out,
  output logic                  metadata_out_valid,

  // Memory controller read
  input  logic                  s_axis_mem_tvalid,
  input  logic [DATA_WIDTH-1:0] s_axis_mem_tdata,
  input  logic [KEEP_WIDTH-1:0] s_axis_mem_tkeep,
  input  logic                  s_axis_mem_tlast,
  output logic                  s_axis_mem_tready,

  input  st_metadata            metadata_mem_in,
  input  logic                  metadata_mem_in_valid,

  // Memory controller write
  output logic                  m_axis_mem_tvalid,
  output logic [DATA_WIDTH-1:0] m_axis_mem_tdata,
  output logic [KEEP_WIDTH-1:0] m_axis_mem_tkeep,
  output logic                  m_axis_mem_tlast,
  input  logic                  m_axis_mem_tready,

  output st_metadata            metadata_mem_out,
  output logic                  metadata_mem_out_valid,
  input  logic                  metadata_mem_out_ready,

  input  logic                  is_leader
);

localparam FIFO_PTR_WIDTH = $clog2(FIFO_DEPTH);
localparam NODE_PTR_WIDTH = $clog2(MAX_NODES);

typedef enum logic [1:0] {
  ACCEPT_NET,
  WRITE_MEM,
  WRITE_REP
} net_state_t;

typedef enum logic {
  ACCEPT_MEM,
  READ_MEM
} mem_state_t;

net_state_t net_state, net_state_next;
mem_state_t mem_state, mem_state_next;

// Signals for metadata FIFOs
logic       net_meta_rd_en;
logic       net_meta_empty;
st_metadata net_meta_out;

logic       mem_meta_rd_en;
logic       mem_meta_empty;
st_metadata mem_meta_out;

// Signals for packet FIFOs
logic                  net_fifo_rd_en;
logic                  net_fifo_empty;
logic                  net_fifo_prog_full;
logic [DATA_WIDTH-1:0] net_fifo_out_tdata;
logic [KEEP_WIDTH-1:0] net_fifo_out_tkeep;
logic                  net_fifo_out_tlast;

logic                  mem_fifo_rd_en;
logic                  mem_fifo_empty;
logic                  mem_fifo_prog_full;
logic [DATA_WIDTH-1:0] mem_fifo_out_tdata;
logic [KEEP_WIDTH-1:0] mem_fifo_out_tkeep;
logic                  mem_fifo_out_tlast;

assign s_axis_tready     = !net_fifo_prog_full;
assign s_axis_mem_tready = !mem_fifo_prog_full;

// Signals for replicating writes to backup nodes
typedef struct packed {
  logic [DATA_WIDTH-1:0] tdata;
  logic [KEEP_WIDTH-1:0] tkeep;
  logic                  tlast;
} st_beat;

(* ram_style="block" *) st_beat replica_mem [FIFO_DEPTH*8];
st_beat replica_mem_read, replica_mem_write;
logic [FIFO_PTR_WIDTH-1:0] rep_write_ptr, rep_write_ptr_next;
logic [FIFO_PTR_WIDTH-1:0] rep_read_cnt, rep_read_cnt_next, rep_read_ptr;
logic [NODE_PTR_WIDTH-1:0] nodes_count, nodes_count_next;
logic                      rep_wr_en;
logic                      metadata_sent, metadata_sent_next;
logic                [1:0] memory_delay, memory_delay_next;

// Signals for keeping track of replicas' write acks
typedef struct packed {
  st_metadata                meta;
  logic [FIFO_PTR_WIDTH-1:0] index;
  logic               [31:0] count;
  logic                      is_running;
} st_ack;

(* ram_style="block" *) st_ack ack_table [FIFO_DEPTH];
st_ack ack_table_read, ack_table_read_tmp, ack_table_write;
logic [FIFO_PTR_WIDTH-1:0] ack_read_ptr, ack_write_ptr;
logic [FIFO_PTR_WIDTH-1:0] ack_id, ack_id_next;
logic                      ack_wr_en;

// Infers BRAM for replica_mem and ack_table
always_ff @(posedge axis_clk) begin
  if (rep_wr_en)
    replica_mem[rep_write_ptr] <= replica_mem_write;
  replica_mem_read <= replica_mem[rep_read_ptr];

  if (ack_wr_en)
    ack_table[ack_write_ptr] <= ack_table_write;
  ack_table_read_tmp <= ack_table[ack_read_ptr];
  ack_table_read <= ack_table_read_tmp;
end

// Keeps track of which side is using the output interface: 10 incoming packets, 01 memory controller
logic [1:0] out_busy, out_busy_next;

// Adds dirty tag to write in memory
logic tag_written, tag_written_next;

// Signals for keeping track of nodes in the network
logic [NODE_PTR_WIDTH-1:0] num_nodes;
logic [NODE_PTR_WIDTH-1:0] table_index, table_index_next;
logic               [31:0] table_ip;
logic               [47:0] table_mac;

// // Checks whether the node is the leader for given key
// function logic is_leader (input logic [KEY_WIDTH-1:0] key);
//   logic [NODE_PTR_WIDTH-1:0] leader_id, node_id;
//   leader_id = key[NODE_PTR_WIDTH-1:0];
//   node_id   = NODE_IPS[0][NODE_PTR_WIDTH-1:0];
//   if (leader_id == node_id)
//     return 1'b1;
//   return 1'b0;
// endfunction

// --------------------------------------------------------------------------------------------------------------
// OUTPUT REGISTERS
// --------------------------------------------------------------------------------------------------------------

logic                  m_axis_tvalid_reg;
logic [DATA_WIDTH-1:0] m_axis_tdata_reg;
logic [KEEP_WIDTH-1:0] m_axis_tkeep_reg;
logic                  m_axis_tlast_reg;
logic                  m_axis_tready_reg;

st_metadata            metadata_out_reg;
logic                  metadata_out_valid_reg;

always_ff @(posedge axis_clk) begin
    metadata_out <= metadata_out_reg;
    metadata_out_valid <= metadata_out_valid_reg;
end


axi_stream_register_slice #(
  .TDATA_W  (DATA_WIDTH),
  .TID_W    (0),
  .TDEST_W  (0),
  .TUSER_W  (0),
  .MODE     ("full")
) axi_s_slice_out (
  .s_axis_tvalid  (m_axis_tvalid_reg),
  .s_axis_tdata   (m_axis_tdata_reg),
  .s_axis_tkeep   (m_axis_tkeep_reg),
  .s_axis_tlast   (m_axis_tlast_reg),
  .s_axis_tid     (),
  .s_axis_tdest   (),
  .s_axis_tuser   (),
  .s_axis_tready  (m_axis_tready_reg),

  .m_axis_tvalid  (m_axis_tvalid),
  .m_axis_tdata   (m_axis_tdata),
  .m_axis_tkeep   (m_axis_tkeep),
  .m_axis_tlast   (m_axis_tlast),
  .m_axis_tid     (),
  .m_axis_tdest   (),
  .m_axis_tuser   (),
  .m_axis_tready  (m_axis_tready),

  .aclk     (axis_clk),
  .aresetn  (axis_rstn)
);

logic                  m_axis_mem_tvalid_reg;
logic [DATA_WIDTH-1:0] m_axis_mem_tdata_reg;
logic [KEEP_WIDTH-1:0] m_axis_mem_tkeep_reg;
logic                  m_axis_mem_tlast_reg;
logic                  m_axis_mem_tready_reg;

st_metadata            metadata_mem_out_reg;
logic                  metadata_mem_out_valid_reg;

always_ff @(posedge axis_clk) begin
    metadata_mem_out <= metadata_mem_out_reg;
    metadata_mem_out_valid <= metadata_mem_out_valid_reg;
end

axi_stream_register_slice #(
  .TDATA_W  (DATA_WIDTH),
  .TID_W    (0),
  .TDEST_W  (0),
  .TUSER_W  (0),
  .MODE     ("full")
) axi_s_slice_mem (

  .s_axis_tvalid  (m_axis_mem_tvalid_reg),
  .s_axis_tdata   (m_axis_mem_tdata_reg),
  .s_axis_tkeep   (m_axis_mem_tkeep_reg),
  .s_axis_tlast   (m_axis_mem_tlast_reg),
  .s_axis_tid     (),
  .s_axis_tdest   (),
  .s_axis_tuser   (),
  .s_axis_tready  (m_axis_mem_tready_reg),

  .m_axis_tvalid  (m_axis_mem_tvalid),
  .m_axis_tdata   (m_axis_mem_tdata ),
  .m_axis_tkeep   (m_axis_mem_tkeep ),
  .m_axis_tlast   (m_axis_mem_tlast ),
  .m_axis_tid     (),
  .m_axis_tdest   (),
  .m_axis_tuser   (),
  .m_axis_tready  (m_axis_mem_tready),

  .aclk     (axis_clk),
  .aresetn  (axis_rstn)
);

// --------------------------------------------------------------------------------------------------------------
// REP ENGINE
// --------------------------------------------------------------------------------------------------------------

always_ff @(posedge axis_clk) begin
  if (!axis_rstn) begin
    net_state      <= ACCEPT_NET;
    mem_state      <= ACCEPT_MEM;
    ack_id         <= 1;
    rep_read_cnt   <= '0;
    rep_write_ptr  <= '0;
    nodes_count    <= '0;
    metadata_sent  <= '0;
    out_busy       <= 1'b0;
    memory_delay   <= '0;
    tag_written    <= 1'b0;
    table_index    <= 1;
  end 
  else begin
    net_state      <= net_state_next;
    mem_state      <= mem_state_next;
    ack_id         <= ack_id_next;
    rep_read_cnt   <= rep_read_cnt_next;
    rep_write_ptr  <= rep_write_ptr_next;
    nodes_count    <= nodes_count_next;
    metadata_sent  <= metadata_sent_next;
    out_busy       <= out_busy_next;
    memory_delay   <= memory_delay_next;
    tag_written    <= tag_written_next;
    table_index    <= table_index_next;
  end
end

always_comb begin
  net_state_next         = net_state;
  mem_state_next         = mem_state;
  net_meta_rd_en         = 1'b0;
  net_fifo_rd_en         = 1'b0;
  mem_meta_rd_en         = 1'b0;
  mem_fifo_rd_en         = 1'b0;

  ack_id_next            = ack_id;
  out_busy_next          = out_busy;
  tag_written_next       = tag_written;
  nodes_count_next       = nodes_count;
  metadata_sent_next     = metadata_sent;
  memory_delay_next      = memory_delay;
  rep_read_cnt_next      = rep_read_cnt;
  rep_write_ptr_next     = rep_write_ptr;
  table_index_next       = table_index;
  replica_mem_write      = 0;
  ack_table_write        = 0;
  rep_read_ptr           = 0;
  ack_read_ptr           = 0;
  ack_write_ptr          = 0;
  rep_wr_en              = 1'b0;
  ack_wr_en              = 1'b0;

  m_axis_tvalid_reg          = 0;
  m_axis_tdata_reg           = 0;
  m_axis_tkeep_reg           = 0;
  m_axis_tlast_reg           = 0;

  metadata_out_valid_reg     = 0;
  metadata_out_reg           = 0;

  m_axis_mem_tvalid_reg      = 0;
  m_axis_mem_tdata_reg       = 0;
  m_axis_mem_tkeep_reg       = 0;
  m_axis_mem_tlast_reg       = 0;

  metadata_mem_out_valid_reg = 0;
  metadata_mem_out_reg       = 0;

  // Process incoming packets
  case (net_state)
    ACCEPT_NET: begin
      if (!net_meta_empty) begin
        case (net_meta_out.opcode)
          READ: begin
            // for read just pass command to the engine
            metadata_mem_out_valid_reg = 1'b1;
            metadata_mem_out_reg       = net_meta_out;

            if (metadata_mem_out_valid_reg)
              net_meta_rd_en = 1'b1;
          end
          WRITE: begin
            
            m_axis_mem_tvalid_reg = !net_fifo_empty;
            m_axis_mem_tdata_reg  = net_fifo_out_tdata;
            m_axis_mem_tkeep_reg  = net_fifo_out_tkeep;
            m_axis_mem_tlast_reg  = net_fifo_out_tlast;
            net_fifo_rd_en = m_axis_mem_tready_reg;
            m_axis_mem_tdata_reg[31:0] = VALID_TAG;
            
            if (m_axis_mem_tvalid_reg) begin
                tag_written_next = 1'b1;
            end

            metadata_mem_out_valid_reg = 1'b1;
            metadata_mem_out_reg       = net_meta_out;

            if (metadata_mem_out_valid_reg) begin
              
              if (is_leader) begin
                net_state_next      = WRITE_REP;
                rep_read_cnt_next   = 0;
                rep_write_ptr_next  = 0;
                nodes_count_next    = 0;

                // Save the first beat for replicas
                if (!net_fifo_empty) begin
                  rep_wr_en = 1'b1;
                  replica_mem_write.tdata = net_fifo_out_tdata;
                  replica_mem_write.tkeep = net_fifo_out_tkeep;
                  replica_mem_write.tlast = net_fifo_out_tlast;
                  replica_mem_write.tdata[31:0] = VALID_TAG;
                  rep_write_ptr_next = 1;
                  tag_written_next = 1'b1;
                end

                // Start keeping track of acks for this write
                ack_table_write.meta       = net_meta_out;
                ack_table_write.index      = ack_id;
                ack_table_write.count      = 0;
                ack_table_write.is_running = 1'b1;
                ack_write_ptr = ack_id;
                ack_wr_en     = 1'b1;
                ack_id_next   = ack_id + 1;
              end
              else begin
                net_state_next = WRITE_MEM;
                net_meta_rd_en = 1'b1;
              end
            end
          end
          // FIXME: maybe net_fifo_rd_en not needed? Parser should drop packets
          WRITE_ACK: begin
            ack_read_ptr  = net_meta_out.index;
            ack_write_ptr = net_meta_out.index;
            if (memory_delay != 2)
              memory_delay_next = memory_delay + 1;
            else begin
              if (is_leader && ack_table_read.is_running) begin
                if (!out_busy[1] && ack_table_read.count + 1 == num_nodes - 1) begin
                  out_busy_next[0] = 1'b1;

                  metadata_out_valid_reg  = 1'b1;
                  metadata_out_reg        = ack_table_read.meta;
                  metadata_out_reg.opcode = WRITE_ACK_LEADER;

                  if (m_axis_tready_reg) begin
                    ack_table_write.is_running = 1'b0;
                    ack_wr_en        = 1'b1;
                    out_busy_next[0] = 1'b0;
                    net_meta_rd_en   = 1'b1;
                    net_fifo_rd_en   = 1'b1;
                    memory_delay_next = '0; 
                  end
                end
                else begin
                  ack_table_write.count = ack_table_read.count + 1;
                  ack_wr_en      = 1'b1;
                  net_meta_rd_en = 1'b1;
                  net_fifo_rd_en = 1'b1; 
                end
              end
              else begin
                net_meta_rd_en = 1'b1;
                net_fifo_rd_en = 1'b1; 
              end
            end
          end
          default: begin
            net_meta_rd_en = 1'b1;
          end
        endcase
      end
    end
    WRITE_MEM: begin
      m_axis_mem_tvalid_reg = !net_fifo_empty;
      m_axis_mem_tdata_reg  = net_fifo_out_tdata;
      m_axis_mem_tkeep_reg  = net_fifo_out_tkeep;
      m_axis_mem_tlast_reg  = net_fifo_out_tlast;
      net_fifo_rd_en = m_axis_mem_tready_reg;
      if (!tag_written_next) begin
        m_axis_mem_tdata_reg[31:0] = VALID_TAG;
        if (m_axis_mem_tvalid_reg && m_axis_mem_tready_reg) begin
          tag_written_next = 1'b1;
        end
      end
      if (m_axis_mem_tvalid_reg && m_axis_mem_tready_reg && m_axis_mem_tlast_reg) begin
        tag_written_next = 1'b0;
        net_state_next   = ACCEPT_NET;
      end
    end
    WRITE_REP: begin
      //FIXME: write pointer should always be at least one higher than read pointer
      rep_read_ptr = rep_read_cnt;

      // While writing to the first node, also move the write to the memory controller
      if (nodes_count == 0) begin
        
        m_axis_mem_tvalid_reg = !net_fifo_empty;
        m_axis_mem_tdata_reg  = net_fifo_out_tdata;
        m_axis_mem_tkeep_reg  = net_fifo_out_tkeep;
        m_axis_mem_tlast_reg  = net_fifo_out_tlast;
        net_fifo_rd_en = m_axis_mem_tready_reg;

        if (m_axis_mem_tvalid_reg && m_axis_mem_tready_reg) begin
          replica_mem_write.tdata = net_fifo_out_tdata;
          replica_mem_write.tkeep = net_fifo_out_tkeep;
          replica_mem_write.tlast = net_fifo_out_tlast;
          rep_write_ptr_next = rep_write_ptr + 1;
          rep_wr_en = 1'b1;
        end

        if (!tag_written_next) begin
          m_axis_mem_tdata_reg[31:0]     = VALID_TAG;
          replica_mem_write.tdata[31:0]  = VALID_TAG;
          if (m_axis_mem_tvalid_reg && m_axis_mem_tready_reg) begin
            tag_written_next = 1'b1;
          end
        end

      end

      // Wait for the replica memory to output first value
      if (memory_delay != 2)
        memory_delay_next = memory_delay + 1;
      else begin
        if (!out_busy[1]) begin
          out_busy_next[0] = 1'b1;
          m_axis_tvalid_reg = 1'b1;
          m_axis_tdata_reg  = replica_mem_read.tdata;
          m_axis_tkeep_reg  = replica_mem_read.tkeep;
          m_axis_tlast_reg  = replica_mem_read.tlast;

          if (rep_read_cnt == 0) begin
            metadata_out_valid_reg = 1'b1;
            metadata_out_reg       = net_meta_out;
            metadata_out_reg.index = ack_id - 1;
            metadata_out_reg.ip    = table_ip;
            metadata_out_reg.mac   = table_mac;
          end

          if (m_axis_tready_reg) begin
            rep_read_ptr      = rep_read_cnt + 1;
            rep_read_cnt_next = rep_read_cnt + 1;
            if (m_axis_tlast_reg) begin
              rep_read_cnt_next  = 0;
              rep_read_ptr       = 0;
              metadata_sent_next = 1'b0;
              nodes_count_next   = nodes_count + 1;
              // Wait one cycle for IP BRAM answer
              table_index_next   = table_index + 1;
              memory_delay_next  = 1;
              if (nodes_count + 1 == num_nodes - 1) begin

                tag_written_next = 1'b0;
                net_state_next    = ACCEPT_NET;
                net_meta_rd_en    = 1'b1;
                out_busy_next[0]  = 1'b0;
                memory_delay_next = 0;
                table_index_next  = 1;
              end
            end
          end
        end
      end
    end
    default:;
  endcase

  // Process incoming memory controller data
  if (!out_busy[0] && !out_busy_next[0]) begin
    case (mem_state)
      ACCEPT_MEM: begin
        if (!mem_meta_empty) begin
          out_busy_next[1] = 1'b1;
          case (mem_meta_out.opcode)
            READ: begin
              m_axis_tvalid_reg = !mem_fifo_empty;
              m_axis_tdata_reg  = mem_fifo_out_tdata;
              m_axis_tkeep_reg  = mem_fifo_out_tkeep;
              m_axis_tlast_reg  = mem_fifo_out_tlast;
              mem_fifo_rd_en = m_axis_tready_reg;

              metadata_out_valid_reg  = 1'b1;
              metadata_out_reg        = mem_meta_out;
              metadata_out_reg.opcode = READ_RESULT;

              if (m_axis_tready_reg) begin
                mem_state_next = READ_MEM;
                mem_meta_rd_en = 1'b1;
              end
            end
            READ_NOT_FOUND: begin
              metadata_out_valid_reg  = 1'b1;
              metadata_out_reg        = mem_meta_out;
              metadata_out_reg.opcode = READ_NOT_FOUND;

              if (m_axis_tready_reg) begin
                out_busy_next[1] = 1'b0;
                mem_meta_rd_en   = 1'b1;
                mem_fifo_rd_en   = 1'b1;
              end
            end
            WRITE: begin
              if (!is_leader) begin
                metadata_out_valid_reg  = 1'b1;
                metadata_out_reg        = mem_meta_out;
                metadata_out_reg.opcode = WRITE_ACK;

                if (m_axis_tready_reg) begin
                  out_busy_next[1] = 1'b0;
                  mem_meta_rd_en   = 1'b1;
                  mem_fifo_rd_en   = 1'b1;
                end
              end
              else begin
                out_busy_next[1] = 1'b0;
                mem_meta_rd_en   = 1'b1;
                mem_fifo_rd_en   = 1'b1;
              end
            end
            default:;
          endcase
        end
      end
      READ_MEM: begin
        m_axis_tvalid_reg = !mem_fifo_empty;
        m_axis_tdata_reg  = mem_fifo_out_tdata;
        m_axis_tkeep_reg  = mem_fifo_out_tkeep;
        m_axis_tlast_reg  = mem_fifo_out_tlast;
        mem_fifo_rd_en = m_axis_tready_reg;

        if (m_axis_tvalid_reg && m_axis_tready_reg && m_axis_tlast_reg) begin
          out_busy_next[1] = 1'b0;
          mem_state_next = ACCEPT_MEM;
        end
      end
      default:;
    endcase
  end
end

nodes_table #(
  .TABLE_SIZE          (MAX_NODES)
) nodes_table_inst (
  .aclk                (axis_clk),
  .rstn                (axis_rstn),

  .metadata_valid      (metadata_in_valid),
  .metadata            (metadata_in),

  .address_table_index (table_index),
  .address_table_ip    (table_ip),
  .address_table_mac   (table_mac),

  .index_table_index   (),
  .index_table_ip      ('0),

  .num_nodes           (num_nodes)
);

logic net_fifo_wr_en;
assign net_fifo_wr_en = s_axis_tvalid && |s_axis_tkeep;

// FIFO to store input replication packets
xpm_fifo_sync #(
  .DOUT_RESET_VALUE    ("0"),
  .ECC_MODE            ("no_ecc"),
  .FIFO_MEMORY_TYPE    ("auto"),
  .FIFO_READ_LATENCY   (1),
  .FIFO_WRITE_DEPTH    (FIFO_DEPTH*8),
  .PROG_FULL_THRESH    (FIFO_DEPTH*8-5),
  .READ_DATA_WIDTH     (DATA_WIDTH + KEEP_WIDTH + 1),
  .READ_MODE           ("fwft"),
  .WRITE_DATA_WIDTH    (DATA_WIDTH + KEEP_WIDTH + 1)
) net_fifo (
  .wr_en               (net_fifo_wr_en),
  .din                 ({s_axis_tdata, s_axis_tkeep, s_axis_tlast}),
  .wr_ack              (),
  .rd_en               (net_fifo_rd_en),
  .data_valid          (),
  .dout                ({net_fifo_out_tdata, net_fifo_out_tkeep, net_fifo_out_tlast}),
  .wr_data_count       (),
  .rd_data_count       (),
  .empty               (net_fifo_empty),
  .full                (),
  .almost_empty        (),
  .almost_full         (),
  .overflow            (),
  .underflow           (),
  .prog_empty          (),
  .prog_full           (net_fifo_prog_full),
  .sleep               (1'b0),
  .sbiterr             (),
  .dbiterr             (),
  .injectsbiterr       (1'b0),
  .injectdbiterr       (1'b0),
  .wr_clk              (axis_clk),
  .rst                 (~axis_rstn),
  .rd_rst_busy         (),
  .wr_rst_busy         ()
);

// FIFO to store input replication metadata
xpm_fifo_sync #(
  .DOUT_RESET_VALUE    ("0"),
  .ECC_MODE            ("no_ecc"),
  .FIFO_MEMORY_TYPE    ("auto"),
  .FIFO_READ_LATENCY   (1),
  .FIFO_WRITE_DEPTH    (FIFO_DEPTH),
  .PROG_FULL_THRESH    (FIFO_DEPTH-5),
  .READ_DATA_WIDTH     (METADATA_WIDTH),
  .READ_MODE           ("fwft"),
  .WRITE_DATA_WIDTH    (METADATA_WIDTH)
) net_metadata_fifo (
  .wr_en               (metadata_in_valid),
  .din                 (metadata_in),
  .wr_ack              (),
  .rd_en               (net_meta_rd_en),
  .data_valid          (),
  .dout                (net_meta_out),
  .wr_data_count       (),
  .rd_data_count       (),
  .empty               (net_meta_empty),
  .full                (),
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
  .wr_clk              (axis_clk),
  .rst                 (~axis_rstn),
  .rd_rst_busy         (),
  .wr_rst_busy         ()
);

logic mem_fifo_wr_en;
assign mem_fifo_wr_en = s_axis_mem_tvalid && |s_axis_mem_tkeep;

// FIFO to store input memory controller packets
xpm_fifo_sync #(
  .DOUT_RESET_VALUE    ("0"),
  .ECC_MODE            ("no_ecc"),
  .FIFO_MEMORY_TYPE    ("auto"),
  .FIFO_READ_LATENCY   (1),
  .FIFO_WRITE_DEPTH    (FIFO_DEPTH*8),
  .PROG_FULL_THRESH    (FIFO_DEPTH*8-5),
  .READ_DATA_WIDTH     (DATA_WIDTH + KEEP_WIDTH + 1),
  .READ_MODE           ("fwft"),
  .WRITE_DATA_WIDTH    (DATA_WIDTH + KEEP_WIDTH + 1)
  ) mem_fifo (
  .wr_en               (s_axis_mem_tvalid),
  .din                 ({s_axis_mem_tdata, s_axis_mem_tkeep, s_axis_mem_tlast}),
  .wr_ack              (),
  .rd_en               (mem_fifo_rd_en),
  .data_valid          (),
  .dout                ({mem_fifo_out_tdata, mem_fifo_out_tkeep, mem_fifo_out_tlast}),
  .wr_data_count       (),
  .rd_data_count       (),
  .empty               (mem_fifo_empty),
  .full                (),
  .almost_empty        (),
  .almost_full         (),
  .overflow            (),
  .underflow           (),
  .prog_empty          (),
  .prog_full           (mem_fifo_prog_full),
  .sleep               (1'b0),
  .sbiterr             (),
  .dbiterr             (),
  .injectsbiterr       (1'b0),
  .injectdbiterr       (1'b0),
  .wr_clk              (axis_clk),
  .rst                 (~axis_rstn),
  .rd_rst_busy         (),
  .wr_rst_busy         ()
);

// FIFO to store input memory controller metadata
xpm_fifo_sync #(
  .DOUT_RESET_VALUE    ("0"),
  .ECC_MODE            ("no_ecc"),
  .FIFO_MEMORY_TYPE    ("auto"),
  .FIFO_READ_LATENCY   (1),
  .FIFO_WRITE_DEPTH    (FIFO_DEPTH),
  .PROG_FULL_THRESH    (FIFO_DEPTH-5),
  .READ_DATA_WIDTH     (METADATA_WIDTH),
  .READ_MODE           ("fwft"),
  .WRITE_DATA_WIDTH    (METADATA_WIDTH)
) mem_metadata_fifo (
  .wr_en               (metadata_mem_in_valid),
  .din                 (metadata_mem_in),
  .wr_ack              (),
  .rd_en               (mem_meta_rd_en),
  .data_valid          (),
  .dout                (mem_meta_out),
  .wr_data_count       (),
  .rd_data_count       (),
  .empty               (mem_meta_empty),
  .full                (),
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
  .wr_clk              (axis_clk),
  .rst                 (~axis_rstn),
  .rd_rst_busy         (),
  .wr_rst_busy         ()
);


`ifdef __simulation_log_rep__
//   integer log_fd;
// 
//   initial begin
//     string filename;
//     $sformat(filename, "replication_engine_%0d.log", THREAD);
//     log_fd = $fopen(filename, "w");
// 
//     $fmonitor(log_fd, "[%t] [HT: %d] REPL_ENGINE METADATA_MEM_OUT_REG:\n net_state=%p, mem_state=%p, ack_id=%d, rep_read_cnt=%d, rep_write_ptr=%d, nodes_count=%d, metadata_sent=%b, out_busy=%b, memory_delay=%d, tag_written=%b, table_index=%d\n 
//     metadata_out_valid_reg=%b, metadata_out_reg=(opcode=%d, index=%d, key=%h, ip=%h, mac=%h)\n 
//     metadata_mem_out_valid_reg=%b, metadata_mem_out_reg=(opcode=%d, index=%d, key=%h, ip=%h, mac=%h)\n 
//     net_meta_out=(opcode=%d, index=%d, key=%h, ip=%h, mac=%h), net_meta_empty=%b\n 
//     mem_meta_out=(opcode=%d, index=%d, key=%h, ip=%h, mac=%h), mem_meta_empty=%b\n 
//     metadata_in_valid=%b, metadata_in=(opcode=%d, index=%d, key=%h, ip=%h, mac=%h)\n 
//     metadata_mem_in_valid=%b, metadata_mem_in=(opcode=%d, index=%d, key=%h, ip=%h, mac=%h)\n
//     num_nodes=%d\n
//     ack_table_write=(meta=(opcode=%d, index=%d, key=%h, ip=%h, mac=%h), index=%d, count=%d, is_running=%b)\n
//     ack_table_read=(meta=(opcode=%d, index=%d, key=%h, ip=%h, mac=%h), index=%d, count=%d, is_running=%b)\n
//     ack_table_read_tmp=(meta=(opcode=%d, index=%d, key=%h, ip=%h, mac=%h), index=%d, count=%d, is_running=%b)", 
//                 $time, 
//                 THREAD, 
//                 net_state, 
//                 mem_state, 
//                 ack_id, 
//                 rep_read_cnt, 
//                 rep_write_ptr, 
//                 nodes_count, 
//                 metadata_sent, 
//                 out_busy, 
//                 memory_delay, 
//                 tag_written, 
//                 table_index,
//                 metadata_out_valid_reg,
//                 metadata_out_reg.opcode,
//                 metadata_out_reg.index,
//                 metadata_out_reg.key,
//                 metadata_out_reg.ip,
//                 metadata_out_reg.mac,
//                 metadata_mem_out_valid_reg,
//                 metadata_mem_out_reg.opcode,
//                 metadata_mem_out_reg.index,
//                 metadata_mem_out_reg.key,
//                 metadata_mem_out_reg.ip,
//                 metadata_mem_out_reg.mac,
//                 net_meta_out.opcode,
//                 net_meta_out.index,
//                 net_meta_out.key,
//                 net_meta_out.ip,
//                 net_meta_out.mac,
//                 net_meta_empty,
//                 mem_meta_out.opcode,
//                 mem_meta_out.index,
//                 mem_meta_out.key,
//                 mem_meta_out.ip,
//                 mem_meta_out.mac,
//                 mem_meta_empty,
//                 metadata_in_valid,
//                 metadata_in.opcode,
//                 metadata_in.index,
//                 metadata_in.key,
//                 metadata_in.ip,
//                 metadata_in.mac,
//                 metadata_mem_in_valid,
//                 metadata_mem_in.opcode,
//                 metadata_mem_in.index,
//                 metadata_mem_in.key,
//                 metadata_mem_in.ip,
//                 metadata_mem_in.mac,
//                 num_nodes,
//                 ack_table_write.meta.opcode,
//                 ack_table_write.meta.index,
//                 ack_table_write.meta.key,
//                 ack_table_write.meta.ip,
//                 ack_table_write.meta.mac,
//                 ack_table_write.index,
//                 ack_table_write.count,
//                 ack_table_write.is_running,
//                 ack_table_read.meta.opcode,
//                 ack_table_read.meta.index,
//                 ack_table_read.meta.key,
//                 ack_table_read.meta.ip,
//                 ack_table_read.meta.mac,
//                 ack_table_read.index,
//                 ack_table_read.count,
//                 ack_table_read.is_running,
//                 ack_table_read_tmp.meta.opcode,
//                 ack_table_read_tmp.meta.index,
//                 ack_table_read_tmp.meta.key,
//                 ack_table_read_tmp.meta.ip,
//                 ack_table_read_tmp.meta.mac,
//                 ack_table_read_tmp.index,
//                 ack_table_read_tmp.count,
//                 ack_table_read_tmp.is_running);
//   end
//
//
//
//  final begin
//    if (log_fd) $fclose(log_fd);
//  end

  // Monitor m_axis_mem interface (Memory controller write)
  always @(posedge axis_clk) begin
    if (m_axis_mem_tvalid && m_axis_mem_tready) begin
      $display("[%t] [HT: %d] REPL_ENGINEs M_AXIS_MEM:\n data=0x%h, keep=0x%h, last=%b", $time, THREAD, m_axis_mem_tdata, m_axis_mem_tkeep, m_axis_mem_tlast);
    end
  end

  // Monitor internal registered signals (Replication packet output)
  always @(posedge axis_clk) begin
    if (m_axis_tvalid_reg && m_axis_tready_reg) begin
      $display("[%t] [HT: %d] REPL_ENGINE M_AXIS_REG:\n data=0x%h, keep=0x%h, last=%b", $time, THREAD, m_axis_tdata_reg, m_axis_tkeep_reg, m_axis_tlast_reg);
    end
  end

  // Monitor internal registered signals (Memory controller write)
  always @(posedge axis_clk) begin
    if (m_axis_mem_tvalid_reg && m_axis_mem_tready_reg) begin
      $display("[%t] [HT: %d] REPL_ENGINE M_AXIS_MEM_REG:\n data=0x%h, keep=0x%h, last=%b", $time, THREAD, m_axis_mem_tdata_reg, m_axis_mem_tkeep_reg, m_axis_mem_tlast_reg);
    end
  end

  // Monitor metadata output (Replication)
  always @(posedge axis_clk) begin
    if (metadata_out_valid_reg) begin
      $display("[%t] [HT: %d] REPL_ENGINE METADATA_OUT_REG:\n opcode=%d, key=%h, IP=%h, MAC=%h", $time, THREAD, metadata_out_reg.opcode, metadata_out_reg.key, metadata_out_reg.ip, metadata_out_reg.mac);
    end
  end
`endif

endmodule