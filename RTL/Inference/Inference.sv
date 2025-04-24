module Inference #(
    parameter INPUT_SIZE         = 784,
    parameter OUTPUT_SIZE        = 10,
    parameter LAYER_1_SIZE       = 512,
    parameter LAYER_2_SIZE       = 256,
    parameter WEIGHTS_WIDTH      = 8,
    parameter BURST_LEN          = 4,
    parameter BIAS_WIDTH         = 32,
    parameter INPUT_DEPTH_BITS   = $clog2(INPUT_SIZE),
    parameter OUTPUT_DEPTH_BITS  = $clog2(OUTPUT_SIZE),
    parameter W0_DEPTH_BITS      = $clog2(INPUT_SIZE * LAYER_1_SIZE),
    parameter W1_DEPTH_BITS      = $clog2(LAYER_1_SIZE * LAYER_2_SIZE),
    parameter W2_DEPTH_BITS      = $clog2(LAYER_2_SIZE * OUTPUT_SIZE),
    parameter B0_DEPTH_BITS      = $clog2(LAYER_1_SIZE),
    parameter B1_DEPTH_BITS      = $clog2(LAYER_2_SIZE),
    parameter B2_DEPTH_BITS      = $clog2(OUTPUT_SIZE)
)
(
    // Clock and control signals
    input logic clk,
    input logic Start,
    output logic Done,
    
    // Inputs RAM read interface
    output logic inputs_read_en,
    output logic [INPUT_DEPTH_BITS-1:0] inputs_read_address,
    input logic [BIAS_WIDTH-1:0]     inputs_read_data_out,
    
    // Outputs RAM write interface
    output logic outputs_write_en,
    output logic [OUTPUT_DEPTH_BITS-1:0] outputs_write_address,
    output logic [BIAS_WIDTH-1:0]         outputs_write_data_in,
    
    // Weights & Bias RAM read interface
    output logic w0_read_en,
    output logic [W0_DEPTH_BITS-1:0] w0_read_addr,
    input logic [BURST_LEN*WEIGHTS_WIDTH-1:0] w0_read_data, // 32 bits
    
    output logic w1_read_en,
    output logic [W1_DEPTH_BITS-1:0] w1_read_addr,
    input logic [BURST_LEN*WEIGHTS_WIDTH-1:0] w1_read_data, // 32 bits
    
    output logic w2_read_en,
    output logic [W2_DEPTH_BITS-1:0] w2_read_addr,
    input logic [BURST_LEN*WEIGHTS_WIDTH-1:0] w2_read_data, // 32 bits
    
    output logic b0_read_en,
    output logic [B0_DEPTH_BITS-1:0] b0_read_addr,
    input logic [BIAS_WIDTH-1:0] b0_read_data,
    
    output logic b1_read_en,
    output logic [B1_DEPTH_BITS-1:0] b1_read_addr,
    input logic [BIAS_WIDTH-1:0] b1_read_data,

    output logic b2_read_en,
    output logic [B2_DEPTH_BITS-1:0] b2_read_addr,
    input logic [BIAS_WIDTH-1:0] b2_read_data
);
	// Scaler constants for each layer (Fill with values from ONNX)
	localparam SCALER1 = 32'h3d0090cc; // (0.0002452194457873702/0.0078125)
	localparam SCALER2 = 32'h3d000000; // (0.000244140625/0.0078125)
	
	// MAC unrolling
    localparam PARALLEL_MACS = 32'd256;
    localparam UNROLL_FACTOR = 32'd2;
    // Intermediate 8-bit layer signals for interconnection
    /*
        * layer1_in: Inputs RAM -> layer1_in
        * layer1_out: layer1_in -> FullyConnected -> layer1_out
        * tanh1_out: layer1_out -> Tanh -> tanh1_out
        * layer2_out: tanh1_out -> FullyConnected -> layer2_out
        * tanh2_out: layer2_out -> Tanh -> tanh2_out
        * layer3_out: tanh2_out -> FullyConnected -> layer3_out
        * outputs: layer3_out -> Outputs RAM
    */

    // Use BRAM to reduce LUTs (Doesn't seem to work)
    (* ram_style = "block" *) logic signed [WEIGHTS_WIDTH-1:0] layer1_in [INPUT_SIZE-1:0];
    (* ram_style = "block" *) logic signed [BIAS_WIDTH-1:0] layer1_out [LAYER_1_SIZE-1:0];
    (* ram_style = "block" *) logic signed [WEIGHTS_WIDTH-1:0] tanh1_out [LAYER_1_SIZE-1:0];
    (* ram_style = "block" *) logic signed [BIAS_WIDTH-1:0] layer2_out [LAYER_2_SIZE-1:0];
    (* ram_style = "block" *) logic signed [WEIGHTS_WIDTH-1:0] tanh2_out [LAYER_2_SIZE-1:0];
    (* ram_style = "block" *) logic signed [BIAS_WIDTH-1:0] layer3_out [OUTPUT_SIZE-1:0];

	// Start and done signals for each layer
	logic Start_layer1;
    logic Done_layer1;

    logic Start_tanh1;
    logic Done_tanh1;

	logic Start_layer2;
    logic Done_layer2;

    logic Start_tanh2;
    logic Done_tanh2;

	logic Start_layer3;
    logic Done_layer3;

	logic Start_layer_output;

    assign Start_tanh1 = Done_layer1;
    assign Start_layer2 = Done_tanh1;
    assign Start_tanh2 = Done_layer2;
    assign Start_layer3 = Done_tanh2;
    assign Start_layer_output = Done_layer3;
    
    // Input layer to read inputs from RAM and convert to 8-bit signed representation
	InputLayer #(
		.INPUT_SIZE(INPUT_SIZE),
		.INPUT_WIDTH(BIAS_WIDTH),
		.OUTPUT_WIDTH(WEIGHTS_WIDTH)
	) input_layer (
        // Clock and control signals
		.clk(clk),
		.start(Start), // Start input signal
		.done(Start_layer1),
		// Input signals
		.inputs_read_en(inputs_read_en),
		.inputs_read_address(inputs_read_address),
		.inputs(inputs_read_data_out),
		// Output signals
		.layer_out(layer1_in)
	);
    
   // UNROLL 256
   FullyConnected_UR #(
       .INPUT_SIZE(INPUT_SIZE),
       .OUTPUT_SIZE(LAYER_1_SIZE),
       .WEIGHTS_WIDTH(WEIGHTS_WIDTH),
       .BURST_LEN(BURST_LEN),
       .BIAS_WIDTH(BIAS_WIDTH),
       .PARALLEL_MACS(PARALLEL_MACS)
   ) layer1 (
        // Clock and control signals
        .clk(clk),
        .start(Start_layer1),
		.done(Done_layer1),
		// Input signals
		.inputs(layer1_in),
		// Weights signals
		.w_read_en(w0_read_en),
		.w_read_addr(w0_read_addr),
		.w_read_data(w0_read_data),
		// Bias signals
		.b_read_en(b0_read_en),
		.b_read_addr(b0_read_addr),
		.b_read_data(b0_read_data),
		// Output signals
		.layer_out(layer1_out)
   );

  Tanh #(
       .INPUT_SIZE(LAYER_1_SIZE),
       .OUTPUT_SIZE(LAYER_1_SIZE),
       .WEIGHTS_WIDTH(WEIGHTS_WIDTH),
       .UNROLL_FACTOR(UNROLL_FACTOR),
       .BIAS_WIDTH(BIAS_WIDTH),
       .SCALER(SCALER1)
   ) tanh1 (
       // Clock and control signals
       .clk(clk),
       .start(Start_tanh1),
       .done(Done_tanh1),
       // Input signals
       .inputs(layer1_out),
       // Output signals
       .layer_out(tanh1_out)
   );
    
    // UNROLL 256
    FullyConnected_UR #(
        .INPUT_SIZE(LAYER_1_SIZE),
        .OUTPUT_SIZE(LAYER_2_SIZE),
        .WEIGHTS_WIDTH(WEIGHTS_WIDTH),
        .BURST_LEN(BURST_LEN),
        .BIAS_WIDTH(BIAS_WIDTH),
        .PARALLEL_MACS(PARALLEL_MACS)
    ) layer2 (
        // Clock and control signals
        .clk(clk),
        .start(Start_layer2),
        .done(Done_layer2),
        // Input signals
        .inputs(tanh1_out),
        // Weights signals
        .w_read_en(w1_read_en),
        .w_read_addr(w1_read_addr),
        .w_read_data(w1_read_data),
        // Bias signals
        .b_read_en(b1_read_en),
        .b_read_addr(b1_read_addr),
        .b_read_data(b1_read_data),
        // Output signals
        .layer_out(layer2_out)
    );

    Tanh #(
       .INPUT_SIZE(LAYER_2_SIZE),
       .OUTPUT_SIZE(LAYER_2_SIZE),
       .WEIGHTS_WIDTH(WEIGHTS_WIDTH),
       .UNROLL_FACTOR(UNROLL_FACTOR),
       .BIAS_WIDTH(BIAS_WIDTH),
       .SCALER(SCALER2)
    ) tanh2 (
        // Clock and control signals
        .clk(clk),
        .start(Start_tanh2),
        .done(Done_tanh2),
        // Input signals
        .inputs(layer2_out),
        // Output signals
        .layer_out(tanh2_out)
    );
    
    // UNROLL 256
    FullyConnected_UR #(
        .INPUT_SIZE(LAYER_2_SIZE),
        .OUTPUT_SIZE(OUTPUT_SIZE),
        .WEIGHTS_WIDTH(WEIGHTS_WIDTH),
        .BURST_LEN(BURST_LEN),
        .BIAS_WIDTH(BIAS_WIDTH),
        .PARALLEL_MACS(PARALLEL_MACS)
    ) layer3 (
        // Clock and control signals
        .clk(clk),
        .start(Start_layer3),
        .done(Done_layer3),
        // Input signals
        .inputs(tanh2_out),
        // Weights signals
        .w_read_en(w2_read_en),
        .w_read_addr(w2_read_addr),
        .w_read_data(w2_read_data),
        // Bias signals
        .b_read_en(b2_read_en),
        .b_read_addr(b2_read_addr),
        .b_read_data(b2_read_data),
        // Output signals
        .layer_out(layer3_out)
    );

    OutputLayer # (
        .OUTPUT_SIZE(OUTPUT_SIZE),
        .OUTPUT_WIDTH(BIAS_WIDTH)
    ) output_layer (
        // Clock and control signals
        .clk(clk),
        .start(Start_layer_output),
        .done(Done), // Done output signal
        // Input signals
        .inputs(layer3_out),
        // Output signals
        .outputs_write_en(outputs_write_en),
        .outputs_write_address(outputs_write_address),
        .outputs_write_data(outputs_write_data_in)
    );
endmodule
