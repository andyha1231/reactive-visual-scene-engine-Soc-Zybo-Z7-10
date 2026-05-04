// tb_scene_tri_band_eq.v
// Tests scene_tri_band_eq: reset, blanking, silent (dim band tints visible),
// full energy in each band, separator rows, sensitivity scaling.
`timescale 1ns / 1ps

module tb_scene_tri_band_eq;

    reg        clk, rst_n, active_video;
    reg [9:0]  pixel_x, pixel_y;
    reg [15:0] amplitude, energy_low, energy_mid, energy_high;
    reg [7:0]  sensitivity;
    wire [3:0] r, g, b;

    localparam CLK_PERIOD = 8;

    scene_tri_band_eq uut (
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
        input [15:0] e_lo, e_md, e_hi;
        input [7:0]  sens;
        begin
            pixel_x      = px;
            pixel_y      = py;
            active_video = av;
            energy_low   = e_lo;
            energy_mid   = e_md;
            energy_high  = e_hi;
            sensitivity  = sens;
            pixel_tick;
        end
    endtask

    initial begin
        $display("=== Scene Tri-Band EQ Testbench ===");
        fail_count   = 0;

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

        // --- Test 2: Blanking is black ---
        drive_pixel(10'd100, 10'd80, 1'b0, 16'hFFFF, 16'hFFFF, 16'hFFFF, 8'd255);
        if (r === 4'd0 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 2: Blanking is black");
        else begin
            $display("[FAIL] Test 2: Blanking r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // --- Test 3: Separator row y=160 is white ---
        drive_pixel(10'd320, 10'd160, 1'b1, 16'd0, 16'd0, 16'd0, 8'd128);
        if (r === 4'd15 && g === 4'd15 && b === 4'd15)
            $display("[PASS] Test 3: Separator at y=160 is white");
        else begin
            $display("[FAIL] Test 3: Separator y=160 r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // --- Test 4: Separator row y=320 is white ---
        drive_pixel(10'd320, 10'd320, 1'b1, 16'd0, 16'd0, 16'd0, 8'd128);
        if (r === 4'd15 && g === 4'd15 && b === 4'd15)
            $display("[PASS] Test 4: Separator at y=320 is white");
        else begin
            $display("[FAIL] Test 4: Separator y=320 r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // --- Test 5: LOW band (y<160) full energy_low → red filled ---
        // bar_width = (energy*sensitivity)>>14, clamped to 640
        // With FFFF*FF = 0xFEFF01, [23:14]=0x3FB=1019 → clamp to 640. Pixel x=100 < 640.
        drive_pixel(10'd100, 10'd80, 1'b1, 16'hFFFF, 16'd0, 16'd0, 8'd255);
        if (r > 4'd5 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 5: LOW band filled - red r=%0d (g=b=0)", r);
        else begin
            $display("[FAIL] Test 5: LOW band r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // --- Test 6: MID band (160<y<320) full energy_mid → green filled ---
        drive_pixel(10'd100, 10'd200, 1'b1, 16'd0, 16'hFFFF, 16'd0, 8'd255);
        if (g > 4'd5 && r === 4'd0 && b === 4'd0)
            $display("[PASS] Test 6: MID band filled - green g=%0d (r=b=0)", g);
        else begin
            $display("[FAIL] Test 6: MID band r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // --- Test 7: HIGH band (y>320) full energy_high → blue filled ---
        drive_pixel(10'd100, 10'd400, 1'b1, 16'd0, 16'd0, 16'hFFFF, 8'd255);
        if (b > 4'd5 && r === 4'd0 && g === 4'd0)
            $display("[PASS] Test 7: HIGH band filled - blue b=%0d (r=g=0)", b);
        else begin
            $display("[FAIL] Test 7: HIGH band r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // --- Test 8: LOW band silent → dim red background visible ---
        // empty bar in low band: r=4'd1, g=0, b=0
        drive_pixel(10'd400, 10'd80, 1'b1, 16'd0, 16'd0, 16'd0, 8'd128);
        if (r === 4'd1 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 8: LOW band silent - dim red bg r=1");
        else begin
            $display("[FAIL] Test 8: LOW silent r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // --- Test 9: HIGH band silent → dim blue background visible ---
        drive_pixel(10'd400, 10'd400, 1'b1, 16'd0, 16'd0, 16'd0, 8'd128);
        if (b === 4'd1 && r === 4'd0 && g === 4'd0)
            $display("[PASS] Test 9: HIGH band silent - dim blue bg b=1");
        else begin
            $display("[FAIL] Test 9: HIGH silent r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // --- Test 10: Pixel beyond bar width is empty bg (medium energy) ---
        // energy_low=0x1000 (4096), sens=128: scaled=524288, [23:14]=32 → bar_width=32
        // Pixel x=400 > 32 → not in bar → dim red bg
        drive_pixel(10'd400, 10'd80, 1'b1, 16'h1000, 16'd0, 16'd0, 8'd128);
        if (r === 4'd1 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 10: Pixel past bar end - dim red bg");
        else begin
            $display("[FAIL] Test 10: past-bar r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // --- Test 11: Pixel within bar with same medium energy → red filled ---
        drive_pixel(10'd10, 10'd80, 1'b1, 16'h1000, 16'd0, 16'd0, 8'd128);
        if (r > 4'd5 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 11: Pixel in bar (medium energy) - red r=%0d", r);
        else begin
            $display("[FAIL] Test 11: in-bar r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        if (fail_count == 0)
            $display("=== Scene Tri-Band EQ: ALL PASS ===");
        else
            $display("=== Scene Tri-Band EQ: %0d FAIL(s) ===", fail_count);

        $finish;
    end

endmodule
