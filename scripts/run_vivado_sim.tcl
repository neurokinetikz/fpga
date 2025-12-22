# Vivado Simulation Script for Phi-N Neural Processor v5.5
# Run with: vivado -mode batch -source run_vivado_sim.tcl

# Set project parameters
set project_name "phi_n_neural"
set project_dir "./vivado_project"
set src_dir "../src"
set tb_dir "../tb"

# Create project
create_project $project_name $project_dir -part xc7z020clg400-1 -force

# Add source files
add_files -fileset sources_1 [glob $src_dir/*.v]

# Add simulation files
add_files -fileset sim_1 [glob $tb_dir/*.v]

# Set top module for synthesis
set_property top phi_n_neural_processor [get_filesets sources_1]

# Set top module for simulation
set_property top tb_full_system [get_filesets sim_1]

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Run simulation
launch_simulation -mode behavioral

# Run for 10ms of simulation time
run 10ms

# Generate reports
report_utilization -file "${project_dir}/utilization.rpt"

puts "========================================="
puts "Simulation Complete"
puts "========================================="
puts "Check waveforms in Vivado GUI or"
puts "view ${project_dir}/utilization.rpt for resource usage"
puts "========================================="

# Close simulation
close_sim

# Exit
exit
