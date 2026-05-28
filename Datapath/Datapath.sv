/*
Seth Amico, John Teal
UW TCES 330
Project Phase III
15 May 2026

Description:
This file contains the register file, ALU, RAM instantiation, data source mux, and combined Datapath module for
Project phase III. this file REQUIRES the verilog file myRAM.v to be included
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
	input clk,
	input [15:0]W_data,
	output [15:0]R_data
	);
	//myRAM (address, clock, data, wren, q);
	myRAM RAM(.address(D_Addr), .clock(clk), .data(W_data), .wren(D_wr), .q(R_data));
	
endmodule




module Datapath(
	input clk,					// system clock for the register file
	
	input [7:0] D_Addr;			// RAM data address 
	input D_wr;					// RAM data write enable
	input RF_s;					// register file mux source select
	
	input RF_W_en,				// register file write enable

	input [3:0] RF_Ra_addr,		// register file read A address
	input [3:0] RF_Rb_addr,		// register file read B address
	input [3:0] RF_W_addr,		// register file write address

	input [2:0] Alu_s0,			// ALU operation select

	output [15:0] Q			// Datapath result output
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
	wire [15:0] W_data;
	wire [15:0] R_Data;
	
	
	
	
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
	RegFile RF(
			.clk(clk),
			.write(RF_W_en),
			.wrAddr(RF_W_addr),
			.wrData(Q_Data),
			.rdAddrA(RF_Ra_addr),
			.rdDataA(Ra_data),
			.rdAddrB(RF_Rb_addr),
			.rdDataB(Rb_data)
			);
			
/*
ALU instance: The register file provides the two ALU operands: Ra_data -> A Rb_data -> B. The
RegALU control signal Alu_s0 selects the ALU operation by connecting to the ALU's S input. The ALU
output is Q.
*/
	ALU ALU0(
			.A(Ra_data),
			.B(Rb_data),
			.S(Alu_s0),
			.Q(Q_Data)
			);
	
/*
Mux instance
*/
	mux16w_2to1 RF_SOURCE(
			.RAM(R_data),
			.ALU(Q),
			.RF_s(RF_s),
			.Q(W_data)
			);
	
/*
RAM skeleton instance
*/
	RAM RAM(
			.D_Addr(D_Addr),
			.D_wr(D_wr),
			.W_data(Ra_data),
			.R_data(R_data)
			);
endmodule



//TODO: replace the regALU Testbench with a datapath testbench.


/*
RegALU Testbench purpose:  This testbench verifies that the RegFile and ALU are correctly connected
inside the RegALU module.  It checks that register outputs feed the ALU inputs, that Alu_s0 selects
the correct ALU operations, and that the ALU output Q can be written back into the register file.
*/
module RegALU_tb();
/*
Testbench signals: These signals act like the controller inputs shown in the datapath diagram. The
testbench drives these values to select the register addresses, chose an ALU operation, and control
when the ALU result is written back into the register file.
*/
	logic clk;
	logic RF_W_en;

	logic [3:0] RF_Ra_addr;
	logic [3:0] RF_Rb_addr;
	logic [3:0] RF_W_addr;

	logic [3:0] Alu_s0;

	logic [15:0] Q;
/*
Testbench counters: pass_count increments when an expected result matches the actual output.
fail_count increments when the DUT output does not match the expected value.
*/
	integer pass_count;
	integer fail_count;
	integer i;
/*
Device Under Test: This instantiates the RegALU module. The testbench connects directly to the 
top-level RegALU control signals, not to the RegFile or ALU submodules directly during normal
testing.
*/
	RegALU DUT(.clk(clk), .RF_W_en(RF_W_en), .RF_Ra_addr(RF_Ra_addr), .RF_Rb_addr(RF_Rb_addr), 
			   .RF_W_addr(RF_W_addr), .Alu_s0(Alu_s0), .Q(Q));
/*
Clock initialization: The register file writes on the rising edge of clk. The ALU itself is 
combinational, so it does not use the clock.	
*/
	initial begin
		clk = 1'b0;
	end
/*
Clock generator: The clock toggles every 5 time units, giving a full clock period of 10 times units.
Testbench write inputs should be set before a rising edge, because that is when the register file
stores data.
*/
	always begin
		#5 clk = ~clk;
	end
/*
seed_registers task: The RegALU module writes ALU ouput Q back into the register file, but it does
not have an external data input for loading starting values. For simulation, this task directly loads
known values into the internal register file before the connection tests begin. This is testbench 
setup only. It is not meant to represent hardware behavior.
*/
	task automatic seed_registers;
		begin
			for(i = 0; i < 16; i = i + 1)begin
				DUT.RF.regfile[i] = 16'h0000;
			end
			DUT.RF.regfile[0] = 16'h0005;
			DUT.RF.regfile[1] = 16'h0003;
			DUT.RF.regfile[2] = 16'h00F0;
			DUT.RF.regfile[3] = 16'h000F;
			DUT.RF.regfile[4] = 16'hAAAA;
			DUT.RF.regfile[5] = 16'h5555;
		end
	endtask
/*
check_Q task: This task checks the RegALU output Q against an expected value. Since the ALU is 
combinational, Q should update shortly after the selected register addresses or Alu_s0 changes.
*/
	task automatic check_Q;
		input [15:0] expected_Q;
		input [8*64-1:0] test_name;

		begin
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

