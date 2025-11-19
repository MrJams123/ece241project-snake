# Clean start
quit -sim
vlib work
vmap work work

# Compile everything in correct order
vlog ../snake.v          # your big file with all modules inside
vlog top.v               # the new wrapper above
vlog testbench.v         # your renamed snake_tb → testbench

# Launch simulation
vsim -voptargs=+acc work.testbench -Lf 220model -Lf altera_mf_ver -Lf verilog

# Waveform (if you have wave.do)
do wave.do

# Run forever (your testbench finishes itself)
run -all