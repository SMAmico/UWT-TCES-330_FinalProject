/*
Seth Amico, John Teal
UW TCES 330
Programmable Processor
Project File: myRAM_tb.sv
10 June 2026
*/

`timescale 1 ps / 1 ps

module myRAM_tb();

    logic Clk;
    logic [7:0] address;
    logic [15:0] data;
    logic wren;
    logic [15:0] q;

    myRAM dut(
        .address(address),
        .clock(Clk),
        .data(data),
        .wren(wren),
        .q(q)
    );

    initial Clk = 1'b0;

    always begin
        #5 Clk = ~Clk;
    end

    task automatic tick;
        begin
            @(posedge Clk);
            #1;
        end
    endtask

    initial begin
        $display("Starting myRAM testbench.");

        wren = 1'b0;
        data = 16'h0000;

        address = 8'h1B;
        #10;
        $display("address=%h q=%h expected=000A", address, q);

        address = 8'h2A;
        #10;
        $display("address=%h q=%h expected=0003", address, q);

        address = 8'h3C;
        #10;
        $display("address=%h q=%h expected=0004", address, q);

        address = 8'h7E;
        #10;
        $display("address=%h q=%h expected=0002", address, q);

        /*
        Write test:
        Store 0009 into RAM address 6A, then read it back.
        */
        address = 8'h6A;
        data = 16'h0009;
        wren = 1'b1;
        tick();

        wren = 1'b0;
        #10;
        $display("address=%h q=%h expected=0009", address, q);

        $display("myRAM testbench complete.");
        $stop;
    end

endmodule
