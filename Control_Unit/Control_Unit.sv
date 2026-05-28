

module Control_Unit(
		input clk,
		input rst,
		output [7:0]D_Addr,
		output D_wr,
		output RF_s,
		output [3:0]RF_W_addr,
		output RF_W_en,
		output [3:0]RF_Ra_addr,
		output [3:0]RF_Rb_addr,
		output [2:0]Alu_s0
		);
	/*Control_Unit_FSM(
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
			);*/
	FSM FSM(.Clk(clk),
			.Rst(rst),
			
			.PC(),
			.PC_clr(),
			.PC_up(),
			.PC_w_en(),
			.PC_set(),
			
			.IR_data(),
			.IR_ld(),
			
			.D_addr(D_Addr),
			.D_wr(D_wr),
			
			.RF_s(RF_s),
			.RF_W_addr(RF_W_addr),
			.RF_Ra_addr(RF_Ra_addr),
			.RF_Rb_addr(RF_Rb_addr),
			.RF_W_en(RF_W_en),
			
			.Alu_s0(Alu_s0),
			.StateOut(StateOut)
			);
	
	
endmodule