

module PC(
		  input clk,
		  input PC_clr,
		  input PC_up,
		  //input [7:0]PC_set
		  //input PC_w_en;
		  );
	logic [7:0] PC;		 
	//myROM (address, clock, q);  

always @* begin
	if(PC_clr == 1) begin
		PC = 8'b0;
	end else if(PC_up == 1) begin
		PC == 8'b0;
	end
end

endmodule