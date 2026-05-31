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
    input PC_w_en,
    input [7:0] PC_set,
    output logic [7:0] PC_out
);

    /*
    The PC module stores the current instruction address. PC_clr, PC_up, and PC_w_en are control 
	signals from the FSM. They are not clocks. The PC only changes on the rising edge of Clk.
    PC_clr  = 1 clears the PC to 0. PC_w_en = 1 loads PC_set into the PC for jump instructions.
    PC_up   = 1 increments the PC by 1. Priority order: 1. Clear the PC. 2. Load a jump address.
    3. Increment the PC. 4. Otherwise hold the current PC value.
    */

    always_ff @(posedge Clk) begin
        if (PC_clr)
            PC_out <= 8'b0;
        else if (PC_w_en)
            PC_out <= PC_set;
        else if (PC_up)
            PC_out <= PC_out + 8'b1;
    end

endmodule
