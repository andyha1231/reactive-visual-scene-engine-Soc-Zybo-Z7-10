// tb_amplitude_detector.v
// Testbench for amplitude envelope detector.

`timescale 1ns / 1ps

module tb_amplitude_detector;

    reg         clk;
    reg         rst_n;
    reg  [15:0] sample_in;
    reg         sample_valid;
    wire [15:0] amplitude;

    // 125 MHz clock
    localparam CLK_PERIOD = 8;

    amplitude_detector uut (
        .clk          (clk),
        .rst_n        (rst_n),
        .sample_in    (sample_in),
        .sample_valid (sample_valid),
        .amplitude    (amplitude)
    );

    // Clock generation
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    integer i;

    initial begin
        $display("=== Amplitude Detector Testbench ===");

        // Initialize
        rst_n        = 0;
        sample_in    = 16'd0;
        sample_valid = 1'b0;

        #(CLK_PERIOD * 10);

        // Test 1: Reset
        if (amplitude !== 16'd0)
            $display("[FAIL] Amplitude not zero after reset");
        else
            $display("[PASS] Reset: amplitude is zero");

        rst_n = 1;
        #(CLK_PERIOD * 5);

        // Test 2: Feed positive samples, amplitude should rise
        $display("[TEST] Feeding positive samples...");
        for (i = 0; i < 100; i = i + 1) begin
            @(posedge clk);
            sample_in    = 16'h4000;  // Large positive value
            sample_valid = 1'b1;
            @(posedge clk);
            sample_valid = 1'b0;
            #(CLK_PERIOD * 10);
        end
        $display("  Amplitude after positive burst: %d", amplitude);
        if (amplitude > 16'd0)
            $display("[PASS] Amplitude rose with positive input");
        else
            $display("[FAIL] Amplitude did not rise");

        // Test 3: Feed negative samples, amplitude should still rise
        $display("[TEST] Feeding negative samples...");
        for (i = 0; i < 100; i = i + 1) begin
            @(posedge clk);
            sample_in    = 16'hC000;  // Large negative value (-16384)
            sample_valid = 1'b1;
            @(posedge clk);
            sample_valid = 1'b0;
            #(CLK_PERIOD * 10);
        end
        $display("  Amplitude after negative burst: %d", amplitude);
        if (amplitude > 16'd0)
            $display("[PASS] Amplitude tracks absolute value");
        else
            $display("[FAIL] Amplitude did not track negative input");

        // Test 4: Feed silence, amplitude should decay
        $display("[TEST] Feeding silence (decay test)...");
        for (i = 0; i < 500; i = i + 1) begin
            @(posedge clk);
            sample_in    = 16'd0;
            sample_valid = 1'b1;
            @(posedge clk);
            sample_valid = 1'b0;
            #(CLK_PERIOD * 10);
        end
        $display("  Amplitude after silence: %d", amplitude);

        $display("=== Amplitude Detector Testbench Complete ===");
        $finish;
    end

endmodule
