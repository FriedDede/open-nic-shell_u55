    read_verilog -quiet [glob -nocomplain -directory $module_dir/include/axi "*.{svh}"]
    read_verilog -quiet -sv [glob -nocomplain -directory $module_dir/src "*.sv"]