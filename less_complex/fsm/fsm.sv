module fsm(
    input logic clk,
    input logic reset,
    input logic x1,

    output logic outp
);

enum logic [1:0] {SX='x, S1=0, S2, S3, S4} state_current, state_next;

always @(posedge clk or posedge reset) begin
    if(reset) begin
        state_current <= S1;
    end else begin
        state_current <= state_next;
    end
end

always @* begin
    casez({state_current, x1})
        {S1, 1'd0}: state_next = S3;
        {S1, 1'd1}: state_next = S2;
        {S2, 1'd?}: state_next = S4;
        {S3, 1'd?}: state_next = S4;
        {S4, 1'd?}: state_next = S1;

        // Drive x's to detect cases we don't expect to hit
        // Would add x assertions to catch this if Icarus Verilog supported them
        default: state_next = SX;
    endcase
end

// Moore outputs
assign outp = ((state_current == S1) || (state_current == S2));

endmodule : fsm
