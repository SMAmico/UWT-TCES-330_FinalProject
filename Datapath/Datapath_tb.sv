/*
Seth Amico, John Teal
UW TCES 330
Programmable Processor
Project File: Datapath_tb.sv
10 June 2026
*/

`timescale 1 ps / 1 ps

module Datapath_tb();

    logic Clk;

    logic [7:0] D_Addr;
    logic D_wr;
    logic RF_s;
    logic RF_W_en;

    logic [3:0] RF_Ra_addr;
    logic [3:0] RF_Rb_addr;
    logic [3:0] RF_W_addr;

    logic [2:0] Alu_s0;

    logic [15:0] ALU_A;
    logic [15:0] ALU_B;
    logic [15:0] ALU_Out;

    logic Alu_Z;
    logic Alu_N;
    logic Alu_V;

    integer pass_count;
    integer fail_count;

    localparam [2:0] ALU_ADDZERO = 3'b000;
    localparam [2:0] ALU_ADD     = 3'b001;
    localparam [2:0] ALU_SUB     = 3'b010;
    localparam [2:0] ALU_PASS    = 3'b011;

Datapath dut(
    .Clk(Clk),

    .D_Addr(D_Addr),
    .D_wr(D_wr),

    .RF_s(RF_s),
    .RF_W_en(RF_W_en),

    .RF_Ra_addr(RF_Ra_addr),
    .RF_Rb_addr(RF_Rb_addr),
    .RF_W_addr(RF_W_addr),

    .Alu_s0(Alu_s0),

    .ALU_A(ALU_A),
    .ALU_B(ALU_B),
    .ALU_Out(ALU_Out)
);

    initial Clk = 1'b0;

    always begin
        #5 Clk = ~Clk;
    end

    task automatic tick;
        begin
            @(posedge Clk);
            #1;
        end
    endtask

    task automatic check16;
        input [255:0] name;
        input [15:0] actual;
        input [15:0] expected;

        begin
            if (actual === expected) begin
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
                $display("FAIL: %0s expected=%h actual=%h time=%0t",
                         name, expected, actual, $time);
            end
        end
    endtask

    task automatic load_ram_to_reg;
        input [7:0] ram_addr;
        input [3:0] reg_addr;
        input [15:0] expected_value;

        begin
            D_Addr     = ram_addr;
            D_wr       = 1'b0;

            RF_s       = 1'b1;
            RF_W_addr  = reg_addr;
            RF_W_en    = 1'b1;

            RF_Ra_addr = reg_addr;
            RF_Rb_addr = 4'h0;
            Alu_s0     = ALU_ADDZERO;

            /*
            Wait briefly after changing D_Addr so the unregistered RAM output can settle before the
            register file writes on the next rising clock edge.
            */
            #2;
            tick();

            RF_W_en = 1'b0;
            #2;

            RF_Ra_addr = reg_addr;
            #2;

            check16("LOAD RAM to RF", ALU_A, expected_value);
        end
    endtask

    task automatic alu_write_reg;
        input [2:0] alu_op;
        input [3:0] reg_a;
        input [3:0] reg_b;
        input [3:0] reg_w;
        input [15:0] expected_value;

        begin
            D_wr       = 1'b0;

            RF_s       = 1'b0;
            RF_Ra_addr = reg_a;
            RF_Rb_addr = reg_b;
            RF_W_addr  = reg_w;
            RF_W_en    = 1'b1;

            Alu_s0     = alu_op;

            #2;
            check16("ALU combinational result", ALU_Out, expected_value);

            tick();

            RF_W_en = 1'b0;
            #2;

            RF_Ra_addr = reg_w;
            #2;

            check16("ALU writeback to RF", ALU_A, expected_value);
        end
    endtask

    task automatic store_reg_to_ram;
        input [3:0] reg_addr;
        input [7:0] ram_addr;
        input [15:0] expected_value;

        begin
            RF_Ra_addr = reg_addr;
            RF_Rb_addr = 4'h0;

            D_Addr     = ram_addr;
            D_wr       = 1'b1;

            RF_W_en    = 1'b0;
            RF_s       = 1'b0;
            Alu_s0     = ALU_PASS;

            #2;
            tick();

            D_wr = 1'b0;
            #10;

            check16("STORE RF to RAM", dut.R_data, expected_value);
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;

        D_Addr     = 8'h00;
        D_wr       = 1'b0;
        RF_s       = 1'b0;
        RF_W_en    = 1'b0;
        RF_Ra_addr = 4'h0;
        RF_Rb_addr = 4'h0;
        RF_W_addr  = 4'h0;
        Alu_s0     = ALU_ADDZERO;

        $display("Starting Datapath testbench.");

        /*
        LOAD D[1B] -> RF[A]
        */
        load_ram_to_reg(8'h1B, 4'hA, 16'h000A);

        /*
        LOAD D[2A] -> RF[B]
        */
        load_ram_to_reg(8'h2A, 4'hB, 16'h0003);

        /*
        SUB RF[A] - RF[B] -> RF[A]
        000A - 0003 = 0007
        */
        alu_write_reg(ALU_SUB, 4'hA, 4'hB, 4'hA, 16'h0007);

        /*
        LOAD D[3C] -> RF[B]
        */
        load_ram_to_reg(8'h3C, 4'hB, 16'h0004);

        /*
        ADD RF[A] + RF[B] -> RF[A]
        0007 + 0004 = 000B
        */
        alu_write_reg(ALU_ADD, 4'hA, 4'hB, 4'hA, 16'h000B);

        /*
        LOAD D[7E] -> RF[B]
        */
        load_ram_to_reg(8'h7E, 4'hB, 16'h0002);

        /*
        SUB RF[A] - RF[B] -> RF[A]
        000B - 0002 = 0009
        */
        alu_write_reg(ALU_SUB, 4'hA, 4'hB, 4'hA, 16'h0009);

        /*
        STORE RF[A] -> D[6A]
        */
        store_reg_to_ram(4'hA, 8'h6A, 16'h0009);

        $display("Datapath testbench complete.");
        $display("Passes: %0d", pass_count);
        $display("Failures: %0d", fail_count);

        if (fail_count == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");

        $stop;
    end

endmodule
