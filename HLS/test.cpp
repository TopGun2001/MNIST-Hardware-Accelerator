#include <iostream>
#include <cmath>

#include "model_params.hpp"
#include "test_data.hpp"

typedef ap_axis<32, 2, 5, 6> axi_stream;

bool is_equal(int a, int b) {
    return (a - b) == 0;
}

int main() {
    int model_output[test_length];  // Store outputs
    bool all_tests_passed = true;
    int count = 0;

    hls::stream<axi_stream> in_stream;
    hls::stream<axi_stream> out_stream;

    // Single loop for both weight loading and inference
    for (int i = 0; i < test_length + 1; i++) {
        if (i == 0) {
            // First iteration: Load weights and biases
            for (int k = 0; k < length; k++) {
                axi_stream val;
                val.data = weights_and_bias[k];
                val.last = (k == length - 1) ? 1 : 0;
                in_stream.write(val);
            }
        } else {
            // Subsequent iterations: Load test input
            for (int j = 0; j < INPUT_SIZE; j++) {
                axi_stream val;
                val.data = *((int*)&test_data[i - 1][j]);  // i-1 since test data starts after weights
                val.last = (j == INPUT_SIZE - 1) ? 1 : 0;
                in_stream.write(val);
            }
        }

        // Run function
        mnist_quantized(in_stream, out_stream);

        // If doing inference, check output
        if (i > 0) {
            axi_stream val = out_stream.read();
            model_output[i-1] = val.data;
            if (is_equal(test_labels[i-1], model_output[i-1])) {
                count += 1;
            }
        }
    }
    float accuracy = count * 1.0 / test_length * 100;
    std::cout << "Accuracy = " << accuracy << std::endl;
}
