# runlab.do
# UW TCES 330
# Project Phase II
#
# Purpose:
# Compile RegFile.sv, load the RegFile_tb testbench, load wave.do,
# and run the simulation.

# Create the work library.
# If the library already exists, ModelSim may print a warning. That is okay.
vlib work

# Compile the SystemVerilog file.
# The -sv flag tells ModelSim to compile using SystemVerilog syntax.
vlog -reportprogress 300 -sv RegFile.sv

# Load the RegFile testbench as the top-level simulation module.
# +acc keeps internal signals visible for debugging in the waveform window.
# -t 1ps sets the simulation time resolution.
vsim -voptargs="+acc" -t 1ps work.RegFile_tb

# Load the waveform setup.
do wave.do

# Run the simulation until the testbench reaches $stop.
run -all