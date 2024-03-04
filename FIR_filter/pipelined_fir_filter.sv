// Implements the pipelined FIR filter
module Pipelined_FIR_Filter #(parameter int IN_WIDTH = 16, parameter int OUT_WIDTH = 40)(
    input clk,
    input logic signed[IN_WIDTH-1:0] x,
    output logic signed[OUT_WIDTH-1:0] y
);
`include "filter_parameters.sv"

// accumulator width is the maximum width the output of the filter can be
localparam ACCUM_WIDTH = IN_WIDTH + COEFF_WIDTH + $clog2(N_TAPS); // accum_width = input width + coeff width + log2(number taps)
logic signed[ACCUM_WIDTH-1:0] pipeline_regs[N_TAPS-1:1] = '{default:'0}; // pipeline registers, 0th pipeline register doesn't exist - it's just the output y

always_ff @(posedge clk)
begin
    pipeline_regs[N_TAPS-1] <= filter_coeffs[N_TAPS-1]*x;
    for(int i=N_TAPS-2; i > 0; i=i-1) begin
        pipeline_regs[i] <= filter_coeffs[i]*x + pipeline_regs[i+1]; // crticial path: 1 multiply + 1 add
    end
    y <= {filter_coeffs[0]*x + pipeline_regs[1]}[ACCUM_WIDTH-1:ACCUM_WIDTH-OUT_WIDTH]; // take the MSBs from the accumlated output
end
endmodule
