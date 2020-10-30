////////////////////////////////////////////////////////////////////
// Message Extractor Testbench
////////////////////////////////////////////////////////////////////
//
// Author:
//     Will Kohut (kohutw@gmail.com)

`timescale 1 ns/1 ns

`include "global_defines.svh"

module top;
    ////////////////////////////////////////////////////////////////////
    // Declare DUT signals
    ////////////////////////////////////////////////////////////////////
    logic                               clk;
    logic                               reset_n; // Synchronous, active-low reset

    logic                               in_valid;
    logic                               in_startofpacket;
    logic                               in_endofpacket;
    logic [`WIDTH_IN_EMPTY_BITS  - 1:0] in_empty;
    logic                               in_error;
    logic [`WIDTH_IN_DATA_BITS   - 1:0] in_data,
                                        in_data_next;

    logic                               in_ready;

    logic                               out_valid;
    logic [`WIDTH_OUT_DATA_BITS  - 1:0] out_data;
    logic [`WIDTH_OUT_DATA_BYTES - 1:0] out_bytemask;

    ////////////////////////////////////////////////////////////////////
    // Declare and initialize TB signals
    ////////////////////////////////////////////////////////////////////
    logic seq_started           = 1'b0;
    logic seq_ended             = 1'b0;
    logic in_ready_d1           = 1'b0;
    logic inject                = 1'b0;
    logic in_startofpacket_seen = 1'b0;

    int pkt_cyc_cnt             = 0;
    int pkt_cnt                 = 0;

    int RUN_BRINGUP_PKT         = 0;
    int NUM_PKT                 = 1;
    int NUM_MSG_PER_PKT         = 1;

    int IN_VALID_PROB           = 100;

    string rand_in_stim_fn      = "rand_input_stimulus.txt";
    int    rand_in_stim_fd      = 0;

    ////////////////////////////////////////////////////////////////////
    // Read in plusargs
    ////////////////////////////////////////////////////////////////////
    initial begin
        if($value$plusargs("RUN_BRINGUP_PKT=%d", RUN_BRINGUP_PKT)) begin
        end else if($value$plusargs("NUM_PKT=%d", NUM_PKT) && $value$plusargs("NUM_MSG_PER_PKT=%d", NUM_MSG_PER_PKT)) begin
        end else begin
            $fatal(0, "Must provide either +RUN_BRINGUP_PKT=<1,0> or +NUM_PKT=<num_pkt> and +NUM_MSG_PER_PKT=<num_msg_per_pkt> plusargs");
        end

        if($value$plusargs("IN_VALID_PROB=%d", IN_VALID_PROB));
    end

    ////////////////////////////////////////////////////////////////////
    // Manage clock
    ////////////////////////////////////////////////////////////////////
    // 500 MHz clock
    int CLK_PERIOD      =              2;
    int CLK_PERIOD_BY_2 = CLK_PERIOD / 2;

    initial forever #CLK_PERIOD_BY_2 clk = !clk;

    default clocking cb @(posedge clk);
        default input #1step output #0;

        output reset_n, in_data, in_startofpacket, in_endofpacket, in_empty, in_error;
        input  in_ready, out_valid, out_data, out_bytemask;
    endclocking

    ////////////////////////////////////////////////////////////////////
    // Test entry point
    ////////////////////////////////////////////////////////////////////
    initial begin
        clk = 1'b1;

        @cb reset_n <= 1'b0; // Enter reset
        @cb reset_n <= 1'b1; // Exit reset

        repeat(2) @cb;

        if(RUN_BRINGUP_PKT) begin
            $display("");
            $display("////////////////////////////////////////////////////////////////////");
            $display("// RUNNING BRINGUP PACKET");
            $display("////////////////////////////////////////////////////////////////////");
            $display("");

            @(cb iff in_ready_d1) in_data <= 'h6262626108000800; in_startofpacket <= 1'b1; in_endofpacket <= 1'b0; in_empty <= 'hX; seq_started <= 1'b1;
            @(cb iff inject     ) in_data <= 'h68670c0063626262; in_startofpacket <= 1'b0; in_endofpacket <= 1'b0; in_empty <= 'hX;
            @(cb iff inject     ) in_data <= 'h6868686868686868; in_startofpacket <= 1'b0; in_endofpacket <= 1'b0; in_empty <= 'hX;
            @(cb iff inject     ) in_data <= 'h7070706f0a006968; in_startofpacket <= 1'b0; in_endofpacket <= 1'b0; in_empty <= 'hX;
            @(cb iff inject     ) in_data <= 'h0f00717070707070; in_startofpacket <= 1'b0; in_endofpacket <= 1'b0; in_empty <= 'hX;
            @(cb iff inject     ) in_data <= 'h7a7a7a7a7a7a7a79; in_startofpacket <= 1'b0; in_endofpacket <= 1'b0; in_empty <= 'hX;
            @(cb iff inject     ) in_data <= 'h007b7a7a7a7a7a7a; in_startofpacket <= 1'b0; in_endofpacket <= 1'b0; in_empty <= 'hX;
            @(cb iff inject     ) in_data <= 'h4d4d4d4d4d4d4c0e; in_startofpacket <= 1'b0; in_endofpacket <= 1'b0; in_empty <= 'hX;
            @(cb iff inject     ) in_data <= 'h004e4d4d4d4d4d4d; in_startofpacket <= 1'b0; in_endofpacket <= 1'b0; in_empty <= 'hX;
            @(cb iff inject     ) in_data <= 'h3838383838383711; in_startofpacket <= 1'b0; in_endofpacket <= 1'b0; in_empty <= 'hX;
            @(cb iff inject     ) in_data <= 'h3838383838383838; in_startofpacket <= 1'b0; in_endofpacket <= 1'b0; in_empty <= 'hX;
            @(cb iff inject     ) in_data <= 'h313131300b003938; in_startofpacket <= 1'b0; in_endofpacket <= 1'b0; in_empty <= 'hX;
            @(cb iff inject     ) in_data <= 'h0032313131313131; in_startofpacket <= 1'b0; in_endofpacket <= 1'b0; in_empty <= 'hX;
            @(cb iff inject     ) in_data <= 'h5a5a5a5a5a5a5909; in_startofpacket <= 1'b0; in_endofpacket <= 1'b0; in_empty <= 'hX;
            @(cb iff inject     ) in_data <= 'hXXXXXXXXXXXX5b5a; in_startofpacket <= 1'b0; in_endofpacket <= 1'b1; in_empty <= 'h6;
        end else begin
            automatic int byte_cnt = 0;

            $display("");
            $display("////////////////////////////////////////////////////////////////////");
            $display("// RUNNING RANDOM PACKETS");
            $display("////////////////////////////////////////////////////////////////////");
            $display("");
            $display("!!! Dumping random input stimulus to %s !!!", rand_in_stim_fn);
            $display("");

            rand_in_stim_fd = $fopen(rand_in_stim_fn, "w");

            repeat(NUM_PKT) begin
                automatic int msg_rem = NUM_MSG_PER_PKT;

                automatic int msg_start_byte = `WIDTH_MSG_CNT_BYTES;

                in_data_next >>= `WIDTH_MSG_CNT_BYTES * `BITS_PER_BYTE;

                // Reverse byte endianness of message count and use to
                // initialize in_data
                in_data_next[`WIDTH_IN_DATA_BITS - 1 -:(`WIDTH_MSG_CNT_BYTES * `BITS_PER_BYTE)] =
                            {<<`BITS_PER_BYTE{msg_rem[(`WIDTH_MSG_CNT_BYTES * `BITS_PER_BYTE) - 1:0]}};

                byte_cnt += `WIDTH_MSG_CNT_BYTES;

                while(msg_rem > 0) begin
                    automatic int msg_bytes = $urandom_range(`MIN_MSG_BYTES, `MAX_MSG_BYTES);

                    automatic int first_msg = msg_rem == NUM_MSG_PER_PKT;
                    automatic int last_msg  = msg_rem == 1;

                    automatic int msg_plus_len_bytes = msg_bytes + `WIDTH_MSG_LEN_BYTES;

                    automatic int rem_bytes = (msg_plus_len_bytes + byte_cnt) % `WIDTH_IN_DATA_BYTES;

                    automatic int pad_bytes = `WIDTH_IN_DATA_BYTES - rem_bytes;

                    automatic int msg_bytes_qual = last_msg ? (msg_plus_len_bytes + pad_bytes) : msg_plus_len_bytes;

                    automatic int msg_delimiter;

                    for(int byte_i = 0; byte_i < msg_bytes_qual; byte_i++) begin
                        in_data_next >>= `BITS_PER_BYTE;

                        if(byte_i >= msg_plus_len_bytes) begin
                            in_data_next[`WIDTH_IN_DATA_BITS - 1 -:`BITS_PER_BYTE] = `BITS_PER_BYTE'hX;
                        end else if(byte_i == 0) begin
                            in_data_next[`WIDTH_IN_DATA_BITS - 1 -:`BITS_PER_BYTE] = msg_bytes[`BITS_PER_BYTE +:`BITS_PER_BYTE];
                        end else if(byte_i == 1) begin
                            in_data_next[`WIDTH_IN_DATA_BITS - 1 -:`BITS_PER_BYTE] = msg_bytes[             0 +:`BITS_PER_BYTE];
                        end else if(byte_i == 2) begin
                            msg_delimiter = $urandom;
                            in_data_next[`WIDTH_IN_DATA_BITS - 1 -:`BITS_PER_BYTE] = msg_delimiter;
                        end else if(byte_i == (msg_plus_len_bytes - 1)) begin
                            in_data_next[`WIDTH_IN_DATA_BITS - 1 -:`BITS_PER_BYTE] = msg_delimiter + 2;
                        end else begin
                            in_data_next[`WIDTH_IN_DATA_BITS - 1 -:`BITS_PER_BYTE] = msg_delimiter + 1;
                        end

                        byte_cnt++;

                        if(!(byte_cnt % `WIDTH_IN_DATA_BYTES)) begin
                            if(first_msg && (byte_i == (`WIDTH_IN_DATA_BYTES - `WIDTH_MSG_CNT_BYTES - 1))) begin
                                @(cb iff in_ready_d1) begin
                                    in_data <= in_data_next; in_startofpacket <= 1'b1; in_endofpacket <= 1'b0; in_empty <= 'dx; in_error <= 1'b0; seq_started <= 1'b1;
                                    $fdisplay(rand_in_stim_fd, "in_data=%h in_startofpacket=%b in_endofpacket=%b in_valid=%b in_empty=%h in_error=%b", in_data_next, 1'b1, 1'b0, in_valid, 'hX, 1'b0);
                                end
                            end else if(last_msg && (byte_i == (msg_bytes_qual - 1))) begin
                                @(cb iff inject) begin
                                    in_data <= in_data_next; in_startofpacket <= 1'b0; in_endofpacket <= 1'b1; in_empty <= pad_bytes; in_error <= 1'b0;
                                    $fdisplay(rand_in_stim_fd, "in_data=%h in_startofpacket=%b in_endofpacket=%b in_valid=%b in_empty=%h in_error=%b", in_data_next, 1'b0, 1'b1, in_valid, pad_bytes, 1'b0);
                                end
                            end else begin
                                @(cb iff inject) begin
                                    in_data <= in_data_next; in_startofpacket <= 1'b0; in_endofpacket <= 1'b0; in_empty <= 'dx; in_error <= 1'b0;
                                    $fdisplay(rand_in_stim_fd, "in_data=%h in_startofpacket=%b in_endofpacket=%b in_valid=%b in_empty=%h in_error=%b", in_data_next, 1'b0, 1'b0, in_valid, 'hX, 1'b0);
                                end
                            end
                        end
                    end

                    msg_rem--;
                end
            end

            $fclose(rand_in_stim_fd);
        end

        @(cb) seq_ended <= 1'b1;

        // Idle pipe
        repeat(5) @(cb);

        $finish;
    end

    ////////////////////////////////////////////////////////////////////
    // Flop ready signal (ready latency is 1)
    ////////////////////////////////////////////////////////////////////
    always_ff @(cb) begin
        if(!reset_n) begin
            in_ready_d1 <= 1'b0;
        end else begin
            in_ready_d1 <= in_ready;
        end
    end

    ////////////////////////////////////////////////////////////////////
    // Manage TB/DUT handshake
    ////////////////////////////////////////////////////////////////////
    always_comb begin
        in_valid = in_ready_d1 ? (($urandom_range(100) <= IN_VALID_PROB) && seq_started && !seq_ended) : 1'b0;
        inject = in_valid && in_ready_d1;
    end

    ////////////////////////////////////////////////////////////////////
    // Track performance
    ////////////////////////////////////////////////////////////////////
    // The requirements say that in_empty should only be qualified with the
    // incoming end of packet, which suggests that in_startofpacket and
    // in_endofpacket imply in_valid is asserted simultaneously. Adding an
    // assertion at the end of this file to enforce that.
    always_ff @(cb) begin
        if(!reset_n || in_endofpacket) begin
            in_startofpacket_seen <= 1'b0;
            pkt_cyc_cnt           <=  'd0;
        end else begin
            if(in_startofpacket) begin
                in_startofpacket_seen <= 1'b1;
            end else begin
                in_startofpacket_seen <= in_startofpacket_seen;
            end

            if(in_startofpacket || in_startofpacket_seen) begin
                pkt_cyc_cnt <= pkt_cyc_cnt + 1'b1;
            end else begin
                pkt_cyc_cnt <= pkt_cyc_cnt;
            end
        end
    end

    always_ff @(cb) begin
        if(!reset_n) begin
            pkt_cnt <= 'd0;
        end else begin
            if(in_startofpacket && !in_startofpacket_seen) begin
                pkt_cnt <= pkt_cnt + 1'b1;
            end else begin
                pkt_cnt <= pkt_cnt;
            end
        end
    end

    ////////////////////////////////////////////////////////////////////
    // Monitor output stream
    ////////////////////////////////////////////////////////////////////
    initial forever @(negedge clk iff out_valid) begin
        $display("[%5t ns, cycle %3d] Packet %2d, cycle %2d: out_data=%h out_bytemask=%b out_valid=%b",
                  $time - CLK_PERIOD_BY_2, $time / CLK_PERIOD, pkt_cnt - 1, pkt_cyc_cnt, out_data, out_bytemask, out_valid);
    end

    ////////////////////////////////////////////////////////////////////
    // Instantiate the DUT
    ////////////////////////////////////////////////////////////////////
    message_extractor #(
        .MIN_MSG_BYTES       (`MIN_MSG_BYTES),
        .MAX_MSG_BYTES       (`MAX_MSG_BYTES),
        .WIDTH_IN_DATA_BYTES (`WIDTH_IN_DATA_BYTES)
    ) dut(.*);

    ////////////////////////////////////////////////////////////////////
    // Dump waves
    ////////////////////////////////////////////////////////////////////
    initial $dumpvars;

endmodule
