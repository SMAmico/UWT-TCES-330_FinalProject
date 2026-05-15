# runlab.do
# UW TCES 330
# Project Phase II

vlib work

vlog -reportprogress 300 -sv RegALU.sv

vsim -voptargs="+acc" -t 1ps work.RegALU_tb

do wave.do

run -all
