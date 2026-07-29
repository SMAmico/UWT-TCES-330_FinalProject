; Sample assembly for assembler
; Demonstrates register ALU ops, LDR, and control flow.

START:
    NOP
    ADD R1, R2, R3    ; R3 = R1 + R2
    SUB R3, R4, R5    ; R5 = R3 - R4
    LDR R11, R1       ; R11 = RAM[RF[R1]]
    JLT R1, R2, SKIP  ; branch forward if R1 < R2
    SUB R5, R5, R6    ; execute when no branch
SKIP:
    ADD R5, R11, R11    ; R11 = R5 + R11
    JNZ R11, R10         ; if R11 != 0, jump to address in R10
    JNZ R11, R10, 1      ; same jump base with +1 optional offset
    STR R11, R1         ; RAM[RF[R1]] = R11
    JMP DONE
    HLT
DONE:
    HLT
