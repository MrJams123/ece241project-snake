`default_nettype none

/*  Snake Game for DE1-SoC
 *  - KEY[0]: Reset
 *  - KEY[1]: Up
 *  - KEY[2]: Down
 *  - KEY[3]: Left
 *  - SW[0] : Right
 *  - SW[8:0]: Color (RGB 3-bit each)
 *  - Snake moves every 0.5 seconds
 */

module vga_demo (
    input  wire       CLOCK_50,
    input  wire [9:0] SW,
    input  wire [3:0] KEY,
    output wire [9:0] LEDR,
    output wire [7:0] VGA_R,
    output wire [7:0] VGA_G,
    output wire [7:0] VGA_B,
    output wire       VGA_HS,
    output wire       VGA_VS,
    output wire       VGA_BLANK_N,
    output wire       VGA_SYNC_N,
    output wire       VGA_CLK
);

    // ==============================
    //  Parameters
    // ==============================
    localparam RESOLUTION = "160x120";
    localparam COLOR_DEPTH = 9;
    localparam nX = 8;
    localparam nY = 7;

    // VGA 640x480@60Hz
    localparam H_ACTIVE = 640, H_FRONT = 16, H_SYNC = 96, H_BACK = 48;
    localparam H_TOTAL = H_ACTIVE + H_FRONT + H_SYNC + H_BACK; // 800
    localparam V_ACTIVE = 480, V_FRONT = 10, V_SYNC = 2, V_BACK = 33;
    localparam V_TOTAL = V_ACTIVE + V_FRONT + V_SYNC + V_BACK; // 525

    localparam SCALE_X = 4, SCALE_Y = 4;
    localparam GRID_W = H_ACTIVE / SCALE_X;  // 160
    localparam GRID_H = V_ACTIVE / SCALE_Y;  // 120

    // ==============================
    //  Inputs
    // ==============================
    wire resetn = KEY[0];
    wire move_up_raw   = ~KEY[1];
    wire move_down_raw = ~KEY[2];
    wire move_left_raw = ~KEY[3];
    wire move_right_raw = SW[0];

    // Synchronize inputs
    wire move_up, move_down, move_left, move_right;
    sync s_up   (move_up_raw,   resetn, CLOCK_50, move_up);
    sync s_down (move_down_raw, resetn, CLOCK_50, move_down);
    sync s_left (move_left_raw, resetn, CLOCK_50, move_left);
    sync s_right(move_right_raw,resetn, CLOCK_50, move_right);

    // ==============================
    //  Half-Second Tick (0.5 s @ 50 MHz)
    // ==============================
    wire half_sec_tick;
    half_second_counter tick_gen (
        .clock  (CLOCK_50),
        .resetn (resetn),
        .tick   (half_sec_tick)
    );

    // ==============================
    //  Snake Logic
    // ==============================
    wire [7:0] snake_x;
    wire [6:0] snake_y;
    wire [8:0] snake_color;
    wire       snake_write;

    snake SNAKE (
        .Resetn    (resetn),
        .Clock     (CLOCK_50),
        .move_up   (move_up),
        .move_down (move_down),
        .move_left (move_left),
        .move_right(move_right),
        .new_color (SW[8:0]),
        .tick      (half_sec_tick),
        .VGA_x     (snake_x),
        .VGA_y     (snake_y),
        .VGA_color (snake_color),
        .VGA_write (snake_write)
    );

    // ==============================
    //  VGA Controller
    // ==============================
    reg [9:0] h_count = 0;
    reg [9:0] v_count = 0;
    reg pixel_clk = 0;
    reg hs = 1, vs = 1, blank = 1;

    // 50 MHz → 25 MHz pixel clock
    always @(posedge CLOCK_50) pixel_clk <= ~pixel_clk;

    always @(posedge pixel_clk or negedge resetn) begin
        if (!resetn) begin
            h_count <= 0;
            v_count <= 0;
            hs <= 1; vs <= 1; blank <= 1;
        end else begin
            if (h_count == H_TOTAL-1) begin
                h_count <= 0;
                v_count <= (v_count == V_TOTAL-1) ? 0 : v_count + 1;
            end else h_count <= h_count + 1;

            hs <= (h_count >= H_ACTIVE + H_FRONT) && (h_count < H_ACTIVE + H_FRONT + H_SYNC);
            vs <= (v_count >= V_ACTIVE + V_FRONT) && (v_count < V_ACTIVE + V_FRONT + V_SYNC);
            blank <= (h_count < H_ACTIVE) && (v_count < V_ACTIVE);
        end
    end

    // Scale grid to pixel
    wire [7:0] pixel_x = snake_x * SCALE_X + h_count[1:0];
    wire [6:0] pixel_y = snake_y * SCALE_Y + v_count[1:0];
    wire in_snake_block = snake_write &&
                          (h_count[9:2] == pixel_x) &&
                          (v_count[8:2] == pixel_y);

    reg [7:0] r_out = 0, g_out = 0, b_out = 0;
    always @(posedge pixel_clk) begin
        if (blank && in_snake_block) begin
            r_out <= {snake_color[8:6], 5'b0};
            g_out <= {snake_color[5:3], 5'b0};
            b_out <= {snake_color[2:0], 5'b0};
        end else begin
            r_out <= 0; g_out <= 0; b_out <= 0;
        end
    end

    // ==============================
    //  Outputs
    // ==============================
    assign VGA_CLK     = pixel_clk;
    assign VGA_HS      = ~hs;
    assign VGA_VS      = ~vs;
    assign VGA_BLANK_N = blank;
    assign VGA_SYNC_N  = 1'b0;
    assign VGA_R       = r_out;
    assign VGA_G       = g_out;
    assign VGA_B       = b_out;

    assign LEDR[9]     = half_sec_tick;
    assign LEDR[8:0]   = SW[8:0];

endmodule

// ------------------------------------------------------------
//  Input Synchronizer
// ------------------------------------------------------------
module sync (input wire D, Resetn, Clock, output reg Q);
    reg Qi;
    always @(posedge Clock or negedge Resetn) begin
        if (!Resetn) {Qi, Q} <= 2'b00;
        else {Qi, Q} <= {D, Qi};
    end
endmodule

// ------------------------------------------------------------
//  Half-Second Tick (0.5 s @ 50 MHz)
// ------------------------------------------------------------
module half_second_counter (input wire clock, resetn, output wire tick);
    `ifdef SIMULATION
        localparam MAX_COUNT = 10 - 1;  // Fast for simulation
    `else
        localparam MAX_COUNT = 1;  // 0.5 s @ 50 MHz
    `endif

    reg [24:0] count = MAX_COUNT;

    always @(posedge clock or negedge resetn) begin
        if (!resetn)
            count <= MAX_COUNT;
        else if (count == 0)
            count <= MAX_COUNT;
        else
            count <= count - 1;
    end

    assign tick = (count == 0);
