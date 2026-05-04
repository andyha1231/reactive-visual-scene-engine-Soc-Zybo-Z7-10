# update_hdmi_test_for_scenes.tcl
# Adds scene engine RTL files and reactive_scene_top.v to the existing
# hdmi_test project, then sets reactive_scene_top as the synthesis top.
# The rgb2dvi IP and HDMI constraints already exist in hdmi_test — no changes needed.
#
# Usage (from final_project/):
#   vivado -mode batch -source reactive-visual-scene-engine/scripts/update_hdmi_test_for_scenes.tcl

set repo_dir  [file normalize [file join [file dirname [info script]] ..]]
set proj_root [file dirname $repo_dir]
set proj_file [file join $proj_root hdmi_test hdmi_test.xpr]

if {![file exists $proj_file]} {
    error "hdmi_test project not found at $proj_file"
}

puts "INFO: Opening $proj_file"
open_project $proj_file

# ------------------------------------------------------------------
# Add scene engine RTL (linked, not copied)
# ------------------------------------------------------------------
set scene_files [list \
    [file join $repo_dir rtl scene_engine scene_loudness_pulse.v] \
    [file join $repo_dir rtl scene_engine scene_bass_bars.v] \
    [file join $repo_dir rtl scene_engine scene_treble_flash.v] \
    [file join $repo_dir rtl scene_engine scene_split_screen.v] \
    [file join $repo_dir rtl scene_engine scene_engine_top.v] \
    [file join $repo_dir rtl top          reactive_scene_top.v] \
]

foreach f $scene_files {
    if {![file exists $f]} {
        error "Missing file: $f"
    }
    if {[llength [get_files -quiet $f]] == 0} {
        add_files -norecurse -fileset sources_1 $f
        puts "INFO: Added $f"
    } else {
        puts "INFO: Already in project: [file tail $f]"
    }
}

# ------------------------------------------------------------------
# Set reactive_scene_top as synthesis top
# ------------------------------------------------------------------
set_property top reactive_scene_top [get_filesets sources_1]
update_compile_order -fileset sources_1

puts ""
puts "============================================================"
puts "hdmi_test project updated."
puts "Top module: reactive_scene_top"
puts ""
puts "NEXT: Open hdmi_test.xpr in Vivado GUI, then:"
puts "  1. Run Synthesis (F11)"
puts "  2. Run Implementation"
puts "  3. Generate Bitstream"
puts "  4. Program via Hardware Manager"
puts ""
puts "SW[1:0] = scene select (0-3)"
puts "SW[2]   = hold max amplitude"
puts "BTN0    = reset"
puts "LED[0]  = MMCM locked (should be ON)"
puts "============================================================"

close_project
