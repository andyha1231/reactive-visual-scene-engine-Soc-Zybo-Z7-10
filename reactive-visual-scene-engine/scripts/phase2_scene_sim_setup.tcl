# phase2_scene_sim_setup.tcl
# Creates the phase2_scene_sim Vivado project for scene module testbenches.
# Links all scene RTL, video RTL, and scene testbenches.
# Usage: vivado -mode batch -source reactive-visual-scene-engine/scripts/phase2_scene_sim_setup.tcl

set repo_dir  [file normalize [file join [file dirname [info script]] ..]]
set proj_root [file dirname $repo_dir]
set proj_dir  [file join $proj_root phase2_scene_sim]
set proj_file [file join $proj_dir phase2_scene_sim.xpr]

puts "INFO: repo_dir = $repo_dir"
puts "INFO: proj_dir = $proj_dir"

# ------------------------------------------------------------------
# Create or open project
# ------------------------------------------------------------------
if {[file exists $proj_file]} {
    puts "INFO: Opening existing project $proj_file"
    open_project $proj_file
} else {
    puts "INFO: Creating new project at $proj_dir"
    create_project phase2_scene_sim $proj_dir -part xc7z010clg400-1
    set_property board_part digilentinc.com:zybo-z7-10:part0:1.2 [current_project]
    set_property target_language Verilog [current_project]
    set_property simulator_language Mixed [current_project]
}

# ------------------------------------------------------------------
# RTL design sources (scene engine + video)
# ------------------------------------------------------------------
set rtl_sources [list \
    [file join $repo_dir rtl scene_engine scene_loudness_pulse.v] \
    [file join $repo_dir rtl scene_engine scene_bass_bars.v] \
    [file join $repo_dir rtl scene_engine scene_treble_flash.v] \
    [file join $repo_dir rtl scene_engine scene_split_screen.v] \
    [file join $repo_dir rtl scene_engine scene_engine_top.v] \
    [file join $repo_dir rtl video        vga_sync.v] \
    [file join $repo_dir rtl video        vga_controller.v] \
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
# Simulation sources (scene testbenches)
# ------------------------------------------------------------------
set tb_sources [list \
    [file join $repo_dir tb tb_scene_loudness_pulse.v] \
    [file join $repo_dir tb tb_scene_bass_bars.v] \
    [file join $repo_dir tb tb_scene_treble_flash.v] \
    [file join $repo_dir tb tb_scene_split_screen.v] \
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
set_property top tb_scene_loudness_pulse [get_filesets sim_1]
set_property top_lib xil_defaultlib      [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts ""
puts "============================================================"
puts "phase2_scene_sim project ready."
puts "Open: $proj_file"
puts ""
puts "Scene simulation sequence:"
puts "  set_property top tb_scene_loudness_pulse [get_filesets sim_1]"
puts "  launch_simulation; run 2ms"
puts ""
puts "  set_property top tb_scene_bass_bars [get_filesets sim_1]"
puts "  relaunch_sim; run 2ms"
puts ""
puts "  set_property top tb_scene_treble_flash [get_filesets sim_1]"
puts "  relaunch_sim; run 10ms"
puts ""
puts "  set_property top tb_scene_split_screen [get_filesets sim_1]"
puts "  relaunch_sim; run 10ms"
puts "============================================================"

close_project
