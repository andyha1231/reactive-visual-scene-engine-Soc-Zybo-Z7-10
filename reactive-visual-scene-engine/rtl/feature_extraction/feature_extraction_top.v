// feature_extraction_top.v
// Top-level wrapper for audio feature extraction.
// Instantiates amplitude detector and band energy estimator.

module feature_extraction_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] sample_in,
    input  wire        sample_valid,
    output wire [15:0] amplitude,
    output wire [15:0] energy_low,
    output wire [15:0] energy_mid,
    output wire [15:0] energy_high
);

    amplitude_detector u_amp (
        .clk          (clk),
        .rst_n        (rst_n),
        .sample_in    (sample_in),
        .sample_valid (sample_valid),
        .amplitude    (amplitude)
    );

    band_energy u_band (
        .clk          (clk),
        .rst_n        (rst_n),
        .sample_in    (sample_in),
        .sample_valid (sample_valid),
        .energy_low   (energy_low),
        .energy_mid   (energy_mid),
        .energy_high  (energy_high)
    );

endmodule
