/*
Seth Amico, John Teal
UW TCES 330
Programmable Processor
Project File: Project.sv
10 June 2026
*/

module Project(
    input CLOCK_50,
    input [3:0] KEY,
    input [9:0] SW,

    output [6:0] HEX0,
    output [6:0] HEX1,
    output [6:0] HEX2,
    output [6:0] HEX3,
    output [6:0] HEX4,
    output [6:0] HEX5
);

    /*
    KEY buttons on the DE board are active-low.

    Processor expects ResetN:
        ResetN = 0 means reset
        ResetN = 1 means run

    KEY[0] is used as ResetN directly:
        Press KEY[0] to reset.
        Release KEY[0] to run.
    */
    wire Clk;
    wire ResetN;

    assign Clk = CLOCK_50;
    assign ResetN = KEY[0];

    /*
    Processor debug outputs.
    */
    wire [15:0] IR_Out;
    wire [6:0] PC_Out;
    wire [3:0] State;
    wire [3:0] NextState;

    wire [15:0] ALU_A;
    wire [15:0] ALU_B;
    wire [15:0] ALU_Out;

    /*
    Display value for HEX7..HEX4.

    HEX3..HEX0 always display IR_Out.
    HEX7..HEX4 display a debug value selected by SW[17:15].
    */
    logic [15:0] Display_Out;

    Processor processor0(
        .Clk(Clk),
        .ResetN(ResetN),

        .IR_Out(IR_Out),
        .PC_Out(PC_Out),
        .State(State),
        .NextState(NextState),

        .ALU_A(ALU_A),
        .ALU_B(ALU_B),
        .ALU_Out(ALU_Out)
    );

    /*
    Display select mux.

    SW[17:15] selects what is shown on HEX7..HEX4.
    */
    always_comb begin
        case (SW[9:7])
            3'b000: Display_Out = {9'b0, PC_Out};
            3'b001: Display_Out = {12'b0, State};
            3'b010: Display_Out = ALU_A;
            3'b011: Display_Out = ALU_B;
            3'b100: Display_Out = ALU_Out;
            3'b101: Display_Out = {12'b0, NextState};
            default: Display_Out = 16'h0000;
        endcase
    end

    /*
    HEX3..HEX0 display the instruction register.
    */
    Decoder ir_hex0(
        .Hex_In(IR_Out[3:0]),
        .Hex_Out(HEX0)
    );

    Decoder ir_hex1(
        .Hex_In(IR_Out[7:4]),
        .Hex_Out(HEX1)
    );

    Decoder ir_hex2(
        .Hex_In(IR_Out[11:8]),
        .Hex_Out(HEX2)
    );

    Decoder ir_hex3(
        .Hex_In(IR_Out[15:12]),
        .Hex_Out(HEX3)
    );

    /*
    HEX5..HEX4 display the selected debug value.
    */
    Decoder dbg_hex4(
        .Hex_In(Display_Out[3:0]),
        .Hex_Out(HEX4)
    );

    Decoder dbg_hex5(
        .Hex_In(Display_Out[7:4]),
        .Hex_Out(HEX5)
    );
endmodule
