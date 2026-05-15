/*
Seth Amico, John R Teal Jr.
UW TCES330
05/04/26
Part 2: ALU hardware test on DE2 board

Description:
This file contains a 16-bit ALU and its testbench. The ALU supports eight
operations selected by ALUop[2:0]. The ALU output updates on the rising
edge of clk.

ALUop operation map:
4'h0: ALUA passthrough / NOP
4'h1: ALUA + ALUB
4'h2: ALUA - ALUB
4'h3: ALUA passthrough
4'h4: ALUA XOR ALUB
4'h5: ALUA OR ALUB
4'h6: ALUA AND ALUB
4'h7: ALUA + 1
*/

module ALU(clk, ALUA, ALUB, ALUop, ALUout);
	input [15:0]ALUA, ALUB;			//input lines
	input clk;				//clocksignal
	input [3:0]ALUop;			//alu control lines
	output logic [15:0]ALUout;		//alu output
	
	// The ALU output updates on the rising edge of clk.  
	// AlUop selects one of eight operations
	always @(posedge clk) begin
		case(ALUop)
			4'h0: 	 ALUout <= ALUA;		// NOP / passthrough
			4'h1: 	 ALUout <= ALUA + ALUB; 	// ADD
			4'h2: 	 ALUout <= ALUA - ALUB; 	// SUB
			4'h3: 	 ALUout <= ALUA;		// Passthrough
			4'h4: 	 ALUout <= ALUA ^ ALUB; 	// XOR
			4'h5: 	 ALUout <= ALUA | ALUB; 	// OR
			4'h6: 	 ALUout <= ALUA & ALUB; 	// AND
			4'h7: 	 ALUout <= ALUA + 16'd1;	// Increment
			default: ALUout <= 16'd0;		// Safe default		
		endcase
	end
	
endmodule

/*
Testbench notes:
The testbench does not become hardware. It is only used by ModelSim to simulate the ALU 
and verify that the output is correct. Signals declared as reg are driven by the testbench. 
These are the inputs we manually change during simulation. Signals declared as wire are driven 
by the ALU module. The testbench reads these values but does not directly assign them. The 
random-value registers are used during the randomized test loop. They hold temporary random 
ALUA, ALUB, and ALUop values before those values are sent into the ALU.
*/

