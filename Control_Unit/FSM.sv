// TCES 330 Spring 2026
// SystemVerilog template to describe
// Moore State Machine 
// if we want to monitor the states of 
// an FSM, we can add to the portlist
// an output named StateOut
// thus the code should contain a line 
// "assign StateOut = State"


module Control_Unit_FSM(
			// system clock
			input Clk, 			//system clock
			
			//Reset line
			input Rst,			 //state machine reset line
			
			//PC control lines
			input logic [7:0]PC,
			output PC_clr,		 //PC clear command line
			output PC_up,		 //PC upcounter control line
			output PC_w_en,
			output [7:0]PC_set, //this is a overwrite line for the PC, will be implemented for JMP
			
			//IR input lines
			input logic [15:0]IR_data, //the raw instruction data from ROM
			output IR_ld,		 //instruction data load command
			
			//RAM control lines
			output [7:0] D_Addr, //output address to RAM
			output D_wr,		 //write enable line to data

			//Register File source control mux select line
			output RF_s,		 //RF source control line

			// Register File control lines
			output [3:0]RF_W_addr,	//RF write address 
			output [3:0]RF_Ra_addr, //RF read address A
			output [3:0]RF_Rb_addr, //RF read address B
			output RF_W_en,			//RF write address enable
			
			//ALU control lines
			output [2:0]Alu_s0,
			//input Alu_Z //this is an inbuilt ALU flag line that will need to be implemented
			//input Alu_V //this is an inbuilt ALU overflow flag line
			//input Alu_N //this is an inbuilt ALU negative flag line
			
			//current state output lines
			output [3:0]StateOut
			);
	
	//opcode localparams
  localparam INS_NOP = 4'h0,
			 INS_STR = 4'h1,
			 INS_LDR = 4'h2,
			 INS_ADD = 4'h3,
			 INS_SUB = 4'h4,
			 INS_HLT = 4'h5,
			 
			 INS_XOR = 4'h6,
			 INS_OR = 4'h7,
			 INS_AND = 4'h8,
			 
			 INS_JMP = 4'h9,
			 INS_JNZ = 4'ha,
			 INS_JLT = 4'hb;
	
	//ALU state localparams
  localparam ALU_ADDZERO = 3'b000,
			ALU_ADD = 3'b001,
			ALU_SUB = 3'b010,
			ALU_PASS = 3'011,
			ALU_XOR = 3'b100,
			ALU_OR = 3'b101,
			ALU_AND = 3'b110,
			ALU_INC =  3'b111;
 			
	// added defined states to each localparam
  localparam S_INIT = 4'd0,
			 S_FETCH = 4'd1,
			 S_DEC = 4'd2,
			 S_NOP = 4'd3,
			 S_STR = 4'd4,
			 S_LDR = 4'd5,
			 S_ADD = 4'd6,
			 S_SUB = 4'd7,
			 S_HLT = 4'd8,
			 
			 S_XOR, //extra states from ALU should we choose to implement them
			 S_OR,
			 S_AND,
			 
			 S_JMP, //Extra credit. these need to be included in the ALU
			 S_JNZ,
			 S_JLT;
			 
  
  logic [3:0] State, NextState;  // state variables
  
  assign StateOut = State; 

  //CombLogic (use blocking assigns)
  //describe state transition
  //of a Moore machine
  always_comb begin
	//setting the state to 0 beforehand ensures quartus can always resolve
    //the state's value even outside the case statement, making a state machine more visible
	State = 4'h0;
	
    case (State)
      S_INIT: begin
        PC_clr = 1;
        if (1)  begin		//always move to fetch state
          NextState = S_FETCH; 
        end
      end  
      
      S_FETCH: begin
		IR_ld = 1;			//increment instruction register
		PC_up = 1;
		
		if (1) begin		//always move to decode state
		  NextState = S_DEC;
		end
	  end
	  
	  S_DEC: begin
		if(IR[15:12] == 4'b0101) begin
			NextState = S_HLT;
		end else NextState = S_EXE;
	  end
	  
	  S_EXE: begin
			case(IR[15:12])begin
				INS_NOP : NextState = S_NOP;
				INS_STR : NextState = S_STR;
				INS_LDR : NextState = S_LDR;
				INS_ADD : NextState = S_ADD;
				INS_SUB : NextState = S_SUB;
				INS_HLT : NextState = S_HLT;
				default : NextState = S_HLT;
			endcase
	  end
	  
	  S_NOP: begin
			NextState = S_FETCH; //NOP instruction simply moves to the next state
	  end
	  S_STR: begin
			RF_Ra_addr = IR[11:8]; //read from the Ra register
			D_wr = 1;			   //enable writing to RAM
			D_addr = IR[7:0];	   //write to the RAM at IR's address
			ALU_s0 = ALU_PASS;	   //set the alu to passthrough
			NextState = S_FETCH;
	  end
	  
	  S_LDR: begin
		    D_addr = IR[11:4]    //load from RAM address
			RF_w_addr = IR[7:0]; //write to RF address # IR
			RF_s = 1;			 //set mux to source from RAM
			RF_w_es = 1;		 //enable RF writing
			NextState = S_FETCH;
	  end
	  
	  S_ADD: begin
			RF_Ra_addr = IR[11:8];//set register addresses
			RF_Rb_addr = IR[7:4]; //for A and B ALU inputs
			RF_w_addr = IR[3:0];  //set writeback register address
			ALU_s0 = ALU_ADD;     //set ALU to add
			RF_s = 0;			  //set register to source from ALU output
			RF_w_en = 1;		  //set RF write enable high
			NextState = S_FETCH;
	  end
	  
	  S_SUB: begin 
			RF_Ra_addr = IR[11:8];//set register addresses
			RF_Rb_addr = IR[7:4]; //for A and B ALU inputs
			RF_w_addr = IR[3:0];  //set writeback register address
			ALU_s0 = ALU_SUB;     //set ALU to subtract
			RF_s = 0;			  //set register to source from ALU output
			RF_w_en = 1;		  //set RF write enable high
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
