# phase3_block_design.tcl
# Creates the phase3_integration Vivado project.
# - Links all RTL sources
# - Creates block design with: Zynq PS7, AXI SmartConnect, AXI BRAM Controller,
#   Block Memory (dual-port), AXI GPIO, Processor System Reset
# - Assigns addresses and generates HDL wrapper
# - DOES NOT synthesize (do that after manual BD completion in GUI)
#
# Usage: vivado -mode batch -source reactive-visual-scene-engine/scripts/phase3_block_design.tcl

set repo_dir         [file normalize [file join [file dirname [info script]] ..]]
set proj_root        [file dirname $repo_dir]
set proj_dir         [file join $proj_root phase3_integration]
set proj_file        [file join $proj_dir phase3_integration.xpr]
set vivado_lib_dir   [file join $proj_root vivado-library]

puts "INFO: repo_dir       = $repo_dir"
puts "INFO: proj_dir       = $proj_dir"
puts "INFO: vivado_lib_dir = $vivado_lib_dir"

if {![file isdirectory $vivado_lib_dir]} {
    error "Digilent vivado-library not found at $vivado_lib_dir\nClone it: git clone https://github.com/Digilent/vivado-library.git"
}

# ------------------------------------------------------------------
# Create or open project
# ------------------------------------------------------------------
if {[file exists $proj_file]} {
    puts "INFO: Opening existing project"
    open_project $proj_file
} else {
    puts "INFO: Creating new project at $proj_dir"
    create_project phase3_integration $proj_dir -part xc7z010clg400-1
    set_property board_part digilentinc.com:zybo-z7-10:part0:1.2 [current_project]
    set_property target_language Verilog [current_project]
}

# ------------------------------------------------------------------
# Add all RTL sources (linked, not copied)
# ------------------------------------------------------------------
set rtl_dirs [list \
    [file join $repo_dir rtl audio] \
    [file join $repo_dir rtl feature_extraction] \
    [file join $repo_dir rtl scene_engine] \
    [file join $repo_dir rtl video] \
    [file join $repo_dir rtl axi_ip] \
]

foreach d $rtl_dirs {
    foreach f [glob -nocomplain [file join $d *.v]] {
        if {[llength [get_files -quiet $f]] == 0} {
            add_files -norecurse -fileset sources_1 $f
            puts "INFO: Added $f"
        }
    }
}

# Add constraints
set xdc [file join $repo_dir constraints zybo_z7_hdmi.xdc]
if {[file exists $xdc] && [llength [get_files -quiet $xdc]] == 0} {
    add_files -norecurse -fileset constrs_1 $xdc
    puts "INFO: Added $xdc"
}

# Add Digilent IP repo (for rgb2dvi)
set_property ip_repo_paths $vivado_lib_dir [current_project]
update_ip_catalog -quiet