endmodule

// ------------------------------------------------------------
//  Snake with Body
// ------------------------------------------------------------
module snake (
    input wire Resetn, Clock,
    input wire move_up, move_down, move_left, move_right,
    input wire [8:0] new_color,
    input wire tick,
    output reg [7:0] VGA_x,
    output reg [6:0] VGA_y,
    output reg [8:0] VGA_color,
    output reg VGA_write
);

    localparam XSCREEN = 160, YSCREEN = 120;
    localparam SNAKE_SIZE = 4, SNAKE_LENGTH = 8;
    localparam ALT = 9'b0;

    localparam INIT=0, WAIT=1, ERASE_TAIL=2, ERASE_DONE=3, MOVE=4, DRAW_HEAD=5, DRAW_DONE=6;
    localparam DIR_RIGHT=0, DIR_LEFT=1, DIR_DOWN=2, DIR_UP=3;

    reg [7:0] body_x [0:SNAKE_LENGTH-1];
    reg [6:0] body_y [0:SNAKE_LENGTH-1];
    reg [1:0] body_dir [0:SNAKE_LENGTH-1];
    reg [8:0] color;
    reg [2:0] state = INIT;
    reg [1:0] direction = DIR_RIGHT;
    reg [1:0] pixel_x = 0, pixel_y = 0;
    reg [3:0] draw_segment = 0;

    wire [7:0] X_INIT = XSCREEN >> 1;
    wire [6:0] Y_INIT = YSCREEN >> 1;

    integer i;

    // Direction control
    always @(posedge Clock) begin
        if (!Resetn) direction <= DIR_RIGHT;
        else if (move_up && direction != DIR_DOWN) direction <= DIR_UP;
        else if (move_down && direction != DIR_UP) direction <= DIR_DOWN;
        else if (move_left && direction != DIR_RIGHT) direction <= DIR_LEFT;
        else if (move_right && direction != DIR_LEFT) direction <= DIR_RIGHT;
    end

    // Color
    always @(posedge Clock) begin
        if (!Resetn) color <= 9'b111_111_111;
        else if (new_color != 0) color <= new_color;
    end

    always @(posedge Clock) begin
        if (!Resetn) begin
            state <= INIT;
            draw_segment <= 0;
            for (i = 0; i < SNAKE_LENGTH; i = i + 1) begin
                body_x[i] <= X_INIT - (i * SNAKE_SIZE);
                body_y[i] <= Y_INIT;
                body_dir[i] <= DIR_RIGHT;
            end
            pixel_x <= 0; pixel_y <= 0;
            VGA_write <= 0;
        end else case (state)
            INIT: begin
                state <= DRAW_HEAD;
                pixel_x <= 0; pixel_y <= 0;
                draw_segment <= 0;
            end
            WAIT: if (tick) begin
                state <= ERASE_TAIL;
                pixel_x <= 0; pixel_y <= 0;
            end
            ERASE_TAIL: begin
                VGA_x <= body_x[SNAKE_LENGTH-1] + pixel_x;
                VGA_y <= body_y[SNAKE_LENGTH-1] + pixel_y;
                VGA_color <= ALT;
                VGA_write <= 1;
                if (pixel_x == SNAKE_SIZE-1) begin
                    pixel_x <= 0;
                    if (pixel_y == SNAKE_SIZE-1) state <= ERASE_DONE;
                    else pixel_y <= pixel_y + 1;
                end else pixel_x <= pixel_x + 1;
            end
            ERASE_DONE: begin VGA_write <= 0; state <= MOVE; end
            MOVE: begin
                for (i = SNAKE_LENGTH-1; i > 0; i = i - 1) begin
                    body_x[i] <= body_x[i-1];
                    body_y[i] <= body_y[i-1];
                    body_dir[i] <= body_dir[i-1];
                end
                case (direction)
                    DIR_RIGHT: body_x[0] <= (body_x[0] >= XSCREEN - SNAKE_SIZE) ? 0 : body_x[0] + SNAKE_SIZE;
                    DIR_LEFT:  body_x[0] <= (body_x[0] < SNAKE_SIZE) ? XSCREEN - SNAKE_SIZE : body_x[0] - SNAKE_SIZE;
                    DIR_DOWN:  body_y[0] <= (body_y[0] >= YSCREEN - SNAKE_SIZE) ? 0 : body_y[0] + SNAKE_SIZE;
                    DIR_UP:    body_y[0] <= (body_y[0] < SNAKE_SIZE) ? YSCREEN - SNAKE_SIZE : body_y[0] - SNAKE_SIZE;
                endcase
                body_dir[0] <= direction;
                state <= DRAW_HEAD;
                pixel_x <= 0; pixel_y <= 0;
                draw_segment <= 0;
            end
            DRAW_HEAD: begin
                VGA_write <= 1;
                VGA_color <= color;
                VGA_x <= body_x[draw_segment] + pixel_x;
                VGA_y <= body_y[draw_segment] + pixel_y;
                if (pixel_x == SNAKE_SIZE-1) begin
                    pixel_x <= 0;
                    if (pixel_y == SNAKE_SIZE-1) begin
                        pixel_y <= 0;
                        if (draw_segment == SNAKE_LENGTH-1) state <= DRAW_DONE;
                        else draw_segment <= draw_segment + 1;
                    end else pixel_y <= pixel_y + 1;
                end else pixel_x <= pixel_x + 1;
            end
            DRAW_DONE: begin VGA_write <= 0; state <= WAIT; end
            default: state <= INIT;
        endcase
    end
endmodule

`default_nettype wire