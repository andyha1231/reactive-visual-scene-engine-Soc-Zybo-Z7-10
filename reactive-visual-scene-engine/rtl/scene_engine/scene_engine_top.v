// scene_engine_top.v
// Instantiates all 4 scene modules and muxes output based on scene_select.
//
// New: quad_view_en (sw[2] in top). When asserted, all 4 scenes render
// simultaneously in a 2x2 grid (320x240 each):
//   top-left=scene 0, top-right=scene 1, bot-left=scene 2, bot-right=scene 3.
// Implementation uses ONE set of scene instances fed virtualized pixel
// coords (each quadrant is mapped back to the full 640x480 logical space
// so each scene renders downscaled). 1-pixel white crosshair marks the
// quadrant boundaries.

module scene_engine_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [9:0]  pixel_x,
    input  wire [9:0]  pixel_y,
    input  wire        active_video,
    // Audio features
    input  wire [15:0] amplitude,
    input  wire [15:0] energy_low,
    input  wire [15:0] energy_mid,
    input  wire [15:0] energy_high,
    // Control
    input  wire [1:0]  scene_select,
    input  wire        quad_view_en,   // 1 = all 4 scenes in 2x2 grid
    input  wire        freeze,         // 1 = halt internal scene counters (treble flash)
    input  wire [7:0]  sensitivity,
    // Pixel output
    output reg  [3:0]  r,
    output reg  [3:0]  g,
    output reg  [3:0]  b
);

    // -------------------------------------------------------------------
    // Quadrant detection + virtualized coordinates for quad-view mode.
    // Each 320x240 quadrant maps back to the full 640x480 logical space
    // by doubling the local coordinate (samples every other pixel of the
    // logical scene -> simple 2x downscale).
    // -------------------------------------------------------------------
    wire in_left = (pixel_x < 10'd320);
    wire in_top  = (pixel_y < 10'd240);

    wire [9:0] qx = in_left ? (pixel_x << 1)
                              : ((pixel_x - 10'd320) << 1);
    wire [9:0] qy = in_top  ? (pixel_y << 1)
                              : ((pixel_y - 10'd240) << 1);

    wire [9:0] vx = quad_view_en ? qx : pixel_x;
    wire [9:0] vy = quad_view_en ? qy : pixel_y;

    // Quadrant index for output mux: 00=TL, 01=TR, 10=BL, 11=BR
    wire [1:0] quad_idx = {~in_top, ~in_left};

    // Crosshair pixels (only meaningful in quad mode)
    wire on_crosshair = quad_view_en &&
                       ((pixel_x == 10'd319) || (pixel_x == 10'd320) ||
                        (pixel_y == 10'd239) || (pixel_y == 10'd240));

    // -------------------------------------------------------------------
    // Scene instances — fed virtualized coords so a single instance set
    // covers both single-scene mode (vx=pixel_x) and quad mode.
    // -------------------------------------------------------------------
    wire [3:0] s1_r, s1_g, s1_b;
    wire [3:0] s2_r, s2_g, s2_b;
    wire [3:0] s3_r, s3_g, s3_b;
    wire [3:0] s4_r, s4_g, s4_b;

    scene_loudness_pulse u_scene1 (
        .clk(clk), .rst_n(rst_n),
        .pixel_x(vx), .pixel_y(vy), .active_video(active_video),
        .amplitude(amplitude), .energy_low(energy_low),
        .energy_mid(energy_mid), .energy_high(energy_high),
        .sensitivity(sensitivity),
        .r(s1_r), .g(s1_g), .b(s1_b)
    );

    scene_bass_bars u_scene2 (
        .clk(clk), .rst_n(rst_n),
        .pixel_x(vx), .pixel_y(vy), .active_video(active_video),
        .amplitude(amplitude), .energy_low(energy_low),
        .energy_mid(energy_mid), .energy_high(energy_high),
        .sensitivity(sensitivity),
        .r(s2_r), .g(s2_g), .b(s2_b)
    );

    scene_treble_flash u_scene3 (
        .clk(clk), .rst_n(rst_n),
        .pixel_x(vx), .pixel_y(vy), .active_video(active_video),
        .amplitude(amplitude), .energy_low(energy_low),
        .energy_mid(energy_mid), .energy_high(energy_high),
        .sensitivity(sensitivity),
        .freeze(freeze),
        .r(s3_r), .g(s3_g), .b(s3_b)
    );

    // Slot 4 — Tri-Band Equalizer (replaces scene_split_screen).
    scene_tri_band_eq u_scene4 (
        .clk(clk), .rst_n(rst_n),
        .pixel_x(vx), .pixel_y(vy), .active_video(active_video),
        .amplitude(amplitude), .energy_low(energy_low),
        .energy_mid(energy_mid), .energy_high(energy_high),
        .sensitivity(sensitivity),
        .r(s4_r), .g(s4_g), .b(s4_b)
    );

    // -------------------------------------------------------------------
    // Output mux:
    //   quad mode -> select scene by quadrant
    //   single    -> select scene by scene_select
    // Crosshair overrides everything in quad mode.
    // -------------------------------------------------------------------
    wire [1:0] sel = quad_view_en ? quad_idx : scene_select;

    always @(*) begin
        if (on_crosshair) begin
            r = 4'd15; g = 4'd15; b = 4'd15;
        end else begin
            case (sel)
                2'd0: begin r = s1_r; g = s1_g; b = s1_b; end
                2'd1: begin r = s2_r; g = s2_g; b = s2_b; end
                2'd2: begin r = s3_r; g = s3_g; b = s3_b; end
                2'd3: begin r = s4_r; g = s4_g; b = s4_b; end
            endcase
        end
    end

endmodule
