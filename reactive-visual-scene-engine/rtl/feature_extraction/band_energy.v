// band_energy.v
// Estimates energy in low, mid, and high frequency bands using
// shift-based single-pole IIR filters. No multipliers required.
//
// Low band:  heavy smoothing  (large alpha = big shift)
// High band: original - low_pass = high_pass
// Mid band:  medium_low_pass - heavy_low_pass
//
// Pipeline: 2-stage to break 14-level CARRY4 critical path.
//   Stage 1: IIR filter update + register abs band values
//   Stage 2: EMA energy update from registered abs values

module band_energy #(
    parameter LOW_SHIFT  = 4,    // Low-pass cutoff: fc ≈ 22050/(2π×16) ≈ 219 Hz
    parameter MID_SHIFT  = 1,    // Mid-range cutoff: fc ≈ 22050/(2π×2)  ≈ 1750 Hz
    parameter EMA_SHIFT  = 5     // Energy smoothing factor
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] sample_in,
    input  wire        sample_valid,
    output reg  [15:0] energy_low,
    output reg  [15:0] energy_mid,
    output reg  [15:0] energy_high
);

    // IIR filter states
    reg signed [17:0] lp_heavy;
    reg signed [17:0] lp_medium;

    wire signed [17:0] sample_ext = {{2{sample_in[15]}}, sample_in};

    // Band signals (combinational)
    wire signed [17:0] hp_signal  = sample_ext - lp_medium;
    wire signed [17:0] mid_signal = lp_medium  - lp_heavy;
    wire signed [17:0] low_signal = lp_heavy;

    // Absolute values (combinational) — feeds stage-1 pipeline registers
    wire [15:0] abs_low_c  = low_signal[17] ? (~low_signal[15:0] + 1) : low_signal[15:0];
    wire [15:0] abs_mid_c  = mid_signal[17] ? (~mid_signal[15:0] + 1) : mid_signal[15:0];
    wire [15:0] abs_high_c = hp_signal[17]  ? (~hp_signal[15:0]  + 1) : hp_signal[15:0];

    // Stage-1 pipeline registers — break the sample_in→energy_high carry chain
    reg [15:0] abs_low_r, abs_mid_r, abs_high_r;
    reg        valid_d;

    // Stage 1: IIR update + latch abs values
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lp_heavy   <= 18'sd0;
            lp_medium  <= 18'sd0;
            abs_low_r  <= 16'd0;
            abs_mid_r  <= 16'd0;
            abs_high_r <= 16'd0;
            valid_d    <= 1'b0;
        end else begin
            valid_d <= sample_valid;
            if (sample_valid) begin
                lp_heavy  <= lp_heavy  + ((sample_ext - lp_heavy)  >>> LOW_SHIFT);
                lp_medium <= lp_medium + ((sample_ext - lp_medium) >>> MID_SHIFT);
                abs_low_r  <= abs_low_c;
                abs_mid_r  <= abs_mid_c;
                abs_high_r <= abs_high_c;
            end
        end
    end

    // Stage 2: EMA energy update from registered abs values
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            energy_low  <= 16'd0;
            energy_mid  <= 16'd0;
            energy_high <= 16'd0;
        end else if (valid_d) begin
            energy_low  <= (abs_low_r  >= energy_low)
                         ? energy_low  + ((abs_low_r  - energy_low)  >> EMA_SHIFT)
                         : energy_low  - ((energy_low  - abs_low_r)  >> EMA_SHIFT);
            energy_mid  <= (abs_mid_r  >= energy_mid)
                         ? energy_mid  + ((abs_mid_r  - energy_mid)  >> EMA_SHIFT)
                         : energy_mid  - ((energy_mid  - abs_mid_r)  >> EMA_SHIFT);
            energy_high <= (abs_high_r >= energy_high)
                         ? energy_high + ((abs_high_r - energy_high) >> EMA_SHIFT)
                         : energy_high - ((energy_high - abs_high_r) >> EMA_SHIFT);
        end
    end

endmodule
