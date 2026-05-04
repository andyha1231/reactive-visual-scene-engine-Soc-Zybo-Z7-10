// scene_bass_bars.v
// Scene 2: Vertical bars whose height is driven by low-frequency energy.

module scene_bass_bars (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [9:0]  pixel_x,
    input  wire [9:0]  pixel_y,
    input  wire        active_video,
    input  wire [15:0] amplitude,
    input  wire [15:0] energy_low,
    input  wire [15:0] energy_mid,
    input  wire [15:0] energy_high,
    input  wire [7:0]  sensitivity,
    output reg  [3:0]  r,
    output reg  [3:0]  g,
    output reg  [3:0]  b
);

    // 8 bars across 640 pixels = 80 pixels per bar
    localparam BAR_WIDTH = 80;
    localparam NUM_BARS  = 8;
    localparam SCREEN_H  = 480;

    // Scale energy_low to bar height (0-480)
    // Use sensitivity to scale: bar_height = (energy_low * sensitivity) >> 8
    wire [23:0] scaled_energy;
    assign scaled_energy = energy_low * {8'd0, sensitivity};

    wire [9:0] bar_height;
    assign bar_height = (scaled_energy[23:14] > 10'd480) ? 10'd480 : scaled_energy[23:14];

    // Bar index from pixel_x
    wire [2:0] bar_idx;
    assign bar_idx = pixel_x[9:4] / 5;  // Approximate 80-pixel grouping

    // Pixel is within a bar if it's in the bottom `bar_height` rows
    wire in_bar;
    assign in_bar = (pixel_y >= (SCREEN_H - bar_height));

    // Bar gap (2 pixels between bars)
    wire in_gap;
    assign in_gap = (pixel_x % BAR_WIDTH) >= (BAR_WIDTH - 2);

    // Color: bars are green with brightness from height ratio
    wire [3:0] bar_brightness;
    assign bar_brightness = 4'd8 + (bar_height[9:7]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r <= 4'd0;
            g <= 4'd0;
            b <= 4'd0;
        end else if (active_video) begin
            if (in_bar && !in_gap) begin
                r <= 4'd1;
                g <= bar_brightness;
                b <= 4'd2;
            end else begin
                // Dark background
                r <= 4'd0;
                g <= 4'd0;
                b <= 4'd0;
            end
        end else begin
            r <= 4'd0;
            g <= 4'd0;
            b <= 4'd0;
        end
    end

endmodule
