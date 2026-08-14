# turn on transcript
transcript on

# avoid stopping the script if ModelSim breaks at $finish
onbreak {resume}

# get rid of current rtl_work library
if {[file exists rtl_work]} {
    vdel -lib rtl_work -all
}

# create rtl_work library and map it to work
vlib rtl_work
vmap work rtl_work

# compile project source files
vlog -sv -work work +acc "./Project/Project.sv"
vlog -sv -work work +acc "./RAM/myRAM.v"
vlog -sv -work work +acc "./ROM/myROM.v"
vlog -sv -work work +acc "./Board/Decoder.sv"
vlog -sv -work work +acc "./Board/KeyFilter.sv"
vlog -sv -work work +acc "./Control_Unit/IR.sv"
vlog -sv -work work +acc "./Control_Unit/FSM.sv"
vlog -sv -work work +acc "./Control_Unit/Control_Unit.sv"
vlog -sv -work work +acc "./Datapath/Datapath.sv"
vlog -sv -work work +acc "./Project/Processor.sv"
vlog -sv -work work +acc "./Project/testProcessor.sv"

# run the main processor testbench
vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L rtl_work -L work -voptargs="+acc" -fsmdebug work.testProcessor

# load waveform setup
do wave.do

# set window views
view wave
view structure
view signals

# run simulation
run -all

# show full waveform
wave zoomfull

# end
