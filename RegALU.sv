/*
Seth Amico, John Teal
UW TCES 330
Project Phase II
15 May 2026

Description:
This file contains the register file, ALU, RegALU integration module, and RegALU testbench for Project 
Phase II.
*/

module RegFile (
	input clk,					// system clock
	input write,				// write enable
	
	input [2:0] wrAddr,			// write address
	input [15:0] wrData,		// write data

	input [2:0] rdAdderA,		// A-sde read address
	output [15:0] rdDataA,		// A-side read data

	input [2:0] rdAdderB,		// B-sde read address
	output [15:0] rdDataB,		// B-side read data
	);

	logic [15:0] regfile [0:7];	// eight 16-bit registers
/*
Read Logic: The register file has two read ports.
rdAddrA selects which register appears on rdDataA.
rdAddrB selects which register appears on rdDataB.
These are combinational reads, so the selected register values appear on the outputs without waiting
for a clock edge.  This follows the register-file style shown in the lecture references, where the
read outputs are assigned directly from the register array.
*/
	assign rdDataA = regfile[rdAddrA];
	assign rdDataB = regfile[rdAddrB];
/*
Write Logic: the register file has one write port.  When write is high, wrData is copied into the 
register selected by wrAddr on the rising edge of clk. When write is low, no register changes.
*/
	always @(posedge clk) begin
		if (write)
			regfile[wrAddr] <= wrData;
	end
endmodule

module ALU (
	input [15:0] A,				// first 16-bit ALU input
	input [15:0] B,				// second 16-bit ALU input
	input [2:0] S,				// 3-bit ALU operation select
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

module RegALU (...);
	...
endmodule

module RegALU_tb();
	...
endmodule
