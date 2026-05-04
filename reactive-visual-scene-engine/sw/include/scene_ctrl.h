/**
 * scene_ctrl.h
 * Driver functions for the Reactive Scene Engine AXI-Lite control registers.
 */

#ifndef SCENE_CTRL_H
#define SCENE_CTRL_H

#include "xil_types.h"

/* Status structure returned by scene_ctrl_get_status() */
typedef struct {
    u8  scene;
    u8  preset;
    u8  sensitivity;
    u16 threshold;
    u8  auto_mode;
    u8  debug_en;
} scene_status_t;

/* Write functions */
void scene_ctrl_set_scene(u8 scene);
void scene_ctrl_set_preset(u8 preset);
void scene_ctrl_set_sensitivity(u8 val);
void scene_ctrl_set_threshold(u16 val);
void scene_ctrl_set_mode(u8 auto_mode);
void scene_ctrl_set_debug(u8 enable);

/* Read functions */
scene_status_t scene_ctrl_get_status(void);

/* Convenience */
void scene_ctrl_reset_defaults(void);

#endif /* SCENE_CTRL_H */
