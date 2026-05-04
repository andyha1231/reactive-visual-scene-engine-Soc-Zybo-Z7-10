## timing_cdc.xdc — implementation-only (marked in project settings)
## CDC false paths: audio features and scene_select cross from 125 MHz / PS clock
## to the 25 MHz pixel clock. Data changes at 22 kHz max — quasi-static.
set_false_path -from [get_clocks sys_clk_pin] -to [get_clocks clkout0]
set_false_path -from [get_clocks clk_fpga_0]  -to [get_clocks clkout0]
