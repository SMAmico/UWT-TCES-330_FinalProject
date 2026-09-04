; Correctness test for the .word/.space/.string/.long/.quad data directives.
;
; Every .data label below is placed so its final address is <=255, which means each
; verification MOVI encodes as a single word: 0x6 | reg<<8 | addr. The comment beside
; each MOVI states the expected assembled hex word so the output file can be checked
; by inspection (run: assembler-EX_ISA test_data_directives.asm test_data_directives.txt).
;
; Expected data addresses (word-addressed):
;   zero_pad   = 0   (.word, 1 word)
;   str_hello  = 1   ("Hi!" -> 3 chars + null = 4 chars -> ceil(4/2) = 2 words: 1..2)
;   str_esc    = 3   ("A\n" -> A + escape(\n) = 2 chars + null = 3 -> ceil(3/2) = 2 words: 3..4)
;   long_vals  = 5   (.long x2 values -> 2*2 = 4 words: 5..8)
;   quad_val   = 9   (.quad x1 value -> 1*4 = 4 words: 9..12)
;   word_vals  = 13  (.word x3 values -> 3 words: 13..15)
;   pad_space  = 16  (.space 5 -> 5 words: 16..20)
;   tail_word  = 21  (.word, 1 word)

.text
    MOVI R1, zero_pad     ; expect 0x6100
    MOVI R2, str_hello    ; expect 0x6201
    MOVI R3, str_esc      ; expect 0x6303
    MOVI R4, long_vals    ; expect 0x6405
    MOVI R5, quad_val     ; expect 0x6509
    MOVI R6, word_vals    ; expect 0x660D
    MOVI R7, pad_space    ; expect 0x6710
    MOVI R8, tail_word    ; expect 0x6815
    HLT                   ; expect 0x5000

.data
zero_pad:  .word 0
str_hello: .string "Hi!"
str_esc:   .string "A\n"
long_vals: .long 1, 70000
quad_val:  .quad 5000000000
word_vals: .word 0x1111, 0x2222, 0x3333
pad_space: .space 5
tail_word: .word 0xBEEF
