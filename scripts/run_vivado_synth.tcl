# Vivado Synthesis Script for Phi-N Neural Processor v5.5
# Run with: vivado -mode batch -source run_vivado_synth.tcl

# Set project parameters
set project_name "phi_n_neural"
set project_dir "./vivado_project"
set src_dir "../src"

# Create project
create_project $project_name $project_dir -part xc7z020clg400-1 -force

# Add source files
add_files -fileset sources_1 [glob $src_dir/*.v]

# Set top module
set_property top phi_n_neural_processor [get_filesets sources_1]

# Update compile order
update_compile_order -fileset sources_1

# Run synthesis
puts "========================================="
puts "Running Synthesis..."
puts "========================================="
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check synthesis status
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed!"
    exit 1
}

# Generate utilization report
open_run synth_1
report_utilization -file "${project_dir}/synth_utilization.rpt"
report_timing_summary -file "${project_dir}/synth_timing.rpt"

puts "========================================="
puts "Synthesis Complete"
puts "========================================="
puts "Reports generated:"
puts "  ${project_dir}/synth_utilization.rpt"
puts "  ${project_dir}/synth_timing.rpt"
puts "========================================="

# Close project
close_project

exit
