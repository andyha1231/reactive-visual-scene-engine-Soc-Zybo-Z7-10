// tb_scene_treble_flash.v -- Scene 3 "Multicolor Particle Storm"
`timescale 1ns / 1ps

module tb_scene_treble_flash;

    reg        clk, rst_n, active_video, freeze;
    reg [9:0]  pixel_x, pixel_y;
    reg [15:0] amplitude, energy_low, energy_mid, energy_high;
    reg [7:0]  sensitivity;
    wire [3:0] r, g, b;

    localparam CLK_PERIOD = 8;

    scene_treble_flash uut (
        .clk(clk), .rst_n(rst_n),
        .pixel_x(pixel_x), .pixel_y(pixel_y), .active_video(active_video),
        .amplitude(amplitude), .energy_low(energy_low),
        .energy_mid(energy_mid), .energy_high(energy_high),
        .sensitivity(sensitivity),
        .freeze(freeze),
        .r(r), .g(g), .b(b)
    );

    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    integer fail_count;

    task drive;
        input [9:0]  px, py;
        input        av;
        input [15:0] e_high, e_mid;
        begin
            pixel_x      = px;
            pixel_y      = py;
            active_video = av;
            energy_high  = e_high;
            energy_mid   = e_mid;
            repeat (2) @(posedge clk); #1;
        end
    endtask

    initial begin
        $display("=== Scene 3 (Multicolor Particle Storm) Testbench ===");
        fail_count   = 0;

        rst_n        = 0;
        freeze       = 1;
        active_video = 0;
        pixel_x      = 0; pixel_y = 0;
        amplitude    = 0; energy_low = 0; energy_mid = 0; energy_high = 0;
        sensitivity  = 8'd128;
        repeat (10) @(posedge clk);

        if (r === 4'd0 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 1: Reset");
        else begin
            $display("[FAIL] Test 1: r=%0d g=%0d b=%0d", r, g, b); fail_count = fail_count+1;
        end

        rst_n = 1;
        repeat (3) @(posedge clk);

        drive(10'd54, 10'd86, 1'b0, 16'hFFFF, 16'hFFFF);
        if (r === 4'd0 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 2: Blanking");
        else begin
            $display("[FAIL] Test 2: r=%0d g=%0d b=%0d", r, g, b); fail_count = fail_count+1;
        end

        // T3: Particle at cell (3,5) -> color_id=(3+5+0)&3=0 -> RED
        // cell_phase=8, tri_b=4, bright=4, output (4,0,0)
        drive(10'd54, 10'd86, 1'b1, 16'd0, 16'd0);
        if (r === 4'd4 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 3: Particle red (cell 3,5) - r=4");
        else begin
            $display("[FAIL] Test 3: r=%0d g=%0d b=%0d (expected 4,0,0)", r, g, b); fail_count = fail_count+1;
        end

        // T4: Particle at cell (4,5) -> color_id=1 -> GREEN
        drive(10'd70, 10'd86, 1'b1, 16'd0, 16'd0);
        if (r === 4'd0 && g === 4'd4 && b === 4'd0)
            $display("[PASS] Test 4: Particle green (cell 4,5) - g=4");
        else begin
            $display("[FAIL] Test 4: r=%0d g=%0d b=%0d (expected 0,4,0)", r, g, b); fail_count = fail_count+1;
        end

        // T5: Particle at cell (5,5) -> color_id=2 -> CYAN
        drive(10'd86, 10'd86, 1'b1, 16'd0, 16'd0);
        if (r === 4'd0 && g === 4'd5 && b === 4'd5)
            $display("[PASS] Test 5: Particle cyan (cell 5,5) - g=5 b=5");
        else begin
            $display("[FAIL] Test 5: r=%0d g=%0d b=%0d (expected 0,5,5)", r, g, b); fail_count = fail_count+1;
        end

        // T6: Particle at cell (6,5) -> color_id=3 -> MAGENTA
        drive(10'd102, 10'd86, 1'b1, 16'd0, 16'd0);
        if (r === 4'd5 && g === 4'd0 && b === 4'd5)
            $display("[PASS] Test 6: Particle magenta (cell 6,5) - r=5 b=5");
        else begin
            $display("[FAIL] Test 6: r=%0d g=%0d b=%0d (expected 5,0,5)", r, g, b); fail_count = fail_count+1;
        end

        // T7: Loud treble brightens red particle
        drive(10'd54, 10'd86, 1'b1, 16'hF000, 16'd0);
        if (r === 4'd15 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 7: Loud treble brightens red particle (15,0,0)");
        else begin
            $display("[FAIL] Test 7: r=%0d g=%0d b=%0d (expected 15,0,0)", r, g, b); fail_count = fail_count+1;
        end

        // T8: Non-particle + e_mid=0xE000 -> magenta bg
        drive(10'd0, 10'd0, 1'b1, 16'd0, 16'hE000);
        if (r === 4'd7 && g === 4'd0 && b === 4'd7)
            $display("[PASS] Test 8: Non-particle + mid - magenta bg");
        else begin
            $display("[FAIL] Test 8: r=%0d g=%0d b=%0d", r, g, b); fail_count = fail_count+1;
        end

        // T9: Non-particle + silent -> black
        drive(10'd0, 10'd0, 1'b1, 16'hFFFF, 16'd0);
        if (r === 4'd0 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 9: Non-particle + silent - black");
        else begin
            $display("[FAIL] Test 9: r=%0d g=%0d b=%0d", r, g, b); fail_count = fail_count+1;
        end

        if (fail_count == 0)
            $display("=== Scene 3 (Multicolor Particle Storm): ALL PASS ===");
        else
            $display("=== Scene 3: %0d FAIL(s) ===", fail_count);

        $finish;
    end

endmodule
