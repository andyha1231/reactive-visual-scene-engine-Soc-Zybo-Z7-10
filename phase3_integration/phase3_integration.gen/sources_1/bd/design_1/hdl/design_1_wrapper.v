//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2023.1 (win64) Build 3865809 Sun May  7 15:05:29 MDT 2023
//Date        : Sun May  3 03:06:56 2026
//Host        : GN9HD17Q running 64-bit major release  (build 9200)
//Command     : generate_target design_1_wrapper.bd
//Design      : design_1_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module design_1_wrapper
   (BRAM_PORTB_0_addr,
    BRAM_PORTB_0_clk,
    BRAM_PORTB_0_din,
    BRAM_PORTB_0_dout,
    BRAM_PORTB_0_en,
    BRAM_PORTB_0_we,
    DDR_addr,
    DDR_ba,
    DDR_cas_n,
    DDR_ck_n,
    DDR_ck_p,
    DDR_cke,
    DDR_cs_n,
    DDR_dm,
    DDR_dq,
    DDR_dqs_n,
    DDR_dqs_p,
    DDR_odt,
    DDR_ras_n,
    DDR_reset_n,
    DDR_we_n,
    FCLK_CLK0_0,
    FIXED_IO_ddr_vrn,
    FIXED_IO_ddr_vrp,
    FIXED_IO_mio,
    FIXED_IO_ps_clk,
    FIXED_IO_ps_porb,
    FIXED_IO_ps_srstb,
    btns_4bits_tri_i,
    scene_ctrl_axi_araddr,
    scene_ctrl_axi_arburst,
    scene_ctrl_axi_arcache,
    scene_ctrl_axi_arlen,
    scene_ctrl_axi_arlock,
    scene_ctrl_axi_arprot,
    scene_ctrl_axi_arqos,
    scene_ctrl_axi_arready,
    scene_ctrl_axi_arsize,
    scene_ctrl_axi_arvalid,
    scene_ctrl_axi_awaddr,
    scene_ctrl_axi_awburst,
    scene_ctrl_axi_awcache,
    scene_ctrl_axi_awlen,
    scene_ctrl_axi_awlock,
    scene_ctrl_axi_awprot,
    scene_ctrl_axi_awqos,
    scene_ctrl_axi_awready,
    scene_ctrl_axi_awsize,
    scene_ctrl_axi_awvalid,
    scene_ctrl_axi_bready,
    scene_ctrl_axi_bresp,
    scene_ctrl_axi_bvalid,
    scene_ctrl_axi_rdata,
    scene_ctrl_axi_rlast,
    scene_ctrl_axi_rready,
    scene_ctrl_axi_rresp,
    scene_ctrl_axi_rvalid,
    scene_ctrl_axi_wdata,
    scene_ctrl_axi_wlast,
    scene_ctrl_axi_wready,
    scene_ctrl_axi_wstrb,
    scene_ctrl_axi_wvalid,
    sws_4bits_tri_i);
  input [14:0]BRAM_PORTB_0_addr;
  input BRAM_PORTB_0_clk;
  input [31:0]BRAM_PORTB_0_din;
  output [31:0]BRAM_PORTB_0_dout;
  input BRAM_PORTB_0_en;
  input [0:0]BRAM_PORTB_0_we;
  inout [14:0]DDR_addr;
  inout [2:0]DDR_ba;
  inout DDR_cas_n;
  inout DDR_ck_n;
  inout DDR_ck_p;
  inout DDR_cke;
  inout DDR_cs_n;
  inout [3:0]DDR_dm;
  inout [31:0]DDR_dq;
  inout [3:0]DDR_dqs_n;
  inout [3:0]DDR_dqs_p;
  inout DDR_odt;
  inout DDR_ras_n;
  inout DDR_reset_n;
  inout DDR_we_n;
  output FCLK_CLK0_0;
  inout FIXED_IO_ddr_vrn;
  inout FIXED_IO_ddr_vrp;
  inout [53:0]FIXED_IO_mio;
  inout FIXED_IO_ps_clk;
  inout FIXED_IO_ps_porb;
  inout FIXED_IO_ps_srstb;
  input [3:0]btns_4bits_tri_i;
  output [31:0]scene_ctrl_axi_araddr;
  output [1:0]scene_ctrl_axi_arburst;
  output [3:0]scene_ctrl_axi_arcache;
  output [7:0]scene_ctrl_axi_arlen;
  output [0:0]scene_ctrl_axi_arlock;
  output [2:0]scene_ctrl_axi_arprot;
  output [3:0]scene_ctrl_axi_arqos;
  input scene_ctrl_axi_arready;
  output [2:0]scene_ctrl_axi_arsize;
  output scene_ctrl_axi_arvalid;
  output [31:0]scene_ctrl_axi_awaddr;
  output [1:0]scene_ctrl_axi_awburst;
  output [3:0]scene_ctrl_axi_awcache;
  output [7:0]scene_ctrl_axi_awlen;
  output [0:0]scene_ctrl_axi_awlock;
  output [2:0]scene_ctrl_axi_awprot;
  output [3:0]scene_ctrl_axi_awqos;
  input scene_ctrl_axi_awready;
  output [2:0]scene_ctrl_axi_awsize;
  output scene_ctrl_axi_awvalid;
  output scene_ctrl_axi_bready;
  input [1:0]scene_ctrl_axi_bresp;
  input scene_ctrl_axi_bvalid;
  input [31:0]scene_ctrl_axi_rdata;
  input scene_ctrl_axi_rlast;
  output scene_ctrl_axi_rready;
  input [1:0]scene_ctrl_axi_rresp;
  input scene_ctrl_axi_rvalid;
  output [31:0]scene_ctrl_axi_wdata;
  output scene_ctrl_axi_wlast;
  input scene_ctrl_axi_wready;
  output [3:0]scene_ctrl_axi_wstrb;
  output scene_ctrl_axi_wvalid;
  input [3:0]sws_4bits_tri_i;

  wire [14:0]BRAM_PORTB_0_addr;
  wire BRAM_PORTB_0_clk;
  wire [31:0]BRAM_PORTB_0_din;
  wire [31:0]BRAM_PORTB_0_dout;
  wire BRAM_PORTB_0_en;
  wire [0:0]BRAM_PORTB_0_we;
  wire [14:0]DDR_addr;
  wire [2:0]DDR_ba;
  wire DDR_cas_n;
  wire DDR_ck_n;
  wire DDR_ck_p;
  wire DDR_cke;
  wire DDR_cs_n;
  wire [3:0]DDR_dm;
  wire [31:0]DDR_dq;
  wire [3:0]DDR_dqs_n;
  wire [3:0]DDR_dqs_p;
  wire DDR_odt;
  wire DDR_ras_n;
  wire DDR_reset_n;
  wire DDR_we_n;
  wire FCLK_CLK0_0;
  wire FIXED_IO_ddr_vrn;
  wire FIXED_IO_ddr_vrp;
  wire [53:0]FIXED_IO_mio;
  wire FIXED_IO_ps_clk;
  wire FIXED_IO_ps_porb;
  wire FIXED_IO_ps_srstb;
  wire [3:0]btns_4bits_tri_i;
  wire [31:0]scene_ctrl_axi_araddr;
  wire [1:0]scene_ctrl_axi_arburst;
  wire [3:0]scene_ctrl_axi_arcache;
  wire [7:0]scene_ctrl_axi_arlen;
  wire [0:0]scene_ctrl_axi_arlock;
  wire [2:0]scene_ctrl_axi_arprot;
  wire [3:0]scene_ctrl_axi_arqos;
  wire scene_ctrl_axi_arready;
  wire [2:0]scene_ctrl_axi_arsize;
  wire scene_ctrl_axi_arvalid;
  wire [31:0]scene_ctrl_axi_awaddr;
  wire [1:0]scene_ctrl_axi_awburst;
  wire [3:0]scene_ctrl_axi_awcache;
  wire [7:0]scene_ctrl_axi_awlen;
  wire [0:0]scene_ctrl_axi_awlock;
  wire [2:0]scene_ctrl_axi_awprot;
  wire [3:0]scene_ctrl_axi_awqos;
  wire scene_ctrl_axi_awready;
  wire [2:0]scene_ctrl_axi_awsize;
  wire scene_ctrl_axi_awvalid;
  wire scene_ctrl_axi_bready;
  wire [1:0]scene_ctrl_axi_bresp;
  wire scene_ctrl_axi_bvalid;
  wire [31:0]scene_ctrl_axi_rdata;
  wire scene_ctrl_axi_rlast;
  wire scene_ctrl_axi_rready;
  wire [1:0]scene_ctrl_axi_rresp;
  wire scene_ctrl_axi_rvalid;
  wire [31:0]scene_ctrl_axi_wdata;
  wire scene_ctrl_axi_wlast;
  wire scene_ctrl_axi_wready;
  wire [3:0]scene_ctrl_axi_wstrb;
  wire scene_ctrl_axi_wvalid;
  wire [3:0]sws_4bits_tri_i;

  design_1 design_1_i
       (.BRAM_PORTB_0_addr(BRAM_PORTB_0_addr),
        .BRAM_PORTB_0_clk(BRAM_PORTB_0_clk),
        .BRAM_PORTB_0_din(BRAM_PORTB_0_din),
        .BRAM_PORTB_0_dout(BRAM_PORTB_0_dout),
        .BRAM_PORTB_0_en(BRAM_PORTB_0_en),
        .BRAM_PORTB_0_we(BRAM_PORTB_0_we),
        .DDR_addr(DDR_addr),
        .DDR_ba(DDR_ba),
        .DDR_cas_n(DDR_cas_n),
        .DDR_ck_n(DDR_ck_n),
        .DDR_ck_p(DDR_ck_p),
        .DDR_cke(DDR_cke),
        .DDR_cs_n(DDR_cs_n),
        .DDR_dm(DDR_dm),
        .DDR_dq(DDR_dq),
        .DDR_dqs_n(DDR_dqs_n),
        .DDR_dqs_p(DDR_dqs_p),
        .DDR_odt(DDR_odt),
        .DDR_ras_n(DDR_ras_n),
        .DDR_reset_n(DDR_reset_n),
        .DDR_we_n(DDR_we_n),
        .FCLK_CLK0_0(FCLK_CLK0_0),
        .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
        .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
        .FIXED_IO_mio(FIXED_IO_mio),
        .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
        .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
        .btns_4bits_tri_i(btns_4bits_tri_i),
        .scene_ctrl_axi_araddr(scene_ctrl_axi_araddr),
        .scene_ctrl_axi_arburst(scene_ctrl_axi_arburst),
        .scene_ctrl_axi_arcache(scene_ctrl_axi_arcache),
        .scene_ctrl_axi_arlen(scene_ctrl_axi_arlen),
        .scene_ctrl_axi_arlock(scene_ctrl_axi_arlock),
        .scene_ctrl_axi_arprot(scene_ctrl_axi_arprot),
        .scene_ctrl_axi_arqos(scene_ctrl_axi_arqos),
        .scene_ctrl_axi_arready(scene_ctrl_axi_arready),
        .scene_ctrl_axi_arsize(scene_ctrl_axi_arsize),
        .scene_ctrl_axi_arvalid(scene_ctrl_axi_arvalid),
        .scene_ctrl_axi_awaddr(scene_ctrl_axi_awaddr),
        .scene_ctrl_axi_awburst(scene_ctrl_axi_awburst),
        .scene_ctrl_axi_awcache(scene_ctrl_axi_awcache),
        .scene_ctrl_axi_awlen(scene_ctrl_axi_awlen),
        .scene_ctrl_axi_awlock(scene_ctrl_axi_awlock),
        .scene_ctrl_axi_awprot(scene_ctrl_axi_awprot),
        .scene_ctrl_axi_awqos(scene_ctrl_axi_awqos),
        .scene_ctrl_axi_awready(scene_ctrl_axi_awready),
        .scene_ctrl_axi_awsize(scene_ctrl_axi_awsize),
        .scene_ctrl_axi_awvalid(scene_ctrl_axi_awvalid),
        .scene_ctrl_axi_bready(scene_ctrl_axi_bready),
        .scene_ctrl_axi_bresp(scene_ctrl_axi_bresp),
        .scene_ctrl_axi_bvalid(scene_ctrl_axi_bvalid),
        .scene_ctrl_axi_rdata(scene_ctrl_axi_rdata),
        .scene_ctrl_axi_rlast(scene_ctrl_axi_rlast),
        .scene_ctrl_axi_rready(scene_ctrl_axi_rready),
        .scene_ctrl_axi_rresp(scene_ctrl_axi_rresp),
        .scene_ctrl_axi_rvalid(scene_ctrl_axi_rvalid),
        .scene_ctrl_axi_wdata(scene_ctrl_axi_wdata),
        .scene_ctrl_axi_wlast(scene_ctrl_axi_wlast),
        .scene_ctrl_axi_wready(scene_ctrl_axi_wready),
        .scene_ctrl_axi_wstrb(scene_ctrl_axi_wstrb),
        .scene_ctrl_axi_wvalid(scene_ctrl_axi_wvalid),
        .sws_4bits_tri_i(sws_4bits_tri_i));
endmodule
