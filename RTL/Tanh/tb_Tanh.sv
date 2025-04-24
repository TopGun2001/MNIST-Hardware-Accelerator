`timescale 1ns/1ps

module tb_Tanh;

  // Parameters (matching the DUT parameters)
  localparam integer INPUT_SIZE    = 32;
  localparam integer OUTPUT_SIZE   = 32;
  localparam integer WEIGHTS_WIDTH = 8;
  localparam integer UNROLL_FACTOR = 4;
  localparam integer BIAS_WIDTH    = 32;
  localparam logic [31:0] SCALER   = 32'h3d0090cc;

  // Signal declarations
  logic clk;
  logic start;
  logic done;
  // The input and output arrays.
  logic signed [BIAS_WIDTH-1:0] inputs [0:INPUT_SIZE-1];
  logic signed [WEIGHTS_WIDTH-1:0] layer_out [0:OUTPUT_SIZE-1];

  // Clock generation: 10 ns period (100 MHz)
  initial clk = 0;
  always #5 clk = ~clk;

  // Instantiate the DUT (Device Under Test)
  Tanh #(
    .INPUT_SIZE(INPUT_SIZE),
    .OUTPUT_SIZE(OUTPUT_SIZE),
    .WEIGHTS_WIDTH(WEIGHTS_WIDTH),
    .UNROLL_FACTOR(UNROLL_FACTOR),
    .BIAS_WIDTH(BIAS_WIDTH),
    .SCALER(SCALER)
  ) dut (
    .clk(clk),
    .start(start),
    .done(done),
    .inputs(inputs),
    .layer_out(layer_out)
  );

  // Test stimulus and comparison
  initial begin
    integer i;
    integer mismatches = 0;
    real in_real;     // The real-valued input after scaling
    real tanh_val;    // The golden tanh value in real numbers
    integer expected; // The quantized (8-bit) expected output

    // Initialize start signal and (if needed) reset signals.
    start = 0;

    // Initialize the inputs with a known or random pattern.
    for (i = 0; i < INPUT_SIZE; i = i + 1) begin
      inputs[i] = $random; // You can change this to a specific test pattern if desired.
    end

    // Wait a few clock cycles before starting.
    #20;
    $display("Starting simulation...");

    // Assert start for one clock cycle.
    start = 1;
    #10;  // Hold start high for one clock period.
    start = 0;

    // Wait until the module asserts done.
    wait(done);
    #20;  // Extra delay to ensure outputs are stable.

    // Display the DUT outputs.
    for (i = 0; i < OUTPUT_SIZE; i = i + 1) begin
      $display("DUT layer_out[%0d] = %0d", i, layer_out[i]);
    end

    for (i = 0; i < OUTPUT_SIZE; i = i + 1) begin
      // Convert the input to a real number and multiply by scaler
      in_real = $itor(inputs[i]) * $itor(SCALER);
      
      // Compute tanh using the mathematical identity.
      // (A more robust implementation might check for overflow, but for a testbench this is acceptable.)
      tanh_val = $tanh(in_real);

      // Quantize the real tanh result into an 8-bit signed integer.
      expected = (tanh_val < 0.0) ? $rtoi(tanh_val * 128.0) : $rtoi(tanh_val * 127.0);

      // Compare the expected value to the DUT output.
      if (expected !== layer_out[i]) begin
        $display("Mismatch at index %0d: expected %0d, got %0d", i, expected, layer_out[i]);
        mismatches = mismatches + 1;
      end else begin
        $display("Match at index %0d: value = %0d", i, layer_out[i]);
      end
    end

    if (mismatches != 0) begin
      $display("Total mismatches: %0d", mismatches);
    end else begin
      $display("All outputs match the expected tanh values.");
    end

    $display("Simulation complete.");
    $finish;
  end

endmodule
