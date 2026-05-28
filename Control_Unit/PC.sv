//tces 330
//Project File : PC register

module PC(
		input clk,
		input PC_clr,
		input PC_up,
		output logic [7:0] PC_out;
		//input [7:0]PC_set
		//input PC_w_en;
);
	
	always_ff @(posedge clk) begin
        if (PC_clr)
            PC_Out <= 8'b0;
        else if (PC_up)
            PC_Out <= PC_Out + 8'b1;
    end

endmodule
/*
always @(posedge PC_up, posedge PC_clr) begin
	if(PC_clr == 1) begin
		PC = 8'b0;
	end else if(PC_up == 1) begin
		PC == 8'b0;
	end else PC = PC;
end
endmodule
*/
