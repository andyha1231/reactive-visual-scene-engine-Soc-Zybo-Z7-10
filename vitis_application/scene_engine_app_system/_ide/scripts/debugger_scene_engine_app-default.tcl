# Usage with Vitis IDE:
# In Vitis IDE create a Single Application Debug launch configuration,
# change the debug type to 'Attach to running target' and provide this 
# tcl script in 'Execute Script' option.
# Path of this script: C:\Users\khuon\ECE520\final_project\vitis_application\scene_engine_app_system\_ide\scripts\debugger_scene_engine_app-default.tcl
# 
# 
# Usage with xsct:
# To debug using xsct, launch xsct and run below command
# source C:\Users\khuon\ECE520\final_project\vitis_application\scene_engine_app_system\_ide\scripts\debugger_scene_engine_app-default.tcl
# 
connect -url tcp:127.0.0.1:3121
targets -set -nocase -filter {name =~"APU*"}
rst -system
after 3000
targets -set -filter {jtag_cable_name =~ "Digilent Zybo Z7 210351BE7B1CA" && level==0 && jtag_device_ctx=="jsn-Zybo Z7-210351BE7B1CA-13722093-0"}
fpga -file C:/Users/khuon/ECE520/final_project/vitis_application/scene_engine_app/_ide/bitstream/reactive_scene_top_ps.bit
targets -set -nocase -filter {name =~"APU*"}
loadhw -hw C:/Users/khuon/ECE520/final_project/vitis_application/zybo_z7_10_plat/export/zybo_z7_10_plat/hw/reactive_scene_top_ps.xsa -mem-ranges [list {0x40000000 0xbfffffff}] -regs
configparams force-mem-access 1
targets -set -nocase -filter {name =~"APU*"}
source C:/Users/khuon/ECE520/final_project/vitis_application/scene_engine_app/_ide/psinit/ps7_init.tcl
ps7_init
ps7_post_config
targets -set -nocase -filter {name =~ "*A9*#0"}
dow C:/Users/khuon/ECE520/final_project/vitis_application/scene_engine_app/Debug/scene_engine_app.elf
configparams force-mem-access 0
targets -set -nocase -filter {name =~ "*A9*#0"}
con
