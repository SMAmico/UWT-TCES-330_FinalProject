/*
Seth Amico, John Teal
UW TCES 330
Programmable Processor
Project File: FSM.sv
10 June 2026
*/


module FSM(
    input Clk,                         // system clock
    input ResetN,                      // synchronous reset low for the FSM state register

    input [7:0] PC,                    // current PC value, used for PC-relative JLT

    output logic PC_clr,               // clears the program counter during INIT
    output logic PC_up,                // increments the program counter during FETCH
    output logic PC_w_en,              // enables loading PC_set into the PC for jump instructions
    output logic [7:0] PC_set,         // value loaded into the PC during jump instructions

    input [15:0] IR_data,              // current instruction stored in the instruction register
    output logic IR_ld,                // loads the instruction register during FETCH

    output logic [7:0] D_Addr,         // data memory address
    output logic D_wr,                 // data memory write enable

    output logic RF_s,                 // register file write-data mux select

    output logic [3:0] RF_W_addr,      // register file write address
    output logic [3:0] RF_Ra_addr,     // register file A-side read address
    output logic [3:0] RF_Rb_addr,     // register file B-side read address
    output logic RF_W_en,              // register file write enable

    output logic [2:0] Alu_s0,         // ALU function select

    input Alu_Z,                       // ALU zero flag, used by JNZ
    input Alu_N,                       // ALU negative flag, used by JLT
    input Alu_V,                       // ALU overflow flag, used by JLT

    output logic [3:0] StateOut,       // current FSM state for debug/display
    output logic [3:0] NextStateOut    // next FSM state for debug/display
);
	
	/*
    Instruction opcode values. Base project: 0000 = NOOP 0001 = STORE 0010 = LOAD 0011 = ADD
    0100 = SUB 0101 = HALT Extra credit: 1001 = JMP 1010 = JNZ 1011 = JLT 
    */
    localparam [3:0] INS_NOP = 4'h0,
                     INS_STR = 4'h1,
                     INS_LDR = 4'h2,
                     INS_ADD = 4'h3,
                     INS_SUB = 4'h4,
                     INS_HLT = 4'h5,

                     INS_XOR = 4'h6,//added instructions
                     INS_OR =  4'h7,
                     INS_AND = 4'h8,

                     INS_JMP = 4'h9,
                     INS_JNZ = 4'hA,
                     INS_JLT = 4'hB,

                     INS_SHL = 4'hC,//added instructions
                     INS_MULT= 4'hD;
                     
    /*
    ALU select values. These must match the ALU module. For JNZ, ALU_PASS is used to pass the selected
	register value through the ALU so the zero flag can be checked. For JLT, ALU_SUB is used so the 
	controller can check N ^ V.
    */
    /*
    ALU operation select:
        S = 000: Q = A + 0
        S = 001: Q = A + B
        S = 010: Q = A - B
        S = 011: Q = A * B
        S = 100: Q = A ^ B
        S = 101: Q = A | B
        S = 110: Q = A & B
        S = 111: Q = A << B

    Alu_Z is high when Q is zero.
    Alu_N is the sign bit of Q.
    Alu_V is signed overflow for ADD, SUB, and INC.
    */
    localparam [2:0] ALU_ADDZERO = 3'b000,
                     ALU_ADD     = 3'b001,
                     ALU_SUB     = 3'b010,
                     ALU_MULT    = 3'b011,
                     ALU_XOR     = 3'b100,
                     ALU_OR      = 3'b101,
                     ALU_AND     = 3'b110,
                     ALU_SHL     = 3'b111;
 			
    /*
    FSM state values. LOAD is split into two states because RAM read and RF write need at least two 
	clock cycles. JNZ is split into two states: S_JNZ_TEST selects the register and lets the ALU/flags
	evaluate it. S_JNZ_JUMP checks Alu_Z and updates the PC if the register is not zero. JLT is split 
	into two states: S_JLT_TEST selects both registers and performs A - B. S_JLT_JUMP checks N ^ V and
	updates the PC if A < B.
    */
    localparam [3:0] S_INIT     = 4'd0,
                     S_FETCH    = 4'd1,
                     S_DEC      = 4'd2,
                     S_NOP      = 4'd3,
                     S_STR      = 4'd4,
                     S_LDA      = 4'd5,
                     S_LDB      = 4'd6,
                     S_ADD      = 4'd7,
                     S_SUB      = 4'd8,
                     S_HLT      = 4'd9,
                     S_JMP      = 4'd10,
                     S_JNZ_TEST = 4'd11,
                     S_JNZ_JUMP = 4'd12,
                     S_JLT_TEST = 4'd13,
                     S_JLT_JUMP = 4'd14;

    logic [3:0] State, NextState;
    
	/*
    Sign-extended 4-bit offset for JLT. JLT uses PC-relative addressing according to the extra-credit 
	slide: JLT instruction format: ???? raaa rbbb bbbb The bbbb field is treated as a signed offset.
    */
    logic [7:0] JLT_offset;

    assign JLT_offset = {{4{IR_data[3]}}, IR_data[3:0]};

    assign StateOut = State;
    assign NextStateOut = NextState;
	
    /*
    Combinational logic for Moore FSM outputs and next-state selection. Every output is given a 
	default value first. This prevents latch inference and allows each state to list only the signals 
	that need to be non-default.
    */
    always_comb begin
        PC_clr     = 1'b0;
        PC_up      = 1'b0;
        PC_w_en    = 1'b0;
        PC_set     = 8'b0;

        IR_ld      = 1'b0;

        D_Addr     = 8'b0;
        D_wr       = 1'b0;

        RF_s       = 1'b0;

        RF_W_addr  = 4'b0;
        RF_Ra_addr = 4'b0;
        RF_Rb_addr = 4'b0;
        RF_W_en    = 1'b0;

        Alu_s0     = ALU_ADDZERO;

        NextState  = State;

        case (State)
            // INIT clears the program counter so instruction execution starts at ROM address 0.
            S_INIT: begin
                PC_clr    = 1'b1;
                NextState = S_FETCH;
            end

            /*
            FETCH loads the current ROM instruction into the IR and increments the PC so it points to 
			the next instruction.
            */
            S_FETCH: begin
                IR_ld     = 1'b1;
                PC_up     = 1'b1;
                NextState = S_DEC;
            end
			
            // DECODE checks the opcode field of the current instruction.
            S_DEC: begin
                case (IR_data[15:12])
                    INS_NOP: NextState = S_NOP;
                    INS_STR: NextState = S_STR;
                    INS_LDR: NextState = S_LDA;
                    INS_ADD: NextState = S_ADD;
                    INS_SUB: NextState = S_SUB;
                    INS_HLT: NextState = S_HLT;
                    INS_JMP: NextState = S_JMP;
                    INS_JNZ: NextState = S_JNZ_TEST;
                    INS_JLT: NextState = S_JLT_TEST;
                    default: NextState = S_HLT;
                endcase
            end
			
            // NOOP performs no datapath operation.
            S_NOP: begin
                NextState = S_FETCH;
            end

            // STORE instruction: 0001 rrrr dddddddd RF[rrrr] -> D[dddddddd]
            S_STR: begin
                RF_Ra_addr = IR_data[11:8];
                D_Addr     = IR_data[7:0];
                D_wr       = 1'b1;

                NextState  = S_FETCH;
            end

            /*
            LOAD_A instruction state: 0010 dddddddd rrrr This first LOAD state places the RAM address 
			on D_Addr and sets the register file write address.
            */
            S_LDA: begin
                D_Addr    = IR_data[11:4];
                RF_s      = 1'b1;
                RF_W_addr = IR_data[3:0];

                NextState = S_LDB;
            end

            /*
            LOAD_B instruction state: This second LOAD state enables the register file write after the
			RAM output has had time to become valid.
            */
            S_LDB: begin
                D_Addr    = IR_data[11:4];
                RF_s      = 1'b1;
                RF_W_addr = IR_data[3:0];
                RF_W_en   = 1'b1;

                NextState = S_FETCH;
            end

            // ADD instruction: 0011 raaa rbbb rccc RF[rccc] = RF[raaa] + RF[rbbb]
            S_ADD: begin
                RF_Ra_addr = IR_data[11:8];
                RF_Rb_addr = IR_data[7:4];
                RF_W_addr  = IR_data[3:0];
                RF_W_en    = 1'b1;
                Alu_s0     = ALU_ADD;
                RF_s       = 1'b0;

                NextState  = S_FETCH;
            end

            // SUB instruction: 0100 raaa rbbb rccc RF[rccc] = RF[raaa] - RF[rbbb]
            S_SUB: begin
                RF_Ra_addr = IR_data[11:8];
                RF_Rb_addr = IR_data[7:4];
                RF_W_addr  = IR_data[3:0];
                RF_W_en    = 1'b1;
                Alu_s0     = ALU_SUB;
                RF_s       = 1'b0;

                NextState  = S_FETCH;
            end

            // JMP instruction: 1001 0000 bbbbbbbb Absolute jump. The PC is loaded with IR_data[7:0].
            S_JMP: begin
                PC_set     = IR_data[7:0];
                PC_w_en    = 1'b1;

                NextState  = S_FETCH;
            end

            /*
            JNZ_TEST instruction state: 1010 bbbbbbbb rrrr Select RF[rrrr] and pass it through the 
			ALUso the zero flag can indicate whether the register is zero.
            */
            S_JNZ_TEST: begin
                RF_Ra_addr = IR_data[3:0];
                Alu_s0     = ALU_PASS;

                NextState  = S_JNZ_JUMP;
            end

            /*
            JNZ_JUMP instruction state: If the selected register was not zero, load the PC with the
			absolute address stored in IR_data[11:4].
            */
            S_JNZ_JUMP: begin
                if (!Alu_Z) begin
                    PC_set  = IR_data[11:4];
                    PC_w_en = 1'b1;
                end

                NextState = S_FETCH;
            end

            /*
            JLT_TEST instruction state: 1011 raaa rbbb bbbb Select RF[raaa] and RF[rbbb], then 
			subtract A - B. The ALU flags are used in the next state to determine whether A < B.
            */
            S_JLT_TEST: begin
                RF_Ra_addr = IR_data[11:8];
                RF_Rb_addr = IR_data[7:4];
                Alu_s0     = ALU_SUB;

                NextState  = S_JLT_JUMP;
            end

            /*
            JLT_JUMP instruction state: Signed less-than is checked with N ^ V. If A < B, load the PC 
			with PC + signed offset. The current PC should already point to the next instruction 
			because FETCH incremented it before decode.
            */
            S_JLT_JUMP: begin
                if (Alu_N ^ Alu_V) begin
                    PC_set  = PC + JLT_offset;
                    PC_w_en = 1'b1;
                end

                NextState = S_FETCH;
            end

            // HALT locks the processor in the halt state.
            S_HLT: begin
                NextState = S_HLT;
            end

            // Any unexpected state moves to HALT as a safe failure state.
            default: begin
                NextState = S_HLT;
            end

        endcase
	end
    
    /*
    Sequential state register. The FSM state only changes on the rising edge of Clk. ResetN returns the 
	FSM to INIT.
    */
    always_ff @(posedge Clk) begin
        if (~ResetN)
            State <= S_INIT;
        else
            State <= NextState;
    end

endmodule
