// Project F: Hardware Sprites - Hourglass (iCEBreaker 12-bit DVI Pmod)
// (C)2022 Will Green, open source hardware released under the MIT License
// Learn more at https://projectf.io/posts/hardware-sprites/

`default_nettype none
`timescale 1ns / 1ps

module top_hourglass (
    input  wire logic clk_12m,      // 12 MHz clock
    input  wire logic btn_rst,      // reset button
    output      logic dvi_clk,      // DVI pixel clock
    output      logic dvi_hsync,    // DVI horizontal sync
    output      logic dvi_vsync,    // DVI vertical sync
    output      logic dvi_de,       // DVI data enable
    output      logic [3:0] dvi_r,  // 4-bit DVI red
    output      logic [3:0] dvi_g,  // 4-bit DVI green
    output      logic [3:0] dvi_b   // 4-bit DVI blue
    );

    // generate pixel clock
    logic clk_pix;
    logic clk_pix_locked;
    clock_480p clock_pix_inst (
       .clk_12m,
       .rst(btn_rst),
       .clk_pix,
       .clk_pix_locked
    );

    // reset in pixel clock domain
    logic rst_pix;
    always_comb rst_pix = !clk_pix_locked;  // wait for clock lock

    // display sync signals and coordinates
    localparam CORDW = 16;  // signed coordinate width (bits)
    logic signed [CORDW-1:0] sx, sy;
    logic hsync, vsync;
    logic de, line;
    display_480p #(.CORDW(CORDW)) display_inst (
        .clk_pix,
        .rst_pix,
        .sx,
        .sy,
        .hsync,
        .vsync,
        .de,
        /* verilator lint_off PINCONNECTEMPTY */
        .frame(),
        /* verilator lint_on PINCONNECTEMPTY */
        .line
    );

    // screen dimensions (must match display_inst)
    localparam H_RES = 640;

    // colour parameters
    localparam CHANW = 4;         // colour channel width (bits)
    localparam COLRW = 3*CHANW;   // colour width: three channels (bits)
    localparam CIDXW = 4;         // colour index width (bits)
    localparam TRANS_INDX = 'hF;  // transparant colour index
    localparam BG_COLR = 'h137;   // background colour
    localparam PAL_FILE = "../../../lib/res/palettes/teleport16_4b.mem";  // palette file

    // sprite parameters
    localparam SX_OFFS    = 3;  // horizontal screen offset (pixels): +1 for CLUT
    localparam SPR_WIDTH  = 8;  // bitmap width in pixels
    localparam SPR_HEIGHT = 8;  // bitmap height in pixels
    localparam SPR_SCALE  = 4;  // 2^4 = 16x scale
    localparam SPR_FILE   = "../res/sprites/hourglass.mem";  // bitmap file

    logic drawing;  // drawing at (sx,sy)
    logic [CIDXW-1:0] spr_pix_indx;  // pixel colour index
    sprite #(
        .CORDW(CORDW),
        .H_RES(H_RES),
        .SX_OFFS(SX_OFFS),
        .SPR_FILE(SPR_FILE),
        .SPR_WIDTH(SPR_WIDTH),
        .SPR_HEIGHT(SPR_HEIGHT),
        .SPR_SCALE(SPR_SCALE),
        .SPR_DATAW(CIDXW)
        ) sprite_hourglass (
        .clk(clk_pix),
        .rst(rst_pix),
        .line,
        .sx,
        .sy,
        .sprx(32),
        .spry(16),
        .pix(spr_pix_indx),
        .drawing
    );

    // colour lookup table
    logic [COLRW-1:0] spr_pix_colr;
    clut_simple #(
        .COLRW(COLRW),
        .CIDXW(CIDXW),
        .F_PAL(PAL_FILE)
        ) clut_instance (
        .clk_write(clk_pix),
        .clk_read(clk_pix),
        .we(0),
        .cidx_write(0),
        .cidx_read(spr_pix_indx),
        .colr_in(0),
        .colr_out(spr_pix_colr)
    );

    // account for transparency and delay drawing signal to match CLUT delay (1 cycle)
    logic drawing_t1;
    always_ff @(posedge clk_pix) drawing_t1 <= drawing && (spr_pix_indx != TRANS_INDX);

    // paint colours
    logic [CHANW-1:0] paint_r, paint_g, paint_b;
    always_comb {paint_r, paint_g, paint_b} = (drawing_t1) ? spr_pix_colr : BG_COLR;

    // DVI Pmod output
    SB_IO #(
        .PIN_TYPE(6'b010100)  // PIN_OUTPUT_REGISTERED
    ) dvi_signal_io [14:0] (
        .PACKAGE_PIN({dvi_hsync, dvi_vsync, dvi_de, dvi_r, dvi_g, dvi_b}),
        .OUTPUT_CLK(clk_pix),
        .D_OUT_0({hsync, vsync, de, paint_r, paint_g, paint_b}),
        /* verilator lint_off PINCONNECTEMPTY */
        .D_OUT_1()
        /* verilator lint_on PINCONNECTEMPTY */
    );

    // DVI Pmod clock output: 180° out of phase with other DVI signals
    SB_IO #(
        .PIN_TYPE(6'b010000)  // PIN_OUTPUT_DDR
    ) dvi_clk_io (
        .PACKAGE_PIN(dvi_clk),
        .OUTPUT_CLK(clk_pix),
        .D_OUT_0(1'b0),
        .D_OUT_1(1'b1)
    );
endmodule
