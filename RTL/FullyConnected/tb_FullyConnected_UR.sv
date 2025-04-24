`timescale 1ns/1ps
module tb_FullyConnected_UR;

    // Parameters
    localparam INPUT_SIZE    = 256;     // Number of inputs
    localparam OUTPUT_SIZE   = 10;     // Number of output neurons
    localparam WEIGHTS_WIDTH = 8;       // Bit-width of weights and inputs
    localparam BIAS_WIDTH    = 32;      // Bit-width of bias values
    localparam PARALLEL_MACS = 256; // Only works for 256 (8 adder pipeline)

    // Control signals
    logic clk;
    logic start;
    logic done;

    // Input vector
    logic signed [WEIGHTS_WIDTH-1:0] inputs [INPUT_SIZE-1:0];

    // Weights and bias RAM read interface
    logic w_read_en;
    logic [$clog2(INPUT_SIZE*OUTPUT_SIZE)-1:0] w_read_addr;
    logic signed [4*WEIGHTS_WIDTH-1:0] w_read_data;
    logic b_read_en;
    logic [$clog2(OUTPUT_SIZE)-1:0] b_read_addr;
    logic signed [BIAS_WIDTH-1:0] b_read_data;

    // Output vector
    logic signed [BIAS_WIDTH-1:0] layer_out [OUTPUT_SIZE-1:0];

    // Instantiate the DUT
    FullyConnected_UR #(
        .INPUT_SIZE(INPUT_SIZE),
        .OUTPUT_SIZE(OUTPUT_SIZE),
        .WEIGHTS_WIDTH(WEIGHTS_WIDTH),
        .BIAS_WIDTH(BIAS_WIDTH),
        .PARALLEL_MACS(PARALLEL_MACS)
    ) dut (
        .clk(clk),
        .start(start),
        .done(done),
        .inputs(inputs),
        .w_read_en(w_read_en),
        .w_read_addr(w_read_addr),
        .w_read_data(w_read_data),
        .b_read_en(b_read_en),
        .b_read_addr(b_read_addr),
        .b_read_data(b_read_data),
        .layer_out(layer_out)
    );
    // Map random values to Weights and Bias RAM
    logic signed [WEIGHTS_WIDTH-1:0] weights [OUTPUT_SIZE-1:0][INPUT_SIZE-1:0];
    logic signed [BIAS_WIDTH-1:0] biases [OUTPUT_SIZE-1:0];
    initial begin
        for (int i = 0; i < OUTPUT_SIZE; i++) begin
            for (int j = 0; j < INPUT_SIZE; j++) begin
                weights[i][j] = $urandom_range(-10, 10);
            end
        end

        for (int i = 0; i < OUTPUT_SIZE; i++) begin
            biases[i] = $urandom_range(-10, 10);
        end
    end

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz clock
    end
    
    integer out_idx;
    integer in_idx;

    // Memory read interface
    always_ff @(posedge clk) begin
        if (w_read_en) begin
            out_idx = w_read_addr / INPUT_SIZE;
            in_idx  = w_read_addr % INPUT_SIZE;
            w_read_data <= {weights[out_idx][in_idx],weights[out_idx][in_idx+1],weights[out_idx][in_idx+2],weights[out_idx][in_idx+3]};
        end
        if (b_read_en) begin
            b_read_data <= biases[b_read_addr];
        end
    end

    // Testbench logic
    initial begin
        for (int test_cnt = 0; test_cnt < 3; test_cnt++) begin
            // Initialize inputs
            start = 0;
            done = 0;
    
            // Load inputs
            for (int i = 0; i < INPUT_SIZE; i++) begin
                inputs[i] = $urandom_range(-10, 10);
            end
    
            // Start the DUT
            @(posedge clk);
            start = 1;
            @(posedge clk);
            start = 0;
    
            // Wait for done signal
            wait(done);
    
            // Check output values
            for (int i = 0; i < OUTPUT_SIZE; i++) begin
                int expected = biases[i];  // start with the bias for the current neuron
                // Sum over all inputs for the dot product
                for (int j = 0; j < INPUT_SIZE; j++) begin
                    expected += weights[i][j] * inputs[j];
                end
            
                if (layer_out[i] !== expected) begin
                    $display("Mismatch at index %0d: Expected %0d, Got %0d", i, expected, layer_out[i]);
                end else begin
                    $display("Match at index %0d: %0d", i, layer_out[i]);
                end
            end
            $display("Test %0d finished", test_cnt);
        end
        $finish;
    end
endmodule