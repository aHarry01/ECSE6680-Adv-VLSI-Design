// Bit serial CORDIC algorithm
module CORDIC_bitserial #(parameter int LENGTH, parameter logic signed[15:0] GAIN, parameter logic signed[15:0] ATAN_LUT[0:LENGTH-1])(
    input clk, start,
    output logic busy,
    input logic signed[15:0] angle,
    output logic signed[15:0] sin, cos
);

logic signed[15:0] angle_diff_reg, atan_lut_reg;
logic signed[15:0] x_reg, x_shifted_reg;
logic signed[15:0] y_reg, y_shifted_reg;
logic[15:0] counter_shift_reg;
logic iter = 1'b0;
logic adding = 1'b0;
logic angle_diff_sign;
logic xAddOut, yAddOut, angleAddOut;

logic[$clog2(LENGTH):0] iter_cnt = '0;

assign sin = (busy == 1'b0) ? y_reg : '0;
assign cos = (busy == 1'b0) ? x_reg : '0;

assign busy = iter | adding;

always_ff @(posedge clk) begin
    if (start == 1'b1) begin
        iter <= 1'b1;
        iter_cnt <= '0;
        x_reg <= GAIN;
        y_reg <= '0;
        angle_diff_reg <= ~angle + 1;
    end

    if (iter == 1'b1) begin
        iter <= 1'b0;

        x_shifted_reg <= x_reg; //>> iter_cnt;
        y_shifted_reg <= y_reg; // >> iter_cnt;
        atan_lut_reg <= ATAN_LUT[iter_cnt];
        angle_diff_sign <= angle_diff_reg[15];

        if (iter_cnt == LENGTH) begin
            adding <= 1'b0;
            counter_shift_reg <= '0;
        end else begin
            adding <= 1'b1;
            counter_shift_reg <= 15'h0001;
        end
    end

    if (adding == 1'b1) begin
        counter_shift_reg <= {counter_shift_reg[14:0], 1'b0};
        if (counter_shift_reg == 16'h0000) begin
            adding <= 1'b0;
            iter <= 1'b1;
            iter_cnt <= iter_cnt + 1;
        end

        if (counter_shift_reg[0] == 1'b0) begin
            atan_lut_reg <= atan_lut_reg >> 1;
            angle_diff_reg <= {angleAddOut, angle_diff_reg[15:1]};
            x_reg <= {xAddOut, x_reg[15:1]};
            y_reg <= {yAddOut, y_reg[15:1]};
            x_shifted_reg <= x_shifted_reg >> 1;
            y_shifted_reg <= y_shifted_reg >> 1;
        end
    end
end



BitSerialAdder xAdd (
    .clk(clk), .reset(~adding),
    .addsub(angle_diff_sign), // subtract if angle_diff_reg < 0
    .bit0(x_reg[0]), .bit1(y_shifted_reg[iter_cnt]),
    .outbit(xAddOut)
);

BitSerialAdder yAdd (
    .clk(clk), .reset(~adding),
    .addsub(~angle_diff_sign), // subtract if angle_diff_reg > 0
    .bit0(y_reg[0]), .bit1(x_shifted_reg[iter_cnt]),
    .outbit(yAddOut)
);

BitSerialAdder angleAdd (
    .clk(clk), .reset(~adding),
    .addsub(~angle_diff_sign), // subtract if angle_diff_reg > 0
    .bit0(angle_diff_reg[0]), .bit1(atan_lut_reg[0]),
    .outbit(angleAddOut)
);

endmodule

// Compute an addition/subtraction one bit at a time
module BitSerialAdder (
    input logic clk, reset,
    input addsub,
    input bit0, bit1,
    output outbit
);
    logic carry_in, carry_out, carry_invert_out, carry_invert_in;
    logic tmp_bit1, reset_delayed;

    // full adder
    assign outbit = bit0 ^ tmp_bit1 ^ carry_in;
    assign carry_out = (reset == 1'b0) ? (bit0 & tmp_bit1) | (bit0 & carry_in) | (tmp_bit1 & carry_in) : 1'b0;

    // invert the second operand bit-by-bit if this is a subtraction
    assign carry_invert_out = (reset_delayed == 1'b0) ? (1'b0 & ~bit1) | (1'b0 & carry_invert_in) | (~bit1 & carry_invert_in) : 1'b1;
    assign tmp_bit1 = (addsub == 1'b1) ? ~bit1 ^ 1'b0 ^ carry_invert_in : bit1;

    // flip flop to hold the carry bit for the next iteration
    always_ff @(posedge clk) begin
        carry_in <= carry_out;
        reset_delayed <= reset;
        carry_invert_in <= carry_invert_out;
    end

endmodule
