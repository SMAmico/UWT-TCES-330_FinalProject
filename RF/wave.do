# wave.do
# UW TCES 330
# Project Phase II
#
# Purpose:
# This waveform file organizes the RegFile_tb simulation signals so the
# register-file behavior can be checked visually in ModelSim.

# Clear any old signals from the waveform window.
delete wave *

# ------------------------------------------------------------
# Testbench control signals
# ------------------------------------------------------------
# clk:
# The register file writes on the positive edge of clk.
#
# write:
# When write = 1, wrData should be written into regfile[wrAddr]
# on the next positive clock edge.
#
# When write = 0, no register should be changed.
add wave -divider "Testbench Control"
add wave -radix binary		sim:/RegFile_tb/clk
add wave -radix binary		sim:/RegFile_tb/write

# ------------------------------------------------------------
# Register-file write port
# ------------------------------------------------------------
# wrAddr:
# Selects which of the 8 registers will be written.
#
# wrData:
# The 16-bit value that will be stored into the selected register.
#
# Expected behavior:
# The value on wrData should only enter the selected register on the
# positive edge of clk when write = 1.
add wave -divider "Write Port"
add wave -radix unsigned	sim:/RegFile_tb/wrAddr
add wave -radix hexadecimal	sim:/RegFile_tb/wrData

# ------------------------------------------------------------
# Register-file read ports
# ------------------------------------------------------------
# rdAddrA:
# Selects which register appears on rdDataA.
#
# rdDataA:
# The 16-bit output from read port A.
#
# rdAddrB:
# Selects which register appears on rdDataB.
#
# rdDataB:
# The 16-bit output from read port B.
#
# Expected behavior:
# Since the RegFile uses combinational reads, rdDataA and rdDataB
# should update shortly after rdAddrA or rdAddrB changes. They do
# not need to wait for a clock edge.
add wave -divider "Read Ports"
add wave -radix unsigned	sim:/RegFile_tb/rdAddrA
add wave -radix hexadecimal	sim:/RegFile_tb/rdDataA
add wave -radix unsigned	sim:/RegFile_tb/rdAddrB
add wave -radix hexadecimal	sim:/RegFile_tb/rdDataB

# ------------------------------------------------------------
# Testbench expected register values
# ------------------------------------------------------------
# expected[0] through expected[7]:
# These are not hardware registers inside the DUT. They are the
# testbench's local copy of what each register should contain.
#
# The testbench updates expected[] after valid writes, then compares
# rdDataA and rdDataB against expected[] during reads.
add wave -divider "Expected Register Values"
add wave -radix hexadecimal	{sim:/RegFile_tb/expected[0]}
add wave -radix hexadecimal	{sim:/RegFile_tb/expected[1]}
add wave -radix hexadecimal	{sim:/RegFile_tb/expected[2]}
add wave -radix hexadecimal	{sim:/RegFile_tb/expected[3]}
add wave -radix hexadecimal	{sim:/RegFile_tb/expected[4]}
add wave -radix hexadecimal	{sim:/RegFile_tb/expected[5]}
add wave -radix hexadecimal	{sim:/RegFile_tb/expected[6]}
add wave -radix hexadecimal	{sim:/RegFile_tb/expected[7]}

# ------------------------------------------------------------
# DUT internal register file
# ------------------------------------------------------------
# DUT/regfile[0] through DUT/regfile[7]:
# These are the actual internal registers inside the RegFile module.
#
# Comparing this section with the expected[] section makes it easier
# to visually confirm that the hardware model and the testbench model
# agree.
#
# Braces are used because Tcl treats square brackets as command syntax.
add wave -divider "DUT Internal Register File"
add wave -radix hexadecimal	{sim:/RegFile_tb/DUT/regfile[0]}
add wave -radix hexadecimal	{sim:/RegFile_tb/DUT/regfile[1]}
add wave -radix hexadecimal	{sim:/RegFile_tb/DUT/regfile[2]}
add wave -radix hexadecimal	{sim:/RegFile_tb/DUT/regfile[3]}
add wave -radix hexadecimal	{sim:/RegFile_tb/DUT/regfile[4]}
add wave -radix hexadecimal	{sim:/RegFile_tb/DUT/regfile[5]}
add wave -radix hexadecimal	{sim:/RegFile_tb/DUT/regfile[6]}
add wave -radix hexadecimal	{sim:/RegFile_tb/DUT/regfile[7]}

# ------------------------------------------------------------
# Testbench counters
# ------------------------------------------------------------
# pass_count:
# Counts successful output checks.
#
# fail_count:
# Counts failed output checks.
#
# The transcript gives the final PASS/FAIL result, but these counters
# are useful to see while stepping through the waveform.
add wave -divider "Testbench Counters"
add wave -radix decimal		sim:/RegFile_tb/pass_count
add wave -radix decimal		sim:/RegFile_tb/fail_count

# ------------------------------------------------------------
# Waveform display settings
# ------------------------------------------------------------
# These settings make the waveform easier to read.
configure wave -namecolwidth 260
configure wave -valuecolwidth 120
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -timelineunits ns

# Zoom to the approximate full simulation range.
# This can be adjusted after the simulation runs.
configure wave -timelineunits ps
WaveRestoreZoom {0 ps} {450 ps}