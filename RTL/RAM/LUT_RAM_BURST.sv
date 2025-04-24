module LUT_RAM_BURST #(
    parameter WIDTH = 8,                          // Width of a single weight
    parameter BURST_LEN = 4,                      // How many weights to read at once
    parameter DEPTH = 784 * 512,                  // Total number of weights
    parameter DEPTH_BITS = $clog2(DEPTH)        // Address bits for the whole RAM
)(
    input clk,

    // Write port
    input write_en,
    input [DEPTH_BITS-1:0] write_address,
    input [WIDTH-1:0] write_data_in,

    // Read port
    input read_en,
    input [DEPTH_BITS-1:0] read_address,
    output logic [BURST_LEN*WIDTH-1:0] read_data_out
);
    localparam BANK_DEPTH = DEPTH / BURST_LEN;    // Depth of each bank
    localparam BANK_ADDR_BITS = $clog2(BANK_DEPTH); // Address bits per bank

    // Create 4 RAM banks
    (* ram_style = "distributed" *) logic [WIDTH-1:0] ram_bank_0 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *) logic [WIDTH-1:0] ram_bank_1 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *) logic [WIDTH-1:0] ram_bank_2 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *) logic [WIDTH-1:0] ram_bank_3 [0:BANK_DEPTH-1];

    // Write logic
    logic [1:0] write_bank_sel = 'd0;
    logic [BANK_ADDR_BITS-1:0] write_bank_addr = 'd0;
    // Read logic
    logic [BANK_ADDR_BITS-1:0] read_bank_addr = 'd0;

    always_ff @(posedge clk) begin
        if (write_en) begin
            write_bank_sel = write_address % BURST_LEN;
            write_bank_addr = write_address / BURST_LEN;
            case (write_bank_sel)
                2'd0: ram_bank_0[write_bank_addr] <= write_data_in;
                2'd1: ram_bank_1[write_bank_addr] <= write_data_in;
                2'd2: ram_bank_2[write_bank_addr] <= write_data_in;
                2'd3: ram_bank_3[write_bank_addr] <= write_data_in;
            endcase
        end
    end

    // Read logic for 4 values (BURST_LEN = 4)
    always_ff @(posedge clk) begin
        if (read_en) begin
            read_bank_addr = read_address / BURST_LEN;
            read_data_out <= {ram_bank_0[read_bank_addr],ram_bank_1[read_bank_addr],ram_bank_2[read_bank_addr],ram_bank_3[read_bank_addr]};
        end
    end
endmodule
