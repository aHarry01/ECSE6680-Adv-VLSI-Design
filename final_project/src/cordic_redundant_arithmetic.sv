// Redundant Arithmetic CORDIC algorithm
module CORDIC_redundant_arithmetic #(parameter int LENGTH, parameter logic signed[15:0] GAIN, parameter logic signed[15:0] ATAN_LUT[0:LENGTH-1])(
    input clk,
    input logic signed[15:0] angle,
    output logic signed[15:0] sin, cos
);
    logic signed[31:0] x_initial, out;
    ConvertSignedToRedundantArith convertGAIN(GAIN, x_initial);

    // // pipelined registers
    // logic signed[15:0] angle_diff_regs[LENGTH:0];
    // logic signed[31:0] x_regs[LENGTH:0];
    // logic signed[31:0] y_regs[LENGTH:0];

    // assign cos = x_regs[LENGTH];
    // assign sin = y_regs[LENGTH];

    // always_ff @(posedge clk) begin
    //     x_regs[0] <= x_initial;
    //     y_regs[0] <= 32'h55555555; // zeros are 01 or 10
    //     angle_diff_regs[0] <= ~angle + 1; // start out negative

    //     // rotate the angle with decreasing angles
    //     for (int i = 0; i < LENGTH; i++) begin
    //         // if angle difference is negative, rotate counter-clockwise
    //         if (angle_diff_regs[i] < 0) begin
    //             angle_diff_regs[i+1] <= angle_diff_regs[i] + ATAN_LUT[i];
    //             x_regs[i+1] <= x_regs[i] - (y_regs[i] >>> i);
    //             y_regs[i+1] <= y_regs[i] + (x_regs[i] >>> i);
    //         end
    //         // if angle difference is positive, rotate clockwise
    //         else begin
    //             angle_diff_regs[i+1] <= angle_diff_regs[i] - ATAN_LUT[i];
    //             x_regs[i+1] <= x_regs[i] + (y_regs[i] >>> i);
    //             y_regs[i+1] <= y_regs[i] - (x_regs[i] >>> i);
    //         end
    //     end
    // end

    RedundantArithmeticAdder RAA (
        .addsub(1'b0),
        //.op1(32'hAAAAAA75),
        //.op2_in(32'hAAAAAA74),
        .op1(32'h00000020),
        .op2_in(32'h00000021),
        .out(out)
    );

endmodule

// Carry free hybrid redundant arithmetic adder (4-2 carry save addition)
// adds an two's complement with a redundant arithmetic number
module RedundantArithmeticAdder (
    input logic addsub, // determines whether to add or subtract
    input logic[31:0] op1, op2_in,
    output logic[31:0] out // op1 + op2 or op1 - op2
);

    logic intermediate_carries[15:0], intermediate_sums[15:0], tmp;
    logic[31:0] op2;

    always_comb begin
        if (addsub == 1'b0) begin
            op2 = op2_in;
        end else begin
            // if subtraction, negate each digit of op2_in to get the negative
            for (int i = 0; i < 16; i++) begin
                case (op2_in[(i <<< 1) +: 2])
                    2'b00 : op2[(i <<< 1) +: 2] = 2'b11;
                    2'b11 : op2[(i <<< 1) +: 2] = 2'b00;
                    default : op2[(i <<< 1) +: 2] = op2_in[(i <<< 1) +: 2]; // since 01 and 10 are equal to 0, do not need to negate these

                endcase
            end
        end

    end

    assign out[0] = 1'b0;
    FullAdder fa0_0(op1[0], op1[1], op2[1], intermediate_carries[0], intermediate_sums[0]);
    MMP fa0_1(intermediate_sums[0], op2[0], 1'b0, out[2], out[1]);

    generate
    for (genvar i = 1; i < 15; i ++) begin
        FullAdder fai_0(op1[i <<< 1], op1[(i <<< 1) + 1], op2[(i <<< 1) + 1], intermediate_carries[i], intermediate_sums[i]);
        MMP fai_1(intermediate_sums[i], op2[i <<< 1], intermediate_carries[i-1] , out[(i <<< 1) + 2], out[(i <<< 1) + 1]);
    end
    endgenerate

    FullAdder fa15_0(op1[30], op1[31], op2[31], intermediate_carries[15], intermediate_sums[15]);
    MMP fa15_1(intermediate_sums[15], op2[30], intermediate_carries[14], tmp, out[31]);

endmodule

module FullAdder (
    input logic a, b, cin,
    output logic c, s
);
    // compute m and p such that 2p-m = a+b-cin
    assign s = a ^ b ^ cin;
    assign c = (a & b) | (cin & (a ^ b));
endmodule

module MMP (
    input logic a, b, cin,
    output logic m, p
);
    // compute m and p such that -2m+p = -a-b+cin
    assign p = a ^ b ^ cin;
    assign m = (~a & b) | (~a & ~b & cin) | (a & b & cin);

endmodule

module ConvertSignedToRedundantArith (
    input logic signed[15:0] twos_comp,
    output logic[31:0] redundant_arith
);
    always_comb begin
        // convert digit-by-digit
        for (int i = 0; i < 16; i++) begin
            case (twos_comp[i])
                1'b0 : redundant_arith[(i <<< 1) +: 2] = 2'b01;
                1'b1 : redundant_arith[(i <<< 1) +: 2] = 2'b11;
                // since 01 and 10 are equal to 0, do not need to negate these
            endcase
        end
    end
endmodule