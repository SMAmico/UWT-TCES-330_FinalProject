# run_regalu.do
# UW TCES 330
# Project Phase II
#
# Purpose:
# Compile RegALU.sv, load the RegALU_tb testbench, and run the RegALU
# integration simulation.

# Create the work library.
# If it already exists, ModelSim may print a warning. That is okay.
vlib work

# Compile the SystemVerilog file.
# RegALU.sv contains RegFile, ALU, RegALU, and RegALU_tb.
vlog -reportprogress 300 -sv RegALU.sv

# Load the RegALU testbench as the simulation top level.
# +acc keeps internal signals visible if we later want to inspect them.
# -t 1ps sets the simulation time resolution.
vsim -voptargs="+acc" -t 1ps work.RegALU_tb

# Run the simulation until the testbench reaches $finish.
run -all
