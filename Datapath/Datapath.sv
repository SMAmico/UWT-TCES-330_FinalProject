/*
Seth Amico, John Teal
UW TCES 330
Programmable Processor
Project File: Datapath.sv
10 June 2026

Description:
This file contains the register file, ALU, RAM instantiation, data source mux, and combined Datapath 
module for Project phase III. this file REQUIRES the verilog file myRAM.v to be included. 
*/

module RegFile (
	input Clk,			// system clock
	input write,			// write enable
	
	input [3:0] wrAddr,		// write address
	input [15:0] wrData,		// write data

	input [3:0] rdAddrA,		// A-side read address
	output [15:0] rdDataA,		// A-side read data

	input [3:0] rdAddrB,		// B-side read address
	output [15:0] rdDataB		// B-side read data
	);

	logic [15:0] regfile [0:15];	// sixteen 16-bit registers
/*
Read Logic: The register file has two read ports. rdAddrA selects which register appears on rdDataA.
rdAddrB selects which register appears on rdDataB. These are combinational reads, so the selected 
register values appear on the outputs without waiting for a clock edge.  This follows the 
register-file style shown in the lecture references, where the read outputs are assigned directly from
the register array.
*/
	assign rdDataA = regfile[rdAddrA];
	assign rdDataB = regfile[rdAddrB];
/*
Write Logic: the register file has one write port.  When write is high, wrData is copied into the 
register selected by wrAddr on the rising edge of clk. When write is low, no register changes.
*/
	always_ff @(posedge Clk) begin
		if (write)
			regfile[wrAddr] <= wrData;
	end
endmodule

module ALU (
	input [15:0] A,			// first 16-bit ALU input
	input [15:0] B,			// second 16-bit ALU input
	input [2:0] S,			// 3-bit ALU operation select
	output logic [15:0] Q		// 16-bit ALU result
);
/*
ALU operation logic: The ALU is combinational, meaning it does not use a clock.  Whenever A, B, or S
changes, Q is recalculated. The select input S chooses which operation appears on Q.
	S = 000: Q = A + 0
	S = 001: Q = A + B
	S = 010: Q = A - B
	S = 011: Q = A
	S = 100: Q = A ^ B
	S = 101: Q = A | B
	S = 110: Q = A & B
	S = 111: Q = A + 1
*/
	always_comb begin
		case (S)
			3'b000: Q = A + 16'd0;
			3'b001: Q = A + B;
			3'b010: Q = A - B;
			3'b011: Q = A;
			3'b100: Q = A ^ B;
			3'b101: Q = A | B;
			3'b110: Q = A & B;
			3'b111: Q = A + 16'd1;
			default: Q = 16'h0000;
		endcase
	end
endmodule


/*
mux16w_2to1: this module controls the data flow into the register file. the RF_s signal
sets the output to be either from the RAM (for load operations) or ALU (for arithmetic operations).
*/
module mux16w_2to1( 
	input [15:0]RAM, ALU,
	input RF_s,
	output logic [15:0]Q
	);

	assign Q = RF_s ? RAM : ALU;
	
endmodule



//TODO: create a module for the RAM by instantiating an IP .v file from the Quartus IP library

/*
RAM module: this module is blank, but will act as a wrapper module for a prebuilt verilog file from Quartus.
*/
module RAM(
	input [7:0]D_Addr,
	input D_wr,
	input Clk,
	input [15:0]W_data,
	output [15:0]R_data
	);
	//myRAM (address, clock, data, wren, q);
	myRAM ram_lpm(.address(D_Addr), .clock(Clk), .data(W_data), .wren(D_wr), .q(R_data));
	
endmodule

module Datapath(
    input Clk,                         	// system clock for the register file and RAM

    input [7:0] D_Addr,                	// RAM data address
    input D_wr,                        	// RAM data write enable
    input RF_s,                        	// register file mux source select

    input RF_W_en,                     	// register file write enable

    input [3:0] RF_Ra_addr,            	// register file read A address
    input [3:0] RF_Rb_addr,            	// register file read B address
    input [3:0] RF_W_addr,             	// register file write address

    input [2:0] Alu_s0,                	// ALU operation select
									   
	output [15:0] ALU_A,	     	// ALU_A output
	output [15:0] ALU_B,		// ALU_B output
	output [15:0] ALU_Out		// ALU_Out output
);

    /*
    Internal datapath wires. Ra_data and Rb_data are the register file read outputs. Q_Data is the 
	ALU output. R_data is the RAM read output. W_data is the mux output that feeds the register file 
	write data input.
    */

    wire [15:0] Ra_data;
    wire [15:0] Rb_data;
    wire [15:0] Q_Data;
    wire [15:0] R_data;
    wire [15:0] W_data;

	assign ALU_A   = Ra_data;
	assign ALU_B   = Rb_data;
	assign ALU_Out = Q_Data;

    /*
    Register file instance. The register file write data comes from W_data, which is selected by the 
	RAM/ALU mux. This allows LOAD to write RAM data and ADD/SUB to write ALU data.
    */
    RegFile rf0(
        .Clk(Clk),
        .write(RF_W_en),
        .wrAddr(RF_W_addr),
        .wrData(W_data),
        .rdAddrA(RF_Ra_addr),
        .rdDataA(Ra_data),
        .rdAddrB(RF_Rb_addr),
        .rdDataB(Rb_data)
    );

    // ALU instance. The ALU uses the two register file read outputs as operands.
    ALU alu0(
        .A(Ra_data),
        .B(Rb_data),
        .S(Alu_s0),
        .Q(Q_Data)
    );

    /*
    Register file write-data mux. RF_s = 1 selects RAM data for LOAD. RF_s = 0 selects ALU data for 
	ADD/SUB.
    */
    mux16w_2to1 rf_source0(
        .RAM(R_data),
        .ALU(Q_Data),
        .RF_s(RF_s),
        .Q(W_data)
    );

    // RAM instance. STORE writes Ra_data into RAM. LOAD reads RAM data out through R_data.
    RAM ram0(
        .D_Addr(D_Addr),
        .D_wr(D_wr),
        .Clk(Clk),
        .W_data(Ra_data),
        .R_data(R_data)
    );

endmodule
