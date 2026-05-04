// vga_test_pattern_top.v
// Minimal top-level for testing VGA output on Zybo Z7.
// Displays 8 colored vertical bars to verify VGA timing and pin mapping.
// This is a PL-only design (no Zynq PS needed).

module vga_test_pattern_top (
    input  wire       clk,          // 125 MHz system clock
    input  wire       btn0,         // BTN0 used as active-high reset
    output wire       vga_hsync,
    output wire       vga_vsync,
    output wire [3:0] vga_r,
    output wire [3:0] vga_g,
    output wire [3:0] vga_b
);

    wire rst_n = ~btn0;  // BTN0 pressed = reset

    // Pixel coordinates from VGA controller
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire       active_video;

    // Test pattern RGB
    reg [3:0] tp_r, tp_g, tp_b;

    // VGA controller (generates pixel clock + sync signals)
    vga_controller u_vga (
        .clk          (clk),
        .rst_n        (rst_n),
        .scene_r      (tp_r),
        .scene_g      (tp_g),
        .scene_b      (tp_b),
        .vga_hsync    (vga_hsync),
        .vga_vsync    (vga_vsync),
        .vga_r        (vga_r),
        .vga_g        (vga_g),
        .vga_b        (vga_b),
        .pixel_x      (pixel_x),
        .pixel_y      (pixel_y),
        .active_video (active_video)
    );

    // 8 colored vertical bars (640 / 8 = 80 pixels each)
    always @(*) begin
        if (!active_video) begin
            tp_r = 4'd0;
            tp_g = 4'd0;
            tp_b = 4'd0;
        end else begin
            case (pixel_x[9:7])  // Divide 640 pixels into 8 bars
                3'd0: begin tp_r = 4'hF; tp_g = 4'hF; tp_b = 4'hF; end  // White
                3'd1: begin tp_r = 4'hF; tp_g = 4'hF; tp_b = 4'h0; end  // Yellow
                3'd2: begin tp_r = 4'h0; tp_g = 4'hF; tp_b = 4'hF; end  // Cyan
                3'd3: begin tp_r = 4'h0; tp_g = 4'hF; tp_b = 4'h0; end  // Green
                3'd4: begin tp_r = 4'hF; tp_g = 4'h0; tp_b = 4'hF; end  // Magenta
                3'd5: begin tp_r = 4'hF; tp_g = 4'h0; tp_b = 4'h0; end  // Red
                3'd6: begin tp_r = 4'h0; tp_g = 4'h0; tp_b = 4'hF; end  // Blue
                3'd7: begin tp_r = 4'h0; tp_g = 4'h0; tp_b = 4'h0; end  // Black
            endcase
        end
    end

endmodule
