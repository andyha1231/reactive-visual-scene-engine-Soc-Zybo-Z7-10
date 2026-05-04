/**
 * scene_ctrl.c
 * Driver implementation for Reactive Scene Engine AXI-Lite control registers.
 * Uses Xil_Out32 / Xil_In32 for memory-mapped register access.
 */

#include "xil_io.h"
#include "scene_ctrl.h"
#include "scene_ctrl_regs.h"

void scene_ctrl_set_scene(u8 scene) {
    Xil_Out32(SCENE_CTRL_REG(SCENE_SEL_OFFSET), (u32)(scene & 0x03));
}

void scene_ctrl_set_preset(u8 preset) {
    Xil_Out32(SCENE_CTRL_REG(PRESET_SEL_OFFSET), (u32)preset);
}

void scene_ctrl_set_sensitivity(u8 val) {
    Xil_Out32(SCENE_CTRL_REG(SENSITIVITY_OFFSET), (u32)val);
}

void scene_ctrl_set_threshold(u16 val) {
    Xil_Out32(SCENE_CTRL_REG(THRESHOLD_OFFSET), (u32)val);
}

void scene_ctrl_set_mode(u8 auto_mode) {
    Xil_Out32(SCENE_CTRL_REG(MODE_CTRL_OFFSET), (u32)(auto_mode & 0x01));
}

void scene_ctrl_set_debug(u8 enable) {
    Xil_Out32(SCENE_CTRL_REG(DEBUG_EN_OFFSET), (u32)(enable & 0x01));
}

scene_status_t scene_ctrl_get_status(void) {
    scene_status_t status;
    status.scene       = (u8)Xil_In32(SCENE_CTRL_REG(SCENE_SEL_OFFSET));
    status.preset      = (u8)Xil_In32(SCENE_CTRL_REG(PRESET_SEL_OFFSET));
    status.sensitivity = (u8)Xil_In32(SCENE_CTRL_REG(SENSITIVITY_OFFSET));
    status.threshold   = (u16)Xil_In32(SCENE_CTRL_REG(THRESHOLD_OFFSET));
    status.auto_mode   = (u8)Xil_In32(SCENE_CTRL_REG(MODE_CTRL_OFFSET));
    status.debug_en    = (u8)Xil_In32(SCENE_CTRL_REG(DEBUG_EN_OFFSET));
    return status;
}

void scene_ctrl_reset_defaults(void) {
    scene_ctrl_set_scene(DEFAULT_SCENE);
    scene_ctrl_set_preset(DEFAULT_PRESET);
    scene_ctrl_set_sensitivity(DEFAULT_SENSITIVITY);
    scene_ctrl_set_threshold(DEFAULT_THRESHOLD);
    scene_ctrl_set_mode(0);
    scene_ctrl_set_debug(0);
}
