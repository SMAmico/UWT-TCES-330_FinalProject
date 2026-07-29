; Sample assembly for assembler-EX_ISA
; Demonstrates register ALU ops, MULT, and control flow.

START:
    NOP
    ADD R1, R2, R3    ; R3 = R1 + R2
    MULT R3, R4, R5   ; R5 = R3 * R4
    JLT R1, R2, SKIP  ; branch forward if R1 < R2
    XOR R5, R5, R6    ; execute when no branch
SKIP:
    SHL R5, R7, R8    ; R8 = R5 << R7
    JNZ R5, R7        ; if R5 != 0, jump to address in R7 (offset defaults to 0)
    JNZ R5, R7, -1    ; optional signed 4-bit offset form
    JMP DONE
    HLT
DONE:
    HLT