# ------------------------------------------------------------------
# Create Block Design
# ------------------------------------------------------------------
set bd_name "design_1"
# Use get_files to check on-disk existence (get_bd_designs only sees opened designs)
set existing_bd [get_files -quiet "${bd_name}.bd"]
if {[llength $existing_bd] > 0} {
    puts "INFO: Block design $bd_name already exists — opening without rebuild"
    open_bd_design [lindex $existing_bd 0]
} else {
    puts "INFO: Creating block design $bd_name"
    create_bd_design $bd_name
    open_bd_design [get_files ${bd_name}.bd]

    # --- Zynq PS7 ---
    create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0

    # Apply board preset (sets DDR, FIXED_IO, UART1 on MIO 48..49, FCLK defaults)
    if {[catch {
        apply_bd_automation \
            -rule xilinx.com:bd_rule:processing_system7 \
            -config {make_external "FIXED_IO, DDR" apply_board_preset "1"} \
            [get_bd_cells processing_system7_0]
    } err]} {
        puts "WARNING: apply_bd_automation: $err"
        puts "INFO: Continuing — DDR/FIXED_IO may need manual external connection"
    }

    # Override: enable AXI GP0, fix FCLK0=125 MHz, disable unused TTC.
    # UART1 (MIO 48..49, FTDI) is already configured by the board preset — do not override.
    set_property -dict [list \
        CONFIG.PCW_USE_M_AXI_GP0              {1} \
        CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ   {125} \
        CONFIG.PCW_TTC0_PERIPHERAL_ENABLE     {0} \
    ] [get_bd_cells processing_system7_0]

    # Connect GP0 AXI clock (required — Vivado won't validate without it)
    connect_bd_net \
        [get_bd_pins processing_system7_0/FCLK_CLK0] \
        [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK]

    # --- Processor System Reset ---
    create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_0_125M
    connect_bd_net \
        [get_bd_pins processing_system7_0/FCLK_CLK0] \
        [get_bd_pins rst_ps7_0_125M/slowest_sync_clk]
    connect_bd_net \
        [get_bd_pins processing_system7_0/FCLK_RESET0_N] \
        [get_bd_pins rst_ps7_0_125M/ext_reset_in]

    # --- AXI SmartConnect: 1 master → 3 slaves ---
    # M00: AXI BRAM ctrl  @ 0x4000_0000
    # M01: AXI GPIO       @ 0x4120_0000
    # M02: scene_ctrl IP  @ 0x43C0_0000  (external port, wired in RTL top)
    create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc
    set_property -dict [list \
        CONFIG.NUM_SI {1} \
        CONFIG.NUM_MI {3} \
    ] [get_bd_cells axi_smc]

    connect_bd_intf_net \
        [get_bd_intf_pins processing_system7_0/M_AXI_GP0] \
        [get_bd_intf_pins axi_smc/S00_AXI]
    connect_bd_net \
        [get_bd_pins processing_system7_0/FCLK_CLK0] \
        [get_bd_pins axi_smc/aclk]
    connect_bd_net \
        [get_bd_pins rst_ps7_0_125M/interconnect_aresetn] \
        [get_bd_pins axi_smc/aresetn]

    # --- AXI BRAM Controller (single-port mode: only BRAM_PORTA driven by AXI) ---
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0
    set_property CONFIG.SINGLE_PORT_BRAM {1} [get_bd_cells axi_bram_ctrl_0]

    connect_bd_intf_net \
        [get_bd_intf_pins axi_smc/M00_AXI] \
        [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]
    connect_bd_net \
        [get_bd_pins processing_system7_0/FCLK_CLK0] \
        [get_bd_pins axi_bram_ctrl_0/s_axi_aclk]
    connect_bd_net \
        [get_bd_pins rst_ps7_0_125M/peripheral_aresetn] \
        [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn]

    # --- Block Memory Generator (True Dual-port, both 32-bit) ---
    # Port A: 32-bit (AXI BRAM ctrl — PS loads audio via AXI)
    # Port B: 32-bit (audio_sample_reader — PL reads; audio sample in bits[15:0])
    # Depth: 32768 words × 32-bit = 128KB; audio_sample_reader SAMPLE_COUNT=32768
    create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 blk_mem_gen_0
    set_property -dict [list \
        CONFIG.Memory_Type   {True_Dual_Port_RAM} \
        CONFIG.Write_Width_A {32} \
        CONFIG.Write_Depth_A {32768} \
        CONFIG.Read_Width_A  {32} \
        CONFIG.Write_Width_B {32} \
        CONFIG.Read_Width_B  {32} \
        CONFIG.Use_RSTA_Pin  {true} \
        CONFIG.Use_RSTB_Pin  {true} \
    ] [get_bd_cells blk_mem_gen_0]

    # Connect Port A to AXI BRAM ctrl
    connect_bd_intf_net \
        [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA] \
        [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTA]

    # Make Port B external (audio_sample_reader will connect to it in RTL top)
    make_bd_intf_pins_external [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTB]

    # --- AXI GPIO (buttons GPIO1, switches GPIO2) ---
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
    set_property -dict [list \
        CONFIG.C_GPIO_WIDTH  {4} \
        CONFIG.C_GPIO2_WIDTH {4} \
        CONFIG.C_IS_DUAL     {1} \
        CONFIG.C_ALL_INPUTS  {1} \
        CONFIG.C_ALL_INPUTS_2 {1} \
    ] [get_bd_cells axi_gpio_0]

    connect_bd_intf_net \
        [get_bd_intf_pins axi_smc/M01_AXI] \
        [get_bd_intf_pins axi_gpio_0/S_AXI]
    connect_bd_net \
        [get_bd_pins processing_system7_0/FCLK_CLK0] \
        [get_bd_pins axi_gpio_0/s_axi_aclk]
    connect_bd_net \
        [get_bd_pins rst_ps7_0_125M/peripheral_aresetn] \
        [get_bd_pins axi_gpio_0/s_axi_aresetn]

    # Make GPIO pins external
    make_bd_pins_external [get_bd_pins axi_gpio_0/gpio_io_i]
    make_bd_pins_external [get_bd_pins axi_gpio_0/gpio2_io_i]

    # Expose M02 AXI port for scene_ctrl (connected in RTL top wrapper)
    make_bd_intf_pins_external [get_bd_intf_pins axi_smc/M02_AXI]
    set_property name scene_ctrl_axi [get_bd_intf_ports M02_AXI_0]
    # Match frequency to SmartConnect (125 MHz) to avoid FREQ_HZ validation error
    set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_ports scene_ctrl_axi]

    # Expose clock and reset for use by RTL top
    make_bd_pins_external [get_bd_pins processing_system7_0/FCLK_CLK0]
    make_bd_pins_external [get_bd_pins rst_ps7_0_125M/peripheral_aresetn]

    # ------------------------------------------------------------------
    # Assign addresses
    # ------------------------------------------------------------------
    assign_bd_address

    # assign_bd_address auto-assigns correct offsets for GPIO and scene_ctrl.
    # Expand BRAM range to 128K using the master-space segment reference.
    set bram_seg [get_bd_addr_segs {processing_system7_0/Data/SEG_axi_bram_ctrl_0_Mem0}]
    if {[llength $bram_seg] > 0} {
        set_property range 128K $bram_seg
        puts "INFO: BRAM address range expanded to 128K"
    } else {
        puts "WARNING: BRAM master segment not found — verify Address Editor shows 128K"
    }

    validate_bd_design
    save_bd_design
}

