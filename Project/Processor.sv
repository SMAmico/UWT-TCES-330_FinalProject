/*
Seth Amico, John Teal
UW TCES 330
Programmable Processor
Project File: Processor.sv
10 June 2026
*/

module Processor(
    input Clk,
    input ResetN,

    output [15:0] IR_Out,
    output [6:0] PC_Out,
    output [3:0] State,
    output [3:0] NextState,

    output [15:0] ALU_A,
    output [15:0] ALU_B,
    output [15:0] ALU_Out
);

    /*
    The PC module and Control Unit use an 8-bit PC internally. The provided testProcessor.sv expects
    PC_Out to be 7 bits because the ROM is 128 words and uses address[6:0].
    */
    wire [7:0] PC_Out_full;

    assign PC_Out = PC_Out_full[6:0];

    /*
    Control signals from the Control Unit to the Datapath.

    These internal wire names intentionally use the capitalization expected by testProcessor.sv.
    The testbench monitors DUT.RF_Ra_Addr directly.
    */
    wire [7:0] D_Addr;
    wire D_wr;

    wire RF_s;

    wire [3:0] RF_W_Addr;
    wire RF_W_en;

    wire [3:0] RF_Ra_Addr;
    wire [3:0] RF_Rb_Addr;

    wire [2:0] Alu_s0;

    /*
    Temporary ALU flag wires.

    These are tied low for the base processor because the current Datapath does not expose Alu_Z,
    Alu_N, or Alu_V yet. They are only needed for extra-credit conditional jump support.
    */
    wire Alu_Z;
    wire Alu_N;
    wire Alu_V;

    assign Alu_Z = 1'b0;
    assign Alu_N = 1'b0;
    assign Alu_V = 1'b0;

    /*
    Control Unit instance.
    */
    Control_Unit control0(
        .Clk(Clk),
        .ResetN(ResetN),

        .Alu_Z(Alu_Z),
        .Alu_N(Alu_N),
        .Alu_V(Alu_V),

        .D_Addr(D_Addr),
        .D_wr(D_wr),

        .RF_s(RF_s),

        .RF_W_addr(RF_W_Addr),
        .RF_W_en(RF_W_en),

        .RF_Ra_addr(RF_Ra_Addr),
        .RF_Rb_addr(RF_Rb_Addr),

        .Alu_s0(Alu_s0),

        .IR_Out(IR_Out),
        .PC_Out(PC_Out_full),
        .StateOut(State),
        .NextStateOut(NextState)
    );

    /*
    Datapath instance.
    */
    Datapath datapath0(
        .Clk(Clk),

        .D_Addr(D_Addr),
        .D_wr(D_wr),

        .RF_s(RF_s),
        .RF_W_en(RF_W_en),

        .RF_Ra_addr(RF_Ra_Addr),
        .RF_Rb_addr(RF_Rb_Addr),
        .RF_W_addr(RF_W_Addr),

        .Alu_s0(Alu_s0),

        .ALU_A(ALU_A),
        .ALU_B(ALU_B),
        .ALU_Out(ALU_Out)
    );
endmodule
