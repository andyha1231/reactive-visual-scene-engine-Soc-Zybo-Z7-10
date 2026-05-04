// scene_treble_flash.v -- Scene 3: "Multicolor Particle Storm"
//
// Grid of particles (4x4 px every 16x16 cell). Each particle has one of
// four colors (red/green/cyan/magenta) determined by its cell position
// plus a slow time drift, so the screen is a colored checkerboard that
// rotates colors over a few seconds. Particle brightness varies with
// per-cell phase (subtle baseline twinkle) plus energy_high (treble
// drives intensity). Background magenta-tinted by energy_mid.

`timescale 1ns / 1ps

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
    input  wire        freeze,
    output reg  [3:0]  r,
    output reg  [3:0]  g,
    output reg  [3:0]  b
);

    // ---- Free-running animation counter (gated by freeze) ----
    reg [23:0] anim_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)        anim_cnt <= 24'd0;
        else if (!freeze)  anim_cnt <= anim_cnt + 24'd1;
    end

    // 16x16 grid cells.
    wire [5:0] cell_x = pixel_x[9:4];
    wire [4:0] cell_y = pixel_y[8:4];

    // Particle is the central 4x4 of each cell.
    wire on_particle = (pixel_x[3:0] >= 4'd6) && (pixel_x[3:0] <= 4'd9) &&
                       (pixel_y[3:0] >= 4'd6) && (pixel_y[3:0] <= 4'd9);

    // Per-cell phase for brightness twinkle.
    wire [4:0] anim_offset = anim_cnt[22:18];
    wire [4:0] cell_phase  = {2'd0, cell_x[2:0]} + {2'd0, cell_y[2:0]} + anim_offset;

    // Halved triangle-wave brightness so treble can dominate.
    wire [3:0] tri_b = cell_phase[4] ? (4'd7 - {1'b0, cell_phase[3:1]})
                                      : {1'b0, cell_phase[3:1]};

    // Add treble energy on top.
    wire [3:0] hi_b = energy_high[15:12];
    wire [4:0] sum  = {1'b0, tri_b} + {1'b0, hi_b};
    wire [3:0] particle_bright = sum[4] ? 4'd15 : sum[3:0];

    // ---- Color: 4-color palette cycling across cells, drifting over time ----
    wire [4:0] color_seed = {2'd0, cell_x[1:0]} +
                            {2'd0, cell_y[1:0]} +
                            {3'd0, anim_cnt[23:22]};
    wire [1:0] color_id = color_seed[1:0];

    reg [3:0] p_r, p_g, p_b;
    always @(*) begin
        case (color_id)
            2'd0: begin p_r = particle_bright; p_g = 4'd0;            p_b = 4'd0;            end // RED
            2'd1: begin p_r = 4'd0;            p_g = particle_bright; p_b = 4'd0;            end // GREEN
            2'd2: begin p_r = 4'd0;            p_g = particle_bright; p_b = particle_bright; end // CYAN
            2'd3: begin p_r = particle_bright; p_g = 4'd0;            p_b = particle_bright; end // MAGENTA
        endcase
    end

    // Background magenta tint from energy_mid.
    wire [3:0] mid_tint = {1'b0, energy_mid[15:13]};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r <= 4'd0;
            g <= 4'd0;
            b <= 4'd0;
        end else if (active_video) begin
            if (on_particle) begin
                r <= p_r;
                g <= p_g;
                b <= p_b;
            end else begin
                r <= mid_tint;
                g <= 4'd0;
                b <= mid_tint;
            end
        end else begin
            r <= 4'd0;
            g <= 4'd0;
            b <= 4'd0;
        end
    end

endmodule
