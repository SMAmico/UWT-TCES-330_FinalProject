/*
Seth Amico, John Teal
UW TCES 330
Programmable Processor
Project File: FSM.sv
10 June 2026
*/


module FSM(
    input Clk,                         // system clock
    input Rst,                         // synchronous reset for the FSM state register

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
                     INS_JMP = 4'h9,
                     INS_JNZ = 4'hA,
                     INS_JLT = 4'hB;
	
    /*
    ALU select values. These must match the ALU module. For JNZ, ALU_PASS is used to pass the selected
	register value through the ALU so the zero flag can be checked. For JLT, ALU_SUB is used so the 
	controller can check N ^ V.
    */
    localparam [2:0] ALU_ADDZERO = 3'b000,
                     ALU_ADD     = 3'b001,
                     ALU_SUB     = 3'b010,
                     ALU_PASS    = 3'b011;
 			
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
	
      S_INIT: begin
        PC_clr = 1'b1;
        NextState = S_FETCH; //always move to fetch state
      end  
      
      S_FETCH: begin
		IR_ld = 1'b1;			//increment instruction register
		PC_up = 1'b1;			//along with the PC
		NextState = S_DEC;//always move to decode state
	  end
		            
		S_DEC: begin
			case (IR_data[15:12])
                    INS_NOP: NextState = S_NOP;
                    INS_STR: NextState = S_STR;
                    INS_LDR: NextState = S_LDR;
                    INS_ADD: NextState = S_ADD;
                    INS_SUB: NextState = S_SUB;
                    INS_HLT: NextState = S_HLT;
                    default: NextState = S_HLT;
                endcase
            end
	  
	  S_NOP: begin
			NextState = S_FETCH; //NOP instruction simply moves to the next state
	  end
	  S_STR: begin
			RF_Ra_addr = IR[11:8]; //read from the Ra register
			D_wr = 1'b1;			   //enable writing to RAM
			D_addr = IR[7:0];	   //write to the RAM at IR's address
			ALU_s0 = ALU_PASS;	   //set the alu to passthrough
			NextState = S_FETCH;
	  end
	  
	  S_LDR: begin
		    D_addr = IR[11:4]    //load from RAM address
			RF_w_addr = IR[7:0]; //write to RF address # IR
			RF_s = 1'b1;			 //set mux to source from RAM
			RF_w_es = 1'b1;		 //enable RF writing
			NextState = S_FETCH;
	  end
	  
	  S_ADD: begin
			RF_Ra_addr = IR[11:8];//set register addresses
			RF_Rb_addr = IR[7:4]; //for A and B ALU inputs
			RF_w_addr = IR[3:0];  //set writeback register address
			ALU_s0 = ALU_ADD;     //set ALU to add
			RF_s = 1'b0;			  //set register to source from ALU output
			RF_w_en = 1'b1;		  //set RF write enable high
			NextState = S_FETCH;
	  end
	  
	  S_SUB: begin 
			RF_Ra_addr = IR[11:8];//set register addresses
			RF_Rb_addr = IR[7:4]; //for A and B ALU inputs
			RF_w_addr = IR[3:0];  //set writeback register address
			ALU_s0 = ALU_SUB;     //set ALU to subtract
			RF_s = 1'b0;			  //set register to source from ALU output
			RF_w_en = 1'b1;		  //set RF write enable high
			NextState = S_FETCH;
	  end
	  S_HLT: begin
			NextState = S_HLT;    //loop back to halt state (lock)
	  end
	  
      default: begin
 
        NextState = S_HLT;          // safe state
      end
    endcase //end case - state transition description
  end // end the always Comb Logic
    
  always_ff @(posedge Clk) begin
    if (Rst)
      State <= S_INIT;
    else
      State <= NextState;   // go to the state we described above
  end // end the always ff logic

  
endmodule


//********************************************//
//                 Testbench	                //
//********************************************//
/*
module 
  
  	
	always begin  // 50 MHz Clock
	  Clock = 1'b0; #10;
	  Clock = 1'b1; #10;
	end
  
  initial begin
    // generate your input sequence
    $stop;
  end
  
  initial
    $monitor( .... );
  
endmodule
*/
