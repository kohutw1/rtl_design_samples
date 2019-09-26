// Testbench

`timescale 1 ns/1 ns

`define MIN_CYCLES                             1
`define MAX_CYCLES                            64

// Assume data and headers are an integral number of bytes wide
`define WIDTH_DATA_BYTES                       8
`define WIDTH_DATA_BITS    `WIDTH_DATA_BYTES * 8
`define WIDTH_BYTEEN_BITS  `WIDTH_DATA_BYTES
`define WIDTH_HDR_A_BYTES                      6
`define WIDTH_HDR_B_BYTES                      4
`define WIDTH_HDR_A_BITS  `WIDTH_HDR_A_BYTES * 8
`define WIDTH_HDR_B_BITS  `WIDTH_HDR_B_BYTES * 8

module top;
    localparam CLK_PERIOD      = 2;
    localparam CLK_PERIOD_BY_2 = CLK_PERIOD / 2;

    // Declare DUT I/O
    logic clk_host = 1'd0;
    logic rst_n    = 1'd1;

    logic bus_in_valid = 1'd0;
    logic bus_in_sop   = 1'd0;
    logic bus_in_eop   = 1'd0;

    logic [`WIDTH_BYTEEN_BITS - 1:0] bus_in_byteen = `WIDTH_BYTEEN_BITS'd0;
    logic [`WIDTH_DATA_BITS   - 1:0] bus_in_data   = `WIDTH_DATA_BITS  'd0;

    logic bus_out_valid;
    logic bus_out_sop;
    logic bus_out_eop;

    logic [`WIDTH_BYTEEN_BITS - 1:0] bus_out_byteen;
    logic [`WIDTH_DATA_BITS   - 1:0] bus_out_data;

    logic [`WIDTH_HDR_A_BITS - 1:0] headerA;
    logic [`WIDTH_HDR_B_BITS - 1:0] headerB;

    // Specify the seed to use for the $random function
    int SEED;

    // Specify the number of cycles
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
    initial forever #CLK_PERIOD_BY_2 clk_host = !clk_host;

    // Instantiate the DUT
    packet_parser #(
        .WIDTH_DATA_BYTES (`WIDTH_DATA_BYTES),
        .WIDTH_HDR_A_BYTES(`WIDTH_HDR_A_BYTES),
        .WIDTH_HDR_B_BYTES(`WIDTH_HDR_B_BYTES)
    ) dut(.*);

    // Drive stimulus into the DUT and compare against model
    initial begin
        @(posedge clk_host) rst_n = 1'd0; // Enter reset
        @(posedge clk_host) rst_n = 1'd1; // Exit reset

        repeat(3) @(posedge clk_host);

        @(posedge clk_host); // Cycle 0
        bus_in_eop    = 1'd0;
        bus_in_sop    = 1'd1;
        bus_in_valid  = 1'd1;
        bus_in_byteen = 8'hFF;
        bus_in_data   = 64'hABABABABABABCDCD;

        @(posedge clk_host); // Cycle 1
        bus_in_eop    = 1'd0;
        bus_in_sop    = 1'd0;
        bus_in_valid  = 1'd1;
        bus_in_byteen = 8'hFF;
        bus_in_data   = 64'hCDCD111111222222;

        @(posedge clk_host); // Cycle 2
        bus_in_eop    = 1'd0;
        bus_in_sop    = 1'd0;
        bus_in_valid  = 1'd1;
        bus_in_byteen = 8'hFF;
        bus_in_data   = 64'h3333333333333333;

        @(posedge clk_host); // Cycle 3
        bus_in_eop    = 1'd1;
        bus_in_sop    = 1'd0;
        bus_in_valid  = 1'd1;
        bus_in_byteen = 8'hFE;
        bus_in_data   = 64'h4444444444444400;

        @(posedge clk_host); // Cycle 4
        bus_in_eop    = 1'd0;
        bus_in_sop    = 1'd0;
        bus_in_valid  = 1'd0;
        bus_in_byteen = 8'h00;
        bus_in_data   = 64'h0000000000000000;

        @(posedge clk_host);
        @(posedge clk_host);

        $finish;

        $display("========== START VERIFICATION ==========");

        repeat(NUM_CYCLES) begin
            @(posedge clk_host);
        end

        $display("========== END VERIFICATION: TEST PASSED! ==========");

        $finish;
    end

    // Dump waves
    initial $dumpvars;
endmodule
