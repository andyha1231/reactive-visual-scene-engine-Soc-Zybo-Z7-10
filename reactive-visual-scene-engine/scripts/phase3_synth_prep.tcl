################################################################################
# phase3_synth_prep.tcl
# Run from Vivado TCL console with phase3_integration project open.
# Fixes BD, regenerates wrapper, sets top, resets synthesis for a clean run.
################################################################################

# ── 1. Open the block design ──────────────────────────────────────────────────
open_bd_design [get_files design_1.bd]

# ── 2. Fix AXI BRAM Controller: reduce to 1 BRAM interface ───────────────────
# Controller currently has 2 interfaces (BRAM_PORTA + BRAM_PORTB), driving two
# separate BRAMs. We want 1 interface → 1 True Dual Port BRAM.
set_property CONFIG.C_NUM_BRAM_ARB {1} [get_bd_cells axi_bram_ctrl_0]
# Vivado auto-removes the BRAM_PORTB interface and its net.

# ── 3. Delete the extra single-port BRAM (was connected to ctrl BRAM_PORTA) ──
# After reducing to 1 interface, axi_bram_ctrl_0/BRAM_PORTA is now disconnected.
# Delete the old single-port BRAM.
if {[llength [get_bd_cells axi_bram_ctrl_0_bram]] > 0} {
    delete_bd_objs [get_bd_intf_nets -of_objects \
        [get_bd_intf_pins axi_bram_ctrl_0_bram/BRAM_PORTA]]
    delete_bd_objs [get_bd_cells axi_bram_ctrl_0_bram]
}

# ── 4. Connect ctrl BRAM_PORTA → True Dual Port BRAM Port A ──────────────────
# axi_bram_ctrl_0_bram_0 is the True Dual Port BRAM:
#   Port A: AXI BRAM Controller (PS writes audio)
#   Port B: already external as BRAM_PORTB_0 (PL reads audio)
connect_bd_intf_net [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA] \
                    [get_bd_intf_pins axi_bram_ctrl_0_bram_0/BRAM_PORTA]

# ── 5. Fix dcm_locked on proc_sys_reset_0 ────────────────────────────────────
# No MMCM inside the BD — tie to 1 so reset releases correctly.
if {[llength [get_bd_cells const_1]] == 0} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 const_1
    set_property CONFIG.CONST_VAL {1} [get_bd_cells const_1]
    set_property CONFIG.CONST_WIDTH {1} [get_bd_cells const_1]
}
connect_bd_net [get_bd_pins const_1/dout] \
               [get_bd_pins proc_sys_reset_0/dcm_locked]

# ── 6. Validate ───────────────────────────────────────────────────────────────
set validate_result [validate_bd_design]
if {$validate_result != 0} {
    puts "WARNING: BD validation returned errors — review before synthesizing."
} else {
    puts "BD validation PASSED."
}

# ── 7. Generate output products + HDL wrapper ─────────────────────────────────
generate_target all [get_files design_1.bd]

set wrapper_path [make_wrapper -files [get_files design_1.bd] -top]
add_files -norecurse $wrapper_path

# ── 8. Set reactive_scene_top_ps as synthesis top ────────────────────────────
set_property top reactive_scene_top_ps [get_filesets sources_1]
set_property top_lib xil_defaultlib    [get_filesets sources_1]

# Sim top unchanged (leave as-is or set to a tb if desired)

# ── 9. Reset stale Phase 3A synthesis + implementation runs ──────────────────
reset_run synth_1
reset_run impl_1

puts ""
puts "================================================"
puts "  phase3_integration ready for synthesis."
puts "  Top module : reactive_scene_top_ps"
puts "  Next step  : launch_runs synth_1"
puts "================================================"
