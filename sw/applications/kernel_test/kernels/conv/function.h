// Adapted from https://github.com/pulp-platform/pulpino/tree/master/sw/apps/sequential_tests/convolution
// Restored to original 3x3 configuration that matches CGRA bitstream
#include <stdint.h>

#define DATA_WIDTH  14
#define IMG_ROW     3
#define IMG_COL     3
#define IMG_DIM     IMG_ROW*IMG_COL

#define FILT_WIN    3
#define FILT_DIM    FILT_WIN*FILT_WIN

#define FILT_HALF   FILT_WIN/2

typedef int16_t    Filtc;
typedef int16_t    Pixel;

// Filter coefficient - must match CGRA bitstream
// Note: Original bitstream appears to use coeff=1, not 2 as documented
#define FILTER_COEFF 1

// Input image: 3x3 = 9 pixels
static Pixel In_Img[IMG_DIM] = { 1, 2, 3, 4, 5, 6, 7, 8, 9 };

// Filter kernel - auto-generated with uniform coefficient
static Filtc Filter_Kern[FILT_DIM] = {
    [0 ... FILT_DIM-1] = FILTER_COEFF
};

void conv2D(Pixel *Out_Img)
{
    int32_t r, c, k, i, j, w, t;
    Filtc coeff;
    Pixel data;
    int32_t S;

    // Image border is not processed (would require padding)
    for (r = FILT_HALF; r < IMG_ROW - FILT_HALF; r++) {
        for (c = FILT_HALF; c < IMG_COL - FILT_HALF; c++) {

            S = 0;
            // Output index: convert 2D (r,c) to 1D linear index
            t = r * IMG_COL + c;

            // Move in the filter window
            /* Coordinate window for 3x3 filter:
                (-1;-1) (-1; 0) (-1;+1)
                ( 0;-1) ( 0; 0) ( 0;+1)
                (+1;-1) (+1; 0) (+1;+1)
            */
            for (i = -FILT_HALF; i <= FILT_HALF; i++) {
                for (j = -FILT_HALF; j <= FILT_HALF; j++) {

                    // Input index: pixel at (r+i, c+j)
                    k = (r + i) * IMG_COL + (c + j);
                    data = In_Img[k];

                    // Filter coefficient index
                    w = (i + FILT_HALF) * FILT_WIN + (j + FILT_HALF);
                    coeff = Filter_Kern[w];

                    S += (int32_t)(coeff * data);
                }
            }

            Out_Img[t] = S;
        }
    }
}
