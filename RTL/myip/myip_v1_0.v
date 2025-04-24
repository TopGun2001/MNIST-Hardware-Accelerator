/* 
----------------------------------------------------------------------------------
--	(c) Rajesh C Panicker, NUS
--  Description : Matrix Multiplication AXI Stream Coprocessor. Based on the orginal AXIS Coprocessor template (c) Xilinx Inc
-- 	Based on the orginal AXIS coprocessor template (c) Xilinx Inc
--	License terms :
--	You are free to use this code as long as you
--		(i) DO NOT post a modified version of this on any public repository;
--		(ii) use it only for educational purposes;
--		(iii) accept the responsibility to ensure that your implementation does not violate any intellectual property of any entity.
--		(iv) accept that the program is provided "as is" without warranty of any kind or assurance regarding its suitability for any particular purpose;
--		(v) send an email to rajesh.panicker@ieee.org briefly mentioning its use (except when used for the course EE4218 at the National University of Singapore);
--		(vi) retain this notice in this file or any files derived from this.
----------------------------------------------------------------------------------
*/
/*
-------------------------------------------------------------------------------
--
-- Definition of Ports
-- ACLK              : Synchronous clock
-- ARESETN           : System reset, active low
-- S_AXIS_TREADY  : Ready to accept data in
-- S_AXIS_TDATA   :  Data in 
-- S_AXIS_TLAST   : Optional data in qualifier
-- S_AXIS_TVALID  : Data in is valid
-- M_AXIS_TVALID  :  Data out is valid
-- M_AXIS_TDATA   : Data Out
-- M_AXIS_TLAST   : Optional data out qualifier
-- M_AXIS_TREADY  : Connected slave device is ready to accept data out
--
-------------------------------------------------------------------------------
*/

