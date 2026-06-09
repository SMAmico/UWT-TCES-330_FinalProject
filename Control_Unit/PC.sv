/*
Seth Amico, John Teal
UW TCES 330
Programmable Processor
Project File: PC.sv
10 June 2026
*/

`timescale 1ns/1ps
module PC(
    input Clk,
    input PC_clr,
    input PC_up,
    input PC_w_en,
    input [7:0] PC_set,
    output logic [7:0] PC_out
);

    /*
    The PC module stores the current instruction address. PC_clr, PC_up, and PC_w_en are control 
    signals from the FSM. They are not clocks. The PC only changes on the rising edge of Clk.
    PC_clr  = 1 clears the PC to 0. PC_w_en = 1 loads PC_set into the PC for jump instructions.
    PC_up   = 1 increments the PC by 1. Priority order: 1. Clear the PC. 2. Load a jump address.
    3. Increment the PC. 4. Otherwise hold the current PC value.
    */

    always_ff @(posedge Clk) begin
        if (PC_clr)
            PC_out <= 8'b0;
        else if (PC_w_en)
            PC_out <= PC_set;
        else if (PC_up)
            PC_out <= PC_out + 8'b1;
    end

endmodule

module PC_tb();

    logic Clk;
    logic PC_clr;
    logic PC_up;
    logic PC_w_en;
    logic [7:0] PC_set;
    logic [7:0] PC_out;

    integer pass_count;
    integer fail_count;

    PC dut(
        .Clk(Clk),
        .PC_clr(PC_clr),
        .PC_up(PC_up),
        .PC_w_en(PC_w_en),
        .PC_set(PC_set),
        .PC_out(PC_out)
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
    	input [7:0] actual;
    	input [7:0] expected;

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

        PC_clr  = 1'b0;
        PC_up   = 1'b0;
        PC_w_en = 1'b0;
        PC_set  = 8'h00;

        $display("Starting PC testbench.");

        // Clear test.
        PC_clr = 1'b1;
        tick();
        check_value("PC clear", PC_out, 8'h00);

        // Hold test.
        PC_clr = 1'b0;
        PC_up = 1'b0;
        PC_w_en = 1'b0;
        tick();
        check_value("PC hold after clear", PC_out, 8'h00);

        // Increment test.
        PC_up = 1'b1;
        tick();
        check_value("PC increment to 1", PC_out, 8'h01);

        tick();
        check_value("PC increment to 2", PC_out, 8'h02);

        // Jump/load test.
        PC_up = 1'b0;
        PC_w_en = 1'b1;
        PC_set = 8'h3C;
        tick();
        check_value("PC load jump address", PC_out, 8'h3C);

        // Priority test: clear should beat jump load.
        PC_clr = 1'b1;
        PC_w_en = 1'b1;
        PC_set = 8'hAA;
        tick();
        check_value("PC clear priority over load", PC_out, 8'h00);

        // Priority test: jump load should beat increment.
        PC_clr = 1'b0;
        PC_w_en = 1'b1;
        PC_up = 1'b1;
        PC_set = 8'h55;
        tick();
        check_value("PC load priority over increment", PC_out, 8'h55);

        // Return to increment.
        PC_w_en = 1'b0;
        PC_up = 1'b1;
        tick();
        check_value("PC increment after load", PC_out, 8'h56);

        $display("PC testbench complete.");
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
