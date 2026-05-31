/*
Seth Amico, John Teal
UW TCES 330
Programmable Processor
Project File: FSM_tb.sv
10 June 2026
*/

module FSM_tb();

    logic Clk;
    logic Rst;

    logic [7:0] PC;

    logic PC_clr;
    logic PC_up;
    logic PC_w_en;
    logic [7:0] PC_set;

    logic [15:0] IR_data;
    logic IR_ld;

    logic [7:0] D_Addr;
    logic D_wr;

    logic RF_s;

    logic [3:0] RF_W_addr;
    logic [3:0] RF_Ra_addr;
    logic [3:0] RF_Rb_addr;
    logic RF_W_en;

    logic [2:0] Alu_s0;

    logic Alu_Z;
    logic Alu_N;
    logic Alu_V;

    logic [3:0] StateOut;
    logic [3:0] NextStateOut;

    integer pass_count;
    integer fail_count;

    localparam [3:0] S_INIT     = 4'd0,
                     S_FETCH    = 4'd1,
                     S_DEC      = 4'd2,
                     S_NOP      = 4'd3,
                     S_STR      = 4'd4,
                     S_LDA      = 4'd5,
                     S_LDB      = 4'd6,
                     S_ADD      = 4'd7,
                     S_SUB      = 4'd8,
                     S_HLT      = 4'd9,
                     S_JMP      = 4'd10,
                     S_JNZ_TEST = 4'd11,
                     S_JNZ_JUMP = 4'd12,
                     S_JLT_TEST = 4'd13,
                     S_JLT_JUMP = 4'd14;

    localparam [2:0] ALU_ADDZERO = 3'b000,
                     ALU_ADD     = 3'b001,
                     ALU_SUB     = 3'b010,
                     ALU_PASS    = 3'b011;

    FSM dut(
        .Clk(Clk),
        .Rst(Rst),

        .PC(PC),

        .PC_clr(PC_clr),
        .PC_up(PC_up),
        .PC_w_en(PC_w_en),
        .PC_set(PC_set),

        .IR_data(IR_data),
        .IR_ld(IR_ld),

        .D_Addr(D_Addr),
        .D_wr(D_wr),

        .RF_s(RF_s),

        .RF_W_addr(RF_W_addr),
        .RF_Ra_addr(RF_Ra_addr),
        .RF_Rb_addr(RF_Rb_addr),
        .RF_W_en(RF_W_en),

        .Alu_s0(Alu_s0),

        .Alu_Z(Alu_Z),
        .Alu_N(Alu_N),
        .Alu_V(Alu_V),

        .StateOut(StateOut),
        .NextStateOut(NextStateOut)
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

    task automatic check_value;
        input [255:0] name;
        input [31:0] actual;
        input [31:0] expected;

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

    task automatic reset_fsm_with_instruction;
        input [15:0] instruction;

        begin
            IR_data = instruction;
            PC      = 8'h20;
            Alu_Z   = 1'b0;
            Alu_N   = 1'b0;
            Alu_V   = 1'b0;

            Rst = 1'b1;
            tick();

            check_value("reset StateOut should be S_INIT", StateOut, S_INIT);
            check_value("S_INIT PC_clr", PC_clr, 1);

            Rst = 1'b0;
            tick();

            check_value("state should be S_FETCH", StateOut, S_FETCH);
            check_value("S_FETCH IR_ld", IR_ld, 1);
            check_value("S_FETCH PC_up", PC_up, 1);

            tick();

            check_value("state should be S_DEC", StateOut, S_DEC);
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;

        Rst     = 1'b0;
        PC      = 8'h00;
        IR_data = 16'h0000;
        Alu_Z   = 1'b0;
        Alu_N   = 1'b0;
        Alu_V   = 1'b0;

        $display("Starting FSM testbench.");

        /*
        Test NOOP:
        0000 0000 0000 0000
        */
        $display("Testing NOOP.");
        reset_fsm_with_instruction(16'h0000);
        tick();

        check_value("NOOP StateOut", StateOut, S_NOP);
        check_value("NOOP D_wr", D_wr, 0);
        check_value("NOOP RF_W_en", RF_W_en, 0);

        tick();
        check_value("NOOP returns to FETCH", StateOut, S_FETCH);

        /*
        Test STORE:
        0001 rrrr dddddddd
        STORE RF[A] -> D[6A]
        */
        $display("Testing STORE.");
        reset_fsm_with_instruction(16'h1A6A);
        tick();

        check_value("STORE StateOut", StateOut, S_STR);
        check_value("STORE RF_Ra_addr", RF_Ra_addr, 4'hA);
        check_value("STORE D_Addr", D_Addr, 8'h6A);
        check_value("STORE D_wr", D_wr, 1);

        /*
        Test LOAD:
        0010 dddddddd rrrr
        LOAD D[1B] -> RF[A]
        */
        $display("Testing LOAD.");
        reset_fsm_with_instruction(16'h21BA);
        tick();

        check_value("LOAD_A StateOut", StateOut, S_LDA);
        check_value("LOAD_A D_Addr", D_Addr, 8'h1B);
        check_value("LOAD_A RF_W_addr", RF_W_addr, 4'hA);
        check_value("LOAD_A RF_s", RF_s, 1);
        check_value("LOAD_A RF_W_en", RF_W_en, 0);

        tick();

        check_value("LOAD_B StateOut", StateOut, S_LDB);
        check_value("LOAD_B D_Addr", D_Addr, 8'h1B);
        check_value("LOAD_B RF_W_addr", RF_W_addr, 4'hA);
        check_value("LOAD_B RF_s", RF_s, 1);
        check_value("LOAD_B RF_W_en", RF_W_en, 1);

        /*
        Test ADD:
        0011 raaa rbbb rccc
        ADD RF[A] + RF[B] -> RF[C]
        */
        $display("Testing ADD.");
        reset_fsm_with_instruction(16'h3ABC);
        tick();

        check_value("ADD StateOut", StateOut, S_ADD);
        check_value("ADD RF_Ra_addr", RF_Ra_addr, 4'hA);
        check_value("ADD RF_Rb_addr", RF_Rb_addr, 4'hB);
        check_value("ADD RF_W_addr", RF_W_addr, 4'hC);
        check_value("ADD RF_W_en", RF_W_en, 1);
        check_value("ADD Alu_s0", Alu_s0, ALU_ADD);
        check_value("ADD RF_s", RF_s, 0);

        /*
        Test SUB:
        0100 raaa rbbb rccc
        SUB RF[A] - RF[B] -> RF[C]
        */
        $display("Testing SUB.");
        reset_fsm_with_instruction(16'h4ABC);
        tick();

        check_value("SUB StateOut", StateOut, S_SUB);
        check_value("SUB RF_Ra_addr", RF_Ra_addr, 4'hA);
        check_value("SUB RF_Rb_addr", RF_Rb_addr, 4'hB);
        check_value("SUB RF_W_addr", RF_W_addr, 4'hC);
        check_value("SUB RF_W_en", RF_W_en, 1);
        check_value("SUB Alu_s0", Alu_s0, ALU_SUB);
        check_value("SUB RF_s", RF_s, 0);

        /*
        Test HALT:
        0101 0000 0000 0000
        */
        $display("Testing HALT.");
        reset_fsm_with_instruction(16'h5000);
        tick();

        check_value("HALT StateOut", StateOut, S_HLT);

        tick();

        check_value("HALT stays HALT", StateOut, S_HLT);

        /*
        Test JMP extra credit:
        1001 0000 bbbbbbbb
        JMP 3C
        */
        $display("Testing JMP.");
        reset_fsm_with_instruction(16'h903C);
        tick();

        check_value("JMP StateOut", StateOut, S_JMP);
        check_value("JMP PC_set", PC_set, 8'h3C);
        check_value("JMP PC_w_en", PC_w_en, 1);

        /*
        Test JNZ extra credit, branch taken:
        1010 bbbbbbbb rrrr
        JNZ 22 if RF[3] is not zero
        */
        $display("Testing JNZ taken.");
        reset_fsm_with_instruction(16'hA223);
        tick();

        check_value("JNZ_TEST StateOut", StateOut, S_JNZ_TEST);
        check_value("JNZ_TEST RF_Ra_addr", RF_Ra_addr, 4'h3);
        check_value("JNZ_TEST Alu_s0", Alu_s0, ALU_PASS);

        Alu_Z = 1'b0;
        tick();

        check_value("JNZ_JUMP StateOut", StateOut, S_JNZ_JUMP);
        check_value("JNZ_JUMP PC_set", PC_set, 8'h22);
        check_value("JNZ_JUMP PC_w_en", PC_w_en, 1);

        /*
        Test JNZ extra credit, branch not taken.
        */
        $display("Testing JNZ not taken.");
        reset_fsm_with_instruction(16'hA223);
        tick();

        Alu_Z = 1'b1;
        tick();

        check_value("JNZ not taken PC_w_en", PC_w_en, 0);

        /*
        Test JLT extra credit, branch taken:
        1011 raaa rbbb bbbb
        JLT RF[1], RF[2], +2
        */
        $display("Testing JLT taken.");
        reset_fsm_with_instruction(16'hB122);
        PC = 8'h20;
        tick();

        check_value("JLT_TEST StateOut", StateOut, S_JLT_TEST);
        check_value("JLT_TEST RF_Ra_addr", RF_Ra_addr, 4'h1);
        check_value("JLT_TEST RF_Rb_addr", RF_Rb_addr, 4'h2);
        check_value("JLT_TEST Alu_s0", Alu_s0, ALU_SUB);

        Alu_N = 1'b1;
        Alu_V = 1'b0;
        tick();

        check_value("JLT_JUMP StateOut", StateOut, S_JLT_JUMP);
        check_value("JLT_JUMP PC_set", PC_set, 8'h22);
        check_value("JLT_JUMP PC_w_en", PC_w_en, 1);

        /*
        Test JLT extra credit, branch not taken.
        */
        $display("Testing JLT not taken.");
        reset_fsm_with_instruction(16'hB122);
        PC = 8'h20;
        tick();

        Alu_N = 1'b0;
        Alu_V = 1'b0;
        tick();

        check_value("JLT not taken PC_w_en", PC_w_en, 0);

        $display("FSM testbench complete.");
        $display("Passes: %0d", pass_count);
        $display("Failures: %0d", fail_count);

        if (fail_count == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");

        $stop;
    end

endmodule
