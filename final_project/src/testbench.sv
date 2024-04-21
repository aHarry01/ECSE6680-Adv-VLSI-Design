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

        // 16'($rtoi($atan(0.0009765625)*2**FRAC_BITS)),
        // 16'($rtoi($atan(0.00048828125)*2**FRAC_BITS)),
        // 16'($rtoi($atan(0.000244140625)*2**FRAC_BITS)),
        // 16'($rtoi($atan(0.0001220703125)*2**FRAC_BITS)),
        // 16'($rtoi($atan(0.00006103515625)*2**FRAC_BITS)),
        // 16'($rtoi($atan(0.000030517578125)*2**FRAC_BITS))
    };
    localparam logic signed[15:0] GAIN = $rtoi(2**FRAC_BITS * real'(0.6072533210898753)); // cos(a1)cos(a2)...cos(a9)

    logic clk, start, busy, start_ser, busy_ser;
    logic signed[15:0] angle_iter, sin_iter, cos_iter, angle, sin, cos, angle_2, sin_2, cos_2, angle_ser, sin_ser, cos_ser;
    real tmp, tmp_sin;
    real avg_sin_error = 0.0;
    real count = 0.0;

    // DUTs
    CORDIC_iterative #(.GAIN(GAIN), .LENGTH(LENGTH), .ATAN_LUT(ATAN_LUT)) dut_iterative(
        .clk(clk), .start(start), .busy(busy),
        .angle(angle_iter),
        .sin(sin_iter),
        .cos(cos_iter)
    );

    CORDIC_pipelined #(.GAIN(GAIN), .LENGTH(LENGTH), .ATAN_LUT(ATAN_LUT)) dut_basic(
        .clk(clk),
        .angle(angle),
        .sin(sin),
        .cos(cos)
    );

    CORDIC_pipelined2 #(.GAIN(GAIN), .LENGTH(LENGTH), .ATAN_LUT(ATAN_LUT)) dut_unrolled(
        .clk(clk),
        .angle(angle_2),
        .sin(sin_2),
        .cos(cos_2)
    );

    CORDIC_bitserial #(.GAIN(GAIN), .LENGTH(LENGTH), .ATAN_LUT(ATAN_LUT)) dut_bitserial(
        .clk(clk), .start(start_ser), .busy(busy_ser),
        .angle(angle_ser),
        .sin(sin_ser),
        .cos(cos_ser)
    );

    initial
    begin
        @(posedge clk);
        for(real a = 0; a < 1.5; a+=0.1) begin
            angle_iter = 16'($rtoi(a * 2**FRAC_BITS)); // angle (in radians)
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;
            @(posedge clk);
            wait(busy == 1'b0);
            @(posedge clk);
        end


        @(posedge clk);
        for(real a = 0; a < 1.5; a+=0.1) begin
            angle = 16'($rtoi(a * 2**FRAC_BITS)); // angle (in radians)
            @(posedge clk);
        end

        for (int i = 0; i < LENGTH/2; i++) begin
            @(posedge clk);
        end

        for(real a = 0; a < 1.5; a+=0.1) begin
            angle_2 = 16'($rtoi(a * 2**FRAC_BITS)); // angle (in radians)
            @(posedge clk);
        end

        for (int i = 0; i < LENGTH; i++) begin
            @(posedge clk);
        end


        for(real a = 0.1; a < 1.5; a+=0.1) begin
            angle_ser = 16'($rtoi(a * 2**FRAC_BITS)); // angle (in radians)
            start_ser = 1'b1;
            @(posedge clk);
            start_ser = 1'b0;
            @(posedge clk);
            wait(busy_ser == 1'b0);
            @(posedge clk);
        end
    end

    initial
    begin
        $display("----ITERATIVE CORDIC TEST----");
        for(real x = 0; x < 1.5; x+=0.1) begin
            wait(start == 1'b1);
            @(posedge clk);
            @(posedge clk);
            @(posedge clk);
            wait(busy == 1'b0);
            count += 1;
            // convert fixed point representation to real number
            tmp = sin_iter/real'(2**FRAC_BITS);
            if ( tmp-$sin(x) > 0) avg_sin_error += tmp-$sin(x);
            else avg_sin_error += $sin(x)-tmp;
            $display("sin(%f) = %f", x, tmp);

            if (tmp - $sin(x) > ERROR_TOLERANCE || $sin(x) - tmp > ERROR_TOLERANCE) begin
                $display("Incorrect sin output: sin(%f) should be %f, not %f", x, $sin(x), tmp);
            end

            tmp = cos_iter/real'(2**FRAC_BITS);
            $display("cos(%f) = %f", x, tmp);

            if (tmp - $cos(x) > ERROR_TOLERANCE || $cos(x) - tmp > ERROR_TOLERANCE) begin
                $display("Incorrect cos output: cos(%f) should be %f, not %f", x, $cos(x), tmp);
            end
            @(posedge clk);
        end

        avg_sin_error = avg_sin_error / count;
        $display("AVERAGE SINE ERROR = %f", avg_sin_error);

        $display("----PIPELINED CORDIC TEST----");
        @(posedge clk);
        for (int i = 0; i < LENGTH+2; i++) begin
            @(posedge clk);
        end

        for(real x = 0; x < 1.5; x+=0.1) begin
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

        $display("----PIPELINED 2 CORDIC TEST----");

        for(real x = 0; x < 1.5; x+=0.1) begin
            // convert fixed point representation to real number
            tmp = sin_2/real'(2**FRAC_BITS);
            $display("sin(%f) = %f", x, tmp);

            if (tmp - $sin(x) > ERROR_TOLERANCE || $sin(x) - tmp > ERROR_TOLERANCE) begin
                $display("Incorrect sin output: sin(%f) should be %f, not %f", x, $sin(x), tmp);
            end

            tmp = cos_2/real'(2**FRAC_BITS);
            $display("cos(%f) = %f", x, tmp);

            if (tmp - $cos(x) > ERROR_TOLERANCE || $cos(x) - tmp > ERROR_TOLERANCE) begin
                $display("Incorrect cos output: cos(%f) should be %f, not %f", x, $cos(x), tmp);
            end
            @(posedge clk);
        end

        $display("----BIT SERIAL CORDIC TEST----");
        for(real x = 0.1; x < 1.5; x+=0.1) begin
            wait(start_ser == 1'b1);
            @(posedge clk);
            @(posedge clk);
            @(posedge clk);
            wait(busy_ser == 1'b0);
            @(negedge clk);
            // convert fixed point representation to real number
            tmp_sin = sin_ser/real'(2**FRAC_BITS);
            $display("sin(%f) = %f", x, tmp);

            if (tmp_sin - $sin(x) > ERROR_TOLERANCE || $sin(x) - tmp_sin > ERROR_TOLERANCE) begin
                $display("Incorrect sin output: sin(%f) should be %f, not %f", x, $sin(x), tmp_sin);
            end

            tmp = cos_ser/real'(2**FRAC_BITS);
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