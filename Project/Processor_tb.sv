/*
Seth Amico, John Teal
UW TCES 330
Programmable Processor
Project File: Processor_tb.sv
10 June 2026
*/

`timescale 1 ps / 1 ps

module Processor_tb();

    logic Clk;
    logic Reset;

    logic [15:0] IR_Out;
    logic [7:0] PC_Out;
    logic [3:0] State;
    logic [3:0] NextState;

    logic [15:0] ALU_A;
    logic [15:0] ALU_B;
    logic [15:0] ALU_Out;

    integer i;
    integer pass_count;
    integer fail_count;

    logic saw_store;
    logic saw_halt;

    localparam [3:0] S_STORE = 4'd4;
    localparam [3:0] S_HALT  = 4'd9;

    Processor dut(
        .Clk(Clk),
        .Reset(Reset),

        .IR_Out(IR_Out),
        .PC_Out(PC_Out),
        .State(State),
        .NextState(NextState),

        .ALU_A(ALU_A),
        .ALU_B(ALU_B),
        .ALU_Out(ALU_Out)
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

    task automatic check1;
        input [255:0] name;
        input actual;
        input expected;

        begin
            if (actual === expected) begin
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
                $display("FAIL: %0s expected=%b actual=%b time=%0t",
                         name, expected, actual, $time);
            end
        end
    endtask

    task automatic check16;
        input [255:0] name;
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

        saw_store = 1'b0;
        saw_halt  = 1'b0;

        Reset = 1'b1;

        $display("Starting Processor testbench.");

        /*
        Hold reset for two clock edges so the control unit starts cleanly.
        */
        tick();
        tick();

        Reset = 1'b0;

        for (i = 0; i < 50; i = i + 1) begin
            tick();

            $display("cycle=%0d PC=%h IR=%h State=%0d Next=%0d ALU_A=%h ALU_B=%h ALU_Out=%h D_Addr=%h D_wr=%b",
                     i, PC_Out, IR_Out, State, NextState, ALU_A, ALU_B, ALU_Out,
                     dut.D_Addr, dut.D_wr);

            /*
            The ROM/RAM test program should eventually execute:
            D[6A] = D[1B] - D[2A] + D[3C] - D[7E]
            D[6A] = 000A - 0003 + 0004 - 0002 = 0009

            During STORE, D_wr should be high, D_Addr should be 6A, and ALU_A should contain 0009.
            */
            if ((State == S_STORE) && (dut.D_wr == 1'b1) && (dut.D_Addr == 8'h6A)) begin
                saw_store = 1'b1;
                check16("STORE value from RF[A]", ALU_A, 16'h0009);
            end

            if (State == S_HALT) begin
                saw_halt = 1'b1;
            end
        end

        check1("Processor reached STORE", saw_store, 1'b1);
        check1("Processor reached HALT", saw_halt, 1'b1);
        check16("Final IR should be HALT", IR_Out, 16'h5000);

        $display("Processor testbench complete.");
        $display("Passes: %0d", pass_count);
        $display("Failures: %0d", fail_count);

        if (fail_count == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");

        $stop;
    end

endmodule
