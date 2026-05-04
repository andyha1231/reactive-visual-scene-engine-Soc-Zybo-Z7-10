// tb_scene_engine_top.v
// Tests the scene_engine_top mux:
//   - single mode (quad_view_en=0): scene_select selects the right scene
//   - quad mode  (quad_view_en=1):  quadrant determines the scene
//   - crosshair pixels in quad mode are white
//   - crosshair pixels in single mode are NOT forced white
//
// Strategy: drive distinct audio features so each scene's pixel output is
// uniquely identifiable, then sample at known coords and verify.

`timescale 1ns / 1ps

module tb_scene_engine_top;

    reg        clk, rst_n, active_video;
    reg [9:0]  pixel_x, pixel_y;
    reg [15:0] amplitude, energy_low, energy_mid, energy_high;
    reg [1:0]  scene_select;
    reg        quad_view_en;
    reg        freeze;
    reg [7:0]  sensitivity;
    wire [3:0] r, g, b;

    localparam CLK_PERIOD = 8;

    scene_engine_top uut (
        .clk(clk), .rst_n(rst_n),
        .pixel_x(pixel_x), .pixel_y(pixel_y), .active_video(active_video),
        .amplitude(amplitude), .energy_low(energy_low),
        .energy_mid(energy_mid), .energy_high(energy_high),
        .scene_select(scene_select),
        .quad_view_en(quad_view_en),
        .freeze(freeze),
        .sensitivity(sensitivity),
        .r(r), .g(g), .b(b)
    );

    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    integer fail_count;

    // Hold inputs steady for a few cycles so all 4 scene instances have time
    // to register their outputs (each scene has a 1-clk pipeline).
    task settle_pixel;
        input [9:0] px, py;
        input [1:0] sel;
        input       quad;
        begin
            pixel_x      = px;
            pixel_y      = py;
            scene_select = sel;
            quad_view_en = quad;
            active_video = 1'b1;
            repeat (3) @(posedge clk);
            #1;
        end
    endtask

    initial begin
        $display("=== Scene Engine Top Testbench ===");
        fail_count = 0;

        rst_n        = 0;
        active_video = 0;
        pixel_x      = 0; pixel_y = 0;
        scene_select = 0; quad_view_en = 0; freeze = 0;
        sensitivity  = 8'd255;
        // Drive features so each scene produces a clearly distinct, max output.
        amplitude    = 16'hFFFF;   // scene_loudness_pulse: bright orange center
        energy_low   = 16'hFFFF;   // scene_bass_bars: green band, scene_tri_band: red top bar
        energy_mid   = 16'hFFFF;   // scene_treble_flash center, scene_tri_band: green mid bar
        energy_high  = 16'hFFFF;   // scene_treble_flash edge flash, scene_tri_band: blue bottom bar

        repeat (10) @(posedge clk);

        // --- Test 1: Reset ---
        if (r === 4'd0 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 1: Reset - outputs zero");
        else begin
            $display("[FAIL] Test 1: Reset - r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        rst_n = 1;
        repeat (3) @(posedge clk);

        // ===================================================================
        // SINGLE MODE (quad_view_en = 0)
        // ===================================================================
        // Sample at center of screen (320,240) — for loudness pulse this is
        // the brightest pixel; bass_bars at this y is empty (bar at bottom);
        // treble_flash center has mid-energy glow; tri_band_eq mid band.

        // Test 2: scene 0 (loudness pulse) at center → bright orange (r > 0)
        settle_pixel(10'd320, 10'd240, 2'd0, 1'b0);
        if (r > 4'd5)
            $display("[PASS] Test 2: Single scene 0 - bright pixel at center r=%0d", r);
        else begin
            $display("[FAIL] Test 2: Single scene 0 r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // Test 3: scene 1 (bass_bars) at y=479 → green band visible
        settle_pixel(10'd100, 10'd479, 2'd1, 1'b0);
        if (g > 4'd0 && r === 4'd1 && b === 4'd2)
            $display("[PASS] Test 3: Single scene 1 - bass bar at bottom g=%0d", g);
        else begin
            $display("[FAIL] Test 3: Single scene 1 r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // Test 4: scene 2 (treble_flash) edge zone → flashing pixel pattern
        // Edge zone: pixel_x < 60. flash_state may be 0 or 1; test for
        // EITHER bright cyan-ish OR dim edge (both valid edge outputs).
        settle_pixel(10'd10, 10'd10, 2'd2, 1'b0);
        // Edge OFF: r=1, g=1, b=2 ; Edge ON: r=8, g=12, b=15
        if ((r === 4'd1 && g === 4'd1 && b === 4'd2) ||
            (r === 4'd8 && g === 4'd12 && b === 4'd15))
            $display("[PASS] Test 4: Single scene 2 - edge zone r=%0d g=%0d b=%0d", r, g, b);
        else begin
            $display("[FAIL] Test 4: Single scene 2 r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // Test 5: scene 3 (tri_band_eq) at y=80 (low band), x=100 → red filled
        settle_pixel(10'd100, 10'd80, 2'd3, 1'b0);
        if (r > 4'd5 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 5: Single scene 3 - tri-band low row red r=%0d", r);
        else begin
            $display("[FAIL] Test 5: Single scene 3 r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // Test 6: Single mode, x=320 (would be crosshair in quad mode)
        // → must NOT be white (crosshair only in quad mode)
        settle_pixel(10'd320, 10'd100, 2'd0, 1'b0);
        if (!(r === 4'd15 && g === 4'd15 && b === 4'd15))
            $display("[PASS] Test 6: Single mode x=320 NOT crosshair (r=%0d g=%0d b=%0d)", r, g, b);
        else begin
            $display("[FAIL] Test 6: Single mode x=320 unexpectedly white");
            fail_count = fail_count + 1;
        end

        // ===================================================================
        // QUAD MODE (quad_view_en = 1)
        // Each 320x240 quadrant maps back to a downscaled 640x480 logical
        // scene. Verify each quadrant shows the right scene.
        // ===================================================================

        // Test 7: TL quadrant (px<320, py<240): logical (vx=2*px, vy=2*py)
        // At (px=160, py=120) → vx=320, vy=240 = center of scene 0 (loudness).
        // Should show bright orange (loudness pulse center).
        settle_pixel(10'd160, 10'd120, 2'd0, 1'b1);
        if (r > 4'd5)
            $display("[PASS] Test 7: Quad TL = scene 0 loudness center r=%0d", r);
        else begin
            $display("[FAIL] Test 7: Quad TL r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // Test 8: TR quadrant (px>=320, py<240): logical (vx=2*(px-320))
        // At (px=480, py=120) → vx=320, vy=240 — center of bass bars.
        // Bass bars at vy=240 → not in bar (bars are at bottom). Should be black.
        // Better: sample at vy near 480 → in bar.
        // (px=480, py=239) → vx=320, vy=478 → IN BAR (green visible).
        settle_pixel(10'd480, 10'd239, 2'd0, 1'b1);
        // Wait — this is on the crosshair! py=239 = crosshair pixel.
        // Use py=200 → vy=400, and vy>=480-bar_height
        // bar_height with FFFF*FF: clamp 480. vy=400 >= 480-480=0 ✓ in bar.
        settle_pixel(10'd480, 10'd200, 2'd0, 1'b1);
        if (g > 4'd0)
            $display("[PASS] Test 8: Quad TR = scene 1 bass bars g=%0d", g);
        else begin
            $display("[FAIL] Test 8: Quad TR r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // Test 9: BL quadrant (px<320, py>=240): scene 2 treble flash
        // At (px=10, py=300) → vx=20, vy=120 — edge zone of treble (vx<60).
        settle_pixel(10'd10, 10'd300, 2'd0, 1'b1);
        // Edge zone — accept either ON or OFF state
        if ((r === 4'd1 && g === 4'd1 && b === 4'd2) ||
            (r === 4'd8 && g === 4'd12 && b === 4'd15))
            $display("[PASS] Test 9: Quad BL = scene 2 treble edge r=%0d g=%0d b=%0d", r, g, b);
        else begin
            $display("[FAIL] Test 9: Quad BL r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // Test 10: BR quadrant (px>=320, py>=240): scene 3 tri-band eq
        // At (px=400, py=300) → vx=160, vy=120 — low band of tri_band, in bar.
        settle_pixel(10'd400, 10'd300, 2'd0, 1'b1);
        if (r > 4'd5 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 10: Quad BR = scene 3 tri-band r=%0d", r);
        else begin
            $display("[FAIL] Test 10: Quad BR r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // Test 11: Quad mode crosshair at x=319 → white
        settle_pixel(10'd319, 10'd100, 2'd0, 1'b1);
        if (r === 4'd15 && g === 4'd15 && b === 4'd15)
            $display("[PASS] Test 11: Quad crosshair x=319 white");
        else begin
            $display("[FAIL] Test 11: Quad crosshair x=319 r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // Test 12: Quad mode crosshair at y=240 → white
        settle_pixel(10'd100, 10'd240, 2'd0, 1'b1);
        if (r === 4'd15 && g === 4'd15 && b === 4'd15)
            $display("[PASS] Test 12: Quad crosshair y=240 white");
        else begin
            $display("[FAIL] Test 12: Quad crosshair y=240 r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // Test 13: Quad mode IGNORES scene_select (BR shows scene 3 even if sel=0)
        settle_pixel(10'd400, 10'd300, 2'd0, 1'b1);
        if (r > 4'd5 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 13: Quad ignores scene_select (BR=scene3 always)");
        else begin
            $display("[FAIL] Test 13: Quad sel=0 BR r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // Test 14: Blanking → black even in quad mode
        active_video = 1'b0;
        repeat (3) @(posedge clk); #1;
        if (r === 4'd0 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 14: Blanking is black in quad mode");
        else begin
            $display("[FAIL] Test 14: Blanking r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        if (fail_count == 0)
            $display("=== Scene Engine Top: ALL PASS ===");
        else
            $display("=== Scene Engine Top: %0d FAIL(s) ===", fail_count);

        $finish;
    end

endmodule
