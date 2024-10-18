#include <stdint.h>
#include <stdio.h>
#include "axx_mults_9x9/bw_mult_9_9_4.h"

#define IN_ROW_DIM 17
#define IN_COL_DIM 17
#define IN_CHANNELS 18
#define OUT_CHANNELS 19

#define BATCH_SIZE 2
#define KERNEL_DIM 3
#define PADDING 1
#define STRIDE 2

#define OUT_ROW_DIM ((IN_ROW_DIM + 2*PADDING - KERNEL_DIM) / STRIDE + 1)
#define OUT_COL_DIM ((IN_COL_DIM + 2*PADDING - KERNEL_DIM) / STRIDE + 1)
#define PATCH_SIZE (KERNEL_DIM * KERNEL_DIM * IN_CHANNELS)
#define N_PATCHES (BATCH_SIZE * OUT_ROW_DIM * OUT_COL_DIM)

static unsigned long int next = 1;
int myrand(void) {
    next = next * 1103515245 + 12345;
    return (unsigned int)(next/65536) % 32768;
}
void mysrand(unsigned int seed)
{
    next = seed;
}

void conv(int batch_size, int in_channels,
        int in_row_dim, int in_col_dim,
        int out_channels, int kernel_dim,
        int out_row_dim, int out_col_dim,
        int stride, int padding,
        int8_t input[batch_size][in_row_dim][in_col_dim][in_channels],
        int8_t weights[out_channels][kernel_dim][kernel_dim][in_channels],
        int32_t bias[out_channels],
        int8_t output[batch_size][out_row_dim][out_col_dim][out_channels]) {
        int16_t index1, index2;

        const int8_t elem_t_max = 127;
        const int8_t elem_t_min = -128;

        for (int b = 0; b < batch_size; b++) {
            for (int orow = 0; orow < out_row_dim; orow++) {
                for (int ocol = 0; ocol < out_col_dim; ocol++) {
                    for (int och = 0; och < out_channels; och++) {
                        int32_t result = bias[och];

                        for (int krow = 0; krow < kernel_dim; krow++) {
                            for (int kcol = 0; kcol < kernel_dim; kcol++) {
                                for (int kch = 0; kch < in_channels; kch++) {
                                    int irow = orow * stride + krow - padding;
                                    int icol = ocol * stride + kcol - padding;

                                    int8_t pixel = irow < 0 || irow >= in_row_dim || icol < 0 || icol >= in_col_dim ? 0 : input[b][irow][icol][kch];
                                    //result += weights[och][krow][kcol][kch] * pixel;
                                    
                                    if (weights[och][krow][kcol][kch] < 0) {
                                        index1 = weights[och][krow][kcol][kch] + 512;
                                    } else {
                                        index1 = weights[och][krow][kcol][kch];
                                    }

                                    if (pixel < 0) {
                                        index2 = pixel + 512;
                                    } else {
                                        index2 = pixel;
                                    }
                                    
                                    result += lut[index1][index2];
                                    // printf("lut[%d][%d] = %d\n", weights[och][krow][kcol][kch], pixel, lut[index1][index2]);
                                    // printf("lut[%d][%d] = %d\n", index1, index2, lut[index1][index2]);
                                    // printf("\n");
                                }
                            }
                        }

                        // Clip result
                        result = result > elem_t_max ? elem_t_max : (result < elem_t_min ? elem_t_min : result);

                        output[b][orow][ocol][och] = result;
                    }
                }
            }
        }
}

void init_pseudo_random(int8_t * buf, int len) {
    int8_t i = 0;
    for (int8_t * ptr = buf; ptr < buf + len; ptr++) {
        *ptr = (myrand() % 5) - 2;
    }
}

void init_pseudo_random_acc(int32_t * buf, int len) {
    int8_t i = 0;
    for (int32_t * ptr = buf; ptr < buf + len; ptr++) {
        *ptr = (myrand() % 5) - 2;
    }
}

int main() {

    static int8_t input[BATCH_SIZE][IN_ROW_DIM][IN_COL_DIM][IN_CHANNELS];
    static int8_t weights[OUT_CHANNELS][KERNEL_DIM][KERNEL_DIM][IN_CHANNELS];
    static int32_t bias[OUT_CHANNELS];
    static int8_t output[BATCH_SIZE][OUT_ROW_DIM][OUT_COL_DIM][OUT_CHANNELS];

    mysrand(3);
    init_pseudo_random(&input[0][0][0][0], sizeof(input) / sizeof(int8_t));
    init_pseudo_random(&weights[0][0][0][0], sizeof(weights) / sizeof(int8_t));
    init_pseudo_random_acc(&bias[0], sizeof(bias) / sizeof(int32_t));

    conv(BATCH_SIZE, IN_CHANNELS,
        IN_ROW_DIM, IN_COL_DIM,
        OUT_CHANNELS, KERNEL_DIM,
        OUT_ROW_DIM, OUT_COL_DIM,
        STRIDE, PADDING,
        input,
        weights,
        bias,
        output);
;

    printf("output_mat:\n");
            for (int batch = 0; batch < BATCH_SIZE; batch++) {
                for (int orow = 0; orow < OUT_ROW_DIM; orow++) {
                    for (int ocol = 0; ocol < OUT_COL_DIM; ocol++) {
                        printf("[");
                        for (int och = 0; och < OUT_CHANNELS; och++) {
                            if (och == OUT_CHANNELS - 1){
                                printf("%d", output[batch][orow][ocol][och]);
                            } else {
                                printf("%d,", output[batch][orow][ocol][och]);
                            }
                            
                        }
                        printf("]\n");
                    }
                }
            }
            printf("\n");

    return 0;
}