`timescale 1ns/1ps
`default_nettype none

// ====================================================================
//  top.v – Pure behavioural top-level for simulation wrapper
//  Works on any simulator (ModelSim, Questa, Vivado, etc.)
//  No Quartus IP, no vga_demo, no PLL, no .mif files required
//  Perfect for your snake testbench
// ====================================================================

module top (
    input  wire       CLOCK_50,
    input  wire [9:0] SW,
    input  wire [3:0] KEY,           // KEY[0] = reset (active low)

    output wire [6:0] HEX0,
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,
    output wire [6:0] HEX4,
    output wire [6:0] HEX5,

    output wire [9:0] LEDR,

    // Legacy "plot" interface – used by your testbench
    output wire [9:0]  VGA_X,      // 0..639
    output wire [8:0]  VGA_Y,      // 0..479
    output wire [23:0] VGA_COLOR,
    output wire        plot,

    // Real VGA pins – connected straight through
    output wire [7:0] VGA_R,
    output wire [7:0] VGA_G,
    output wire [7:0] VGA_B,
    output wire       VGA_HS,
    output wire       VGA_VS,
    output wire       VGA_BLANK_N,
    output wire       VGA_SYNC_N,
    output wire       VGA_CLK
);

    // ================================================================
    //  Instantiate your snake module directly
    // ================================================================
    wire [7:0] vga_r, vga_g, vga_b;
    wire       vga_hs, vga_vs, vga_blank, vga_sync, vga_clk;

    snake U1 (
        .CLOCK_50     (CLOCK_50),
        .SW           (SW),
        .KEY          (KEY),
        .PS2_CLK      (1'b0),        // not used in simulation
        .PS2_DAT      (1'b0),        // not used
        .LEDR         (LEDR),
        .HEX0         (HEX0),
        .HEX1         (HEX1),
        .VGA_R        (vga_r),
        .VGA_G        (vga_g),
        .VGA_B        (vga_b),
        .VGA_HS       (vga_hs),
        .VGA_VS       (vga_vs),
        .VGA_BLANK_N  (vga_blank),
        .VGA_SYNC_N   (vga_sync),
        .VGA_CLK      (vga_clk)
    );

    // Drive real VGA outputs
    assign VGA_R        = vga_r;
    assign VGA_G        = vga_g;
    assign VGA_B        = vga_b;
    assign VGA_HS       = vga_hs;
    assign VGA_VS       = vga_vs;
    assign VGA_BLANK_N  = vga_blank;
    assign VGA_SYNC_N   = vga_sync;
    assign VGA_CLK      = vga_clk;

    // Expose the internal plot signals so your original testbench still works perfectly
    assign VGA_X     = U1.SNAKE.VGA_x;           // 10-bit (0-639)
    assign VGA_Y     = U1.SNAKE.VGA_y;           // 9-bit (0-479)
    assign VGA_COLOR = {U1.SNAKE.VGA_color[8:6], 5'd0,
                        U1.SNAKE.VGA_color[5:3], 5'd0,
                        U1.SNAKE.VGA_color[2:0], 5'd0};  // expand 9-bit → 24-bit
    assign plot      = U1.SNAKE.VGA_write;

    // Turn off unused HEX displays
    assign {HEX5, HEX4, HEX3, HEX2} = 28'b1;  // blank

endmodule

`default_nettype wire