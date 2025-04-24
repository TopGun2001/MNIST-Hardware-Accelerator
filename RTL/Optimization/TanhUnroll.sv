`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.04.2025 13:58:03
// Design Name: 
// Module Name: TanhUnroll
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

module TanhUnroll#(
    parameter integer INPUT_SIZE    = 512,
    parameter integer OUTPUT_SIZE   = 512,
    parameter integer WEIGHTS_WIDTH = 8,
    parameter integer BIAS_WIDTH    = 32,
    parameter logic [31:0] SCALER = 32'h3d0090cc // 32b float
)(
    input  logic clk,
    input  logic start,
    output logic done,
    input  logic signed [BIAS_WIDTH-1:0] inputs , // 32b integer
    output logic signed [WEIGHTS_WIDTH-1:0] layer_out // 8b integer
);  
 
    // CONVERT int32_to_float32_inst
    logic s_axis_a_tvalid_CONVERT;
    logic s_axis_a_tready_CONVERT;
    logic [31:0] s_axis_a_tdata_CONVERT;
    logic m_axis_result_tvalid_CONVERT;
    logic [31:0] m_axis_result_tdata_CONVERT;
    logic [31:0] input_float;
    
    // MULTIPLY float32_multiply_float32
    logic s_axis_a_tvalid_MULTIPLY;
    logic [31:0] s_axis_a_tdata_MULTIPLY;
    logic s_axis_b_tvalid_MULTIPLY;
    logic [31:0] s_axis_b_tdata_MULTIPLY;
    logic m_axis_result_tvalid_MULTIPLY;
    logic [31:0] m_axis_result_tdata_MULTIPLY;
    logic [31:0] multiply_float;
    
    // SINH COSH
    logic s_axis_phase_tvalid_SINH_COSH;
    logic [31:0] s_axis_phase_tdata_SINH_COSH;
    logic m_axis_dout_tvalid_SINH_COSH;
    logic [63:0] m_axis_dout_tdata_SINH_COSH;
    logic [31:0] sinh_float;
    logic [31:0] cosh_float;
    
    // TANH
    logic s_axis_a_tvalid_TANH;
    logic s_axis_a_tready_TANH;
    logic [31:0] s_axis_a_tdata_TANH;
    logic s_axis_b_tvalid_TANH;
    logic s_axis_b_tready_TANH;
    logic [31:0] s_axis_b_tdata_TANH;
    logic m_axis_result_tvalid_TANH;
    logic m_axis_result_tready_TANH;
    logic [31:0] m_axis_result_tdata_TANH;
    logic [31:0] tanh_float;
    
    // TRUNCATE
    logic s_axis_a_tvalid_TRUNCATE;
    logic s_axis_a_tready_TRUNCATE;
    logic [31:0] s_axis_a_tdata_TRUNCATE;
    logic m_axis_result_tvalid_TRUNCATE;
    logic [7:0] m_axis_result_tdata_TRUNCATE;
    logic [7:0] tanh_int;

    // State Machine States
    typedef enum logic [4:0] {
        IDLE = 5'd0,
        CONVERT = 5'd1,
        CONVERT_DONE = 5'd2,
        MULTIPLY = 5'd3,
        MULTIPLY_DONE = 5'd4,
        SINH_COSH = 5'd5,
        SINH_COSH_DONE = 5'd6,
        TANH = 5'd7,
        TANH_DONE = 5'd8,
        TRUNCATE = 5'd9,
        TRUNCATE_DONE = 5'd10,
        DONE = 5'd11
    } state_t;

    state_t state = IDLE; // Initial state
    always_ff @(posedge clk) begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                input_float <= 'b0;
                multiply_float <= 'b0;
                // All signals to modules
                s_axis_a_tvalid_CONVERT <= 1'b0;
                s_axis_a_tvalid_MULTIPLY <= 1'b0;
                s_axis_b_tvalid_MULTIPLY <= 1'b0;
                s_axis_phase_tvalid_SINH_COSH <= 1'b0;
                s_axis_a_tvalid_TANH <= 1'b0;
                s_axis_b_tvalid_TANH <= 1'b0;
                m_axis_result_tready_TANH <= 1'b0;
                s_axis_a_tvalid_TRUNCATE <= 1'b0;
                if (start) begin
                    state <= CONVERT;
                end
            end
            CONVERT: begin
                if (s_axis_a_tready_CONVERT) begin
                    s_axis_a_tvalid_CONVERT <= 1'b1;
                    s_axis_a_tdata_CONVERT <= inputs;
                    state <= CONVERT_DONE;
                end else begin
                    s_axis_a_tvalid_CONVERT <= 1'b0;
                    state <= CONVERT;
                end
            end
            CONVERT_DONE: begin
                s_axis_a_tvalid_CONVERT <= 1'b0;
                if (m_axis_result_tvalid_CONVERT) begin
                    input_float <= m_axis_result_tdata_CONVERT;
                    state <= MULTIPLY;
                end else begin
                    state <= CONVERT_DONE;
                end
            end
            MULTIPLY: begin
                s_axis_a_tvalid_MULTIPLY <= 1'b1;
                s_axis_a_tdata_MULTIPLY <= input_float;
                s_axis_b_tvalid_MULTIPLY <= 1'b1;
                s_axis_b_tdata_MULTIPLY <= SCALER;
                state <= MULTIPLY_DONE;
            end
            MULTIPLY_DONE: begin
                s_axis_a_tvalid_MULTIPLY <= 1'b0;
                s_axis_a_tdata_MULTIPLY <= 'b0;
                s_axis_b_tvalid_MULTIPLY <= 1'b0;
                s_axis_b_tdata_MULTIPLY <= 'b0;
                if (m_axis_result_tvalid_MULTIPLY) begin
                    multiply_float <= m_axis_result_tdata_MULTIPLY;
                    state <= SINH_COSH;
                end else begin
                    state <= MULTIPLY_DONE;
                end
            end
            SINH_COSH: begin
                s_axis_phase_tvalid_SINH_COSH <= 1'b1;
                s_axis_phase_tdata_SINH_COSH <= multiply_float;
                state <= SINH_COSH_DONE;
            end
            SINH_COSH_DONE: begin
                s_axis_phase_tvalid_SINH_COSH <= 1'b0;
                s_axis_phase_tdata_SINH_COSH <= 'b0;
                if (m_axis_dout_tvalid_SINH_COSH) begin
                    cosh_float <= m_axis_dout_tdata_SINH_COSH[63:32];
                    sinh_float <= m_axis_dout_tdata_SINH_COSH[31:0];
                    state <= TANH;
                end else begin
                    state <= SINH_COSH_DONE;
                end
            end
            TANH: begin
                if (s_axis_a_tready_TANH && s_axis_b_tready_TANH) begin
                    s_axis_a_tvalid_TANH <= 1'b1;
                    s_axis_b_tvalid_TANH <= 1'b1;          
                    s_axis_a_tdata_TANH <= sinh_float;     
                    s_axis_b_tdata_TANH <= cosh_float;
                    m_axis_result_tready_TANH <= 1'b1;
                    state <= TANH_DONE;
                end else begin
                    state <= TANH;
                end
            end
            TANH_DONE: begin
                s_axis_a_tvalid_TANH <= 1'b0;
                s_axis_b_tvalid_TANH <= 1'b0;          
                s_axis_a_tdata_TANH <= 'b0;     
                s_axis_b_tdata_TANH <= 'b0;
                if (m_axis_result_tvalid_TANH) begin
                    m_axis_result_tready_TANH <= 1'b0;
                    tanh_float <= m_axis_result_tdata_TANH;
                    state <= TRUNCATE;
                end else begin
                    m_axis_result_tready_TANH <= 1'b1;
                    state <= TANH_DONE;
                end
            end
            TRUNCATE: begin
                if (s_axis_a_tready_TRUNCATE) begin
                    s_axis_a_tvalid_TRUNCATE <= 1'b1;
                    s_axis_a_tdata_TRUNCATE <= tanh_float;
                    state <= TRUNCATE_DONE;
                end else begin
                    state <= TRUNCATE;
                end
            end
            TRUNCATE_DONE: begin
                s_axis_a_tvalid_TRUNCATE <= 1'b0;
                s_axis_a_tdata_TRUNCATE <= 'b0;
                if (m_axis_result_tvalid_TRUNCATE) begin
                    tanh_int <= m_axis_result_tdata_TRUNCATE;
                    state <= DONE;
                end else begin
                    state <= TRUNCATE_DONE;
                end
            end
            DONE: begin
                    layer_out <= tanh_int;
                    
                    done <= 1'b1;
                    state <= IDLE;
                  end
        endcase
    end
    
    // CONVERT
    int32_to_float32 int32_to_float32_inst (
      .aclk(clk),                                  // input wire aclk
      .s_axis_a_tvalid(s_axis_a_tvalid_CONVERT),            // input wire s_axis_a_tvalid
      .s_axis_a_tready(s_axis_a_tready_CONVERT),            // output wire s_axis_a_tready
      .s_axis_a_tdata(s_axis_a_tdata_CONVERT),              // input wire [31 : 0] s_axis_a_tdata
      .m_axis_result_tvalid(m_axis_result_tvalid_CONVERT),  // output wire m_axis_result_tvalid
      .m_axis_result_tdata(m_axis_result_tdata_CONVERT)    // output wire [31 : 0] m_axis_result_tdata
    );

    // MULTIPLY
    float32_multiply_float32 float32_multiply_float32_inst (
      .aclk(clk),                                  // input wire aclk
      .s_axis_a_tvalid(s_axis_a_tvalid_MULTIPLY),            // input wire s_axis_a_tvalid
      .s_axis_a_tdata(s_axis_a_tdata_MULTIPLY),              // input wire [31 : 0] s_axis_a_tdata
      .s_axis_b_tvalid(s_axis_b_tvalid_MULTIPLY),            // input wire s_axis_b_tvalid
      .s_axis_b_tdata(s_axis_b_tdata_MULTIPLY),              // input wire [31 : 0] s_axis_b_tdata
      .m_axis_result_tvalid(m_axis_result_tvalid_MULTIPLY),  // output wire m_axis_result_tvalid
      .m_axis_result_tdata(m_axis_result_tdata_MULTIPLY)    // output wire [31 : 0] m_axis_result_tdata
    );
    
    // SINH COSH
    Sinh_Cosh Sinh_Cosh_inst (
      .aclk(clk),                                // input wire aclk
      .s_axis_phase_tvalid(s_axis_phase_tvalid_SINH_COSH),  // input wire s_axis_phase_tvalid
      .s_axis_phase_tdata(s_axis_phase_tdata_SINH_COSH),    // input wire [31 : 0] s_axis_phase_tdata
      .m_axis_dout_tvalid(m_axis_dout_tvalid_SINH_COSH),    // output wire m_axis_dout_tvalid
      .m_axis_dout_tdata(m_axis_dout_tdata_SINH_COSH)      // output wire [63 : 0] m_axis_dout_tdata
    );
    
    // TANH
    sinh_divide_tanh sinh_divide_tanh_inst (
      .aclk(clk),                                  // input wire aclk
      .s_axis_a_tvalid(s_axis_a_tvalid_TANH),            // input wire s_axis_a_tvalid
      .s_axis_a_tready(s_axis_a_tready_TANH),            // output wire s_axis_a_tready
      .s_axis_a_tdata(s_axis_a_tdata_TANH),              // input wire [31 : 0] s_axis_a_tdata
      .s_axis_b_tvalid(s_axis_b_tvalid_TANH),            // input wire s_axis_b_tvalid
      .s_axis_b_tready(s_axis_b_tready_TANH),            // output wire s_axis_b_tready
      .s_axis_b_tdata(s_axis_b_tdata_TANH),              // input wire [31 : 0] s_axis_b_tdata
      .m_axis_result_tvalid(m_axis_result_tvalid_TANH),  // output wire m_axis_result_tvalid
      .m_axis_result_tready(m_axis_result_tready_TANH),  // input wire m_axis_result_tready
      .m_axis_result_tdata(m_axis_result_tdata_TANH)    // output wire [31 : 0] m_axis_result_tdata
    );
    
    // TRUNCATE
    float32_to_int8 float32_to_int8_inst (
      .aclk(clk),                                  // input wire aclk
      .s_axis_a_tvalid(s_axis_a_tvalid_TRUNCATE),            // input wire s_axis_a_tvalid
      .s_axis_a_tready(s_axis_a_tready_TRUNCATE),            // output wire s_axis_a_tready
      .s_axis_a_tdata(s_axis_a_tdata_TRUNCATE),              // input wire [31 : 0] s_axis_a_tdata
      .m_axis_result_tvalid(m_axis_result_tvalid_TRUNCATE),  // output wire m_axis_result_tvalid
      .m_axis_result_tdata(m_axis_result_tdata_TRUNCATE)    // output wire [7 : 0] m_axis_result_tdata
    );
endmodule
