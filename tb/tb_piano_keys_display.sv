
`timescale 1ns/1ns

module tb_piano_keys_display;

    logic [6:0] score_value;
    logic [1:0] score_multi;

    logic [3:0] lane_0_value;
    logic [3:0] lane_1_value;
    logic [3:0] lane_2_value;
    logic [3:0] lane_3_value;

    logic lane_0_led;
    logic lane_1_led;
    logic lane_2_led;
    logic lane_3_led;

    wire [6:0] score_ones_HEX;
    wire [6:0] score_tens_HEX;

    wire [2:0] score_multi_leds;

    wire [6:0] lane_0_HEX;
    wire [6:0] lane_1_HEX;
    wire [6:0] lane_2_HEX;
    wire [6:0] lane_3_HEX;

    wire [3:0] lane_leds;


    piano_keys_display dut (
        .score_value(score_value),
        .score_multi(score_multi),

        .lane_0_value(lane_0_value),
        .lane_1_value(lane_1_value),
        .lane_2_value(lane_2_value),
        .lane_3_value(lane_3_value),

        .lane_0_led(lane_0_led),
        .lane_1_led(lane_1_led),
        .lane_2_led(lane_2_led),
        .lane_3_led(lane_3_led),

        .score_ones_HEX(score_ones_HEX),
        .score_tens_HEX(score_tens_HEX),

        .score_multi_leds(score_multi_leds),

        .lane_0_HEX(lane_0_HEX),
        .lane_1_HEX(lane_1_HEX),
        .lane_2_HEX(lane_2_HEX),
        .lane_3_HEX(lane_3_HEX),

        .lane_leds(lane_leds)
    );


    initial begin

        score_value = 42;
        score_multi = 2'b01;

        lane_0_value = 0;
        lane_1_value = 1;
        lane_2_value = 10;
        lane_3_value = 9;

        lane_0_led = 1;
        lane_1_led = 0;
        lane_2_led = 1;
        lane_3_led = 0;

        #1;

        if (score_ones_HEX !== 7'b0100100)
            $fatal(1, "FAIL: score ones not 2");

        if (score_tens_HEX !== 7'b0011001)
            $fatal(1, "FAIL: score tens not 4");

        if (lane_0_HEX !== 7'b1000000)
            $fatal(1, "FAIL: lane 0");

        if (lane_1_HEX !== 7'b1111001)
            $fatal(1, "FAIL: lane 1");

        if (lane_2_HEX !== 7'b1111111)
            $fatal(1, "FAIL: inactive lane not blank");

        if (lane_3_HEX !== 7'b0010000)
            $fatal(1, "FAIL: lane 3");

        if (lane_leds !== 4'b0101)
            $fatal(1, "FAIL: lane LED mapping");

        if (score_multi_leds !== 3'b010)
            $fatal(1, "FAIL: multiplier LED mapping");

        $display(
            "ALL TESTS PASSED: tb_piano_keys_display"
        );

        $finish;
    end

endmodule
