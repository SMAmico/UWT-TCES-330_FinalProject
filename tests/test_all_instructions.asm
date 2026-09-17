; Comprehensive assembly test for EX_ISA instruction formats.
;
; Assembly formatting instructions:
; 1) Use .text for instructions and instruction labels.
; 2) Use .data for data directives and data labels.
; 3) Labels end with ':' and may appear on their own line.
; 4) Tokens are separated by whitespace and/or commas.
; 5) Comments may start with ';', '//' or '#'.
; 6) Registers are R0..R15 (case-insensitive); R14 is assembler scratch and R15 is PC.
; 7) Control-flow labels (JMP/JNZ/JLT and conditional pseudo-branch forms) must be .text labels.
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
    STR R1, R2, 16
    STR R1, R2, -16
    STR R1, data_ptr
    STR R1, data_ptr, 1
    STR R1, data_ptr, 300

    LDR R3, R4
    LDR R3, R4, -2
    LDR R3, R4, 16
    LDR R3, R4, -16
    LDR R3, data_ptr
    LDR R3, data_ptr, 2
    LDR R3, R4, -300

    COPY R1, R2
    COPY R1, R2, 3

    ADD R5, R1, R2
    SUB R6, R5, R1
    OR R9, R1, R2
    AND R10, R1, R2
    SHL R11, R1, 2
    SHR R12, R2, 1
    MULT R13, R1, R2
    XOR R4, R1, R2

    CMP R1, R2
    SETLT R3
    SETEQ R4
    SETNE R5
    SETLE R6
    SETGT R7
    SETGE R8

    MOVI R1, 1
    JNZ R1, R0, 2
    HLT
    MOVI R1, 0
    MOVI R2, 1
    JLT R1, R2, 1
    HLT

    JZ R1, branch_jz
branch_jz:
    JEQ R1, R2, branch_jeq
branch_jeq:
    JNE R1, 0x1234, branch_jne
branch_jne:
    JLE R1, R2, branch_jle
branch_jle:
    JGT R1, -1, branch_jgt
branch_jgt:
    JGE R1, R2, branch_jge
branch_jge:
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
