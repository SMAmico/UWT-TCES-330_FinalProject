/*
Seth Amico, John Teal
UW TCES 330
Programmable Processor
Project File: Control_Unit.sv
10 June 2026
*/

module Control_Unit(
		input Clk,
		input ResetN,
		    
    /*
    ALU flag inputs come from the datapath. These are only needed for the extra-credit conditional 
	jump states. Alu_Z is used by JNZ. Alu_N and Alu_V are used by JLT.
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
    Debug outputs passed up to Processor.sv. The provided processor testbench expects the processor to
	expose the instruction register, program counter, current state, and next state.
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
        .ResetN(ResetN),

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
