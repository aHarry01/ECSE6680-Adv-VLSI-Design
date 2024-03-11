// Implements a reduced complexity L-parallel FIR filter without pipelining
module Parallel_FIR_Filter #(parameter int L=2, parameter int IN_WIDTH = 16, parameter int OUT_WIDTH = 40,
                             parameter int USE_PIPELINING)(
    input clk,
    input logic signed[IN_WIDTH-1:0] x[L-1:0], // L inputs
    output logic signed[OUT_WIDTH-1:0] y[L-1:0] // L outputs
);
`include "filter_parameters.sv"

// split the coefficients into the required sub-filters (e.g. for L=2 they are H0, H1, and H0+H1)
typedef logic signed[COEFF_WIDTH-1:0] subfilter_arr_t[0:(N_TAPS/L)-1];
function subfilter_arr_t create_subfilter(int offset);
    // splits filter_coeffs into subfilter with given offset
    for (int i = 0; i < N_TAPS/L; i++) begin
        create_subfilter[i] = filter_coeffs[L*i + offset];
    end
endfunction

function subfilter_arr_t add_subfilters(subfilter_arr_t f1, subfilter_arr_t f2);
    // adds subfilters
    for (int i = 0; i < N_TAPS/L; i++) begin
        add_subfilters[i] = f1[i] + f2[i];
    end
endfunction

generate
    // 2-parallel filter
    if (L == 2) begin
        localparam logic signed[COEFF_WIDTH-1:0] filter_coeffs_H0[0:(N_TAPS/L)-1] = create_subfilter(0);
        localparam logic signed[COEFF_WIDTH-1:0] filter_coeffs_H1[0:(N_TAPS/L)-1] = create_subfilter(1);
        localparam logic signed[COEFF_WIDTH-1:0] filter_coeffs_H0H1[0:(N_TAPS/L)-1] = add_subfilters(filter_coeffs_H0, filter_coeffs_H1);

        logic signed[OUT_WIDTH-1:0] H0_output, H1_output, H0H1_output, delayed_H1_output;
        logic signed[IN_WIDTH:0] inputs_added;

        assign inputs_added = {x[0][IN_WIDTH-1], x[0]} + {x[1][IN_WIDTH-1], x[1]}; // sign-extend inputs by 1 bit to avoid overflow when adding

        FIR_Filter #(.subfilter_taps(N_TAPS/L), .subfilter_coeffs(filter_coeffs_H0)) H0_filter (
            .clk(clk),
            .x(x[0]),
            .y(H0_output)
        );

        FIR_Filter #(.subfilter_taps(N_TAPS/L), .subfilter_coeffs(filter_coeffs_H1)) H1_filter (
            .clk(clk),
            .x(x[1]),
            .y(H1_output)
        );

        FIR_Filter #(.IN_WIDTH(IN_WIDTH+1), .subfilter_taps(N_TAPS/L), .subfilter_coeffs(filter_coeffs_H0H1)) H0H1_filter (
            .clk(clk),
            .x(inputs_added),
            .y(H0H1_output)
        );

        always_ff @(posedge clk)
        begin
            delayed_H1_output <= H1_output;
        end

        assign y[0] = H0_output + delayed_H1_output; // y(2k)
        assign y[1] = H0H1_output - H0_output - H1_output; // y(2k+1)

    end

    // 3-parallel filter
    else if (L == 3) begin
        localparam logic signed[COEFF_WIDTH-1:0] filter_coeffs_H0[0:(N_TAPS/L)-1] = create_subfilter(0);
        localparam logic signed[COEFF_WIDTH-1:0] filter_coeffs_H1[0:(N_TAPS/L)-1] = create_subfilter(1);
        localparam logic signed[COEFF_WIDTH-1:0] filter_coeffs_H2[0:(N_TAPS/L)-1] = create_subfilter(2);
        localparam logic signed[COEFF_WIDTH-1:0] filter_coeffs_H0H1[0:(N_TAPS/L)-1] = add_subfilters(filter_coeffs_H0, filter_coeffs_H1);
        localparam logic signed[COEFF_WIDTH-1:0] filter_coeffs_H1H2[0:(N_TAPS/L)-1] = add_subfilters(filter_coeffs_H1, filter_coeffs_H2);
        localparam logic signed[COEFF_WIDTH-1:0] filter_coeffs_H0H1H2[0:(N_TAPS/L)-1] = add_subfilters(filter_coeffs_H0H1, filter_coeffs_H2);


        logic signed[OUT_WIDTH-1:0] H0_output, H1_output, H2_output, H0H1_output, H1H2_output, H0H1H2_output, delayed_H2_output, H0H1_minus_H1, H0_minus_H2_delayed, H1H2_minus_H1, delayed_H1H2_minus_H1;
        logic signed[IN_WIDTH:0] inputs_added_x0x1, inputs_added_x1x2;
        logic signed[IN_WIDTH+1:0] inputs_added_all;

        assign inputs_added_x0x1 = {x[0][IN_WIDTH-1], x[0]} + {x[1][IN_WIDTH-1], x[1]}; // sign extend to avoid overflow when adding inputs
        assign inputs_added_x1x2 = {x[1][IN_WIDTH-1], x[1]} + {x[2][IN_WIDTH-1], x[2]}; // sign extend to avoid overflow when adding inputs
        assign inputs_added_all = {inputs_added_x0x1[IN_WIDTH], inputs_added_x0x1} + { {2{x[2][IN_WIDTH-1]}}, x[2]}; // sign extend to avoid overflow when adding inputs

        FIR_Filter #(.subfilter_taps(N_TAPS/L), .subfilter_coeffs(filter_coeffs_H0)) H0_filter (
            .clk(clk),
            .x(x[0]),
            .y(H0_output)
        );

        FIR_Filter #(.subfilter_taps(N_TAPS/L), .subfilter_coeffs(filter_coeffs_H1)) H1_filter (
            .clk(clk),
            .x(x[1]),
            .y(H1_output)
        );

        FIR_Filter #(.subfilter_taps(N_TAPS/L), .subfilter_coeffs(filter_coeffs_H2)) H2_filter (
            .clk(clk),
            .x(x[2]),
            .y(H2_output)
        );

        FIR_Filter #(.subfilter_taps(N_TAPS/L), .subfilter_coeffs(filter_coeffs_H0H1), .IN_WIDTH(IN_WIDTH + 1)) H0H1_filter (
            .clk(clk),
            .x(inputs_added_x0x1),
            .y(H0H1_output)
        );

        FIR_Filter #(.subfilter_taps(N_TAPS/L), .subfilter_coeffs(filter_coeffs_H1H2), .IN_WIDTH(IN_WIDTH + 1)) H1H2_filter (
            .clk(clk),
            .x(inputs_added_x1x2),
            .y(H1H2_output)
        );

        FIR_Filter #(.subfilter_taps(N_TAPS/L), .subfilter_coeffs(filter_coeffs_H0H1H2), .IN_WIDTH(IN_WIDTH + 2)) H0H1H2_filter (
            .clk(clk),
            .x(inputs_added_all),
            .y(H0H1H2_output)
        );

        always_ff @(posedge clk)
        begin
            delayed_H2_output <= H2_output;
            delayed_H1H2_minus_H1 <= H1H2_minus_H1;
        end

        assign H1H2_minus_H1 = H1H2_output - H1_output;
        assign H0H1_minus_H1 = H0H1_output - H1_output;
        assign H0_minus_H2_delayed = H0_output - delayed_H2_output;
        assign y[0] = H0_minus_H2_delayed + delayed_H1H2_minus_H1; // y(3k)
        assign y[1] = H0H1_minus_H1 - H0_minus_H2_delayed; // y(3k+1)
        assign y[2] = H0H1H2_output - H0H1_minus_H1 - H1H2_minus_H1; // y(3k+2)

    end
endgenerate

// FIR filter that is used as sub-filters
module FIR_Filter #(parameter int IN_WIDTH = 16, parameter int OUT_WIDTH = 40, parameter int COEFF_WIDTH = 16,
                    parameter int subfilter_taps, parameter subfilter_arr_t subfilter_coeffs)(
    input clk,
    input logic signed[IN_WIDTH-1:0] x,
    output logic signed[OUT_WIDTH-1:0] y
);

    generate
    // use pipelined FIR filters
    if (USE_PIPELINING == 1) begin
        logic signed[OUT_WIDTH-1:0] pipeline_regs[N_TAPS-1:1] = '{default:'0}; // pipeline registers, 0th pipeline register doesn't exist - it's just the output y

        always_ff @(posedge clk)
        begin
            pipeline_regs[N_TAPS-1] <= subfilter_coeffs[subfilter_taps-1]*x;
            for(int i=subfilter_taps-2; i > 0; i=i-1) begin
                pipeline_regs[i] <= subfilter_coeffs[i]*x + pipeline_regs[i+1]; // crticial path: 1 multiply + 1 add
            end
            y <= subfilter_coeffs[0]*x + pipeline_regs[1]; // take the MSBs from the accumlated output
        end
    end

    // use non-pipelined FIR filters
    else begin
        logic signed[OUT_WIDTH-1:0] delayed_input[subfilter_taps-2:0] = '{default:'0};
        logic signed[OUT_WIDTH-1:0] y_comb;

        // critical path - N_TAPS-1 additions + 1 multiply
        always_comb begin
            y_comb = x*subfilter_coeffs[0];
            for (int i = 1; i < subfilter_taps; i++) begin
                y_comb = y_comb + delayed_input[i-1]*subfilter_coeffs[i];
            end
        end

        always_ff @(posedge clk)
        begin
            delayed_input[0] <= x;
            for (int i=1; i < subfilter_taps-1; i++) begin
                delayed_input[i] <= delayed_input[i-1];
            end
            y <= y_comb;
        end
    end

    endgenerate
endmodule

endmodule


