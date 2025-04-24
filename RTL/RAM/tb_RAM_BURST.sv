`timescale 1ns / 1ps

module tb_RAM_BURST;
    // Parameters
    localparam WIDTH = 8;
    localparam BURST_LEN = 4;
    localparam DEPTH = 1024;
    localparam DEPTH_BITS = $clog2(DEPTH);
    
    // Clock and control signals
    logic clk = 0;
    
    // Write port signals
    logic write_en;
    logic [DEPTH_BITS-1:0] write_address;
    logic [WIDTH-1:0] write_data_in;
    
    // Read port signals
    logic read_en;
    logic [DEPTH_BITS-1:0] read_address;
    logic [BURST_LEN*WIDTH-1:0] read_data_out;
    
    // Expected data storage for verification
    logic [WIDTH-1:0] expected_data [DEPTH-1:0];
    logic [WIDTH-1:0] read_data_array [0:BURST_LEN-1];
    
    // Instantiate the RAM_BURST module
    RAM_BURST #(
        .WIDTH(WIDTH),
        .BURST_LEN(BURST_LEN),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .write_en(write_en),
        .write_address(write_address),
        .write_data_in(write_data_in),
        .read_en(read_en),
        .read_address(read_address),
        .read_data_out(read_data_out)
    );
    
    // Clock generation
    always #5 clk = ~clk;  // 100MHz clock
    
    // Test stimulus and checking
    initial begin
        // Initialize signals
        write_en = 0;
        write_address = 0;
        write_data_in = 0;
        read_en = 0;
        read_address = 0;
        
        // Wait for a few clock cycles to stabilize
        repeat(5) @(posedge clk);
        
        $display("Writing sequential data to memory...");
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge clk);
            write_en = 1;
            write_address = i;
            write_data_in = i % 256;  // Use modulo to keep within WIDTH range
            
            // Store expected data for verification
            expected_data[i] = i % 256;
            
            // Wait for write to complete
            @(posedge clk);
        end
        write_en = 0;
        
        $display("Reading back data in burst mode...");
        for (int i = 0; i < DEPTH; i += BURST_LEN) begin
            @(posedge clk);
            read_en = 1;
            read_address = i;
            
            // Wait two clock cycles for read data to be valid
            repeat(2) @(posedge clk);
            read_en = 0;
            
            // Check burst read data
            $display("Reading address %0d: Expected %h %h %h %h, Got %h", 
                     i, 
                     expected_data[i], expected_data[i+1], expected_data[i+2], expected_data[i+3],
                     read_data_out);
        end
        // Write specific pattern to 4 consecutive addresses
        @(posedge clk);
        write_en = 1;
        write_address = 100;
        write_data_in = 8'hAA;
        @(posedge clk);
        write_address = 101;
        write_data_in = 8'hBB;
        @(posedge clk);
        write_address = 102;
        write_data_in = 8'hCC;
        @(posedge clk);
        write_address = 103;
        write_data_in = 8'hDD;
        @(posedge clk);
        write_en = 0;
        
        // Update expected data
        expected_data[100] = 8'hAA;
        expected_data[101] = 8'hBB;
        expected_data[102] = 8'hCC;
        expected_data[103] = 8'hDD;
        
        // Read back as burst
        @(posedge clk);
        read_en = 1;
        read_address = 100;
        
        // Wait two clock cycles for read data to be valid
        repeat(2) @(posedge clk);
        read_en = 0;
        
        // Display raw burst read data
        $display("Burst read from address 100: %h", read_data_out);
        
        // Verify individual bytes and their positions
        $display("Byte 0: %h (Expected: %h)", read_data_out[7:0], expected_data[103]);
        $display("Byte 1: %h (Expected: %h)", read_data_out[15:8], expected_data[102]);
        $display("Byte 2: %h (Expected: %h)", read_data_out[23:16], expected_data[101]);
        $display("Byte 3: %h (Expected: %h)", read_data_out[31:24], expected_data[100]);
        
        // Finish simulation
        repeat(5) @(posedge clk);
        $display("Testbench completed successfully!");
        $finish;
    end
endmodule