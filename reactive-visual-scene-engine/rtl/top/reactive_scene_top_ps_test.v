// reactive_scene_top_ps_test.v
// Phase 3B HARDWARE TEST top — full PS+BRAM+AXI pipeline, but scene_select
// and display modes are driven by SW directly (NOT from scene_ctrl_v1_0).
// Lets us verify all 4 scenes (incl. scene_tri_band_eq) AND the quad-view +
// freeze features render correctly with real BRAM-driven audio BEFORE Vitis
// is integrated.
//
// Switch contract (PL direct):
//   sw[1:0] = scene_select  (00=loudness, 01=bass, 10=treble, 11=tri-band EQ)
//   sw[2]   = quad_view_en  (1 = display all 4 scenes in 2x2 grid;
//                            sw[1:0] is ignored when this is on)
//   sw[3]   = freeze        (1 = latch current audio features; visuals pause)
//
// LED layout (so you can verify the active mode at a glance):
//   LED[0] = mmcm_locked
//   LED[1] = active_video
//   LED[2] = quad_view_en   (sw[2])
//   LED[3] = freeze         (sw[3])
//
// scene_ctrl_v1_0 stays on the AXI bus (so the BD wrapper port list is
// unchanged) but its scene_select output is intentionally ignored. Its
// sensitivity output IS still used (so Vitis can tune sensitivity later).
//
// AFTER all combinations look right, swap the project top to
// `reactive_scene_top_ps` for Vitis integration — that one obeys this same
// switch contract AND enables AXI-driven sensitivity from the UART menu.

