/*
Seth Amico, John Teal
UW TCES 330
Programmable Processor
Project File: PC.sv
10 June 2026
*/

module PC(
    input Clk,
    input PC_clr,
    input PC_up,
	output logic [7:0] PC_out
);

    /*
    The PC module stores the current instruction address. PC_clr and PC_up are control signals from 
	the FSM. They are not clocks. The PC only changes on the rising edge of clk. PC_clr = 1 clears 
	the PC to 0. PC_up  = 1 increments the PC by 1. If both PC_clr and PC_up are 0, the PC holds its 
	current value. PC_clr has priority over PC_up because the reset/init behavior should force the 
	processor to start from instruction address 0.
    */

    always_ff @(posedge clk) begin
        if (PC_clr)
            PC_out <= 8'b0;
        else if (PC_up)
            PC_out <= PC_out + 8'b1;
    end
endmodule
