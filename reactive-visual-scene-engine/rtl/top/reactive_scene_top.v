// reactive_scene_top.v
// PL-only hardware test top for the Reactive Visual Scene Engine.
// No PS, no BRAM, no AXI — standalone scene engine driven by a
// slow oscillating test signal so all 4 scenes are visually active.
//
// SW[1:0] — scene select (live, no debounce needed for switches)
// SW[2]   — hold maximum amplitude (freeze at brightest state)
// SW[3]   — spare (tied to LED[3])
// BTN0    — active-high reset
// LED[0]  — MMCM locked (clock OK)
// LED[1]  — active_video pulse (blinks at 60 Hz)
// LED[2]  — mirrors SW[0]
// LED[3]  — mirrors SW[1]

`timescale 1ns / 1ps

module reactive_scene_top (
    input  wire       clk,            // 125 MHz (K17)
    input  wire       btn0,           // Reset (active high)
    input  wire [3:0] sw,             // Switches
    output wire [3:0] led,
    // HDMI TMDS
    output wire       hdmi_tx_clk_p,
    output wire       hdmi_tx_clk_n,
    output wire [2:0] hdmi_tx_d_p,
    output wire [2:0] hdmi_tx_d_n
);

    // -------------------------------------------------------
    // Clock generation
    // -------------------------------------------------------
    wire pixel_clk, serial_clk, mmcm_locked;

    pixel_clk_gen u_pclk (
        .clk_125m  (clk),
        .rst       (btn0),
        .pixel_clk (pixel_clk),
        .serial_clk(serial_clk),
        .locked    (mmcm_locked)
    );

    wire rst_n = mmcm_locked & ~btn0;

    // -------------------------------------------------------
    // VGA timing generator (640x480 @ 60 Hz on 25 MHz pixel clk)
    // -------------------------------------------------------
    wire       hsync, vsync, active_video;
    wire [9:0] pixel_x, pixel_y;

    vga_sync u_sync (
        .pclk        (pixel_clk),
        .rst_n       (rst_n),
        .hsync       (hsync),
        .vsync       (vsync),
        .pixel_x     (pixel_x),
        .pixel_y     (pixel_y),
        .active_video(active_video)
    );

    // -------------------------------------------------------
    // Oscillating audio values — slow triangle wave
    // 25-bit counter @ 125 MHz: full period ≈ 268 ms (3.7 Hz)
    // Creates a smooth 0→max→0 pulse so scenes look alive.
    // -------------------------------------------------------
    reg [24:0] wave_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) wave_cnt <= 25'd0;
        else        wave_cnt <= wave_cnt + 1'd1;
    end

    // Triangle wave: bit[24] selects ascending or descending half
    wire [15:0] tri_wave = wave_cnt[24] ? ~{wave_cnt[23:8]} : {wave_cnt[23:8]};

    // SW[2]=1: lock at ~75% max so rect is clearly visible in scene 0
    wire [15:0] audio_val = sw[2] ? 16'hBFFF : tri_wave;

    // Audio features fed to scene engine:
    //   amplitude  = oscillating value  → scene 0 rect pulses in/out
    //   energy_low = same value         → scene 1 bass bars rise/fall
    //   energy_mid = half value         → scene 2 center glow
    //   energy_high = inverted value    → scene 2/3 treble flash is fast when bass is quiet
    wire [15:0] amplitude    = audio_val;
    wire [15:0] energy_low   = audio_val;
    wire [15:0] energy_mid   = {1'b0, audio_val[15:1]};
    wire [15:0] energy_high  = ~audio_val;

    // -------------------------------------------------------
    // Scene engine (all 4 scenes instantiated; SW[1:0] selects)
    // Runs on pixel_clk so coordinates and RGB are synchronous.
    // -------------------------------------------------------
    wire [3:0] scene_r, scene_g, scene_b;

    scene_engine_top u_scene (
        .clk          (pixel_clk),
        .rst_n        (rst_n),
        .pixel_x      (pixel_x),
        .pixel_y      (pixel_y),
        .active_video (active_video),
        .amplitude    (amplitude),
        .energy_low   (energy_low),
        .energy_mid   (energy_mid),
        .energy_high  (energy_high),
        .scene_select (sw[1:0]),
        .sensitivity  (8'd128),
        .r            (scene_r),
        .g            (scene_g),
        .b            (scene_b)
    );

    // -------------------------------------------------------
    // HDMI output via Digilent rgb2dvi IP
    // Expand 4-bit channels to 8-bit by duplicating each nibble.
    // Digilent rgb2dvi channel mapping (confirmed from hdmi_test):
    //   [23:16] = Red, [15:8] = Blue, [7:0] = Green
    wire [23:0] vid_data = {
        {scene_r, scene_r},
        {scene_b, scene_b},
        {scene_g, scene_g}
    };

    rgb2dvi_0 u_hdmi (
        .PixelClk    (pixel_clk),
        .SerialClk   (serial_clk),
        .aRst        (btn0),
        .vid_pData   (vid_data),
        .vid_pVDE    (active_video),
        .vid_pHSync  (hsync),
        .vid_pVSync  (vsync),
        .TMDS_Clk_p  (hdmi_tx_clk_p),
        .TMDS_Clk_n  (hdmi_tx_clk_n),
        .TMDS_Data_p (hdmi_tx_d_p),
        .TMDS_Data_n (hdmi_tx_d_n)
    );

    // -------------------------------------------------------
    // LED status indicators
    // -------------------------------------------------------
    assign led[0] = mmcm_locked;   // clock good
    assign led[1] = active_video;  // blinks at ~60 Hz
    assign led[2] = sw[0];
    assign led[3] = sw[1];

endmodule
