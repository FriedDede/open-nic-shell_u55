`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/17/2025 08:44:13 PM
// Design Name: 
// Module Name: Controller_Arbitrer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module synchronizer #(
    parameter N = 8
)(
    input logic  aclk,
    input logic  aresetn,

    input logic  s2mm_cmd_start,

    input logic  command_sent,
    input logic  stream_sent,

    output logic stream_enable
);

    // Arbitrer FSM states
    typedef enum {A_IDLE,A_WAIT_COMMAND,A_INCR_COMMAND,A_DECR_COMMAND} state_a;

    logic [N-1:0] cmd_count_reg;
    logic [N-1:0] cmd_count_next;

    state_a state_reg, state_next; 

    always_ff @(posedge aclk, negedge aresetn) begin
        if(!aresetn) begin // Boot up the FSM.
            state_reg <= A_IDLE;
            cmd_count_reg <= '0;
        end
        else begin
            state_reg <= state_next;
            cmd_count_reg <= cmd_count_next; 
        end
    end

    // Arbitrer FSM
    always_comb begin
        state_next = state_reg;
        cmd_count_next = cmd_count_reg;

        case(state_reg)

        //Arbitrer IDLE state
        A_IDLE: begin 
            if(s2mm_cmd_start)
                state_next = A_WAIT_COMMAND;
            else
                state_next = A_IDLE;
        end
        
        //CMD START state
        A_WAIT_COMMAND: begin
            if(command_sent && stream_sent)
                state_next = A_WAIT_COMMAND; // no change
            else if (command_sent)
                state_next = A_INCR_COMMAND;
            else if (stream_sent)
                state_next = A_DECR_COMMAND;
            else
                state_next = A_WAIT_COMMAND;
        end

        A_INCR_COMMAND: begin
            cmd_count_next = cmd_count_reg +1;
            state_next = A_WAIT_COMMAND;
        end 

        A_DECR_COMMAND: begin
        if(cmd_count_reg > 0)
                cmd_count_next = cmd_count_reg -1;
            state_next = A_WAIT_COMMAND;
        end

        endcase

    end

    assign stream_enable = (cmd_count_reg !=0);

endmodule