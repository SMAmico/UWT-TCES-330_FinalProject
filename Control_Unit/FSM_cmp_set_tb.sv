`timescale 1ns/1ps

module FSM_cmp_set_tb;

    logic Clk;
    logic ResetN;
    logic [15:0] PC;
    logic PC_clr;
    logic PC_up;
    logic PC_w_en;
    logic [15:0] PC_set;
    logic [15:0] IR_data;
    logic IR_ld;
    logic [3:0] D_Addr_reg;
    logic [3:0] D_Data_reg;
    logic D_wr;
    logic RF_s;
    logic [3:0] RF_W_addr;
    logic [3:0] RF_Ra_addr;
    logic [3:0] RF_Rb_addr;
    logic [15:0] RF_Rb_data;
    logic RF_W_en;
    logic [2:0] Alu_s0;
    logic [7:0] MOVI_d;
    logic Flags_W_en;
    logic SET_result_en;
    logic SET_result;
    logic Alu_Z;
    logic Alu_N;
    logic Alu_V;
    logic Status_Z;
    logic Status_N;
    logic Status_V;
    logic [3:0] StateOut;
    logic [3:0] NextStateOut;
    integer pass_count;
    integer fail_count;

    localparam [3:0] S_CMP = 4'd8,
                     S_HLT = 4'd9,
                     S_SET = 4'd15;
    localparam [2:0] ALU_SUB = 3'b010;

    FSM dut(
        .Clk(Clk), .ResetN(ResetN), .PC(PC),
        .PC_clr(PC_clr), .PC_up(PC_up), .PC_w_en(PC_w_en), .PC_set(PC_set),
        .IR_data(IR_data), .IR_ld(IR_ld),
        .D_Addr_reg(D_Addr_reg), .D_Data_reg(D_Data_reg), .D_wr(D_wr),
        .RF_s(RF_s), .RF_W_addr(RF_W_addr), .RF_Ra_addr(RF_Ra_addr),
        .RF_Rb_addr(RF_Rb_addr), .RF_Rb_data(RF_Rb_data), .RF_W_en(RF_W_en),
        .Alu_s0(Alu_s0), .MOVI_d(MOVI_d),
        .Flags_W_en(Flags_W_en), .SET_result_en(SET_result_en), .SET_result(SET_result),
        .Alu_Z(Alu_Z), .Alu_N(Alu_N), .Alu_V(Alu_V),
        .Status_Z(Status_Z), .Status_N(Status_N), .Status_V(Status_V),
        .StateOut(StateOut), .NextStateOut(NextStateOut)
    );

    initial Clk = 1'b0;
    always #5 Clk = ~Clk;

    task automatic tick;
        begin
            @(posedge Clk);
            #1;
        end
    endtask

    task automatic check;
        input [255:0] name;
        input [31:0] actual;
        input [31:0] expected;
        begin
            if (actual === expected)
                pass_count = pass_count + 1;
            else begin
                fail_count = fail_count + 1;
                $display("FAIL: %0s expected=%h actual=%h", name, expected, actual);
            end
        end
    endtask

    task automatic reset_to_decode;
        input [15:0] instruction;
        begin
            IR_data = instruction;
            ResetN = 1'b0;
            tick();
            ResetN = 1'b1;
            tick();
            tick();
        end
    endtask

    task automatic test_set;
        input [255:0] name;
        input [15:0] instruction;
        input z;
        input n;
        input v;
        input expected_result;
        input [3:0] expected_dest;
        begin
            Status_Z = z;
            Status_N = n;
            Status_V = v;
            reset_to_decode(instruction);
            tick();
            check({name, " state"}, StateOut, S_SET);
            check({name, " write enable"}, RF_W_en, 1'b1);
            check({name, " result select"}, SET_result_en, 1'b1);
            check({name, " destination"}, RF_W_addr, expected_dest);
            check({name, " result"}, SET_result, expected_result);
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;
        PC = 16'h0000;
        RF_Rb_data = 16'h0000;
        Alu_Z = 1'b0;
        Alu_N = 1'b0;
        Alu_V = 1'b0;
        Status_Z = 1'b0;
        Status_N = 1'b0;
        Status_V = 1'b0;

        reset_to_decode(16'hE120);
        tick();
        check("CMP state", StateOut, S_CMP);
        check("CMP source A", RF_Ra_addr, 4'h1);
        check("CMP source B", RF_Rb_addr, 4'h2);
        check("CMP subtraction", Alu_s0, ALU_SUB);
        check("CMP captures flags", Flags_W_en, 1'b1);
        check("CMP does not write RF", RF_W_en, 1'b0);

        test_set("SETLT true", 16'hE30F, 1'b0, 1'b1, 1'b0, 1'b1, 4'h3);
        test_set("SETEQ true", 16'hE41F, 1'b1, 1'b0, 1'b0, 1'b1, 4'h4);
        test_set("SETNE false", 16'hE52F, 1'b1, 1'b0, 1'b0, 1'b0, 4'h5);
        test_set("SETLE true", 16'hE63F, 1'b0, 1'b1, 1'b0, 1'b1, 4'h6);
        test_set("SETGT false", 16'hE74F, 1'b1, 1'b0, 1'b0, 1'b0, 4'h7);
        test_set("SETGE true", 16'hE85F, 1'b0, 1'b0, 1'b0, 1'b1, 4'h8);

        reset_to_decode(16'hE36F);
        tick();
        check("invalid SET condition halts", StateOut, S_HLT);

        $display("CMP/SET FSM testbench complete. Passes: %0d Failures: %0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");
        $finish;
    end

endmodule