
module IR(
		input clk, 
		input [7:0]PC_addr,	 //pc address to use for
		output logic [15:0]Ir_data,//returned data from ROM
		input Ir_ld			 //trigger line to fetch an instruction from the current PC value
		
		);
		
	always @(posedge Ir_ld) begin
		
	end
		
endmodule

