/*
Seth Amico, John Teal
UW TCES 330
Programmable Processor
Project File: myROM_tb.sv
10 June 2026
*/

`timescale 1 ps / 1 ps

module myROM_tb();

    logic Clk;
    logic [6:0] address;
    logic [15:0] q;

    myROM dut(
        .address(address),
        .clock(Clk),
        .q(q)
    );

    initial Clk = 1'b0;

    always begin
        #5 Clk = ~Clk;
    end

    initial begin
        $display("Starting myROM testbench.");

        address = 7'h00;
        #10;
        $display("address=%h q=%h expected=21BA", address, q);

        address = 7'h01;
        #10;
        $display("address=%h q=%h expected=22AB", address, q);

        address = 7'h02;
        #10;
        $display("address=%h q=%h expected=4ABA", address, q);

        address = 7'h08;
        #10;
        $display("address=%h q=%h expected=5000", address, q);

        $display("myROM testbench complete.");
        $stop;
    end

endmodule
