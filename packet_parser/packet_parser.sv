/*

Title:  Packet Parser

Author: Will Kohut (www.github.com/kohutw1/rtl_design_samples)

Description:
    Introduction

    Consider an interface which streams packets of data. The interface is comprised of a 64-bit wide
    data bus, an 8-bit byte enable vector, valid, start of packet, and end of packet flags. All
    signals are synchronous to the rising edge of the clock. The start and end of packet flag are
    high for one clock cycle at the beginning and end of packets, respectively. The valid flag is
    high for the duration of the packet. The length of the packet can be any number of bytes. The
    data inside of the packet is contiguous and 64-bit aligned, meaning a packet always start at bit
    64 (big endian) and all data words are completely full, except for the last one. The byte enable
    vector indicates which data is valid in the last word. Possible values for the byte enable are
    8'b10000000, 8'b11000000, 8'b11100000, 8'b11110000, etc. Within the packet the byte enable
    should always be 8'b11111111.

    Exercise

    Consider a stream of packets. The packets have several headers at the beginning of the packet.
    Parse the header fields, remove the headers, and output the remainder of the data realigned. The
    packet has the following format:

    Header A: 6 bytes
    Header B: 4 bytes

    63                              0
    ---------------------------------
    |      Header A      | Header B |
    ---------------------------------
    | Header B |        Data        |
    ---------------------------------
    |             Data              |
    ---------------------------------
    |             ...               |
    ---------------------------------

    The output should stream the realigned packets, plus additional signals for the parsed headers.

    Example

    The waveforms in waveforms.png show the expected output for one single input example packet.
    Your module should be able to parse any number of packets of any size.
*/

module packet_parser #(
    parameter WIDTH_DATA_BYTES  = 8,
    parameter WIDTH_HDR_A_BYTES = 6,
    parameter WIDTH_HDR_B_BYTES = 4
) (
    // Inputs
    input logic clk_host,
    input logic rst_n,

    input logic bus_in_valid,

    input logic bus_in_sop,
    input logic bus_in_eop,

    input logic [ WIDTH_DATA_BYTES      - 1:0] bus_in_byteen,
    input logic [(WIDTH_DATA_BYTES * 8) - 1:0] bus_in_data,

    // Outputs
    output logic bus_out_valid,

    output logic bus_out_sop,
    output logic bus_out_eop,

    output logic [ WIDTH_DATA_BYTES      - 1:0] bus_out_byteen,
    output logic [(WIDTH_DATA_BYTES * 8) - 1:0] bus_out_data,

    output logic [(WIDTH_HDR_A_BYTES * 8) - 1:0] headerA,
    output logic [(WIDTH_HDR_B_BYTES * 8) - 1:0] headerB
);

localparam WIDTH_DATA_BITS  = WIDTH_DATA_BYTES  * 8;
localparam WIDTH_HDR_A_BITS = WIDTH_HDR_A_BYTES * 8;
localparam WIDTH_HDR_B_BITS = WIDTH_HDR_B_BYTES * 8;

localparam HDR_A_CYC_LAST = ((WIDTH_HDR_A_BYTES % WIDTH_DATA_BYTES) == 0) ?
                            ((WIDTH_HDR_A_BYTES / WIDTH_DATA_BYTES) - 1) :
                            ( WIDTH_HDR_A_BYTES / WIDTH_DATA_BYTES);

localparam HDR_B_CYC_LAST = (((WIDTH_HDR_A_BYTES + WIDTH_HDR_B_BYTES) % WIDTH_DATA_BYTES) == 0) ?
                            (((WIDTH_HDR_A_BYTES + WIDTH_HDR_B_BYTES) / WIDTH_DATA_BYTES) - 1) :
                            ( (WIDTH_HDR_A_BYTES + WIDTH_HDR_B_BYTES) / WIDTH_DATA_BYTES);

localparam HDR_B_CYC_FIRST = WIDTH_HDR_A_BYTES / WIDTH_DATA_BYTES;

localparam SYNTH_GUARD_HDR_A_CYC_LAST_GT_0            = HDR_A_CYC_LAST > 0;
localparam SYNTH_GUARD_HDR_B_CYC_LAST_EQ_FIRST        = HDR_B_CYC_LAST == HDR_B_CYC_FIRST;
localparam SYNTH_GUARD_HDR_B_CYC_LAST_NEQ_FIRST       = !SYNTH_GUARD_HDR_B_CYC_LAST_EQ_FIRST;
localparam SYNTH_GUARD_HDR_B_CYC_LAST_GT_FIRST_PLUS_1 = HDR_B_CYC_LAST > (HDR_B_CYC_FIRST + 1);

