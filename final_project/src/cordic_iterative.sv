// Iterative implementation of CORDIC
module CORDIC_iterative #(parameter int LENGTH, parameter logic signed[15:0] GAIN, parameter logic signed[15:0] ATAN_LUT[0:LENGTH-1])(
    input  logic clk, start,
    output logic busy,
    input  logic signed[15:0] angle,
    output logic signed[15:0] sin, cos
);

logic signed[15:0] angle_diff_reg;
logic signed[15:0] x_reg;
logic signed[15:0] y_reg;

logic[$clog2(LENGTH)-1:0] iter_cnt = '0;

assign sin = (busy == 1'b0) ? y_reg : '0;
assign cos = (busy == 1'b0) ? x_reg : '0;

always_ff @(posedge clk) begin
    if (start == 1'b1) begin
        busy <= 1'b1;
        iter_cnt <= '0;
        x_reg <= GAIN;
        y_reg <= '0;
        angle_diff_reg <= ~angle + 1;
    end

    if (busy == 1'b1) begin
        iter_cnt <= iter_cnt + 1;

        // if angle difference is negative, rotate counter-clockwise
        if (angle_diff_reg < 0) begin
            angle_diff_reg <= angle_diff_reg + ATAN_LUT[iter_cnt];
            x_reg <= x_reg - (y_reg >>> iter_cnt);
            y_reg <= y_reg + (x_reg >>> iter_cnt);
        end
        // if angle difference is positive, rotate clockwise
        else begin
            angle_diff_reg <= angle_diff_reg - ATAN_LUT[iter_cnt];
            x_reg <= x_reg + (y_reg >>> iter_cnt);
            y_reg <= y_reg - (x_reg >>> iter_cnt);
        end

        if (iter_cnt == LENGTH-2) begin
            busy <= 1'b0;
        end
    end

end

endmodule