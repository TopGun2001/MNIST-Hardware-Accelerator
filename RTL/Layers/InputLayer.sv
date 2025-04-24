module InputLayer #(
    parameter INPUT_SIZE    = 784,  // Number of input elements
    parameter INPUT_WIDTH = 32,     // Bit-width of each input
    parameter OUTPUT_WIDTH = 8
)(
    input  logic clk,
    input  logic start,                 // Start signal for reading input
    output logic done,                   // Done signal when all inputs are read
    
    // Input RAM read interface
    output logic inputs_read_en,         // Enable signal for reading from RAM
    output logic [$clog2(INPUT_SIZE)-1:0] inputs_read_address,  // Read address
    input logic [INPUT_WIDTH-1:0] inputs, // Read data from RAM

    // Output: Array to store input values
    output logic signed [OUTPUT_WIDTH-1:0] layer_out [INPUT_SIZE-1:0]
);

    // State Machine States
    typedef enum logic [2:0] {
        IDLE = 3'd0,
        READ = 3'd1,
        PENDING = 3'd2,
        RECV = 3'd3,
        DONE = 3'd4
    } state_t;

    state_t state = IDLE; // Initial state

    always_ff @(posedge clk) begin
        case (state)
            IDLE: begin
                done <= 1'b0; // Reset done\
                inputs_read_en <= 1'b0; // Enable first read
                inputs_read_address <= 'b0;
                if (start) begin
                    state <= READ;
                end else begin
                    state <= IDLE;
                end
            end
            READ: begin
                inputs_read_en <= 1'b1; // Enable first read
                inputs_read_address <= inputs_read_address;
                state <= PENDING;
            end
            PENDING: begin
                state <= RECV;
            end
            RECV: begin
                layer_out[inputs_read_address] <= inputs[OUTPUT_WIDTH-1:0]; // Truncate to 8 bits
                inputs_read_address <= inputs_read_address + 1'b1; // Next address
                // Transition to IDLE and Done signal
                state <= (inputs_read_address == INPUT_SIZE) ? DONE : READ;
            end
            DONE: begin
                done <= 1'b1; // Signal that reading is complete
                if (!start) begin
                    state <= IDLE; // Reset when start deasserts
                end
            end
            default: begin
                inputs_read_en <= 1'b0;
                inputs_read_address <= 'b0;
                state <= IDLE;
            end
        endcase
    end
endmodule