// tb_scene_loudness_pulse.v
// Tests scene_loudness_pulse: reset, blanking, active+silent, active+loud.
`timescale 1ns / 1ps

module tb_scene_loudness_pulse;

    reg        clk, rst_n, active_video;
    reg [9:0]  pixel_x, pixel_y;
    reg [15:0] amplitude, energy_low, energy_mid, energy_high;
    reg [7:0]  sensitivity;
    wire [3:0] r, g, b;

    localparam CLK_PERIOD = 8;

    scene_loudness_pulse uut (
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

    // Simulate one pixel clock
    task pixel_tick;
        begin @(posedge clk); #1; end
    endtask

    // Scan a single pixel at (x,y) with given audio, return output
    task drive_pixel;
        input [9:0]  px, py;
        input        av;
        input [15:0] amp;
        begin
            pixel_x      = px;
            pixel_y      = py;
            active_video = av;
            amplitude    = amp;
            pixel_tick;
        end
    endtask

    initial begin
        $display("=== Scene Loudness Pulse Testbench ===");
        fail_count  = 0;

        // Init
        rst_n        = 0;
        active_video = 0;
        pixel_x      = 0;
        pixel_y      = 0;
        amplitude    = 0;
        energy_low   = 0;
        energy_mid   = 0;
        energy_high  = 0;
        sensitivity  = 8'd128;
        repeat (10) @(posedge clk);

        // --- Test 1: Reset clears outputs ---
        if (r === 4'd0 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 1: Reset - outputs zero");
        else begin
            $display("[FAIL] Test 1: Reset - r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        rst_n = 1;
        repeat (3) @(posedge clk);

        // --- Test 2: Blanking region always black regardless of amplitude ---
        drive_pixel(10'd0, 10'd0, 1'b0, 16'hFFFF);
        if (r === 4'd0 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 2: Blanking is black");
        else begin
            $display("[FAIL] Test 2: Blanking not black - r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // --- Test 3: Active video, silence → background color (non-zero) ---
        // Use corner pixel (10,10) — always outside the minimum rect [310,330)×[230,250)
        drive_pixel(10'd10, 10'd10, 1'b1, 16'd0);
        if (r !== 4'd0 || g !== 4'd0 || b !== 4'd0)
            $display("[PASS] Test 3: Active+silence - background pixel r=%0d g=%0d b=%0d", r, g, b);
        else begin
            $display("[FAIL] Test 3: Active+silence - background pixel all black");
            fail_count = fail_count + 1;
        end

        // --- Test 4: Active video, loud center pixel → bright rect ---
        // With amplitude=0x7FFF, scaled_amp = 0x7FFF>>7 = 255 (clamped to 200)
        // Center pixel (320,240) is always inside rect when scaled_amp=200
        drive_pixel(10'd320, 10'd240, 1'b1, 16'h7FFF);
        if (r > 4'd0)
            $display("[PASS] Test 4: Loud center - r=%0d (non-zero brightness)", r);
        else begin
            $display("[FAIL] Test 4: Loud center - r=0 (expected brightness)");
            fail_count = fail_count + 1;
        end

        // --- Test 5: Corner pixel outside rect when quiet → background ---
        drive_pixel(10'd1, 10'd1, 1'b1, 16'd0);
        // With amplitude=0, scaled_amp=10 (min), corner pixel is outside rect
        if (r !== 4'd0 || b !== 4'd0)
            $display("[PASS] Test 5: Quiet corner - background color visible r=%0d b=%0d", r, b);
        else begin
            $display("[FAIL] Test 5: Quiet corner - background should be non-zero");
            fail_count = fail_count + 1;
        end

        // --- Test 6: active_video=0 mid-frame → black even if loud ---
        drive_pixel(10'd320, 10'd240, 1'b0, 16'hFFFF);
        if (r === 4'd0 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 6: Blanking override - stays black");
        else begin
            $display("[FAIL] Test 6: Blanking override - got r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // Summary
        if (fail_count == 0)
            $display("=== Scene Loudness Pulse: ALL PASS ===");
        else
            $display("=== Scene Loudness Pulse: %0d FAIL(s) ===", fail_count);

        $finish;
    end

endmodule