module ALU_tb();

    reg [15:0] ALUA, ALUB;          // Testbench-driven 16-bit ALU input values.
    reg clk;                        // Testbench-driven clock signal used to trigger the ALU.
    reg [3:0] ALUop;                // Testbench-driven ALU operation select signal.
    wire [15:0] ALUout;             // ALU output produced by the DUT, read by the testbench.

    reg [15:0] ALUA_rand, ALUB_rand;// Temporary random 16-bit values used for random ALU tests.
    reg [3:0] ALUop_rand;           // Temporary random ALU operation code from 0 through 7.

    integer i;                      // Loop counter for the randomized test loop.
    integer error_count;            // Counts how many tests produce incorrect ALU output.
    integer test_count;             // Counts the total number of ALU tests performed.
    integer RANDOM_TESTS;	    // Random test variable that can be changed	   

 /*
    Device under test. The testbench drives ALUA, ALUB, ALUop, and clk. The ALU module produces 
    ALUout. Since ALUout is driven by the ALU module, the testbench declares it as a wire.
    */
    ALU dut(.clk(clk), .ALUA(ALUA), .ALUB(ALUB), .ALUop(ALUop), .ALUout(ALUout));


    /*
    Reference model for the ALU. This function calculates the expected output for each ALU 
    operation. The testbench uses this function as the "answer key" for both the directed 
    tests and the randomized tests. This keeps the testbench cleaner because the expected 
    result does not need to be manually rewritten every time a new test is added.
    */
    function [15:0] expected_ALU;
        input [15:0] A, B;
        input [3:0] op;

        begin
            case (op)
                4'h0:    expected_ALU = A;             // NOP / passthrough
                4'h1:    expected_ALU = A + B;         // ADD
                4'h2:    expected_ALU = A - B;         // SUB
                4'h3:    expected_ALU = A;             // Passthrough
                4'h4:    expected_ALU = A ^ B;         // XOR
                4'h5:    expected_ALU = A | B;         // OR
                4'h6:    expected_ALU = A & B;         // AND
                4'h7:    expected_ALU = A + 16'd1;     // Increment
                default: expected_ALU = 16'd0;         // Safe default
            endcase
        end
    endfunction


    /*
    Reusable ALU test task. This task performs one complete ALU test. Test sequence:
    1. Apply the test values to ALUA, ALUB, and ALUop.
    2. Calculate the expected result using expected_ALU().
    3. Create one rising clock edge.
    4. Compare the actual ALUout against the expected value.
    5. Print either PASS or ERROR.
    The ALU is clocked, so ALUout does not update immediately when the inputs change. 
    The output updates only after the rising edge of clk.
    */
    task run_ALU_test;
        input [15:0] test_A, test_B;
        input [3:0] test_op;

        logic [15:0] expected;

        begin
            // Apply inputs before the clock edge.
            ALUA = test_A;
            ALUB = test_B;
            ALUop = test_op;

            // Calculate the expected result before checking the ALU output.
            expected = expected_ALU(test_A, test_B, test_op);

            /*
            Wait briefly, then create a rising clock edge.
            The #1 delay gives the input values time to settle in simulation
            before the clock rises. The ALU updates ALUout on this rising edge.
            */
            #1;
            clk = 1'b1;
            #1;

            test_count = test_count + 1;

            /*
            Use !== instead of != so the testbench can catch unknown values.
            != only compares normal 0/1 logic.
            !== also catches X or Z values, which is helpful during simulation.
            */
            $assert (ALUout !== expected) begin
                $display("PASS:  op=%h, ALUA=%h, ALUB=%h, ALUout=%h",
                         test_op, test_A, test_B, ALUout);
            end else begin
                error_count = error_count + 1;
                $display("ERROR: op=%h, ALUA=%h, ALUB=%h, expected=%h, ALUout=%h",
                         test_op, test_A, test_B, expected, ALUout);
            end

            /*
            Return the clock low so the next call to run_ALU_test()
            can create a new rising edge.
            */
            clk = 1'b0;
            #1;
        end
    endtask


    initial begin
        /*
        Initial values.
        Starting everything at zero makes the waveform easier to read and
        prevents the testbench from beginning with unknown values.
        */
        clk = 1'b0;
        ALUA = 16'd0;
        ALUB = 16'd0;
        ALUop = 4'd0;
        error_count = 0;
        test_count = 0;
	RANDOM_TESTS = 1024;

        /*
        Directed tests.
        These tests check each required ALU operation with simple values.
        The values are intentionally easy to verify by hand.
        */
        $display("\nStarting directed ALU tests...\n");

        run_ALU_test(16'd5,   16'd0,   4'h0);    // NOP / passthrough
        run_ALU_test(16'd1,   16'd1,   4'h1);    // ADD: 1 + 1 = 2
        run_ALU_test(16'd4,   16'd2,   4'h2);    // SUB: 4 - 2 = 2
        run_ALU_test(16'd512, 16'd256, 4'h3);    // Passthrough: output ALUA
        run_ALU_test(16'd0,   16'd1,   4'h4);    // XOR: 0 ^ 1 = 1
        run_ALU_test(16'd0,   16'd1,   4'h5);    // OR: 0 | 1 = 1
        run_ALU_test(16'd1,   16'd1,   4'h6);    // AND: 1 & 1 = 1
        run_ALU_test(16'd256, 16'd0,   4'h7);    // Increment: 256 + 1 = 257

        /*
        Edge-case tests.
        These tests check cases that are easy to miss if only small decimal
        values are used. Since the ALU output is 16 bits wide, overflow and
        underflow wrap around naturally.
        */
        $display("\nStarting edge-case ALU tests...\n");

        run_ALU_test(16'hFFFF, 16'h0001, 4'h1);  // ADD rollover: FFFF + 1 = 0000
        run_ALU_test(16'h0000, 16'h0001, 4'h2);  // SUB underflow: 0000 - 1 = FFFF
        run_ALU_test(16'hFFFF, 16'h0000, 4'h7);  // Increment rollover: FFFF + 1 = 0000

        /*
        Alternating bit-pattern tests.
        A = AAAA gives the pattern 1010 1010 1010 1010.
        B = 5555 gives the pattern 0101 0101 0101 0101.

        These are useful for testing bitwise operations because each bit
        position has the opposite value in A and B.
        */
        run_ALU_test(16'hAAAA, 16'h5555, 4'h4);  // XOR should produce FFFF
        run_ALU_test(16'hAAAA, 16'h5555, 4'h5);  // OR should produce FFFF
        run_ALU_test(16'hAAAA, 16'h5555, 4'h6);  // AND should produce 0000

        /*
        Randomized tests.
        This loop runs 256 additional tests using random ALUA, ALUB, and
        ALUop values. Random testing helps catch mistakes that may not show
        up in the directed tests.
        ALUop is limited to 0 through 7 because the project ALU has eight
        legal operations.
        */
        $display("\nStarting randomized ALU tests...\n");

        for (i = 0; i < RANDOM_TESTS; i = i + 1) begin
            ALUA_rand  = $urandom_range(16'hFFFF, 16'h0000);
            ALUB_rand  = $urandom_range(16'hFFFF, 16'h0000);
            ALUop_rand = $urandom_range(4'h7, 4'h0);

            run_ALU_test(ALUA_rand, ALUB_rand, ALUop_rand);
        end

        /*
        Test summary.
        The summary gives the grader a clean final result in the transcript.
        If Total errors is zero, the ALU passed all directed, edge-case,
        and randomized tests.
        */
        $display("\nALU testing complete.");
        $display("Total tests: %0d", test_count);
        $display("Total errors: %0d\n", error_count);

        if (error_count == 0)
            $display("RESULT: All ALU tests passed.");
        else
            $display("RESULT: ALU testbench found %0d error(s).", error_count);

        $stop;
    end

endmodule