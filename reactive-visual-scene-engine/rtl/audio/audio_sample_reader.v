// audio_sample_reader.v
// Reads 16-bit audio samples from BRAM at a configurable sample rate.
// Address wraps at SAMPLE_COUNT for looping playback.

module audio_sample_reader #(
    parameter CLK_FREQ      = 125_000_000,  // System clock frequency (Hz)
    parameter SAMPLE_RATE   = 22_050,       // Audio sample rate (Hz)
    parameter SAMPLE_COUNT  = 32768,        // Number of 32-bit words in BRAM Port B
    parameter ADDR_WIDTH    = 15            // log2(SAMPLE_COUNT)
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    en,           // Playback enable
    // BRAM read port
    output reg  [ADDR_WIDTH-1:0]   bram_addr,
    input  wire [31:0]             bram_dout,    // Port B is 32-bit; audio in [15:0]
    output wire                    bram_en,
    // Sample output
    output reg  [15:0]             sample_out,
    output reg                     sample_valid,
    // Pulse-stretched flag: held high for ~16 sys_clk cycles each time bram_addr
    // wraps from SAMPLE_COUNT-1 back to 0. Drives scene_ctrl wrap-flag register
    // so PS knows it can stream the next chunk into BRAM Port A.
    output wire                    wrap_pulse
);

    // Clock divider: CLK_FREQ / SAMPLE_RATE
    localparam integer DIV_COUNT = CLK_FREQ / SAMPLE_RATE - 1;
    localparam integer DIV_WIDTH = $clog2(DIV_COUNT + 1);

    reg [DIV_WIDTH-1:0] div_counter;
    reg                 tick;

    assign bram_en = en;

    // Clock divider for sample rate
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_counter <= 0;
            tick        <= 1'b0;
        end else if (en) begin
            if (div_counter == DIV_COUNT[DIV_WIDTH-1:0]) begin
                div_counter <= 0;
                tick        <= 1'b1;
            end else begin
                div_counter <= div_counter + 1;
                tick        <= 1'b0;
            end
        end else begin
            div_counter <= 0;
            tick        <= 1'b0;
        end
    end

    // BRAM address counter + wrap detection
    reg wrap_event;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bram_addr  <= 0;
            wrap_event <= 1'b0;
        end else if (en && tick) begin
            if (bram_addr == SAMPLE_COUNT - 1) begin
                bram_addr  <= 0;
                wrap_event <= 1'b1;
            end else begin
                bram_addr  <= bram_addr + 1;
                wrap_event <= 1'b0;
            end
        end else begin
            wrap_event <= 1'b0;
        end
    end

    // Pulse-stretch wrap_event so a slower destination clock (clk_fpga_0 = 100 MHz)
    // can synchronize it reliably without missing the 1-cycle pulse.
    reg [3:0] wrap_stretch;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wrap_stretch <= 4'd0;
        else if (wrap_event)
            wrap_stretch <= 4'd15;     // hold high for 15 cycles (~120 ns @ 125 MHz)
        else if (wrap_stretch != 0)
            wrap_stretch <= wrap_stretch - 1;
    end
    assign wrap_pulse = (wrap_stretch != 0);

    // Capture BRAM output (1 cycle latency after address)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_out   <= 16'd0;
            sample_valid <= 1'b0;
        end else begin
            sample_valid <= tick & en;
            if (tick & en)
                sample_out <= bram_dout[15:0];  // lower 16 bits hold the audio sample
        end
    end

endmodule
