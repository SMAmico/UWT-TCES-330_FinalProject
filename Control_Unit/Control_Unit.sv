/*
Seth Amico, John Teal
UW TCES 330
Programmable Processor
Project File: Control_Unit.sv
10 June 2026
*/

module Control_Unit(
		input clk,
		input rst,
		    
	/*
    ALU flag inputs come from the datapath. These are only needed for the extra-credit conditional 
	jump states. Alu_Z is used by JNZ. Alu_N and Alu_V are used by JLT.
    */
    input Alu_Z,
    input Alu_N,
    input Alu_V,
	
    // Control signals sent to the datapath.
    output [7:0] D_Addr,
    output D_wr,

    output RF_s,

    output [3:0] RF_W_addr,
    output RF_W_en,

    output [3:0] RF_Ra_addr,
    output [3:0] RF_Rb_addr,

    output [2:0] Alu_s0,
    
	/*
    Debug outputs passed up to Processor.sv. The provided processor testbench expects the processor to
	expose the instruction register, program counter, current state, and next state.
    */
    output [15:0] IR_Out,
    output [7:0] PC_Out,
    output [3:0] StateOut,
    output [3:0] NextStateOut
);
		
	wire PC_clr;
	wire PC_up;
	wire [7:0]PC;
	
	wire IR_ld;
	wire[15:0]IR_in;
	wire[15:0]IR_data;
		
	/*FSM(
			// system clock
			input Clk, 			//system clock
			
			//Reset line
			input Rst,			 //state machine reset line
			
			//PC control lines
			output logic PC_clr,		 //PC clear command line
			output logic PC_up,		 //PC upcounter control line
			// output logic PC_w_en,
			// output logic [7:0]PC_set, //this is a overwrite line for the PC, will be implemented for JMP
			
			//IR input lines
			input [15:0] IR_data, //the raw instruction data from ROM
			output logic IR_ld,		 //instruction data load command
			
			//RAM control lines
			output logic [7:0] D_Addr, //output address to RAM
			output logic D_wr,		 //write enable line to data

			//Register File source control mux select line
			output logic RF_s,		 //RF source control line

			// Register File control lines
			output logic [3:0] RF_W_addr,	//RF write address 
			output logic [3:0]RF_Ra_addr, //RF read address A
			output logic [3:0]RF_Rb_addr, //RF read address B
			output logic RF_W_en,			//RF write address enable
			
			//ALU control lines
			output logic [2:0]Alu_s0,
			//input Alu_Z //this is an inbuilt ALU flag line that will need to be implemented
			//input Alu_V //this is an inbuilt ALU overflow flag line
			//input Alu_N //this is an inbuilt ALU negative flag line
			
			//current state output lines
			output logic [3:0]StateOut
			);*/
	FSM FSM(.Clk(clk),
			.Rst(rst),
			
			.PC_clr(PC_clr),
			.PC_up(PC_up),
			//.PC_w_en(),  //PC overwriting isn't implemented yet
			//.PC_set(),   
			
			.IR_data(IR_data),
			.IR_ld(IR_ld),
			
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
			
		/*
		PC(
			input clk,
			input PC_clr,
			input PC_up,
			output logic [7:0] PC_out
			);
		*/
	PC PC(
			.clk(clk),
			.PC_clr(PC_clr),
			.PC_up(PC_up),
			.PC_out(PC)
			);
	
		/*
		IR(
			input clk,
			input IR_ld,
			input [15:0] Instruction_In,
			output logic [15:0] IR_data
		);
		*/
	IR IR(
			.clk(clk),
			.IR_ld(IR_ld),
			.Instruction_In(IR_in),
			.IR_data(IR_data)
		 );
		 
		/*
		myROM (
			address,
			clock,
			q
		);
		*/
	myROM ROM(
			.address(PC),
			.clock(clk),
			.q(IR_in)
		);
	
	
endmodule
