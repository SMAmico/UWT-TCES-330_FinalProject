/*
Seth Amico, John Teal
UW TCES 330
Programmable Processor
Project File: Processor.sv
10 June 2026
*/

module Processor(
    input Clk,
    input Reset,

    output [15:0] IR_Out,
    output [7:0] PC_Out,
    output [3:0] State,
    output [3:0] NextState,

    output [15:0] ALU_A,
    output [15:0] ALU_B,
    output [15:0] ALU_Out
);

    /*
    Control signals from the Control Unit to the Datapath.
    */
    wire [7:0] D_Addr;
    wire D_wr;

    wire RF_s;

    wire [3:0] RF_W_addr;
    wire RF_W_en;

    wire [3:0] RF_Ra_addr;
    wire [3:0] RF_Rb_addr;

    wire [2:0] Alu_s0;

    /*
    Temporary ALU flag wires.

    These are tied low for the base processor test because the current Datapath module does not expose
    Alu_Z, Alu_N, or Alu_V yet. They are only needed for the extra-credit conditional jump states.
    */
    wire Alu_Z;
    wire Alu_N;
    wire Alu_V;

    assign Alu_Z = 1'b0;
    assign Alu_N = 1'b0;
    assign Alu_V = 1'b0;

    /*
    Control Unit instance.

    The Control Unit fetches instructions, decodes opcodes, controls the PC and IR, and sends control
    signals to the Datapath.
    */
    Control_Unit control0(
        .Clk(Clk),
        .rst(Reset),

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
        .StateOut(State),
        .NextStateOut(NextState)
    );

    /*
    Datapath instance.

    The Datapath contains the register file, ALU, RAM, and register-file write-back mux.
    */
    Datapath datapath0(
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
        .ALU_Out(ALU_Out)
    );

endmodule
