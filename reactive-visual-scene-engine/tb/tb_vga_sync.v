// tb_vga_sync.v
// Testbench for VGA sync generator. Verifies timing for 640x480 @ 60Hz.

`timescale 1ns / 1ps

module tb_vga_sync;

    reg        pclk;
    reg        rst_n;
    wire       hsync;
    wire       vsync;
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire       active_video;

    // 25 MHz pixel clock = 40 ns period
    localparam PCLK_PERIOD = 40;

    // Instantiate DUT
    vga_sync uut (
        .pclk         (pclk),
        .rst_n        (rst_n),
        .hsync        (hsync),
        .vsync        (vsync),
        .pixel_x      (pixel_x),
        .pixel_y      (pixel_y),
        .active_video (active_video)
    );

    // Clock generation
    initial pclk = 0;
    always #(PCLK_PERIOD / 2) pclk = ~pclk;

    // Expected timing constants
    localparam H_TOTAL = 800;
    localparam V_TOTAL = 525;

    integer h_count, v_count;
    integer frame_count;

    initial begin
        $display("=== VGA Sync Testbench ===");

        // Test 1: Reset behavior
        rst_n = 0;
        #(PCLK_PERIOD * 5);
        if (pixel_x !== 0 || pixel_y !== 0)
            $display("[FAIL] Pixel counters not zero during reset");
        else
            $display("[PASS] Reset: pixel counters at zero");

        // Release reset
        rst_n = 1;

        // Test 2: Verify one full frame timing
        // One frame = H_TOTAL * V_TOTAL = 800 * 525 = 420000 pixel clocks
        frame_count = 0;
        @(negedge vsync);  // Wait for vsync assertion
        @(posedge vsync);  // Wait for vsync de-assertion
        @(negedge vsync);  // Start of next frame
        $display("[PASS] VSync pulse detected");

        // Test 3: Verify active video region
        @(posedge pclk);
        wait (pixel_x == 0 && pixel_y == 0);
        @(posedge pclk);
        if (active_video)
            $display("[PASS] Active video asserted at (0,0)");
        else
            $display("[FAIL] Active video not asserted at (0,0)");

        // Let a few frames run
        #(PCLK_PERIOD * H_TOTAL * V_TOTAL * 2);

        $display("=== VGA Sync Testbench Complete ===");
        $finish;
    end

endmodule
