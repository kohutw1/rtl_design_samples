/*

Title:  Divisible-by-5 Detector

Author: Will Kohut (www.github.com/kohutw1/rtl_design_samples)

Description:
    Detect if n is divisible by 5 after shifting a random bit into the LSB position.
    This can be represented by the following:

        n = (n << 1) | in_bit

    We can detect divisibility by 5 of n by tracking the remainder of each new result.
    The remainder can be calculated as follows:

        remainder_next = (2 * remainder_current) + in_bit

    Whenever the current remainder becomes 0, we know the new result is divisible by 5.

    The legal remainder values are [0, 1, 2, 3, 4]. Whenever the new result goes beyond
    4, we wrap back to 0. This behavior is captured in the truth table below:

    in_bit remainder_current | remainder_next
    =========================================
         0 000 (0)           | 000 (0)
         0 001 (1)           | 010 (2)
         0 010 (2)           | 100 (4)
         0 011 (3)           | 001 (1)
         0 100 (4)           | 011 (3)
         0 101               | xxx
         0 110               | xxx
         0 111               | xxx
         1 000 (0)           | 001 (1)
         1 001 (1)           | 011 (3)
         1 010 (2)           | 000 (0)
         1 011 (3)           | 010 (2)
         1 100 (4)           | 100 (4)
         1 101               | xxx
         1 110               | xxx
         1 111               | xxx

    Note: Icarus Verilog doesn't seem to support always_ff or always_comb yet
*/

`define WIDTH_REM 3

module div_5_detector(
    input logic clk,
    input logic rst_n,

    input logic in_bit,

    output logic div_5
);

logic first_1_seen;
logic [`WIDTH_REM-1:0] remainder_current;
logic [`WIDTH_REM-1:0] remainder_next;

// We can't be div_5 on reset, so generate a signal to guard against this
always @(posedge clk) begin
    if(!rst_n) begin
        first_1_seen <= 1'd0;
    end else begin
        if(in_bit) begin
            first_1_seen <= 1'd1;
        end else begin
            first_1_seen <= first_1_seen;
        end
    end
end

// State update
always @(posedge clk) remainder_current <= !rst_n ? {`WIDTH_REM{1'd0}} : remainder_next;

// Next state logic
always @* begin
    case({in_bit, remainder_current})
        // Shift in 0: remainder_next = remainder_current << 1 | 0 [remainder_next = (2 * remainder_current) + 0]
        {1'd0, `WIDTH_REM'd0}: remainder_next = `WIDTH_REM'd0;
        {1'd0, `WIDTH_REM'd1}: remainder_next = `WIDTH_REM'd2;
        {1'd0, `WIDTH_REM'd2}: remainder_next = `WIDTH_REM'd4;
        {1'd0, `WIDTH_REM'd3}: remainder_next = `WIDTH_REM'd1;
        {1'd0, `WIDTH_REM'd4}: remainder_next = `WIDTH_REM'd3;

        // Shift in 1: remainder_next = remainder_current << 1 | 1 [remainder_next = (2 * remainder_current) + 1]
        {1'd1, `WIDTH_REM'd0}: remainder_next = `WIDTH_REM'd1;
        {1'd1, `WIDTH_REM'd1}: remainder_next = `WIDTH_REM'd3;
        {1'd1, `WIDTH_REM'd2}: remainder_next = `WIDTH_REM'd0;
        {1'd1, `WIDTH_REM'd3}: remainder_next = `WIDTH_REM'd2;
        {1'd1, `WIDTH_REM'd4}: remainder_next = `WIDTH_REM'd4;

        // Drive x's to detect cases we don't expect to hit
        // Would add x assertions to catch this if Icarus Verilog supported them
        default: remainder_next = {`WIDTH_REM{1'bx}};
    endcase
end

// Moore output
assign div_5 = (remainder_current == `WIDTH_REM'd0) && first_1_seen;

endmodule : div_5_detector
