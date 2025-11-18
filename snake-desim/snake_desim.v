/*  Snake Game
 *  - KEY[0]: Reset
 *  - KEY[1]: Up
 *  - KEY[2]: Down
 *  - KEY[3]: Left
 *  - SW[0] : Right
 *  - SW[8:0]: Color (RGB 3-bit each)
 *  - Snake moves every 0.5 seconds
 */

 // -------------------------------------------------
 // !! DESIM VERSION !!
 // -------------------------------------------------

module snake_desim (
    input  wire       CLOCK_50,
    input  wire [9:0] SW, // SW[0] = RESET
    input  wire [3:0] KEY, // KEY[0] = RIGHT, KEY[1] = UP, KEY[2] = DOWN, KEY[3] = LEFT
    output wire [9:0] LEDR,
    output wire [6:0] HEX0,
    output wire [6:0] HEX1,
    output wire [7:0] VGA_R,
    output wire [7:0] VGA_G,
    output wire [7:0] VGA_B,
    output wire       VGA_HS,
    output wire       VGA_VS,
    output wire       VGA_BLANK_N,
    output wire       VGA_SYNC_N,
    output wire       VGA_CLK
);

    //  Parameters

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


    //  Inputs
    wire resetn = ~SW[0];
    wire move_up_raw   = ~KEY[1];
    wire move_down_raw = ~KEY[2];
    wire move_left_raw = ~KEY[3];
    wire move_right_raw = ~KEY[0];

    // Synchronize inputs
    wire move_up, move_down, move_left, move_right;
    sync s_up   (move_up_raw,   resetn, CLOCK_50, move_up);
    sync s_down (move_down_raw, resetn, CLOCK_50, move_down);
    sync s_left (move_left_raw, resetn, CLOCK_50, move_left);
    sync s_right(move_right_raw,resetn, CLOCK_50, move_right);


    //  Half-Second Tick (0.5 s @ 50 MHz)
    wire half_sec_tick;
    half_second_counter tick_gen (
        .clock  (CLOCK_50),
        .resetn (resetn),
        .tick   (half_sec_tick)
    );

    // Snake and Food Logic
    wire [9:0] snake_x;
    wire [8:0] snake_y;
    wire [8:0] snake_color;
    wire snake_write;
    wire [7:0] score;
    wire game_over;

    snake_game_fsm SG (
        .Resetn (resetn),
        .Clock (CLOCK_50),
        .move_up (move_up),
        .move_down (move_down),
        .move_left (move_left),
        .move_right(move_right),
        .new_color (SW[8:0]),
        .tick (half_sec_tick),
        .VGA_x (snake_x),
        .VGA_y (snake_y),
        .VGA_color (snake_color),
        .VGA_write (snake_write),
        .score (score),
        .game_over (game_over)
    );

    //  VGA Controller
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

    // Scale grid to pixel - FIXED
    wire [9:0] grid_x = h_count[9:2];  // Divide by 4 to get grid coordinate
    wire [8:0] grid_y = v_count[8:2];  // Divide by 4 to get grid coordinate
    
    wire in_snake_block = snake_write &&
                          (grid_x == snake_x) &&
                          (grid_y == snake_y);

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

    //  Outputs
    assign VGA_CLK     = pixel_clk;
    assign VGA_HS      = ~hs;
    assign VGA_VS      = ~vs;
    assign VGA_BLANK_N = blank;
    assign VGA_SYNC_N  = 1'b0;
    assign VGA_R       = r_out;
    assign VGA_G       = g_out;
    assign VGA_B       = b_out;

    assign LEDR[9]     = game_over;
    assign LEDR[8]     = half_sec_tick;
    assign LEDR[7:0]   = SW[7:0];

    // Score display on 7-segment
    wire [3:0] ones = score % 10;
    wire [3:0] tens = (score / 10) % 10;
   
    hex_decoder H0 (.hex(ones), .segments(HEX0));
    hex_decoder H1 (.hex(tens), .segments(HEX1));

endmodule

