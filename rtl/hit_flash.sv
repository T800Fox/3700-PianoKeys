// Stretches a one-clock hit event into a visible LED indication. Duration is
// measured in subbeat ticks so simulations can use the same module with a
// reduced tick period.

module hit_flash #(
    parameter FLASH_TICKS = 4
) (
    input  logic clk,
    input  logic reset,
    input  logic subbeat_tick,
    input  logic trigger,
    output logic led
);

    localparam COUNTER_WIDTH =
        (FLASH_TICKS <= 1) ? 1 : $clog2(FLASH_TICKS + 1);

    logic [COUNTER_WIDTH-1:0] ticks_remaining;

    always_ff @(posedge clk) begin
        if (reset) begin
            ticks_remaining <= '0;
            led             <= 1'b0;
        end
        else if (trigger) begin
            ticks_remaining <= COUNTER_WIDTH'(FLASH_TICKS);
            led             <= 1'b1;
        end
        else if (led && subbeat_tick) begin
            if (ticks_remaining <= 1) begin
                ticks_remaining <= '0;
                led             <= 1'b0;
            end
            else begin
                ticks_remaining <= ticks_remaining - 1'b1;
            end
        end
    end

endmodule
