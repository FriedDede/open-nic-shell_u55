    read_verilog -quiet [glob -nocomplain -directory $module_dir/replication_subsystem "*.{v,vh}"]
    read_verilog -quiet -sv [glob -nocomplain -directory $module_dir/replication_subsystem "*.sv"]