module myip_v1_0 
	(
		// DO NOT EDIT BELOW THIS LINE ////////////////////
		ACLK,
		ARESETN,
		S_AXIS_TREADY,
		S_AXIS_TDATA,
		S_AXIS_TLAST,
		S_AXIS_TVALID,
		S_AXIS_TKEEP,
		M_AXIS_TVALID,
		M_AXIS_TDATA,
		M_AXIS_TLAST,
		M_AXIS_TREADY,
		M_AXIS_TKEEP
		// DO NOT EDIT ABOVE THIS LINE ////////////////////
	);
	input					ACLK;    // Synchronous clock
	input					ARESETN; // System reset, active low
	// slave in interface
	output	reg				S_AXIS_TREADY;  // Ready to accept data in
	input	[31 : 0]		S_AXIS_TDATA;   // Data in
	input					S_AXIS_TLAST;   // Optional data in qualifier
	input					S_AXIS_TVALID;  // Data in is valid
	input	[3 : 0]		S_AXIS_TKEEP;   // Optional data in qualifier
	// master out interface
	output	reg				M_AXIS_TVALID;  // Data out is valid
	output	reg [31 : 0]	M_AXIS_TDATA;   // Data Out
	output	reg				M_AXIS_TLAST;   // Optional data out qualifier
	input					M_AXIS_TREADY;  // Connected slave device is ready to accept data out
	output	[3 : 0]		M_AXIS_TKEEP;   // Optional data out qualifier

	// Overall parameters for design
    localparam INPUT_SIZE = 784;
    localparam OUTPUT_SIZE = 10;
    localparam LAYER_1_SIZE = 512;
    localparam LAYER_2_SIZE = 256;
    localparam WEIGHTS_WIDTH = 8; 
    localparam WEIGHTS_BURST = 4; // Send 32 bits instead
    localparam BIAS_WIDTH  = 32;
    parameter NUM_WEIGHTS = (INPUT_SIZE * LAYER_1_SIZE) + (LAYER_1_SIZE * LAYER_2_SIZE) + (LAYER_2_SIZE * OUTPUT_SIZE);
    parameter NUM_BIAS  = LAYER_1_SIZE + LAYER_2_SIZE + OUTPUT_SIZE;
	parameter TOTAL_WEIGHTS_BIAS = NUM_WEIGHTS + NUM_BIAS;
	// For RAM
	parameter INPUT_DEPTH = INPUT_SIZE;
	parameter OUTPUT_DEPTH = OUTPUT_SIZE;
	parameter W0_DEPTH = INPUT_SIZE * LAYER_1_SIZE;
	parameter W1_DEPTH = LAYER_1_SIZE * LAYER_2_SIZE;
	parameter W2_DEPTH = LAYER_2_SIZE * OUTPUT_SIZE;
	parameter B0_DEPTH = LAYER_1_SIZE;
	parameter B1_DEPTH = LAYER_2_SIZE;
	parameter B2_DEPTH = OUTPUT_SIZE;
	// For RAM adressing
	parameter INPUT_DEPTH_BITS = $clog2(INPUT_SIZE);
	parameter OUTPUT_DEPTH_BITS = $clog2(OUTPUT_SIZE);
	parameter W0_DEPTH_BITS = $clog2(INPUT_SIZE * LAYER_1_SIZE);
	parameter W1_DEPTH_BITS = $clog2(LAYER_1_SIZE * LAYER_2_SIZE);
	parameter W2_DEPTH_BITS = $clog2(LAYER_2_SIZE * OUTPUT_SIZE);
	parameter B0_DEPTH_BITS = $clog2(LAYER_1_SIZE);
	parameter B1_DEPTH_BITS = $clog2(LAYER_2_SIZE);
	parameter B2_DEPTH_BITS = $clog2(OUTPUT_SIZE);

	// M_AXIS_TKEEP
	assign M_AXIS_TKEEP = 4'b1111; // Always valid

	// Counter to load in weights and Biases
	localparam W0_END = INPUT_SIZE * LAYER_1_SIZE;
	localparam B0_END = W0_END + LAYER_1_SIZE;
	localparam W1_END = B0_END + LAYER_1_SIZE * LAYER_2_SIZE;
	localparam B1_END = W1_END + LAYER_2_SIZE;
	localparam W2_END = B1_END + LAYER_2_SIZE * OUTPUT_SIZE;
	localparam B2_END = W2_END + OUTPUT_SIZE;
	reg [$clog2(TOTAL_WEIGHTS_BIAS) - 1:0] wb_read_counter;
	
	// Counter to load in inputs
	reg [$clog2(INPUT_SIZE) - 1:0] inputs_read_counter;

	// Counter to load in outputs
	reg [$clog2(OUTPUT_SIZE) - 1:0] outputs_read_counter;
    
	// Define the states of state machine (one hot encoding)
	localparam Idle  = 4'd0;
	localparam Read_Weights_Biases = 4'd1;
	localparam Read_Inputs = 4'd2;
	localparam Inference = 4'd3;
	localparam Read_Results = 4'd4;	
	localparam Recv_Results = 4'd5;
	localparam Write_Outputs  = 4'd6;
	localparam Write_Outputs_Wait = 4'd7;
	localparam Store_Results = 4'd8;
	localparam Compare_Results = 4'd9;
	reg [3:0] state;
	
	// To keep start asserted for one cycle in FSM
	reg hasStarted = 1'b0;

    // Flag to indicate whether to accept Weights/Biases or Inputs
    reg isInference = 1'b0;

	// Inference signals
	reg Start; 						
	wire  Done;

	// Inputs_ram signals (32 bit inputs)
	reg inputs_write_en;
	reg [INPUT_DEPTH_BITS-1:0] inputs_write_address;
	reg [BIAS_WIDTH-1:0] inputs_write_data_in;
	wire inputs_read_en;
	wire [INPUT_DEPTH_BITS-1:0] inputs_read_address;
	wire [BIAS_WIDTH-1:0] inputs_read_data_out;

	// Outputs_ram signals (32 bit outputs)
	wire outputs_write_en; // Declare as wire
	wire [OUTPUT_DEPTH_BITS-1:0] outputs_write_address; // Declare as wire
	wire [BIAS_WIDTH-1:0] outputs_write_data_in;// Declare as wire
	reg outputs_read_en; // Declare as reg
	reg [OUTPUT_DEPTH_BITS-1:0] outputs_read_address; // Declare as reg
	wire [BIAS_WIDTH-1:0] outputs_read_data_out;

	// Weights_0_ram signals (8 bit weights)
	reg w0_write_en;
	reg [W0_DEPTH_BITS-1:0] w0_write_addr;
	reg [WEIGHTS_WIDTH-1:0] w0_write_data;
	wire w0_read_en;
	wire [W0_DEPTH_BITS-1:0] w0_read_addr;
	wire [WEIGHTS_BURST * WEIGHTS_WIDTH - 1:0] w0_read_data; // 32 bits

	// Weights_1_ram signals (8 bit weights)
	reg w1_write_en;
	reg [W1_DEPTH_BITS-1:0] w1_write_addr;
	reg [WEIGHTS_WIDTH-1:0] w1_write_data;
	wire w1_read_en;
	wire [W1_DEPTH_BITS-1:0] w1_read_addr;
	wire [WEIGHTS_BURST * WEIGHTS_WIDTH - 1:0] w1_read_data; // 32 bits

	// Weights_2_ram signals (8 bit weights)
	reg w2_write_en;
	reg [W2_DEPTH_BITS-1:0] w2_write_addr;
	reg [WEIGHTS_WIDTH-1:0] w2_write_data;
	wire w2_read_en;
	wire [W2_DEPTH_BITS-1:0] w2_read_addr;
	wire [WEIGHTS_BURST * WEIGHTS_WIDTH - 1:0] w2_read_data; // 32 bits

	// Bias_0_ram signals (32 bit biases)
	reg b0_write_en;
	reg [B0_DEPTH_BITS-1:0] b0_write_addr;
	reg [BIAS_WIDTH-1:0] b0_write_data;
	wire b0_read_en;
	wire [B0_DEPTH_BITS-1:0] b0_read_addr;
	wire [BIAS_WIDTH-1:0] b0_read_data;

	// Bias_1_ram signals (32 bit biases)
	reg b1_write_en;
	reg [B1_DEPTH_BITS-1:0] b1_write_addr;
	reg [BIAS_WIDTH-1:0] b1_write_data;
	wire b1_read_en;
	wire [B1_DEPTH_BITS-1:0] b1_read_addr;
	wire [BIAS_WIDTH-1:0] b1_read_data;

	// Bias_2_ram signals (32 bit biases)
	reg b2_write_en;
	reg [B2_DEPTH_BITS-1:0] b2_write_addr;
	reg [BIAS_WIDTH-1:0] b2_write_data;
	wire b2_read_en;
	wire [B2_DEPTH_BITS-1:0] b2_read_addr;
	wire [BIAS_WIDTH-1:0] b2_read_data;
	
	// argmax variables
	reg [BIAS_WIDTH-1:0] curr_val = 0;
	reg [BIAS_WIDTH-1:0] max_val = 0;
	reg [$clog2(OUTPUT_SIZE) - 1:0] index_max_val = 0;

	always @(posedge ACLK) 
	begin
		// Active Low Reset
		if (!ARESETN) begin
			state <= Idle;
        end else begin
			case (state)
				Idle: begin
				
				    curr_val <= 0;
				    max_val <= 0;
				    index_max_val <= 0;
					// Counters
					wb_read_counter <= 0;
					inputs_read_counter <= 0;
					outputs_read_counter <= 0;
					// Toggles
					hasStarted <= 0;
					b2_write_en <= 0;
					// AXIS signals
					S_AXIS_TREADY 	<= 0;
					M_AXIS_TVALID 	<= 0;
					M_AXIS_TLAST  	<= 0;
					// IDLE -> Read_Inputs
					if (S_AXIS_TVALID == 1) begin
						if (isInference == 1'b0) begin
							// Load weights and biases
							state <= Read_Weights_Biases;
							S_AXIS_TREADY <= 1'b1;
						end else begin
							// Load inputs
							state <= Read_Inputs;
							S_AXIS_TREADY <= 1'b1;
						end
					end else begin
					   state <= Idle;
					end
				end
				Read_Weights_Biases: begin
					S_AXIS_TREADY <= 1'b1;
					if (S_AXIS_TVALID == 1) begin
						// Select which RAM to write based on wb_read_counter
						if (wb_read_counter < W0_END) begin
							w0_write_en   <= 1'b1;
							w0_write_addr <= wb_read_counter;
							w0_write_data <= S_AXIS_TDATA;
						end else if (wb_read_counter < B0_END) begin
							w0_write_en   <= 1'b0;
							b0_write_en   <= 1'b1;
							b0_write_addr <= wb_read_counter - W0_END;
							b0_write_data <= S_AXIS_TDATA;
						end else if (wb_read_counter < W1_END) begin
							b0_write_en   <= 1'b0;
							w1_write_en   <= 1'b1;
							w1_write_addr <= wb_read_counter - B0_END;
							w1_write_data <= S_AXIS_TDATA;
						end else if (wb_read_counter < B1_END) begin
							w1_write_en   <= 1'b0;
							b1_write_en   <= 1'b1;
							b1_write_addr <= wb_read_counter - W1_END;
							b1_write_data <= S_AXIS_TDATA;
						end else if (wb_read_counter < W2_END) begin
							b1_write_en   <= 1'b0;
							w2_write_en   <= 1'b1;
							w2_write_addr <= wb_read_counter - B1_END;
							w2_write_data <= S_AXIS_TDATA;
						end else if (wb_read_counter < B2_END) begin
							w2_write_en   <= 1'b0;
							b2_write_en   <= 1'b1;
							b2_write_addr <= wb_read_counter - W2_END;
							b2_write_data <= S_AXIS_TDATA;
						end
						wb_read_counter <= wb_read_counter + 1;
					end

					// Check if last word
					if (wb_read_counter == TOTAL_WEIGHTS_BIAS) begin
						b2_write_en <= 1'b0;
						S_AXIS_TREADY <= 1'b0; // Let Read_Inputs handle the next stream
						isInference <= 1'b1;
						state <= Read_Inputs;
					end
				end
				Read_Inputs: begin
					S_AXIS_TREADY <= 1'b1;
					if (S_AXIS_TVALID == 1) begin
						// Write data to RAM
						if (inputs_read_counter < INPUT_SIZE) begin
                            inputs_write_en      <= 1'b1;
                            inputs_write_address <= inputs_read_counter;
                            inputs_write_data_in <= S_AXIS_TDATA;
                        end
						inputs_read_counter <= inputs_read_counter + 1;
					end
					// Check if last word
					if (inputs_read_counter == INPUT_SIZE) begin
						inputs_write_en    <= 1'b0;
						S_AXIS_TREADY      <= 1'b0;
						state              <= Inference;
					end
				end
				Inference: begin
					// Start signal to Inference unit asserted for one cycle
					if (Start == 1'b0 && hasStarted == 1'b0) begin
						Start <= 1'b1;
						hasStarted <= 1'b1;
					end else begin
						Start <= 1'b0;
					end
					// Wait for Done signal from Inference unit
					if (Done == 1) begin
						Start <= 1'b0;
						state <= Read_Results;
					end else begin
						state <= Inference;
					end
				end
				Read_Results: begin
					// Request the next data word from the Outputs RAM.
					outputs_read_en    <= 1'b1;
					outputs_read_address <= outputs_read_counter;
					// Clear TVALID so the new data is not immediately sent.
					M_AXIS_TVALID    <= 1'b0;
					// Move to wait state to let the RAM read complete.
					state <= Recv_Results;
				end
				Recv_Results: begin
					// Wait for RAM to give value
					state <= Store_Results;
				end
				Store_Results: begin
				    curr_val <= outputs_read_data_out;
				    state <= Compare_Results;
				end
				Compare_Results: begin
				    if ((curr_val[BIAS_WIDTH-1] != max_val[BIAS_WIDTH-1] && max_val[BIAS_WIDTH-1] == 1'b1) ||(curr_val[BIAS_WIDTH-1] == max_val[BIAS_WIDTH-1] && curr_val > max_val)) begin
				        max_val <= curr_val;
				        index_max_val <= outputs_read_counter;
				    end
				    outputs_read_counter <= outputs_read_counter + 1'b1;
				    if (outputs_read_counter == OUTPUT_SIZE - 1) begin
				        state <= Write_Outputs;
				    end
				    else begin
				        state <= Read_Results;
				    end
				end
				Write_Outputs: begin
				    if (M_AXIS_TREADY) begin
                        // Drive TVALID and TDATA once DMA READY
                        M_AXIS_TVALID <= 1'b1;
                        M_AXIS_TLAST <= 1'b1;
                        M_AXIS_TDATA <= index_max_val;           
				    end
				    state <= Write_Outputs_Wait;
				end
				Write_Outputs_Wait: begin
				    M_AXIS_TVALID <= 1'b0;
				    M_AXIS_TLAST <= 1'b0;
                    outputs_read_en <= 1'b0;
				    outputs_read_counter <= 0;
					state <= Idle;
                    curr_val <= 0;
				    max_val <= 0;
				    index_max_val <= 0;
				end
			endcase
		end
	end

	// Instantiate RAM Modules and port mapping
	// Inputs RAM
	ULTRA_RAM # (
		.WIDTH(BIAS_WIDTH),
		.DEPTH(INPUT_DEPTH),
		.DEPTH_BITS(INPUT_DEPTH_BITS)
	) Inputs_ram (
		.clk(ACLK),
		.write_en(inputs_write_en),
		.write_address(inputs_write_address),
		.write_data_in(inputs_write_data_in),
		.read_en(inputs_read_en),    
		.read_address(inputs_read_address),
		.read_data_out(inputs_read_data_out)
	);
	// Outputs RAM
	ULTRA_RAM # (
		.WIDTH(BIAS_WIDTH),
		.DEPTH(OUTPUT_DEPTH),
		.DEPTH_BITS(OUTPUT_DEPTH_BITS)
	) Outputs_ram (
		.clk(ACLK),
		.write_en(outputs_write_en),
		.write_address(outputs_write_address),
		.write_data_in(outputs_write_data_in),
		.read_en(outputs_read_en),    
		.read_address(outputs_read_address),
		.read_data_out(outputs_read_data_out)
	);
	// Weights_0 RAM
	RAM_BURST # (
		.WIDTH(WEIGHTS_WIDTH),
		.BURST_LEN(WEIGHTS_BURST),
		.DEPTH(W0_DEPTH),
		.DEPTH_BITS(W0_DEPTH_BITS)
	) Weights_0_ram (
		.clk(ACLK),
		.write_en(w0_write_en),
		.write_address(w0_write_addr),
		.write_data_in(w0_write_data),
		.read_en(w0_read_en),    
		.read_address(w0_read_addr),
		.read_data_out(w0_read_data)
	);

	// Weights_1 RAM
	RAM_BURST # (
		.WIDTH(WEIGHTS_WIDTH),
		.BURST_LEN(WEIGHTS_BURST),
		.DEPTH(W1_DEPTH),
		.DEPTH_BITS(W1_DEPTH_BITS)
	) Weights_1_ram (
		.clk(ACLK),
		.write_en(w1_write_en),
		.write_address(w1_write_addr),
		.write_data_in(w1_write_data),
		.read_en(w1_read_en),    
		.read_address(w1_read_addr),
		.read_data_out(w1_read_data)
	);

	// Weights_2 RAM
	LUT_RAM_BURST # (
		.WIDTH(WEIGHTS_WIDTH),
		.BURST_LEN(WEIGHTS_BURST),
		.DEPTH(W2_DEPTH),
		.DEPTH_BITS(W2_DEPTH_BITS)
	) Weights_2_ram (
		.clk(ACLK),
		.write_en(w2_write_en),
		.write_address(w2_write_addr),
		.write_data_in(w2_write_data),
		.read_en(w2_read_en),    
		.read_address(w2_read_addr),
		.read_data_out(w2_read_data)
	);

	// Bias_0 RAM
	ULTRA_RAM # (
		.WIDTH(BIAS_WIDTH),
		.DEPTH(B0_DEPTH),
		.DEPTH_BITS(B0_DEPTH_BITS)
	) Bias_0_ram (
		.clk(ACLK),
		.write_en(b0_write_en),
		.write_address(b0_write_addr),
		.write_data_in(b0_write_data),
		.read_en(b0_read_en),    
		.read_address(b0_read_addr),
		.read_data_out(b0_read_data)
	);

	// Bias_1 RAM
	ULTRA_RAM # (
		.WIDTH(BIAS_WIDTH),
		.DEPTH(B1_DEPTH),
		.DEPTH_BITS(B1_DEPTH_BITS)
	) Bias_1_ram (
		.clk(ACLK),
		.write_en(b1_write_en),
		.write_address(b1_write_addr),
		.write_data_in(b1_write_data),
		.read_en(b1_read_en),    
		.read_address(b1_read_addr),
		.read_data_out(b1_read_data)
	);

	// Bias_2 RAM
	ULTRA_RAM # (
		.WIDTH(BIAS_WIDTH),
		.DEPTH(B2_DEPTH),
		.DEPTH_BITS(B2_DEPTH_BITS)
	) Bias_2_ram (
		.clk(ACLK),
		.write_en(b2_write_en),
		.write_address(b2_write_addr),
		.write_data_in(b2_write_data),
		.read_en(b2_read_en),    
		.read_address(b2_read_addr),
		.read_data_out(b2_read_data)
	);

	// Instantiate Inference module and port mapping to RAM
	Inference # (
		.INPUT_SIZE(INPUT_SIZE),
		.OUTPUT_SIZE(OUTPUT_SIZE),
		.LAYER_1_SIZE(LAYER_1_SIZE),
		.LAYER_2_SIZE(LAYER_2_SIZE),
		.WEIGHTS_WIDTH(WEIGHTS_WIDTH),
		.BURST_LEN(WEIGHTS_BURST),
		.BIAS_WIDTH(BIAS_WIDTH),
		.INPUT_DEPTH_BITS(INPUT_DEPTH_BITS),
		.OUTPUT_DEPTH_BITS(OUTPUT_DEPTH_BITS),
		.W0_DEPTH_BITS(W0_DEPTH_BITS),
		.W1_DEPTH_BITS(W1_DEPTH_BITS),
		.W2_DEPTH_BITS(W2_DEPTH_BITS),
		.B0_DEPTH_BITS(B0_DEPTH_BITS),
		.B1_DEPTH_BITS(B1_DEPTH_BITS),
		.B2_DEPTH_BITS(B2_DEPTH_BITS)
	) Inference_inst (
		.clk(ACLK),
		.Start(Start),
		.Done(Done),
		// Inputs RAM reads
		.inputs_read_en(inputs_read_en),
		.inputs_read_address(inputs_read_address),
		.inputs_read_data_out(inputs_read_data_out),

		// Outputs RAM writes
		.outputs_write_en(outputs_write_en),
		.outputs_write_address(outputs_write_address),
		.outputs_write_data_in(outputs_write_data_in),

		// Weights_0 RAM reads
		.w0_read_en(w0_read_en),
		.w0_read_addr(w0_read_addr),
		.w0_read_data(w0_read_data),

		// Weights_1 RAM reads
		.w1_read_en(w1_read_en),
		.w1_read_addr(w1_read_addr),
		.w1_read_data(w1_read_data),

		// Weights_2 RAM reads
		.w2_read_en(w2_read_en),
		.w2_read_addr(w2_read_addr),
		.w2_read_data(w2_read_data),

		// Bias_0 RAM reads
		.b0_read_en(b0_read_en),
		.b0_read_addr(b0_read_addr),
		.b0_read_data(b0_read_data),

		// Bias_1 RAM reads
		.b1_read_en(b1_read_en),
		.b1_read_addr(b1_read_addr),
		.b1_read_data(b1_read_data),

		// Bias_2 RAM reads
		.b2_read_en(b2_read_en),
		.b2_read_addr(b2_read_addr),
		.b2_read_data(b2_read_data)
	);
endmodule
