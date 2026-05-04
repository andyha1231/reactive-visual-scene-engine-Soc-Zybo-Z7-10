// scene_split_screen.v
// Scene 4: Left half responds to low/mid energy (bars),
//          Right half responds to high energy (flash).

module scene_split_screen (
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

    localparam SCREEN_MID = 320;
    localparam SCREEN_H   = 480;
    localparam BAR_WIDTH  = 80;  // 4 bars in left half (320 / 80)

    // --- Left half: Bass bars ---
    wire [23:0] scaled_low;
    assign scaled_low = energy_low * {8'd0, sensitivity};
    wire [9:0] bar_height;
    assign bar_height = (scaled_low[23:14] > 10'd480) ? 10'd480 : scaled_low[23:14];

    wire left_in_bar;
    assign left_in_bar = (pixel_y >= (SCREEN_H - bar_height));

    wire left_in_gap;
    assign left_in_gap = (pixel_x % BAR_WIDTH) >= (BAR_WIDTH - 2);

    // --- Right half: Treble flash ---
    reg [23:0] flash_counter;
    reg        flash_state;

    wire [23:0] flash_period;
    assign flash_period = (energy_high < 16'd16) ? 24'd2_000_000 : {8'd0, ~energy_high};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            flash_counter <= 24'd0;
            flash_state   <= 1'b0;
        end else begin
            if (flash_counter >= flash_period) begin
                flash_counter <= 24'd0;
                flash_state   <= ~flash_state;
            end else begin
                flash_counter <= flash_counter + 1;
            end
        end
    end

    // --- Divider line ---
    wire on_divider;
    assign on_divider = (pixel_x >= SCREEN_MID - 1) && (pixel_x <= SCREEN_MID + 1);

    // --- Output mux ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r <= 4'd0;
            g <= 4'd0;
            b <= 4'd0;
        end else if (active_video) begin
            if (on_divider) begin
                // White divider line
                r <= 4'd15;
                g <= 4'd15;
                b <= 4'd15;
            end else if (pixel_x < SCREEN_MID) begin
                // Left half: bass bars
                if (left_in_bar && !left_in_gap) begin
                    r <= 4'd1;
                    g <= 4'd10;
                    b <= 4'd2;
                end else begin
                    r <= 4'd0;
                    g <= 4'd0;
                    b <= 4'd0;
                end
            end else begin
                // Right half: treble flash
                if (flash_state) begin
                    r <= 4'd8;
                    g <= 4'd12;
                    b <= 4'd15;
                end else begin
                    r <= 4'd1;
                    g <= 4'd1;
                    b <= 4'd2;
                end
            end
        end else begin
            r <= 4'd0;
            g <= 4'd0;
            b <= 4'd0;
        end
    end

endmodule
