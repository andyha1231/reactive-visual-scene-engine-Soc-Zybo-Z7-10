// hdmi_test_pattern_top.v
// Top-level for testing HDMI output on Zybo Z7.
// Displays 8 colored vertical bars via Digilent's rgb2dvi IP.
// This is a PL-only design (no Zynq PS needed).

module hdmi_test_pattern_top (
    input  wire       clk,           // 125 MHz system clock (K17)
    input  wire       btn0,          // BTN0 = reset (active high)
    input  wire [1:0] sw,            // SW[1:0] for future scene select
    output wire [3:0] led,           // Status LEDs
    // HDMI TX (directly to connector via TMDS)
    output wire       hdmi_tx_clk_p,
    output wire       hdmi_tx_clk_n,
    output wire [2:0] hdmi_tx_d_p,
    output wire [2:0] hdmi_tx_d_n
);

    // -------------------------------------------------------
    // Reset and Clock Generation
    // -------------------------------------------------------
    wire rst = btn0;
    wire pixel_clk;
    wire mmcm_locked;
    wire serial_clk;
    pixel_clk_gen u_pclk (
        .clk_125m  (clk),
        .rst       (rst),
        .pixel_clk (pixel_clk),
        .serial_clk(serial_clk),
        .locked    (mmcm_locked)
    );

    wire rst_n = mmcm_locked & ~rst;

    // -------------------------------------------------------
    // VGA Timing Generator (runs on 25 MHz pixel clock)
    // -------------------------------------------------------
    wire       hsync, vsync, active_video;
    wire [9:0] pixel_x, pixel_y;

    vga_sync u_sync (
        .pclk         (pixel_clk),
        .rst_n        (rst_n),
        .hsync        (hsync),
        .vsync        (vsync),
        .pixel_x      (pixel_x),
        .pixel_y      (pixel_y),
        .active_video (active_video)
    );
    // -------------------------------------------------------
    // Test Pattern: 8 Colored Vertical Bars
    // -------------------------------------------------------
    reg [7:0] tp_r, tp_g, tp_b;

    // 8 bars of exactly 80 pixels each (640 / 8 = 80)
    wire [2:0] bar_idx = (pixel_x < 80)  ? 3'd0 :
                         (pixel_x < 160) ? 3'd1 :
                         (pixel_x < 240) ? 3'd2 :
                         (pixel_x < 320) ? 3'd3 :
                         (pixel_x < 400) ? 3'd4 :
                         (pixel_x < 480) ? 3'd5 :
                         (pixel_x < 560) ? 3'd6 : 3'd7;

    always @(*) begin
        if (!active_video) begin
            tp_r = 8'd0; tp_g = 8'd0; tp_b = 8'd0;
        end else begin
            case (bar_idx)   // <-- was pixel_x[9:7]
                3'd0: begin tp_r = 8'hFF; tp_g = 8'hFF; tp_b = 8'hFF; end  // White
                3'd1: begin tp_r = 8'hFF; tp_g = 8'hFF; tp_b = 8'h00; end  // Yellow
                3'd2: begin tp_r = 8'h00; tp_g = 8'hFF; tp_b = 8'hFF; end  // Cyan
                3'd3: begin tp_r = 8'h00; tp_g = 8'hFF; tp_b = 8'h00; end  // Green
                3'd4: begin tp_r = 8'hFF; tp_g = 8'h00; tp_b = 8'hFF; end  // Magenta
                3'd5: begin tp_r = 8'hFF; tp_g = 8'h00; tp_b = 8'h00; end  // Red
                3'd6: begin tp_r = 8'h00; tp_g = 8'h00; tp_b = 8'hFF; end  // Blue
                3'd7: begin tp_r = 8'h00; tp_g = 8'h00; tp_b = 8'h00; end  // Black
            endcase
        end
    end
    // Pack RGB into 24-bit bus (R=MSB, B=LSB matches rgb2dvi default)
    wire [23:0] vid_data = {tp_r, tp_b, tp_g};

    // -------------------------------------------------------
    // Digilent rgb2dvi IP (HDMI TMDS Encoder)
    // -------------------------------------------------------
    // After generating the IP in Vivado's IP Catalog, the instance
    // name will be "rgb2dvi_0". Update the module name below if
    // you customized it differently.

    rgb2dvi_0 u_rgb2dvi (
        .PixelClk   (pixel_clk),
        .SerialClk  (serial_clk), 
        .aRst       (rst),
        .vid_pData  (vid_data),
        .vid_pVDE   (active_video),
        .vid_pHSync (hsync),
        .vid_pVSync (vsync),
        .TMDS_Clk_p (hdmi_tx_clk_p),
        .TMDS_Clk_n (hdmi_tx_clk_n),
        .TMDS_Data_p(hdmi_tx_d_p),
        .TMDS_Data_n(hdmi_tx_d_n)
    );

    // -------------------------------------------------------
    // LED Status Indicators
    // -------------------------------------------------------
    assign led[0] = mmcm_locked;     // MMCM locked = clock OK
    assign led[1] = active_video;    // Blinks with active video
    assign led[2] = sw[0];           // Mirror switch state
    assign led[3] = sw[1];

endmodule
