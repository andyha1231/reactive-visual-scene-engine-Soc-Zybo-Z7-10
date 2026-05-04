################################################################################
# phase3_project_cleanup.tcl
# Run from Vivado TCL console with phase3_integration.xpr open.
# Cleans up design sources for Phase 3B synthesis:
#   - Adds reactive_scene_top_ps.v (the actual Phase 3B top)
#   - Removes Phase 3A top (reactive_scene_top.v) from synthesis
#   - Removes unused vga_controller.v from synthesis
#   - Re-enables all AutoDisabled RTL needed for Phase 3B
#   - Sets correct top module
#   - Keeps all 9 testbenches in sim fileset (verification portfolio)
################################################################################

# ── 1. Add missing Phase 3B top-level file ────────────────────────────────────
add_files -fileset sources_1 -norecurse \
    {../reactive-visual-scene-engine/rtl/top/reactive_scene_top_ps.v}

# ── 2. Remove Phase 3A top and unused files from synthesis ───────────────────
# reactive_scene_top.v — PL-only Phase 3A, no longer the synthesis top
remove_files -fileset sources_1 \
    [get_files -of_objects [get_filesets sources_1] \
        {*reactive_scene_top.v}]

# vga_controller.v — legacy reference file, not instantiated anywhere
remove_files -fileset sources_1 \
    [get_files -of_objects [get_filesets sources_1] \
        {*vga_controller.v}]

# ── 3. Enable all AutoDisabled RTL needed for Phase 3B ───────────────────────
foreach f {
    amplitude_detector.v
    audio_sample_reader.v
    band_energy.v
    feature_extraction_top.v
    scene_ctrl_v1_0.v
    scene_ctrl_v1_0_S00_AXI.v
} {
    set matched [get_files -quiet -of_objects [get_filesets sources_1] *$f]
    if {$matched ne ""} {
        set_property IS_ENABLED 1 [get_files $matched]
        puts "Enabled: $f"
    } else {
        puts "WARNING: $f not found in project — add manually if missing"
    }
}

# Enable the block design and generated wrapper
set bd_file [get_files -quiet -of_objects [get_filesets sources_1] {*design_1.bd}]
if {$bd_file ne ""} {
    set_property IS_ENABLED 1 [get_files $bd_file]
    puts "Enabled: design_1.bd"
}

set wrapper [get_files -quiet -of_objects [get_filesets sources_1] {*design_1_wrapper.v}]
if {$wrapper ne ""} {
    set_property IS_ENABLED 1 [get_files $wrapper]
    puts "Enabled: design_1_wrapper.v"
}

# ── 4. Set Phase 3B top module ────────────────────────────────────────────────
set_property top     reactive_scene_top_ps [get_filesets sources_1]
set_property top_lib xil_defaultlib        [get_filesets sources_1]
puts "Top set to: reactive_scene_top_ps"

# ── 5. Constraints — keep HDMI xdc, remove VGA xdc ───────────────────────────
set vga_xdc [get_files -quiet -of_objects [get_filesets constrs_1] {*vga*.xdc}]
if {$vga_xdc ne ""} {
    remove_files -fileset constrs_1 [get_files $vga_xdc]
    puts "Removed from constraints: zybo_z7_vga.xdc"
}
# Confirm HDMI xdc is present
set hdmi_xdc [get_files -quiet -of_objects [get_filesets constrs_1] {*hdmi*.xdc}]
if {$hdmi_xdc ne ""} {
    puts "Constraints OK: zybo_z7_hdmi.xdc present"
} else {
    puts "WARNING: zybo_z7_hdmi.xdc not found in constrs_1 — add it manually"
}

# ── 6. Sim fileset — keep all 9 testbenches, just confirm ────────────────────
puts ""
puts "Simulation fileset (testbenches — keep all for verification portfolio):"
foreach tb [get_files -quiet -of_objects [get_filesets sim_1] {*tb_*.v}] {
    puts "  [file tail $tb]"
}

# ── 7. Reset synthesis so it picks up the new top ────────────────────────────
reset_run synth_1
reset_run impl_1

# ── 8. Summary ────────────────────────────────────────────────────────────────
puts ""
puts "======================================================="
puts "  Design sources — Phase 3B synthesis:"
foreach f [get_files -of_objects [get_filesets sources_1]] {
    set tail [file tail $f]
    set ena  [get_property IS_ENABLED [get_files $f]]
    if {$ena} { puts "  [format %-45s $tail] ENABLED" } \
    else       { puts "  [format %-45s $tail] disabled" }
}
puts ""
puts "  Top module : [get_property top [get_filesets sources_1]]"
puts "  Synth run  : RESET — ready to launch"
puts "======================================================="
