////////////////////////////////////////////////////////////////////
// Message Extractor
////////////////////////////////////////////////////////////////////
//
// Author:
//     Will Kohut (kohutw@gmail.com)

`include "global_defines.svh"

module message_extractor #(
    parameter MIN_MSG_BYTES        = 8,
    parameter MAX_MSG_BYTES        = 32,
    parameter WIDTH_IN_DATA_BYTES  = 8
) (
    ////////////////////////////////////////////////////////////////////
    // Inputs
    ////////////////////////////////////////////////////////////////////

    input  logic                                  clk,
    input  logic                                  reset_n, // Synchronous, active-low reset

    input  logic                                  in_valid,
    input  logic                                  in_startofpacket,
    input  logic                                  in_endofpacket,
    input  logic [`WIDTH_IN_EMPTY_BITS  - 1:0]    in_empty,
    input  logic                                  in_error,
    input  logic [`WIDTH_IN_DATA_BITS   - 1:0]    in_data,

    output logic                                  in_ready,

    ////////////////////////////////////////////////////////////////////
    // Outputs
    ////////////////////////////////////////////////////////////////////

    output logic                                  out_valid,
    output logic [`WIDTH_OUT_DATA_BITS  - 1:0]    out_data,
    output logic [`WIDTH_OUT_DATA_BYTES - 1:0]    out_bytemask
);

    ////////////////////////////////////////////////////////////////////
    // Local parameters
    ////////////////////////////////////////////////////////////////////

    localparam BITS_PER_BYTE                   =  `BITS_PER_BYTE;

    localparam WIDTH_IN_DATA_BITS              =  `WIDTH_IN_DATA_BITS;

    localparam WIDTH_MSG_CNT_BYTES             =  `WIDTH_MSG_CNT_BYTES;
    localparam WIDTH_MSG_LEN_BYTES             =  `WIDTH_MSG_LEN_BYTES;

    localparam WIDTH_MSG_CNT_BITS              =  WIDTH_MSG_CNT_BYTES * BITS_PER_BYTE;
    localparam WIDTH_MSG_LEN_BITS              =  WIDTH_MSG_LEN_BYTES * BITS_PER_BYTE;

    localparam WIDTH_MSG_LEN_BYTES_HALVED      =  WIDTH_MSG_LEN_BYTES / 2;
    localparam WIDTH_MSG_LEN_BITS_HALVED       =  WIDTH_MSG_LEN_BYTES_HALVED * BITS_PER_BYTE;

    localparam MAX_MSG_CYC                     =  `ceil(MAX_MSG_BYTES, WIDTH_IN_DATA_BYTES)

    localparam WIDTH_MSG_LEN_REM_BITS          =  `bitwidth_of_val(MAX_MSG_BYTES)

    // We subtract 1 because the last word in the message never needs to be stored
    localparam NUM_MSG_BUFFER_WORDS            =  MAX_MSG_CYC - 1;

    localparam WIDTH_DATA_BUFFER_BITS          =  WIDTH_IN_DATA_BITS * NUM_MSG_BUFFER_WORDS;

    localparam WIDTH_PTR_BITS                  =  `bitwidth_of_cnt(MAX_MSG_CYC)

    localparam MAX_DOWNSHIFT_BYTES             =  WIDTH_IN_DATA_BYTES - 1;
    localparam MAX_UPSHIFT_NON_TAIL_OUT_BYTES  =  WIDTH_IN_DATA_BYTES;
    localparam MAX_UPSHIFT_TAIL_OUT_BYTES      =  WIDTH_IN_DATA_BYTES * 2;

    localparam WIDTH_DOWNSHIFT_BITS            =  `bitwidth_of_val(MAX_DOWNSHIFT_BYTES)
    localparam WIDTH_UPSHIFT_NON_TAIL_OUT_BITS =  `bitwidth_of_val(MAX_UPSHIFT_NON_TAIL_OUT_BYTES)
    localparam WIDTH_UPSHIFT_TAIL_OUT_BITS     =  `bitwidth_of_val(MAX_UPSHIFT_TAIL_OUT_BYTES)

    ////////////////////////////////////////////////////////////////////
    // Declarations
    ////////////////////////////////////////////////////////////////////

    logic                                         get_new_msg_len_from_sop,
                                                  get_new_msg_len_from_straddle_next,
                                                  get_new_msg_len_from_straddle,
                                                  get_new_msg_len_from_shift;

    logic [WIDTH_MSG_LEN_BITS - 1:0]              msg_len_from_sop,
                                                  msg_len_from_straddle,
                                                  msg_len_from_shift;

    logic [WIDTH_MSG_LEN_REM_BITS - 1:0]          msg_len_rem_bytes,
                                                  msg_len_rem_bytes_next;

    logic [WIDTH_DATA_BUFFER_BITS - 1:0]          data_buffer;

    logic [NUM_MSG_BUFFER_WORDS - 1:0]            mask_buffer;

    logic [WIDTH_MSG_LEN_BITS_HALVED - 1:0]       straddle_hi,
                                                  straddle_lo;

    logic [WIDTH_PTR_BITS - 1:0]                  head_ptr,
                                                  tail_ptr;

    logic                                         nothing_to_store,
                                                  nothing_to_store_next;

    logic [WIDTH_DOWNSHIFT_BITS - 1:0]            head_in_downshift_bytes_next,
                                                  head_in_downshift_bytes,
                                                  head_in_downshift_bytes_prev;

    logic [WIDTH_UPSHIFT_NON_TAIL_OUT_BITS - 1:0] head_out_upshift_bytes,
                                                  tail_in_upshift_bytes,
                                                  tail_in_upshift_bytes_next;

    logic [WIDTH_UPSHIFT_TAIL_OUT_BITS - 1:0]     tail_out_upshift_bytes;

    logic [WIDTH_IN_DATA_BITS - 1:0]              head_out_bitmask,
                                                  tail_out_bitmask;

    logic [MAX_MSG_CYC - 1:0]                     is_head,
                                                  is_head_nowrap,
                                                  is_tail;

    logic [WIDTH_IN_DATA_BYTES - 1:0]             head_out_bytemask,
                                                  tail_out_bytemask;

    logic [WIDTH_IN_DATA_BITS - 1:0]              msg_len_from_shift_wide;

    logic [WIDTH_IN_DATA_BITS - 1:0]              head_in_data,
                                                  head_in_data_out,
                                                  tail_in_data;

    logic [WIDTH_IN_DATA_BITS - 1:0]              head_out_data,
                                                  tail_out_data;

    logic                                         last_cyc_in_msg,
                                                  last_cyc_in_msg_next,
                                                  last_cyc_in_msg_vld;

    logic                                         use_head;

    ////////////////////////////////////////////////////////////////////
    // Determine how to decrement remaining message length
    ////////////////////////////////////////////////////////////////////

    // The requirements say that in_empty should only be qualified with the
    // incoming end of packet, which suggests that in_startofpacket and
    // in_endofpacket imply in_valid is asserted simultaneously. Adding an
    // assertion at the end of this file to enforce that.
    assign get_new_msg_len_from_sop = in_startofpacket;

    assign get_new_msg_len_from_shift = msg_len_rem_bytes <= (WIDTH_IN_DATA_BYTES - WIDTH_MSG_LEN_BYTES);

    assign get_new_msg_len_from_straddle_next = (WIDTH_IN_DATA_BYTES - msg_len_rem_bytes) == WIDTH_MSG_LEN_BYTES_HALVED;

    always_ff @(posedge clk) begin
        if(!reset_n) begin
            get_new_msg_len_from_straddle <= 1'b0;
        end else begin
            get_new_msg_len_from_straddle <= get_new_msg_len_from_straddle_next;
        end
    end

    ////////////////////////////////////////////////////////////////////
    // Prepare inputs to decrement logic
    ////////////////////////////////////////////////////////////////////

    always_ff @(posedge clk) begin
        if(!reset_n) begin
            straddle_lo <= {WIDTH_MSG_LEN_BITS_HALVED{1'b0}};
        end else begin
            if(in_valid) begin
                straddle_lo <= in_data[WIDTH_IN_DATA_BITS - 1 -:WIDTH_MSG_LEN_BITS_HALVED];
            end else begin
                straddle_lo <= straddle_lo;
            end
        end
    end

    assign straddle_hi = in_data[WIDTH_MSG_LEN_BITS_HALVED - 1:0];

    assign msg_len_from_shift_wide = in_data >> (msg_len_rem_bytes * BITS_PER_BYTE);

    ////////////////////////////////////////////////////////////////////
    // Reset and decrement remaining message length
    ////////////////////////////////////////////////////////////////////

    always_comb begin
        msg_len_from_sop      = reverse_byte_endianness(in_data[WIDTH_MSG_CNT_BITS + WIDTH_MSG_LEN_BITS - 1 -:WIDTH_MSG_LEN_BITS]);
        msg_len_from_straddle = reverse_byte_endianness({straddle_hi, straddle_lo});
        msg_len_from_shift    = reverse_byte_endianness(msg_len_from_shift_wide[WIDTH_MSG_LEN_BITS - 1:0]);

        // Unique keyword shortens path by allowing parallel case evaluation
        unique casez({
            // The requirements say that in_empty should only be qualified with the
            // incoming end of packet, which suggests that in_startofpacket and
            // in_endofpacket imply in_valid is asserted simultaneously. Adding an
            // assertion at the end of this file to enforce that.
            get_new_msg_len_from_sop,
            get_new_msg_len_from_straddle_next || in_endofpacket,
            get_new_msg_len_from_straddle,
            get_new_msg_len_from_shift
        })
            4'b1???: msg_len_rem_bytes_next = msg_len_from_sop      - (WIDTH_IN_DATA_BYTES - WIDTH_MSG_CNT_BYTES - WIDTH_MSG_LEN_BYTES);
            4'b01??: msg_len_rem_bytes_next = {WIDTH_MSG_LEN_REM_BITS{1'b0}};
            4'b001?: msg_len_rem_bytes_next = msg_len_from_straddle - (WIDTH_IN_DATA_BYTES - WIDTH_MSG_LEN_BYTES_HALVED);
            4'b0001: msg_len_rem_bytes_next = msg_len_from_shift    - (WIDTH_IN_DATA_BYTES - WIDTH_MSG_LEN_BYTES - msg_len_rem_bytes);
            default: msg_len_rem_bytes_next = msg_len_rem_bytes     -  WIDTH_IN_DATA_BYTES;
        endcase
    end

    always_ff @(posedge clk) begin
        if(!reset_n) begin
            msg_len_rem_bytes <= {WIDTH_MSG_LEN_REM_BITS{1'b0}};
        end else begin
            if(in_valid) begin
                msg_len_rem_bytes <= msg_len_rem_bytes_next;
            end else begin
                msg_len_rem_bytes <= msg_len_rem_bytes;
            end
        end
    end

    ////////////////////////////////////////////////////////////////////
    // Manage buffer word pointers
    ////////////////////////////////////////////////////////////////////

    assign last_cyc_in_msg_next = (msg_len_rem_bytes_next <= WIDTH_IN_DATA_BYTES) && |msg_len_rem_bytes_next;

    assign nothing_to_store_next = (msg_len_rem_bytes_next >= (WIDTH_IN_DATA_BYTES - WIDTH_MSG_LEN_BYTES)) &&
                                   (msg_len_rem_bytes_next <=  WIDTH_IN_DATA_BYTES);

    always_ff @(posedge clk) begin
        if(!reset_n) begin
            nothing_to_store <= 1'b0;
        end else begin
            if(in_valid) begin
                nothing_to_store <= nothing_to_store_next;
            end else begin
                nothing_to_store <= nothing_to_store;
            end
        end
    end

    always_ff @(posedge clk) begin
        if(!reset_n) begin
            head_ptr <= {WIDTH_PTR_BITS{1'b0}};
            tail_ptr <= {WIDTH_PTR_BITS{1'b0}};
        end else begin
            if(in_valid) begin
                // The requirements say that in_empty should only be qualified with the
                // incoming end of packet, which suggests that in_startofpacket and
                // in_endofpacket imply in_valid is asserted simultaneously. Adding an
                // assertion at the end of this file to enforce that.
                head_ptr <= (last_cyc_in_msg_next || nothing_to_store || in_endofpacket) ?
                            {WIDTH_PTR_BITS{1'b0}} :
                            head_ptr + 1'b1;

                tail_ptr <= head_ptr;
            end else begin
                head_ptr <= head_ptr;
                tail_ptr <= tail_ptr;
            end
        end
    end

    ////////////////////////////////////////////////////////////////////
    // Construct and apply buffer bytemasks
    ////////////////////////////////////////////////////////////////////

    assign head_in_downshift_bytes_next = msg_len_rem_bytes_next + WIDTH_MSG_LEN_BYTES;

    assign tail_in_upshift_bytes_next = WIDTH_IN_DATA_BYTES - head_in_downshift_bytes;

    always_ff @(posedge clk) begin
        // The requirements say that in_empty should only be qualified with the
        // incoming end of packet, which suggests that in_startofpacket and
        // in_endofpacket imply in_valid is asserted simultaneously. Adding an
        // assertion at the end of this file to enforce that.
        if(!reset_n || in_endofpacket) begin
            head_in_downshift_bytes_prev <= {WIDTH_DOWNSHIFT_BITS{1'b0}};
            head_in_downshift_bytes      <=                        WIDTH_MSG_CNT_BYTES + WIDTH_MSG_LEN_BYTES;
            tail_in_upshift_bytes        <= WIDTH_IN_DATA_BYTES - (WIDTH_MSG_CNT_BYTES + WIDTH_MSG_LEN_BYTES);
        end else begin
            if(in_valid && last_cyc_in_msg_next) begin
                head_in_downshift_bytes      <= head_in_downshift_bytes_next;
                head_in_downshift_bytes_prev <= head_in_downshift_bytes;
            end else begin
                head_in_downshift_bytes      <= head_in_downshift_bytes;
                head_in_downshift_bytes_prev <= head_in_downshift_bytes_prev;
            end

            if(in_valid && last_cyc_in_msg) begin
                tail_in_upshift_bytes <= tail_in_upshift_bytes_next;
            end else begin
                tail_in_upshift_bytes <= tail_in_upshift_bytes;
            end
        end
    end

    assign use_head = msg_len_rem_bytes > head_in_downshift_bytes_prev;

    assign head_in_data     = in_data >> (head_in_downshift_bytes      * BITS_PER_BYTE);
    assign head_in_data_out = in_data >> (head_in_downshift_bytes_prev * BITS_PER_BYTE);
    assign tail_in_data     = in_data << (tail_in_upshift_bytes        * BITS_PER_BYTE);

    assign head_out_upshift_bytes = msg_len_rem_bytes - head_in_downshift_bytes_prev;
    assign tail_out_upshift_bytes = msg_len_rem_bytes + tail_in_upshift_bytes;

    assign head_out_bytemask = ~({WIDTH_IN_DATA_BYTES{1'b1}} << head_out_upshift_bytes);
    assign tail_out_bytemask = ~({WIDTH_IN_DATA_BYTES{1'b1}} << tail_out_upshift_bytes);

    genvar byte_i;

    generate
        for(byte_i = 0; byte_i < WIDTH_IN_DATA_BYTES; byte_i = byte_i + 1) begin: out_bitmasks
            assign head_out_bitmask[BITS_PER_BYTE * byte_i +:BITS_PER_BYTE] = {BITS_PER_BYTE{head_out_bytemask[byte_i]}};
            assign tail_out_bitmask[BITS_PER_BYTE * byte_i +:BITS_PER_BYTE] = {BITS_PER_BYTE{tail_out_bytemask[byte_i]}};
        end
    endgenerate

    assign head_out_data = head_in_data_out & head_out_bitmask;
    assign tail_out_data = tail_in_data     & tail_out_bitmask;

    ////////////////////////////////////////////////////////////////////
    // Loop over all words in output
    ////////////////////////////////////////////////////////////////////
    genvar word_i;

    generate
        for(word_i = 0; word_i < MAX_MSG_CYC; word_i = word_i + 1) begin: buffer_and_output
            localparam CURR_WORD_LSBYTE = WIDTH_IN_DATA_BYTES * word_i;
            localparam CURR_WORD_LSBIT  = CURR_WORD_LSBYTE * BITS_PER_BYTE;

            assign is_head       [word_i] = head_ptr == word_i;
            assign is_tail       [word_i] = tail_ptr == word_i;

            assign is_head_nowrap[word_i] = (tail_ptr + 1'b1) == word_i;

            ////////////////////////////////////////////////////////////////////
            // Buffer input data stream and manage bytemask
            ////////////////////////////////////////////////////////////////////

            // Don't reset the first word after last cycle in message; overwrite
            // it instead. This prevents us from squashing new data when we wrap.
            if(word_i == 0) begin
                always_ff @(posedge clk) begin
                    if(!reset_n) begin
                        data_buffer[CURR_WORD_LSBIT +:WIDTH_IN_DATA_BITS] <= {WIDTH_IN_DATA_BITS{1'b0}};

                        // We assume a minimum message length of
                        // WIDTH_IN_DATA_BYTES and enforce with an assertion
                        mask_buffer[word_i] <= 1'b1;
                    end else begin
                        // Unique keyword shortens path by allowing parallel case evaluation
                        unique casez({
                            is_head[word_i],
                            is_tail[word_i]
                        })
                            2'b1?:   data_buffer[CURR_WORD_LSBIT +:WIDTH_IN_DATA_BITS] <= head_in_data;
                            2'b01:   data_buffer[CURR_WORD_LSBIT +:WIDTH_IN_DATA_BITS] <= data_buffer[CURR_WORD_LSBIT +:WIDTH_IN_DATA_BITS] | tail_in_data;
                            default: data_buffer[CURR_WORD_LSBIT +:WIDTH_IN_DATA_BITS] <= data_buffer[CURR_WORD_LSBIT +:WIDTH_IN_DATA_BITS];
                        endcase

                        mask_buffer[word_i] <= mask_buffer[word_i];
                    end
                end
            end else if(word_i < NUM_MSG_BUFFER_WORDS) begin
                always_ff @(posedge clk) begin
                    if(!reset_n || last_cyc_in_msg_vld) begin
                        data_buffer[CURR_WORD_LSBIT +:WIDTH_IN_DATA_BITS] <= {WIDTH_IN_DATA_BITS{1'b0}};
                        mask_buffer[word_i]                               <= 1'b0;
                    end else begin
                        // Unique keyword shortens path by allowing parallel case evaluation
                        unique casez({
                            is_head[word_i],
                            is_tail[word_i]
                        })
                            2'b1?:   data_buffer[CURR_WORD_LSBIT +:WIDTH_IN_DATA_BITS] <= head_in_data;
                            2'b01:   data_buffer[CURR_WORD_LSBIT +:WIDTH_IN_DATA_BITS] <= data_buffer[CURR_WORD_LSBIT +:WIDTH_IN_DATA_BITS] | tail_in_data;
                            default: data_buffer[CURR_WORD_LSBIT +:WIDTH_IN_DATA_BITS] <= data_buffer[CURR_WORD_LSBIT +:WIDTH_IN_DATA_BITS];
                        endcase

                        mask_buffer[word_i] <= mask_buffer[word_i] | is_tail[word_i];
                    end
                end
            end

            ////////////////////////////////////////////////////////////////////
            // Drive outputs
            ////////////////////////////////////////////////////////////////////

            if(word_i < NUM_MSG_BUFFER_WORDS) begin
                always_comb begin
                    // Unique keyword shortens path by allowing parallel case evaluation
                    unique casez({
                         is_head_nowrap[word_i] && use_head,
                         is_tail       [word_i]
                    })
                        2'b1?: begin
                            out_data    [CURR_WORD_LSBIT  +:WIDTH_IN_DATA_BITS ] = head_out_data;
                            out_bytemask[CURR_WORD_LSBYTE +:WIDTH_IN_DATA_BYTES] = head_out_bytemask;
                        end

                        2'b01: begin
                            out_data    [CURR_WORD_LSBIT  +:WIDTH_IN_DATA_BITS ] = data_buffer[CURR_WORD_LSBIT +:WIDTH_IN_DATA_BITS] | tail_out_data;
                            out_bytemask[CURR_WORD_LSBYTE +:WIDTH_IN_DATA_BYTES] = tail_out_bytemask;
                        end

                        default: begin
                            out_data    [CURR_WORD_LSBIT  +:WIDTH_IN_DATA_BITS ] = data_buffer[CURR_WORD_LSBIT +:WIDTH_IN_DATA_BITS];
                            out_bytemask[CURR_WORD_LSBYTE +:WIDTH_IN_DATA_BYTES] = {WIDTH_IN_DATA_BYTES{mask_buffer[word_i]}};
                        end
                    endcase
                end
            end else begin
                // The most significant word doesn't need mask buffer storage
                assign out_data    [CURR_WORD_LSBIT  +:WIDTH_IN_DATA_BITS ] = (is_head_nowrap[word_i] && use_head) ? head_out_data     : {WIDTH_IN_DATA_BITS {1'b0}};
                assign out_bytemask[CURR_WORD_LSBYTE +:WIDTH_IN_DATA_BYTES] = (is_head_nowrap[word_i] && use_head) ? head_out_bytemask : {WIDTH_IN_DATA_BYTES{1'b0}};
            end
        end
    endgenerate

    always_ff @(posedge clk) begin
        if(!reset_n) begin
            last_cyc_in_msg <= 1'b0;
        end else begin
            if(in_valid) begin
                last_cyc_in_msg <= last_cyc_in_msg_next;
            end else begin
                last_cyc_in_msg <= last_cyc_in_msg;
            end
        end
    end

    assign last_cyc_in_msg_vld = last_cyc_in_msg && in_valid;

    assign out_valid = last_cyc_in_msg_vld;

    // Serial-in-parallel-out paradigm implies that we're always ready by design
    assign in_ready = 1'b1;

    ////////////////////////////////////////////////////////////////////
    // Functions
    ////////////////////////////////////////////////////////////////////

    function  logic [WIDTH_MSG_LEN_BITS - 1:0] reverse_byte_endianness(
        input logic [WIDTH_MSG_LEN_BITS - 1:0] data
    );

        // We could also use the stream operator, but synthesizability may
        // still be questionable for some tools
        for(int byte_i = 0; byte_i < WIDTH_MSG_LEN_BYTES; byte_i = byte_i + 1) begin
            reverse_byte_endianness[((WIDTH_MSG_LEN_BYTES - byte_i) * BITS_PER_BYTE) - 1 -:BITS_PER_BYTE] =
                               data[((                      byte_i) * BITS_PER_BYTE)     +:BITS_PER_BYTE];
        end

    endfunction

    ////////////////////////////////////////////////////////////////////
    // Assertions
    ////////////////////////////////////////////////////////////////////

    `ifndef SYNTHESIS
        initial begin
            assert(MIN_MSG_BYTES <= MAX_MSG_BYTES) else
                $fatal(0, "Minimum message length (%0d bytes) must less than or equal to maximum message length (%0d bytes)", MIN_MSG_BYTES, MAX_MSG_BYTES);

            // Enforce serial-in-parallel-out paradigm
            assert(MIN_MSG_BYTES >= WIDTH_IN_DATA_BYTES) else
                $fatal(0, "Minimum message length (%0d bytes) must be greater than or equal to in_data bus width (%0d bytes)", MIN_MSG_BYTES, WIDTH_IN_DATA_BYTES);
        end

        // Sample assertions on negedge to avoid race conditions
        always_ff @(negedge clk) begin
            assert(!in_valid || !(|in_error === 1'b1)) else
                $fatal(0, "in_error is non-zero (%0b)", in_error);

            // The requirements say that in_empty should only be qualified with the
            // incoming end of packet, which suggests that in_startofpacket and
            // in_endofpacket imply in_valid is asserted simultaneously.
            // TODO: Needs some tweaking to play nicely with random bubbles
            //assert(!((in_startofpacket === 1'b1) || (in_endofpacket === 1'b1)) || in_valid) else
            //    $fatal(0, "in_startofpacket=%b, in_endofpacket=%b, in_valid=%b", in_startofpacket, in_endofpacket, in_valid);

            // TODO: Assert if packet is greater than 1500 bytes
            //assert() else
            //    $fatal(0, "", );

            /* TODO: These need a little fine-tuning
            assert(!(in_valid && get_new_msg_len_from_sop)      || (MIN_MSG_BYTES <= msg_len_from_sop)) else
                $fatal(0, "Minimum message length (%0d bytes) must be less than or equal to message length from start of packet (%0d)", MIN_MSG_BYTES, msg_len_from_sop);

            assert(!(in_valid && get_new_msg_len_from_sop)      || (MAX_MSG_BYTES >= msg_len_from_sop)) else
                $fatal(0, "Maximum message length (%0d bytes) must be greater than or equal to message length from start of packet (%0d)", MAX_MSG_BYTES, msg_len_from_sop);

            assert(!(in_valid && get_new_msg_len_from_straddle) || (MIN_MSG_BYTES <= msg_len_from_straddle)) else
                $fatal(0, "Minimum message length (%0d bytes) must be less than or equal to message length from straddle (%0d)", MIN_MSG_BYTES, msg_len_from_straddle);

            assert(!(in_valid && get_new_msg_len_from_straddle) || (MAX_MSG_BYTES >= msg_len_from_straddle)) else
                $fatal(0, "Maximum message length (%0d bytes) must be greater than or equal to message length from straddle (%0d)", MAX_MSG_BYTES, msg_len_from_straddle);

            assert(!(in_valid && get_new_msg_len_from_shift)    || (MIN_MSG_BYTES <= msg_len_from_shift)) else
                $fatal(0, "Minimum message length (%0d bytes) must be less than or equal to message length from shift (%0d)", MIN_MSG_BYTES, msg_len_from_shift);

            assert(!(in_valid && get_new_msg_len_from_shift)    || (MAX_MSG_BYTES >= msg_len_from_shift)) else
                $fatal(0, "Maximum message length (%0d bytes) must be greater than or equal to message length from shift (%0d)", MAX_MSG_BYTES, msg_len_from_shift);
            */
        end
    `endif

endmodule
