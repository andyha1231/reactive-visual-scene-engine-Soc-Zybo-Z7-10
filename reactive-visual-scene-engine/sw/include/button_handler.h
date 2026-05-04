/**
 * button_handler.h
 * GPIO switch reader for the Reactive Scene Engine.
 *
 * NOTE: Under the current HW-driven design, scene_select / quad_view / freeze
 * are controlled by board switches in PL (not via AXI). This module exists
 * only to let software READ the switch state for status reporting in the
 * UART menu. There is no scene/preset/auto-mode logic here anymore.
 *
 *   sw[1:0] (visible to PS via AXI GPIO ch1)
 *     -- scene_select that PL is currently displaying
 *   sw[3:2] (NOT visible to PS — BD pads them as 2'b0 into the GPIO IP)
 *     -- quad_view (sw[2]) and freeze (sw[3]); PL-only
 *
 * btn[0] (visible to PS via AXI GPIO ch2 BUT also = PL reset; reading is
 * not useful in practice, so no public read function is provided).
 */

#ifndef BUTTON_HANDLER_H
#define BUTTON_HANDLER_H

#include "xil_types.h"

/* Initialize AXI GPIO. Returns XST_SUCCESS on success. */
int button_handler_init(void);

/* Read the current state of sw[1:0] (low 2 bits). Returns 0..3. */
u8 button_handler_read_scene_switches(void);

#endif /* BUTTON_HANDLER_H */
