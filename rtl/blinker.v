// blinker.v, scaffold demo module.
//
// Toggles `out` every CLKS_PER_TOGGLE clock cycles.
//
// The period is a PARAMETER, not a hard-coded number, so that tb_blinker.sv can
// shrink it to 4 cycles and verify the same RTL that goes on the board.
// Motivation: 12.5 million clocks will take ages to simulate, whereas 4 cycles will
// take seconds.

module blinker #(
    parameter CLKS_PER_TOGGLE = 12_500_000   // 0.25 s at 50 MHz -> 2 Hz LED
) (
    input  wire clk,
    input  wire reset,
    output reg  out
);

    // Width derived from the parameter, so the counter adapts if someone
    // overrides CLKS_PER_TOGGLE:
    localparam CW = $clog2(CLKS_PER_TOGGLE);

    // The value the counter stops at, sized to CW bits:
    localparam [CW-1:0] LAST = CLKS_PER_TOGGLE[CW-1:0] - 1'b1;

    reg [CW-1:0] count;

    always @(posedge clk) begin
        if (reset) begin
            count <= {CW{1'b0}};
            out   <= 1'b0;
        end
        else if (count == LAST) begin
            count <= {CW{1'b0}};
            // Toggle the output ("blink the LED"):
            out   <= ~out;
        end
        else begin
            count <= count + 1'b1;
        end
    end

endmodule
