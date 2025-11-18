# wave.do – waveform for snake_tb (DUT = top)

onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {Clock & Reset}
add wave -noupdate -color Yellow   -label CLOCK_50   /snake_tb/CLOCK_50
add wave -noupdate -color Orange   -label Resetn     /snake_tb/dut/KEY[0]

add wave - -noupdate -divider {Inputs}
add wave -noupdate -radix binary -label KEY   /snake_tb/KEY
add wave -noupdate -radix binary -label SW    /snake_tb/SW

add wave -noupdate -divider {Synchronised Controls}
add wave -noupdate -label move_up    /snake_tb/dut/move_up
add wave -noupdate -label move_down  /snake_tb/dut/move_down
add wave -noupdate -label move_left  /snake_tb/dut/move_left
add wave -noupdate -label move_right /snake_tb/dut/move_right

add wave -noupdate -divider {Timing}
add wave -noupdate -color Cyan -label half_sec_tick /snake_tb/dut/half_sec_tick

add wave -noupdate -divider {Snake FSM}
add wave -noupdate -radix unsigned -label state        /snake_tb/dut/U1/SNAKE/state
add wave -noupdate -radix unsigned -label direction    /snake_tb/dut/U1/SNAKE/direction
add wave -noupdate -radix unsigned -label draw_segment /snake_tb/dut/U1/SNAKE/draw_segment

add wave -noupdate -divider {Head (seg 0)}
add wave -noupdate -color Green -radix unsigned -label X[0] /snake_tb/dut/U1/SNAKE/body_x[0]
add wave -noupdate -color Green -radix unsigned -label Y[0] /snake_tb/dut/U1/SNAKE/body_y[0]

add wave -noupdate -divider {Tail (seg 7)}
add wave -noupdate -radix unsigned -label X[7] /snake_tb/dut/U1/SNAKE/body_x[7]
add wave -noupdate -radix unsigned -label Y[7] /snake_tb/dut/U1/SNAKE/body_y[7]

add wave -noupdate -divider {Pixel Drawing}
add wave -noupdate -radix unsigned -label pixel_x /snake_tb/dut/U1/SNAKE/pixel_x
add wave -noupdate -radix unsigned -label pixel_y /snake_tb/dut/U1/SNAKE/pixel_y

add wave -noupdate -divider {Snake to VGA}
add wave -noupdate -color Magenta -label VGA_write /snake_tb/dut/U1/SNAKE/VGA_write
add wave -noupdate -radix unsigned -label VGA_x    /snake_tb/dut/U1/SNAKE/VGA_x
add wave -noupdate -radix unsigned -label VGA_y    /snake_tb/dut/U1/SNAKE/VGA_y
add wave -noupdate -radix hex      -label VGA_color /snake_tb/dut/U1/SNAKE/VGA_color

add wave -noupdate -divider {Plot Interface}
add wave -noupdate -label plot     /snake_tb/plot
add wave -noupdate -radix unsigned -label VGA_X    /snake_tb/VGA_X
add wave -noupdate -radix unsigned -label VGA_Y    /snake_tb/VGA_Y
add wave -noupdate -radix hex      -label VGA_COLOR /snake_tb/VGA_COLOR

add wave -noupdate -divider {LEDs}
add wave -noupdate -radix binary -label LEDR /snake_tb/LEDR

TreeUpdate [SetDefaultTree]
configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
update
WaveRestoreZoom {0 ns} {2 us}