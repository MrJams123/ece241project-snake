`timescale 1ns/1ps
`default_nettype none
`define SIMULATION

module testbench();

   // --------------------------------------------------------------
   // DUT ports (top)
   // --------------------------------------------------------------
   reg        CLOCK_50;
   reg [9:0]  SW;
   reg [3:0]  KEY;
   wire [6:0] HEX0,HEX1,HEX2,HEX3,HEX4,HEX5;
   wire [9:0] LEDR;
   wire [9:0] VGA_X;
   wire [8:0] VGA_Y;
   wire [23:0] VGA_COLOR;
   wire       plot;
   wire [7:0] VGA_R,VGA_G,VGA_B;
   wire       VGA_HS,VGA_VS,VGA_BLANK_N,VGA_SYNC_N,VGA_CLK;

   // --------------------------------------------------------------
   // Instantiate top (the wrapper)
   // --------------------------------------------------------------
   top dut ( .CLOCK_50(CLOCK_50), .SW(SW), .KEY(KEY),
             .HEX0(HEX0),.HEX1(HEX1),.HEX2(HEX2),.HEX3(HEX3),.HEX4(HEX4),.HEX5(HEX5),
             .LEDR(LEDR),
             .VGA_X(VGA_X), .VGA_Y(VGA_Y), .VGA_COLOR(VGA_COLOR), .plot(plot),
             .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B),
             .VGA_HS(VGA_HS), .VGA_VS(VGA_VS),
             .VGA_BLANK_N(VGA_BLANK_N), .VGA_SYNC_N(VGA_SYNC_N), .VGA_CLK(VGA_CLK) );

   // --------------------------------------------------------------
   // Clock (50 MHz)
   // --------------------------------------------------------------
   initial CLOCK_50 = 0;
   always #10 CLOCK_50 = ~CLOCK_50;

   // --------------------------------------------------------------
   // Helper tasks
   // --------------------------------------------------------------
   task press_key(input [3:0] k, input integer ns);
      begin
         $display("%0t ns  *** PRESS KEY[%0d] ***", $time, k);
         KEY[k] = 0; #(ns); KEY[k] = 1;
      end
   endtask

   // Named shortcuts – easier to read in the waveform log
   task press_up   ; press_key(1, 800); endtask
   task press_down ; press_key(2, 800); endtask
   task press_left ; press_key(3, 800); endtask
   task press_reset; press_key(0, 800); endtask

   task set_color(input [8:0] rgb);
      begin SW[8:0]=rgb; #1000; end
   endtask

   task wait_ticks(input integer n);
      integer i;
      begin
         for(i=0;i<n;i=i+1) @(posedge dut.U1.half_sec_tick);
      end
   endtask

   // --------------------------------------------------------------
   // Test sequence – **key presses are now LONG and visible**
   // --------------------------------------------------------------
   initial begin
      $display("\n=== SNAKE KEY-PRESS DEMO ===\n");
      SW = 0; KEY = 4'b1111;   // everything released

            press_reset;
      #1000;
      if (dut.U1.SNAKE.state !== 0) $error("INIT failed");

      set_color(9'b000_111_000);
      if (dut.U1.SNAKE.color !== 9'b000_111_000) $error("colour failed");

      $display("%0t ns  Letting snake move RIGHT (default)...", $time);
      wait_ticks(4);

      press_up;
      wait_ticks(1);
      if (dut.U1.SNAKE.direction !== 2'b11) $error("UP failed");

      press_down;
      #2000;
      if (dut.U1.SNAKE.direction !== 2'b11) $error("180° allowed!");

      press_left;
      wait_ticks(1);
      if (dut.U1.SNAKE.direction !== 2'b01) $error("LEFT failed");

      press_down;
      wait_ticks(1);
      if (dut.U1.SNAKE.direction !== 2'b10) $error("DOWN failed");

      SW[0] = 1; #1000; SW[0] = 0;
      wait_ticks(1);
      if (dut.U1.SNAKE.direction !== 2'b00) $error("SW[0] failed");

      force dut.U1.SNAKE.body_x[0] = 156;
      wait_ticks(1);
      release dut.U1.SNAKE.body_x[0];
      if (dut.U1.SNAKE.body_x[0] !== 0) $error("wrap-around failed");

      $display("\n=== DEMO FINISHED – CHECK WAVEFORM ===\n");
      #5000 $finish;
   end

   // --------------------------------------------------------------
   // Tick monitor – prints every move
   // --------------------------------------------------------------
   always @(posedge dut.U1.half_sec_tick)
      $display("TICK @%0t | Head(%0d,%0d) Dir=%b State=%0d",
               $time,
               dut.U1.SNAKE.body_x[0], dut.U1.SNAKE.body_y[0],
               dut.U1.SNAKE.direction, dut.U1.SNAKE.state);

   // --------------------------------------------------------------
   // VCD dump for external viewers
   // --------------------------------------------------------------
   initial begin
      $dumpfile("snake_tb.vcd");
      $dumpvars(0,snake_tb);
   end
endmodule