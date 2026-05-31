/*
Seth Amico, John Teal
UW TCES 330
Programmable Processor
Project File: Control_Unit_tb.sv
10 June 2026
*/

`timescale 1 ps / 1 ps

module Control_Unit_tb();

    logic Clk;
    logic rst;

    logic Alu_Z;
    logic Alu_N;
    logic Alu_V;

    logic [7:0] D_Addr;
    logic D_wr;

    logic RF_s;

    logic [3:0] RF_W_addr;
    logic RF_W_en;

    logic [3:0] RF_Ra_addr;
    logic [3:0] RF_Rb_addr;

    logic [2:0] Alu_s0;

    logic [15:0] IR_Out;
    logic [7:0] PC_Out;
    logic [3:0] StateOut;
    logic [3:0] NextStateOut;

    integer i;

    Control_Unit dut(
        .Clk(Clk),
        .rst(rst),

        .Alu_Z(Alu_Z),
        .Alu_N(Alu_N),
        .Alu_V(Alu_V),

        .D_Addr(D_Addr),
        .D_wr(D_wr),

        .RF_s(RF_s),

        .RF_W_addr(RF_W_addr),
        .RF_W_en(RF_W_en),

        .RF_Ra_addr(RF_Ra_addr),
        .RF_Rb_addr(RF_Rb_addr),

        .Alu_s0(Alu_s0),

        .IR_Out(IR_Out),
        .PC_Out(PC_Out),
        .StateOut(StateOut),
        .NextStateOut(NextStateOut)
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
        Alu_Z = 1'b0;
        Alu_N = 1'b0;
        Alu_V = 1'b0;

        rst = 1'b1;

        $display("Starting Control_Unit testbench.");

	/*
	Hold reset for two clock edges.
	
	First edge: forces the FSM state to INIT.
	Second edge: lets the INIT state's PC_clr output clear the PC to 0.
	
	This gives the ROM address time to become stable before the first FETCH cycle.
	*/
	tick();
	tick();
	
	rst = 1'b0;
	
        /*
        Run enough cycles to observe:
        INIT -> FETCH -> DECODE -> instruction state -> FETCH ...
        */
 	for (i = 0; i < 34; i = i + 1) begin
    	tick();

    	$display("cycle=%0d PC=%h IR_ld=%b IR_in=%h IR=%h State=%0d Next=%0d D_Addr=%h D_wr=%b RF_s=%b RF_W_addr=%h RF_W_en=%b Alu_s0=%b",
             i, PC_Out, dut.IR_ld, dut.IR_in, IR_Out, StateOut, NextStateOut, D_Addr, D_wr, RF_s, RF_W_addr, RF_W_en, Alu_s0);
	end
        $display("Control_Unit testbench complete.");
        $stop;
    end

endmodule
