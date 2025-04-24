`timescale 1ns / 1ps
module FullyConnected #(
    parameter INPUT_SIZE    = 784,     // Number of inputs
    parameter OUTPUT_SIZE   = 512,     // Number of output neurons
    parameter WEIGHTS_WIDTH = 8,       // Bit-width of weights and inputs
    parameter BIAS_WIDTH    = 32       // Bit-width of bias values
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
    input  logic signed [WEIGHTS_WIDTH-1:0] w_read_data,

    // Bias RAM read interface
    output logic b_read_en,
    output logic [$clog2(OUTPUT_SIZE)-1:0] b_read_addr,
    input  logic signed [BIAS_WIDTH-1:0] b_read_data,

    // Output vector
    output logic signed [BIAS_WIDTH-1:0] layer_out [OUTPUT_SIZE-1:0]
);

    // Internal signals and registers
    logic signed [BIAS_WIDTH-1:0] bias = 'd0;
    logic signed [WEIGHTS_WIDTH-1:0] weights [INPUT_SIZE-1:0];
    
    // Dot product result register
    logic [$clog2(INPUT_SIZE):0] mac_counter = 'd0;
    logic signed [BIAS_WIDTH-1:0] mac_result = 'd0;

    // Counters for nodes and weights indices
    integer node_idx = 'd0;
    integer weight_idx = 'd0;
    
    // We do unrolling for but only for 1 neuron in the hidden layer at 1 time.
    logic signed [BIAS_WIDTH-1:0] LU_Result [INPUT_SIZE-1:0];

    genvar idx;
    integer x;
    
	// Generate for loop to instantiate N times
	generate
		for (idx = 0; idx < INPUT_SIZE; idx = idx + 1) begin
          LayerUnroll LU (weights[idx], inputs[idx], LU_Result[idx]);
		end
	endgenerate
    
    always_comb begin
        layer_out[node_idx] = bias;
        for (x = 0; x < INPUT_SIZE; x = x + 1) begin
            layer_out[node_idx] = layer_out[node_idx] + LU_Result[x];
        end
    end
    
    // State Machine States
    typedef enum logic [4:0] {
        IDLE            = 5'd0,
        READ_WEIGHTS    = 5'd1,
        PENDING_WEIGHTS = 5'd2,
        RECV_WEIGHTS = 5'd3,
        READ_BIAS    = 5'd4,
        PENDING_BIAS = 5'd5,
        RECV_BIAS   = 5'd6,
        COMPUTE     = 5'd7,
        DONE_STATE  = 5'd8
    } state_t;

    state_t state = IDLE;
    // Synchronous state machine
    always_ff @(posedge clk) begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                w_read_en <= 1'b0;
                b_read_en <= 1'b0;
                mac_result <= 32'b0;
                mac_counter <= 'b0;
                if(start) begin
                    node_idx   <= 0;
                    weight_idx <= 0;
                    // Begin loading weights for the first node
                    state      <= READ_WEIGHTS;
                end
            end
            READ_WEIGHTS: begin
                // Reset MAC counter/result
                mac_result <= 32'b0;
                mac_counter <= 'b0;
                // Enable weights RAM reading
                w_read_en <= 1'b1;
                w_read_addr <= node_idx * INPUT_SIZE + weight_idx;
                state <= PENDING_WEIGHTS;
            end
            PENDING_WEIGHTS: begin
                state <= RECV_WEIGHTS;
            end
            RECV_WEIGHTS: begin
                // Assume that w_read_data is valid in this cycle.
                weights[weight_idx] <= w_read_data;
                if (weight_idx == INPUT_SIZE - 1) begin
                    w_read_en <= 1'b0;
                    weight_idx <= 0;
                    state      <= READ_BIAS;
                end else begin
                    weight_idx <= weight_idx + 1;
                    state <= READ_WEIGHTS;
                end
            end
            READ_BIAS: begin
                // Enable bias RAM read
                b_read_en <= 1'b1;
                // Address bias using the current node index
                b_read_addr <= node_idx;
                state <= PENDING_BIAS;
            end
            PENDING_BIAS: begin
                state <= RECV_BIAS;
            end
            RECV_BIAS: begin
                // Assume that b_read_data is valid in this cycle.
                bias <= b_read_data;
                b_read_en <= 1'b0;
                state <= COMPUTE;
            end
            COMPUTE: begin
                if (node_idx == OUTPUT_SIZE - 1) begin
                    mac_result <= 32'b0;
                    mac_counter <= 'b0;
                    state <= DONE_STATE;
                end 
                else begin
                    node_idx <= node_idx + 1;
                    state <= READ_WEIGHTS;
                end
            end
            DONE_STATE: begin
                done <= 1'b1;
                mac_result <= 32'b0;
                mac_counter <= 'b0;
                node_idx   <= 'b0;
                weight_idx <= 'b0;
                // Optionally return to IDLE or hold the DONE state until reset.
                state <= IDLE;
            end
            default: state <= IDLE;
        endcase
    end
endmodule
