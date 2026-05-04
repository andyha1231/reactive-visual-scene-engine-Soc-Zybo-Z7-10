// vga_sync.v
// VGA timing generator for 640x480 @ 60Hz.
// Pixel clock: 25 MHz (derived from system clock externally or via counter).

module vga_sync (
    input  wire        pclk,        // 25 MHz pixel clock
    input  wire        rst_n,
    output reg         hsync,
    output reg         vsync,
    output reg  [9:0]  pixel_x,     // Current horizontal pixel (0-639 active)
    output reg  [9:0]  pixel_y,     // Current vertical pixel (0-479 active)
    output wire        active_video  // High during visible area
);

    // 640x480 @ 60Hz VGA timing parameters
    localparam H_ACTIVE  = 640;
    localparam H_FP      = 16;    // Front porch
    localparam H_SYNC    = 96;    // Sync pulse
    localparam H_BP      = 48;    // Back porch
    localparam H_TOTAL   = H_ACTIVE + H_FP + H_SYNC + H_BP;  // 800

    localparam V_ACTIVE  = 480;
    localparam V_FP      = 10;
    localparam V_SYNC    = 2;
    localparam V_BP      = 33;
    localparam V_TOTAL   = V_ACTIVE + V_FP + V_SYNC + V_BP;   // 525

    // Active video flag
    assign active_video = (pixel_x < H_ACTIVE) && (pixel_y < V_ACTIVE);

    // Horizontal counter
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_x <= 10'd0;
        end else begin
            if (pixel_x == H_TOTAL - 1)
                pixel_x <= 10'd0;
            else
                pixel_x <= pixel_x + 1;
        end
    end

    // Vertical counter
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_y <= 10'd0;
        end else if (pixel_x == H_TOTAL - 1) begin
            if (pixel_y == V_TOTAL - 1)
                pixel_y <= 10'd0;
            else
                pixel_y <= pixel_y + 1;
        end
    end

    // Sync signals (active low)
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            hsync <= 1'b1;
            vsync <= 1'b1;
        end else begin
            hsync <= ~((pixel_x >= H_ACTIVE + H_FP) && (pixel_x < H_ACTIVE + H_FP + H_SYNC));
            vsync <= ~((pixel_y >= V_ACTIVE + V_FP) && (pixel_y < V_ACTIVE + V_FP + V_SYNC));
        end
    end

endmodule
