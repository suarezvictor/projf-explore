// Project F: FPGA Graphics - Bounce Verilator C++
// (C)2021 Will Green, open source software released under the MIT License
// Learn more at https://projectf.io

#include <stdio.h>
#include <SDL2/SDL.h>
#include <verilated.h>
#include "Vtop_bounce.h"

// screen dimensions
const int H_RES = 640;
const int V_RES = 480;

typedef struct Pixel {  // for SDL texture
    uint8_t a;  // transparency
    uint8_t b;  // blue
    uint8_t g;  // green
    uint8_t r;  // red
} Pixel;

int main(int argc, char* argv[]) {
    Verilated::commandArgs(argc, argv);

    if(SDL_Init(SDL_INIT_VIDEO) < 0) {
        printf("SDL init failed.\n");
        return 1;
    }

    Pixel screenbuffer[H_RES*V_RES];

    SDL_Window*   sdl_window   = NULL;
    SDL_Renderer* sdl_renderer = NULL;
    SDL_Texture*  sdl_texture  = NULL;

    sdl_window = SDL_CreateWindow("Top Bounce", SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_CENTERED, H_RES, V_RES, SDL_WINDOW_SHOWN);
    if (!sdl_window) {
        printf("Window creation failed: %s\n", SDL_GetError());
        return 1;
    }

    sdl_renderer = SDL_CreateRenderer(sdl_window, -1, SDL_RENDERER_ACCELERATED);
    if (!sdl_renderer) {
        printf("Renderer creation failed: %s\n", SDL_GetError());
        return 1;
    }

    sdl_texture = SDL_CreateTexture(sdl_renderer, SDL_PIXELFORMAT_RGBA8888,
        SDL_TEXTUREACCESS_TARGET, H_RES, V_RES);
    if (!sdl_texture) {
        printf("Texture creation failed: %s\n", SDL_GetError());
        return 1;
    }

    // initialize Verilog module
    Vtop_bounce* top = new Vtop_bounce;

    top->rst = 1;
    top->clk_pix = 0;
    top->eval();
    top->rst = 0;
    top->eval();

    while (1) {
        // check for quit event
        SDL_Event e;
        if (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) {
                break;
            }
        }

        // cycle the clock
        top->clk_pix = 1;
        top->eval();
        top->clk_pix = 0;
        top->eval();

        // update pixel if not in blanking interval
        if (top->de) {
            Pixel* p = &screenbuffer[top->sy*H_RES + top->sx];
            p->a = 0xFF;  // transparency
            p->b = top->sdl_b;
            p->g = top->sdl_g;
            p->r = top->sdl_r;
        }

        // update texture once per frame at start of blanking
        if (top->sy == V_RES && top->sx == 0) {
            SDL_UpdateTexture(sdl_texture, NULL, screenbuffer, H_RES*sizeof(Pixel));
            SDL_RenderClear(sdl_renderer);
            SDL_RenderCopy(sdl_renderer, sdl_texture, NULL, NULL);
            SDL_RenderPresent(sdl_renderer);
        }
    }

    top->final();  // simulation done

    SDL_DestroyTexture(sdl_texture);
    SDL_DestroyRenderer(sdl_renderer);
    SDL_DestroyWindow(sdl_window);
    SDL_Quit();
    return 0;
}