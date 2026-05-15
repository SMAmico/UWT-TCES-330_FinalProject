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

module ALU (...);
	...
endmodule

module RegALU (...);
	...
endmodule

module RegALU_tb();
	...
endmodule
