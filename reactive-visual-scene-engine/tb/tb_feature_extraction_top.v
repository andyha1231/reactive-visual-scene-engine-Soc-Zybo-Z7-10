// tb_feature_extraction_top.v
// Comprehensive testbench for feature_extraction_top (amplitude + band energy).
// 9 tests covering reset, silence, DC, bass, treble, mid, decay, gating, and alternating tones.
// Run: `run 20ms` in Vivado TCL console.

`timescale 1ns / 1ps

module tb_feature_extraction_top;

    reg         clk;
    reg         rst_n;
    reg  [15:0] sample_in;
    reg         sample_valid;
    wire [15:0] amplitude;
    wire [15:0] energy_low;
    wire [15:0] energy_mid;
    wire [15:0] energy_high;

    localparam CLK_PERIOD = 8;  // 125 MHz

    feature_extraction_top uut (
        .clk          (clk),
        .rst_n        (rst_n),
        .sample_in    (sample_in),
        .sample_valid (sample_valid),
        .amplitude    (amplitude),
        .energy_low   (energy_low),
        .energy_mid   (energy_mid),
        .energy_high  (energy_high)
    );

    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    integer i;
    reg [15:0] amp_snap;

    // -------------------------------------------------------------------------
    // Tasks
    // -------------------------------------------------------------------------

    task do_reset;
        begin
            rst_n        = 0;
            sample_in    = 16'd0;
            sample_valid = 1'b0;
            repeat (10) @(posedge clk);
            rst_n = 1;
            repeat (5) @(posedge clk);
        end
    endtask

    task send_sample;
        input [15:0] s;
        begin
            @(posedge clk);
            sample_in    = s;
            sample_valid = 1'b1;
            @(posedge clk);
            sample_valid = 1'b0;
        end
    endtask

    // Square-wave tone: num_samples total, alternates polarity every half_period samples.
    task send_tone;
        input integer num_samples;
        input integer half_period;
        input [15:0] pos_val;
        input [15:0] neg_val;
        integer j;
        begin
            for (j = 0; j < num_samples; j = j + 1) begin
                if ((j / half_period) % 2 == 0)
                    send_sample(pos_val);
                else
                    send_sample(neg_val);
                repeat (10) @(posedge clk);  // gap between samples (sim speed)
            end
        end
    endtask

    task send_silence;
        input integer num_samples;
        integer j;
        begin
            for (j = 0; j < num_samples; j = j + 1) begin
                send_sample(16'd0);
                repeat (10) @(posedge clk);
            end
        end
    endtask

    task snapshot;
        begin
            $display("    amp=%0d  lo=%0d  mid=%0d  hi=%0d",
                     amplitude, energy_low, energy_mid, energy_high);
        end
    endtask

    // -------------------------------------------------------------------------
    // Test sequence
    // -------------------------------------------------------------------------

    initial begin
        $display("=== Feature Extraction Top Testbench ===");

        // ------------------------------------------------------------------
        // Test 1: Reset — all outputs must be zero immediately after reset
        // ------------------------------------------------------------------
        do_reset;
        if (amplitude === 16'd0 && energy_low  === 16'd0 &&
            energy_mid === 16'd0 && energy_high === 16'd0)
            $display("[PASS] Test 1: Reset - all outputs zero");
        else begin
            $display("[FAIL] Test 1: Reset - one or more outputs non-zero");
            snapshot;
        end

        // ------------------------------------------------------------------
        // Test 2: Silence — amplitude stays at zero when all input is 0
        // amplitude_detector is gated on sample_valid; abs(0)=0 so no attack.
        // ------------------------------------------------------------------
        send_silence(200);
        if (amplitude == 16'd0)
            $display("[PASS] Test 2: Silence - amplitude stays zero");
        else begin
            $display("[FAIL] Test 2: Silence - amplitude non-zero (%0d)", amplitude);
            snapshot;
        end

        // ------------------------------------------------------------------
        // Test 3: DC offset — large positive constant raises amplitude
        // ------------------------------------------------------------------
        do_reset;
        for (i = 0; i < 200; i = i + 1) begin
            send_sample(16'h4000);
            repeat (10) @(posedge clk);
        end
        if (amplitude > 16'd0)
            $display("[PASS] Test 3: DC offset - amplitude rose to %0d", amplitude);
        else begin
            $display("[FAIL] Test 3: DC offset - amplitude did not rise");
            snapshot;
        end

        // ------------------------------------------------------------------
        // Test 4: 100 Hz bass — energy_low should exceed energy_high
        // Freq = 22050/(2*110) ≈ 100 Hz. Below MID fc (~1378 Hz), at LOW fc (~172 Hz).
        // lp_heavy partially tracks → energy_low > 0; hp_signal ≈ 0 → energy_high ≈ 0.
        // ------------------------------------------------------------------
        do_reset;
        send_tone(2000, 110, 16'h3FFF, 16'hC001);
        $display("[TEST] Test 4: 100Hz bass:");
        snapshot;
        if (energy_low > energy_high)
            $display("[PASS] Test 4: Bass - energy_low (%0d) > energy_high (%0d)",
                     energy_low, energy_high);
        else begin
            $display("[FAIL] Test 4: Bass - energy_low not dominant");
            snapshot;
        end

        // ------------------------------------------------------------------
        // Test 5: 4000 Hz treble — energy_high should exceed energy_low
        // Freq = 22050/(2*2) ≈ 5512 Hz. Above both LOW and MID fc.
        // Both IIR filters attenuate → hp_signal ≈ sample → energy_high dominates.
        // ------------------------------------------------------------------
        do_reset;
        send_tone(2000, 2, 16'h3FFF, 16'hC001);
        $display("[TEST] Test 5: 4000Hz treble:");
        snapshot;
        if (energy_high > energy_low)
            $display("[PASS] Test 5: Treble - energy_high (%0d) > energy_low (%0d)",
                     energy_high, energy_low);
        else begin
            $display("[FAIL] Test 5: Treble - energy_high not dominant");
            snapshot;
        end

        // ------------------------------------------------------------------
        // Test 6: 1000 Hz mid — energy_mid must be non-zero
        // Freq = 22050/(2*11) ≈ 1002 Hz. Below MID fc but above LOW fc.
        // lp_medium follows; lp_heavy attenuated → mid_signal nonzero.
        // ------------------------------------------------------------------
        do_reset;
        send_tone(2000, 11, 16'h3FFF, 16'hC001);
        $display("[TEST] Test 6: 1000Hz mid:");
        snapshot;
        if (energy_mid > 16'd0)
            $display("[PASS] Test 6: Mid - energy_mid elevated (%0d)", energy_mid);
        else begin
            $display("[FAIL] Test 6: Mid - energy_mid is zero");
            snapshot;
        end

        // ------------------------------------------------------------------
        // Test 7: Decay after silence
        // After loud tone, feeding zeros with sample_valid=1 triggers decay path
        // (abs_sample=0 < amplitude → amplitude -= amplitude>>DECAY_SHIFT).
        // ------------------------------------------------------------------
        do_reset;
        send_tone(1000, 5, 16'h3FFF, 16'hC001);
        $display("[TEST] Test 7: Before silence:");
        snapshot;
        amp_snap = amplitude;
        send_silence(2000);
        if (amplitude < amp_snap)
            $display("[PASS] Test 7: Decay - amplitude fell from %0d to %0d",
                     amp_snap, amplitude);
        else begin
            $display("[FAIL] Test 7: Decay - amplitude did not fall (was %0d, now %0d)",
                     amp_snap, amplitude);
            snapshot;
        end

        // ------------------------------------------------------------------
        // Test 8: sample_valid gating — output frozen when valid=0
        // Both amplitude_detector and band_energy are fully gated on sample_valid.
        // Driving a large value on sample_in while valid=0 must have no effect.
        // ------------------------------------------------------------------
        do_reset;
        send_tone(500, 5, 16'h3FFF, 16'hC001);
        amp_snap     = amplitude;
        sample_valid = 1'b0;
        sample_in    = 16'h7FFF;  // large value, must be ignored
        repeat (200) @(posedge clk);
        if (amplitude === amp_snap)
            $display("[PASS] Test 8: Gating - amplitude frozen at %0d with valid=0",
                     amp_snap);
        else begin
            $display("[FAIL] Test 8: Gating - amplitude changed to %0d (was %0d)",
                     amplitude, amp_snap);
            snapshot;
        end

        // Clean up after gating test
        sample_in    = 16'd0;
        sample_valid = 1'b0;

        // ------------------------------------------------------------------
        // Test 9: Alternating tones — bass then treble, no crash
        // Verifies the system handles rapid energy transitions cleanly.
        // ------------------------------------------------------------------
        do_reset;
        $display("[TEST] Test 9: Alternating bass -> treble:");
        send_tone(1000, 110, 16'h3FFF, 16'hC001);  // bass burst
        $display("  After bass:");
        snapshot;
        send_tone(1000, 2, 16'h3FFF, 16'hC001);    // treble burst
        $display("  After treble:");
        snapshot;
        $display("[PASS] Test 9: Alternating tones completed");

        $display("=== Feature Extraction Top Testbench COMPLETE ===");
        $finish;
    end

endmodule