//---------------------------------------------------
// 7-Segment Hex Decoder
//---------------------------------------------------
module hex_decoder(
    input [3:0] hex,
    output reg [6:0] segments
);
    always @(*) begin
        case(hex)
            4'h0: segments = 7'b1000000;
            4'h1: segments = 7'b1111001;
            4'h2: segments = 7'b0100100;
            4'h3: segments = 7'b0110000;
            4'h4: segments = 7'b0011001;
            4'h5: segments = 7'b0010010;
            4'h6: segments = 7'b0000010;
            4'h7: segments = 7'b1111000;
            4'h8: segments = 7'b0000000;
            4'h9: segments = 7'b0010000;
            4'hA: segments = 7'b0001000;
            4'hB: segments = 7'b0000011;
            4'hC: segments = 7'b1000110;
            4'hD: segments = 7'b0100001;
            4'hE: segments = 7'b0000110;
            4'hF: segments = 7'b0001110;
            default: segments = 7'b1111111;
        endcase
    end
endmodule

//  Input Synchronizer
module sync (input wire D, Resetn, Clock, output reg Q);
    reg Qi;
    always @(posedge Clock or negedge Resetn) begin
        if (!Resetn) {Qi, Q} <= 2'b00;
        else {Qi, Q} <= {D, Qi};
    end
endmodule


//  Half-Second Tick (0.5 s @ 50 MHz)
module half_second_counter (input wire clock, resetn, output wire tick);
    `ifdef SIMULATION
        localparam MAX_COUNT = 10 - 1;  // Fast for simulation
    `else
        localparam MAX_COUNT = 100000 - 1;  // 0.5 s @ 50 MHz | 25MHz for DE1-SoC, 100kHz for DESim
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


