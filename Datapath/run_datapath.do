# run_datapath.do
# UW TCES 330
# Project Phase III
#
# Purpose:
# Compile Datapath.sv, load the Datapath_tb testbench, and run the Datapath
# integration simulation.

# Create the work library.
# If it already exists, ModelSim may print a warning. That is okay.
vlib work

# Compile the SystemVerilog file.
# Datapath.sv contains RegFile, ALU, RegALU, Mux16w_2to1, RAM, and Datapath_tb.
vlog -reportprogress 300 -sv Datapath.sv

# Load the Datapath testbench as the simulation top level.
# +acc keeps internal signals visible if we later want to inspect them.
# -t 1ps sets the simulation time resolution.
vsim -voptargs="+acc" -t 1ps work.Datapath_tb

# Run the simulation until the testbench reaches $finish.
run -all
