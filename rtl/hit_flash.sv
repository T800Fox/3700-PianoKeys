// Stretches a one-clock hit event into a fixed-duration LED indication.

module hit_flash #(
    parameter FLASH_MS = 300,
    parameter CLKS_PER_MS = 50000
) (
    input  logic clk,
    input  logic reset,
    input  logic trigger,
    output logic led
);

    localparam FLASH_CLKS = FLASH_MS * CLKS_PER_MS;
    localparam COUNTER_WIDTH =
        (FLASH_CLKS <= 1) ? 1 : $clog2(FLASH_CLKS + 1);

    logic [COUNTER_WIDTH-1:0] clocks_remaining;

    always_ff @(posedge clk) begin
        if (reset) begin
            clocks_remaining <= '0;
            led              <= 1'b0;
        end
        else if (trigger) begin
            clocks_remaining <= COUNTER_WIDTH'(FLASH_CLKS);
            led              <= 1'b1;
        end
        else if (led) begin
            if (clocks_remaining <= 1) begin
                clocks_remaining <= '0;
                led              <= 1'b0;
            end
            else begin
                clocks_remaining <= clocks_remaining - 1'b1;
            end
        end
    end

endmodule
