; Sample assembly for assembler
; Demonstrates register ALU ops, LDR, and control flow.

START:
    NOP
    ADD R1, R2, R3    ; R3 = R1 + R2
    SUB R3, R4, R5    ; R5 = R3 - R4
    LDR 0x00, R11     ; R11 = RAM[00]
    JLT R1, R2, SKIP  ; branch forward if R1 < R2
    SUB R5, R5, R6    ; execute when no branch
SKIP:
    ADD R5, R11, R11    ; R11 = R5 + R11
    STR R11, 0x00       ; RAM[00] = R11
    JMP DONE
    HLT
DONE:
    HLT
