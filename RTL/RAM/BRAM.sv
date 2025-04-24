`timescale 1ns / 1ps
module BRAM #(
		parameter WIDTH = 1, // WIDTH is the number of bits per location
		parameter DEPTH = 1, // depth is the number of addresses
		parameter DEPTH_BITS = 1 // DEPTH is number of bits used to represent address

	)(
		input clk,
		input write_en,
		input [DEPTH_BITS-1:0] write_address,
		input [WIDTH-1:0] write_data_in,
		input read_en,    
		input [DEPTH_BITS-1:0] read_address,
		output logic [WIDTH-1:0] read_data_out
	);
    (* ram_style = "block" *) logic [WIDTH-1:0] RAM [DEPTH-1:0];
    logic [DEPTH_BITS-1:0] address;
    logic enable;
    
    assign enable = read_en | write_en;
    assign address = write_en ? write_address : read_address;

	always @(posedge clk)
	begin
		 if (enable)
		 begin
			if (write_en)
				RAM[address] <= write_data_in;
		 else
			read_data_out <= RAM[address];
		 end
	end

endmodule
