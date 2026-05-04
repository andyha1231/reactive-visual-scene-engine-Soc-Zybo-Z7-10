// scene_treble_flash.v
// Scene 3: Edge zones flash at a rate proportional to high-frequency energy.

module scene_treble_flash (
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
    input  wire        freeze,        // 1 = halt flash_counter, hold current state
    output reg  [3:0]  r,
    output reg  [3:0]  g,
    output reg  [3:0]  b
);

    // Edge zone width (pixels from each border)
    localparam EDGE_WIDTH = 60;

    // Flash counter -- rate controlled by energy_high
    reg [23:0] flash_counter;
    reg        flash_state;

    // Flash period: smaller energy_high = slower flash
    // Invert so more energy = faster toggle
    wire [23:0] flash_period;
    assign flash_period = (energy_high < 16'd16) ? 24'd2_000_000 :  // Very slow
                          {8'd0, ~energy_high};  // Faster with more energy

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            flash_counter <= 24'd0;
            flash_state   <= 1'b0;
        end else if (!freeze) begin
            if (flash_counter >= flash_period) begin
                flash_counter <= 24'd0;
                flash_state   <= ~flash_state;
            end else begin
                flash_counter <= flash_counter + 1;
            end
        end
        // freeze: hold flash_counter and flash_state at current values
    end

    // Edge zone detection
    wire in_edge;
    assign in_edge = (pixel_x < EDGE_WIDTH) || (pixel_x >= 640 - EDGE_WIDTH) ||
                     (pixel_y < EDGE_WIDTH) || (pixel_y >= 480 - EDGE_WIDTH);

    // Center zone gets subtle mid-energy coloring
    wire [3:0] center_brightness;
    assign center_brightness = energy_mid[15:12];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r <= 4'd0;
            g <= 4'd0;
            b <= 4'd0;
        end else if (active_video) begin
            if (in_edge && flash_state) begin
                // Flashing edge: bright cyan/white
                r <= 4'd8;
                g <= 4'd12;
                b <= 4'd15;
            end else if (in_edge) begin
                // Edge off: dark
                r <= 4'd1;
                g <= 4'd1;
                b <= 4'd2;
            end else begin
                // Center: subtle mid-energy glow
                r <= center_brightness >> 1;
                g <= 4'd0;
                b <= center_brightness;
            end
        end else begin
            r <= 4'd0;
            g <= 4'd0;
            b <= 4'd0;
        end
    end

endmodule
