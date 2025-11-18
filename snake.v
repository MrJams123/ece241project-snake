// -----------------------
// VERSION 2025-11-18
// -----------------------
// for DE1-SoC
// ----------------------
// to do:
// * background image
// * game over image
// start game image
// switch reset to spacebar
// --------------------------

module snake (
    input wire CLOCK_50,
    input wire [9:0] SW,
    input wire [3:0] KEY, // KEY[0] = RESET
    inout wire PS2_CLK,
    inout wire PS2_DAT,
    output wire [9:0] LEDR,
    output wire [6:0] HEX0,
    output wire [6:0] HEX1,
    output wire [7:0] VGA_R,
    output wire [7:0] VGA_G,
    output wire [7:0] VGA_B,
    output wire VGA_HS,
    output wire VGA_VS,
    output wire VGA_BLANK_N,
    output wire VGA_SYNC_N,
    output wire VGA_CLK
);

    localparam RESOLUTION = "160x120";
    localparam COLOR_DEPTH = 3;
    localparam nX = 10;
    localparam nY = 9;
   
    localparam H_ACTIVE = 640, H_FRONT = 16, H_SYNC = 96, H_BACK = 48;
    localparam H_TOTAL = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;
    localparam V_ACTIVE = 480, V_FRONT = 10, V_SYNC = 2, V_BACK = 33;
    localparam V_TOTAL = V_ACTIVE + V_FRONT + V_SYNC + V_BACK;

    localparam SCALE_X = 4, SCALE_Y = 4;
    localparam GRID_W = H_ACTIVE / SCALE_X;
    localparam GRID_H = V_ACTIVE / SCALE_Y;

    wire resetn = KEY[0];

    //---------------------------------------------------
    // PS/2 Keyboard Direction Control
    //---------------------------------------------------
    wire move_up, move_down, move_left, move_right;
   
    ps2_direction_decoder PS2_DIR (
        .CLOCK_50(CLOCK_50),
        .Resetn(resetn),
        .PS2_CLK(PS2_CLK),
        .PS2_DAT(PS2_DAT),
        .move_up(move_up),
        .move_down(move_down),
        .move_left(move_left),
        .move_right(move_right)
    );

    // Half-Second Tick
    wire half_sec_tick;
    half_second_counter tick_gen (
        .clock (CLOCK_50),
        .resetn (resetn),
        .tick (half_sec_tick)
    );

    // Snake and Food Logic
    wire [9:0] snake_x;
    wire [8:0] snake_y;
    wire [8:0] snake_color;
    wire snake_write;
    wire [7:0] score;
    wire game_over;

    snake_game_fsm SNAKE_GAME (
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
   
    // Game over indicator on LED
    assign LEDR[9] = game_over;
   
    reg [9:0] h_count = 0;
    reg [9:0] v_count = 0;
    reg pixel_clk = 0;
    reg hs = 1, vs = 1, blank = 1;

    vga_adapter VGA (
        .resetn(KEY[0]),
        .clock(CLOCK_50),
        .color(snake_color),
        .x(snake_x),
        .y(snake_y),
        .write(snake_write),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_BLANK_N(VGA_BLANK_N),
        .VGA_SYNC_N(VGA_SYNC_N),
        .VGA_CLK(VGA_CLK));
   
    defparam VGA.BACKGROUND_IMAGE = "./MIF/background_640x480.mif";

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

//---------------------------------------------------
// PS/2 Direction Decoder with Edge Detection
//---------------------------------------------------
module ps2_direction_decoder (
    input wire CLOCK_50,
    input wire Resetn,
    inout wire PS2_CLK,
    inout wire PS2_DAT,
    output reg move_up,
    output reg move_down,
    output reg move_left,
    output reg move_right
);

    wire PS2_CLK_S, PS2_DAT_S;
    reg prev_ps2_clk;
    wire negedge_ps2_clk;

    sync S3 (PS2_CLK, Resetn, CLOCK_50, PS2_CLK_S);
    sync S4 (PS2_DAT, Resetn, CLOCK_50, PS2_DAT_S);

    always @(posedge CLOCK_50)
        prev_ps2_clk <= PS2_CLK_S;

    assign negedge_ps2_clk = (prev_ps2_clk & ~PS2_CLK_S);

    reg [32:0] Serial;
    reg [3:0] Packet;

    always @(posedge CLOCK_50) begin
        if (!Resetn)
            Serial <= 33'b0;
        else if (negedge_ps2_clk) begin
            Serial[31:0] <= Serial[32:1];
            Serial[32] <= PS2_DAT_S;
        end
    end

    always @(posedge CLOCK_50) begin
        if (!Resetn || Packet == 4'd11)
            Packet <= 4'd0;
        else if (negedge_ps2_clk)
            Packet <= Packet + 1'b1;
    end

    wire ps2_rec = (Packet == 4'd11);
    wire [7:0] scancode = Serial[8:1];

    // Track E0 prefix and break codes (F0)
    reg got_E0;
    reg got_F0;
   
    always @(posedge CLOCK_50) begin
        if (!Resetn) begin
            got_E0 <= 1'b0;
            got_F0 <= 1'b0;
        end else if (ps2_rec) begin
            if (scancode == 8'hE0)
                got_E0 <= 1'b1;
            else if (scancode == 8'hF0)
                got_F0 <= 1'b1;
            else begin
                got_E0 <= 1'b0;
                got_F0 <= 1'b0;
            end
        end
    end

    // Direction control - pulse on key press, hold until new direction
    reg [1:0] current_direction;
   
    always @(posedge CLOCK_50) begin
        if (!Resetn) begin
            current_direction <= 2'b11; // Start moving right
            move_up <= 0;
            move_down <= 0;
            move_left <= 0;
            move_right <= 1;
        end else if (ps2_rec && got_E0 && !got_F0) begin
            // Only respond to make codes (key press), not break codes
            case (scancode)
                8'h75: begin // UP
                    current_direction <= 2'b00;
                    move_up <= 1;
                    move_down <= 0;
                    move_left <= 0;
                    move_right <= 0;
                end
                8'h72: begin // DOWN
                    current_direction <= 2'b01;
                    move_up <= 0;
                    move_down <= 1;
                    move_left <= 0;
                    move_right <= 0;
                end
                8'h6B: begin // LEFT
                    current_direction <= 2'b10;
                    move_up <= 0;
                    move_down <= 0;
                    move_left <= 1;
                    move_right <= 0;
                end
                8'h74: begin // RIGHT
                    current_direction <= 2'b11;
                    move_up <= 0;
                    move_down <= 0;
                    move_left <= 0;
                    move_right <= 1;
                end
            endcase
        end
    end
endmodule

// Input Synchronizer
module sync (input wire D, Resetn, Clock, output reg Q);
    reg Qi;
    always @(posedge Clock or negedge Resetn) begin
        if (!Resetn) {Qi, Q} <= 2'b00;
        else {Qi, Q} <= {D, Qi};
    end
endmodule

// Half-Second Tick
module half_second_counter (input wire clock, resetn, output wire tick);
    `ifdef SIMULATION
        localparam MAX_COUNT = 10 - 1;
    `else
        localparam MAX_COUNT = 25000000;
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
               
                // ===== CHANGE 1: Fixed loop bounds to prevent index 64 access =====
                // Check self-collision (head hitting body)
                // OLD: for (i = 1; i < SNAKE_LENGTH; i = i + 1)
                // NEW: for (i = 1; i < MAX_SNAKE_LENGTH; i = i + 1) with condition
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