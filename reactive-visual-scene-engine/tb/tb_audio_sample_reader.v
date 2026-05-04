// tb_audio_sample_reader.v
// Testbench for BRAM-based audio sample reader.

`timescale 1ns / 1ps

module tb_audio_sample_reader;

    // Use small values for simulation speed
    localparam CLK_FREQ     = 1000;     // Simulated "1 kHz" clock
    localparam SAMPLE_RATE  = 100;      // 100 samples/sec
    localparam SAMPLE_COUNT = 16;       // 16 samples in memory
    localparam ADDR_WIDTH   = 4;

    reg                    clk;
    reg                    rst_n;
    reg                    en;
    wire [ADDR_WIDTH-1:0]  bram_addr;
    reg  [15:0]            bram_dout;
    wire                   bram_en;
    wire [15:0]            sample_out;
    wire                   sample_valid;

    localparam CLK_PERIOD = 1_000_000;  // 1 ms for 1 kHz sim clock

    audio_sample_reader #(
        .CLK_FREQ     (CLK_FREQ),
        .SAMPLE_RATE  (SAMPLE_RATE),
        .SAMPLE_COUNT (SAMPLE_COUNT),
        .ADDR_WIDTH   (ADDR_WIDTH)
    ) uut (
        .clk          (clk),
        .rst_n        (rst_n),
        .en           (en),
        .bram_addr    (bram_addr),
        .bram_dout    (bram_dout),
        .bram_en      (bram_en),
        .sample_out   (sample_out),
        .sample_valid (sample_valid)
    );

    // Clock generation
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Simple BRAM model: address = data
    always @(*) begin
        bram_dout = {12'd0, bram_addr};
    end

    integer sample_count;

    initial begin
        $display("=== Audio Sample Reader Testbench ===");

        rst_n = 0;
        en    = 0;
        sample_count = 0;

        #(CLK_PERIOD * 5);

        // Test 1: Reset
        if (bram_addr !== 0)
            $display("[FAIL] Address not zero during reset");
        else
            $display("[PASS] Reset: address is zero");

        rst_n = 1;
        #(CLK_PERIOD * 3);

        // Test 2: Enable playback, count samples
        en = 1;
        repeat (SAMPLE_COUNT * 2 + 5) begin
            @(posedge clk);
            if (sample_valid) begin
                $display("  Sample %0d: addr=%0d data=0x%04X", sample_count, bram_addr, sample_out);
                sample_count = sample_count + 1;
            end
        end

        // Test 3: Address wrapping
        if (sample_count >= SAMPLE_COUNT)
            $display("[PASS] Received enough samples, wrapping likely occurred");

        // Test 4: Disable
        en = 0;
        #(CLK_PERIOD * 20);
        if (!sample_valid)
            $display("[PASS] No samples when disabled");

        $display("=== Audio Sample Reader Testbench Complete ===");
        $finish;
    end

endmodule
