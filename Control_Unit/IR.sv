/*
Seth Amico, John Teal
UW TCES 330
Programmable Processor
Project File: IR.sv
10 June 2026
*/

module IR(
    input clk,
    input IR_ld,
    input [15:0] Instruction_In,
    output logic [15:0] IR_data
);

    /*
    The Instruction Register stores the current 16-bit instruction. IR_ld is a load-enable signal from 
	the FSM. It is not a clock. When IR_ld = 1, the IR loads the current instruction from ROM on the 
	rising edge of clk. When IR_ld = 0, the IR holds its previous instruction.
    */

    always_ff @(posedge clk) begin
        if (IR_ld)
            IR_data <= Instruction_In;
    end

endmodule
