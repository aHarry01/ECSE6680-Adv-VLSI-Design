// Basic CORDIC algorithm, pipelined but no other optimizations
module CORDIC #(parameter int LENGTH, parameter logic signed[15:0] GAIN, parameter logic signed[15:0] ATAN_LUT[0:LENGTH-1])(
    input clk,
    input logic signed[15:0] angle,
    output logic signed[15:0] sin, cos
);

// pipelined registers
logic signed[15:0] angle_diff_regs[LENGTH:0];
logic signed[15:0] x_regs[LENGTH:0];
logic signed[15:0] y_regs[LENGTH:0];

assign cos = x_regs[LENGTH];
assign sin = y_regs[LENGTH];

always_ff @(posedge clk) begin
    x_regs[0] <= GAIN;
    y_regs[0] <= '0;
    angle_diff_regs[0] <= ~angle + 1; // start out negative

    // rotate the angle with decreasing angles
    for (int i = 0; i < LENGTH; i++) begin
        // if angle difference is negative, rotate counter-clockwise
        if (angle_diff_regs[i] < 0) begin
            angle_diff_regs[i+1] <= angle_diff_regs[i] + ATAN_LUT[i];
            x_regs[i+1] <= x_regs[i] - (y_regs[i] >>> i);
            y_regs[i+1] <= y_regs[i] + (x_regs[i] >>> i);
        end
        // if angle difference is positive, rotate clockwise
        else begin
            angle_diff_regs[i+1] <= angle_diff_regs[i] - ATAN_LUT[i];
            x_regs[i+1] <= x_regs[i] + (y_regs[i] >>> i);
            y_regs[i+1] <= y_regs[i] - (x_regs[i] >>> i);
        end
    end
end

endmodule