`timescale 1ns / 1ps
module ULTRA_RAM #(
    parameter WIDTH = 72,                      // UltraRAM supports up to 72-bit wide words
    parameter DEPTH = 1, // depth is the number of addresses
	parameter DEPTH_BITS = 1 // DEPTH is number of bits used to represent address

)(
    input logic clk,
    
    // Write port
    input logic write_en,
    input logic [DEPTH_BITS-1:0] write_address,
    input logic [WIDTH-1:0] write_data_in,
    
    // Read port
    input logic read_en,
    input logic [DEPTH_BITS-1:0] read_address,
    output logic [WIDTH-1:0] read_data_out
);

    // Corrected directive: tells Vivado to use UltraRAM
    (* ram_style = "ultra" *) logic [WIDTH-1:0] RAM [0:DEPTH-1];

    // Write logic
    always_ff @(posedge clk) begin
        if (write_en)
            RAM[write_address] <= write_data_in;
    end

    // Read logic
    always_ff @(posedge clk) begin
        if (read_en)
            read_data_out <= RAM[read_address];
    end

endmodule
