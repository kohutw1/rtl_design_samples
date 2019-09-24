// Testbench

`timescale 1 ns/1 ns

`define MIN_CYCLES  1
`define MAX_CYCLES 64

module top;
    // Specify local parameters
    localparam CLK_PERIOD      = 2;
    localparam CLK_PERIOD_BY_2 = CLK_PERIOD/2;

    // Declare DUT I/O
    logic clk = 1'd0;
    logic rst_n = 1'd1;

    logic in_bit;
    logic div_5_dut;

    logic [`MAX_CYCLES-1:0] div_5_model = `MAX_CYCLES'd0;

    int cycle=0;

    // Specify the seed to use for the $random function
    int SEED;

    // Specify the number of cycles, where a single random bit
    // is shifted into the LSB position on each cycle
    int NUM_CYCLES;

    initial begin
        if($value$plusargs("SEED=%d", SEED)) begin end else $fatal(0, "Must provide +SEED=<random_seed> plusarg");

        if($value$plusargs("NUM_CYCLES=%d", NUM_CYCLES)) begin
            if((NUM_CYCLES < `MIN_CYCLES) || (NUM_CYCLES > `MAX_CYCLES)) begin
                $fatal(0, "NUM_CYCLES must be between %0d and %0d, inclusive", `MIN_CYCLES, `MAX_CYCLES);
            end
        end else begin
            $fatal(0, "Must provide +NUM_CYCLES=<num_cycles_to_simulate> plusarg");
        end
    end

    // Generate a clock
    initial forever #CLK_PERIOD_BY_2 clk = !clk;

    // Instantiate the DUT
    div_5_detector dut(.div_5(div_5_dut), .*);

    // Drive stimulus into the DUT and compare against model
    initial begin
        #10 rst_n = 1'd0; // Enter reset
        #10 rst_n = 1'd1; // Exit reset

        $display("========== START VERIFICATION ==========");

        repeat(NUM_CYCLES) begin
            // Drive random value
            @(negedge clk) in_bit = $urandom(SEED);

            // I'd use an assertion here, but Icarus Verilog doesn't support them yet
            if(((div_5_model % 5) == 0) && dut.first_1_seen) begin
                if( div_5_dut) begin display_status_msg("pass", div_5_dut);
                end else       begin display_status_msg("fail", div_5_dut); end
            end else begin
                if(!div_5_dut) begin display_status_msg("pass", div_5_dut);
                end else       begin display_status_msg("fail", div_5_dut); end
            end

            // Shift into register to verify div_5_dut
            @(posedge clk) div_5_model = (div_5_model << 1) | in_bit;

            cycle++;
        end

        $display("========== END VERIFICATION: TEST PASSED! ==========");

        $finish;
    end

    // Dump waves
    initial $dumpvars;

    task display_status_msg(input string status, input logic div_5_dut);
        string div_5_string;

        if(div_5_dut) begin
            div_5_string = " <== Divisible by 5";
        end else begin
            div_5_string = "";
        end

        if(status == "pass") begin
            $display(   "PASS: cycle=%2d (t=%3t ns): div_5_dut=%b, div_5_model=%0d%s", cycle, $time, div_5_dut, div_5_model, div_5_string);
        end else if(status == "fail") begin
            $fatal  (0, "FAIL: cycle=%2d (t=%3t ns): div_5_dut=%b, div_5_model=%0d%s", cycle, $time, div_5_dut, div_5_model, div_5_string);
        end else begin
            $fatal  (0, "Illegal status");
        end
    endtask
endmodule
