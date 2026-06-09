`timescale 1ns/1ps

/*
Seth Amico, John Teal
UW TCES 330
Programmable Processor
Project File: Decoder.sv
10 June 2026

Description: This file contains a 4-bit hexadecimal to seven-segment display decoder.
The decoder is used to drive the DE board HEX displays.
*/

module Decoder(
input [3:0] Hex_In,
output logic [6:0] Hex_Out
);


/*
The DE board HEX displays are active-low. A segment value of 0 turns the segment on.
A segment value of 1 turns the segment off. Segment order: Hex_Out[6:0] = {g, f, e, d, c, b, a}
*/

always_comb begin
    case (Hex_In)
        4'h0: Hex_Out = 7'b1000000;
        4'h1: Hex_Out = 7'b1111001;
        4'h2: Hex_Out = 7'b0100100;
        4'h3: Hex_Out = 7'b0110000;
        4'h4: Hex_Out = 7'b0011001;
        4'h5: Hex_Out = 7'b0010010;
        4'h6: Hex_Out = 7'b0000010;
        4'h7: Hex_Out = 7'b1111000;
        4'h8: Hex_Out = 7'b0000000;
        4'h9: Hex_Out = 7'b0010000;
        4'hA: Hex_Out = 7'b0001000;
        4'hB: Hex_Out = 7'b0000011;
        4'hC: Hex_Out = 7'b1000110;
        4'hD: Hex_Out = 7'b0100001;
        4'hE: Hex_Out = 7'b0000110;
        4'hF: Hex_Out = 7'b0001110;
        default: Hex_Out = 7'b1111111;
    endcase
end

endmodule

module Decoder_tb();

logic [3:0] Hex_In;
logic [6:0] Hex_Out;

integer passes;
integer failures;

/*
Device under test. This testbench checks every hexadecimal input from 0 through F against the 
expected active-low seven-segment output pattern.
*/
Decoder dut(
    .Hex_In(Hex_In),
    .Hex_Out(Hex_Out)
);

// Check one decoder output. Case equality is used so unknown values are counted as failures.
task automatic check_decoder;
    input string name;
    input [3:0] value;
    input [6:0] expected;

    begin
        Hex_In = value;
        #1;

        if (Hex_Out === expected) begin
            passes = passes + 1;
            $display("PASS: %0s Hex_In=%h expected=%b actual=%b",
                     name, value, expected, Hex_Out);
        end
        else begin
            failures = failures + 1;
            $display("FAIL: %0s Hex_In=%h expected=%b actual=%b time=%0t",
                     name, value, expected, Hex_Out, $time);
        end
    end
endtask

initial begin
    $display("Starting Decoder testbench.");

    passes = 0;
    failures = 0;

    // Test all sixteen hexadecimal display values.
    check_decoder("display 0", 4'h0, 7'b1000000);
    check_decoder("display 1", 4'h1, 7'b1111001);
    check_decoder("display 2", 4'h2, 7'b0100100);
    check_decoder("display 3", 4'h3, 7'b0110000);
    check_decoder("display 4", 4'h4, 7'b0011001);
    check_decoder("display 5", 4'h5, 7'b0010010);
    check_decoder("display 6", 4'h6, 7'b0000010);
    check_decoder("display 7", 4'h7, 7'b1111000);
    check_decoder("display 8", 4'h8, 7'b0000000);
    check_decoder("display 9", 4'h9, 7'b0010000);
    check_decoder("display A", 4'hA, 7'b0001000);
    check_decoder("display B", 4'hB, 7'b0000011);
    check_decoder("display C", 4'hC, 7'b1000110);
    check_decoder("display D", 4'hD, 7'b0100001);
    check_decoder("display E", 4'hE, 7'b0000110);
    check_decoder("display F", 4'hF, 7'b0001110);

    // Print final test summary.
    $display("Decoder testbench complete.");
    $display("Passes: %0d", passes);
    $display("Failures: %0d", failures);

    if (failures == 0) begin
        $display("RESULT: PASS");
    end
    else begin
        $display("RESULT: FAIL");
    end

    $finish;
end

endmodule
