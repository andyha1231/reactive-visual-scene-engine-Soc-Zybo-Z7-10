// tb_band_energy.v
// Testbench for band energy estimator.

`timescale 1ns / 1ps

module tb_band_energy;

    reg         clk;
    reg         rst_n;
    reg  [15:0] sample_in;
    reg         sample_valid;
    wire [15:0] energy_low;
    wire [15:0] energy_mid;
    wire [15:0] energy_high;

    localparam CLK_PERIOD = 8;  // 125 MHz

    band_energy uut (
        .clk          (clk),
        .rst_n        (rst_n),
        .sample_in    (sample_in),
        .sample_valid (sample_valid),
        .energy_low   (energy_low),
        .energy_mid   (energy_mid),
        .energy_high  (energy_high)
    );

    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    integer i;
    reg signed [15:0] sine_val;

    initial begin
        $display("=== Band Energy Testbench ===");

        rst_n        = 0;
        sample_in    = 16'd0;
        sample_valid = 1'b0;
        #(CLK_PERIOD * 10);

        // Test 1: Reset
        if (energy_low !== 0 && energy_mid !== 0 && energy_high !== 0)
            $display("[FAIL] Energies not zero after reset");
        else
            $display("[PASS] Reset: all energies zero");

        rst_n = 1;
        #(CLK_PERIOD * 5);

        // Test 2: Low frequency signal (slow alternating)
        // Alternates every 64 samples -- simulates low freq
        $display("[TEST] Low frequency input...");
        for (i = 0; i < 1024; i = i + 1) begin
            @(posedge clk);
            sample_in    = (i[6]) ? 16'h3000 : 16'hD000;  // Toggle every 64 samples
            sample_valid = 1'b1;
            @(posedge clk);
            sample_valid = 1'b0;
            #(CLK_PERIOD * 4);
        end
        $display("  Low=%d  Mid=%d  High=%d", energy_low, energy_mid, energy_high);

        // Test 3: High frequency signal (fast alternating)
        $display("[TEST] High frequency input...");
        for (i = 0; i < 1024; i = i + 1) begin
            @(posedge clk);
            sample_in    = (i[0]) ? 16'h3000 : 16'hD000;  // Toggle every sample
            sample_valid = 1'b1;
            @(posedge clk);
            sample_valid = 1'b0;
            #(CLK_PERIOD * 4);
        end
        $display("  Low=%d  Mid=%d  High=%d", energy_low, energy_mid, energy_high);

        $display("=== Band Energy Testbench Complete ===");
        $finish;
    end

endmodule
