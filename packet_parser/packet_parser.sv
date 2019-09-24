/* TODO:
    1. Align data
    2. Drive byteen
    3. Drive sop
    4. Drive eop
    5. Describe module
    6. Describe synthesis guards
    7. Add Icarus Verilog notes: SV interfaces, assertions, always_{ff, comb}, ...
*/

module packet_parser #(
    parameter WIDTH_DATA_BYTES  = 8,
    parameter WIDTH_HDR_A_BYTES = 6,
    parameter WIDTH_HDR_B_BYTES = 4
) (
    // Inputs
    input logic clk_host,
    input logic rst_n,

    input logic bus_in_eop,
    input logic bus_in_sop,

    input logic bus_in_valid,

    input logic [WIDTH_DATA_BYTES - 1:0] bus_in_byteen,

    input logic [WIDTH_DATA_BITS - 1:0] bus_in_data,

    // Outputs
    output logic bus_out_eop,
    output logic bus_out_sop,

    output logic bus_out_valid,

    output logic [WIDTH_DATA_BYTES - 1:0] bus_out_byteen,

    output logic [WIDTH_DATA_BITS - 1:0] bus_out_data,

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

logic [WIDTH_HDR_A_BITS - 1:0] headerA_aligned;
logic [WIDTH_HDR_B_BITS - 1:0] headerB_aligned;

//logic [WIDTH_DATA_ALIGNMENT_BITS - 1:0] data_alignment_buffer;
//logic [WIDTH_DATA_LOWER_PORTION  - 1:0] data_frac_portion;
logic [WIDTH_DATA_BITS           - 1:0] data_aligned;

logic [WIDTH_HDR_CYC_CNT_BITS - 1:0] hdr_cyc_cnt;

logic start_hdr_cnt_next;

logic set_valid_next;
logic clr_valid_next;

// Iterate through header cycles
assign start_hdr_cnt_next = bus_in_valid && bus_in_sop;

always @(posedge clk_host) begin
    if(!rst_n || (hdr_cyc_cnt == LAST_HDR_B_CYC)) begin
        hdr_cyc_cnt <= {WIDTH_HDR_CYC_CNT_BITS{1'd0}};
    end else begin
        if(start_hdr_cnt_next || (hdr_cyc_cnt > {WIDTH_HDR_CYC_CNT_BITS{1'd0}})) begin
            hdr_cyc_cnt <= hdr_cyc_cnt + 1'd1;
        end else begin
            hdr_cyc_cnt <= hdr_cyc_cnt;
        end
    end
end

// Align headers
always @(posedge clk_host) begin
    if(!rst_n) begin
        headerA_aligned <= {WIDTH_HDR_A_BITS{1'd0}};
    end else begin
        if(hdr_cyc_cnt == LAST_HDR_A_CYC) begin
            headerA_aligned <= (headerA_aligned << WIDTH_HDR_A_FRAC_BITS) | bus_in_data[WIDTH_DATA_BITS - 1:HDR_A_FRAC_LSB];
        end else if(SYNTH_GUARD_HDR_A_CYC_LAST_GT_0 && (hdr_cyc_cnt < LAST_HDR_A_CYC)) begin
            headerA_aligned <= (headerA_aligned << WIDTH_DATA_BITS      ) | bus_in_data;
        end else begin
            headerA_aligned <= headerA_aligned;
        end
    end
end

always @(posedge clk_host) begin
    if(!rst_n) begin
        headerB_aligned <= {WIDTH_HDR_B_BITS{1'd0}};
    end else begin
        if(SYNTH_GUARD_HDR_B_CYC_LAST_EQ_FIRST && ((hdr_cyc_cnt == FIRST_HDR_B_CYC) && (hdr_cyc_cnt == LAST_HDR_B_CYC))) begin
            headerB_aligned <= (headerB_aligned << WIDTH_HDR_B_FRAC_MIDDLE_BITS) | bus_in_data[HDR_B_FRAC_MSB:HDR_B_FRAC_LSB * SYNTH_GUARD_HDR_B_CYC_LAST_EQ_FIRST];
        end else if(SYNTH_GUARD_HDR_B_CYC_LAST_NEQ_FIRST && (hdr_cyc_cnt == FIRST_HDR_B_CYC)) begin
            headerB_aligned <= (headerB_aligned << WIDTH_HDR_B_FRAC_LOWER_BITS ) | bus_in_data[HDR_B_FRAC_MSB:0];
        end else if(SYNTH_GUARD_HDR_B_CYC_LAST_NEQ_FIRST && (hdr_cyc_cnt == LAST_HDR_B_CYC)) begin
            headerB_aligned <= (headerB_aligned << WIDTH_HDR_B_FRAC_UPPER_BITS ) | bus_in_data[WIDTH_DATA_BITS - 1:HDR_B_FRAC_LSB];
        end else if(SYNTH_GUARD_HDR_B_CYC_LAST_GT_FIRST_PLUS_1 && ((hdr_cyc_cnt > FIRST_HDR_B_CYC) && (hdr_cyc_cnt < LAST_HDR_B_CYC))) begin
            headerB_aligned <= (headerB_aligned << WIDTH_DATA_BITS             ) | bus_in_data;
        end else begin
            headerB_aligned <= headerB_aligned;
        end
    end
end

// Drive outputs
assign set_valid_next = hdr_cyc_cnt == LAST_HDR_B_CYC;
assign clr_valid_next = bus_out_valid && bus_out_eop;

always @(posedge clk_host) bus_out_valid <= (
                                    !rst_n ||
                                    clr_valid_next
                            ) ? 1'd0 : (set_valid_next || bus_out_valid);

assign headerA      = bus_out_valid ? headerA_aligned : {WIDTH_HDR_A_BITS{1'd0}};
assign headerB      = bus_out_valid ? headerB_aligned : {WIDTH_HDR_B_BITS{1'd0}};
assign bus_out_data = bus_out_valid ?    data_aligned : {WIDTH_DATA_BITS {1'd0}};

endmodule
