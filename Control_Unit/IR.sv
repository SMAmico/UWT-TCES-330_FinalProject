// TCES 330 Spring 2026
// Project File: IR.sv
// Instruction Register

module IR(
    input clk,
    input IR_ld,
    input [15:0] Instruction_In,
	output logic [15:0] IR_data
);
		
/*
The IR is a clocked register. Ir_ld = 1 means load the current instruction from ROM. Ir_ld = 0 means 
hold the previous instruction.
*/
    always_ff @(posedge clk) begin
		if (IR_ld)
            IR_data <= Instruction_In;
    end
endmodule

