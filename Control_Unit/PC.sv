//tces 330
//Project File : PC register

module PC(
		input clk,
		input PC_clr,
		input PC_up,
		output logic [7:0] PC_out
		);
	
	always_ff @(posedge clk) begin
        if (PC_clr)
            PC_Out <= 8'b0;
        else if (PC_up)
            PC_Out <= PC_Out + 8'b1;
    end

endmodule

