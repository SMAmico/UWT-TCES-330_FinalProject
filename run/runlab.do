transcript on
onbreak {resume}

if {[file exists work]} {
    vdel -lib work -all
}

vlib work
vmap work work

vlog -sv -work work +acc ./myRAM.v
vlog -sv -work work +acc ./myROM.v
vlog -sv -work work +acc ./Decoder.sv
vlog -sv -work work +acc ./KeyFilter.sv
vlog -sv -work work +acc ./PC.sv
vlog -sv -work work +acc ./IR.sv
vlog -sv -work work +acc ./FSM.sv
vlog -sv -work work +acc ./Control_Unit.sv
vlog -sv -work work +acc ./Datapath.sv
vlog -sv -work work +acc ./Processor.sv
vlog -sv -work work +acc ./Project.sv
vlog -sv -work work +acc ./testProcessor.sv

vsim -t 1ps \
    -L altera_ver \
    -L lpm_ver \
    -L sgate_ver \
    -L altera_mf_ver \
    -L altera_lnsim_ver \
    -L cyclonev_ver \
    -L work \
    -voptargs="+acc" \
    work.testProcessor

do wave.do

run -all
