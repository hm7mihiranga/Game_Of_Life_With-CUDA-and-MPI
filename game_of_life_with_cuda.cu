#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <unistd.h>
#include <SDL2/SDL.h>

#define BLOCK_SIDE 16
#define WINDOW_WIDTH 640
#define WINDOW_HEIGHT 640

typedef unsigned char ubyte;

// CUDA device functions
__device__ ubyte getat(ubyte* pboard, int nrows, int ncols, int x, int y) {
    if (x >= 0 && x < ncols && y >= 0 && y < nrows)
        return pboard[x * nrows + y];
    return 0x0;
}

__device__ int numneighbors(int x, int y, ubyte* pboard, int nrows, int ncols) {
    int num = 0;
    num += (getat(pboard, nrows, ncols, x-1, y));
    num += (getat(pboard, nrows, ncols, x+1, y));
    num += (getat(pboard, nrows, ncols, x, y-1));
    num += (getat(pboard, nrows, ncols, x, y+1));
    num += (getat(pboard, nrows, ncols, x-1, y-1));
    num += (getat(pboard, nrows, ncols, x-1, y+1));
    num += (getat(pboard, nrows, ncols, x+1, y-1));
    num += (getat(pboard, nrows, ncols, x+1, y+1));
    
    return num;
}

__global__ void simstep(int nrows, int ncols, ubyte* pCurrBoard, ubyte* pNewBoard) {
    int x = blockIdx.x * BLOCK_SIDE + threadIdx.x;
    int y = blockIdx.y * BLOCK_SIDE + threadIdx.y;

    if (x < ncols && y < nrows) {
        int indx = x * nrows + y;
        pNewBoard[indx] = pCurrBoard[indx];

        int neighbors = numneighbors(x, y, pCurrBoard, nrows, ncols);

        // Apply game rules:
        if (neighbors < 2)
            pNewBoard[indx] = 0x0;
        else if (neighbors > 3)
            pNewBoard[indx] = 0x0;
        else if (neighbors == 3 && !pCurrBoard[indx])
            pNewBoard[indx] = 0x1;
    }
}

// Function to initialize the random board state
void randomizeBoard(ubyte* pboard, int nrows, int ncols, float probability) {
    for (int x = 0; x < ncols; x++) {
        for (int y = 0; y < nrows; y++) {
            float rnd = rand() / (float)RAND_MAX;
            pboard[x * nrows + y] = (rnd >= probability) ? 0x1 : 0x0;
        }
    }
}

// Function to draw the board using SDL
void drawBoard(SDL_Renderer* renderer, ubyte* pboard, int nrows, int ncols) {
    int cellSize = WINDOW_WIDTH / ncols;
    for (int x = 0; x < ncols; x++) {
        for (int y = 0; y < nrows; y++) {
            SDL_Rect cellRect = { x * cellSize, y * cellSize, cellSize, cellSize };
            SDL_SetRenderDrawColor(renderer, pboard[x * nrows + y] * 255, pboard[x * nrows + y] * 255, 0, 255);
            SDL_RenderFillRect(renderer, &cellRect);
        }
    }
}

// Function to toggle the state of a cell
void toggleCell(ubyte* pboard, int nrows, int x, int y) {
    int index = x * nrows + y;
    pboard[index] = (pboard[index] == 0x1) ? 0x0 : 0x1;
}

// Main simulation function to be called from MPI code
extern "C" void run_simulation(int boardW, int boardH, int ngenerations) {
    srand(time(0));
    ubyte* pboard = (ubyte*)malloc(boardW * boardH * sizeof(ubyte));
    randomizeBoard(pboard, boardH, boardW, 0.7f);

    SDL_Init(SDL_INIT_VIDEO);
    SDL_Window* window = SDL_CreateWindow("Game of Life", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, WINDOW_WIDTH, WINDOW_HEIGHT, SDL_WINDOW_SHOWN);
    SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

    ubyte* pDevBoard0;
    cudaMalloc((void**)&pDevBoard0, boardW * boardH * sizeof(ubyte));
    cudaMemcpy(pDevBoard0, pboard, boardH * boardW * sizeof(ubyte), cudaMemcpyHostToDevice);

    ubyte* pDevBoard1;
    cudaMalloc((void**)&pDevBoard1, boardW * boardH * sizeof(ubyte));
    cudaMemset(pDevBoard1, 0x0, boardH * boardW * sizeof(ubyte));

    dim3 blocksize(BLOCK_SIDE, BLOCK_SIDE);
    dim3 gridsize((boardW + BLOCK_SIDE - 1) / BLOCK_SIDE, (boardH + BLOCK_SIDE - 1) / BLOCK_SIDE);

    struct timeval ti;
    gettimeofday(&ti, NULL);

    ubyte* pcurr;
    ubyte* pnext;
    bool running = true;
    SDL_Event event;
    bool quit = false;

    int gen = 0;

    while (!quit) {
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) {
                quit = true;
            }
        }

        if (gen < ngenerations) {
            pcurr = (gen % 2 == 0) ? pDevBoard0 : pDevBoard1;
            pnext = (gen % 2 == 0) ? pDevBoard1 : pDevBoard0;

            simstep<<<gridsize, blocksize>>>(boardH, boardW, pcurr, pnext);
            cudaDeviceSynchronize();

            cudaMemcpy(pboard, pnext, boardH * boardW * sizeof(ubyte), cudaMemcpyDeviceToHost);
            SDL_RenderClear(renderer);
            drawBoard(renderer, pboard, boardH, boardW);
            SDL_RenderPresent(renderer);

            gen++;
        } else {
            quit = true;
        }
    }

    cudaMemcpy(pboard, pcurr, boardW * boardH * sizeof(ubyte), cudaMemcpyDeviceToHost);

    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    cudaFree(pDevBoard0);
    cudaFree(pDevBoard1);
    free(pboard);

    struct timeval tf;
    gettimeofday(&tf, NULL);
    double t = ((tf.tv_sec - ti.tv_sec) * 1000.0) + ((tf.tv_usec - ti.tv_usec) / 1000.0);
    printf("Simulation completed in %f ms\n", t);
}
