# phase1_sim_setup.tcl
# Creates or opens the phase1_sim Vivado project.
# Links audio RTL + all audio/video testbenches. Sets tb_amplitude_detector as default top.
# Usage: vivado -mode batch -source reactive-visual-scene-engine/scripts/phase1_sim_setup.tcl

set repo_dir   [file normalize [file join [file dirname [info script]] ..]]
set proj_root  [file dirname $repo_dir]
set proj_dir   [file join $proj_root phase1_sim]
set proj_file  [file join $proj_dir phase1_sim.xpr]

puts "INFO: repo_dir  = $repo_dir"
puts "INFO: proj_dir  = $proj_dir"

# ------------------------------------------------------------------
# Create or open project
# ------------------------------------------------------------------
if {[file exists $proj_file]} {
    puts "INFO: Opening existing project $proj_file"
    open_project $proj_file
} else {
    puts "INFO: Creating new project at $proj_dir"
    create_project phase1_sim $proj_dir -part xc7z010clg400-1
    set_property board_part digilentinc.com:zybo-z7-10:part0:1.2 [current_project]
    set_property target_language Verilog [current_project]
    set_property simulator_language Mixed [current_project]
}

# ------------------------------------------------------------------
# RTL design sources (audio pipeline)
# ------------------------------------------------------------------
set rtl_sources [list \
    [file join $repo_dir rtl audio         audio_sample_reader.v] \
    [file join $repo_dir rtl feature_extraction amplitude_detector.v] \
    [file join $repo_dir rtl feature_extraction band_energy.v] \
    [file join $repo_dir rtl feature_extraction feature_extraction_top.v] \
]

foreach src $rtl_sources {
    if {![file exists $src]} { error "Missing RTL: $src" }
    if {[llength [get_files -quiet $src]] == 0} {
        add_files -norecurse -fileset sources_1 $src
        puts "INFO: Added $src"
    } else {
        puts "INFO: Already in project: $src"
    }
}

# ------------------------------------------------------------------
# Simulation sources (testbenches)
# ------------------------------------------------------------------
set tb_sources [list \
    [file join $repo_dir tb tb_amplitude_detector.v] \
    [file join $repo_dir tb tb_band_energy.v] \
    [file join $repo_dir tb tb_feature_extraction_top.v] \
    [file join $repo_dir tb tb_audio_sample_reader.v] \
    [file join $repo_dir tb tb_vga_sync.v] \
]

foreach tb $tb_sources {
    if {![file exists $tb]} {
        puts "WARNING: Testbench not found (skip): $tb"
        continue
    }
    if {[llength [get_files -quiet -of_objects [get_filesets sim_1] $tb]] == 0} {
        add_files -norecurse -fileset sim_1 $tb
        puts "INFO: Added testbench $tb"
    } else {
        puts "INFO: TB already in sim_1: $tb"
    }
}

# ------------------------------------------------------------------
# Set default simulation top
# ------------------------------------------------------------------
set_property top tb_amplitude_detector [get_filesets sim_1]
set_property top_lib xil_defaultlib    [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts ""
puts "============================================================"
puts "phase1_sim project ready."
puts "Open: $proj_file"
puts ""
puts "To run simulations, use the Vivado TCL console:"
puts "  set_property top tb_amplitude_detector [get_filesets sim_1]"
puts "  launch_simulation; run 5ms"
puts ""
puts "  set_property top tb_band_energy [get_filesets sim_1]"
puts "  relaunch_sim; run 5ms"
puts ""
puts "  set_property top tb_feature_extraction_top [get_filesets sim_1]"
puts "  relaunch_sim; run 20ms"
puts "============================================================"

close_project
