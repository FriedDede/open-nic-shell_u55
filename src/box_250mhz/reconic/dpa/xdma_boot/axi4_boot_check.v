// module that checks for the iniatialization complete signal from the dma
module axi4_boot_check #(
    parameter DATA_WIDTH = 512,
    parameter ADDR_WIDTH = 64,
    parameter ID_WIDTH = 4
)(
    // Global signals
    input wire aclk,
    input wire aresetn,
    // AXI Master Interface
    input wire [ADDR_WIDTH-1:0] s_axi_awaddr,
    input wire [DATA_WIDTH-1:0] s_axi_wdata,
    input wire s_axi_wvalid,
    // start the core
    output wire start_o
);

    reg start;
    integer counter;
    assign start_o = start;

    reg [63:0]    wdata_q;
    reg [63:0]    awaddr_q;
    reg           wvalid_q;
    
    always @(posedge aclk, negedge aresetn) begin
        if (!aresetn) begin
            start <= 1'b0;
            counter <= 0;
        end else if (aclk) begin
            if (counter < 100 && start) begin
                counter <= counter + 1;
            end
            if (counter == 100 && start) begin
                start <= 0;
                counter <= 0;
            end else if (wdata_q[63 : 0] == 64'hffffffff_ffffffff & awaddr_q == 64'h0 & wvalid_q & start == 0) begin
                start <= 1'b1;
                counter <= 0;
            end
        end
    end

    always @(posedge aclk, negedge aresetn) begin
        if (!aresetn) begin
            wdata_q     <= 'b0; 
            awaddr_q    <= 'b0;
            wvalid_q    <= 'b0;
        end else if (aclk) begin
            wdata_q     <= s_axi_wdata[63:0]; 
            awaddr_q    <= s_axi_awaddr;
            wvalid_q    <= s_axi_wvalid;
        end
    end
    

endmodule
