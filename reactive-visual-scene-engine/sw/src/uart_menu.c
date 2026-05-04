/**
 * uart_menu.c
 * UART terminal menu for the Reactive Scene Engine (115200 baud).
 *
 * Under the current HW-driven design:
 *   - Scene / quad / freeze are PL switches (sw[3:0]); software cannot drive them.
 *   - Sensitivity (AXI register 0x43C00008) is the only knob software controls.
 *   - This menu therefore only exposes sensitivity + status; commands that
 *     would write SCENE_SEL/PRESET/THRESHOLD have been removed because the
 *     RTL ignores those registers.
 */

#include "xil_printf.h"
#include "xuartps.h"
#include "xparameters.h"
#include "uart_menu.h"
#include "scene_ctrl.h"
#include "scene_ctrl_regs.h"
#include "button_handler.h"

static XUartPs uart_inst;
static int uart_initialized = 0;

static int uart_init(void) {
    XUartPs_Config *cfg;
    int status;

    cfg = XUartPs_LookupConfig(XPAR_XUARTPS_0_DEVICE_ID);
    if (!cfg) return XST_FAILURE;

    status = XUartPs_CfgInitialize(&uart_inst, cfg, cfg->BaseAddress);
    if (status != XST_SUCCESS) return status;

    XUartPs_SetBaudRate(&uart_inst, 115200);
    uart_initialized = 1;
    return XST_SUCCESS;
}

static int uart_read_char(char *c) {
    if (!uart_initialized) {
        if (uart_init() != XST_SUCCESS) return 0;
    }
    return XUartPs_Recv(&uart_inst, (u8 *)c, 1);
}

static const char *scene_name(u8 scene) {
    switch (scene) {
        case 0: return "Loudness Pulse";
        case 1: return "Bass Bars";
        case 2: return "Treble Flash";
        case 3: return "Tri-Band EQ";
        default: return "Unknown";
    }
}

void uart_menu_show(void) {
    xil_printf("\r\n");
    xil_printf("========================================\r\n");
    xil_printf("  Reactive Visual Scene Engine\r\n");
    xil_printf("========================================\r\n");
    xil_printf("  1 - Set sensitivity (0-9 -> 0-252)\r\n");
    xil_printf("  2 - Show current status\r\n");
    xil_printf("  3 - Reset sensitivity to default (128)\r\n");
    xil_printf("  h - Show this menu\r\n");
    xil_printf("\r\n");
    xil_printf("  Note: scene/quad/freeze are PL switches:\r\n");
    xil_printf("    sw[1:0] -> scene 0..3\r\n");
    xil_printf("    sw[2]   -> quad-view (all 4 at once)\r\n");
    xil_printf("    sw[3]   -> freeze\r\n");
    xil_printf("========================================\r\n");
    xil_printf("> ");
}

void uart_menu_process(void) {
    char c;

    if (uart_read_char(&c) == 0) return;

    switch (c) {
        case '1': {
            xil_printf("\r\nEnter sensitivity (0-9, mapped to 0-252): ");
            char sv;
            while (uart_read_char(&sv) == 0);
            if (sv >= '0' && sv <= '9') {
                u8 sens = (u8)((sv - '0') * 28);
                scene_ctrl_set_sensitivity(sens);
                xil_printf("%c\r\nSensitivity set to: %d\r\n", sv, sens);
            } else {
                xil_printf("\r\nInvalid (expected 0-9).\r\n");
            }
            break;
        }
        case '2': {
            scene_status_t st = scene_ctrl_get_status();
            u8 hw_scene    = button_handler_read_scene_switches();
            xil_printf("\r\n--- Current Status ---\r\n");
            xil_printf("  HW scene (sw[1:0]): %s (%d)\r\n", scene_name(hw_scene), hw_scene);
            xil_printf("  Sensitivity (AXI): %d\r\n", st.sensitivity);
            xil_printf("  Note: sw[2] (quad) and sw[3] (freeze) are PL-only;\r\n");
            xil_printf("        not visible to PS (BD pads sw[3:2] as 0 into GPIO).\r\n");
            xil_printf("----------------------\r\n");
            break;
        }
        case '3':
            scene_ctrl_set_sensitivity(DEFAULT_SENSITIVITY);
            xil_printf("\r\nSensitivity reset to default (%d).\r\n", DEFAULT_SENSITIVITY);
            break;
        case 'h':
        case 'H':
            uart_menu_show();
            return;
        default:
            xil_printf("\r\nUnknown command '%c'. Press 'h' for help.\r\n", c);
            break;
    }
    xil_printf("> ");
}
