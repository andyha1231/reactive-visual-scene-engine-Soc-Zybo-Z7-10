/**
 * main.c
 * Reactive Visual Scene Engine - ARM Application
 *
 * Entry point for the Zynq PS. Initializes peripherals, displays the UART
 * menu, and idles in a poll loop waiting for UART input. Scene/quad/freeze
 * are HW switches in PL — software only tunes sensitivity and reports status.
 */

#include "xil_printf.h"
#include "xparameters.h"
#include "sleep.h"
#include "scene_ctrl.h"
#include "scene_ctrl_regs.h"
#include "button_handler.h"
#include "uart_menu.h"

int main(void) {
    int status;

    xil_printf("\r\n");
    xil_printf("=============================================\r\n");
    xil_printf("  Reactive Visual Scene Engine\r\n");
    xil_printf("  ECE 520 Final Project\r\n");
    xil_printf("  Macy Varga & Andy Ha\r\n");
    xil_printf("=============================================\r\n");

    /* Set sensitivity to default (other AXI regs are not consumed by RTL). */
    scene_ctrl_set_sensitivity(DEFAULT_SENSITIVITY);
    xil_printf("[INIT] Sensitivity set to default (%d).\r\n", DEFAULT_SENSITIVITY);

    /* Init AXI GPIO so we can read sw[1:0] for status reporting. */
    status = button_handler_init();
    if (status != XST_SUCCESS) {
        xil_printf("[ERROR] GPIO init failed (status=%d).\r\n", status);
        return -1;
    }
    xil_printf("[INIT] GPIO ready (sw[1:0] readable for status).\r\n");

    /* Show menu, then poll for UART input. */
    uart_menu_show();

    while (1) {
        uart_menu_process();
        usleep(10000);  /* 10 ms */
    }

    return 0;
}
