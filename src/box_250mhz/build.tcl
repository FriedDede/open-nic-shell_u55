# This is a generated file. Do not modify by hand
# cmd: ../scripts/build_tcl.py -nic rdma-opennic

add_files ./box_250mhz.sv
add_files ./rdma_onic_plugin.sv
add_files ./reconic_address_map.sv
add_files ./reconic/packet_classification/packet_filter.sv
add_files ./reconic/packet_classification/packet_classification.sv
add_files ./reconic/top/reconic.sv
add_files ./reconic/lookside/cl_box.v
add_files ./reconic/lookside/mmult_systolic_m_axi.v
add_files ./reconic/lookside/cl_box_cl_box_Pipeline_1.v
add_files ./reconic/lookside/control_command_processor.sv
add_files ./reconic/lookside/mmult_mmult_Pipeline_4.v
add_files ./reconic/lookside/cl_box_cl_box_Pipeline_VITIS_LOOP_22_1.v
add_files ./reconic/lookside/mmult_mul_32s_32s_32_2_1.v
add_files ./reconic/lookside/mmult_flow_control_loop_pipe_sequential_init.v
add_files ./reconic/lookside/cl_box_cmd_array_RAM_AUTO_1R1W.v
add_files ./reconic/lookside/mmult_mmult_Pipeline_1.v
add_files ./reconic/lookside/mmult_localA_RAM_AUTO_1R1W.v
add_files ./reconic/lookside/mmult_mmult_Pipeline_2.v
add_files ./reconic/lookside/mmult_mmult_Pipeline_systolic1.v
add_files ./reconic/lookside/cl_box_flow_control_loop_pipe_sequential_init.v
add_files ./reconic/lookside/mmult_sparsemux_33_4_32_1_1.v
add_files ./reconic/lookside/compute_logic_wrapper.sv
add_files ./reconic/lookside/mmult.v
add_files ./reconic/utilities/rn_reg_control.sv

