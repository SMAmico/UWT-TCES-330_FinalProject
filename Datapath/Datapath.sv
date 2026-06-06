/*
Seth Amico, John Teal
UW TCES 330
Programmable Processor
Project File: Datapath.sv
10 June 2026
*/

/*
This file contains the register file, ALU, RAM wrapper, register-file source mux, and combined 
Datapath module for the programmable processor project. This file requires the Quartus-generated 
myRAM.v file to be included in the Quartus project and in the ModelSim compile list. The myRAM module 
is expected to use the standard LPM RAM port names: address, clock, data, wren, and q.
*/

module RegFile (
    input Clk,
    input write,

    input [3:0] wrAddr,
    input [15:0] wrData,

    input [3:0] rdAddrA,
    output [15:0] rdDataA,

    input [3:0] rdAddrB,
    output [15:0] rdDataB
);

    logic [15:0] regfile [0:15];

    /*
    The register file has two combinational read ports. When rdAddrA or rdAddrB changes, the selected
    register value appears on rdDataA or rdDataB without waiting for a clock edge.
    */
    assign rdDataA = regfile[rdAddrA];
    assign rdDataB = regfile[rdAddrB];

    /*
    The register file has one clocked write port. When write is high, wrData is copied into the
    register selected by wrAddr on the rising edge of Clk. When write is low, no register changes.
    */
    always_ff @(posedge Clk) begin
        if (write)
            regfile[wrAddr] <= wrData;
    end

endmodule


module ALU (
    input [15:0] A,
    input [15:0] B,
    input [2:0] S,

    output logic [15:0] Q,

    output logic Alu_Z,
    output logic Alu_N,
    output logic Alu_V
);

    /*
    ALU operation select:
        S = 000: Q = A + 0
        S = 001: Q = A + B
        S = 010: Q = A - B
        S = 011: Q = A * B
        S = 100: Q = A ^ B
        S = 101: Q = A | B
        S = 110: Q = A & B
        S = 111: Q = A << B

    Alu_Z is high when Q is zero.
    Alu_N is the sign bit of Q.
    Alu_V is signed overflow for ADD, SUB, and INC.
    */

    always_comb begin
        Q = 16'h0000;
        Alu_V = 1'b0;

        case (S)
            3'b000: begin
                Q = A + 16'd0;
                Alu_V = 1'b0;
            end

            3'b001: begin
                Q = A + B;
                Alu_V = (~(A[15] ^ B[15])) & (Q[15] ^ A[15]);
            end

            3'b010: begin
                Q = A - B;
                Alu_V = (A[15] ^ B[15]) & (Q[15] ^ A[15]);
            end

            3'b011: begin
                Q = A * B;
                Alu_V = 1'b0;
            end

            3'b100: begin
                Q = A ^ B;
                Alu_V = 1'b0;
            end

            3'b101: begin
                Q = A | B;
                Alu_V = 1'b0;
            end

            3'b110: begin
                Q = A & B;
                Alu_V = 1'b0;
            end

            3'b111: begin
                Q = A << B;
                Alu_V = 1'b0;
            end

            default: begin
                Q = 16'h0000;
                Alu_V = 1'b0;
            end
        endcase
    end

    assign Alu_Z = (Q == 16'h0000);
    assign Alu_N = Q[15];

endmodule


module mux16w_2to1 (
    input [15:0] RAM,
    input [15:0] ALU,
    input RF_s,
    output [15:0] Q
);

    /*
    RF_s selects the source that writes back into the register file.
    RF_s = 1 selects RAM data for LOAD.
    RF_s = 0 selects ALU data for arithmetic and logic instructions.
    */
    assign Q = RF_s ? RAM : ALU;

endmodule


module RAM (
    input [7:0] D_Addr,
    input D_wr,
    input Clk,
    input [15:0] W_data,
    output [15:0] R_data
);

    /*
    RAM wrapper for the Quartus-generated myRAM LPM module.

    Expected myRAM ports:
        address[7:0]
        clock
        data[15:0]
        wren
        q[15:0]

    The RAM q output should be UNREGISTERED in the LPM setup.
    */
    myRAM ram_lpm(
        .address(D_Addr),
        .clock(Clk),
        .data(W_data),
        .wren(D_wr),
        .q(R_data)
    );

endmodule


module Datapath (
    input Clk,

    input [7:0] D_Addr,
    input D_wr,

    input RF_s,
    input RF_W_en,

    input [3:0] RF_Ra_addr,
    input [3:0] RF_Rb_addr,
    input [3:0] RF_W_addr,

    input [2:0] Alu_s0,

    output [15:0] ALU_A,
    output [15:0] ALU_B,
    output [15:0] ALU_Out,

    output Alu_Z,
    output Alu_N,
    output Alu_V
);

    /*
    Internal datapath wires:
        Ra_data is the register file A-side read output.
        Rb_data is the register file B-side read output.
        Q_Data is the ALU result.
        R_data is the RAM read output.
        W_data is the selected write-back value for the register file.
    */
    wire [15:0] Ra_data;
    wire [15:0] Rb_data;
    wire [15:0] Q_Data;
    wire [15:0] R_data;
    wire [15:0] W_data;

    assign ALU_A   = Ra_data;
    assign ALU_B   = Rb_data;
    assign ALU_Out = Q_Data;

    /*
    Register file instance.

    LOAD writes RAM data into the register file through W_data.
    ADD/SUB and other ALU operations write ALU data into the register file through W_data.
    */
    RegFile rf0(
        .Clk(Clk),
        .write(RF_W_en),
        .wrAddr(RF_W_addr),
        .wrData(W_data),
        .rdAddrA(RF_Ra_addr),
        .rdDataA(Ra_data),
        .rdAddrB(RF_Rb_addr),
        .rdDataB(Rb_data)
    );

    /*
    ALU instance.

    The ALU uses the two register-file read outputs as operands. The flags are used by the extra-credit
    conditional jump instructions.
    */
    ALU alu0(
        .A(Ra_data),
        .B(Rb_data),
        .S(Alu_s0),
        .Q(Q_Data),
        .Alu_Z(Alu_Z),
        .Alu_N(Alu_N),
        .Alu_V(Alu_V)
    );

    /*
    Register-file write-back mux.

    RF_s = 1 selects RAM data for LOAD.
    RF_s = 0 selects ALU data for ADD, SUB, and other ALU operations.
    */
    mux16w_2to1 rf_source0(
        .RAM(R_data),
        .ALU(Q_Data),
        .RF_s(RF_s),
        .Q(W_data)
    );

    /*
    RAM instance.

    STORE writes Ra_data into RAM.
    LOAD reads RAM data through R_data and sends it to the register-file write-back mux.
    */
    RAM ram0(
        .D_Addr(D_Addr),
        .D_wr(D_wr),
        .Clk(Clk),
        .W_data(Ra_data),
        .R_data(R_data)
    );

endmodule
