module Tanh #(
    parameter integer INPUT_SIZE    = 512,
    parameter integer OUTPUT_SIZE   = 512,
    parameter integer WEIGHTS_WIDTH = 8,
    parameter integer UNROLL_FACTOR = 8,
    parameter integer BIAS_WIDTH    = 32,
    parameter logic [31:0] SCALER = 32'h3d0090cc // 32b float
)(
    input  logic clk,
    input  logic start,
    output logic done,
    input  logic signed [BIAS_WIDTH-1:0] inputs [INPUT_SIZE-1:0], // 32b integer
    output logic signed [WEIGHTS_WIDTH-1:0] layer_out [OUTPUT_SIZE-1:0] // 8b integer
);
    // Number of chunks for unrolling
    localparam NUM_CHUNKS = INPUT_SIZE / UNROLL_FACTOR;
    // Current chunk index
    logic [$clog2(NUM_CHUNKS)-1:0] chunk_index = 'd0;
  
    logic signed [BIAS_WIDTH-1:0] input_to_tanh_unroll [UNROLL_FACTOR-1:0];
    logic signed [WEIGHTS_WIDTH-1:0] output_from_tanh_unroll [UNROLL_FACTOR-1:0];
    
    logic signed [WEIGHTS_WIDTH-1:0] layer_out_reg [OUTPUT_SIZE-1:0];
    assign layer_out = layer_out_reg;


    always_comb begin
        for (int i = 0; i < UNROLL_FACTOR; i++) begin
            input_to_tanh_unroll[i] = inputs[chunk_index * UNROLL_FACTOR + i];
        end
    end
   
   
    // Array to capture each unroll's done signal
    logic [UNROLL_FACTOR-1:0] unroll_done;

    typedef enum logic [1:0] {
        IDLE = 2'd0,
        RUNNING = 2'd1,
        DONE = 2'd2
    } state_t;

    state_t state = IDLE;
    logic start_chunk = 'b0;
    always_ff @(posedge clk) begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                chunk_index <= 'd0;
                if (start) begin
                    start_chunk <= 1'b1;
                    state <= RUNNING;
                end else begin
                    start_chunk <= 1'b0;
                end
            end
            RUNNING: begin
                start_chunk <= 1'b0;
                if (&unroll_done) begin // Check if all unrolls are done
                    // Write each set to layer out
                    for (int i = 0; i < UNROLL_FACTOR; i++) begin
                        layer_out_reg[chunk_index * UNROLL_FACTOR + i] <= output_from_tanh_unroll[i];
                    end
                    if (chunk_index == NUM_CHUNKS - 1) begin
                        state <= DONE;
                    end else begin
                        chunk_index <= chunk_index + 1;
                        start_chunk <= 1'b1;
                    end
                end
            end
            DONE: begin
                done <= 1'b1;
                state <= IDLE;
            end
        endcase
    end

    // Generate unrolled instances of Tanh
    genvar i;
    generate
    for (i = 0; i < UNROLL_FACTOR; i = i + 1) begin : unroll_array
        Tanh_unroll #(
        .INPUT_SIZE(1),
        .OUTPUT_SIZE(1),
        .WEIGHTS_WIDTH(WEIGHTS_WIDTH),
        .BIAS_WIDTH(BIAS_WIDTH),
        .SCALER(SCALER)
        ) tanh_unroll_inst (
        .clk(clk),
        .start(start_chunk),
        .done(unroll_done[i]),
        .inputs(input_to_tanh_unroll[i]),
        .layer_out(output_from_tanh_unroll[i])
        );
    end
    endgenerate
endmodule