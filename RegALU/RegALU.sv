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
	
	input [3:0] wrAddr,			// write address
	input [15:0] wrData,		// write data

	input [3:0] rdAddrA,		// A-side read address
	output [15:0] rdDataA,		// A-side read data

	input [2:0] rdAddrB,		// B-side read address
	output [15:0] rdDataB		// B-side read data
	);

	logic [15:0] regfile [0:15];	// sixteen 16-bit registers
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

module RegALU (
	input clk,					// system clock for the register file
	input RF_W_en,				// register file write enable

	input [3:0] RF_Ra_addr,		// register file read A address
	input [3:0] RF_Rb_addr,		// register file read B address
	input [3:0] RF_W_addr,		// register file write address

	input [2:0] Alu_s0,			// ALU operation select

	output [15:0] Q			// ALU result output
);
/*
This internal wire connects the ALU output back to the register file write data input.
Hence, a compartmentalized approach can be taken where the module output, Q, is not directly
in the internal signal path.
*/

	wire [15:0] Q_Data;
	assign Q = Q_Data;

/*
Internal datapath wires: Ra_data carries the register selected by RF_Ra_addr. Rb_data carries the 
register selected by RF_Rb_addr. These two values become the A and the B inputs of the ALU.
*/
	wire [15:0] Ra_data;
	wire [15:0] Rb_data;
/*
Register file instance: The RegALU control signals use the naming convention from the datapath 
diagram. These are mapped into the RegFile module's simpler port names.
	RF_W_en    -> write
	RF_W_addr  -> wrAddr
	Q          -> wrData
	RF_Ra_addr -> rdAddrA
	Ra_data    -> rdDataA
	RF_Rb_addr -> rdAddrB
	Rb_data    -> rdDataB
The important connection is Q feeding back into wrData. That means the ALU result can be written back
into the register file on the rising clock edge when RF_W_en is high.
*/
	RegFile RF(.clk(clk), .write(RF_W_en), .wrAddr(RF_W_addr), .wrData(Q_Data), .rdAddrA(RF_Ra_addr),
			   .rdDataA(Ra_data), .rdAddrB(RF_Rb_addr), .rdDataB(Rb_data));
/*
ALU instance: The register file provides the two ALU operands: Ra_data -> A Rb_data -> B. The
RegALU control signal Alu_s0 selects the ALU operation by connecting to the ALU's S input. The ALU
output is Q.
*/
	ALU ALU0(.A(Ra_data), .B(Rb_data), .S(Alu_s0), .Q(Q_Data));
endmodule

/*
RegALU Testbench Purpose:
This testbench verifies that the RegFile and ALU are correctly connected inside the RegALU module.
The testbench only assigns Alu_s0, then checks that Q changes according to the selected ALU operation.
*/
module RegALU_tb();

/*
Testbench signals:
Alu_s0 is the only signal assigned by the testbench to drive the datapath.
Q is observed and checked against the expected ALU result.
*/
	logic [2:0] Alu_s0;
	logic [15:0] Q;

/*
Testbench counters:
pass_count increments when Q matches the expected result.
fail_count increments when Q does not match the expected result.
*/
	integer pass_count;
	integer fail_count;

/*
Device Under Test:
RegALU is treated as the standalone box under test. The testbench does not directly drive RegFile
control signals, register addresses, clock, or internal register values.
*/
	RegALU DUT (
		.Alu_s0(Alu_s0),
		.Q(Q)
	);

/*
check_Q task:
This task assigns one ALU select value to Alu_s0, waits briefly for the combinational datapath to
update, then compares Q against the expected result.
*/
	task automatic check_Q;
		input [2:0] op;
		input [15:0] expected_Q;
		input [8*64-1:0] test_name;

		begin
			Alu_s0 = op;
			#1;

			assert (Q === expected_Q) begin
				pass_count = pass_count + 1;
			end else begin
				fail_count = fail_count + 1;
				$display("FAIL %0s at time %0t: expected Q = %h, actual Q = %h",
					test_name, $time, expected_Q, Q);
			end
		end
	endtask

	initial begin
/*
Initialize counters.

The register file values are initialized inside RegFile, not here.
The testbench only changes Alu_s0.
*/
		pass_count = 0;
		fail_count = 0;

/*
RegFile internal setup:
regfile[0] = 1234, used as A
regfile[1] = 00FF, used as B

Expected ALU results:
A + 0 = 1234
A + B = 1333
A - B = 1135
A     = 1234
A ^ B = 12CB
A | B = 12FF
A & B = 0034
A + 1 = 1235
*/
		$display("Test 1: verify A + 0.");
		check_Q(3'b000, 16'h1234, "A + 0");

		$display("Test 2: verify A + B.");
		check_Q(3'b001, 16'h1333, "A + B");

		$display("Test 3: verify A - B.");
		check_Q(3'b010, 16'h1135, "A - B");

		$display("Test 4: verify A passthrough.");
		check_Q(3'b011, 16'h1234, "A passthrough");

		$display("Test 5: verify A XOR B.");
		check_Q(3'b100, 16'h12CB, "A XOR B");

		$display("Test 6: verify A OR B.");
		check_Q(3'b101, 16'h12FF, "A OR B");

		$display("Test 7: verify A AND B.");
		check_Q(3'b110, 16'h0034, "A AND B");

		$display("Test 8: verify A + 1.");
		check_Q(3'b111, 16'h1235, "A + 1");

		$display("RegALU testbench complete.");
		$display("Passes: %0d", pass_count);
		$display("Failures: %0d", fail_count);

		if (fail_count == 0)
			$display("RESULT: PASS");
		else
			$display("RESULT: FAIL");

		$stop;
	end

endmodule
