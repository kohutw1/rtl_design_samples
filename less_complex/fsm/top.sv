// Testbench

`timescale 1 ns/1 ns

`define MIN_CYCLES  1
`define MAX_CYCLES 64

module top;
    // Specify local parameters
    localparam CLK_PERIOD      = 2;
    localparam CLK_PERIOD_BY_2 = CLK_PERIOD/2;

    // Declare DUT I/O
    logic clk   = 1'd0;
    logic reset = 1'd0;
    logic x1    = 1'd0;

    logic outp_dut;

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
    fsm dut(.outp(outp_dut), .*);

    // Drive stimulus into the DUT and TODO compare against model
    initial begin
        #10 reset = 1'd1; // Enter reset
        #10 reset = 1'd0; // Exit reset

        // TODO: $display("========== START VERIFICATION ==========");

        repeat(NUM_CYCLES) begin
            // Drive random value
            @(negedge clk) x1 = $urandom(SEED);
        end

        // TODO: $display("========== END VERIFICATION: TEST PASSED! ==========");

        $finish;
    end

    // Dump waves
    initial $dumpvars;
endmodule
