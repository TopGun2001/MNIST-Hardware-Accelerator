`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.04.2025 23:45:01
// Design Name: 
// Module Name: LayerPipeline
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


module LayerPipeline#(	
        parameter INPUT_SIZE = 784,
		parameter OUTPUT_SIZE = 512,
		parameter WEIGHTS_WIDTH = 8,       // Bit-width of weights and inputs
        parameter BIAS_WIDTH    = 32       // Bit-width of bias values
	) 
    (
        input         CLK,
        input  [BIAS_WIDTH - 1:0] BIAS,
        input  [WEIGHTS_WIDTH - 1:0]  WEIGHTS [INPUT_SIZE - 1:0],
        input  [WEIGHTS_WIDTH - 1:0]  INPUTS  [INPUT_SIZE - 1:0],
        output [BIAS_WIDTH - 1:0]     NeuronOutput
    );
    
    logic signed [BIAS_WIDTH - 1:0] finalVal;
    int i;

    always_comb begin
        finalVal = BIAS;
        for (i = 0; i < INPUT_SIZE; i++) begin
            finalVal += INPUTS[i] * WEIGHTS[i];
        end
    end

    assign NeuronOutput = finalVal;
    
endmodule
