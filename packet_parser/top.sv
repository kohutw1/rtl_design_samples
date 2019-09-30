// Testbench

`timescale 1 ns/1 ns

// Assume data and headers are an integral number of bytes wide
`define WIDTH_DATA_BYTES                       8
`define WIDTH_HDR_A_BYTES                      6
`define WIDTH_HDR_B_BYTES                      4

// Derived defines
`define WIDTH_DATA_BITS   `WIDTH_DATA_BYTES  * 8
`define WIDTH_BYTEEN_BITS `WIDTH_DATA_BYTES
`define WIDTH_HDR_A_BITS  `WIDTH_HDR_A_BYTES * 8
`define WIDTH_HDR_B_BITS  `WIDTH_HDR_B_BYTES * 8

`define WIDTH_BITS_PER_BYTEEN                  1
`define WIDTH_BITS_PER_BYTE                    8

module top;
    localparam CLK_PERIOD      =              2;
    localparam CLK_PERIOD_BY_2 = CLK_PERIOD / 2;

    // Declare DUT I/O
    logic clk_host     = 1'd0;
    logic rst_n        = 1'd1;

    logic bus_in_valid = 1'd0;
    logic bus_in_sop   = 1'd0;
    logic bus_in_eop   = 1'd0;

    logic [`WIDTH_BYTEEN_BITS - 1:0] bus_in_byteen = `WIDTH_BYTEEN_BITS'd0;
    logic [`WIDTH_DATA_BITS   - 1:0] bus_in_data   = `WIDTH_DATA_BITS  'd0;

    logic bus_out_valid;
    logic bus_out_sop;
    logic bus_out_eop;

    logic [`WIDTH_BYTEEN_BITS - 1:0] bus_out_byteen, current_cycle_byteen;
    logic [`WIDTH_DATA_BITS   - 1:0] bus_out_data,   current_cycle_data;

    logic [`WIDTH_HDR_A_BITS - 1:0] headerA, in_headerA;
    logic [`WIDTH_HDR_B_BITS - 1:0] headerB, in_headerB;

    int pkt_size_in_bytes;
    int total_cycles;
    int last_byte_rem;
    int hdr_A_cnt;
    int hdr_B_cnt;

    logic [`WIDTH_BITS_PER_BYTE - 1:0] hdrA_rand_byte, hdrB_rand_byte;

    logic [`WIDTH_BITS_PER_BYTE - 1:0] byte_data;
    logic                              byte_byteen;

    // Specify the seed to use for the $random function
    int SEED;

    // Specify the number of packets
    int NUM_PKTS;

    // Specify the packet size in bytes
    int MAX_PKT_SIZE_IN_BYTES;

    // Run the bringup packet
    int RUN_BRINGUP_PKT;

    initial begin
        if($value$plusargs("SEED=%d",                  SEED                 )) begin end else $fatal(0, "Must provide +SEED=<random_seed> plusarg");
        if($value$plusargs("NUM_PKTS=%d",              NUM_PKTS             )) begin end else $fatal(0, "Must provide +NUM_PKTS=<num_packets_to_simulate> plusarg");
        if($value$plusargs("MAX_PKT_SIZE_IN_BYTES=%d", MAX_PKT_SIZE_IN_BYTES)) begin end else $fatal(0, "Must provide +MAX_PKT_SIZE_IN_BYTES=<max_packet_size_in_bytes> plusarg");
        if($value$plusargs("RUN_BRINGUP_PKT=%d",       RUN_BRINGUP_PKT      )) begin end else $fatal(0, "Must provide +RUN_BRINGUP_PKT=<0|1> plusarg");
    end

    // Generate a clock
    initial forever #CLK_PERIOD_BY_2 clk_host = !clk_host;

    // Instantiate the DUT
    packet_parser #(
        .WIDTH_DATA_BYTES (`WIDTH_DATA_BYTES ),
        .WIDTH_HDR_A_BYTES(`WIDTH_HDR_A_BYTES),
        .WIDTH_HDR_B_BYTES(`WIDTH_HDR_B_BYTES)
    ) dut(.*);

    // Drive stimulus into the DUT and compare against model
    initial begin
        @(posedge clk_host) rst_n = 1'd0; // Enter reset
        @(posedge clk_host) rst_n = 1'd1; // Exit reset

        repeat(2) @(posedge clk_host);

        if(RUN_BRINGUP_PKT) begin
            $display("========== RUNNING BRINGUP PACKET ==========");

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

            repeat(2) @(posedge clk_host);

            $finish;

        end else begin
            $display("========== RUNNING RANDOM PACKETS ==========");

            // TODO: Add scoreboard
            repeat(NUM_PKTS) begin
                // Randomize packet size
                pkt_size_in_bytes = $urandom(SEED) % (MAX_PKT_SIZE_IN_BYTES + 1);

                total_cycles = ((pkt_size_in_bytes % `WIDTH_DATA_BYTES) != 0) ?
                                (pkt_size_in_bytes / `WIDTH_DATA_BYTES) + 1 :
                                 pkt_size_in_bytes / `WIDTH_DATA_BYTES;

                last_byte_rem = `WIDTH_DATA_BYTES - (pkt_size_in_bytes % `WIDTH_DATA_BYTES);

                // Randomize headers
                hdrA_rand_byte = $urandom(SEED) & {`WIDTH_BITS_PER_BYTE{1'd1}};
                hdrB_rand_byte = $urandom(SEED) & {`WIDTH_BITS_PER_BYTE{1'd1}};

                in_headerA = {`WIDTH_HDR_A_BYTES{hdrA_rand_byte}};
                in_headerB = {`WIDTH_HDR_B_BYTES{hdrB_rand_byte}};

                hdr_A_cnt = 0;
                hdr_B_cnt = 0;

                // Iterate over all packet bytes
                for(int in_cycle = 0; in_cycle < total_cycles; in_cycle = in_cycle + 1) begin
                    for(int in_byte = `WIDTH_DATA_BYTES - 1; in_byte >= 0; in_byte = in_byte - 1) begin
                        byte_byteen = !((in_cycle == (total_cycles - 1)) && (in_byte < last_byte_rem));

                        if(hdr_A_cnt < `WIDTH_HDR_A_BYTES) begin
                            byte_data = in_headerA[`WIDTH_BITS_PER_BYTE * hdr_A_cnt +: `WIDTH_BITS_PER_BYTE];
                            hdr_A_cnt = hdr_A_cnt + 1;
                        end else if(hdr_B_cnt < `WIDTH_HDR_B_BYTES) begin
                            byte_data = in_headerB[`WIDTH_BITS_PER_BYTE * hdr_B_cnt +: `WIDTH_BITS_PER_BYTE];
                            hdr_B_cnt = hdr_B_cnt + 1;
                        end else begin
                            byte_data = ($urandom(SEED) & {`WIDTH_BITS_PER_BYTE{1'd1}}) & {`WIDTH_BITS_PER_BYTE{byte_byteen}};
                        end

                        current_cycle_byteen = (current_cycle_byteen << `WIDTH_BITS_PER_BYTEEN) | byte_byteen;
                        current_cycle_data   = (current_cycle_data   << `WIDTH_BITS_PER_BYTE  ) | byte_data;
                    end

                    bus_in_eop    = in_cycle == (total_cycles - 1);
                    bus_in_sop    = in_cycle == 0;
                    bus_in_valid  = 1'd1; // TODO: Add random bubbles
                    bus_in_byteen = current_cycle_byteen;
                    bus_in_data   = current_cycle_data;

                    @(posedge clk_host);
                end
            end

            $finish;
        end
    end

    // Dump waves
    initial $dumpvars;
endmodule
