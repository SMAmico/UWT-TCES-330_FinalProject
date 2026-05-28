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
			input Clk, 
			
			//Reset line
			input Rst,
			
			//PC control lines
			output PC_clr,
			output PC_up,
			//output [7:0]PC_set, //this is a overwrite line for the PC, will be implemented for JMP
			
			//IR input lines
			input [15:0]IR_data,
			output Id,
			
			//RAM control lines
			output [7:0] D_Addr,
			output D_wr,

			//Register File source control mux select line
			output RF_s,

			// Register File control lines
			output [3:0]RF_W_addr,
			output [3:0]RF_Ra_addr,
			output [3:0]RF_Rb_addr,
			output RF_W_en,
			
			//ALU control lines
			output [2:0]Alu_s0,
			//input Alu_Z //this is an inbuilt ALU flag line that will need to be implemented
			//input Alu_V //this is an inbuilt ALU overflow flag line
			//input Alu_N //this is an inbuilt ALU negative flag line
			
			//current state output lines
			output [3:0]StateOut
			);

  localparam S_INIT = 4'b0000;
			 S_FETCH = 4'b0001;
			 S_DEC = 4'b0010;
			 S_EXE = 4'b0011;
			 S_NOP = 4'b0100;
			 S_STR = 4'b0101;
			 S_LDR = 4'b0110;
			 S_ADD = 4'b0111;
			 S_SUB = 4'b1000;
			 S_HLT = 4'b1001;
			 //S_XOR = 4'b1010; //extra states from ALU should we choose to implement them
			 //S_OR  = 4'b1011;
			 //S_AND = 4'b1100;
			 
			 //S_JMP = 4'b1101; //Extra credit. these need to be included in the ALU
			 //S_JNZ = 4'b1110;
			 //S_JLT = 4'b1111;
  
  logic [3:0] State, NextState;  // state variables
  
  assign StateOut = State; 

  //CombLogic (use blocking assigns)
  //describe state transition
  //of a Moore machine
  always_comb begin
	
	
    case (State)
      S_INIT: begin
        PC_clr = 1;
        if (1)  begin		//always move to fetch state
          NextState = S_FETCH; 
        end
      end  
      
      
      default: begin
 
        NextState = S_INIT;          // safe state
      end
    endcase //end case - state trnasition description
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