/*
write_Q_to_register task: This task writes the current ALU output Q into the selected register. The 
task sets RF_W_addr, enables RF_W_en, waits for the positive clock edge, and then disables RF_W_en. 
The write occurs on the positive clock edge	because the register file uses synchronous writes.
*/
	task automatic write_Q_to_register;
		input [3:0] dest_addr;

		begin
			@(negedge clk);
			RF_W_addr = dest_addr;
			RF_W_en = 1'b1;

			@(posedge clk);
			#1;

			@(negedge clk);
			RF_W_en = 1'b0;
		end
	endtask

	initial begin
// Initialize counters and control signals before running the tests.
		pass_count = 0;
		fail_count = 0;

		RF_W_en = 1'b0;
/*
Start the read addresses away from the first test values.  After seed_registers runs, Test 1 will
change these addresses to 0 and 1, which forces the combinational read outputs to update cleanly.
*/
		RF_Ra_addr = 4'd15;
		RF_Rb_addr = 4'd15;
		RF_W_addr = 4'd0;
		Alu_s0 = 3'b000;

		#10;
// Load known starting values into the register file so the integration tests have known operands.
		seed_registers();

/*
Test 1: Verify that RF_Ra_addr selects the value feeding ALU input A.
Register 0 contains 0005. ALU operation 000 is Q = A + 0. Expected Q is 0005.
*/
		$display("Test 1: verify RF_Ra_addr feeds ALU input A.");
		RF_Ra_addr = 4'd0;
		RF_Rb_addr = 4'd1;
		Alu_s0 = 3'b000;
		check_Q(16'h0005, "A input / A + 0");

/*
Test 2:	Verify that RF_Rb_addr selects the value feeding ALU input B.
Register 0 contains 0005. Register 1 contains 0003. ALU operation 001 is Q = A + B.
Expected Q is 0008.
*/
		$display("Test 2: verify RF_Rb_addr feeds ALU input B.");
		RF_Ra_addr = 4'd0;
		RF_Rb_addr = 4'd1;
		Alu_s0 = 3'b001;
		check_Q(16'h0008, "A + B");

/*
Test 3: Verify subtraction through the integrated RegALU datapath.
Register 0 contains 0005. Register 1 contains 0003. ALU operation 010 is Q = A - B.
Expected Q is 0002.
*/
		$display("Test 3: verify subtraction through RegALU.");
		Alu_s0 = 3'b010;
		check_Q(16'h0002, "A - B");

/*
Test 4: Verify a bitwise operation through the integrated datapath.
Register 2 contains 00F0. Register 3 contains 000F. ALU operation 101 is Q = A | B.
Expected Q is 00FF.
*/
		$display("Test 4: verify OR operation through RegALU.");
		RF_Ra_addr = 4'd2;
		RF_Rb_addr = 4'd3;
		Alu_s0 = 3'b101;
		check_Q(16'h00FF, "A OR B");

/*
Test 5: Verify that ALU output Q writes back into the register file.
Register 0 contains 0005. Register 1 contains 0003. Q should become 0008 from A + B.
Then Q is written into register 6. Afterward, selecting register 6 as A with operation A + 0 should 
make Q show 0008.
*/
		$display("Test 5: verify ALU result writes back into the register file.");
		RF_Ra_addr = 4'd0;
		RF_Rb_addr = 4'd1;
		Alu_s0 = 3'b001;
		check_Q(16'h0008, "Q before write-back");

		write_Q_to_register(4'd6);

		RF_Ra_addr = 4'd6;
		RF_Rb_addr = 4'd0;
		Alu_s0 = 3'b000;
		check_Q(16'h0008, "Q after write-back to register 6");

/*
Test 6: Verify a second write-back using the increment operation.
Register 6 now contains 0008. ALU operation 111 is Q = A + 1. Expected Q is 0009. Then Q is written 
into register 7 and read back using A + 0.
*/
		$display("Test 6: verify second write-back using A + 1.");
		RF_Ra_addr = 4'd6;
		RF_Rb_addr = 4'd0;
		Alu_s0 = 3'b111;
		check_Q(16'h0009, "A + 1 before write-back");

		write_Q_to_register(4'd7);

		RF_Ra_addr = 4'd7;
		RF_Rb_addr = 4'd0;
		Alu_s0 = 3'b000;
		check_Q(16'h0009, "Q after write-back to register 7");


/*
Test 7: test the ALU passthrough operation.
Register 4 contains AAAA. ALU operation 011 is Q = A. Expected Q is AAAA.
*/
		$display("Test 7: verify ALU passthrough operation.");
		RF_Ra_addr = 4'd4;
		RF_Rb_addr = 4'd0;
		Alu_s0 = 3'b011;
		check_Q(16'hAAAA, "ALU passthrough A");

/*
Test 8: test the ALU XOR operation.
Register 4 contains AAAA. Register 5 contains 5555. ALU operation 100 is Q = A ^ B. Expected Q is FFFF.
*/
		$display("Test 8: verify ALU XOR operation.");
		RF_Ra_addr = 4'd4;
		RF_Rb_addr = 4'd5;
		Alu_s0 = 3'b100;
		check_Q(16'hFFFF, "A XOR B");
		
/*
Test 9: test the ALU AND operation.
Register 4 contains AAAA. Register 5 contains 5555. ALU operation 110 is Q = A & B. Expected Q is 0000.
*/
		$display("Test 9: verify ALU AND operation.");
		RF_Ra_addr = 4'd4;
		RF_Rb_addr = 4'd5;
		Alu_s0 = 3'b110;
		check_Q(16'h0000, "A AND B");


//Final test summary.
		$display("RegALU testbench complete.");
		$display("Passes: %0d", pass_count);
		$display("Failures: %0d", fail_count);

		if (fail_count == 0)
			$display("RESULT: PASS");
		else
			$display("RESULT: FAIL");

		$finish;
	end
endmodule
