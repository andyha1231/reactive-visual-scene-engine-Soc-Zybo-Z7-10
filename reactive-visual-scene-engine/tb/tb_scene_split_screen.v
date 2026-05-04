// tb_scene_split_screen.v
// Tests scene_split_screen: reset, blanking, divider line, left bass, right flash.
// Run for 10ms.
`timescale 1ns / 1ps

module tb_scene_split_screen;

    reg        clk, rst_n, active_video;
    reg [9:0]  pixel_x, pixel_y;
    reg [15:0] amplitude, energy_low, energy_mid, energy_high;
    reg [7:0]  sensitivity;
    wire [3:0] r, g, b;

    localparam CLK_PERIOD = 8;

    scene_split_screen uut (
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
    integer i;
    integer x, div_pass;
    reg saw_flash, saw_dark;
    reg [3:0] left_g;

    task pixel_tick; begin @(posedge clk); #1; end endtask

    task drive_pixel;
        input [9:0]  px, py;
        input        av;
        input [15:0] e_low, e_high;
        input [7:0]  sens;
        begin
            pixel_x      = px;
            pixel_y      = py;
            active_video = av;
            energy_low   = e_low;
            energy_high  = e_high;
            sensitivity  = sens;
            pixel_tick;
        end
    endtask

    initial begin
        $display("=== Scene Split Screen Testbench ===");
        fail_count = 0;

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
            $display("[FAIL] Test 1: Reset r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        rst_n = 1;
        repeat (3) @(posedge clk);

        // --- Test 2: Blanking ---
        drive_pixel(10'd320, 10'd240, 1'b0, 16'hFFFF, 16'hFFFF, 8'd255);
        if (r === 4'd0 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 2: Blanking is black");
        else begin
            $display("[FAIL] Test 2: Blanking not black r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // --- Test 3: Divider line at x=319,320,321 → white ---
        begin
            div_pass = 1;
            for (x = 319; x <= 321; x = x + 1) begin
                drive_pixel(x[9:0], 10'd240, 1'b1, 16'h8000, 16'h8000, 8'd128);
                if (r !== 4'd15 || g !== 4'd15 || b !== 4'd15) begin
                    $display("[FAIL] Test 3: Divider at x=%0d not white r=%0d g=%0d b=%0d", x, r, g, b);
                    div_pass = 0;
                    fail_count = fail_count + 1;
                end
            end
            if (div_pass)
                $display("[PASS] Test 3: Divider line is white at x=319-321");
        end

        // --- Test 4: Left half (x=40) with high energy_low → green bar at bottom ---
        // energy_low=0xFFFF, sensitivity=255 → bar_height=480 → y=479 in bar
        drive_pixel(10'd40, 10'd479, 1'b1, 16'hFFFF, 16'd0, 8'd255);
        if (g > 4'd0)
            $display("[PASS] Test 4: Left bass bar visible at bottom (g=%0d)", g);
        else begin
            $display("[FAIL] Test 4: Left bass bar not visible at y=479 (g=0)");
            fail_count = fail_count + 1;
        end

        // --- Test 5: Left half (x=40) with zero energy_low → black background ---
        drive_pixel(10'd40, 10'd479, 1'b1, 16'd0, 16'd0, 8'd255);
        if (r === 4'd0 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 5: Left silent - black (no bars)");
        else begin
            $display("[FAIL] Test 5: Left silent - expected black r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // --- Test 6: Right half (x=400) with high energy_high → flashing ---
        // energy_high=0xFFFF → flash_period=~0xFFFF≈0 → toggles every cycle
        // Right half shows flash_state
        energy_high  = 16'hFFFF;
        energy_low   = 16'd0;
        active_video = 1'b1;
        pixel_x      = 10'd400;
        pixel_y      = 10'd240;
        saw_flash    = 1'b0;
        saw_dark     = 1'b0;
        for (i = 0; i < 100; i = i + 1) begin
            @(posedge clk); #1;
            if (r >= 4'd8 && b >= 4'd15) saw_flash = 1'b1;
            if (r <= 4'd2)               saw_dark  = 1'b1;
        end
        if (saw_flash && saw_dark)
            $display("[PASS] Test 6: Right flash - both bright and dark seen");
        else begin
            $display("[FAIL] Test 6: Right flash - flash=%0d dark=%0d", saw_flash, saw_dark);
            fail_count = fail_count + 1;
        end

        // --- Test 7: Left and right are independent ---
        // Set high energy_low (left bars) AND high energy_high (right flash)
        // Check that left has green bar and right has non-green output
        drive_pixel(10'd40, 10'd479, 1'b1, 16'hFFFF, 16'hFFFF, 8'd255);
        begin
            left_g = g;
            drive_pixel(10'd400, 10'd479, 1'b1, 16'hFFFF, 16'hFFFF, 8'd255);
            if (left_g > 4'd0 && (r != 4'd1 || g != 4'd10))
                $display("[PASS] Test 7: Left=bass-green, right=flash-independent");
            else begin
                $display("[FAIL] Test 7: Left/right independence check - left_g=%0d right r=%0d g=%0d b=%0d",
                         left_g, r, g, b);
                fail_count = fail_count + 1;
            end
        end

        if (fail_count == 0)
            $display("=== Scene Split Screen: ALL PASS ===");
        else
            $display("=== Scene Split Screen: %0d FAIL(s) ===", fail_count);

        $finish;
    end

endmodule
