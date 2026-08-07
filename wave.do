onerror {resume}
quietly WaveActivateNextPane {} 0
quietly delete wave *

# Custom symbolic radix maps for easier debug readability.
# Wrapped in catch blocks so the script still runs on simulators lacking custom radix support.
catch {
	radix define FSM_STATE {
		4'b0000 "S_INIT"
		4'b0001 "S_FETCH"
		4'b0010 "S_DEC"
		4'b0011 "S_NOP"
		4'b0100 "S_STR"
		4'b0101 "S_LDA"
		4'b0110 "S_LDB"
		4'b0111 "S_ALU"
		4'b1001 "S_HLT"
		4'b1010 "S_JMP"
		4'b1011 "S_JNZ_TEST"
		4'b1100 "S_JNZ_JUMP"
		4'b1101 "S_JLT_TEST"
		4'b1110 "S_JLT_JUMP"
	}
}

catch {
	radix define ISA_OPCODE {
		4'b0000 "INS_SHR"
		4'b0001 "INS_STR"
		4'b0010 "INS_LDR"
		4'b0011 "INS_ADD"
		4'b0100 "INS_SUB"
		4'b0101 "INS_HLT"
		4'b0110 "INS_MOVI"
		4'b0111 "INS_OR"
		4'b1000 "INS_AND/NOP"
		4'b1001 "INS_JMP"
		4'b1010 "INS_JNZ"
		4'b1011 "INS_JLT"
		4'b1100 "INS_SHL"
		4'b1101 "INS_MULT"
	}
}

# -----------------------------------------------------------------------------
# Top-level timing and architectural state
# -----------------------------------------------------------------------------
add wave -noupdate -divider {Clock and Reset}
add wave -noupdate -radix binary /testProcessor/Clk
add wave -noupdate -radix binary /testProcessor/ResetN

add wave -noupdate -divider {Architectural View}
add wave -noupdate -radix hexadecimal /testProcessor/PC_Out
add wave -noupdate -radix hexadecimal /testProcessor/IR_Out
add wave -noupdate -radix unsigned /testProcessor/State
add wave -noupdate -radix unsigned /testProcessor/NextState
add wave -noupdate -radix FSM_STATE /testProcessor/State
add wave -noupdate -radix FSM_STATE /testProcessor/NextState

# IR field breakdown: [15:12]=opcode, [11:8]=ra, [7:4]=rb/imm-hi, [3:0]=rc/imm-lo
add wave -noupdate -divider {IR Decode Fields}
add wave -noupdate -radix ISA_OPCODE /testProcessor/IR_Out[15:12]
add wave -noupdate -radix hexadecimal /testProcessor/IR_Out[15:12]
add wave -noupdate -radix hexadecimal /testProcessor/IR_Out[11:8]
add wave -noupdate -radix hexadecimal /testProcessor/IR_Out[7:4]
add wave -noupdate -radix hexadecimal /testProcessor/IR_Out[3:0]
add wave -noupdate -radix hexadecimal /testProcessor/IR_Out[7:0]
add wave -noupdate -radix hexadecimal /testProcessor/IR_Out[11:0]

# -----------------------------------------------------------------------------
# Control unit internals
# -----------------------------------------------------------------------------
add wave -noupdate -divider {Control Unit: PC and IR Control}
add wave -noupdate -radix binary /testProcessor/DUT/control0/PC_clr
add wave -noupdate -radix binary /testProcessor/DUT/control0/PC_up
add wave -noupdate -radix binary /testProcessor/DUT/control0/PC_w_en
add wave -noupdate -radix hexadecimal /testProcessor/DUT/control0/PC_set
add wave -noupdate -radix binary /testProcessor/DUT/control0/IR_ld
add wave -noupdate -radix hexadecimal /testProcessor/DUT/control0/IR_in
add wave -noupdate -radix hexadecimal /testProcessor/DUT/control0/IR_data

add wave -noupdate -divider {Control Unit: Register File and ALU Select}
add wave -noupdate -radix unsigned /testProcessor/DUT/RF_Ra_Addr
add wave -noupdate -radix unsigned /testProcessor/DUT/RF_Rb_Addr
add wave -noupdate -radix unsigned /testProcessor/DUT/RF_W_Addr
add wave -noupdate -radix binary /testProcessor/DUT/RF_W_en
add wave -noupdate -radix binary /testProcessor/DUT/RF_s
add wave -noupdate -radix unsigned /testProcessor/DUT/Alu_s0
add wave -noupdate -radix hexadecimal /testProcessor/DUT/MOVI_d
add wave -noupdate -radix unsigned /testProcessor/DUT/D_Addr_reg
add wave -noupdate -radix unsigned /testProcessor/DUT/D_Data_reg
add wave -noupdate -radix binary /testProcessor/DUT/D_wr

# -----------------------------------------------------------------------------
# Datapath and memory visibility
# -----------------------------------------------------------------------------
add wave -noupdate -divider {Datapath: ALU Ports and Flags}
add wave -noupdate -radix hexadecimal /testProcessor/ALU_A
add wave -noupdate -radix hexadecimal /testProcessor/ALU_B
add wave -noupdate -radix hexadecimal /testProcessor/ALU_Out
add wave -noupdate -radix binary /testProcessor/DUT/Alu_Z
add wave -noupdate -radix binary /testProcessor/DUT/Alu_N
add wave -noupdate -radix binary /testProcessor/DUT/Alu_V

add wave -noupdate -divider {Datapath: Memory Interface}
add wave -noupdate -radix hexadecimal /testProcessor/DUT/datapath0/D_Addr
add wave -noupdate -radix hexadecimal /testProcessor/DUT/datapath0/D_Data
add wave -noupdate -radix hexadecimal /testProcessor/DUT/datapath0/R_data
add wave -noupdate -radix hexadecimal /testProcessor/DUT/datapath0/W_data

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 0
configure wave -namecolwidth 280
configure wave -valuecolwidth 120
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 10
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {1000 ns}
