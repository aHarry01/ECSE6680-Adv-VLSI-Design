`timescale 1ns / 1ps

/* Pipedlined FIR filter Testbench */
module testbench_pipelined();
    `include "filter_parameters.sv"
    localparam int CLK_PERIOD_NS = 10; // for now, 10ns period/100MHz sampling rate...should probably be slower, like 48KHz or something? TODO: update based on synopsys design compiler timing results (?)
    localparam real scale_factor = 1/real'(2**30); // 30 fraction bits in the fixed point representation of the output (15 fraction bits in coefficients and inputs)
    localparam IN_WIDTH = 16;
    localparam OUT_WIDTH = 40;
    localparam real pi = 3.141592653;

    // input frequencies to test, as a proportion of Fs (i.e. 0.1*Fs, 0.2*Fs, etc)
    // cutoff between 0.1*Fs and 0.115*Fs
    localparam int NUM_FREQ_TESTS = 14;
    localparam real test_freqs[0:NUM_FREQ_TESTS-1] = {0, 0.025, 0.05, 0.075, 0.1, 0.105, 0.110, 0.115, 0.125, 0.15, 0.175, 0.2, 0.3, 0.4};

    logic clk;
    logic rst = 1'b1;
    logic input_go = 1'b0;
    real input_period_ns = 0;
    real input_period_ns_loop = 0;
    real sine_analog = 0;
    real radians = 0;

    logic signed[IN_WIDTH-1:0] x = '0;
    logic signed[OUT_WIDTH-1:0] y;
    logic signed[OUT_WIDTH-1:0] max_y;

    // Instantiate the FIR filter
    Pipelined_FIR_Filter #(.IN_WIDTH(IN_WIDTH), .OUT_WIDTH(OUT_WIDTH)) dut_pipelined(clk, x, y);

    // Provide the test inputs
    initial
    begin
        // ----- PIPELINED FILTER TESTS ---------------------------------------------------------------
        // save results to csv files so freq response can be graphed in excel
        int fd = $fopen("testbench_results/results_pipelined.csv", "w");

        $fwrite(fd, "Sample period, %0dns\n", CLK_PERIOD_NS);
        $fwrite(fd, "Input period (ns), Input frequency, Output magnitude, Output magnitude (db)\n");

        // measure output magnitude with various frequency inputs
        for (int i = 0; i < NUM_FREQ_TESTS; i++) begin
            // set the input frequency
            if (test_freqs[i] == 0) input_period_ns = 0;
            else input_period_ns = real'(CLK_PERIOD_NS)/real'(test_freqs[i]);

            input_go = 1'b1; // set input_go to trigger the input to the filter

            // wait at least the number of taps clock cycles before reading the output magnitude
            for (int j = 0; j < 1.5*N_TAPS; j++) begin
                @(posedge clk);
            end

            // read maximum output magnitude over 2*input_period_ns clock cycles
            if (input_period_ns == 0) input_period_ns_loop = 10;
            else input_period_ns_loop = input_period_ns;
            max_y = y;
            for (int j = 0; j < 2*input_period_ns_loop; j++) begin
                @(posedge clk);
                if (y > max_y) max_y = y;
            end

            // save the results
            $fwrite(fd, "%f, %f*Fs, %f, %f\n", input_period_ns, test_freqs[i], $itor(max_y)*scale_factor, real'(20)*$log10($itor(max_y)*scale_factor));

            input_go = 1'b0; // stop providing input at this frequency
            @(posedge clk);
            @(posedge clk);
        end

        $fclose(fd);
        $stop;
    end

    // Generate the clock
	always
    begin
        clk=1; #(CLK_PERIOD_NS/2);
        clk=0; #(CLK_PERIOD_NS/2);
    end

    // Generate input with a period equal to input_period_ns
    real increment = 0;
    always @(posedge clk)
    begin
        if (input_go == 1'b1) begin
            // DC input is a special case when the input period is set to 0
            if (input_period_ns == 0) begin
                // just hold the input at the maximum postive value (all 1s except the sign bit is 0)
                x <= {1'b0, (IN_WIDTH-1)'('1)};
            end else begin
                // CLK_PERIOD_NS have passed since the last update of the input
                // need to add (CLK_PERIOD_NS/input_period_ns)*2pi radians
                // to update the radians input
                radians = radians + real'(real'(CLK_PERIOD_NS)/input_period_ns)*real'(2*pi);

                sine_analog = $sin(radians);
                // provide sample to the non-parallel filter and the second input to the 2-parallel filter
                if (sine_analog == 1)
                    x = {1'b0, (IN_WIDTH-1)'('1)};
                else
                    // convert to 16-bit fixed point
                    // first multiply it by the scale factor, then convert to an integer and use the lower IN_WIDTH bits
                    x = 16'($rtoi(sine_analog * real'(2**(IN_WIDTH-1))));
            end

        end else begin
            radians = 0;
        end
    end


endmodule