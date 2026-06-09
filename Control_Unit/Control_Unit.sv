/*
Seth Amico, John Teal
UW TCES 330
Programmable Processor
Project File: Control_Unit.sv
10 June 2026
*/

module Control_Unit(
    input Clk,
    input rst,
		    
    /*
    ALU flag inputs come from the datapath. These are only needed for the extra-credit 
    conditional jump states. Alu_Z is used by JNZ. Alu_N and Alu_V are used by JLT.
    */
    input Alu_Z,
    input Alu_N,
    input Alu_V,
	
    // Control signals sent to the datapath.
    output [7:0] D_Addr,
    output D_wr,

    output RF_s,

    output [3:0] RF_W_addr,
    output RF_W_en,

    output [3:0] RF_Ra_addr,
    output [3:0] RF_Rb_addr,

    output [2:0] Alu_s0,
    
    /*
    Debug outputs passed up to Processor.sv. The provided processor testbench expects the 
    processor to expose the instruction register, program counter, current state, and next state.
    */
    output [15:0] IR_Out,
    output [7:0] PC_Out,
    output [3:0] StateOut,
    output [3:0] NextStateOut
);
    // Internal control wires between the FSM and PC.
    wire PC_clr;
    wire PC_up;
    wire PC_w_en;
    wire [7:0] PC_set;
	    
    /*
    Internal instruction-register control and data wires. IR_in is the raw instruction coming from 
    instruction ROM. IR_data is the latched instruction stored in the IR.
    */
    wire IR_ld;
    wire [15:0] IR_in;
    wire [15:0] IR_data;

    // PC is the current program counter value. It is also exposed as PC_Out for debugging.
    wire [7:0] PC;

    assign PC_Out = PC;
    assign IR_Out = IR_data;
    
    /*
    The FSM generates all control signals for the PC, IR, and datapath. The FSM reads the latched 
    instruction from IR_data, not the raw ROM output.
    */
    FSM fsm0(
        .Clk(Clk),
        .Rst(rst),

        .PC(PC),
        .PC_clr(PC_clr),
        .PC_up(PC_up),
        .PC_w_en(PC_w_en),
        .PC_set(PC_set),

        .IR_data(IR_data),
        .IR_ld(IR_ld),

        .D_Addr(D_Addr),
        .D_wr(D_wr),

        .RF_s(RF_s),

        .RF_W_addr(RF_W_addr),
        .RF_Ra_addr(RF_Ra_addr),
        .RF_Rb_addr(RF_Rb_addr),
        .RF_W_en(RF_W_en),

        .Alu_s0(Alu_s0),

        .Alu_Z(Alu_Z),
        .Alu_N(Alu_N),
        .Alu_V(Alu_V),

        .StateOut(StateOut),
        .NextStateOut(NextStateOut)
    );
	
    /*
    The PC stores the current instruction address. PC_clr and PC_up come from the FSM. PC_w_en and 
    PC_set are only needed for jump instructions.
    */
    PC pc0(
		.Clk(Clk),
        .PC_clr(PC_clr),
        .PC_up(PC_up),
        .PC_w_en(PC_w_en),
        .PC_set(PC_set),
        .PC_out(PC)
    );
	
    /*
    The IR stores the current instruction. The ROM output IR_in is loaded into IR_data when IR_ld is 
    asserted during the FETCH state.
    */
    IR ir0(
		.Clk(Clk),
        .IR_ld(IR_ld),
        .Instruction_In(IR_in),
        .IR_data(IR_data)
    );
		 
    /*
    Instruction ROM. The instruction memory is 128 x 16, so only the lower 7 bits of the program 
    counter are used as the ROM address.
    */
    myROM rom0(
        .address(PC[6:0]),
		.clock(Clk),
        .q(IR_in)
    );

endmodule

