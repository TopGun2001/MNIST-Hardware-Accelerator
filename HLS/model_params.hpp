#ifndef MLP_HPP
#define MLP_HPP

#include "hls_stream.h"
#include "ap_axi_sdata.h"

#define INPUT_SIZE 784
#define HIDDEN_SIZE_0 512
#define HIDDEN_SIZE_1 256
#define OUTPUT_SIZE 10
#define WEIGHTS_BIAS_0 (INPUT_SIZE * HIDDEN_SIZE_0 + HIDDEN_SIZE_0)
#define WEIGHTS_BIAS_1 (HIDDEN_SIZE_0 * HIDDEN_SIZE_1 + HIDDEN_SIZE_1)
#define WEIGHTS_BIAS_2 (OUTPUT_SIZE * HIDDEN_SIZE_1 + OUTPUT_SIZE)
#define TOTAL_WEIGHTS_BIAS (WEIGHTS_BIAS_0 + WEIGHTS_BIAS_1 + WEIGHTS_BIAS_2)
/*
 * Define ap_axis data type
 * data: 32 bit data width
 * id: 2 bit used to differentiate streams
 * user: 5 bit custom metadata
 * dest: 6 bit destination of the data
 */
typedef ap_axis<32, 2, 5, 6> axi_stream;
typedef ap_int<8> int8;
typedef ap_int<32> int32;

/*
 * Union to represent different data type in same memory location.
 * Used to intepret int as float or vice versa.
 */
union data {
	int intVal;
	float floatVal;
};

// Scaling factors for quantization (tune these based on calibration)
// Tanh
const float scale_0 = 0.0002452194457873702f / 0.0078125f; // From ONNX file
const float scale_1 = 0.000244140625f / 0.0078125f; // From ONNX file
    
void init_layers(hls::stream<axi_stream> &in_stream);
void read_inputs(hls::stream<axi_stream> &in_stream, int8 input[INPUT_SIZE]);
float tanh_approx(float x);
int8 quantize_tanh(int32 sum, float scale);
int32 inference(int8 input[INPUT_SIZE],
               int8 hidden_1[HIDDEN_SIZE_0],
               int8 hidden_2[HIDDEN_SIZE_1],
               int32 output[OUTPUT_SIZE],
               int8 weights_0[HIDDEN_SIZE_0][INPUT_SIZE],
               int8 weights_1[HIDDEN_SIZE_1][HIDDEN_SIZE_0],
               int8 weights_2[OUTPUT_SIZE][HIDDEN_SIZE_1],
               int32 bias_0[HIDDEN_SIZE_0],
               int32 bias_1[HIDDEN_SIZE_1],
               int32 bias_2[OUTPUT_SIZE],
               float scale_0,
               float scale_1);
void compute_layer0(int8 input[INPUT_SIZE],
                    int8 hidden1[HIDDEN_SIZE_0],
                    int8 w0[HIDDEN_SIZE_0][INPUT_SIZE],
                    int32 b0[HIDDEN_SIZE_0],
                    float scale_0);
void compute_layer1(int8 hidden1[HIDDEN_SIZE_0],
                    int8 hidden2[HIDDEN_SIZE_1],
                    int8 w1[HIDDEN_SIZE_1][HIDDEN_SIZE_0],
                    int32 b1[HIDDEN_SIZE_1],
                    float scale_1);
void compute_layer2(int8 hidden2[HIDDEN_SIZE_1],
                    int32 output[OUTPUT_SIZE],
                    int8 w2[OUTPUT_SIZE][HIDDEN_SIZE_1],
                    int32 b2[OUTPUT_SIZE]);
int32 compute_argmax(int32 output[OUTPUT_SIZE]);
void send_outputs(hls::stream<axi_stream> &out_stream, int32 max_index);
void mnist_quantized(hls::stream<axi_stream> &in_stream, hls::stream<axi_stream> &out_stream);
#endif
