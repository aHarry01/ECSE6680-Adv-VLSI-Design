// used when vivado synthesizing
module TopLevel(
    input  logic clk, start,
    output logic busy,
    input  logic signed[15:0] angle,
    output logic signed[15:0] sin, cos
);
    localparam real FRAC_BITS = 14; // 16 bit fixed-point, FRAC_BITS fraction bits

    localparam int LENGTH = 8;
    localparam logic signed[15:0] ATAN_LUT[0:LENGTH-1] = {
        16'($rtoi($atan(1)*2**FRAC_BITS)),
        16'($rtoi($atan(0.5)*2**FRAC_BITS)),
        16'($rtoi($atan(0.25)*2**FRAC_BITS)),
        16'($rtoi($atan(0.125)*2**FRAC_BITS)),
        16'($rtoi($atan(0.0625)*2**FRAC_BITS)),
        16'($rtoi($atan(0.03125)*2**FRAC_BITS)),
        16'($rtoi($atan(0.015625)*2**FRAC_BITS)),
        16'($rtoi($atan(0.0078125)*2**FRAC_BITS))
        // 16'($rtoi($atan(0.00390625)*2**FRAC_BITS)),
        // 16'($rtoi($atan(0.001953125)*2**FRAC_BITS)),

        // 16'($rtoi($atan(0.0009765625)*2**FRAC_BITS)),
        // 16'($rtoi($atan(0.00048828125)*2**FRAC_BITS)),
        // 16'($rtoi($atan(0.000244140625)*2**FRAC_BITS)),
        // 16'($rtoi($atan(0.0001220703125)*2**FRAC_BITS))
    };

    localparam logic signed[15:0] GAIN = $rtoi(2**FRAC_BITS * real'(0.6072533210898753)); // 1/cos(a1)cos(a2)...cos(a9)

    logic clk, start, busy, start_ser, busy_ser;
    CORDIC_iterative #(.GAIN(GAIN), .LENGTH(LENGTH), .ATAN_LUT(ATAN_LUT)) dut_iterative(
        .clk(clk), .start(start), .busy(busy),
        .angle(angle),
        .sin(sin),
        .cos(cos)
    );

    // CORDIC_pipelined #(.GAIN(GAIN), .LENGTH(LENGTH), .ATAN_LUT(ATAN_LUT)) dut_basic(
    //     .clk(clk),
    //     .angle(angle),
    //     .sin(sin),
    //     .cos(cos)
    // );

    // CORDIC_pipelined2 #(.GAIN(GAIN), .LENGTH(LENGTH), .ATAN_LUT(ATAN_LUT)) dut_unrolled(
    //     .clk(clk),
    //     .angle(angle),
    //     .sin(sin),
    //     .cos(cos)
    // );

    // CORDIC_bitserial #(.GAIN(GAIN), .LENGTH(LENGTH), .ATAN_LUT(ATAN_LUT)) dut_bitserial(
    //     .clk(clk), .start(start), .busy(busy),
    //     .angle(angle),
    //     .sin(sin),
    //     .cos(cos)
    // );
endmodule