`timescale 1ns/1ps

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
    integer passes;
    integer failures;

    /*
    State values used for final testbench checks. These values must match the FSM state encoding
    in FSM.sv. The final program instruction is HALT, so the control unit should eventually 
    remain in S_HLT.
    */
    localparam [3:0] S_HLT = 4'd9;

    /*
    Device under test. The control unit connects the FSM, program counter, instruction register,
    and instruction ROM. This testbench observes the control signals produced while the 
    instruction program executes.
    */
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

    /*
    Clock generation. The control unit is clocked, so the testbench creates a repeating 10 ns 
    clock period.
    */
    initial Clk = 1'b0;

    always begin
        #5 Clk = ~Clk;
    end

    /*
    Advance the simulation by one positive clock edge. The #1 delay gives clocked values time to
    update before the testbench prints or checks signal values.
    */
    task automatic tick;
        begin
            @(posedge Clk);
            #1;
        end
    endtask

    /*
    Check one value and update the pass/fail counters. Case equality is used so unknown values 
    are treated as failures instead of being ignored.
    */
    task automatic check_value;
    	input string name;
    	input [31:0] actual;
    	input [31:0] expected;

        begin
            if (actual === expected) begin
                passes = passes + 1;
                $display("PASS: %0s expected=%h actual=%h", name, expected, actual);
            end
            else begin
                failures = failures + 1;
                $display("FAIL: %0s expected=%h actual=%h", name, expected, actual);
            end
        end
    endtask

    initial begin
        $display("Starting Control_Unit testbench.");

        passes = 0;
        failures = 0;

        /*
        Initialize ALU flags. The current instruction program does not use the jump instructions,
        but the FSM has ALU flag inputs for JNZ and JLT. These are set to known values so the 
        simulation does not depend on unknown inputs.
        */
        Alu_Z = 1'b0;
        Alu_N = 1'b0;
        Alu_V = 1'b0;

        /*
        Begin in reset. Reset is held for two clock edges. The first clock edge forces the FSM 
     	into INIT. The second clock edge allows the INIT state's PC_clr signal to clear the 
	program counter to address 0 before instruction fetch begins.
        */
        rst = 1'b1;
        tick();
        tick();

        /*
        Release reset so the control unit can begin executing the instruction program stored in 
	myROM.
        */
        rst = 1'b0;

        /*
        Run enough cycles to observe the full instruction sequence. The display output shows the
	program counter, instruction register, FSM state, next state, and key datapath control
        signals. This verifies that the control unit steps through FETCH, DECODE, LOAD, ADD, SUB,
	STORE, and HALT behavior.
        */
        for (i = 0; i < 34; i = i + 1) begin
            tick();

            $display("cycle=%0d PC=%h IR_ld=%b IR_in=%h IR=%h State=%0d Next=%0d D_Addr=%h D_wr=%b RF_s=%b RF_W_addr=%h RF_Ra_addr=%h RF_Rb_addr=%h RF_W_en=%b Alu_s0=%b",
                     i, PC_Out, dut.IR_ld, dut.IR_in, IR_Out, StateOut, NextStateOut,
                     D_Addr, D_wr, RF_s, RF_W_addr, RF_Ra_addr, RF_Rb_addr, RF_W_en, Alu_s0);
        end

        /*
        Final checks. At the end of the program, the control unit should have fetched the HALT 
	instruction and remained in the HALT state. The PC should be sitting at 09 because FETCH
	increments the PC after reading the HALT instruction at ROM address 08.
        */
        check_value("final PC_Out", PC_Out, 8'h09);
        check_value("final IR_Out should be HALT instruction", IR_Out, 16'h5000);
        check_value("final StateOut should be S_HLT", StateOut, S_HLT);
        check_value("final D_wr should be inactive", D_wr, 1'b0);
        check_value("final RF_W_en should be inactive", RF_W_en, 1'b0);

        // Print final test summary.
        $display("Control_Unit testbench complete.");
        $display("Passes: %0d", passes);
        $display("Failures: %0d", failures);

        if (failures == 0) begin
            $display("RESULT: PASS");
        end
        else begin
            $display("RESULT: FAIL");
        end

        $finish;
    end

endmodule
