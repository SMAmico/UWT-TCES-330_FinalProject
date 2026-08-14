transcript on
onbreak {resume}

if {[file exists work]} {
    vdel -lib work -all
}

vlib work
vmap work work

# compile project source files
vlog -sv -work work +acc "./Project/testProcessor.sv"
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

# -----------------------------------------------------------------------------
# Memory debug visibility: ROM and RAM interface signals
# -----------------------------------------------------------------------------
add wave -noupdate -divider {Memory Debug: ROM Interface}
add wave -noupdate -radix hexadecimal /testProcessor/DUT/control0/rom0/address
add wave -noupdate -radix hexadecimal /testProcessor/DUT/control0/rom0/q

add wave -noupdate -divider {Memory Debug: RAM Wrapper Interface}
add wave -noupdate -radix hexadecimal /testProcessor/DUT/datapath0/ram0/D_Addr
add wave -noupdate -radix binary /testProcessor/DUT/datapath0/ram0/D_wr
add wave -noupdate -radix hexadecimal /testProcessor/DUT/datapath0/ram0/W_data
add wave -noupdate -radix hexadecimal /testProcessor/DUT/datapath0/ram0/R_data

add wave -noupdate -divider {Memory Debug: RAM LPM Ports}
add wave -noupdate -radix hexadecimal /testProcessor/DUT/datapath0/ram0/ram_lpm/address
add wave -noupdate -radix binary /testProcessor/DUT/datapath0/ram0/ram_lpm/wren
add wave -noupdate -radix hexadecimal /testProcessor/DUT/datapath0/ram0/ram_lpm/data
add wave -noupdate -radix hexadecimal /testProcessor/DUT/datapath0/ram0/ram_lpm/q

update

run -all
exit
