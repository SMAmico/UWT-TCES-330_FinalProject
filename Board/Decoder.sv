/*
Seth Amico, John Teal
UW TCES 330
Programmable Processor
Project File: Decoder.sv
10 June 2026
*/

module Decoder(
    input [3:0] Hex_In,
    output logic [6:0] Hex_Out
);

    /*
    Decoder converts a 4-bit hexadecimal value into the seven-segment pattern used by the DE board
    HEX displays.

    The DE board HEX displays are active-low:
        0 = segment on
        1 = segment off

    Segment order:
        Hex_Out[6:0] = {g, f, e, d, c, b, a}
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
