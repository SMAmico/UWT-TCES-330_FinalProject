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
`timescale 1ns/1ps

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
    input [15:0] A,
    input [15:0] B,
    input [2:0] S,
    output logic [15:0] Q,
    output logic Alu_Z,
    output logic Alu_N,
    output logic Alu_V
);
/*
ALU operation logic. The ALU is combinational, meaning it does not use a clock. Whenever A, B, 
or S changes, the result Q and the ALU flags are recalculated. The select input S chooses which 
operation appears on Q.
S = 000: Q = A + 0
S = 001: Q = A + B
S = 010: Q = A - B
S = 011: Q = A
S = 100: Q = A ^ B
S = 101: Q = A | B
S = 110: Q = A & B
S = 111: Q = A + 1
Alu_Z is set when Q is zero. This is used by JNZ. Alu_N is set when Q is negative in signed 
16-bit form. Alu_V is set when signed overflow occurs during ADD or SUB. JLT uses Alu_N ^ Alu_V
to determine signed less-than.
*/
    always_comb begin
    Q     = 16'h0000;
    Alu_V = 1'b0;

    case (S)
	3'b000: begin
	        Q = A + 16'd0;
		end

    	3'b001: begin
	        Q = A + B;
	        Alu_V = (~A[15] & ~B[15] & Q[15]) | (A[15] & B[15] & ~Q[15]);
		end

	3'b010: begin
	        Q = A - B;
	        Alu_V = (~A[15] & B[15] & Q[15]) | (A[15] & ~B[15] & ~Q[15]);
		end

	3'b011: begin
		Q = A;
		end

	3'b100: begin
	        Q = A ^ B;
		end
	
	3'b101: begin
	        Q = A | B;
		end
	
	3'b110: begin
	        Q = A & B;
		end
	
	3'b111: begin
	        Q = A + 16'd1;
		end
	
	default: begin
	        Q = 16'h0000;
		end
    endcase

    	Alu_Z = (Q == 16'h0000);
    	Alu_N = Q[15];


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

/*
RAM wrapper. This module connects the datapath to the Quartus-generated myRAM memory module. 
The wrapper keeps the datapath connection names simple while allowing the actual memory 
implementation to come from the generated IP file.
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
									   
    output [15:0] ALU_A,
    output [15:0] ALU_B,
    output [15:0] ALU_Out,

    output Alu_Z,
    output Alu_N,
    output Alu_V
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
	.Q(Q_Data),
	.Alu_Z(Alu_Z),
	.Alu_N(Alu_N),
	.Alu_V(Alu_V)
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


module Datapath_tb();

    logic Clk;

    logic [7:0] D_Addr;
    logic D_wr;
    logic RF_s;
    logic RF_W_en;

    logic [3:0] RF_Ra_addr;
    logic [3:0] RF_Rb_addr;
    logic [3:0] RF_W_addr;

    logic [2:0] Alu_s0;

    logic [15:0] ALU_A;
    logic [15:0] ALU_B;
    logic [15:0] ALU_Out;

    logic Alu_Z;
    logic Alu_N;
    logic Alu_V;

    integer pass_count;
    integer fail_count;

    localparam [2:0] ALU_ADDZERO = 3'b000;
    localparam [2:0] ALU_ADD     = 3'b001;
    localparam [2:0] ALU_SUB     = 3'b010;
    localparam [2:0] ALU_PASS    = 3'b011;

    /*
    Device under test. The datapath connects the register file, ALU, RAM wrapper, and 
    register-file source mux. This testbench drives the same control signals that the Control 
    Unit would normally generate.
    */
    Datapath dut(
        .Clk(Clk),

        .D_Addr(D_Addr),
        .D_wr(D_wr),

        .RF_s(RF_s),
        .RF_W_en(RF_W_en),

        .RF_Ra_addr(RF_Ra_addr),
        .RF_Rb_addr(RF_Rb_addr),
        .RF_W_addr(RF_W_addr),

        .Alu_s0(Alu_s0),

	.ALU_A(ALU_A),
	.ALU_B(ALU_B),
	.ALU_Out(ALU_Out),

	.Alu_Z(Alu_Z),
	.Alu_N(Alu_N),
	.Alu_V(Alu_V)
    );

    /*
    Clock generation. The register file and RAM are clocked, so this creates a repeating 10 ns 
    clock period.
    */
    initial Clk = 1'b0;

    always begin
        #5 Clk = ~Clk;
    end

    /*
    Advance the simulation by one positive clock edge. The #1 delay gives clocked outputs time 
    to update before the testbench checks the result.
    */
    task automatic tick;
        begin
            @(posedge Clk);
            #1;
        end
    endtask

    /*
    Check one 16-bit value. Case equality is used so unknown values are counted as failures. 
    This makes the testbench catch X values instead of accidentally passing them.
    */
    task automatic check16;
        input [255:0] name;
        input [15:0] actual;
        input [15:0] expected;

        begin
            if (actual === expected) begin
                pass_count = pass_count + 1;
                $display("PASS: %0s expected=%h actual=%h", name, expected, actual);
            end
            else begin
                fail_count = fail_count + 1;
                $display("FAIL: %0s expected=%h actual=%h time=%0t",
                         name, expected, actual, $time);
            end
        end
    endtask

    /*
    Simulate a LOAD instruction at the datapath level. The Control Unit normally performs LOAD 
    in two stages: LOAD_A places the RAM address on D_Addr and selects RAM as the register-file 
    write source. LOAD_B enables the register-file write after RAM data has had time to become 
    valid. This task reproduces that sequence manually.
    */
    task automatic load_ram_to_reg;
        input [7:0] ram_addr;
        input [3:0] reg_addr;
        input [15:0] expected_value;

        begin
            D_Addr     = ram_addr;
            D_wr       = 1'b0;

            RF_s       = 1'b1;
            RF_W_addr  = reg_addr;
            RF_W_en    = 1'b0;

            RF_Ra_addr = reg_addr;
            RF_Rb_addr = 4'h0;
            Alu_s0     = ALU_ADDZERO;

            // Wait one clock edge for the RAM output to become valid for the selected address.
            #2;
            tick();

            // Write the RAM output into the selected register.
            RF_W_en = 1'b1;

            #2;
            tick();

            // Disable register writing and read the destination register through ALU_A.
            RF_W_en = 1'b0;
            #2;

            RF_Ra_addr = reg_addr;
            #2;

            check16("LOAD RAM to RF", ALU_A, expected_value);
        end
    endtask

    /*
    Simulate an ALU operation with register-file writeback. The task selects two register-file 
    read addresses, applies the requested ALU operation, verifies the combinational ALU result,
    writes that result into the destination register, and then reads the destination register 
    back.
    */
    task automatic alu_write_reg;
        input [2:0] alu_op;
        input [3:0] reg_a;
        input [3:0] reg_b;
        input [3:0] reg_w;
        input [15:0] expected_value;

        begin
            D_wr       = 1'b0;

            RF_s       = 1'b0;
            RF_Ra_addr = reg_a;
            RF_Rb_addr = reg_b;
            RF_W_addr  = reg_w;
            RF_W_en    = 1'b1;

            Alu_s0     = alu_op;

            #2;
            check16("ALU combinational result", ALU_Out, expected_value);

            tick();

            RF_W_en = 1'b0;
            #2;

            RF_Ra_addr = reg_w;
            #2;

            check16("ALU writeback to RF", ALU_A, expected_value);
        end
    endtask

    /*
    Simulate a STORE instruction at the datapath level. The selected register is placed on the 
    A-side read port. The RAM write enable is asserted for one clock edge so the register value
    is written into the selected RAM address.
    */
    task automatic store_reg_to_ram;
        input [3:0] reg_addr;
        input [7:0] ram_addr;
        input [15:0] expected_value;

        begin
            RF_Ra_addr = reg_addr;
            RF_Rb_addr = 4'h0;

            D_Addr     = ram_addr;
            D_wr       = 1'b1;

            RF_W_en    = 1'b0;
            RF_s       = 1'b0;
            Alu_s0     = ALU_PASS;

            #2;
            tick();

            D_wr = 1'b0;
            #10;

            check16("STORE RF to RAM", dut.R_data, expected_value);
        end
    endtask

    initial begin
        $display("Starting Datapath testbench.");

        pass_count = 0;
        fail_count = 0;

        // Initialize all control inputs to safe inactive values before running the datapath sequence.
        D_Addr     = 8'h00;
        D_wr       = 1'b0;
        RF_s       = 1'b0;
        RF_W_en    = 1'b0;
        RF_Ra_addr = 4'h0;
        RF_Rb_addr = 4'h0;
        RF_W_addr  = 4'h0;
        Alu_s0     = ALU_ADDZERO;

        /*
        Load initial RAM values into registers. These values come from mifRAM.mif and match the 
 	Phase 3 program data used by the full processor simulation.
        */
        load_ram_to_reg(8'h1B, 4'hA, 16'h21BA);
        load_ram_to_reg(8'h2A, 4'hB, 16'hA04E);

        // First ALU operation: 21BA - A04E = 816C Store the result back into register A.
        alu_write_reg(ALU_SUB, 4'hA, 4'hB, 4'hA, 16'h816C);

        // Load the next RAM value into register B.
        load_ram_to_reg(8'h3C, 4'hB, 16'h71AC);

        // Second ALU operation: 816C + 71AC = F318 Store the result back into register A.
        alu_write_reg(ALU_ADD, 4'hA, 4'hB, 4'hA, 16'hF318);

        // Load the final RAM value into register B.
        load_ram_to_reg(8'h7E, 4'hB, 16'hB17F);

        // Third ALU operation: F318 - B17F = 4199 Store the result back into register A.
        alu_write_reg(ALU_SUB, 4'hA, 4'hB, 4'hA, 16'h4199);

        // Store the final datapath result into RAM address 6A.
        store_reg_to_ram(4'hA, 8'h6A, 16'h4199);

        // Print final test summary.
        $display("Datapath testbench complete.");
        $display("Passes: %0d", pass_count);
        $display("Failures: %0d", fail_count);

        if (fail_count == 0) begin
            $display("RESULT: PASS");
        end
        else begin
            $display("RESULT: FAIL");
        end

        $finish;
    end

endmodule
