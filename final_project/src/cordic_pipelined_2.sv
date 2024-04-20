// Loop-unrolled CORDIC, pipelined registers every 2 iterations
module CORDIC_pipelined2 #(parameter int LENGTH, parameter logic signed[15:0] GAIN, parameter logic signed[15:0] ATAN_LUT[0:LENGTH-1])(
    input clk,
    input logic signed[15:0] angle,
    output logic signed[15:0] sin, cos
);

// pipelined registers
logic signed[15:0] angle_diff_regs[LENGTH/2:0];
logic signed[15:0] x_regs[LENGTH/2:0];
logic signed[15:0] y_regs[LENGTH/2:0];

logic signed[15:0] angle_comb_out[LENGTH/2 - 1:0];
logic signed[15:0] x_comb_out[LENGTH/2 - 1:0];
logic signed[15:0] y_comb_out[LENGTH/2 - 1:0];

assign cos = x_regs[LENGTH/2];
assign sin = y_regs[LENGTH/2];

// generate LENGTH/2 unrolled blocks that each compute 2 iterations

generate
    for (genvar i = 0; i < LENGTH/2; i++) begin
        always_comb begin
            // intermediate wires inside unrolled logic block (scoped for only this always block)
            logic signed[15:0] angle_diff_tmp, y_tmp, x_tmp;
            // inputs x_regs[i], y_regs[i], and angle_diff_regs[i]
            // outputs angled_comb_out[i], x_comb_out[i], y_comb_out[i]

            if (angle_diff_regs[i] < 0) begin
                angle_diff_tmp = angle_diff_regs[i] + ATAN_LUT[i <<< 1];
                x_tmp = x_regs[i] - (y_regs[i] >>> (i <<< 1));
                y_tmp = y_regs[i] + (x_regs[i] >>> (i <<< 1));
            end
            else begin
                angle_diff_tmp = angle_diff_regs[i] - ATAN_LUT[i <<< 1];
                x_tmp = x_regs[i] + (y_regs[i] >>> (i <<< 1));
                y_tmp = y_regs[i] - (x_regs[i] >>> (i <<< 1));
            end

            if (angle_diff_tmp < 0) begin
                angle_comb_out[i] = angle_diff_tmp + ATAN_LUT[(i <<< 1)+1];
                x_comb_out[i] = x_tmp - (y_tmp >>> ((i <<< 1)+1));
                y_comb_out[i] = y_tmp + (x_tmp >>> ((i <<< 1)+1));
            end
            else begin
                angle_comb_out[i] = angle_diff_tmp - ATAN_LUT[(i <<< 1)+1];
                x_comb_out[i] = x_tmp + (y_tmp >>> ((i <<< 1)+1));
                y_comb_out[i] = y_tmp - (x_tmp >>> ((i <<< 1)+1));
            end

        end
    end
endgenerate



always_ff @(posedge clk) begin
    x_regs[0] <= GAIN;
    y_regs[0] <= '0;
    angle_diff_regs[0] <= ~angle + 1; // start out negative

    // rotate the angle with decreasing angles
    for (int i = 0; i < LENGTH/2; i++) begin
        angle_diff_regs[i+1] <= angle_comb_out[i];
        x_regs[i+1] <= x_comb_out[i];
        y_regs[i+1] <= y_comb_out[i];
    end
end

endmodule