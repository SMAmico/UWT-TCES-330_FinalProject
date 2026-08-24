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

    input [15:0] PC,                    // current PC value, used for PC-relative JLT

    output logic PC_clr,               // clears the program counter during INIT
    output logic PC_up,                // increments the program counter during FETCH
    output logic PC_w_en,              // enables loading PC_set into the PC for jump instructions
    output logic [15:0] PC_set,         // value loaded into the PC during jump instructions

    input [15:0] IR_data,              // current instruction stored in the instruction register
    output logic IR_ld,                // loads the instruction register during FETCH

    output logic [3:0] D_Addr_reg,     // data address register
    output logic [3:0] D_Data_reg,     // data register (contains data to write or destination for load)
    output logic D_wr,                 // data memory write enable

    output logic RF_s,                 // register file write-data mux select

    output logic [3:0] RF_W_addr,      // register file write address
    output logic [3:0] RF_Ra_addr,     // register file A-side read address
    output logic [3:0] RF_Rb_addr,     // register file B-side read address
    input [15:0] RF_Rb_data,           // live value read from RF_Rb_addr in datapath
    output logic RF_W_en,              // register file write enable

    output logic [2:0] Alu_s0,         // ALU function select
    output logic [7:0] MOVI_d,         // ALU immediate data

    output logic Flags_W_en,            // captures ALU flags for CMP
    output logic SET_result_en,         // selects the full-word SET writeback value
    output logic SET_result,            // Boolean value written by SETcc

    input Alu_Z,                       // ALU zero flag, used by JNZ
    input Alu_N,                       // ALU negative flag, used by JLT
    input Alu_V,                       // ALU overflow flag, used by JLT

    input Status_Z,                    // flag captured by the most recent CMP
    input Status_N,
    input Status_V,

    output logic [3:0] StateOut,       // current FSM state for debug/display
    output logic [3:0] NextStateOut    // next FSM state for debug/display
);
	
	/*
    Instruction opcode values. Current map: 0000 = SHR, 0001 = STORE, 0010 = LOAD,
    0011 = ADD, 0100 = SUB, 0101 = HALT, 0110 = MOVI, 0111 = OR, 1000 = AND,
    1001 = JMP, 1010 = JNZ, 1011 = JLT, 1100 = SHL, 1101 = MULT.
    NOP is a pseudo-instruction encoded as AND R0,R0,R0 (16'h8000).
    */
    localparam [3:0] INS_STR = 4'h1,
                     INS_LDR = 4'h2,
                     INS_ADD = 4'h3,
                     INS_SUB = 4'h4,
                     INS_HLT = 4'h5,

                     INS_MOVI = 4'h6,//added instructions
                     INS_OR =  4'h7,
                     INS_AND = 4'h8,

                     INS_JMP = 4'h9,
                     INS_JNZ = 4'hA,
                     INS_JLT = 4'hB,

                     INS_SHL = 4'hC,
                     INS_MULT= 4'hD,
                     INS_CMP_SET = 4'hE,
                     INS_SHR = 4'h0;
                     
    /*
    ALU select values. These must match the ALU module. For JNZ, ALU_PASS is used to pass the selected
	register value through the ALU so the zero flag can be checked. For JLT, ALU_SUB is used so the 
	controller can check N ^ V.
    */
    /*
    ALU operation select:
        S = 000: Q = A >> shift immediate
        S = 001: Q = A + B
        S = 010: Q = A - B
        S = 011: Q = A * B
        S = 100: Q = IMM[7:0] 
        S = 101: Q = A | B
        S = 110: Q = A & B
        S = 111: Q = A << shift immediate

    Alu_Z is high when Q is zero.
    Alu_N is the sign bit of Q.
    Alu_V is signed overflow for ADD, SUB, and INC.
    */
    localparam [2:0] ALU_SHR     = 3'b000,
                     ALU_ADD     = 3'b001,
                     ALU_SUB     = 3'b010,
                     ALU_MULT    = 3'b011,
                     ALU_MOVI    = 3'b100, // new addition replacing XOR
                     ALU_OR      = 3'b101,
                     ALU_AND     = 3'b110,
                     ALU_SHL     = 3'b111;
 			
    /*
    FSM state values. LOAD is split into two states because RAM read and RF write need at least two 
	clock cycles. JNZ is split into two states: S_JNZ_TEST selects the register and lets the ALU/flags
	evaluate it. S_JNZ_JUMP checks Alu_Z and updates the PC if the register is not zero. JLT is split 
	into two states: S_JLT_TEST selects both registers and performs A - B. S_JLT_JUMP checks N ^ V and
	updates the PC if A < B.
	
	S_ALU takes the place of multiple operations, specifically those that follow the flow: FETCH, DEC,
	(some ALU op), write back.
	
    */
    localparam [3:0] S_INIT     = 4'd0,
                     S_FETCH    = 4'd1,
                     S_DEC      = 4'd2,
                     S_NOP      = 4'd3,
                     S_STR      = 4'd4,
                     S_LDA      = 4'd5,
                     S_LDB      = 4'd6,
                     S_ALU      = 4'd7,//S_ALU contains all alu operations
                     S_CMP      = 4'd8,
                     S_HLT      = 4'd9,
                     S_JMP      = 4'd10,
                     S_JNZ_TEST = 4'd11,
                     S_JNZ_JUMP = 4'd12,
                     S_JLT_TEST = 4'd13,
                     S_JLT_JUMP = 4'd14,
                     S_SET      = 4'd15;

    logic [3:0] State, NextState;
    
	/*
    Sign-extended 12-bit and 4-bit offsets for jump instructions.
    JMP uses a signed 12-bit PC-relative offset and wraps to 8-bit PC space.
    JNZ and JLT use signed 4-bit offsets.
    */
    logic signed [15:0] JMP_offset;
    logic [15:0] JMP_target;
    logic signed [7:0] JNZ_offset;
    logic [7:0] JLT_offset;
    logic JNZ_not_zero;

	/*
	JMP_offset takes the immediate offset data from the IR and sign-extends it out to the PC width.
	
	JMP_target sums the PC as a signed value and the signed jump offset, then converts both back to unsigned values.
	
	JNZ_offset and JLT offset both sign extend the immediate offset information in the IR out to the PC length.
	*/
    assign JMP_offset = {{1{IR_data[11]}}, IR_data[11:0]};
    assign JMP_target = $unsigned($signed(PC) + JMP_offset);
    assign JNZ_offset = {{4{IR_data[3]}}, IR_data[3:0]};
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
        PC_set     = 16'b0;

        IR_ld      = 1'b0;

        D_Addr_reg = 4'b0;
        D_Data_reg = 4'b0;
        D_wr       = 1'b0;

        RF_s       = 1'b0;

        RF_W_addr  = 4'b0;
        RF_Ra_addr = 4'b0;
        RF_Rb_addr = 4'b0;
        RF_W_en    = 1'b0;

        Alu_s0     = ALU_SHR;
        MOVI_d     = 8'b0;
        Flags_W_en  = 1'b0;
        SET_result_en = 1'b0;
        SET_result  = 1'b0;

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
                // NOP is encoded as AND R0,R0,R0 (0x8000), so detect the full word first.
                if (IR_data == 16'h8000) begin
                    NextState = S_NOP;
                end else begin
                case (IR_data[15:12])
                    INS_STR: NextState = S_STR;
                    INS_LDR: NextState = S_LDA;

                    INS_ADD: NextState = S_ALU;//all simple ALU ops route to one ALU operation state
					     INS_SUB: NextState = S_ALU;
					     INS_AND: NextState = S_ALU;
					     INS_OR : NextState = S_ALU;
					     INS_MOVI:NextState = S_ALU;
						  INS_SHL: NextState = S_ALU;
                    INS_SHR: NextState = S_ALU;
                    INS_MULT:NextState = S_ALU;

                    INS_HLT: NextState = S_HLT;
                    INS_JMP: NextState = S_JMP;
                    INS_JNZ: NextState = S_JNZ_TEST;
                    INS_JLT: NextState = S_JLT_TEST;
                    //to save instruction space, CMP and SET are combined into one instruction with a 4-bit sub-opcode field.
                    INS_CMP_SET: begin
                        if (IR_data[3:0] == 4'h0)
                            NextState = S_CMP;
                        else if (IR_data[3:0] == 4'hF && IR_data[7:4] <= 4'h5)
                            NextState = S_SET;
                        else
                            NextState = S_HLT;
                    end
                    default: NextState = S_HLT;
                endcase
                end
            end
			
            // NOOP performs no datapath operation.
            S_NOP: begin
                NextState = S_FETCH;
            end

            // STORE instruction: 0001 aaaa bbbb 0000 RF[aaaa] -> D[RF[bbbb]]
            S_STR: begin
                D_Data_reg = IR_data[11:8];  // data register
                D_Addr_reg = IR_data[7:4];   // address register
                D_wr       = 1'b1;

                NextState  = S_FETCH;
            end

            /*
            LOAD_A instruction state: 0010 aaaa bbbb 0000 This first LOAD state reads the RAM address
            from the address register (bbbb) specified in the instruction. The destination register (aaaa)
            is set for write-back on the next cycle after RAM data is valid.
            */
            S_LDA: begin
                D_Data_reg = IR_data[11:8];  // destination register for loaded data
                D_Addr_reg = IR_data[7:4];   // address register
                RF_s      = 1'b1;            // write source select for memory writing into register file
                RF_W_addr = IR_data[11:8];   // writeback register for memory data

                NextState = S_LDB;
            end

            /*
            LOAD_B instruction state: This second LOAD state enables the register file write after the
			RAM output has had time to become valid.
            */
            S_LDB: begin
                D_Data_reg = IR_data[11:8];  // destination register for loaded data
                D_Addr_reg = IR_data[7:4];   // address register
                RF_s      = 1'b1;
                RF_W_addr = IR_data[11:8];
                RF_W_en   = 1'b1;            // register file writes cleared data into register

                NextState = S_FETCH;
            end

            // ALU instruction: 0011 raaa rbbb rccc RF[rccc] = RF[raaa] (ALUop) RF[rbbb]
            S_ALU: begin
                RF_Ra_addr = IR_data[11:8];
                RF_Rb_addr = IR_data[7:4];
                RF_W_addr  = IR_data[3:0];
                RF_W_en    = 1'b1;

                //set ALU control lines to the appropriate operation
                case(IR_data[15:12]) 
                    INS_ADD: Alu_s0 = ALU_ADD;
                    INS_SUB: Alu_s0 = ALU_SUB;
                    INS_AND: Alu_s0 = ALU_AND;
                    INS_OR : Alu_s0 = ALU_OR;
                    INS_MOVI: begin
                        Alu_s0 = ALU_MOVI;
                        MOVI_d = IR_data[7:0];
								RF_Ra_addr = IR_data[11:8];
								RF_W_addr  = IR_data[11:8];
                    end
                    INS_SHL: begin
                        Alu_s0 = ALU_SHL;
                        RF_Rb_addr = 4'b0;
                        MOVI_d = {4'b0, IR_data[7:4]};
                    end
                    INS_SHR: begin
                        Alu_s0 = ALU_SHR;
                        RF_Rb_addr = 4'b0;
                        MOVI_d = {4'b0, IR_data[7:4]};
                    end
                    INS_MULT:Alu_s0 = ALU_MULT;
                    default: Alu_s0 = ALU_ADD;
                endcase
                RF_s       = 1'b0;

                NextState  = S_FETCH;
            end

            // CMP instruction: 1110 raaa rbbb 0000. Capture signed-subtraction flags only.
            S_CMP: begin
                RF_Ra_addr = IR_data[11:8];
                RF_Rb_addr = IR_data[7:4];
                Alu_s0     = ALU_SUB;
                Flags_W_en = 1'b1;

                NextState  = S_FETCH;
            end

            // SETcc instruction: 1110 rddd cccc 1111. Write a full-word Boolean from CMP flags.
            S_SET: begin
                RF_W_addr     = IR_data[11:8];
                RF_W_en       = 1'b1;
                SET_result_en = 1'b1;

                case (IR_data[7:4])
                    4'h0: SET_result = Status_N ^ Status_V;
                    4'h1: SET_result = Status_Z;
                    4'h2: SET_result = ~Status_Z;
                    4'h3: SET_result = Status_Z | (Status_N ^ Status_V);
                    4'h4: SET_result = ~Status_Z & ~(Status_N ^ Status_V);
                    4'h5: SET_result = ~(Status_N ^ Status_V);
                    default: begin
                        RF_W_en       = 1'b0;
                        SET_result_en = 1'b0;
                    end
                endcase

                NextState = S_FETCH;
            end

            // JMP instruction: 1001 bbbb bbbb bbbb. PC-relative jump by signed 12-bit offset.
            S_JMP: begin
                PC_set     = JMP_target;
                PC_w_en    = 1'b1;

                NextState  = S_FETCH;
            end

            /*
            JNZ_TEST instruction state: 1010 raaa rbbb bbbb.
            Read RF[raaa] on both ALU inputs and use AND so the ALU output equals RF[raaa].
            This drives Alu_Z based on the test register value.
            */
            S_JNZ_TEST: begin
                RF_Ra_addr = IR_data[11:8];
                RF_Rb_addr = IR_data[11:8];
                Alu_s0     = ALU_AND;

                NextState  = S_JNZ_JUMP;
            end

            /*
            JNZ_JUMP instruction state: If RF[raaa] was non-zero during S_JNZ_TEST, jump to
            RF[rbbb] + signed 4-bit offset.
            */
            S_JNZ_JUMP: begin
                RF_Rb_addr = IR_data[7:4];

                if (JNZ_not_zero) begin
                    PC_set  = PC + JNZ_offset;
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
                RF_Ra_addr = IR_data[11:8];
                RF_Rb_addr = IR_data[7:4];
                Alu_s0     = ALU_SUB;

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

            /*
            MULT performs multiple operations within one cycle, looping back until the operation is complete.
            */


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
        if (~ResetN) begin
            State <= S_INIT;
            JNZ_not_zero <= 1'b0;
        end
        else begin
            State <= NextState;
            if (State == S_JNZ_TEST)
                JNZ_not_zero <= ~Alu_Z;
        end
    end

endmodule
