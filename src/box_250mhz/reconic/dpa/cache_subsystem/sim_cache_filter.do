# ============================================================================
# Questa Simulator Tcl Script for Cache Subsystem
# ============================================================================

# 1. Set the top-level testbench name here. 
# Change this to "tb_page_mover" when you want to test the DMA alone.
set TOP_LEVEL "tb_cache_filter"

# Quit any currently running simulation to free up the workspace

# 2. Rebuild the 'work' library from scratch to ensure a clean compile
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

echo "--- Starting Compilation ---"

# 3. Compile Packages FIRST
# SystemVerilog requires packages to be compiled before modules that import them.
# If the PULP AXI library has specific packages, compile them explicitly here:
vlog -sv -work work +incdir+../axi_pulp/include/axi/ ../axi_pulp/src/axi_pkg.sv
vlog -sv -work work +incdir+../axi_pulp/include/axi/ ./cache_ss_pkg.sv

# 4. Compile the AXI PULP directory files
# +incdir+ allows the compiler to find `include "axi_assign.svh" etc.
vlog -sv -work work +incdir+../axi_pulp/include/axi/ ../axi_pulp/src/axi_intf.sv

# 5. Compile the current directory files (Cache controller, DMA, Testbenches)
vlog -sv -work work +incdir+../axi_pulp/include/axi/ +incdir+. ./*.sv

echo "--- Compilation Complete ---"

# 6. Load the simulation
# -voptargs=+acc ensures that signals are not optimized away, allowing you to 
# view them in the waveform window.
echo "--- Loading $TOP_LEVEL ---"
vsim -voptargs=+acc work.$TOP_LEVEL

# 7. Add waveforms
# Opens the wave window and adds all signals in the top level.
# 'add wave -r' would add recursively, but can freeze Questa if the design is massive.
view wave
add wave -r -position insertpoint sim:/$TOP_LEVEL/*

# Optional: Add specific internal signals to the wave window for debugging
# add wave -position insertpoint sim:/$TOP_LEVEL/dut/read_control_fsm/*

# 8. Run the simulation
# Runs until it hits a $finish statement in your testbench
run -all

echo "--- Simulation Complete ---"