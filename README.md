# ece241project-snake
Snake game project from ECE241

update: 2025-11-26

How to load on DE1-SoC:
- open Quartus file (.qpf)
- the project should be compiled but if not, press the compile button (green triangle)
- make sure DE1-SoC is plugged in to the computer, and the PS/2 Keyboard & VGA Monitor are connected to the board.
- press tools -> programmer -> start

To play:

- Press KEY[0] to start
- Use arrow keys on PS/2 Keyboard to move snake
- As the snake eats the food, the speed will increase
- You lose when the snake hits itself or the walls
- Use SW[8:0] to customize the colors of the snake (9-bit color)
