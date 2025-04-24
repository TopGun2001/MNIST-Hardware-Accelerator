`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.04.2025 23:31:19
// Design Name: 
// Module Name: LayerUnroll
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module LayerUnroll#(	
        parameter WEIGHTS_WIDTH = 8,       // Bit-width of weights and inputs
        parameter BIAS_WIDTH    = 32       // Bit-width of bias values
	) 
    (
        input  logic        [WEIGHTS_WIDTH - 1:0]  WEIGHTS,
        input  logic        [WEIGHTS_WIDTH - 1:0]  INPUTS,
        output logic signed [BIAS_WIDTH - 1:0]     RESULT    
    );
   
    // Just multiply the input with it's respective weight
    assign RESULT = INPUTS * WEIGHTS;
    
endmodule
