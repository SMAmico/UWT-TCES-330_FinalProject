transcript on

onbreak {resume}

if {[file exists work]} {
vdel -lib work -all
}

vlib work
vmap work work

puts "\n============================================================"
puts "Compiling project source files"
puts "============================================================"

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

proc run_tb {tb} {
puts "\n============================================================"
puts "Running $tb"
puts "============================================================"

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L work -voptargs="+acc" work.$tb

onfinish stop
run -all
quit -sim -force

}

run_tb PC_tb
run_tb IR_tb
run_tb Decoder_tb
run_tb FSM_tb
run_tb myROM_tb
run_tb myRAM_tb
run_tb Datapath_tb
run_tb Control_Unit_tb
run_tb Processor_tb
run_tb testProcessor

puts "\n============================================================"
puts "All requested testbenches have been run."
puts "Check transcript for RESULT: PASS lines and any FAIL messages."
puts "============================================================"
