module OutputLayer #(
    parameter int OUTPUT_SIZE = 10,   // Number of outputs
    parameter int OUTPUT_WIDTH = 32   // Bit-width of each output
)(
    input logic clk,
    input logic start,
    output logic done,
    
    // Inputs
    input logic signed [OUTPUT_WIDTH-1:0] inputs [OUTPUT_SIZE-1:0],
    
    // Output to array
    output logic outputs_write_en,
    output logic [$clog2(OUTPUT_SIZE)-1:0] outputs_write_address,
    output logic [OUTPUT_WIDTH-1:0] outputs_write_data
);

    // State Machine States
    typedef enum logic [1:0] {
        IDLE = 2'd0,
        WRITE = 2'd1,
        DONE = 2'd2
    } state_t;

    state_t state = IDLE; // Initial state
    
    logic [$clog2(OUTPUT_SIZE)-1:0] outputs_write_counter = 'd0;

    always_ff @(posedge clk) begin
        case (state)
            IDLE: begin
                outputs_write_en <= 1'b0;
                outputs_write_address <= 'b0;
                outputs_write_data <= 'b0;
                outputs_write_counter <= 'd0;
                done <= 1'b0;
                if (start) begin
                    state <= WRITE;
                end
            end
            WRITE: begin
                if (outputs_write_counter == OUTPUT_SIZE) begin
                    outputs_write_en <= 1'b0;
                    outputs_write_address <= 'd0;
                    outputs_write_data <= 'd0;
                    outputs_write_counter <= 'd0;
                    state <= DONE;
                end else begin
                    outputs_write_en <= 1'b1;
                    outputs_write_address <= outputs_write_counter;
                    outputs_write_data <= inputs[outputs_write_counter];
                    outputs_write_counter <= outputs_write_counter + 1'd1;
                    state <= WRITE;
                end
            end
            DONE: begin
                outputs_write_en <= 0;
                outputs_write_address <= 'd0;
                outputs_write_data <= 'd0;
                outputs_write_counter <= 'd0;
                done <= 1'b1;
                if (!start) state <= IDLE; // Wait for restart
            end
        endcase
    end
endmodule
