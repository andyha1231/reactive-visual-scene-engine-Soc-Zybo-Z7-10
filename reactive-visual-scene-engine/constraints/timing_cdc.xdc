## timing_cdc.xdc — implementation-only (marked in project settings)
## CDC false paths.
##
## (1) Audio features and scene_select cross from 125 MHz / PS clock to the
##     25 MHz pixel clock. Data changes at 22 kHz max — quasi-static.
set_false_path -from [get_clocks sys_clk_pin] -to [get_clocks clkout0]
set_false_path -from [get_clocks clk_fpga_0]  -to [get_clocks clkout0]

## (2) wrap_pulse from audio_sample_reader (sys_clk) -> WRAP_FLAG sync in
##     scene_ctrl_v1_0_S00_AXI (clk_fpga_0). Pulse-stretched to 15 cycles in
##     source so the 2-FF synchronizer captures it; CDC structural pattern.
set_false_path -from [get_clocks sys_clk_pin] -to [get_clocks clk_fpga_0]
