// scene_tri_band_eq.v
// Scene 4 (NEW): Tri-band equalizer — replaces scene_split_screen.
//
// 3 horizontal stacked bars (each 160 pixels tall):
//   y =   0..159 : LOW band  (red,   driven by energy_low)
//   y = 160..319 : MID band  (green, driven by energy_mid)  -- the only scene
//                                                              that visualizes mid
//   y = 320..479 : HIGH band (blue,  driven by energy_high)
//
// Each bar fills LEFT->RIGHT with width = (band_energy * sensitivity) >> 14,
// clamped to the 640px screen width. Brightness inside a filled bar tracks
// the band energy magnitude (high nibble), with a floor so even quiet bars
// remain visible. The empty (right) portion of each row shows a dim tint
// in that band's color so the layout is always readable.
//
// 1-pixel white separator rows at y=160 and y=320 mark band boundaries.

`timescale 1ns / 1ps

module scene_tri_band_eq (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [9:0]  pixel_x,
    input  wire [9:0]  pixel_y,
    input  wire        active_video,
    input  wire [15:0] amplitude,
    input  wire [15:0] energy_low,
    input  wire [15:0] energy_mid,
    input  wire [15:0] energy_high,
    input  wire [7:0]  sensitivity,
    output reg  [3:0]  r,
    output reg  [3:0]  g,
    output reg  [3:0]  b
);

    localparam [9:0] SEP_LOW_MID = 10'd160;
    localparam [9:0] SEP_MID_HI  = 10'd320;
    localparam [9:0] SCREEN_W    = 10'd640;

    // -------------------------------------------------------------
    // Select which band's energy applies to the current row
    // -------------------------------------------------------------
    reg [15:0] band_energy;
    always @(*) begin
        if (pixel_y < SEP_LOW_MID)      band_energy = energy_low;
        else if (pixel_y < SEP_MID_HI)  band_energy = energy_mid;
        else                            band_energy = energy_high;
    end

    // -------------------------------------------------------------
    // Bar width = (band_energy * sensitivity) >> 13, clamped to 640.
    // Shift tuned for music (real signals weaker than synthetic test tones).
    // Take 11 bits to preserve MSB; clamp to 640 in the wider domain.
    // -------------------------------------------------------------
    wire [23:0] scaled         = band_energy * {8'd0, sensitivity};
    wire [10:0] scaled_shifted = scaled[23:13];
    wire [9:0]  bar_width;
    assign bar_width = (scaled_shifted > {1'b0, SCREEN_W}) ? SCREEN_W : scaled_shifted[9:0];

    wire in_bar = (pixel_x < bar_width);

    // Brightness floor so a filled bar is always visible
    wire [3:0] raw_bright = band_energy[15:12];
    wire [3:0] bright     = (raw_bright < 4'd6) ? 4'd6 : raw_bright;

    // -------------------------------------------------------------
    // Pixel output
    // -------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r <= 4'd0;
            g <= 4'd0;
            b <= 4'd0;
        end else if (active_video) begin
            // Separator rows
            if (pixel_y == SEP_LOW_MID || pixel_y == SEP_MID_HI) begin
                r <= 4'd15;
                g <= 4'd15;
                b <= 4'd15;
            end else if (pixel_y < SEP_LOW_MID) begin
                // LOW band — red
                r <= in_bar ? bright : 4'd1;
                g <= 4'd0;
                b <= 4'd0;
            end else if (pixel_y < SEP_MID_HI) begin
                // MID band — green
                r <= 4'd0;
                g <= in_bar ? bright : 4'd1;
                b <= 4'd0;
            end else begin
                // HIGH band — blue
                r <= 4'd0;
                g <= 4'd0;
                b <= in_bar ? bright : 4'd1;
            end
        end else begin
            r <= 4'd0;
            g <= 4'd0;
            b <= 4'd0;
        end
    end

endmodule
