`timescale 1ns/1ps

import metadata_pkg::*; 

module election_engine_controller #(
  parameter int                     MAX_NODES    = 32,
  parameter int                     PTR_WIDTH    = $clog2(MAX_NODES),
  parameter int                     TIMER_WIDTH  = 25,  // ~134ms
  parameter int                     SEED         = 32'hdeadbeef,
  parameter logic [TIMER_WIDTH-1:0] TAP_MASK     = 25'h1200000,
  parameter logic             [7:0] BROADCAST_ID = '1,
  parameter logic             [7:0] LEADER_ID    = '0
) (
  input  logic                 axis_aclk,
  input  logic                 axi_rstn,

  input  logic [PTR_WIDTH-1:0] num_nodes,
  output logic           [7:0] leader,
  output logic           [7:0] term,
  input  st_election_command   received_command,
  output st_election_command   send_command
);
  
typedef enum logic [7:0] { 
  FOLLOWER,
  CANDIDATE,
  LEADER
} role_e;

st_election_command     send_command_next;
role_e                  role, role_next;
logic             [7:0] received_seq, received_seq_next;
logic             [7:0] send_seq, send_seq_next;
logic             [7:0] term_next;
logic             [7:0] leader_next;
logic             [7:0] votes, votes_next;
logic [TIMER_WIDTH-1:0] timer_max;
logic [TIMER_WIDTH-1:0] timer;
logic [TIMER_WIDTH-1:0] random;
logic                   timeout;
logic                   reset_timer;

// RAFT Leader Election
always_ff @(posedge axis_aclk) begin
  if (!axi_rstn) begin
    role         <= FOLLOWER;
    term         <= 0;
    leader       <= 1;
    votes        <= 1;
    received_seq <= 0;
    send_seq     <= 0;
    send_command <= 0;
    send_command.sequence_number <= 1;
  end
  else begin
    role         <= role_next;
    term         <= term_next;
    leader       <= leader_next;
    received_seq <= received_seq_next;
    send_seq     <= send_seq_next;
    send_command <= send_command_next;
    votes        <= votes_next;
  end
end

always_comb begin
  role_next         = role;
  term_next         = term;
  leader_next       = leader;
  votes_next        = votes;
  received_seq_next = received_seq;
  send_seq_next     = send_seq;
  reset_timer       = 1'b0;
  send_command_next = send_command;
  case (role)
    FOLLOWER: begin
      if (timeout && num_nodes != 1) begin
        term_next = term + 1;
        role_next = CANDIDATE;
      end
      else if (received_command.sequence_number != received_seq) begin
        received_seq_next = received_command.sequence_number;
        send_seq_next     = send_seq + 1;
        case (received_command.opcode)
          HEARTBEAT: begin
            reset_timer                       = 1'b1;
            send_command_next.sequence_number = send_seq;
            send_command_next.message_id      = received_command.message_id;
            send_command_next.node_id         = received_command.node_id;
            send_command_next.opcode          = HEARTBEAT_ACK;
          end
          VOTE_REQUEST: begin
            if (received_command.message_id > term) begin
              reset_timer                       = 1'b1;
              term_next                         = received_command.message_id;
              leader_next                       = received_command.node_id;
              send_command_next.sequence_number = send_seq;
              send_command_next.message_id      = received_command.message_id;
              send_command_next.node_id         = received_command.node_id;
              send_command_next.opcode          = VOTE;
            end
          end
        endcase
      end
    end
    CANDIDATE: begin
      if (timeout) begin
        reset_timer                       = 1'b1;
        send_seq_next                     = send_seq + 1;
        send_command_next.sequence_number = send_seq;
        send_command_next.message_id      = term;
        send_command_next.node_id         = BROADCAST_ID;
        send_command_next.opcode          = VOTE_REQUEST;
      end
      else if (received_command.sequence_number != received_seq) begin
        received_seq_next = received_command.sequence_number;
        send_seq_next     = send_seq + 1;
        case (received_command.opcode)
          HEARTBEAT, VOTE_REQUEST: begin
            if (received_command.message_id >= term) begin
              reset_timer                       = 1'b1;
              role_next                         = FOLLOWER;
              term_next                         = received_command.message_id;
              leader_next                       = received_command.node_id;
              send_command_next.sequence_number = send_seq;
              send_command_next.message_id      = received_command.message_id;
              send_command_next.node_id         = received_command.node_id;
              if (received_command.opcode == VOTE_REQUEST)
                send_command_next.opcode = VOTE;
              else
                send_command_next.opcode = HEARTBEAT_ACK;
            end
          end
          VOTE: begin
            votes_next = votes + 1;
            if (votes + 1 == num_nodes / 2 + 1) begin
              reset_timer                       = 1'b1;
              votes_next                        = 1;
              role_next                         = LEADER;
              leader_next                       = LEADER_ID;
              send_seq_next                     = send_seq + 1;
              send_command_next.sequence_number = send_seq;
              send_command_next.message_id      = term;
              send_command_next.node_id         = BROADCAST_ID;
              send_command_next.opcode          = HEARTBEAT;
            end
          end
        endcase
      end
    end
    LEADER: begin
      if (timeout) begin
        reset_timer                       = 1'b1;
        send_seq_next                     = send_seq + 1;
        send_command_next.sequence_number = send_seq;
        send_command_next.message_id      = term;
        send_command_next.node_id         = BROADCAST_ID;
        send_command_next.opcode          = HEARTBEAT;
      end
    end
  endcase
end

// Timer 
always_ff @(posedge axis_aclk) begin
  if (!axi_rstn || reset_timer) begin
    timer   <= 0;
    timeout <= 1'b0;
  end
  else begin
    timer   <= timer + 1;
    timeout <= 1'b0;
    if (timer == timer_max) begin
      timer   <= timer;
      timeout <= 1'b1;
    end
  end
end

// Galois LSFR
always_ff @(posedge axis_aclk) begin
  if (!axi_rstn) begin
    random    <= SEED;
    timer_max <= SEED;
  end
  else begin
    timer_max <= {1'b1, random[TIMER_WIDTH-2:0]};
    if (reset_timer) begin
      random <= (random >> 1) ^ (random[0] ? TAP_MASK : {TIMER_WIDTH{1'b0}});
    end
    // Leader should send heartbeats more often than followers expect to receive them
    if (role == LEADER) begin
      timer_max <= {1'b1, random[TIMER_WIDTH-2:0]} >> 2;
    end
  end
end

endmodule