localparam WIDTH_HDR_CYC_CNT_BITS = (HDR_B_CYC_LAST == 0) ? 1 : $clog2(HDR_B_CYC_LAST + 1);

localparam HDR_A_FRAC_LSB = ((WIDTH_DATA_BYTES - ( WIDTH_HDR_A_BYTES                      % WIDTH_DATA_BYTES)) % WIDTH_DATA_BYTES) * 8;
localparam HDR_B_FRAC_LSB = ((WIDTH_DATA_BYTES - ((WIDTH_HDR_A_BYTES + WIDTH_HDR_B_BYTES) % WIDTH_DATA_BYTES)) % WIDTH_DATA_BYTES) * 8;
localparam HDR_B_FRAC_MSB = ((WIDTH_HDR_A_BYTES % WIDTH_DATA_BYTES) == 0) ? (WIDTH_DATA_BITS - 1) : (HDR_A_FRAC_LSB - 1);

localparam WIDTH_HDR_A_FRAC_BITS        = WIDTH_DATA_BITS - HDR_A_FRAC_LSB;
localparam WIDTH_HDR_B_FRAC_MIDDLE_BITS = HDR_B_FRAC_MSB - HDR_B_FRAC_LSB + 1;
localparam WIDTH_HDR_B_FRAC_LOWER_BITS  = HDR_B_FRAC_MSB + 1;
localparam WIDTH_HDR_B_FRAC_UPPER_BITS  = WIDTH_DATA_BITS - HDR_B_FRAC_LSB;

localparam HDR_B_CYC_LAST_BYTES = (WIDTH_HDR_A_BYTES + WIDTH_HDR_B_BYTES) % WIDTH_DATA_BYTES;

localparam TRIVIAL_BYTEEN_AND_DATA_PASSTHROUGH = HDR_B_FRAC_LSB == 0;

logic [WIDTH_HDR_A_BITS - 1:0] aligned_headerA;
logic [WIDTH_HDR_B_BITS - 1:0] aligned_headerB;
logic [WIDTH_DATA_BYTES - 1:0] aligned_byteen;
logic [WIDTH_DATA_BITS  - 1:0] aligned_data;

logic [WIDTH_HDR_CYC_CNT_BITS - 1:0] hdr_cyc_cnt;

logic start_hdr_cnt_next;
logic cnt_hdr_0_multiple_times;

logic set_valid_next;
logic clr_valid_next;

logic in_valid_eop;

logic [WIDTH_HDR_A_BITS - 1:0] icarus_verilog_bug_workaround_0;
logic [WIDTH_HDR_A_BITS - 1:0] icarus_verilog_bug_workaround_1;
logic [WIDTH_HDR_B_BITS - 1:0] icarus_verilog_bug_workaround_2;
logic [WIDTH_HDR_B_BITS - 1:0] icarus_verilog_bug_workaround_3;
logic [WIDTH_HDR_B_BITS - 1:0] icarus_verilog_bug_workaround_4;
logic [WIDTH_HDR_B_BITS - 1:0] icarus_verilog_bug_workaround_5;

//////////////////////////////////////////////////////////
// Iterate through header cycles
//////////////////////////////////////////////////////////
assign start_hdr_cnt_next = bus_in_valid && bus_in_sop;