`timescale 1ns / 1ps

module reactive_scene_top_ps_test (
    input  wire        clk,             // 125 MHz (K17)
    input  wire        btn0,            // PL reset (active-high, K18)
    input  wire [3:0]  sw,              // Switches: sw[1:0] selects scene
    output wire [3:0]  led,

    output wire        hdmi_tx_clk_p,
    output wire        hdmi_tx_clk_n,
    output wire [2:0]  hdmi_tx_d_p,
    output wire [2:0]  hdmi_tx_d_n,

    // Zynq PS pins
    inout  wire [14:0] DDR_addr,
    inout  wire [2:0]  DDR_ba,
    inout  wire        DDR_cas_n,
    inout  wire        DDR_ck_n,
    inout  wire        DDR_ck_p,
    inout  wire        DDR_cke,
    inout  wire        DDR_cs_n,
    inout  wire [3:0]  DDR_dm,
    inout  wire [31:0] DDR_dq,
    inout  wire [3:0]  DDR_dqs_n,
    inout  wire [3:0]  DDR_dqs_p,
    inout  wire        DDR_odt,
    inout  wire        DDR_ras_n,
    inout  wire        DDR_reset_n,
    inout  wire        DDR_we_n,
    inout  wire        FIXED_IO_ddr_vrn,
    inout  wire        FIXED_IO_ddr_vrp,
    inout  wire [53:0] FIXED_IO_mio,
    inout  wire        FIXED_IO_ps_clk,
    inout  wire        FIXED_IO_ps_porb,
    inout  wire        FIXED_IO_ps_srstb
);

    // -------------------------------------------------------------------------
    // Clocks and reset
    // -------------------------------------------------------------------------
    wire pixel_clk, serial_clk, mmcm_locked;

    pixel_clk_gen u_pclk (
        .clk_125m   (clk),
        .rst        (btn0),
        .pixel_clk  (pixel_clk),
        .serial_clk (serial_clk),
        .locked     (mmcm_locked)
    );

    wire rst_n = mmcm_locked & ~btn0;

    // -------------------------------------------------------------------------
    // Block design (PS, BRAM, AXI BRAM ctrl, AXI GPIO, SmartConnect)
    // -------------------------------------------------------------------------
    wire        fclk_clk0;

    wire [14:0] bram_portb_addr;
    wire [31:0] bram_portb_dout;
    wire        bram_portb_en;

    // AXI4 signals from SmartConnect M02 to scene_ctrl_v1_0
    wire [31:0] sc_awaddr, sc_wdata, sc_araddr, sc_rdata;
    wire [3:0]  sc_wstrb;
    wire [2:0]  sc_awprot, sc_arprot;
    wire [1:0]  sc_bresp, sc_rresp;
    wire        sc_awvalid, sc_awready, sc_wvalid, sc_wready;
    wire        sc_bvalid, sc_bready;
    wire        sc_arvalid, sc_arready, sc_rvalid, sc_rready;

    design_1_wrapper u_ps (
        .FCLK_CLK0_0        (fclk_clk0),

        .BRAM_PORTB_0_addr  (bram_portb_addr),
        .BRAM_PORTB_0_clk   (clk),
        .BRAM_PORTB_0_din   (32'b0),
        .BRAM_PORTB_0_dout  (bram_portb_dout),
        .BRAM_PORTB_0_en    (bram_portb_en),
        .BRAM_PORTB_0_we    (1'b0),

        .sws_4bits_tri_i    ({2'b0, sw[1:0]}),
        .btns_4bits_tri_i   ({3'b0, btn0}),

        .scene_ctrl_axi_awaddr   (sc_awaddr),
        .scene_ctrl_axi_awprot   (sc_awprot),
        .scene_ctrl_axi_awvalid  (sc_awvalid),
        .scene_ctrl_axi_awready  (sc_awready),
        .scene_ctrl_axi_awlen    (),
        .scene_ctrl_axi_awsize   (),
        .scene_ctrl_axi_awburst  (),
        .scene_ctrl_axi_awcache  (),
        .scene_ctrl_axi_awlock   (),
        .scene_ctrl_axi_awqos    (),
        .scene_ctrl_axi_wdata    (sc_wdata),
        .scene_ctrl_axi_wstrb    (sc_wstrb),
        .scene_ctrl_axi_wvalid   (sc_wvalid),
        .scene_ctrl_axi_wlast    (),
        .scene_ctrl_axi_wready   (sc_wready),
        .scene_ctrl_axi_bresp    (sc_bresp),
        .scene_ctrl_axi_bvalid   (sc_bvalid),
        .scene_ctrl_axi_bready   (sc_bready),
        .scene_ctrl_axi_araddr   (sc_araddr),
        .scene_ctrl_axi_arprot   (sc_arprot),
        .scene_ctrl_axi_arvalid  (sc_arvalid),
        .scene_ctrl_axi_arready  (sc_arready),
        .scene_ctrl_axi_arlen    (),
        .scene_ctrl_axi_arsize   (),
        .scene_ctrl_axi_arburst  (),
        .scene_ctrl_axi_arcache  (),
        .scene_ctrl_axi_arlock   (),
        .scene_ctrl_axi_arqos    (),
        .scene_ctrl_axi_rdata    (sc_rdata),
        .scene_ctrl_axi_rresp    (sc_rresp),
        .scene_ctrl_axi_rvalid   (sc_rvalid),
        .scene_ctrl_axi_rlast    (sc_rvalid),
        .scene_ctrl_axi_rready   (sc_rready),

        .DDR_addr          (DDR_addr),
        .DDR_ba            (DDR_ba),
        .DDR_cas_n         (DDR_cas_n),
        .DDR_ck_n          (DDR_ck_n),
        .DDR_ck_p          (DDR_ck_p),
        .DDR_cke           (DDR_cke),
        .DDR_cs_n          (DDR_cs_n),
        .DDR_dm            (DDR_dm),
        .DDR_dq            (DDR_dq),
        .DDR_dqs_n         (DDR_dqs_n),
        .DDR_dqs_p         (DDR_dqs_p),
        .DDR_odt           (DDR_odt),
        .DDR_ras_n         (DDR_ras_n),
        .DDR_reset_n       (DDR_reset_n),
        .DDR_we_n          (DDR_we_n),
        .FIXED_IO_ddr_vrn  (FIXED_IO_ddr_vrn),
        .FIXED_IO_ddr_vrp  (FIXED_IO_ddr_vrp),
        .FIXED_IO_mio      (FIXED_IO_mio),
        .FIXED_IO_ps_clk   (FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb  (FIXED_IO_ps_porb),
        .FIXED_IO_ps_srstb (FIXED_IO_ps_srstb)
    );

    // -------------------------------------------------------------------------
    // AXI-Lite scene control IP — kept on the bus so the BD wrapper port list
    // is unchanged. scene_select is ignored (switches drive it). sensitivity
    // is wired through so the UART/Vitis can still tune it.
    // -------------------------------------------------------------------------
    wire [7:0] axi_sensitivity;

    scene_ctrl_v1_0 u_ctrl (
        .scene_select   (),
        .preset_select  (),
        .sensitivity    (axi_sensitivity),
        .threshold      (),
        .auto_mode      (),
        .debug_en       (),
        .s00_axi_aclk    (fclk_clk0),
        .s00_axi_aresetn (rst_n),
        .s00_axi_awaddr  (sc_awaddr[4:0]),
        .s00_axi_awprot  (sc_awprot),
        .s00_axi_awvalid (sc_awvalid),
        .s00_axi_awready (sc_awready),
        .s00_axi_wdata   (sc_wdata),
        .s00_axi_wstrb   (sc_wstrb),
        .s00_axi_wvalid  (sc_wvalid),
        .s00_axi_wready  (sc_wready),
        .s00_axi_bresp   (sc_bresp),
        .s00_axi_bvalid  (sc_bvalid),
        .s00_axi_bready  (sc_bready),
        .s00_axi_araddr  (sc_araddr[4:0]),
        .s00_axi_arprot  (sc_arprot),
        .s00_axi_arvalid (sc_arvalid),
        .s00_axi_arready (sc_arready),
        .s00_axi_rdata   (sc_rdata),
        .s00_axi_rresp   (sc_rresp),
        .s00_axi_rvalid  (sc_rvalid),
        .s00_axi_rready  (sc_rready)
    );

    // -------------------------------------------------------------------------
    // Audio pipeline (125 MHz) — same as reactive_scene_top_ps.v
    // -------------------------------------------------------------------------
    wire [14:0] bram_word_addr;
    wire        bram_en_sig;

    assign bram_portb_addr = bram_word_addr;
    assign bram_portb_en   = bram_en_sig;

    wire [15:0] sample_out;
    wire        sample_valid;

    audio_sample_reader #(
        .CLK_FREQ    (125_000_000),
        .SAMPLE_RATE (22_050),
        .SAMPLE_COUNT(32768),
        .ADDR_WIDTH  (15)
    ) u_audio (
        .clk         (clk),
        .rst_n       (rst_n),
        .en          (1'b1),
        .bram_addr   (bram_word_addr),
        .bram_dout   (bram_portb_dout[15:0]),
        .bram_en     (bram_en_sig),
        .sample_out  (sample_out),
        .sample_valid(sample_valid)
    );

    wire [15:0] amplitude, energy_low, energy_mid, energy_high;

    feature_extraction_top u_feat (
        .clk          (clk),
        .rst_n        (rst_n),
        .sample_in    (sample_out),
        .sample_valid (sample_valid),
        .amplitude    (amplitude),
        .energy_low   (energy_low),
        .energy_mid   (energy_mid),
        .energy_high  (energy_high)
    );

    // -------------------------------------------------------------------------
    // Freeze: when sw[3]=1, latch the current feature values so visuals stop
    // animating. When 0, registers track the live feature stream each cycle.
    // Same clock domain as feature_extraction_top (sys_clk 125 MHz). The
    // CDC into pixel_clk is the existing one (false-pathed in timing_cdc.xdc).
    // -------------------------------------------------------------------------
    reg [15:0] amp_held, lo_held, mid_held, hi_held;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            amp_held <= 16'd0;
            lo_held  <= 16'd0;
            mid_held <= 16'd0;
            hi_held  <= 16'd0;
        end else if (!sw[3]) begin
            amp_held <= amplitude;
            lo_held  <= energy_low;
            mid_held <= energy_mid;
            hi_held  <= energy_high;
        end
    end

    // -------------------------------------------------------------------------
    // VGA timing (25 MHz pixel clock)
    // -------------------------------------------------------------------------
    wire        hsync, vsync, active_video;
    wire [9:0]  pixel_x, pixel_y;

    vga_sync u_sync (
        .pclk         (pixel_clk),
        .rst_n        (rst_n),
        .hsync        (hsync),
        .vsync        (vsync),
        .pixel_x      (pixel_x),
        .pixel_y      (pixel_y),
        .active_video (active_video)
    );

    // -------------------------------------------------------------------------
    // Scene engine (25 MHz):
    //   scene_select  = sw[1:0]            (PL direct)
    //   quad_view_en  = sw[2]              (PL direct)
    //   sensitivity   = axi_sensitivity    (AXI register, default 0x80)
    //   features      = held versions      (sw[3] freeze gate above)
    // CDC: features and switches change much slower than pixel clock; safe
    // to sample directly. Constraints in timing_cdc.xdc still apply.
    // -------------------------------------------------------------------------
    wire [3:0] scene_r, scene_g, scene_b;

    scene_engine_top u_scene (
        .clk          (pixel_clk),
        .rst_n        (rst_n),
        .pixel_x      (pixel_x),
        .pixel_y      (pixel_y),
        .active_video (active_video),
        .amplitude    (amp_held),
        .energy_low   (lo_held),
        .energy_mid   (mid_held),
        .energy_high  (hi_held),
        .scene_select (sw[1:0]),
        .quad_view_en (sw[2]),
        .freeze       (sw[3]),
        .sensitivity  (axi_sensitivity),
        .r            (scene_r),
        .g            (scene_g),
        .b            (scene_b)
    );

    // -------------------------------------------------------------------------
    // HDMI output (Digilent rgb2dvi: [23:16]=R, [15:8]=B, [7:0]=G)
    // -------------------------------------------------------------------------
    wire [23:0] vid_data = {{scene_r, scene_r}, {scene_b, scene_b}, {scene_g, scene_g}};

    rgb2dvi_0 u_hdmi (
        .PixelClk    (pixel_clk),
        .SerialClk   (serial_clk),
        .aRst        (btn0),
        .vid_pData   (vid_data),
        .vid_pVDE    (active_video),
        .vid_pHSync  (hsync),
        .vid_pVSync  (vsync),
        .TMDS_Clk_p  (hdmi_tx_clk_p),
        .TMDS_Clk_n  (hdmi_tx_clk_n),
        .TMDS_Data_p (hdmi_tx_d_p),
        .TMDS_Data_n (hdmi_tx_d_n)
    );

    assign led[0] = mmcm_locked;
    assign led[1] = active_video;
    assign led[2] = sw[2];        // quad_view_en
    assign led[3] = sw[3];        // freeze

endmodule
