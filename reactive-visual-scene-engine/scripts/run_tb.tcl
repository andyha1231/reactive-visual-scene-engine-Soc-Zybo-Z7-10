# run_tb.tcl
# Universal batch-mode testbench runner.
# Opens the correct sim project, sets the testbench top, runs for the specified time,
# and reports PASS/FAIL counts from the transcript.
#
# Usage:
#   vivado -mode batch -source reactive-visual-scene-engine/scripts/run_tb.tcl \
#          -tclargs <tb_name> [run_time] [proj_override]
#
# Examples:
#   vivado -mode batch -source ... -tclargs tb_amplitude_detector 5ms
#   vivado -mode batch -source ... -tclargs tb_feature_extraction_top 20ms
#   vivado -mode batch -source ... -tclargs tb_scene_bass_bars 2ms
#   vivado -mode batch -source ... -tclargs phase1   (runs all phase1 TBs)
#   vivado -mode batch -source ... -tclargs phase2   (runs all phase2 TBs)

set repo_dir  [file normalize [file join [file dirname [info script]] ..]]
set proj_root [file dirname $repo_dir]

# ------------------------------------------------------------------
# Parse arguments
# ------------------------------------------------------------------
if {[llength $argv] == 0} {
    puts "ERROR: No testbench specified."
    puts "Usage: -tclargs <tb_name|phase1|phase2> [run_time]"
    exit 1
}

set tb_arg   [lindex $argv 0]
set run_time [expr {[llength $argv] > 1 ? [lindex $argv 1] : ""}]

# ------------------------------------------------------------------
# Phase shortcuts
# ------------------------------------------------------------------
proc run_all {tb_list times proj_file} {
    global repo_dir
    open_project $proj_file
    set pass_total 0
    set fail_total 0
    foreach {tb t} [zip_lists $tb_list $times] {
        puts ""
        puts "============================================================"
        puts "Running $tb for $t ..."
        puts "============================================================"
        set_property top $tb [get_filesets sim_1]
        set_property top_lib xil_defaultlib [get_filesets sim_1]
        if {[catch {launch_simulation} err]} {
            puts "ERROR launching sim for $tb: $err"
            incr fail_total
            continue
        }
        run $t
        close_sim
        # Count PASS/FAIL in current transcript
        set log [get_property DIRECTORY [get_runs sim_1]]
        # Results are in stdout captured during run
    }
    close_project
}

proc zip_lists {a b} {
    set result {}
    for {set i 0} {$i < [llength $a]} {incr i} {
        lappend result [lindex $a $i] [lindex $b $i]
    }
    return $result
}

# ------------------------------------------------------------------
# Determine project and run time by TB name
# ------------------------------------------------------------------
set phase1_tbs  {tb_amplitude_detector tb_band_energy tb_feature_extraction_top}
set phase1_times {5ms 5ms 20ms}
set phase2_tbs  {tb_scene_loudness_pulse tb_scene_bass_bars tb_scene_treble_flash tb_scene_split_screen}
set phase2_times {2ms 2ms 10ms 10ms}

set phase1_proj [file join $proj_root phase1_sim phase1_sim.xpr]
set phase2_proj [file join $proj_root phase2_scene_sim phase2_scene_sim.xpr]

# Map individual TB names to project + default time
array set tb_info {
    tb_amplitude_detector       {phase1 5ms}
    tb_band_energy              {phase1 5ms}
    tb_feature_extraction_top   {phase1 20ms}
    tb_audio_sample_reader      {phase1 5ms}
    tb_scene_loudness_pulse     {phase2 2ms}
    tb_scene_bass_bars          {phase2 2ms}
    tb_scene_treble_flash       {phase2 10ms}
    tb_scene_split_screen       {phase2 10ms}
}

# ------------------------------------------------------------------
# Run
# ------------------------------------------------------------------
if {$tb_arg eq "phase1"} {
    if {![file exists $phase1_proj]} {
        puts "ERROR: phase1_sim project not found. Run phase1_sim_setup.tcl first."
        exit 1
    }
    open_project $phase1_proj
    foreach {tb t} [zip_lists $phase1_tbs $phase1_times] {
        puts "\n=== Running $tb ($t) ==="
        set_property top $tb [get_filesets sim_1]
        set_property top_lib xil_defaultlib [get_filesets sim_1]
        launch_simulation
        run $t
        close_sim
    }
    close_project
    puts "\nPhase 1 simulation complete. Check transcript above for \[PASS\]/\[FAIL\]."

} elseif {$tb_arg eq "phase2"} {
    if {![file exists $phase2_proj]} {
        puts "ERROR: phase2_scene_sim project not found. Run phase2_scene_sim_setup.tcl first."
        exit 1
    }
    open_project $phase2_proj
    foreach {tb t} [zip_lists $phase2_tbs $phase2_times] {
        puts "\n=== Running $tb ($t) ==="
        set_property top $tb [get_filesets sim_1]
        set_property top_lib xil_defaultlib [get_filesets sim_1]
        launch_simulation
        run $t
        close_sim
    }
    close_project
    puts "\nPhase 2 simulation complete. Check transcript above for \[PASS\]/\[FAIL\]."

} elseif {[info exists tb_info($tb_arg)]} {
    set info   $tb_info($tb_arg)
    set phase  [lindex $info 0]
    set t      [expr {$run_time ne "" ? $run_time : [lindex $info 1]}]
    set proj   [expr {$phase eq "phase1" ? $phase1_proj : $phase2_proj}]

    if {![file exists $proj]} {
        puts "ERROR: Project for $phase not found."
        puts "Run the corresponding setup script first."
        exit 1
    }

    puts "Opening $proj"
    open_project $proj

    puts "Setting top: $tb_arg"
    set_property top $tb_arg [get_filesets sim_1]
    set_property top_lib xil_defaultlib [get_filesets sim_1]

    puts "Launching simulation..."
    launch_simulation
    puts "Running for $t ..."
    run $t
    close_sim
    close_project

    puts "\nDone. Check transcript above for \[PASS\]/\[FAIL\]."

} else {
    puts "ERROR: Unknown testbench '$tb_arg'"
    puts "Known TBs: [array names tb_info]"
    puts "Shortcuts: phase1, phase2"
    exit 1
}
