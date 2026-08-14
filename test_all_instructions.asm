; Comprehensive assembly test for EX_ISA instruction formats.
;
; Assembly formatting instructions:
; 1) Use .text for instructions and instruction labels.
; 2) Use .data for data directives and data labels.
; 3) Labels end with ':' and may appear on their own line.
; 4) Tokens are separated by whitespace and/or commas.
; 5) Comments may start with ';', '//' or '#'.
; 6) Registers are R1..R13 (case-insensitive).
; 7) Control-flow labels (JMP/JNZ/JLT label form) must be .text labels.
; 8) Memory-address labels (STR/LDR label form) must be .data labels.

.text
start:
    NOP
    MOVI R1, 1
    MOVI R2, 2
    MOVI R7, 0x1234
    MOVI R8, data_ptr

    STR R1, R2
    STR R1, R2, 3
    STR R1, data_ptr
    STR R1, data_ptr, 1

    LDR R3, R4
    LDR R3, R4, -2
    LDR R3, data_ptr
    LDR R3, data_ptr, 2

    ADD R5, R1, R2
    SUB R6, R5, R1
    OR R9, R1, R2
    AND R10, R1, R2
    SHL R11, R1, 2
    SHR R12, R2, 1
    MULT R13, R1, R2
    XOR R4, R1, R2

    JNZ branch_target, R1
    NOP
branch_target:
    JLT R1, R2, branch_fallthrough
    NOP
branch_fallthrough:
    JMP done
done:
    HLT

.data
data_ptr:
    .word 0
    .word 0x22
array_base:
    .space 4
; this is how a global variable would be defined.
; global variables would keep this label in 
global_base:
    .word 0x1234
test_var:
    .word 0x5678
