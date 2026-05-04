/**
 * scene_ctrl_regs.h
 * Register offset definitions for the Reactive Scene Engine AXI-Lite IP.
 *
 * Base address is assigned in Vivado Address Editor (typically 0x43C0_0000).
 */

#ifndef SCENE_CTRL_REGS_H
#define SCENE_CTRL_REGS_H

/* Base address -- update after Vivado address assignment */
#define SCENE_CTRL_BASE_ADDR    0x43C00000

/* Register offsets */
#define SCENE_SEL_OFFSET        0x00    /* [1:0]  RW  Active scene (0-3)        */
#define PRESET_SEL_OFFSET       0x04    /* [7:0]  RW  Active preset             */
#define SENSITIVITY_OFFSET      0x08    /* [7:0]  RW  Visual response strength  */
#define THRESHOLD_OFFSET        0x0C    /* [15:0] RW  Feature threshold value   */
#define MODE_CTRL_OFFSET        0x10    /* [0]    RW   0=manual, 1=auto          */
#define DEBUG_EN_OFFSET         0x14    /* [0]    RW   Debug overlay enable      */
#define WRAP_FLAG_OFFSET        0x18    /* [0]    R/W1C  Sticky bit, set on each
                                                BRAM addr wrap; write 1 to clear */

/* Convenience macros */
#define SCENE_CTRL_REG(offset)  (SCENE_CTRL_BASE_ADDR + (offset))

/* AXI BRAM controller base — PS writes here to fill BRAM with new audio chunks.
 * The BRAM is 32-bit wide, 32768 deep; sample N lives at offset (N * 4). */
#define BRAM_CTRL_BASE_ADDR     0x40000000
#define BRAM_SAMPLE_ADDR(n)     (BRAM_CTRL_BASE_ADDR + ((n) << 2))

/* Scene IDs */
#define SCENE_LOUDNESS_PULSE    0
#define SCENE_BASS_BARS         1
#define SCENE_TREBLE_FLASH      2
#define SCENE_SPLIT_SCREEN      3
#define NUM_SCENES              4

/* Default values */
#define DEFAULT_SENSITIVITY     240   /* near-max; combined with RTL >>13 gives ~3.75x boost vs older >>14, sens=128 */
#define DEFAULT_THRESHOLD       0
#define DEFAULT_SCENE           SCENE_LOUDNESS_PULSE
#define DEFAULT_PRESET          0

#endif /* SCENE_CTRL_REGS_H */
