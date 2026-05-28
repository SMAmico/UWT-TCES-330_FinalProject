// TCES 330 Spring 2026
// Project File: ROM.sv
// Instruction Memory: 128 x 16 ROM
// Behavioral combinational-read version for ModelSim testin

module ROM(
  input  [6:0] address,      // address from PC
  output [15:0] instruction  // instruction sent to IR
);

    // Create memory array
    memory[0:127] each 16 bits wide;

    // Fill memory with instructions
    initial begin
        memory[0] = first instruction;
        memory[1] = second instruction;
        memory[2] = third instruction;
        ...
        memory[last] = HALT instruction;
    end

    // Read instruction from current address
    instruction = memory[address];

endmodule
