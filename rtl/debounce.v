// Adapted from the Reaction Time Game debounce lesson module.
module debounce #(
    parameter DELAY_COUNTS = 2500
) (
    input  wire clk,
    input  wire reset,
    input  wire button,
    output reg  button_pressed
);

    localparam COUNT_WIDTH =
        (DELAY_COUNTS <= 1) ? 1 : $clog2(DELAY_COUNTS);

    wire button_sync;
    reg [COUNT_WIDTH-1:0] count;

    synchroniser u_synchroniser (
        .clk   (clk),
        .reset (reset),
        .x     (button),
        .y     (button_sync)
    );

    always @(posedge clk) begin
        if (reset) begin
            count          <= {COUNT_WIDTH{1'b0}};
            button_pressed <= 1'b0;
        end
        else if (button_sync == button_pressed) begin
            count <= {COUNT_WIDTH{1'b0}};
        end
        else if (count >= DELAY_COUNTS - 1) begin
            count          <= {COUNT_WIDTH{1'b0}};
            button_pressed <= button_sync;
        end
        else begin
            count <= count + 1'b1;
        end
    end

endmodule
