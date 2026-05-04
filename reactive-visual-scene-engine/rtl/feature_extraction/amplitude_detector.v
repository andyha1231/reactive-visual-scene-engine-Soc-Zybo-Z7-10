// amplitude_detector.v
// Computes a running amplitude envelope from signed 16-bit audio samples.
// Uses absolute value + exponential moving average (shift-based, no multiplier).

module amplitude_detector #(
    parameter ATTACK_SHIFT = 2,   // Smaller = faster attack (right-shift amount)
    parameter DECAY_SHIFT  = 6    // Larger  = slower decay  (right-shift amount)
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] sample_in,      // Signed 16-bit audio sample
    input  wire        sample_valid,
    output reg  [15:0] amplitude       // Unsigned amplitude envelope
);

    wire [15:0] abs_sample;

    // Absolute value of signed sample
    assign abs_sample = sample_in[15] ? (~sample_in + 16'd1) : sample_in;

    // Exponential moving average envelope
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            amplitude <= 16'd0;
        end else if (sample_valid) begin
            if (abs_sample > amplitude) begin
                // Attack: rise quickly toward peak
                amplitude <= amplitude + ((abs_sample - amplitude) >> ATTACK_SHIFT);
            end else begin
                // Decay: fall slowly
                amplitude <= amplitude - (amplitude >> DECAY_SHIFT);
            end
        end
    end

endmodule