assign cnt_hdr_0_multiple_times = (hdr_cyc_cnt == {WIDTH_HDR_CYC_CNT_BITS{1'd0}}) && !start_hdr_cnt_next;

always @(posedge clk_host) begin
    if(!rst_n || (hdr_cyc_cnt == HDR_B_CYC_LAST)) begin
        hdr_cyc_cnt <= {WIDTH_HDR_CYC_CNT_BITS{1'd0}};
    end else begin
        if((start_hdr_cnt_next || (hdr_cyc_cnt > {WIDTH_HDR_CYC_CNT_BITS{1'd0}}))) begin
            hdr_cyc_cnt <= hdr_cyc_cnt + 1'd1;
        end else begin
            hdr_cyc_cnt <= hdr_cyc_cnt;
        end
    end
end

//////////////////////////////////////////////////////////
// Align headers
//////////////////////////////////////////////////////////
assign icarus_verilog_bug_workaround_0 = (aligned_headerA << WIDTH_HDR_A_FRAC_BITS) | bus_in_data[WIDTH_DATA_BITS - 1:HDR_A_FRAC_LSB];
assign icarus_verilog_bug_workaround_1 = (aligned_headerA << WIDTH_DATA_BITS      ) | bus_in_data;

always @(posedge clk_host) begin
    if(!rst_n) begin
        aligned_headerA <= {WIDTH_HDR_A_BITS{1'd0}};
    end else begin
        if((hdr_cyc_cnt == HDR_A_CYC_LAST) && !cnt_hdr_0_multiple_times) begin
            aligned_headerA <= icarus_verilog_bug_workaround_0;
        end else if(SYNTH_GUARD_HDR_A_CYC_LAST_GT_0 && ((hdr_cyc_cnt < HDR_A_CYC_LAST) && !cnt_hdr_0_multiple_times)) begin
            aligned_headerA <= icarus_verilog_bug_workaround_1;
        end else begin
            aligned_headerA <= aligned_headerA;
        end
    end
end

assign icarus_verilog_bug_workaround_2 = (aligned_headerB << WIDTH_HDR_B_FRAC_MIDDLE_BITS) | bus_in_data[HDR_B_FRAC_MSB:HDR_B_FRAC_LSB * SYNTH_GUARD_HDR_B_CYC_LAST_EQ_FIRST];
assign icarus_verilog_bug_workaround_3 = (aligned_headerB << WIDTH_HDR_B_FRAC_LOWER_BITS ) | bus_in_data[HDR_B_FRAC_MSB:0];
assign icarus_verilog_bug_workaround_4 = (aligned_headerB << WIDTH_HDR_B_FRAC_UPPER_BITS ) | bus_in_data[WIDTH_DATA_BITS - 1:HDR_B_FRAC_LSB];
assign icarus_verilog_bug_workaround_5 = (aligned_headerB << WIDTH_DATA_BITS             ) | bus_in_data;

always @(posedge clk_host) begin
    if(!rst_n) begin
        aligned_headerB <= {WIDTH_HDR_B_BITS{1'd0}};
    end else begin
        if(SYNTH_GUARD_HDR_B_CYC_LAST_EQ_FIRST && ((hdr_cyc_cnt == HDR_B_CYC_FIRST) && !cnt_hdr_0_multiple_times)) begin
            aligned_headerB <= icarus_verilog_bug_workaround_2;
        end else if(SYNTH_GUARD_HDR_B_CYC_LAST_NEQ_FIRST && ((hdr_cyc_cnt == HDR_B_CYC_FIRST) && !cnt_hdr_0_multiple_times)) begin
            aligned_headerB <= icarus_verilog_bug_workaround_3;
        end else if(SYNTH_GUARD_HDR_B_CYC_LAST_NEQ_FIRST && ((hdr_cyc_cnt == HDR_B_CYC_LAST) && !cnt_hdr_0_multiple_times)) begin
            aligned_headerB <= icarus_verilog_bug_workaround_4;
        end else if(SYNTH_GUARD_HDR_B_CYC_LAST_GT_FIRST_PLUS_1 && ((hdr_cyc_cnt > HDR_B_CYC_FIRST) && (hdr_cyc_cnt < HDR_B_CYC_LAST))) begin
            aligned_headerB <= icarus_verilog_bug_workaround_5;
        end else begin
            aligned_headerB <= aligned_headerB;
        end
    end
end

//////////////////////////////////////////////////////////
// Align byteen and data
//////////////////////////////////////////////////////////
if(TRIVIAL_BYTEEN_AND_DATA_PASSTHROUGH) begin
    align_byteen_and_data_trivial #(
        .WIDTH_DATA_BYTES(WIDTH_DATA_BYTES)
    ) align(.*);
end else begin
    align_byteen_and_data #(
        .WIDTH_DATA_BYTES    (WIDTH_DATA_BYTES    ),
        .HDR_B_CYC_LAST_BYTES(HDR_B_CYC_LAST_BYTES)
    ) align(.*);
end

//////////////////////////////////////////////////////////
// Drive outputs
//////////////////////////////////////////////////////////
assign set_valid_next = hdr_cyc_cnt == HDR_B_CYC_LAST;
assign clr_valid_next = bus_out_valid && bus_out_eop;

assign in_valid_eop = bus_in_valid && bus_in_eop;

always @(posedge clk_host) begin
    bus_out_valid <= (!rst_n || clr_valid_next) ? 1'd0 : (set_valid_next || bus_out_valid);
    bus_out_sop   <=  !rst_n                    ? 1'd0 :  set_valid_next;
    bus_out_eop   <=  !rst_n                    ? 1'd0 :  in_valid_eop;
end

assign headerA        = bus_out_valid ? aligned_headerA : {WIDTH_HDR_A_BITS{1'd0}};
assign headerB        = bus_out_valid ? aligned_headerB : {WIDTH_HDR_B_BITS{1'd0}};
assign bus_out_byteen = bus_out_valid ? aligned_byteen  : {WIDTH_DATA_BYTES{1'd0}};
assign bus_out_data   = bus_out_valid ? aligned_data    : {WIDTH_DATA_BITS {1'd0}};

endmodule : packet_parser

//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////

module align_byteen_and_data_trivial #(
    parameter WIDTH_DATA_BYTES = 8
) (
    // Inputs
    input logic [ WIDTH_DATA_BYTES      - 1:0] bus_in_byteen,
    input logic [(WIDTH_DATA_BYTES * 8) - 1:0] bus_in_data,

    // Outputs
    output logic [ WIDTH_DATA_BYTES      - 1:0] aligned_byteen,
    output logic [(WIDTH_DATA_BYTES * 8) - 1:0] aligned_data
);

assign aligned_byteen = bus_in_byteen;
assign aligned_data   = bus_in_data;

endmodule : align_byteen_and_data_trivial

//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////

module align_byteen_and_data #(
    parameter WIDTH_DATA_BYTES     = 8,
    parameter HDR_B_CYC_LAST_BYTES = 1
) (
    // Inputs
    input logic clk_host,
    input logic rst_n,

    input logic bus_out_valid,

    input logic bus_out_eop,

    input logic [ WIDTH_DATA_BYTES      - 1:0] bus_in_byteen,
    input logic [(WIDTH_DATA_BYTES * 8) - 1:0] bus_in_data,

    input logic set_valid_next,

    // Outputs
    output logic [ WIDTH_DATA_BYTES      - 1:0] aligned_byteen,
    output logic [(WIDTH_DATA_BYTES * 8) - 1:0] aligned_data
);

localparam WIDTH_DATA_BITS = WIDTH_DATA_BYTES * 8;

localparam WIDTH_LOWER_BYTEEN_BITS = HDR_B_CYC_LAST_BYTES;
localparam WIDTH_LOWER_DATA_BITS   = HDR_B_CYC_LAST_BYTES * 8;

localparam WIDTH_UPPER_BYTEEN_BITS =  WIDTH_DATA_BYTES - HDR_B_CYC_LAST_BYTES;
localparam WIDTH_UPPER_DATA_BITS   = (WIDTH_DATA_BYTES - HDR_B_CYC_LAST_BYTES) * 8;

localparam LOWER_BYTEEN_LSB = WIDTH_DATA_BYTES -  HDR_B_CYC_LAST_BYTES;
localparam LOWER_DATA_LSB   = WIDTH_DATA_BITS  - (HDR_B_CYC_LAST_BYTES * 8);

localparam UPPER_BYTEEN_MSB = LOWER_BYTEEN_LSB - 1;
localparam UPPER_DATA_MSB   = LOWER_DATA_LSB   - 1;

logic [WIDTH_LOWER_BYTEEN_BITS - 1:0] lower_byteen;
logic [WIDTH_LOWER_DATA_BITS   - 1:0] lower_data;

logic [WIDTH_UPPER_BYTEEN_BITS - 1:0] upper_byteen;
logic [WIDTH_UPPER_DATA_BITS   - 1:0] upper_data;

logic flop_upper;

logic [WIDTH_UPPER_BYTEEN_BITS - 1:0] icarus_verilog_bug_workaround_6;
logic [WIDTH_UPPER_DATA_BITS   - 1:0] icarus_verilog_bug_workaround_7;

assign flop_upper = set_valid_next || (bus_out_valid && !bus_out_eop);

assign lower_byteen = (bus_out_valid && bus_out_eop) ? {WIDTH_LOWER_BYTEEN_BITS{1'd0}} : bus_in_byteen[WIDTH_DATA_BYTES - 1:LOWER_BYTEEN_LSB];
assign lower_data   = (bus_out_valid && bus_out_eop) ? {WIDTH_LOWER_DATA_BITS  {1'd0}} : bus_in_data  [WIDTH_DATA_BITS  - 1:LOWER_DATA_LSB  ];

assign icarus_verilog_bug_workaround_6 = flop_upper ? bus_in_byteen[UPPER_BYTEEN_MSB:0] : upper_byteen;
assign icarus_verilog_bug_workaround_7 = flop_upper ? bus_in_data  [UPPER_DATA_MSB  :0] : upper_data;

always @(posedge clk_host) begin
    upper_byteen <= !rst_n ? {WIDTH_UPPER_BYTEEN_BITS{1'd0}} : icarus_verilog_bug_workaround_6;
    upper_data   <= !rst_n ? {WIDTH_UPPER_DATA_BITS  {1'd0}} : icarus_verilog_bug_workaround_7;
end

assign aligned_byteen = {upper_byteen, lower_byteen};
assign aligned_data   = {upper_data  , lower_data  };

endmodule : align_byteen_and_data
