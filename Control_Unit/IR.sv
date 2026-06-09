/*
Seth Amico, John Teal
UW TCES 330
Programmable Processor
Project File: IR.sv
10 June 2026
*/

`timescale 1ns/1ps
module IR(
    input Clk,
    input IR_ld,
    input [15:0] Instruction_In,
    output logic [15:0] IR_data
);

    /*
    The Instruction Register stores the current 16-bit instruction. IR_ld is a load-enable signal from 
    the FSM. It is not a clock. When IR_ld = 1, the IR loads the current instruction from ROM on the 
    rising edge of Clk. When IR_ld = 0, the IR holds its previous instruction.
    */

    always_ff @(posedge Clk) begin
        if (IR_ld)
            IR_data <= Instruction_In;
    end

endmodule

module IR_tb();

    logic Clk;
    logic IR_ld;
    logic [15:0] Instruction_In;
    logic [15:0] IR_data;

    integer pass_count;
    integer fail_count;

    IR dut(
        .Clk(Clk),
        .IR_ld(IR_ld),
        .Instruction_In(Instruction_In),
        .IR_data(IR_data)
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

    task automatic check_value;
	    input string name;
	    input [15:0] actual;
	    input [15:0] expected;

        begin
            if (actual === expected) begin
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
                $display("FAIL: %0s expected=%h actual=%h time=%0t",
                         name, expected, actual, $time);
            end
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;

        IR_ld = 1'b0;
        Instruction_In = 16'h0000;

        $display("Starting IR testbench.");

        // Test 1: Load instruction 1234 into the IR.
        Instruction_In = 16'h1234;
        IR_ld = 1'b1;
        tick();

        check_value("IR loads 1234 when IR_ld is high", IR_data, 16'h1234);

        // Test 2: Change the input while IR_ld is low. IR_data should hold 1234.
        IR_ld = 1'b0;
        Instruction_In = 16'hABCD;
        tick();

        check_value("IR holds 1234 when IR_ld is low", IR_data, 16'h1234);

        // Test 3: Load a new instruction.
        IR_ld = 1'b1;
        Instruction_In = 16'h5000;
        tick();

        check_value("IR loads 5000 when IR_ld is high", IR_data, 16'h5000);

        // Test 4: Hold again after another input change.
        IR_ld = 1'b0;
        Instruction_In = 16'hFFFF;
        tick();

        check_value("IR holds 5000 when IR_ld is low", IR_data, 16'h5000);

        $display("IR testbench complete.");
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
