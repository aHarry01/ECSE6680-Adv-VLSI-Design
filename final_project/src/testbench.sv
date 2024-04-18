`timescale 1ns / 1ps

// Testbench to verify that computed results are correct
module testbench();
    localparam int CLK_PERIOD_NS = 50; // 50ns period/20MHz sampling rate
    localparam real PI = 3.1415926535;
    localparam real ERROR_TOLERANCE = 0.05; // output should be within ERROR_TOLERANCE of correct answer
    localparam real FRAC_BITS = 14; // 16 bit fixed-point, FRAC_BITS fraction bits

    localparam int LENGTH = 10;
    localparam logic signed[15:0] ATAN_LUT[0:LENGTH-1] = {
        16'($rtoi($atan(1)*2**FRAC_BITS)),
        16'($rtoi($atan(0.5)*2**FRAC_BITS)),
        16'($rtoi($atan(0.25)*2**FRAC_BITS)),
        16'($rtoi($atan(0.125)*2**FRAC_BITS)),
        16'($rtoi($atan(0.0625)*2**FRAC_BITS)),
        16'($rtoi($atan(0.03125)*2**FRAC_BITS)),
        16'($rtoi($atan(0.015625)*2**FRAC_BITS)),
        16'($rtoi($atan(0.0078125)*2**FRAC_BITS)),
        16'($rtoi($atan(0.00390625)*2**FRAC_BITS)),
        16'($rtoi($atan(0.001953125)*2**FRAC_BITS))
    };
    localparam logic signed[15:0] GAIN = $rtoi(2**FRAC_BITS * real'(0.6072533210898753)); // 1/cos(a1)cos(a2)...cos(a9)

    logic clk;
    logic signed[15:0] angle, sin, cos, angle_unrolled, sin_unrolled, cos_unrolled;
    real tmp;

    // DUTs
    CORDIC #(.GAIN(GAIN), .LENGTH(LENGTH), .ATAN_LUT(ATAN_LUT)) dut_basic(
        .clk(clk),
        .angle(angle),
        .sin(sin),
        .cos(cos)
    );

    CORDIC_unrolled #(.GAIN(GAIN), .LENGTH(LENGTH), .ATAN_LUT(ATAN_LUT)) dut_unrolled(
        .clk(clk),
        .angle(angle_unrolled),
        .sin(sin_unrolled),
        .cos(cos_unrolled)
    );

    initial
    begin
        @(posedge clk);
        for(real a = 0; a < 1.5; a+=0.1) begin
            angle = 16'($rtoi(a * 2**FRAC_BITS)); // angle (in radians)
            @(posedge clk);
        end

        for (int i = 0; i < 5; i++) begin
            @(posedge clk);
        end

        for(real a = 0; a < 1.5; a+=0.1) begin
            angle_unrolled = 16'($rtoi(a * 2**FRAC_BITS)); // angle (in radians)
            @(posedge clk);
        end
    end

    initial
    begin
        $display("----BASIC CORDIC TEST----");
        @(posedge clk);
        for (int i = 0; i < LENGTH+2; i++) begin
            @(posedge clk);
        end

        for(real x = 0; x < 1.5; x+=0.1) begin
            // TODO: cos
            // convert fixed point representation to real number
            tmp = sin/real'(2**FRAC_BITS);
            $display("sin(%f) = %f", x, tmp);

            if (tmp - $sin(x) > ERROR_TOLERANCE || $sin(x) - tmp > ERROR_TOLERANCE) begin
                $display("Incorrect sin output: sin(%f) should be %f, not %f", x, $sin(x), tmp);
            end

            tmp = cos/real'(2**FRAC_BITS);
            $display("cos(%f) = %f", x, tmp);

            if (tmp - $cos(x) > ERROR_TOLERANCE || $cos(x) - tmp > ERROR_TOLERANCE) begin
                $display("Incorrect cos output: cos(%f) should be %f, not %f", x, $cos(x), tmp);
            end
            @(posedge clk);
        end

        $display("----UNROLLED CORDIC TEST----");

        for(real x = 0; x < 1.5; x+=0.1) begin
            // TODO: cos
            // convert fixed point representation to real number
            tmp = sin_unrolled/real'(2**FRAC_BITS);
            $display("sin(%f) = %f", x, tmp);

            if (tmp - $sin(x) > ERROR_TOLERANCE || $sin(x) - tmp > ERROR_TOLERANCE) begin
                $display("Incorrect sin output: sin(%f) should be %f, not %f", x, $sin(x), tmp);
            end

            tmp = cos_unrolled/real'(2**FRAC_BITS);
            $display("cos(%f) = %f", x, tmp);

            if (tmp - $cos(x) > ERROR_TOLERANCE || $cos(x) - tmp > ERROR_TOLERANCE) begin
                $display("Incorrect cos output: cos(%f) should be %f, not %f", x, $cos(x), tmp);
            end
            @(posedge clk);
        end

        $stop;
    end


    // Generate the clock
	always
    begin
        clk=1; #(CLK_PERIOD_NS/2);
        clk=0; #(CLK_PERIOD_NS/2);
    end
endmodule