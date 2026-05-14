# Create work library
vlib work

# Compile SystemVerilog file
# This file contains both the ALU module and the ALU_tb testbench.
vlog -reportprogress 300 "./ALU.sv"

# Start simulation using the ALU testbench.
vsim -voptargs="+acc" -t 1ps -lib work ALU_tb

# Load waveform setup.
do ALU_wave.do

# Open useful simulation windows.
view wave
view structure
view signals

# Run the full testbench.
run -all