//---------------------------------------------------
// Snake Game FSM with Full Screen Support
//---------------------------------------------------
module snake_game_fsm (
    input wire Resetn, Clock,
    input wire move_up, move_down, move_left, move_right,
    input wire [8:0] new_color,
    input wire tick,
    output reg [9:0] VGA_x,
    output reg [8:0] VGA_y,
    output reg [8:0] VGA_color,
    output reg VGA_write,
    output reg [7:0] score,
    output reg game_over
);

    localparam XSCREEN = 160, YSCREEN = 120;
    localparam SNAKE_SIZE = 4, SNAKE_LENGTH = 8;
    localparam FOOD_SIZE = 4;
    localparam VGA_WIDTH = 640, VGA_HEIGHT = 480;
    localparam SCALE = 4;
    localparam SNAKE_COLOR = 9'b000_001_000;  // White
    localparam FOOD_COLOR = 9'b111_000_000;   // Red
    localparam BG_COLOR = 9'b0;
    localparam MAX_SNAKE_LENGTH = 64;  // Maximum possible snake length

    localparam INIT=0, CLEAR_SCREEN=1, CLEAR_SCREEN_DONE=2, WAIT=3,
               CHECK_COLLISION=4, ERASE_TAIL=5, ERASE_DONE=6, MOVE=7,
               DRAW_HEAD=8, DRAW_DONE=9, DRAW_FOOD=10, DRAW_FOOD_DONE=11,
               ERASE_FOOD=12, ERASE_FOOD_DONE=13, GAME_OVER_STATE=14;
    localparam DIR_RIGHT=0, DIR_LEFT=1, DIR_DOWN=2, DIR_UP=3;
     
    reg [7:0] body_x [0:MAX_SNAKE_LENGTH-1];
    reg [6:0] body_y [0:MAX_SNAKE_LENGTH-1];
    reg [1:0] body_dir [0:MAX_SNAKE_LENGTH-1];
    reg [8:0] color;
    reg [4:0] state = INIT;
    reg [1:0] direction = DIR_RIGHT;
   
    // Pixel counters for drawing (support full VGA resolution)
    reg [9:0] pixel_x = 0;  // 0-639
    reg [8:0] pixel_y = 0;  // 0-479
    reg [6:0] draw_segment = 0;  // Changed to 7 bits to support up to 64 segments
    reg [7:0] next_x;
    reg [6:0] next_y;
    reg collision;
   
    // Dynamic snake length
    reg [6:0] snake_length = 8;  // Start with length 8
   
    // Food position
    reg [7:0] food_x;
    reg [6:0] food_y;
    reg food_eaten;
   
    // LFSR for random food position
    reg [15:0] lfsr = 16'hACE1;
    wire feedback = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];
   
    always @(posedge Clock) begin
        if (!Resetn)
            lfsr <= 16'hACE1;
        else
            lfsr <= {lfsr[14:0], feedback};
    end

    wire [7:0] X_INIT = XSCREEN >> 1;  // Should be 80
    wire [6:0] Y_INIT = YSCREEN >> 1;  // Should be 60

    integer i;

    // Direction control - only when not game over
    always @(posedge Clock) begin
        if (!Resetn)
            direction <= DIR_RIGHT;
        else if (!game_over) begin
            if (move_up && direction != DIR_DOWN) direction <= DIR_UP;
            else if (move_down && direction != DIR_UP) direction <= DIR_DOWN;
            else if (move_left && direction != DIR_RIGHT) direction <= DIR_LEFT;
            else if (move_right && direction != DIR_LEFT) direction <= DIR_RIGHT;
        end
    end

    // Color
    always @(posedge Clock) begin
        if (!Resetn) color <= SNAKE_COLOR;
        else if (new_color != 0) color <= new_color;
    end

    always @(posedge Clock) begin
        if (!Resetn) begin
            state <= INIT;
            draw_segment <= 0;
            score <= 0;
            game_over <= 0;
            food_eaten <= 0;
            food_x <= 100;
            food_y <= 80;
            snake_length <= 8;  // Reset to initial length
            for (i = 0; i < MAX_SNAKE_LENGTH; i = i + 1) begin
                body_x[i] <= X_INIT - (i * SNAKE_SIZE);
                body_y[i] <= Y_INIT;
                body_dir[i] <= DIR_RIGHT;
            end
            pixel_x <= 0; pixel_y <= 0;
            VGA_write <= 0;
        end else case (state)
            INIT: begin
                state <= CLEAR_SCREEN;
                pixel_x <= 0; pixel_y <= 0;
            end
                       
            CLEAR_SCREEN: begin
                VGA_x <= pixel_x;
                VGA_y <= pixel_y;
                VGA_color <= BG_COLOR;
                VGA_write <= 1;
               
                if (pixel_x == VGA_WIDTH-1) begin
                    pixel_x <= 0;
                    if (pixel_y == VGA_HEIGHT-1)
                        state <= CLEAR_SCREEN_DONE;
                    else
                        pixel_y <= pixel_y + 1;
                end else
                    pixel_x <= pixel_x + 1;
            end
           
            CLEAR_SCREEN_DONE: begin
                VGA_write <= 0;
                state <= DRAW_FOOD;
                pixel_x <= 0;
                pixel_y <= 0;
            end
           
            DRAW_FOOD: begin
                VGA_x <= food_x * SCALE + pixel_x;
                VGA_y <= food_y * SCALE + pixel_y;
                VGA_color <= FOOD_COLOR;
                VGA_write <= 1;
               
                if (pixel_x == (FOOD_SIZE * SCALE) - 1) begin
                    pixel_x <= 0;
                    if (pixel_y == (FOOD_SIZE * SCALE) - 1)
                        state <= DRAW_FOOD_DONE;
                    else
                        pixel_y <= pixel_y + 1;
                end else
                    pixel_x <= pixel_x + 1;
           end
           
            DRAW_FOOD_DONE: begin
                VGA_write <= 0;
                food_eaten <= 0; // jw - change food_eaten to 0 after drawing food
                state <= DRAW_HEAD;
                pixel_x <= 0; pixel_y <= 0;
                draw_segment <= 0;
            end
           
            WAIT: begin
                if (tick && !game_over) begin
                    state <= CHECK_COLLISION;
                end
           end
           
            CHECK_COLLISION: begin
                // Calculate next head position
               
               next_x = body_x[0];
                next_y = body_y[0];
                collision = 0;
               
                // Calculate next position based on direction
                case (direction)
                    DIR_RIGHT: begin
                        next_x = body_x[0] + SNAKE_SIZE;
                        if (next_x >= XSCREEN) collision = 1;  // Hit right wall
                    end
                    DIR_LEFT: begin
                        if (body_x[0] < SNAKE_SIZE)
                            collision = 1;  // Hit left wall
                        else
                            next_x = body_x[0] - SNAKE_SIZE;
                    end
                    DIR_DOWN: begin
                        next_y = body_y[0] + SNAKE_SIZE;
                        if (next_y >= YSCREEN) collision = 1;  // Hit bottom wall
                    end
                    DIR_UP: begin
                        if (body_y[0] < SNAKE_SIZE)
                            collision = 1;  // Hit top wall
                        else
                            next_y = body_y[0] - SNAKE_SIZE;
                    end
                endcase
               
                if (!collision) begin
                    for (i = 1; i < MAX_SNAKE_LENGTH; i = i + 1) begin
                        if (i < snake_length && next_x == body_x[i] && next_y == body_y[i]) begin
                            collision = 1;
                        end
                    end
                end
                // ===== END CHANGE 1 =====
               
                // Check collision with food
                if (collision) begin
                    game_over <= 1;
                    state <= GAME_OVER_STATE;
                end else begin
                    if (next_x == food_x && next_y == food_y) begin // jw - fixed food collision
                        food_eaten <= 1;
                        state <= ERASE_FOOD;
                    end else begin  
                        food_eaten <= 0;
                        state <= ERASE_TAIL;
                    end
                end

                pixel_x <= 0; pixel_y <= 0;
            end
           
            ERASE_FOOD: begin
                VGA_x <= food_x * SCALE + pixel_x;
                VGA_y <= food_y * SCALE + pixel_y;
                VGA_color <= BG_COLOR;
                VGA_write <= 1;
                if (pixel_x == (FOOD_SIZE * SCALE) - 1) begin
                    pixel_x <= 0;
                    if (pixel_y == (FOOD_SIZE * SCALE) - 1) state <= ERASE_FOOD_DONE;
                    else pixel_y <= pixel_y + 1;
                end else pixel_x <= pixel_x + 1;
            end
           
            ERASE_FOOD_DONE: begin
                VGA_write <= 0;
                score <= score + 1;

                // Increase snake length (up to maximum)
                if (snake_length < MAX_SNAKE_LENGTH)
                    snake_length <= snake_length + 1;

                // Generate new food position
                food_x <= (lfsr[7:0] % (XSCREEN / SNAKE_SIZE)) * SNAKE_SIZE;
                food_y <= (lfsr[14:8] % (YSCREEN / SNAKE_SIZE)) * SNAKE_SIZE;
                             
                state <= MOVE; // jw - changed from ERASE_TAIL -> MOVE (grow; skip tail erase)
            end
           
            ERASE_TAIL: begin
                VGA_x <= body_x[snake_length-1] * SCALE + pixel_x;
                VGA_y <= body_y[snake_length-1] * SCALE + pixel_y;
                VGA_color <= BG_COLOR;
                VGA_write <= 1;
                if (pixel_x == (SNAKE_SIZE * SCALE) - 1) begin
                    pixel_x <= 0;
                    if (pixel_y == SNAKE_SIZE * SCALE -1) state <= ERASE_DONE;
                    else pixel_y <= pixel_y + 1;
                end else pixel_x <= pixel_x + 1;
            end
           
            ERASE_DONE: begin VGA_write <= 0; state <= MOVE; end
           
            // ===== CHANGE 2: Fixed MOVE loop to prevent index 64 access =====
            MOVE: begin
                // OLD: for (i = SNAKE_LENGTH-1; i > 0; i = i - 1)
                // NEW: for (i = MAX_SNAKE_LENGTH-1; i > 0; i = i - 1) with condition
                for (i = MAX_SNAKE_LENGTH-1; i > 0; i = i - 1) begin
                    if (i < snake_length) begin
                        body_x[i] <= body_x[i-1];
                        body_y[i] <= body_y[i-1];
                        body_dir[i] <= body_dir[i-1];
                    end
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
            // ===== END CHANGE 2 =====
           
            DRAW_HEAD: begin
                VGA_write <= 1;
                VGA_color <= color;
                VGA_x <= body_x[draw_segment] * SCALE + pixel_x;
                VGA_y <= body_y[draw_segment] * SCALE + pixel_y;
                if (pixel_x == (SNAKE_SIZE * SCALE) -1) begin
                    pixel_x <= 0;
                    if (pixel_y == SNAKE_SIZE * SCALE -1) begin
                        pixel_y <= 0;
                        if (draw_segment == snake_length-1) state <= DRAW_DONE;
                        else draw_segment <= draw_segment + 1;
                    end else pixel_y <= pixel_y + 1;
                end else pixel_x <= pixel_x + 1;
            end
           
            DRAW_DONE: begin
                VGA_write <= 0;
                if (food_eaten) begin
                    state <= DRAW_FOOD;
                    pixel_x <= 0; pixel_y <= 0;
                end else begin
                    state <= WAIT;
                end
            end

            GAME_OVER_STATE: begin
                // Stay here until reset
                VGA_write <= 0;
            end
           
            default: state <= INIT;
        endcase
    end
endmodule