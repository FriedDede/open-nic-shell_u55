`timescale 1ns/1ps

module tb_axi4_boot_check;

    // Parameters
    parameter DATA_WIDTH = 512;
    parameter ADDR_WIDTH = 64;
    parameter ID_WIDTH = 4;

    // Clock and Reset
    reg aclk;
    reg aresetn;

    // AXI Master Interface
    reg [ADDR_WIDTH-1:0] tb_s_axi_awaddr;
    reg [DATA_WIDTH-1:0] tb_s_axi_wdata;
    reg tb_s_axi_wvalid;
    reg tb_s_axi_awvalid;

    wire start_o;

    // Instantiate the DUT (Device Under Test)
    axi4_boot_check #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ID_WIDTH(ID_WIDTH)
    ) dut (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axi_awaddr(tb_s_axi_awaddr),
        .s_axi_wdata(tb_s_axi_wdata),
        .s_axi_wvalid(tb_s_axi_wvalid),
        .start_o(start_o)
    );

    // Clock generation
    initial begin
        aclk = 0;
        forever #5 aclk = ~aclk; // 100MHz clock
    end

    // Reset generation
    initial begin
        aresetn = 0;
        # 5 aresetn = 1;
    end

    initial begin
        #100 tb_s_axi_awaddr = '0;
        #10 tb_s_axi_wdata[63 : 0] = 64'hffff_ffff_ffff_ffff;

        #2 tb_s_axi_wvalid = 1;
        tb_s_axi_awvalid = 1;

        #5;
         tb_s_axi_awaddr = '0;
         tb_s_axi_wdata[63 : 0] = 64'hffff_3232_ffff_ffff;

        #5;
        if (start_o) begin
            #2000;
            if (!start_o) begin
                $display("simulation passed");
            end else begin
                $error("simulation not passed");
            end
        end else begin
            $error("simulation not passed");
        end

        #1000;
        #100 tb_s_axi_awaddr = '0;
        #10 tb_s_axi_wdata[63 : 0] = 64'hffff_ffff_ffff_ffff;
        #2 tb_s_axi_wvalid = 1;
        tb_s_axi_awvalid = 1;
        #5;
         tb_s_axi_awaddr = '0;
         tb_s_axi_wdata[63 : 0] = 64'hffff_3232_ffff_ffff;
        #5;
        if (start_o) begin
            #2000;
            if (!start_o) begin
                $display("simulation passed");
            end else begin
                $error("simulation not passed");
            end
        end else begin
            $error("simulation not passed");
        end
    end
endmodule

       
