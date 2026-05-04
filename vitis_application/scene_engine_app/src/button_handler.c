/**
 * button_handler.c
 * Minimal GPIO switch reader. See button_handler.h for the rationale —
 * scenes/quad/freeze are PL-driven, software only reads sw[1:0] to report
 * "what HW is rendering" in the UART status display.
 */

#include "xgpio.h"
#include "xparameters.h"
#include "button_handler.h"

/* Single AXI GPIO instance: ch1=switches (sws_4bits), ch2=buttons (unused). */
#define GPIO_CH_SW   1

static XGpio gpio;

int button_handler_init(void) {
    int status = XGpio_Initialize(&gpio, XPAR_AXI_GPIO_0_DEVICE_ID);
    if (status != XST_SUCCESS) return status;

    XGpio_SetDataDirection(&gpio, GPIO_CH_SW, 0xFF);
    return XST_SUCCESS;
}

u8 button_handler_read_scene_switches(void) {
    return (u8)(XGpio_DiscreteRead(&gpio, GPIO_CH_SW) & 0x3);
}
