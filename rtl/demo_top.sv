// demo_top.sv, scaffold demo top level.
//
// Reset is SW0, matching the Assignment 1 interface, where SW0 is the game
// reset.

module demo_top #(
    parameter CLKS_PER_TOGGLE = 12_500_000
) (
    input  logic       CLOCK_50,
    input  logic [3:0] KEY,
    input  logic [9:0] SW,
    output logic [9:0] LEDR,
    output logic [6:0] HEX0,
    output logic [6:0] HEX1,
    output logic [6:0] HEX2,
    output logic [6:0] HEX3,
    output logic [6:0] HEX4,
    output logic [6:0] HEX5
);

    logic heartbeat;

    blinker #(.CLKS_PER_TOGGLE(CLKS_PER_TOGGLE)) u_heartbeat (
        .clk   (CLOCK_50),
        .reset (SW[0]),
        .out   (heartbeat)
    );

    assign LEDR[0]   = heartbeat;
    assign LEDR[4:1] = ~KEY;    // Active low push button, so invert to drive LEDs
    assign LEDR[6:5] = SW[9:8];
    assign LEDR[9:7] = 3'b000;  // Assign every output bit, even unused ones

    assign HEX0 = ~SW[7:1];
    assign HEX1 = 7'b1111111;   // All ones = display off (active low)
    assign HEX2 = 7'b1111111;
    assign HEX3 = 7'b1111111;
    assign HEX4 = 7'b1111111;
    assign HEX5 = 7'b1111111;

endmodule
