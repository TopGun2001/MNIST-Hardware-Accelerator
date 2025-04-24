module Tanh #(
    parameter integer INPUT_SIZE    = 512,
    parameter integer OUTPUT_SIZE   = 512,
    parameter integer WEIGHTS_WIDTH = 8,
    parameter integer BIAS_WIDTH    = 32,
    parameter logic [31:0] SCALER = 32'h3d0090cc // 32b float
)(
    input  logic clk,
    input  logic start,
    output logic done,
    input  logic signed [BIAS_WIDTH-1:0] inputs [INPUT_SIZE-1:0], // 32b integer
    output logic signed [WEIGHTS_WIDTH-1:0] layer_out [OUTPUT_SIZE-1:0] // 8b integer
);  
    // counter
    logic [$clog2(INPUT_SIZE)-1:0] input_counter = 'd0;
    logic unroll_done [0:OUTPUT_SIZE -1];
    logic start_unroll [0:OUTPUT_SIZE -1];
    logic ALL_DONE = 1'd1;

    integer i,j;
    genvar idx;
    
    // Unroll for each of OUTPUT_SIZE neuron
    generate
        for (idx = 0; idx < OUTPUT_SIZE; idx = idx + 1) begin
                TanhUnroll #( 
                        .INPUT_SIZE(INPUT_SIZE),
                        .OUTPUT_SIZE(OUTPUT_SIZE),
                        .WEIGHTS_WIDTH(WEIGHTS_WIDTH),
                        .BIAS_WIDTH(BIAS_WIDTH),
                        .SCALER(SCALER)
                   ) tanhUnroll (
                        .clk(clk),
                        .done(unroll_done[idx]),
                        .start(start_unroll[idx]),
                        .inputs(inputs[idx]),
                        .layer_out(layer_out[idx])
                   );                      
        end
    endgenerate
    
    
    // State Machine States
    typedef enum logic [4:0] {
        IDLE = 5'd0,
        START_UNROLL = 5'd1,
        UNROLL_DONE = 5'd2
    } state_t;

    state_t state = IDLE; // Initial state
    
    
    always_ff @(posedge clk) begin
        
        case(state)
            
            IDLE: 
            begin 
                done  <= 1'b0;    
                for (j = 0; j < OUTPUT_SIZE; j = j + 1) begin
                    start_unroll[j] <= 1'b0;                   
                end
                
                for (j = 0; j < OUTPUT_SIZE; j = j + 1) begin
                    unroll_done[j] <= 1'b0;                   
                end
                if(start) state <= START_UNROLL;
            end
            
            START_UNROLL: 
            begin
                for (j = 0; j < OUTPUT_SIZE; j = j + 1) begin
                    start_unroll[j] <= 1'b1;              
                end
                state <= UNROLL_DONE;          
            end
            
            UNROLL_DONE: 
            begin        
                for (j = 0; j < OUTPUT_SIZE; j = j + 1) begin
                    if (unroll_done[j] && ALL_DONE) begin
                        ALL_DONE <= 1'b1;
                    end  
                    else begin
                        ALL_DONE <= 1'b0;   // no point checking if even 1 tanh unroll is yet to finish
                        break;
                    end
                end

                if (ALL_DONE) begin       // all tanh unrolling finished, can send out data.
                    done <= 1'b1;
                    state <= IDLE;
                end
            end
               
        endcase
    
    end
    
endmodule
