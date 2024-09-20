#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>

#define BOARD_WIDTH 64
#define BOARD_HEIGHT 64

typedef unsigned char ubyte;

// External function declaration from hasitha.cu
extern void run_simulation(int boardW, int boardH, int ngenerations);

// Function prototypes
void randomizeBoard(ubyte* board, int nrows, int ncols, float probability);
void initializeMPI(int* argc, char*** argv, int* rank, int* size);
void finalizeMPI();

// Main MPI function
int main(int argc, char* argv[]) {
    int rank, size;
    int ngenerations;

    initializeMPI(&argc, &argv, &rank, &size);

    if (rank == 0) {
        printf("Enter the number of generations: ");
        fflush(stdout); // Ensure output is printed immediately
        if (scanf("%d", &ngenerations) != 1) {
            printf("Failed to read the number of generations. Exiting.\n");
            finalizeMPI();
            return 1;
        }
        // Check for valid input
        if (ngenerations <= 0) {
            printf("Invalid number of generations. Exiting.\n");
            finalizeMPI();
            return 1;
        }
        
        // Run simulation
        run_simulation(BOARD_WIDTH, BOARD_HEIGHT, ngenerations);
    }


    finalizeMPI();
    return 0;
}

void initializeMPI(int* argc, char*** argv, int* rank, int* size) {
    MPI_Init(argc, argv);
    MPI_Comm_rank(MPI_COMM_WORLD, rank);
    MPI_Comm_size(MPI_COMM_WORLD, size);
}

void finalizeMPI() {
    MPI_Finalize();
}

// Implement the randomizeBoard function if needed
void randomizeBoard(ubyte* pboard, int nrows, int ncols, float probability) {
    for (int x = 0; x < ncols; x++) {
        for (int y = 0; y < nrows; y++) {
            float rnd = rand() / (float)RAND_MAX;
            pboard[x * nrows + y] = (rnd >= probability) ? 0x1 : 0x0;
        }
    }
}
