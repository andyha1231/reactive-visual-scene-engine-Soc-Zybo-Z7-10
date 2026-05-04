// scene_loudness_pulse.v
// Scene 1: Center rectangle pulses in size/brightness with overall amplitude.

module scene_loudness_pulse (
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

    // Center of screen
    localparam CX = 320;
    localparam CY = 240;

    // Scale amplitude to a rectangle half-size (min 10, max 200 pixels)
    wire [8:0] scaled_amp;
    assign scaled_amp = (amplitude[15:7] > 9'd200) ? 9'd200 :
                        (amplitude[15:7] < 9'd10)  ? 9'd10  : amplitude[15:7];

    // Brightness from amplitude (upper 4 bits)
    wire [3:0] brightness;
    assign brightness = amplitude[15:12];

    // Check if pixel is inside the pulsing rectangle
    wire in_rect;
    assign in_rect = (pixel_x >= (CX - scaled_amp)) && (pixel_x < (CX + scaled_amp)) &&
                     (pixel_y >= (CY - scaled_amp)) && (pixel_y < (CY + scaled_amp));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r <= 4'd0;
            g <= 4'd0;
            b <= 4'd0;
        end else if (active_video) begin
            if (in_rect) begin
                r <= brightness;
                g <= brightness >> 1;  // Slightly tinted
                b <= brightness >> 2;
            end else begin
                // Dark background with subtle color
                r <= 4'd1;
                g <= 4'd0;
                b <= 4'd1;
            end
        end else begin
            r <= 4'd0;
            g <= 4'd0;
            b <= 4'd0;
        end
    end

endmodule
