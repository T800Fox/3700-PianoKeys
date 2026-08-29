// Adapted from the Reaction Time Game synchroniser lesson module.
module synchroniser (
    input  wire clk,
    input  wire reset,
    input  wire x,
    output wire y
);

    reg x_q0, x_q1;

    always @(posedge clk) begin
        if (reset) begin
            x_q0 <= 1'b0;
            x_q1 <= 1'b0;
        end
        else begin
            x_q0 <= x;
            x_q1 <= x_q0;
        end
    end

    assign y = x_q1;

endmodule
