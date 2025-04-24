`timescale 1ns / 1ps

module tb_myip_v1_0();
    
    reg                          ACLK = 0;    // Synchronous clock
    reg                          ARESETN; // System reset, active low
    // slave in interface
    wire                         S_AXIS_TREADY;  // Ready to accept data in
    reg      [31 : 0]            S_AXIS_TDATA;   // Data in
    reg                          S_AXIS_TLAST;   // Optional data in qualifier
    reg                          S_AXIS_TVALID;  // Data in is valid
    reg [3:0] S_AXIS_TKEEP;
    // master out interface
    wire                         M_AXIS_TVALID;  // Data out is valid
    wire     [31 : 0]            M_AXIS_TDATA;   // Data out
    wire                         M_AXIS_TLAST;   // Optional data out qualifier
    reg                          M_AXIS_TREADY;  // Connected slave device is ready to accept data out
    wire [3:0] M_AXIS_TKEEP;
    myip_v1_0 U1 ( 
                .ACLK(ACLK),
                .ARESETN(ARESETN),
                .S_AXIS_TREADY(S_AXIS_TREADY),
                .S_AXIS_TDATA(S_AXIS_TDATA),
                .S_AXIS_TLAST(S_AXIS_TLAST),
                .S_AXIS_TKEEP(S_AXIS_TKEEP),
                .S_AXIS_TVALID(S_AXIS_TVALID),
                .M_AXIS_TVALID(M_AXIS_TVALID),
                .M_AXIS_TDATA(M_AXIS_TDATA),
                .M_AXIS_TLAST(M_AXIS_TLAST),
                .M_AXIS_TREADY(M_AXIS_TREADY),
                .M_AXIS_TKEEP(M_AXIS_TKEEP)
	);
    
    // Weights and bias
	// Overall parameters for design
    localparam INPUT_SIZE = 3;
    localparam OUTPUT_SIZE = 10;
    localparam LAYER_1_SIZE = 6;
    localparam LAYER_2_SIZE = 6;
    localparam WEIGHTS_WIDTH = 8; 
    localparam BIAS_WIDTH  = 32;
    localparam NUM_WEIGHTS = (INPUT_SIZE * LAYER_1_SIZE) + (LAYER_1_SIZE * LAYER_2_SIZE) + (LAYER_2_SIZE * OUTPUT_SIZE);
    localparam NUM_BIAS  = LAYER_1_SIZE + LAYER_2_SIZE + OUTPUT_SIZE;
    localparam TOTAL_WEIGHTS_BIAS = NUM_WEIGHTS + NUM_BIAS;
	// Inputs
	localparam NUM_INPUTS = INPUT_SIZE;

	reg M_AXIS_TLAST_prev = 1'b0;

	// INPUT DATA
    logic [31:0] data [0:INPUT_SIZE-1];
    assign data = {34, 7, 25};

    // WEIGHTS/BIAS DATA
    logic [31:0] weights [0:TOTAL_WEIGHTS_BIAS-1];
    assign weights = {64, 35, 12, 98, -48, -63, 115, -39, 23, 85, -102, -19, 108, 56, 3, 35, 50, 70, 112, -44, -42, 61, -23, 51, 92, -40, 75, -36, 52, 55, 118, 17, 117, -6, 98, 81, -100, -75, -109, 13, 61, -6, 95, 34, 58, -124, -69, 1, -52, -116, -14, 35, 4, 69, 20, -123, 103, -3, 44, 22, 34, 46, -19, 100, 107, -34, -97, 61, -107, -33, -17, 8, 52, -54, -26, -70, 1, 84, -50, 73, -55, 78, -107, -115, -113, 50, -124, -92, -35, -33, 36, 19, 48, 11, -19, 7, -3, 90, 29, 117, -81, 50, 46, 94, -59, -1, 40, 10, 117, -51, 42, -46, -80, -113, 17, -25, -30, -14, 72, -14, 85, -94, 120, -104, -14, 81, -68, 13, -128, -28, -31, -43, -15, 1, 122, -17};
    
    // RESULTS
   	integer word_cnt;
    logic [31:0] result_memory [0:OUTPUT_SIZE-1];

   	always@(posedge ACLK)
		M_AXIS_TLAST_prev <= M_AXIS_TLAST;
           
	always
		#50 ACLK = ~ACLK;

	initial begin
    	#25						// to make inputs and capture from testbench not aligned with clock edges
    	ARESETN = 1'b0; 		// apply reset (active low)
    	S_AXIS_TVALID = 1'b0;   // no valid data placed on the S_AXIS_TDATA yet
    	S_AXIS_TLAST = 1'b0; 	// not required unless we are dealing with an unknown number of inputs. Ignored by the coprocessor. We will be asserting it correctly anyway
    	M_AXIS_TREADY = 1'b0;	// not ready to receive data from the co-processor yet.   
    	#100 					// hold reset for 100 ns.
    	ARESETN = 1'b1;			// release reset
    	
    	word_cnt = 'd0;
        // Drive ascending values into weights and bias
        S_AXIS_TVALID = 1'b1;
        while(word_cnt < TOTAL_WEIGHTS_BIAS) begin
            // Wait until DUT asserts TREADY
            if (S_AXIS_TREADY) begin
                S_AXIS_TDATA = weights[word_cnt];  // Send ascending value
                S_AXIS_TLAST = (word_cnt == TOTAL_WEIGHTS_BIAS - 1) ? 1'b1 : 1'b0;
                word_cnt = word_cnt + 1;
            end
            #100;
        end

        S_AXIS_TVALID = 1'b0;
        S_AXIS_TLAST  = 1'b0;
        #100;
        @ (posedge ACLK);

        for (int test = 0; test < 5; test = test + 1) begin
            word_cnt = 'd0;
            // Load inputs
            $display("Starting input streaming...");
            S_AXIS_TVALID = 1'b1;
			while(word_cnt < NUM_INPUTS)
			begin
				if(S_AXIS_TREADY)	// S_AXIS_TREADY is asserted by the coprocessor in response to S_AXIS_TVALID
				begin
					S_AXIS_TDATA = data[word_cnt]; // set the next data ready
					if(word_cnt == NUM_INPUTS-1)
						S_AXIS_TLAST = 1'b1; 
					else
						S_AXIS_TLAST = 1'b0;
					word_cnt=word_cnt+1;
				end
				#100;			// wait for one clock cycle before for co-processor to capture data (if S_AXIS_TREADY was set) 				          // or before checking S_AXIS_TREADY again (if S_AXIS_TREADY was not set)
			end

            word_cnt = 0;
            S_AXIS_TVALID = 1'b0;
            S_AXIS_TLAST  = 1'b0;
            // Optionally finish the simulation
            // Note: result_memory is not written at a clock edge, which is fine as it is just a testbench construct and not actual hardware
            M_AXIS_TREADY = 1'b1;	// we are now ready to receive data
            while(M_AXIS_TLAST | ~M_AXIS_TLAST_prev) // receive data until the falling edge of M_AXIS_TLAST
            begin
                if(M_AXIS_TVALID)
                begin
                    result_memory[word_cnt] = M_AXIS_TDATA;
                    word_cnt = word_cnt+1;
                    $display("Output: %d:", M_AXIS_TDATA);
                end
                #100;
            end						// receive loop
            M_AXIS_TREADY = 1'b0;	// not ready to receive data from the co-processor anymore.	
        end
        $finish;
    end
endmodule