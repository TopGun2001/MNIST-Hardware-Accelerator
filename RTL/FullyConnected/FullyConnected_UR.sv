`timescale 1ns / 1ps
module FullyConnected_UR #(
    parameter INPUT_SIZE    = 512,     // Number of inputs
    parameter OUTPUT_SIZE   = 256,     // Number of output neurons
    parameter WEIGHTS_WIDTH = 8,       // Bit-width of weights and inputs
    parameter BURST_LEN = 4,
    parameter BIAS_WIDTH    = 32,      // Bit-width of bias values
    parameter PARALLEL_MACS = 256       // Number of parallel MAC operations
)(
    // Clock and control signals
    input  logic clk,
    input  logic start,
    output logic done, 

    // Input vector
    input  logic signed [WEIGHTS_WIDTH-1:0] inputs [INPUT_SIZE-1:0],

    // Weights RAM read interface
    output logic w_read_en,
    output logic [$clog2(INPUT_SIZE*OUTPUT_SIZE)-1:0] w_read_addr,
    input  logic signed [BURST_LEN*WEIGHTS_WIDTH-1:0] w_read_data,

    // Bias RAM read interface
    output logic b_read_en,
    output logic [$clog2(OUTPUT_SIZE)-1:0] b_read_addr,
    input  logic signed [BIAS_WIDTH-1:0] b_read_data,

    // Output vector
    output logic signed [BIAS_WIDTH-1:0] layer_out [OUTPUT_SIZE-1:0]
);

    // Bias and weights
    logic signed [BIAS_WIDTH-1:0] bias = 'd0;
    logic signed [WEIGHTS_WIDTH-1:0] weight_buffer [INPUT_SIZE-1:0];
    
    // Weights unpacking (currently 4 sets of 8 = 32 bits)
    logic signed [WEIGHTS_WIDTH-1:0] w_read_data_array [0:BURST_LEN-1];
    
    // MAC control signals
    logic [$clog2(INPUT_SIZE/PARALLEL_MACS)+1:0] mac_iteration = 'd0;
    logic signed [BIAS_WIDTH-1:0] mac_result = 'd0;

    // Counters for nodes and weight addresses
    integer node_idx = 'd0;
    integer weight_base_idx = 'd0;
    
    // Number of iterations needed for processing one node's input vector
    localparam MAC_ITERATIONS = (INPUT_SIZE + PARALLEL_MACS - 1) / PARALLEL_MACS;

    // Pipeline delay constant for the adder tree
    localparam PIPE_DELAY = 4;
    logic [$clog2(PIPE_DELAY+1)-1:0] pipe_wait_cnt = 'd0;

    typedef enum logic [4:0] {
        IDLE            = 5'd0,
        LOAD_WEIGHTS    = 5'd1,
        PENDING_WEIGHTS = 5'd2,
        STORE_WEIGHTS   = 5'd3,
        LOAD_BIAS       = 5'd4,
        PENDING_BIAS    = 5'd5,
        COMPUTE_SETUP   = 5'd6,
        COMPUTE         = 5'd7,
        WAIT_PIPELINE   = 5'd8,
        ACCUMULATE_UPDATE = 5'd9,
        FINISH_NODE     = 5'd10,
        DONE_STATE      = 5'd11
    } state_t;

    state_t state = IDLE;

    // Compute the multiplications for the current iteration in parallel.
    logic signed [BIAS_WIDTH-1:0] mult_results [0:PARALLEL_MACS-1];
    generate
        for (genvar i = 0; i < PARALLEL_MACS; i++) begin : mult_gen
            assign mult_results[i] = ((mac_iteration * PARALLEL_MACS + i) < INPUT_SIZE) ?
                                     (inputs[mac_iteration * PARALLEL_MACS + i] * weight_buffer[mac_iteration * PARALLEL_MACS + i]) : 0;
        end
    endgenerate

    // 4-by-4 Adder Tree: 256 -> 64 -> 16 -> 4 -> 1
    logic signed [BIAS_WIDTH-1:0] sum_stage1 [0:(PARALLEL_MACS/4)-1];
    always_ff @(posedge clk) begin
        for (int i = 0; i < PARALLEL_MACS/4; i++) begin
            sum_stage1[i] <= mult_results[4*i] + mult_results[4*i+1] +
                             mult_results[4*i+2] + mult_results[4*i+3];
        end
    end

    logic signed [BIAS_WIDTH-1:0] sum_stage2 [0:(PARALLEL_MACS/16)-1];
    always_ff @(posedge clk) begin
        for (int i = 0; i < PARALLEL_MACS/16; i++) begin
            sum_stage2[i] <= sum_stage1[4*i] + sum_stage1[4*i+1] +
                             sum_stage1[4*i+2] + sum_stage1[4*i+3];
        end
    end

    logic signed [BIAS_WIDTH-1:0] sum_stage3 [0:(PARALLEL_MACS/64)-1];
    always_ff @(posedge clk) begin
        for (int i = 0; i < PARALLEL_MACS/64; i++) begin
            sum_stage3[i] <= sum_stage2[4*i] + sum_stage2[4*i+1] +
                             sum_stage2[4*i+2] + sum_stage2[4*i+3];
        end
    end

    logic signed [BIAS_WIDTH-1:0] final_sum;
    always_ff @(posedge clk) begin
        final_sum <= sum_stage3[0] + sum_stage3[1] +
                     sum_stage3[2] + sum_stage3[3];
    end

    always_ff @(posedge clk) begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                w_read_en <= 1'b0;
                b_read_en <= 1'b0;
                mac_result <= 'd0;
                mac_iteration <= 'd0;
                pipe_wait_cnt <= 'd0;
                if(start) begin
                    node_idx <= 0;
                    weight_base_idx <= 0;
                    state <= LOAD_WEIGHTS;
                end
            end
            LOAD_WEIGHTS: begin
                w_read_en <= 1'b1;
                w_read_addr <= (node_idx * INPUT_SIZE + weight_base_idx);
                state <= PENDING_WEIGHTS;
            end
            PENDING_WEIGHTS: begin
                state <= STORE_WEIGHTS;
            end
            STORE_WEIGHTS: begin
                weight_buffer[weight_base_idx + 0] <= w_read_data[3*WEIGHTS_WIDTH +: WEIGHTS_WIDTH];
                weight_buffer[weight_base_idx + 1] <= w_read_data[2*WEIGHTS_WIDTH +: WEIGHTS_WIDTH];
                weight_buffer[weight_base_idx + 2] <= w_read_data[1*WEIGHTS_WIDTH +: WEIGHTS_WIDTH];
                weight_buffer[weight_base_idx + 3] <= w_read_data[0*WEIGHTS_WIDTH +: WEIGHTS_WIDTH];

                if (weight_base_idx + 4 >= INPUT_SIZE) begin
                    w_read_en <= 1'b0;
                    weight_base_idx <= 0;
                    state <= LOAD_BIAS;
                end else begin
                    weight_base_idx <= weight_base_idx + 4;
                    state <= LOAD_WEIGHTS;
                end
            end
            LOAD_BIAS: begin
                b_read_en <= 1'b1;
                b_read_addr <= node_idx;
                state <= PENDING_BIAS;
            end
            PENDING_BIAS: begin
                state <= COMPUTE_SETUP;
            end
            COMPUTE_SETUP: begin
                bias <= b_read_data;
                b_read_en <= 1'b0;
                mac_result <= 'd0;
                mac_iteration <= 'd0;
                pipe_wait_cnt <= 'd0;
                state <= COMPUTE;
            end
            COMPUTE: begin
                // Immediately move to waiting for the adder tree pipeline to settle
                pipe_wait_cnt <= 'd0;  // reset wait counter
                state <= WAIT_PIPELINE;
            end
            WAIT_PIPELINE: begin
                // Wait for PIPE_DELAY cycles to let the pipelined adder tree produce final_sum
                if (pipe_wait_cnt < PIPE_DELAY-1)
                    pipe_wait_cnt <= pipe_wait_cnt + 1;
                else
                    state <= ACCUMULATE_UPDATE;
            end
            ACCUMULATE_UPDATE: begin
                // Update mac_result with the pipelined adder tree output.
                mac_result <= mac_result + final_sum;
                if (mac_iteration == MAC_ITERATIONS - 1)
                    state <= FINISH_NODE;
                else begin
                    mac_iteration <= mac_iteration + 1;
                    state <= COMPUTE;  // start next iteration
                end
            end
            FINISH_NODE: begin
                // Final result for this node is mac_result + bias.
                layer_out[node_idx] <= mac_result + bias;
                if (node_idx == OUTPUT_SIZE - 1)
                    state <= DONE_STATE;
                else begin
                    node_idx <= node_idx + 1;
                    weight_base_idx <= 0;
                    mac_result <= 'd0;
                    mac_iteration <= 'd0;
                    state <= LOAD_WEIGHTS;
                end
            end
            DONE_STATE: begin
                done <= 1'b1;
                mac_result <= 'd0;
                node_idx <= 'd0;
                weight_base_idx <= 'd0;
                mac_iteration <= 'd0;
                state <= IDLE;
            end
            default: state <= IDLE;
        endcase
    end

endmodule
