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
			logic [7:0]PC,
			output PC_clr,		 //PC clear command line
			wire PC_up,		 //PC upcounter control line
			//output PC_w_en,
			//output [7:0]PC_set, //this is a overwrite line for the PC, will be implemented for JMP
			
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
			

  localparam S_INIT,
			 S_FETCH,
			 S_DEC,
			 S_EXE,
			 S_NOP,
			 S_STR,
			 S_LDR,
			 S_ADD,
			 S_SUB,
			 S_HLT,
			 
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
	  S_EXE:
	  S_NOP:
	  S_STR:
	  S_LDR:
	  S_ADD:
	  S_SUB:
	  S_HLT:
	  
      default: begin
 
        NextState = S_INIT;          // safe state
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
