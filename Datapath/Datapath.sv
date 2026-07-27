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

    input PC_clr,
    input PC_up,
    input PC_w_en,
    input [7:0] PC_set,

    input [3:0] wrAddr,
    input [15:0] wrData,

    input [3:0] rdAddrA,
    output [15:0] rdDataA,

    input [3:0] rdAddrB,
    output [15:0] rdDataB,

    input [3:0] DAddrReg,
    output [15:0] DAddrDat,

    input [3:0] DDataReg,
    output [15:0] DDataDat,

    output [7:0] PC_out
);

    logic [15:0] regfile [0:15];

    /*
    The register file has two combinational read ports. When rdAddrA or rdAddrB changes, the selected
    register value appears on rdDataA or rdDataB without waiting for a clock edge.

    Register 16 (address 4'hF) is reserved as the program counter register. Because it is part of the
    register file, it can still be read through either read port like any other register.
    */
    assign rdDataA = regfile[rdAddrA];
    assign rdDataB = regfile[rdAddrB];
    assign PC_out  = regfile[4'hF][7:0];

    /*
    The memory is accessed by reading the register at DAddrReg and sending it to DAddrDat
    to be used as a RAM address.
    */
    assign DAddrDat = regfile[DAddrReg];
    
    /*
    The data to be written to memory is read from the register at DDataReg and sent to DDataDat.
    */
    assign DDataDat = regfile[DDataReg];
    /*
    The register file has one clocked write port plus dedicated PC update controls.

    Priority order for register 16 (PC):
    1) PC_clr clears PC to 0
    2) PC_w_en loads PC_set
    3) PC_up increments PC
    4) regular register-file write to wrAddr=4'hF

    Regular writes to registers 0..14 are unchanged.
    */
    always_ff @(posedge Clk) begin
        if (PC_clr)
            regfile[4'hF] <= 16'h0000;
        else if (PC_w_en)
            regfile[4'hF] <= {8'h00, PC_set};
        else if (PC_up)
            regfile[4'hF] <= regfile[4'hF] + 16'h0001;
        else if (write)
            regfile[wrAddr] <= wrData;
    end

endmodule


module ALU (
    input [15:0] A,
    input [15:0] B,
    input [2:0] S,
    input [7:0] MOVI_d,

    output logic [15:0] Q,

    output logic Alu_Z,
    output logic Alu_N,
    output logic Alu_V
);

    /*
    ALU operation select:
        S = 000: Q = A >> B     (Don't ask why it's up here. You know it's from not wanting to
        S = 001: Q = A + B       realign everything in the ISA.)
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
    localparam [2:0] ALU_SHR     = 3'b000,
                     ALU_ADD     = 3'b001,
                     ALU_SUB     = 3'b010,
                     ALU_MULT    = 3'b011,
                     ALU_MOVI     = 3'b100,
                     ALU_OR      = 3'b101,
                     ALU_AND     = 3'b110,
                     ALU_SHL     = 3'b111;

    always_comb begin
        Q = 16'h0000;
        Alu_V = 1'b0;

        case (S)
            ALU_SHR: begin
                Q = A >> B;
                Alu_V = 1'b0;
            end

            ALU_ADD: begin
                Q = A + B;
                Alu_V = (~(A[15] ^ B[15])) & (Q[15] ^ A[15]);
            end

            ALU_SUB: begin
                Q = A - B;
                Alu_V = (A[15] ^ B[15]) & (Q[15] ^ A[15]);
            end

            ALU_MULT: begin
                Q = A * B;
                Alu_V = (~(A[15] ^ B[15]) & (Q[15] ^ A[15]));
            end

            ALU_MOVI: begin
                Q = (A & 16'hFF00) | {8'h00, MOVI_d};
            end

            ALU_OR: begin
                Q = A | B;
                Alu_V = 1'b0;
            end

            ALU_AND: begin
                Q = A & B;
                Alu_V = 1'b0;
            end

            ALU_SHL: begin
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

    /*
    PC control lines from the control unit. Register 16 in the register file stores the live PC value.
    */
    input PC_clr,
    input PC_up,
    input PC_w_en,
    input [7:0] PC_set,

    /*
    change: the datapath block now has a D_wr line to allow the control module to tell the
    datapath when to read from data memory, as well as a select line of the register to
    read the address from.
    */
    input [3:0] D_Addr_reg,
    input [3:0] D_Data_reg,
    input D_wr,

    input RF_s,
    input RF_W_en,

    input [3:0] RF_Ra_addr,
    input [3:0] RF_Rb_addr,
    input [3:0] RF_W_addr,

    input [2:0] Alu_s0,
    input [7:0] MOVI_d,

    output [15:0] ALU_A,
    output [15:0] ALU_B,
    output [15:0] ALU_Out,

    output [7:0] PC_Out,

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
        D_Addr is the address sent from the register file to the ram.
        D_Data is the data from the data register to be written to memory.
    */
    wire [15:0] Ra_data;
    wire [15:0] Rb_data;
    wire [15:0] Q_Data;
    wire [15:0] R_data;
    wire [15:0] W_data;
    wire [15:0] D_Addr;
    wire [15:0] D_Data;
    wire [7:0] PC_reg;

    assign ALU_A   = Ra_data;
    assign ALU_B   = Rb_data;
    assign ALU_Out = Q_Data;
    assign PC_Out  = PC_reg;

    /*
    Register file instance.

    LOAD writes RAM data into the register file through W_data.
    ADD/SUB and other ALU operations write ALU data into the register file through W_data.
    
    D_Addr_reg specifies which register contains the memory address.
    D_Data_reg specifies which register contains the data to write to memory on STORE,
    or which register to write the loaded data to on LOAD.
    */
    RegFile rf0(
        .Clk(Clk),
        .write(RF_W_en),
        .PC_clr(PC_clr),
        .PC_up(PC_up),
        .PC_w_en(PC_w_en),
        .PC_set(PC_set),
        .wrAddr(RF_W_addr),
        .wrData(W_data),
        .rdAddrA(RF_Ra_addr),
        .rdDataA(Ra_data),
        .rdAddrB(RF_Rb_addr),
        .rdDataB(Rb_data),
        .DAddrReg(D_Addr_reg),
        .DAddrDat(D_Addr),
        .DDataReg(D_Data_reg),
        .DDataDat(D_Data),
        .PC_out(PC_reg)
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
        .Alu_V(Alu_V),
        .MOVI_d(MOVI_d)
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

    STORE writes D_Data (from the data register specified by D_Data_reg) into RAM at the address
    specified by D_Addr (from the address register specified by D_Addr_reg).
    LOAD reads RAM data through R_data using the address from D_Addr and sends it to the 
    register-file write-back mux, where it is written to the register specified by D_Data_reg
    on the next clock cycle.
    */
    RAM ram0(
        .D_Addr(D_Addr),
        .D_wr(D_wr),
        .Clk(Clk),
        .W_data(D_Data),
        .R_data(R_data)
    );

endmodule
