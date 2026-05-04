// vga_controller.v
// Combines VGA sync generation with scene engine pixel output.
// Generates 25 MHz pixel clock from 125 MHz system clock.

module vga_controller (
    input  wire        clk,          // 125 MHz system clock
    input  wire        rst_n,
    // Scene engine pixel data
    input  wire [3:0]  scene_r,
    input  wire [3:0]  scene_g,
    input  wire [3:0]  scene_b,
    // VGA output
    output wire        vga_hsync,
    output wire        vga_vsync,
    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b,
    // Pixel coordinates (to scene engine)
    output wire [9:0]  pixel_x,
    output wire [9:0]  pixel_y,
    output wire        active_video
);

    // Generate 25 MHz pixel clock from 125 MHz (divide by 5)
    reg [2:0] pclk_counter;
    reg       pclk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pclk_counter <= 3'd0;
            pclk         <= 1'b0;
        end else begin
            if (pclk_counter == 3'd4) begin
                pclk_counter <= 3'd0;
                pclk         <= ~pclk;
            end else begin
                pclk_counter <= pclk_counter + 1;
            end
        end
    end

    // VGA sync generator
    vga_sync u_sync (
        .pclk         (pclk),
        .rst_n        (rst_n),
        .hsync        (vga_hsync),
        .vsync        (vga_vsync),
        .pixel_x      (pixel_x),
        .pixel_y      (pixel_y),
        .active_video (active_video)
    );

    // Blank RGB during non-active video
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            vga_r <= 4'd0;
            vga_g <= 4'd0;
            vga_b <= 4'd0;
        end else begin
            vga_r <= active_video ? scene_r : 4'd0;
            vga_g <= active_video ? scene_g : 4'd0;
            vga_b <= active_video ? scene_b : 4'd0;
        end
    end

endmodule
