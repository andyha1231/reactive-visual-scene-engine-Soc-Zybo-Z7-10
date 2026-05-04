// scene_loudness_pulse.v -- Scene 1: "Concentric Circles"
//
// Solid yellow core in screen center. Around it, concentric orange rings
// at FIXED radii every 32 pixels outward. The NUMBER of visible rings is
// driven by `amplitude`:
//   - silence  -> no rings, just the core
//   - quiet    -> 1-2 rings near the core
//   - loud     -> many rings spreading outward across the screen

`timescale 1ns / 1ps

module scene_loudness_pulse (
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
    input  wire        freeze,
    output reg  [3:0]  r,
    output reg  [3:0]  g,
    output reg  [3:0]  b
);

    localparam [9:0]  CX = 10'd320;
    localparam [9:0]  CY = 10'd240;
    localparam [10:0] CORE_RADIUS = 11'd25;
    localparam [4:0]  RING_THICK  = 5'd6;

    // Free-running animation counter (gated by freeze) -- kept so freeze has
    // a register to gate, even though current rendering doesn't animate.
    reg [23:0] anim_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)        anim_cnt <= 24'd0;
        else if (!freeze)  anim_cnt <= anim_cnt + 24'd1;
    end

    // Manhattan distance from screen center.
    wire [9:0]  dx = (pixel_x >= CX) ? (pixel_x - CX) : (CX - pixel_x);
    wire [9:0]  dy = (pixel_y >= CY) ? (pixel_y - CY) : (CY - pixel_y);
    wire [10:0] mh = {1'b0, dx} + {1'b0, dy};

    wire in_core = (mh < CORE_RADIUS);

    // Each pixel falls into a ring slot if mh % 32 < 6.
    wire on_ring_pattern = (mh[4:0] < RING_THICK);

    // Ring index (0 is innermost). Rings 1..num_rings are visible.
    wire [5:0] ring_idx = mh[10:5];

    // Number of active rings = music response.
    wire [5:0] num_rings = {1'b0, amplitude[15:11]};

    wire ring_lit = on_ring_pattern && (ring_idx != 6'd0) && (ring_idx <= num_rings);

    // Brightness floor for visibility when amplitude is small.
    wire [3:0] amp_b  = amplitude[15:12];
    wire [3:0] bright = (amp_b < 4'd6) ? 4'd6 : amp_b;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r <= 4'd0;
            g <= 4'd0;
            b <= 4'd0;
        end else if (active_video) begin
            if (in_core) begin
                // SOLID YELLOW CORE
                r <= 4'd15;
                g <= 4'd12;
                b <= 4'd2;
            end else if (ring_lit) begin
                // ORANGE RING
                r <= bright;
                g <= bright >> 1;
                b <= 4'd0;
            end else begin
                // DIM PURPLE BACKGROUND
                r <= 4'd1;
                g <= 4'd0;
                b <= 4'd1;
            end
        end else begin
            r <= 4'd0;
            g <= 4'd0;
            b <= 4'd0;
        end
    end

endmodule
