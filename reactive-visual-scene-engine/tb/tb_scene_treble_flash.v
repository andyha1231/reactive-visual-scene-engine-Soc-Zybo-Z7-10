// tb_scene_treble_flash.v
// Tests scene_treble_flash: reset, blanking, edge flash behavior, center glow.
// Run for 10ms to observe flash_state toggling.
`timescale 1ns / 1ps

module tb_scene_treble_flash;

    reg        clk, rst_n, active_video, freeze;
    reg [9:0]  pixel_x, pixel_y;
    reg [15:0] amplitude, energy_low, energy_mid, energy_high;
    reg [7:0]  sensitivity;
    wire [3:0] r, g, b;

    localparam CLK_PERIOD = 8;

    scene_treble_flash uut (
        .clk(clk), .rst_n(rst_n),
        .pixel_x(pixel_x), .pixel_y(pixel_y), .active_video(active_video),
        .amplitude(amplitude), .energy_low(energy_low),
        .energy_mid(energy_mid), .energy_high(energy_high),
        .sensitivity(sensitivity),
        .freeze(freeze),
        .r(r), .g(g), .b(b)
    );

    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    integer fail_count;
    integer i;
    reg saw_bright, saw_dark;
    reg [3:0] r_snap;

    task pixel_tick; begin @(posedge clk); #1; end endtask

    task drive_pixel;
        input [9:0]  px, py;
        input        av;
        input [15:0] e_high, e_mid;
        begin
            pixel_x      = px;
            pixel_y      = py;
            active_video = av;
            energy_high  = e_high;
            energy_mid   = e_mid;
            pixel_tick;
        end
    endtask

    initial begin
        $display("=== Scene Treble Flash Testbench ===");
        fail_count = 0;

        rst_n        = 0;
        active_video = 0;
        freeze       = 0;
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
        drive_pixel(10'd5, 10'd5, 1'b0, 16'hFFFF, 16'hFFFF);
        if (r === 4'd0 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 2: Blanking is black");
        else begin
            $display("[FAIL] Test 2: Blanking not black r=%0d g=%0d b=%0d", r, g, b);
            fail_count = fail_count + 1;
        end

        // --- Test 3: Center pixel with no treble → center glow uses energy_mid ---
        // energy_mid=0 → center_brightness=0 → center pixels are fully black
        drive_pixel(10'd320, 10'd240, 1'b1, 16'd0, 16'd0);
        if (r === 4'd0 && b === 4'd0)
            $display("[PASS] Test 3: Center quiet - black center r=%0d b=%0d", r, b);
        else begin
            $display("[FAIL] Test 3: Center quiet - expected black, got r=%0d b=%0d", r, b);
            fail_count = fail_count + 1;
        end

        // --- Test 4: Center pixel with mid energy → subtle glow ---
        // energy_mid=0x8000 → center_brightness=0x8000[15:12]=8
        drive_pixel(10'd320, 10'd240, 1'b1, 16'd0, 16'h8000);
        if (b > 4'd0)
            $display("[PASS] Test 4: Center mid energy - glow visible b=%0d", b);
        else begin
            $display("[FAIL] Test 4: Center mid energy - expected b>0");
            fail_count = fail_count + 1;
        end

        // --- Test 5: Edge pixel with high treble → flash_state will toggle ---
        // energy_high=0xFFFF → flash_period = ~0xFFFF = 0 → toggles every cycle
        // Run several clocks while monitoring edge pixel, expect both bright and dark states
        energy_high  = 16'hFFFF;
        energy_mid   = 16'd0;
        active_video = 1'b1;
        pixel_x      = 10'd5;   // edge zone (< EDGE_WIDTH=60)
        pixel_y      = 10'd240;
        saw_bright   = 1'b0;
        saw_dark     = 1'b0;
        for (i = 0; i < 100; i = i + 1) begin
            @(posedge clk); #1;
            if (r >= 4'd8 && b >= 4'd15) saw_bright = 1'b1;
            if (r <= 4'd2 && g <= 4'd2)  saw_dark   = 1'b1;
        end
        if (saw_bright && saw_dark)
            $display("[PASS] Test 5: Edge flashing - saw both bright and dark states");
        else begin
            $display("[FAIL] Test 5: Edge flashing - bright=%0d dark=%0d", saw_bright, saw_dark);
            fail_count = fail_count + 1;
        end

        // --- Test 6: With zero treble → very slow flash (period=2_000_000 cycles) ---
        // Across short window, flash_state should remain stable (no toggle observed)
        rst_n = 0; repeat (5) @(posedge clk); rst_n = 1;
        energy_high  = 16'd0;
        active_video = 1'b1;
        pixel_x      = 10'd5;
        pixel_y      = 10'd10;
        @(posedge clk); #1;
        begin
            r_snap = r;
            // Check that over 1000 cycles, output doesn't change (period >> 1000)
            repeat (1000) @(posedge clk);
            #1;
            if (r === r_snap)
                $display("[PASS] Test 6: Slow flash - stable over 1000 cycles");
            else begin
                $display("[FAIL] Test 6: Slow flash - unexpected change");
                fail_count = fail_count + 1;
            end
        end

        if (fail_count == 0)
            $display("=== Scene Treble Flash: ALL PASS ===");
        else
            $display("=== Scene Treble Flash: %0d FAIL(s) ===", fail_count);

        $finish;
    end

endmodule
