// Converts one raw active-low board button into one pulse per physical press.
module button_conditioner #(
    parameter DEBOUNCE_COUNTS = 2500
) (
    input  logic clk,
    input  logic reset,
    input  logic button,
    output logic press_pulse
);

    logic button_pressed;
    logic previous_button;

    debounce #(
        .DELAY_COUNTS(DEBOUNCE_COUNTS)
    ) u_debounce (
        .clk            (clk),
        .reset          (reset),
        .button         (~button),
        .button_pressed (button_pressed)
    );

    always_ff @(posedge clk) begin
        if (reset)
            previous_button <= 1'b0;
        else
            previous_button <= button_pressed;
    end

    assign press_pulse = button_pressed && !previous_button;

endmodule
