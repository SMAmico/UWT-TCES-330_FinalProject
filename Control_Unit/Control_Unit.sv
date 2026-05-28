// TCES 330 Spring 2026
// SystemVerilog template to describe
// Moore State Machine 
// if we want to monitor the states of 
// an FSM, we can add to the portlist
// an output named StateOut
// thus the code should contain a line 
// "assign StateOut = State"

module Name( Clk, other input signals, output signals, StateOut);

  input Clk;        // system clock
  input ....        // other inputs including Clr, Reset, etc

  output logic ...  // system output 
  output [X:0]StateOut; // if we want to monitor the states of 
	                  // an FSM, we can add to the portlist 
		            // an output named StateOut

  // name your states with localparams
  // depend on the number of states, assign
  // approriate values to these localparams
  // suppose 3 states named A, B, C
  localparam A  = 2'd0, 
             B  = 2'd1, 
             C  = 2'd2;
  
  //notice the state variables should have bit-size
  //matching the number of states
  //in this example, 3 states, so 2-bits
  //if you have N states, then the vector size is
  //decided by $clog2(N)-1
  logic [1:0] State, NextState;  // state variables
  
  //assign the StateOut values the same as State
  //this step CANNOT skip! Quartus cannot generate 
  //the right state transition diagram if you combine
  //the State and StateOut
  assign StateOut = State; 

  //CombLogic (use blocking assigns)
  //describe state transition
  //of a Moore machine
  always_comb begin
    
    case (State)
      A: begin
        // specify the output if different from the default
        if ( any input deciding the state switching)  begin
          NextState = B; 
        end
      end  
      
      B: begin
         // specify the output if different from the default
        if ( any input deciding the state switching ) begin
          NextState = C;
        end
      end  
      
      C: begin
        //specify the output if different from the default
	if ( any input deciding the state switching ) begin
          NextState = A;
        end
       end
      
      default: begin
        // specify the default output 
        NextState = ;          // safe state
      end
    endcase //end case - state trnasition description
  end // end the always Comb Logic
    
  //StateReg (use non-blocking assigns)
  //this example has an active low reset signal
  //so name it as 'ResetN'; if an active high
  //signal, match it with a name Reset
  //the template given here has the reset signal
  //synchronized by the Clk signal. Most of the time
  //if not specified, we make this a default setting
  always_ff @(posedge Clk) begin
    if (!ResetN)
      State <= A;
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
