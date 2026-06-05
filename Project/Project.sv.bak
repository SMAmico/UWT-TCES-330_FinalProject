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
    KEY buttons on the DE10 board are active-low.

    Processor expects ResetN:
        ResetN = 0 means reset
        ResetN = 1 means run

    KEY[1] is used as ResetN directly:
        Press KEY[1] to reset.
        Release KEY[1] to run.

    KEY[2] is used as the manual processor clock step:
        Press KEY[2] to advance the processor one clock cycle.
    */
    wire Clk;
    wire ResetN;
    wire StepButton;

    /* KEY[2] is active-low on the DE10 board.
   The KeyFilter expects an active-high input, so KEY[2] is inverted. */
    assign StepButton = ~KEY[2];

    /* KEY[1] is active-low reset.
   Pressed  = 0 = reset active.
   Released = 1 = run. */
    assign ResetN = KEY[1];

    KeyFilter keyfilter0 (
        .Clk(CLOCK_50),
        .In(StepButton),
        .Out(Clk)
    );

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
    Display value for HEX5..HEX4.

    HEX3..HEX0 always display IR_Out.
    HEX5..HEX4 display the lower 8 bits of the debug value selected by SW[9:7].
    */
    logic [15:0] Display_Out;
	

    Processor processor0 (
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
    Main_Display is the full 16-bit value shown on HEX3..HEX0.

    Because the DE10 board has six HEX displays instead of eight, it cannot show both a full 16-bit
    IR value and a full 16-bit debug value at the same time. SW[9:7] selects which full 16-bit value
    is shown on HEX3..HEX0.

    HEX4 shows the current FSM state.
    HEX5 shows the display select mode.

	SW[9:7] = 000 -> HEX3..HEX0 shows IR_Out
	SW[9:7] = 001 -> HEX3..HEX0 shows PC_Out
	SW[9:7] = 010 -> HEX3..HEX0 shows {NextState, State}
	SW[9:7] = 011 -> HEX3..HEX0 shows ALU_A
	SW[9:7] = 100 -> HEX3..HEX0 shows ALU_B
	SW[9:7] = 101 -> HEX3..HEX0 shows ALU_Out
	SW[9:7] = 110 -> reserved / blank
	SW[9:7] = 111 -> reserved / blank
    */
    logic [15:0] Main_Display;

    always_comb begin
        case (SW[9:7])
            3'b000: Main_Display = IR_Out;
            3'b001: Main_Display = {9'b0, PC_Out};
            3'b010: Main_Display = {8'b0, NextState, State};
            3'b011: Main_Display = ALU_A;
            3'b100: Main_Display = ALU_B;
            3'b101: Main_Display = ALU_Out;
            default: Main_Display = 16'h0000;
        endcase
    end

    /*
    HEX3..HEX0 display the selected full 16-bit value.
    */
    Decoder main_hex0(
        .Hex_In(Main_Display[3:0]),
        .Hex_Out(HEX0)
    );

    Decoder main_hex1(
        .Hex_In(Main_Display[7:4]),
        .Hex_Out(HEX1)
    );

    Decoder main_hex2(
        .Hex_In(Main_Display[11:8]),
        .Hex_Out(HEX2)
    );

    Decoder main_hex3(
        .Hex_In(Main_Display[15:12]),
        .Hex_Out(HEX3)
    );

    /*
    HEX4 shows the current FSM state.
    HEX5 shows the current display-select mode from SW[9:7].
    */
    Decoder state_hex4(
        .Hex_In(State),
        .Hex_Out(HEX4)
    );

    Decoder mode_hex5(
        .Hex_In({1'b0, SW[9:7]}),
        .Hex_Out(HEX5)
    );
endmodule
