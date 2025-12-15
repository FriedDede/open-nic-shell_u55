`timescale 1ns/1ps

import metadata_pkg::*; 

module election_engine #(
  parameter int MAX_NODES      = 32,
  parameter int PTR_WIDTH      = $clog2(MAX_NODES),
  parameter int FIFO_DEPTH     = 16,
  parameter int TIMER_WIDTH    = 30,  // ~4.2 s
  parameter int SEED           = 32'hdeadbeef,
  parameter logic [TIMER_WIDTH-1:0] TAP_MASK = 30'h60000000,
  parameter int USE_CONTROLLER = 1
) (
  input  logic        axis_aclk,
  input  logic        axil_aclk,
  input  logic        axi_rstn,

  input  logic [31:0] s_axil_awaddr,
  input  logic        s_axil_awvalid,
  output logic        s_axil_awready,
  input  logic [31:0] s_axil_wdata,
  input  logic  [7:0] s_axil_wstrb,
  input  logic        s_axil_wvalid,
  output logic        s_axil_wready,
  output logic  [1:0] s_axil_bresp,
  output logic        s_axil_bvalid,
  input  logic        s_axil_bready,
  input  logic [31:0] s_axil_araddr,
  input  logic        s_axil_arvalid,
  output logic        s_axil_arready,
  output logic [31:0] s_axil_rdata,
  output logic  [1:0] s_axil_rresp,
  output logic        s_axil_rvalid,
  input  logic        s_axil_rready,

  input  st_metadata  metadata_in,
  input  logic        metadata_in_valid,

  output st_metadata  metadata_out,
  output logic        metadata_out_valid,

  output logic        is_leader
);

localparam logic [7:0] BROADCAST_ID = '1;
localparam logic [7:0] LEADER_ID    = '0;

logic           [7:0] term;
logic           [7:0] leader;
logic           [7:0] num_sent;
logic [PTR_WIDTH-1:0] num_nodes;
logic [PTR_WIDTH-1:0] send_index;
logic          [31:0] send_ip;
logic          [47:0] send_mac;
logic           [7:0] send_seq;
st_metadata           received_metadata;
logic                 received_process;
logic                 received_empty;
logic          [31:0] received_ip;
logic [PTR_WIDTH-1:0] received_index;
logic           [7:0] received_seq;
logic                 axi_write_ready;
logic                 axi_read_ready;
logic                 broadcast;
logic                 update_send;
logic                 update_delay;
logic                 update_received;
st_election_command   send_command;
st_election_command   received_command;

assign axi_read_ready   = s_axil_arvalid && s_axil_rready;
assign axi_write_ready  = s_axil_awvalid && s_axil_wvalid;
assign is_leader        = leader == LEADER_ID;
assign broadcast        = send_command.node_id == BROADCAST_ID;
assign send_index       = broadcast ? num_sent : send_command.node_id;
assign received_ip      = received_metadata.ip;

// AXI Slave logic
generate
  if (!USE_CONTROLLER) begin
    always_ff @(posedge axil_aclk) begin
      s_axil_bvalid   <= 1'b0;
      s_axil_rvalid   <= 1'b0;
      if (!axi_rstn) begin
        s_axil_awready  <= 1'b0;
        s_axil_wready   <= 1'b0;
        s_axil_bresp    <= 2'b00;
        s_axil_arready  <= 1'b0;
        s_axil_rdata    <= '0;
        s_axil_rresp    <= 2'b00;
        term            <= 0;
        leader          <= 1;
      end 
      else begin
        s_axil_bvalid   <= 1'b1;
        s_axil_awready <= axi_write_ready;
        s_axil_wready  <= axi_write_ready;
        s_axil_arready <= axi_read_ready;
        if (axi_write_ready) begin
          s_axil_bvalid   <= 1'b1;
          case (s_axil_awaddr)
            32'h000: send_command <= s_axil_wdata;
            32'h008: leader       <= s_axil_wdata;
            32'h00C: term         <= s_axil_wdata;
            default:;
          endcase
        end
        if (axi_read_ready) begin
          s_axil_rvalid <= 1'b1;
          case (s_axil_araddr)
            32'h004: s_axil_rdata <= received_command;
            32'h008: s_axil_rdata <= leader;
            32'h00C: s_axil_rdata <= term;
            32'h010: s_axil_rdata <= num_nodes;
            default: s_axil_rdata <= '0;
          endcase
        end
      end
    end
  end
  else begin
    election_engine_controller #(
      .TIMER_WIDTH      (TIMER_WIDTH),
      .TAP_MASK         (TAP_MASK),
      .SEED             (SEED),
      .BROADCAST_ID     (BROADCAST_ID),
      .LEADER_ID        (LEADER_ID)
    ) election_engine_controller_inst (
      .axis_aclk        (axis_aclk),
      .axi_rstn         (axi_rstn),
      .num_nodes        (num_nodes),
      .received_command (received_command),
      .send_command     (send_command),
      .leader           (leader),
      .term             (term)
    );
  end
endgenerate

// Receiver
always_ff @(posedge axis_aclk) begin
  if (!axi_rstn) begin
    received_command <= '0;
    received_seq     <= 1;
    received_process <= 1'b0;
    update_received  <= 1'b0;
  end
  // Wait one cycle for index BRAM
  else if (!received_empty) begin
    received_process <= 1'b1;
    update_received  <= 1'b1;
  end
  else if (update_received) begin
    received_seq                     <= received_seq + 1;
    received_command.sequence_number <= received_seq;
    received_command.node_id         <= received_index;
    received_command.message_id      <= received_metadata.index;
    received_command.opcode          <= received_metadata.opcode;
    received_process                 <= 1'b0;
    update_received                  <= 1'b0;
  end
end

// Sender
always_ff @(posedge axis_aclk) begin
  metadata_out_valid <= 1'b0;
  if (!axi_rstn) begin
    metadata_out <= 0;
    num_sent     <= 0;
    send_seq     <= 1;
    update_send  <= 1'b1;
    update_delay <= 1'b0;
  end
  else if (send_command.sequence_number != send_seq) begin
    update_send <= 2'b01;
    send_seq    <= send_command.sequence_number;
    if (broadcast) begin
      num_sent <= num_sent + 1;
    end
  end
  // Wait one extra cycle for address BRAM
  // TODO: Refactor this
  else if (update_send) begin
    update_delay <= 1'b1;
    update_send  <= 1'b0;
  end
  else if (update_delay) begin
    metadata_out_valid  <= 1'b1;
    metadata_out.ip     <= send_ip;
    metadata_out.mac    <= send_mac;
    metadata_out.opcode <= send_command.opcode;
    metadata_out.index  <= send_command.message_id;
    metadata_out.key    <= 0;
    update_delay        <= 1'b0;
    if (broadcast) begin
      num_sent <= num_sent + 1;
      if (num_sent == num_nodes - 1) begin
        num_sent    <= 0;
        update_send <= 1'b0;
      end
    end
    else begin  // !broadcast
      update_send <= 1'b0;
    end
  end
end

nodes_table #( 
  .TABLE_SIZE          (MAX_NODES)
) nodes_table_inst (
  .aclk                (axis_aclk),
  .rstn                (axi_rstn),
  .metadata_valid      (metadata_in_valid),
  .metadata            (metadata_in),
  .address_table_index (send_index),
  .address_table_ip    (send_ip),
  .address_table_mac   (send_mac),
  .index_table_ip      (received_ip),
  .index_table_index   (received_index),
  .num_nodes           (num_nodes)
);

// Received packets FIFO
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
) receiver_fifo (
  .wr_en               (metadata_in_valid),
  .din                 (metadata_in),
  .wr_ack              (),
  .rd_en               (received_process),
  .data_valid          (),
  .dout                (received_metadata),
  .wr_data_count       (),
  .rd_data_count       (),
  .empty               (received_empty),
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
  .wr_clk              (axis_aclk),
  .rst                 (~axi_rstn),
  .rd_rst_busy         (),
  .wr_rst_busy         ()
);

endmodule
