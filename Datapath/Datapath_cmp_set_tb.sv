`timescale 1ns/1ps

module Datapath_cmp_set_tb;

    logic Clk;
    logic PC_clr;
    logic PC_up;
    logic PC_w_en;
    logic [15:0] PC_set;
    logic [3:0] D_Addr_reg;
    logic [3:0] D_Data_reg;
    logic D_wr;
    logic RF_s;
    logic RF_W_en;
    logic [3:0] RF_Ra_addr;
    logic [3:0] RF_Rb_addr;
    logic [3:0] RF_W_addr;
    logic [2:0] Alu_s0;
    logic [7:0] MOVI_d;
    logic Flags_W_en;
    logic SET_result_en;
    logic SET_result;
    logic [15:0] ALU_A;
    logic [15:0] ALU_B;
    logic [15:0] ALU_Out;
    logic [15:0] PC_Out;
    logic Alu_Z;
    logic Alu_N;
    logic Alu_V;
    logic Status_Z;
    logic Status_N;
    logic Status_V;
    integer pass_count;
    integer fail_count;

    Datapath dut(
        .Clk(Clk), .PC_clr(PC_clr), .PC_up(PC_up), .PC_w_en(PC_w_en), .PC_set(PC_set),
        .D_Addr_reg(D_Addr_reg), .D_Data_reg(D_Data_reg), .D_wr(D_wr),
        .RF_s(RF_s), .RF_W_en(RF_W_en), .RF_Ra_addr(RF_Ra_addr),
        .RF_Rb_addr(RF_Rb_addr), .RF_W_addr(RF_W_addr), .Alu_s0(Alu_s0), .MOVI_d(MOVI_d),
        .Flags_W_en(Flags_W_en), .SET_result_en(SET_result_en), .SET_result(SET_result),
        .ALU_A(ALU_A), .ALU_B(ALU_B), .ALU_Out(ALU_Out), .PC_Out(PC_Out),
        .Alu_Z(Alu_Z), .Alu_N(Alu_N), .Alu_V(Alu_V),
        .Status_Z(Status_Z), .Status_N(Status_N), .Status_V(Status_V)
    );

    initial Clk = 1'b0;
    always #5 Clk = ~Clk;

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
            if (actual === expected)
                pass_count = pass_count + 1;
            else begin
                fail_count = fail_count + 1;
                $display("FAIL: %0s expected=%h actual=%h", name, expected, actual);
            end
        end
    endtask

    task automatic check1;
        input [255:0] name;
        input actual;
        input expected;
        begin
            if (actual === expected)
                pass_count = pass_count + 1;
            else begin
                fail_count = fail_count + 1;
                $display("FAIL: %0s expected=%b actual=%b", name, expected, actual);
            end
        end
    endtask

    initial begin
        PC_clr = 1'b0;
        PC_up = 1'b0;
        PC_w_en = 1'b0;
        PC_set = 16'h0000;
        D_Addr_reg = 4'h0;
        D_Data_reg = 4'h0;
        D_wr = 1'b0;
        RF_s = 1'b0;
        RF_W_en = 1'b0;
        RF_Ra_addr = 4'h0;
        RF_Rb_addr = 4'h0;
        RF_W_addr = 4'h0;
        Alu_s0 = 3'b010;
        MOVI_d = 8'h00;
        Flags_W_en = 1'b0;
        SET_result_en = 1'b0;
        SET_result = 1'b0;
        pass_count = 0;
        fail_count = 0;

        PC_clr = 1'b1;
        tick();
        PC_clr = 1'b0;
        check1("status Z resets", Status_Z, 1'b0);
        check1("status N resets", Status_N, 1'b0);
        check1("status V resets", Status_V, 1'b0);

        dut.rf0.regfile[4'h1] = 16'h8000;
        dut.rf0.regfile[4'h2] = 16'h0001;
        RF_Ra_addr = 4'h1;
        RF_Rb_addr = 4'h2;
        Flags_W_en = 1'b1;
        #1;
        check16("CMP subtraction result", ALU_Out, 16'h7FFF);
        tick();
        Flags_W_en = 1'b0;
        check1("CMP captures Z", Status_Z, 1'b0);
        check1("CMP captures N", Status_N, 1'b0);
        check1("CMP captures V", Status_V, 1'b1);

        SET_result_en = 1'b1;
        SET_result = 1'b1;
        RF_W_addr = 4'h3;
        RF_W_en = 1'b1;
        tick();
        check16("SET writes full-word true", dut.rf0.regfile[4'h3], 16'h0001);

        SET_result = 1'b0;
        RF_W_addr = 4'h4;
        tick();
        check16("SET writes full-word false", dut.rf0.regfile[4'h4], 16'h0000);

        SET_result = 1'b1;
        RF_W_addr = 4'h0;
        tick();
        check16("R0 ignores writeback", dut.rf0.regfile[4'h0], 16'h0000);
        RF_Ra_addr = 4'h0;
        #1;
        check16("R0 reads as zero", ALU_A, 16'h0000);
        check1("SET preserves CMP Z", Status_Z, 1'b0);
        check1("SET preserves CMP N", Status_N, 1'b0);
        check1("SET preserves CMP V", Status_V, 1'b1);

        $display("CMP/SET datapath testbench complete. Passes: %0d Failures: %0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");
        $finish;
    end

endmodule