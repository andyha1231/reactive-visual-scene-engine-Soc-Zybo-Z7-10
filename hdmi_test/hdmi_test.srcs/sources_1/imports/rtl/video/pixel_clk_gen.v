// pixel_clk_gen.v
// Generates a 25 MHz pixel clock from the 125 MHz system clock
// using a Xilinx MMCME2_BASE primitive (no IP generation needed).
//
// VCO: 125 MHz * 8 = 1000 MHz (within 600-1200 MHz range)
// Output: 1000 MHz / 40 = 25 MHz

module pixel_clk_gen (
    input  wire clk_125m,
    input  wire rst,
    output wire pixel_clk,     // 25 MHz pixel clock output
    output wire serial_clk,    // 125 MHz serial clock (5x pixel)
    output wire locked
);

    wire clkfb;
    wire clkout0;
    wire clkout1;
    MMCME2_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKFBOUT_MULT_F    (8.0),       // VCO = 125 * 8 = 1000 MHz
        .CLKFBOUT_PHASE     (0.0),
        .CLKIN1_PERIOD       (8.0),       // 125 MHz = 8 ns period
        .CLKOUT0_DIVIDE_F   (40.0),      // 1000 / 40 = 25 MHz
        .CLKOUT0_DUTY_CYCLE (0.5),
        .CLKOUT0_PHASE      (0.0),
        .CLKOUT1_DIVIDE     (8),         // 1000 / 8 = 125 MHz
        .CLKOUT1_DUTY_CYCLE (0.5),
        .CLKOUT1_PHASE      (0.0),
        .DIVCLK_DIVIDE      (1),
        .REF_JITTER1        (0.010),
        .STARTUP_WAIT       ("FALSE")
    ) u_mmcm (
        .CLKOUT0  (clkout0),
        .CLKOUT0B (),
         .CLKOUT1  (clkout1),
        .CLKOUT1B (),
        .CLKOUT2  (),
        .CLKOUT2B (),
        .CLKOUT3  (),
        .CLKOUT3B (),
        .CLKOUT4  (),
        .CLKOUT5  (),
        .CLKOUT6  (),
        .CLKFBOUT (clkfb),
        .CLKFBOUTB(),
        .LOCKED   (locked),
        .CLKIN1   (clk_125m),
        .PWRDWN   (1'b0),
        .RST      (rst),
        .CLKFBIN  (clkfb)
    );

    // Buffer the output clock onto the global clock network
    BUFG u_bufg (
        .I (clkout0),
        .O (pixel_clk)
    );
    BUFG u_bufg_sclk ( 
        .I (clkout1),
        .O (serial_clk)
    );
endmodule
