/**
 * main.c -- Reactive Visual Scene Engine, ARM application.
 *
 * Boot sequence:
 *   1. Banner + initialise default sensitivity, GPIO readback.
 *   2. Print song length / chunk count.
 *   3. Print [READY] marker -- play_demo.ps1 watches for this to know it
 *      can prompt the user to press ENTER.
 *   4. Wait for 'G' (or 'g') on UART before starting the audio streamer.
 *   5. Init streamer, show menu, enter poll loop.
 *
 * The poll loop just runs:
 *   - audio_streamer_process(): on each WRAP_FLAG, write the next song
 *     chunk into BRAM. Walks through the embedded song chunk by chunk.
 *   - uart_menu_process(): one-char menu -- sensitivity, status, restart,
 *     loop toggle, pause, silence, etc. (See uart_menu.c.)
 *
 * Display modes (scene / quad / freeze) are PL switches; software has
 * nothing to do with rendering.
 */

#include "xil_printf.h"
#include "xparameters.h"
#include "xuartps.h"
#include "sleep.h"
#include "scene_ctrl.h"
#include "scene_ctrl_regs.h"
#include "button_handler.h"
#include "uart_menu.h"
#include "audio_streamer.h"
#include "song_data.h"

/* Block until 'G' or 'g' arrives on UART. Used to synchronize the FPGA
 * streamer with PC-played MP3 audio: tools/play_demo.ps1 fires 'G' and
 * starts MP3 playback in the same script tick. */
static void wait_for_go(void) {
    XUartPs_Config *cfg = XUartPs_LookupConfig(XPAR_XUARTPS_0_DEVICE_ID);
    if (!cfg) return;
    XUartPs uart;
    if (XUartPs_CfgInitialize(&uart, cfg, cfg->BaseAddress) != XST_SUCCESS) return;
    XUartPs_SetBaudRate(&uart, 115200);

    while (1) {
        u8 c;
        if (XUartPs_Recv(&uart, &c, 1) > 0) {
            if (c == 'G' || c == 'g') {
                xil_printf("[GATE] Got GO -- starting streamer.\r\n");
                return;
            }
        }
        usleep(1000);
    }
}

int main(void) {
    int status;

    xil_printf("\r\n");
    xil_printf("=============================================\r\n");
    xil_printf("  Reactive Visual Scene Engine\r\n");
    xil_printf("  ECE 520 Final Project\r\n");
    xil_printf("  Macy Varga & Andy Ha\r\n");
    xil_printf("=============================================\r\n");

    scene_ctrl_set_sensitivity(DEFAULT_SENSITIVITY);
    xil_printf("[INIT] Sensitivity = %d\r\n", DEFAULT_SENSITIVITY);

    status = button_handler_init();
    if (status != XST_SUCCESS) {
        xil_printf("[ERROR] GPIO init failed (%d).\r\n", status);
        return -1;
    }
    xil_printf("[INIT] GPIO ready.\r\n");

    {
        u32 total_s = song_total_samples;
        u32 chunks  = (total_s + song_chunk_samples - 1u) / song_chunk_samples;
        u32 dur_ms  = (total_s * 1000u) / song_sample_rate;
        xil_printf("[INIT] Song: %u samples (%u.%03u s, %u chunks of %u)\r\n",
                   (unsigned)total_s,
                   (unsigned)(dur_ms / 1000u),
                   (unsigned)(dur_ms % 1000u),
                   (unsigned)chunks,
                   (unsigned)song_chunk_samples);
    }

    /* Sentinel for play_demo.ps1. Must be the LAST line printed before
     * wait_for_go() so the PowerShell helper can use it to know the FPGA
     * is fully booted and ready to receive 'G'. Don't change the wording. */
    xil_printf("[READY] Press 'G' to start.\r\n");

    wait_for_go();

    audio_streamer_init();
    uart_menu_show();

    while (1) {
        audio_streamer_process();
        uart_menu_process();
        usleep(10000);  /* 10 ms */
    }

    return 0;
}
