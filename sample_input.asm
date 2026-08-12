; Sample assembly for assembler-EX_ISA
; Simple check program for .mif init

START:
    NOP
    MOVI    R1, 0x0001      ; R1 = 1
    MOVI    R2, 0x0002      ; R2 = 2
    ADD     R3, R1, R2      ; R3 = R1 + R2
    JLT     R3, R2, LESS    ;
    JMP ERROR               ;
LESS:
    MOVI    R4, 0xFFFF      ; R4 = -1 to show we finished the program correctly
    STR     R4, R0      ; store R4 to 0x0000
    HLT
ERROR:
    MOVI    R4, 0x0001      ; R4 = 1 to show we finished the program incorrectly
    STR     R4, R0      ; Store R4 to memory address 0x0000
    HLT
