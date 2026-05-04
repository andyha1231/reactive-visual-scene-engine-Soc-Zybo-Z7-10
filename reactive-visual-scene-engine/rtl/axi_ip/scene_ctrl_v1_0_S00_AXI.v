// scene_ctrl_v1_0_S00_AXI.v
// AXI4-Lite slave interface for the Reactive Scene Engine control registers.
// 6 registers (24 bytes), base offset 0x00-0x14.
//
// NOTE: This file is a TEMPLATE. When you create the AXI IP in Vivado using
// "Create and Package New IP", Vivado will auto-generate a similar file.
// Modify the generated file to match the register map below.

module scene_ctrl_v1_0_S00_AXI #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 5   // 2^5 = 32 bytes (8 regs max)
)(
    // Control outputs to PL
    output wire [1:0]  scene_select,
    output wire [7:0]  preset_select,
    output wire [7:0]  sensitivity,
    output wire [15:0] threshold,
    output wire        auto_mode,
    output wire        debug_en,

    // Audio streaming wrap flag input (from audio_sample_reader, sys_clk domain).
    // Pulse-stretched in source so this 2-FF synchronizer + edge-detect catches
    // every wrap event reliably.
    input  wire        wrap_pulse_async,

    // AXI4-Lite slave interface signals
    input  wire                              S_AXI_ACLK,
    input  wire                              S_AXI_ARESETN,
    // Write address channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_AWADDR,
    input  wire [2:0]                        S_AXI_AWPROT,
    input  wire                              S_AXI_AWVALID,
    output wire                              S_AXI_AWREADY,
    // Write data channel
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                              S_AXI_WVALID,
    output wire                              S_AXI_WREADY,
    // Write response channel
    output wire [1:0]                        S_AXI_BRESP,
    output wire                              S_AXI_BVALID,
    input  wire                              S_AXI_BREADY,
    // Read address channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_ARADDR,
    input  wire [2:0]                        S_AXI_ARPROT,
    input  wire                              S_AXI_ARVALID,
    output wire                              S_AXI_ARREADY,
    // Read data channel
    output wire [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_RDATA,
    output wire [1:0]                        S_AXI_RRESP,
    output wire                              S_AXI_RVALID,
    input  wire                              S_AXI_RREADY
);

    // ---------------------------------------------------------------
    // Register Map
    // ---------------------------------------------------------------
    // Offset 0x00: SCENE_SEL    [1:0]  RW  Active scene (0-3)
    // Offset 0x04: PRESET_SEL   [7:0]  RW  Active preset
    // Offset 0x08: SENSITIVITY  [7:0]  RW  Visual response strength
    // Offset 0x0C: THRESHOLD    [15:0] RW  Feature threshold
    // Offset 0x10: MODE_CTRL    [0]    RW  0=manual, 1=auto
    // Offset 0x14: DEBUG_EN     [0]    RW  Debug overlay enable
    // Offset 0x18: WRAP_FLAG    [0]    R/W1C  Set on each BRAM wrap; write 1 to clear
    // ---------------------------------------------------------------

    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg0;  // SCENE_SEL
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg1;  // PRESET_SEL
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg2;  // SENSITIVITY
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg3;  // THRESHOLD
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg4;  // MODE_CTRL
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg5;  // DEBUG_EN
    reg                          wrap_flag; // sticky bit, set by wrap_pulse_async, cleared by W1C

    // Map register fields to output ports
    assign scene_select  = slv_reg0[1:0];
    assign preset_select = slv_reg1[7:0];
    assign sensitivity   = slv_reg2[7:0];
    assign threshold     = slv_reg3[15:0];
    assign auto_mode     = slv_reg4[0];
    assign debug_en      = slv_reg5[0];

    // ---------------------------------------------------------------
    // wrap_pulse synchronizer + edge detect (CDC: sys_clk -> S_AXI_ACLK)
    // ---------------------------------------------------------------
    reg wrap_sync_1, wrap_sync_2, wrap_sync_seen;
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            wrap_sync_1    <= 1'b0;
            wrap_sync_2    <= 1'b0;
            wrap_sync_seen <= 1'b0;
        end else begin
            wrap_sync_1    <= wrap_pulse_async;
            wrap_sync_2    <= wrap_sync_1;
            wrap_sync_seen <= wrap_sync_2;
        end
    end
    wire wrap_event = wrap_sync_2 & ~wrap_sync_seen;  // rising edge in AXI clock domain

    // --- AXI handshake logic ---
    reg axi_awready, axi_wready, axi_bvalid;
    reg axi_arready, axi_rvalid;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr, axi_araddr;
    reg [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;
    reg [1:0] axi_bresp, axi_rresp;

    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;

    // Write address ready
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_awready <= 1'b0;
            axi_awaddr  <= 0;
        end else if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID) begin
            axi_awready <= 1'b1;
            axi_awaddr  <= S_AXI_AWADDR;
        end else begin
            axi_awready <= 1'b0;
        end
    end

    // Write data ready
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            axi_wready <= 1'b0;
        else if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID)
            axi_wready <= 1'b1;
        else
            axi_wready <= 1'b0;
    end

    // Write register logic
    wire slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;
    wire wrap_clear  = slv_reg_wren && (axi_awaddr[4:2] == 3'd6) && S_AXI_WDATA[0];

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            slv_reg0 <= 32'd0;   // Default scene 0
            slv_reg1 <= 32'd0;   // Default preset 0
            slv_reg2 <= 32'd240; // Default sensitivity (near max; bigger bars before software writes)
            slv_reg3 <= 32'd0;   // Default threshold 0
            slv_reg4 <= 32'd0;   // Default manual mode
            slv_reg5 <= 32'd0;   // Default debug off
        end else if (slv_reg_wren) begin
            case (axi_awaddr[4:2])
                3'd0: slv_reg0 <= S_AXI_WDATA;
                3'd1: slv_reg1 <= S_AXI_WDATA;
                3'd2: slv_reg2 <= S_AXI_WDATA;
                3'd3: slv_reg3 <= S_AXI_WDATA;
                3'd4: slv_reg4 <= S_AXI_WDATA;
                3'd5: slv_reg5 <= S_AXI_WDATA;
                // 3'd6 (WRAP_FLAG) handled below
                default: ;
            endcase
        end
    end

    // WRAP_FLAG: sticky bit, set by wrap_event, cleared by writing 1 to bit 0 at offset 0x18
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            wrap_flag <= 1'b0;
        else if (wrap_event)
            wrap_flag <= 1'b1;
        else if (wrap_clear)
            wrap_flag <= 1'b0;
    end

    // Write response
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_bvalid <= 1'b0;
            axi_bresp  <= 2'b0;
        end else if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID) begin
            axi_bvalid <= 1'b1;
            axi_bresp  <= 2'b00; // OKAY
        end else if (S_AXI_BREADY && axi_bvalid) begin
            axi_bvalid <= 1'b0;
        end
    end

    // Read address ready
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_arready <= 1'b0;
            axi_araddr  <= 0;
        end else if (~axi_arready && S_AXI_ARVALID) begin
            axi_arready <= 1'b1;
            axi_araddr  <= S_AXI_ARADDR;
        end else begin
            axi_arready <= 1'b0;
        end
    end

    // Read data valid
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_rvalid <= 1'b0;
            axi_rresp  <= 2'b0;
        end else if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
            axi_rvalid <= 1'b1;
            axi_rresp  <= 2'b00; // OKAY
        end else if (axi_rvalid && S_AXI_RREADY) begin
            axi_rvalid <= 1'b0;
        end
    end

    // Read data mux
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            axi_rdata <= 0;
        else if (~axi_rvalid && S_AXI_ARVALID) begin
            case (S_AXI_ARADDR[4:2])
                3'd0: axi_rdata <= slv_reg0;
                3'd1: axi_rdata <= slv_reg1;
                3'd2: axi_rdata <= slv_reg2;
                3'd3: axi_rdata <= slv_reg3;
                3'd4: axi_rdata <= slv_reg4;
                3'd5: axi_rdata <= slv_reg5;
                3'd6: axi_rdata <= {31'd0, wrap_flag};
                default: axi_rdata <= 32'd0;
            endcase
        end
    end

endmodule
