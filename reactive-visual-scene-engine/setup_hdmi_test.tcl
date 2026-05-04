set repo_dir [file normalize [file dirname [info script]]]
set workspace_dir [file dirname $repo_dir]
set project_dir [file join $repo_dir hdmi_test]
set project_file [file join $project_dir hdmi_test.xpr]
set vivado_library_dir [file join $workspace_dir vivado-library]

if {![file isdirectory $vivado_library_dir]} {
    error "Digilent vivado-library not found at $vivado_library_dir"
}

if {[file exists $project_file]} {
    open_project $project_file
} else {
    create_project hdmi_test $project_dir -part xc7z010clg400-1
}

set_property board_part digilentinc.com:zybo-z7-10:part0:1.2 [current_project]

set source_files [list \
    [file join $repo_dir rtl top hdmi_test_pattern_top.v] \
    [file join $repo_dir rtl video vga_sync.v] \
    [file join $repo_dir rtl video pixel_clk_gen.v] \
]

foreach src $source_files {
    if {![file exists $src]} {
        error "Missing source file: $src"
    }
}

add_files -norecurse -fileset sources_1 $source_files

set constraint_file [file join $repo_dir constraints zybo_z7_hdmi.xdc]
if {![file exists $constraint_file]} {
    error "Missing constraint file: $constraint_file"
}
add_files -norecurse -fileset constrs_1 $constraint_file

set_property top hdmi_test_pattern_top [get_filesets sources_1]

set_property ip_repo_paths $vivado_library_dir [current_project]
update_ip_catalog

if {[llength [get_ips -quiet rgb2dvi_0]] == 0} {
    create_ip -name rgb2dvi -vendor digilentinc.com -library ip -module_name rgb2dvi_0
}

set_property -dict [list \
    CONFIG.kGenerateSerialClk {false} \
    CONFIG.kClkRange {2} \
    CONFIG.kRstActiveHigh {true} \
] [get_ips rgb2dvi_0]

generate_target all [get_ips rgb2dvi_0]
export_ip_user_files -of_objects [get_ips rgb2dvi_0] -no_script -sync -force -quiet

update_compile_order -fileset sources_1

set top_name [get_property top [get_filesets sources_1]]
puts "TOP_MODULE=$top_name"

set hierarchy_targets [list \
    [file normalize [file join $repo_dir rtl video pixel_clk_gen.v]] \
    [file normalize [file join $repo_dir rtl video vga_sync.v]] \
]
foreach required_file $hierarchy_targets {
    if {[llength [get_files -quiet $required_file]] == 0} {
        error "Required design source not present in project: $required_file"
    }
}

if {[llength [get_ips -quiet rgb2dvi_0]] == 0} {
    error "Required rgb2dvi_0 IP was not generated"
}

close_project
