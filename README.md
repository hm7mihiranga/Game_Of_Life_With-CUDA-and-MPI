# Game_Of_Life_With-CUDA-and-MPI
The "Game of Life" is a cellular automaton devised by John Conway, consisting of a grid of cells that evolve over discrete time steps based on a set of rules. Each cell can be either alive or dead, and the state of the grid evolves according to these rules:

1) Birth: A dead cell becomes alive if it has exactly three live neighbors.
2) Survival: A live cell remains alive if it has two or three live neighbors.
3) Death by Overpopulation: A live cell dies if it has more than three live neighbors.
4) Death by Isolation: A live cell dies if it has fewer than two live neighbors.
   
These simple rules lead to complex and often unpredictable patterns, making the Game of Life a classic example of emergent behavior in mathematical systems.

As a Example of Preview :
![Teaser Animation](src/game_of_life.gif)
