// tb_scene_bass_bars.v
// Tests scene_bass_bars: reset, blanking, silent (all black bg), low energy (bars visible).
`timescale 1ns / 1ps

module tb_scene_bass_bars;

    reg        clk, rst_n, active_video;
    reg [9:0]  pixel_x, pixel_y;
    reg [15:0] amplitude, energy_low, energy_mid, energy_high;
    reg [7:0]  sensitivity;
    wire [3:0] r, g, b;

    localparam CLK_PERIOD = 8;

    scene_bass_bars uut (
        .clk(clk), .rst_n(rst_n),
        .pixel_x(pixel_x), .pixel_y(pixel_y), .active_video(active_video),
        .amplitude(amplitude), .energy_low(energy_low),
        .energy_mid(energy_mid), .energy_high(energy_high),
        .sensitivity(sensitivity),
        .r(r), .g(g), .b(b)
    );

    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    integer fail_count;

    task pixel_tick;
        begin @(posedge clk); #1; end
    endtask

    task drive_pixel;
        input [9:0]  px, py;
        input        av;
        input [15:0] e_low;
        input [7:0]  sens;
        begin
            pixel_x      = px;
            pixel_y      = py;
            active_video = av;
            energy_low   = e_low;
            sensitivity  = sens;
            pixel_tick;
        end
    endtask

    initial begin
        $display("=== Scene Bass Bars Testbench ===");
        fail_count  = 0;

        rst_n        = 0;
        active_video = 0;
        pixel_x      = 0; pixel_y = 0;
        amplitude    = 0; energy_low = 0; energy_mid = 0; energy_high = 0;
        sensitivity  = 8'd128;
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

        // --- Test 2: Blanking ---
        drive_pixel(10'd40, 10'd400, 1'b0, 16'hFFFF, 8'd255);
        if (r === 4'd0 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 2: Blanking is black");
        else begin
            $display("[FAIL] Test 2: Blanking not black r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // --- Test 3: Silent (energy_low=0) → background black ---
        // bar_height = 0 → no bar anywhere → all black background
        drive_pixel(10'd40, 10'd400, 1'b1, 16'd0, 8'd255);
        if (r === 4'd0 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 3: Silent - black background (no bars)");
        else begin
            $display("[FAIL] Test 3: Silent - expected black, got r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // --- Test 4: Full energy_low → bar should reach top (bar_height=480) ---
        // bar_height = (energy_low * sensitivity)[23:14]
        // energy_low=0xFFFF, sensitivity=255 → scaled=0xFFFF*0xFF = 0xFEFF01
        // [23:14] = 0x3FB = 1019 → clamped to 480
        // Bottom pixel (y=479) is always in bar
        drive_pixel(10'd40, 10'd479, 1'b1, 16'hFFFF, 8'd255);
        if (g > 4'd0)
            $display("[PASS] Test 4: Full energy - bottom pixel in bar (g=%0d)", g);
        else begin
            $display("[FAIL] Test 4: Full energy - bottom pixel not in bar (g=0)");
            fail_count = fail_count + 1;
        end

        // --- Test 5: Top pixel (y=0) - with full energy bars reach top ---
        // bar_height=480 → (SCREEN_H - bar_height)=0 → y=0 >= 0 → in bar
        drive_pixel(10'd40, 10'd0, 1'b1, 16'hFFFF, 8'd255);
        if (g > 4'd0)
            $display("[PASS] Test 5: Full energy - top pixel also in bar (g=%0d)", g);
        else begin
            $display("[FAIL] Test 5: Full energy - top pixel not in bar");
            fail_count = fail_count + 1;
        end

        // --- Test 6: Gap pixels are black (pixel_x at right edge of bar, every 80px) ---
        // Bar gap: (pixel_x % 80) >= 78
        drive_pixel(10'd78, 10'd479, 1'b1, 16'hFFFF, 8'd255);
        if (g === 4'd0)
            $display("[PASS] Test 6: Gap pixel is black at x=78 (r=%0d g=%0d b=%0d)", r, g, b);
        else begin
            $display("[FAIL] Test 6: Gap pixel not black (g=%0d)", g);
            fail_count = fail_count + 1;
        end

        // --- Test 7: Medium energy → only bottom portion has bars ---
        // energy_low=0x1000 (4096), sensitivity=128
        // scaled = 4096*128 = 524288 → [23:14] = 524288>>14 = 32
        // bar_height=32 → bar is at y >= 480-32 = 448
        drive_pixel(10'd40, 10'd400, 1'b1, 16'h1000, 8'd128);
        if (g === 4'd0)
            $display("[PASS] Test 7: Medium energy - y=400 not in bar (above bar top)");
        else begin
            $display("[FAIL] Test 7: Medium energy - y=400 unexpectedly in bar (g=%0d)", g);
            fail_count = fail_count + 1;
        end

        drive_pixel(10'd40, 10'd470, 1'b1, 16'h1000, 8'd128);
        if (g > 4'd0)
            $display("[PASS] Test 7b: Medium energy - y=470 in bar (g=%0d)", g);
        else begin
            $display("[FAIL] Test 7b: Medium energy - y=470 should be in bar");
            fail_count = fail_count + 1;
        end

        if (fail_count == 0)
            $display("=== Scene Bass Bars: ALL PASS ===");
        else
            $display("=== Scene Bass Bars: %0d FAIL(s) ===", fail_count);

        $finish;
    end

endmodule
