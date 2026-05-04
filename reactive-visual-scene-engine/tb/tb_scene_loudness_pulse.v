// tb_scene_loudness_pulse.v -- Scene 1 "Concentric Circles"
`timescale 1ns / 1ps

module tb_scene_loudness_pulse;

    reg        clk, rst_n, active_video, freeze;
    reg [9:0]  pixel_x, pixel_y;
    reg [15:0] amplitude, energy_low, energy_mid, energy_high;
    reg [7:0]  sensitivity;
    wire [3:0] r, g, b;

    localparam CLK_PERIOD = 8;

    scene_loudness_pulse uut (
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
        input [15:0] amp;
        begin
            pixel_x      = px;
            pixel_y      = py;
            active_video = av;
            amplitude    = amp;
            repeat (2) @(posedge clk); #1;
        end
    endtask

    initial begin
        $display("=== Scene 1 (Concentric Circles) Testbench ===");
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
            $display("[FAIL] Test 1: r=%0d g=%0d b=%0d", r, g, b); fail_count = fail_count + 1;
        end

        rst_n = 1;
        repeat (3) @(posedge clk);

        drive(10'd320, 10'd240, 1'b0, 16'hFFFF);
        if (r === 4'd0 && g === 4'd0 && b === 4'd0)
            $display("[PASS] Test 2: Blanking");
        else begin
            $display("[FAIL] Test 2: r=%0d g=%0d b=%0d", r, g, b); fail_count = fail_count + 1;
        end

        // T3: Sun core at center
        drive(10'd320, 10'd240, 1'b1, 16'd0);
        if (r === 4'd15 && g === 4'd12 && b === 4'd2)
            $display("[PASS] Test 3: Sun core - yellow (15,12,2)");
        else begin
            $display("[FAIL] Test 3: r=%0d g=%0d b=%0d", r, g, b); fail_count = fail_count + 1;
        end

        // T4: Off-pattern background
        drive(10'd400, 10'd240, 1'b1, 16'hFFFF);
        if (r === 4'd1 && g === 4'd0 && b === 4'd1)
            $display("[PASS] Test 4: Off-pattern - dim purple bg");
        else begin
            $display("[FAIL] Test 4: r=%0d g=%0d b=%0d", r, g, b); fail_count = fail_count + 1;
        end

        // T5: Silent music -> no rings (just bg)
        drive(10'd384, 10'd240, 1'b1, 16'd0);
        if (r === 4'd1 && g === 4'd0 && b === 4'd1)
            $display("[PASS] Test 5: Silent music -> bg");
        else begin
            $display("[FAIL] Test 5: r=%0d g=%0d b=%0d", r, g, b); fail_count = fail_count + 1;
        end

        // T6: Loud amp -> ring lit orange
        drive(10'd384, 10'd240, 1'b1, 16'hFFFF);
        if (r > 4'd10 && g > 4'd4 && b === 4'd0)
            $display("[PASS] Test 6: Loud amp - ring lit r=%0d g=%0d", r, g);
        else begin
            $display("[FAIL] Test 6: r=%0d g=%0d b=%0d", r, g, b); fail_count = fail_count + 1;
        end

        // T7a: Far ring lit at high amp
        drive(10'd576, 10'd240, 1'b1, 16'hC000);
        if (r > 4'd5 && g > 4'd2 && b === 4'd0)
            $display("[PASS] Test 7a: Ring 8 lit at high amp");
        else begin
            $display("[FAIL] Test 7a: r=%0d g=%0d b=%0d", r, g, b); fail_count = fail_count + 1;
        end

        // T7b: Far ring dark at low amp
        drive(10'd576, 10'd240, 1'b1, 16'h2000);
        if (r === 4'd1 && g === 4'd0 && b === 4'd1)
            $display("[PASS] Test 7b: Ring 8 dark at low amp");
        else begin
            $display("[FAIL] Test 7b: r=%0d g=%0d b=%0d", r, g, b); fail_count = fail_count + 1;
        end

        if (fail_count == 0)
            $display("=== Scene 1 (Concentric Circles): ALL PASS ===");
        else
            $display("=== Scene 1: %0d FAIL(s) ===", fail_count);

        $finish;
    end

endmodule
