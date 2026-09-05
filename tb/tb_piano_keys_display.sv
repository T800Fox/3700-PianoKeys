
`timescale 1ns/1ns

module tb_piano_keys_display;

    logic clk = 0;

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

    logic [2:0] difficulty_level;

    wire [6:0] score_ones_HEX;
    wire [6:0] score_tens_HEX;

    wire [2:0] score_multi_leds;

    wire [6:0] lane_0_HEX;
    wire [6:0] lane_1_HEX;
    wire [6:0] lane_2_HEX;
    wire [6:0] lane_3_HEX;

    wire [3:0] lane_leds;
    wire [2:0] difficulty_leds;


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

        .difficulty_level(difficulty_level),

        .score_ones_HEX(score_ones_HEX),
        .score_tens_HEX(score_tens_HEX),

        .score_multi_leds(score_multi_leds),

        .lane_0_HEX(lane_0_HEX),
        .lane_1_HEX(lane_1_HEX),
        .lane_2_HEX(lane_2_HEX),
        .lane_3_HEX(lane_3_HEX),

        .lane_leds(lane_leds),
        .difficulty_leds(difficulty_leds)
    );

    task automatic toggle_check_lane_led(
        ref   logic  lane_led_input,
        input int    lane_index,
        input string test_name,
        input string lane_number
    );
        lane_led_input = 0;
        #1;
        if (lane_leds[lane_index] !== 0)
            $fatal(1, "FAIL %sa: lane %s LED not off; expected 0 got %b",
                    test_name, lane_number, lane_leds[lane_index]);

        lane_led_input = 1;
        #1;
        if (lane_leds[lane_index] !== 1)
            $fatal(1, "FAIL %sb: lane %s LED not on; expected 1 got %b",
                    test_name, lane_number, lane_leds[lane_index]);

        $display("PASS %s: led for lane %s toggles correctly", test_name, lane_number);
    endtask


    /* verilator lint_off BLKSEQ */
    always #10 clk = ~clk;   // 20 ns period, like the DE1-SoC's 50 MHz
    /* verilator lint_on BLKSEQ */

    initial begin : waveform_dump
        if ($test$plusargs("dump")) begin
`ifdef VERILATOR
            $dumpfile("waveform.fst");
`else
            $dumpfile("waveform.vcd");
`endif
            $dumpvars(0, tb_score_handler);
        end
    end

    initial begin : test_cases

        // Test 1: Display single digit score
        score_value = 5;
        #1;
        if (score_ones_HEX !== 7'b0010010)
            $fatal(1, "FAIL test 1a: ones score digit not correctly displayed; expected %b got %b",
                    7'b0010010, score_ones_HEX);
        if (score_tens_HEX !== 7'b1000000)
            $fatal(1, "FAIL test 1b: tens score digit not correctly displayed; expected %b got %b",
                    7'b1000000, score_tens_HEX);
        $display("PASS test 1: correctly displays single digit score");

        // Test 2: Display double digit score
        score_value = 42;
        #1;
        if (score_ones_HEX !== 7'b0100100)
            $fatal(1, "FAIL test 2a: ones score digit not correctly displayed; expected %b got %b",
                    7'b0100100, score_ones_HEX);
        if (score_tens_HEX !== 7'b0011001)
            $fatal(1, "FAIL test 2b: tens score digit not correctly displayed; expected %b got %b",
                    7'b0011001, score_tens_HEX);
        $display("PASS test 2: correctly displays double digit score");

        // Test 3: Displays overflow bits for score above 99
        score_value = 101;
        #1;
        if (score_ones_HEX !== 7'b0111111)
            $fatal(1, "FAIL test 3a: ones score digit not correctly displayed; expected %b got %b",
                    7'b0111111, score_ones_HEX);
        if (score_tens_HEX !== 7'b0111111)
            $fatal(1, "FAIL test 3b: tens score digit not correctly displayed; expected %b got %b",
                    7'b0111111, score_tens_HEX);
        $display("PASS test 3: correctly displays overflowed bits f/ score above 99") ;
        

        // Test 4: Lane 0 hit LED's 
        toggle_check_lane_led(lane_0_led, 0, "test 4", "0");
        #1;

        // Test 5: Lane 1 hit LED's 
        toggle_check_lane_led(lane_1_led, 1, "test 5", "1");
        #1;

        // Test 6: Lane 2 hit LED's 
        toggle_check_lane_led(lane_2_led, 2, "test 6", "2");
        #1;

        // Test 7: Lane 3 hit LED's 
        toggle_check_lane_led(lane_3_led, 3, "test 7", "3");
        #1;


        // Test 8: X1 multiplier
        score_multi = 2'b00;
        #1;
        if (score_multi_leds !== 3'b100)
            $fatal(1, "FAIL test 8: X1 score multiplier incorrectly displayed; expected %b got %b",
                    3'b100, score_multi_leds);
        $display("PASS test 8: X1 score multiplier correctly displayed");

        // Test 9: X2 multiplier
        score_multi = 2'b01;
        #1;
        if (score_multi_leds !== 3'b010)
            $fatal(1, "FAIL test 9: X2 score multiplier incorrectly displayed; expected %b got %b",
                    3'b010, score_multi_leds);
        $display("PASS test 9: X2 score multiplier correctly displayed");

        // Test 10: X4 multiplier
        score_multi = 2'b10;
        #1;
        if (score_multi_leds !== 3'b001)
            $fatal(1, "FAIL test 10: X4 score multiplier incorrectly displayed; expected %b got %b",
                    3'b001, score_multi_leds);
        $display("PASS test 10: X4 score multiplier correctly displayed");


        // Test 11: Difficulty level 0
        difficulty_level = 3'd0;
        #1;
        if (difficulty_leds !== 3'b001)
            $fatal(1, "FAIL test 11: difficulty level 0 incorrectly displayed; expected %b got %b",
                    3'b001, difficulty_leds);
        $display("PASS test 11: difficulty level 0 correctly displayed");

        // Test 12: Difficulty level 1
        difficulty_level = 3'd1;
        #1;
        if (difficulty_leds !== 3'b010)
            $fatal(1, "FAIL test 12: difficulty level 1 incorrectly displayed; expected %b got %b",
                    3'b010, difficulty_leds);
        $display("PASS test 12: difficulty level 1 correctly displayed");

        // Test 13: Difficulty level 2 (and above) falls through to the default pattern
        difficulty_level = 3'd2;
        #1;
        if (difficulty_leds !== 3'b100)
            $fatal(1, "FAIL test 13: difficulty level 2 incorrectly displayed; expected %b got %b",
                    3'b100, difficulty_leds);
        $display("PASS test 13: difficulty level 2 correctly displayed");

        // Test 14: Confirm the ternary's default branch also catches out-of-range values
        difficulty_level = 3'd7;
        #1;
        if (difficulty_leds !== 3'b100)
            $fatal(1, "FAIL test 14: difficulty level 7 (out-of-range) incorrectly displayed; expected %b got %b",
                    3'b100, difficulty_leds);
        $display("PASS test 14: difficulty level 7 falls through to default pattern");


        $display("ALL TESTS PASSED: tb_piano_keys_display");
        $finish;
    end

endmodule
