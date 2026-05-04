# 
# Usage: To re-create this platform project launch xsct with below options.
# xsct C:\Users\khuon\ECE520\final_project\vitis_application\zybo_z7_10_plat\platform.tcl
# 
# OR launch xsct and run below command.
# source C:\Users\khuon\ECE520\final_project\vitis_application\zybo_z7_10_plat\platform.tcl
# 
# To create the platform in a different location, modify the -out option of "platform create" command.
# -out option specifies the output directory of the platform project.

platform create -name {zybo_z7_10_plat}\
-hw {C:\Users\khuon\ECE520\final_project\phase3_integration\reactive_scene_top_ps.xsa}\
-proc {ps7_cortexa9_0} -os {standalone} -out {C:/Users/khuon/ECE520/final_project/vitis_application}

platform write
platform generate -domains 
platform active {zybo_z7_10_plat}
platform generate
bsp reload
domain active {zynq_fsbl}
bsp reload
bsp reload
platform config -updatehw {C:/Users/khuon/ECE520/final_project/phase3_integration/reactive_scene_top_ps.xsa}
platform generate -domains 
platform config -updatehw {C:/Users/khuon/ECE520/final_project/phase3_integration/reactive_scene_top_ps.xsa}
platform generate -domains 
platform config -updatehw {C:/Users/khuon/ECE520/final_project/phase3_integration/reactive_scene_top_ps.xsa}
platform generate -domains 
platform config -updatehw {C:/Users/khuon/ECE520/final_project/phase3_integration/reactive_scene_top_ps.xsa}
platform generate -domains 
platform config -updatehw {C:/Users/khuon/ECE520/final_project/phase3_integration/reactive_scene_top_ps.xsa}
platform generate -domains 
platform config -updatehw {C:/Users/khuon/ECE520/final_project/phase3_integration/reactive_scene_top_ps.xsa}
platform generate -domains 
platform config -updatehw {C:/Users/khuon/ECE520/final_project/phase3_integration/reactive_scene_top_ps.xsa}
platform generate -domains 
platform config -updatehw {C:/Users/khuon/ECE520/final_project/phase3_integration/reactive_scene_top_ps.xsa}
platform generate -domains 
platform config -updatehw {C:/Users/khuon/ECE520/final_project/phase3_integration/reactive_scene_top_ps.xsa}
platform generate -domains 
platform config -updatehw {C:/Users/khuon/ECE520/final_project/phase3_integration/reactive_scene_top_ps.xsa}
platform generate -domains 
platform config -updatehw {C:/Users/khuon/ECE520/final_project/phase3_integration/reactive_scene_top_ps.xsa}
platform generate -domains 
platform config -updatehw {C:/Users/khuon/ECE520/final_project/phase3_integration/reactive_scene_top_ps.xsa}
platform generate -domains 
platform clean
platform config -updatehw {C:/Users/khuon/ECE520/final_project/phase3_integration/reactive_scene_top_ps.xsa}
platform clean
platform generate
platform config -updatehw {C:/Users/khuon/ECE520/final_project/phase3_integration/reactive_scene_top_ps.xsa}
platform generate -domains 
platform config -updatehw {C:/Users/khuon/ECE520/final_project/phase3_integration/reactive_scene_top_ps.xsa}
platform generate -domains 
