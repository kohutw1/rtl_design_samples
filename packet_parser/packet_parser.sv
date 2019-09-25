/* TODO:
    1. Describe module
    2. Describe synthesis guards
    3. Add Icarus Verilog notes: SV interfaces, assertions, always_{ff, comb}, ...
    4. Add section delimiters
    5. Clean up any FIXMEs
    6. Clean up any TODOs
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

    input logic [WIDTH_DATA_BYTES - 1:0] bus_in_byteen,
    input logic [WIDTH_DATA_BITS  - 1:0] bus_in_data,

    // Outputs
    output logic bus_out_valid,

    output logic bus_out_sop,
    output logic bus_out_eop,

    output logic [WIDTH_DATA_BYTES - 1:0] bus_out_byteen,
    output logic [WIDTH_DATA_BITS  - 1:0] bus_out_data,

    output logic [WIDTH_HDR_A_BITS - 1:0] headerA,
    output logic [WIDTH_HDR_B_BITS - 1:0] headerB
);

localparam WIDTH_DATA_BITS  = WIDTH_DATA_BYTES  * 8;
localparam WIDTH_HDR_A_BITS = WIDTH_HDR_A_BYTES * 8;
localparam WIDTH_HDR_B_BITS = WIDTH_HDR_B_BYTES * 8;

localparam LAST_HDR_A_CYC = ((WIDTH_HDR_A_BYTES % WIDTH_DATA_BYTES) == 0) ?
                            ((WIDTH_HDR_A_BYTES / WIDTH_DATA_BYTES) - 1) :
                            ( WIDTH_HDR_A_BYTES / WIDTH_DATA_BYTES);

localparam LAST_HDR_B_CYC = (((WIDTH_HDR_A_BYTES + WIDTH_HDR_B_BYTES) % WIDTH_DATA_BYTES) == 0) ?
                            (((WIDTH_HDR_A_BYTES + WIDTH_HDR_B_BYTES) / WIDTH_DATA_BYTES) - 1) :
                            ( (WIDTH_HDR_A_BYTES + WIDTH_HDR_B_BYTES) / WIDTH_DATA_BYTES);

localparam SYNTH_GUARD_HDR_A_CYC_LAST_GT_0            = LAST_HDR_A_CYC > 0;
localparam SYNTH_GUARD_HDR_B_CYC_LAST_EQ_FIRST        = LAST_HDR_B_CYC == FIRST_HDR_B_CYC;
localparam SYNTH_GUARD_HDR_B_CYC_LAST_NEQ_FIRST       = !SYNTH_GUARD_HDR_B_CYC_LAST_EQ_FIRST;
localparam SYNTH_GUARD_HDR_B_CYC_LAST_GT_FIRST_PLUS_1 = LAST_HDR_B_CYC > (FIRST_HDR_B_CYC + 1);

localparam FIRST_HDR_B_CYC = WIDTH_HDR_A_BYTES / WIDTH_DATA_BYTES;

localparam WIDTH_HDR_CYC_CNT_BITS = (LAST_HDR_B_CYC == 0) ? 1 : $clog2(LAST_HDR_B_CYC + 1);

localparam HDR_A_FRAC_LSB = ((WIDTH_DATA_BYTES - ( WIDTH_HDR_A_BYTES                      % WIDTH_DATA_BYTES)) % WIDTH_DATA_BYTES) * 8;
localparam HDR_B_FRAC_LSB = ((WIDTH_DATA_BYTES - ((WIDTH_HDR_A_BYTES + WIDTH_HDR_B_BYTES) % WIDTH_DATA_BYTES)) % WIDTH_DATA_BYTES) * 8;
localparam HDR_B_FRAC_MSB = ((WIDTH_HDR_A_BYTES % WIDTH_DATA_BYTES) == 0) ? (WIDTH_DATA_BITS - 1) : (HDR_A_FRAC_LSB - 1);

localparam WIDTH_HDR_A_FRAC_BITS        = WIDTH_DATA_BITS - HDR_A_FRAC_LSB;
localparam WIDTH_HDR_B_FRAC_MIDDLE_BITS = HDR_B_FRAC_MSB - HDR_B_FRAC_LSB + 1;
localparam WIDTH_HDR_B_FRAC_LOWER_BITS  = HDR_B_FRAC_MSB + 1;
localparam WIDTH_HDR_B_FRAC_UPPER_BITS  = WIDTH_DATA_BITS - HDR_B_FRAC_LSB;

localparam LAST_HDR_B_CYC_BYTES = (WIDTH_HDR_A_BYTES + WIDTH_HDR_B_BYTES) % WIDTH_DATA_BYTES;

localparam TRIVIAL_BYTEEN_AND_DATA_PASSTHROUGH = HDR_B_FRAC_LSB == 0;

logic [WIDTH_HDR_A_BITS - 1:0] aligned_headerA;
logic [WIDTH_HDR_B_BITS - 1:0] aligned_headerB;
logic [WIDTH_DATA_BYTES - 1:0] aligned_byteen;
logic [WIDTH_DATA_BITS  - 1:0] aligned_data;

logic [WIDTH_HDR_CYC_CNT_BITS - 1:0] hdr_cyc_cnt;

logic start_hdr_cnt_next;
logic reset_hdr_cnt_next;

logic set_valid_next;
logic clr_valid_next;

// Iterate through header cycles
assign start_hdr_cnt_next = bus_in_valid && bus_in_sop;
assign reset_hdr_cnt_next = bus_in_valid && bus_in_eop;

always @(posedge clk_host) begin
    if(!rst_n || reset_hdr_cnt_next) begin
        hdr_cyc_cnt <= {WIDTH_HDR_CYC_CNT_BITS{1'd0}};
    end else begin
        if((start_hdr_cnt_next || (hdr_cyc_cnt > {WIDTH_HDR_CYC_CNT_BITS{1'd0}})) && (hdr_cyc_cnt != LAST_HDR_B_CYC)) begin
            hdr_cyc_cnt <= hdr_cyc_cnt + 1'd1;
        end else begin
            hdr_cyc_cnt <= hdr_cyc_cnt;
        end
    end
end

// Align headers
always @(posedge clk_host) begin
    if(!rst_n) begin
        aligned_headerA <= {WIDTH_HDR_A_BITS{1'd0}};
    end else begin
        if(hdr_cyc_cnt == LAST_HDR_A_CYC) begin
            aligned_headerA <= (aligned_headerA << WIDTH_HDR_A_FRAC_BITS) | bus_in_data[WIDTH_DATA_BITS - 1:HDR_A_FRAC_LSB];
        end else if(SYNTH_GUARD_HDR_A_CYC_LAST_GT_0 && (hdr_cyc_cnt < LAST_HDR_A_CYC)) begin
            aligned_headerA <= (aligned_headerA << WIDTH_DATA_BITS      ) | bus_in_data;
        end else begin
            aligned_headerA <=  aligned_headerA;
        end
    end
end

always @(posedge clk_host) begin
    if(!rst_n) begin
        aligned_headerB <= {WIDTH_HDR_B_BITS{1'd0}};
    end else begin
        if(SYNTH_GUARD_HDR_B_CYC_LAST_EQ_FIRST && ((hdr_cyc_cnt == FIRST_HDR_B_CYC) && (hdr_cyc_cnt == LAST_HDR_B_CYC))) begin
            aligned_headerB <= (aligned_headerB << WIDTH_HDR_B_FRAC_MIDDLE_BITS) | bus_in_data[HDR_B_FRAC_MSB:HDR_B_FRAC_LSB * SYNTH_GUARD_HDR_B_CYC_LAST_EQ_FIRST];
        end else if(SYNTH_GUARD_HDR_B_CYC_LAST_NEQ_FIRST && (hdr_cyc_cnt == FIRST_HDR_B_CYC)) begin
            aligned_headerB <= (aligned_headerB << WIDTH_HDR_B_FRAC_LOWER_BITS ) | bus_in_data[HDR_B_FRAC_MSB:0];
        end else if(SYNTH_GUARD_HDR_B_CYC_LAST_NEQ_FIRST && (hdr_cyc_cnt == LAST_HDR_B_CYC)) begin
            aligned_headerB <= (aligned_headerB << WIDTH_HDR_B_FRAC_UPPER_BITS ) | bus_in_data[WIDTH_DATA_BITS - 1:HDR_B_FRAC_LSB];
        end else if(SYNTH_GUARD_HDR_B_CYC_LAST_GT_FIRST_PLUS_1 && ((hdr_cyc_cnt > FIRST_HDR_B_CYC) && (hdr_cyc_cnt < LAST_HDR_B_CYC))) begin
            aligned_headerB <= (aligned_headerB << WIDTH_DATA_BITS             ) | bus_in_data;
        end else begin
            aligned_headerB <=  aligned_headerB;
        end
    end
end

// Align byteen and data
if(TRIVIAL_BYTEEN_AND_DATA_PASSTHROUGH) begin
    align_byteen_and_data_trivial #(
        .WIDTH_DATA_BYTES(WIDTH_DATA_BYTES)
    ) align(.*);
end else begin
    align_byteen_and_data #(
        .WIDTH_DATA_BYTES(WIDTH_DATA_BYTES),
        .LAST_HDR_B_CYC_BYTES(LAST_HDR_B_CYC_BYTES)
    ) align(.*);
end

// Drive outputs
assign set_valid_next = hdr_cyc_cnt == LAST_HDR_B_CYC;
assign clr_valid_next = bus_out_valid && bus_out_eop;

always @(posedge clk_host) begin
    bus_out_valid <= (!rst_n || clr_valid_next) ? 1'd0 : (set_valid_next || bus_out_valid);
    bus_out_sop   <=  !rst_n                    ? 1'd0 :  set_valid_next;
    bus_out_eop   <=  !rst_n                    ? 1'd0 : (bus_in_valid && bus_in_eop);
end

assign headerA        = bus_out_valid ? aligned_headerA : {WIDTH_HDR_A_BITS{1'd0}};
assign headerB        = bus_out_valid ? aligned_headerB : {WIDTH_HDR_B_BITS{1'd0}};
assign bus_out_byteen = bus_out_valid ? aligned_byteen  : {WIDTH_DATA_BYTES{1'd0}};
assign bus_out_data   = bus_out_valid ? aligned_data    : {WIDTH_DATA_BITS {1'd0}};

endmodule

module align_byteen_and_data_trivial #(
    parameter WIDTH_DATA_BYTES = 8
) (
    // Inputs
    input logic [WIDTH_DATA_BYTES - 1:0] bus_in_byteen,
    input logic [WIDTH_DATA_BITS  - 1:0] bus_in_data,

    // Outputs
    output logic [WIDTH_DATA_BYTES - 1:0] aligned_byteen,
    output logic [WIDTH_DATA_BITS  - 1:0] aligned_data
);

localparam WIDTH_DATA_BITS = WIDTH_DATA_BYTES * 8;

assign aligned_byteen = bus_in_byteen;
assign aligned_data   = bus_in_data;

endmodule

module align_byteen_and_data #(
    parameter WIDTH_DATA_BYTES     = 8,
    parameter LAST_HDR_B_CYC_BYTES = 1
) (
    // Inputs
    input logic clk_host,
    input logic rst_n,

    input logic bus_out_valid,

    input logic bus_out_eop,

    input logic [WIDTH_DATA_BYTES - 1:0] bus_in_byteen,
    input logic [WIDTH_DATA_BITS  - 1:0] bus_in_data,

    input logic set_valid_next,

    // Outputs
    output logic [WIDTH_DATA_BYTES - 1:0] aligned_byteen,
    output logic [WIDTH_DATA_BITS  - 1:0] aligned_data
);

localparam WIDTH_DATA_BITS = WIDTH_DATA_BYTES * 8;

localparam WIDTH_LOWER_BYTEEN_BITS = LAST_HDR_B_CYC_BYTES;
localparam WIDTH_LOWER_DATA_BITS   = LAST_HDR_B_CYC_BYTES * 8;

localparam WIDTH_UPPER_BYTEEN_BITS =  WIDTH_DATA_BYTES - LAST_HDR_B_CYC_BYTES;
localparam WIDTH_UPPER_DATA_BITS   = (WIDTH_DATA_BYTES - LAST_HDR_B_CYC_BYTES) * 8;

localparam LOWER_BYTEEN_LSB = WIDTH_DATA_BYTES -  LAST_HDR_B_CYC_BYTES;
localparam LOWER_DATA_LSB   = WIDTH_DATA_BITS  - (LAST_HDR_B_CYC_BYTES * 8);

localparam UPPER_BYTEEN_MSB = LOWER_BYTEEN_LSB - 1;
localparam UPPER_DATA_MSB   = LOWER_DATA_LSB   - 1;

logic [WIDTH_LOWER_BYTEEN_BITS - 1:0] lower_byteen;
logic [WIDTH_LOWER_DATA_BITS   - 1:0] lower_data;

logic [WIDTH_UPPER_BYTEEN_BITS - 1:0] upper_byteen;
logic [WIDTH_UPPER_DATA_BITS   - 1:0] upper_data;

logic flop_upper;

assign flop_upper = set_valid_next || (bus_out_valid && !bus_out_eop);

assign lower_byteen = (bus_out_valid && bus_out_eop) ? {WIDTH_LOWER_BYTEEN_BITS{1'd0}} : bus_in_byteen[WIDTH_DATA_BYTES - 1:LOWER_BYTEEN_LSB];
assign lower_data   = (bus_out_valid && bus_out_eop) ? {WIDTH_LOWER_DATA_BITS  {1'd0}} : bus_in_data  [WIDTH_DATA_BITS  - 1:LOWER_DATA_LSB  ];

always @(posedge clk_host) begin
    if(!rst_n) begin
        upper_byteen <= {WIDTH_UPPER_BYTEEN_BITS{1'd0}};
        upper_data   <= {WIDTH_UPPER_DATA_BITS  {1'd0}};
    end else begin
        // Clock gate to save power
        if(flop_upper) begin
            upper_byteen <= bus_in_byteen[UPPER_BYTEEN_MSB:0];
            upper_data   <= bus_in_data  [UPPER_DATA_MSB  :0];
        end else begin
            upper_byteen <= upper_byteen;
            upper_data   <= upper_data;
        end
    end
end

assign aligned_byteen = {upper_byteen, lower_byteen};
assign aligned_data   = {upper_data  , lower_data  };

endmodule
