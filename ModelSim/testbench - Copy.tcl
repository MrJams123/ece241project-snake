# =============================================================
#  testbench.tcl – ModelSim/Questa simulation script
#  Works with: vga_demo.v  +  top.v  +  testbench.v
#  Hierarchy: /snake_tb/dut  =  top
# =============================================================

# ---------- 1. Clean work ----------
if {[file exists work]} { vdel -lib work -all }
vlib work
vmap work work

# ---------- 2. Compile ----------
vlog -sv \
    ../vga_demo.v \
    top.v \
    testbench.v

# ---------- 3. Load testbench ----------
vsim -voptargs=+acc work.snake_tb

# ---------- 4. Waveform ----------
do wave.do

# ---------- 5. Run ----------
run -all