# ------------------------------------------------------------------
# Generate HDL wrapper
# ------------------------------------------------------------------
# Wrapper lands at the standard path after make_wrapper
set wrapper_file [file join $proj_dir phase3_integration.srcs \
    sources_1 bd design_1 hdl design_1_wrapper.v]

if {![file exists $wrapper_file]} {
    puts "INFO: Generating HDL wrapper..."
    make_wrapper -files [get_files design_1.bd] -top
    if {[file exists $wrapper_file]} {
        add_files -norecurse -fileset sources_1 $wrapper_file
        puts "INFO: Added wrapper: $wrapper_file"
    } else {
        puts "WARNING: Wrapper not found at expected path."
        puts "         Check: $wrapper_file"
        puts "         You may need to add it manually via File → Add Sources."
    }
} else {
    puts "INFO: Wrapper already exists: $wrapper_file"
    if {[llength [get_files -quiet $wrapper_file]] == 0} {
        add_files -norecurse -fileset sources_1 $wrapper_file
    }
}

set_property top design_1_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1

puts ""
puts "============================================================"
puts "phase3_integration project created."
puts "Open: $proj_file"
puts ""
puts "NEXT MANUAL STEPS in Vivado GUI:"
puts "  1. Open design_1 block design"
puts "  2. Verify Address Editor (Tools → Address Editor)"
puts "     axi_bram_ctrl_0  @ 0x4000_0000 (128K)"
puts "     axi_gpio_0       @ 0x4120_0000 (64K)"
puts "     scene_ctrl_axi   @ 0x43C0_0000 (64K)"
puts "  3. Double-click blk_mem_gen_0 → set audio_samples.coe"
puts "  4. Validate design (F6)"
puts "  5. Tell Claude 'continue' when done"
puts "============================================================"

close_project
