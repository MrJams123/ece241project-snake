`default_nettype none

/* --------------------------------------------------------------------
   Top-level for DE1-SoC
   - Connects the original "plot" interface (for simulation) to the
     real VGA outputs that vga_demo now provides.
   - HEX displays are left unconnected (you can drive them later).
   ------------------------------------------------------------------- */
module top (
    input  wire       CLOCK_50,      // 50 MHz clock
    input  wire [9:0] SW,            // switches
    input  wire [3:0] KEY,           // push-buttons (active-low)

    output wire [6:0] HEX0,          // HEX displays – not used
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,
    output wire [6:0] HEX4,
    output wire [6:0] HEX5,

    output wire [9:0] LEDR,          // LEDs

    // ----- "plot" interface (kept for legacy test-benches) -----
    output wire [9:0] VGA_X,
    output wire [8:0] VGA_Y,
    output wire [23:0] VGA_COLOR,
    output wire       plot,

    // ----- Real VGA pins (DE1-SoC) -----
    output wire [7:0] VGA_R,
    output wire [7:0] VGA_G,
    output wire [7:0] VGA_B,
    output wire       VGA_HS,
    output wire       VGA_VS,
    output wire       VGA_BLANK_N,
    output wire       VGA_SYNC_N,
    output wire       VGA_CLK
);

    // ----------------------------------------------------------------
    //  Parameters (same as before)
    // ----------------------------------------------------------------
    parameter RESOLUTION  = "160x120";
    parameter COLOR_DEPTH = 9;

    // Width of X/Y coordinates for the selected resolution
    localparam nX = (RESOLUTION == "640x480") ? 10 :
                    (RESOLUTION == "320x240") ?  9 : 8;
    localparam nY = (RESOLUTION == "640x480") ?  9 :
                    (RESOLUTION == "320x240") ?  8 : 7;

    // ----------------------------------------------------------------
    //  Instantiate the **real** VGA demo (the one with VGA_R/G/B …)
    // ----------------------------------------------------------------
    wire [7:0] vga_r, vga_g, vga_b;
    wire       vga_hs, vga_vs, vga_blank_n, vga_sync_n, vga_clk;

    vga_demo U1 (
        .CLOCK_50    (CLOCK_50),
        .SW          (SW),
        .KEY         (KEY),
        .LEDR        (LEDR),

        .VGA_R       (vga_r),
        .VGA_G       (vga_g),
        .VGA_B       (vga_b),
        .VGA_HS      (vga_hs),
        .VGA_VS      (vga_vs),
        .VGA_BLANK_N (vga_blank_n),
        .VGA_SYNC_N  (vga_sync_n),
        .VGA_CLK     (vga_clk)
    );
    defparam U1.RESOLUTION  = RESOLUTION;
    defparam U1.COLOR_DEPTH = COLOR_DEPTH;

    // ----------------------------------------------------------------
    //  Drive the **real** VGA pins
    // ----------------------------------------------------------------
    assign VGA_R       = vga_r;
    assign VGA_G       = vga_g;
    assign VGA_B       = vga_b;
    assign VGA_HS      = vga_hs;
    assign VGA_VS      = vga_vs;
    assign VGA_BLANK_N = vga_blank_n;
    assign VGA_SYNC_N  = vga_sync_n;
    assign VGA_CLK     = vga_clk;

    // ----------------------------------------------------------------
    //  Optional: expose the internal "plot" interface for simulation
    //  (connect to the snake's write signals – safe because they exist
    //   inside vga_demo even though they are not top-level ports)
    // ----------------------------------------------------------------
    assign VGA_X     = U1.SG.VGA_x;          // 8-bit (160 max)
    assign VGA_Y     = U1.SG.VGA_y;          // 7-bit (120 max)
    assign VGA_COLOR = {U1.SG.VGA_color[8:6],5'b0,
                        U1.SG.VGA_color[5:3],5'b0,
                        U1.SG.VGA_color[2:0],5'b0};
    assign plot      = U1.SG.VGA_write;

    // ----------------------------------------------------------------
    //  HEX displays – leave blank (or drive them with score later)
    // ----------------------------------------------------------------
    assign {HEX5,HEX4,HEX3,HEX2,HEX1,HEX0} = {42{1'b1}}; // all segments off

endmodule

`default_nettype wire