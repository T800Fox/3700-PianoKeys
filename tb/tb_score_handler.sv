`timescale 1ns/1ns

module tb_score_handler;
    localparam MAX_SCORE = 99;
    localparam CONSEC_FOR_X2 = 2;
    localparam CONSEC_FOR_X4 = 4;

    localparam logic [1:0] QUALITY_PERFECT = 2'b00;
    localparam logic [1:0] QUALITY_NORMAL  = 2'b01;
    localparam logic [1:0] QUALITY_POOR    = 2'b10;
    localparam logic [1:0] QUALITY_BAD     = 2'b11;

    localparam logic [1:0] MULTI_X1        = 2'b00;
    localparam logic [1:0] MULTI_X2        = 2'b01;
    localparam logic [1:0] MULTI_X4        = 2'b10;


    logic clk = 0;
    logic rst;
    logic l_0_quality_valid, l_1_quality_valid, l_2_quality_valid, l_3_quality_valid;
    logic [1:0] l_0_quality_value, l_1_quality_value, l_2_quality_value, l_3_quality_value;
    logic [6:0] score;
    reg   [1:0] encoded_muliplier_state;

    score_handler #(
        .MAX_SCORE(MAX_SCORE),
        .CONSEC_PERFECT_FOR_MOVE_TO_X2(CONSEC_FOR_X2),
        .CONSEC_PERFECT_FOR_MOVE_TO_X4(CONSEC_FOR_X4)
    ) score_handler_99 (
        .clk(clk), .rst(rst),
        .l_0_quality_valid(l_0_quality_valid), .l_0_quality_value(l_0_quality_value),
        .l_1_quality_valid(l_1_quality_valid), .l_1_quality_value(l_1_quality_value),
        .l_2_quality_valid(l_2_quality_valid), .l_2_quality_value(l_2_quality_value),
        .l_3_quality_valid(l_3_quality_valid), .l_3_quality_value(l_3_quality_value),

        .score(score),
        .curr_multi_state(encoded_muliplier_state)
    );

    /* verilator lint_off BLKSEQ */
    always #10 clk = ~clk;   // 20 ns period, like the DE1-SoC's 50 MHz
    /* verilator lint_on BLKSEQ */

    // Drive a single lane's hit for one clock cycle - all others held invalid
    task automatic hit_lane(input integer lane, input logic [1:0] quality);
        @(negedge clk);
        l_0_quality_valid = (lane == 0);
        l_1_quality_valid = (lane == 1);
        l_2_quality_valid = (lane == 2);
        l_3_quality_valid = (lane == 3);
        l_0_quality_value = (lane == 0) ? quality : 2'b00;
        l_1_quality_value = (lane == 1) ? quality : 2'b00;
        l_2_quality_value = (lane == 2) ? quality : 2'b00;
        l_3_quality_value = (lane == 3) ? quality : 2'b00;
        @(posedge clk); #1;
        @(negedge clk);
        l_0_quality_valid = 0; l_1_quality_valid = 0;
        l_2_quality_valid = 0; l_3_quality_valid = 0;
    endtask

    task automatic do_reset;
        @(negedge clk) rst = 1;
        repeat (2) @(posedge clk);
        #1;
        @(negedge clk) rst = 1'b0;
        #1;
    endtask

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
        // Test 1: Zero's score @ Reset
        do_reset();

        if (score !== 0) $fatal(1, "FAIL test 1a: score=%b during reset, expected 0", score);
        $display("PASS test 1a: reset zero's score");

        if (encoded_muliplier_state !== MULTI_X1) $fatal(1, "FAIL test 1b: multi_enc=%b during reset, expected 2'b00", encoded_muliplier_state);
        $display("PASS test 1b: multilplier FSM @ X1 after reset");


        // Test 2: 1x Normal on each row bring the score up to 4
        hit_lane(0, QUALITY_NORMAL);
        #1;
        hit_lane(1, QUALITY_NORMAL);
        #1;
        hit_lane(2, QUALITY_NORMAL);
        #1;
        hit_lane(3, QUALITY_NORMAL);
        #1;

        if (score !== 4) 
            $fatal(1, "FAIL test 2a: score=%b during reset, expected 4", score);
        $display("PASS test 2a: one normal per. lane gets score 4");

        if (encoded_muliplier_state !== MULTI_X1)
            $fatal(1, "FAIL test 2b: multi_enc=%b after normal hits, expected 2'b00", encoded_muliplier_state);
        $display("PASS test 2b: multilplier FSM @ X1 after consecutive normal hits");


        // Test 3: Score Multiplier Behaviour for X2
        do_reset();

        repeat (CONSEC_FOR_X2) hit_lane(0, QUALITY_PERFECT);
        if (score !== CONSEC_FOR_X2)
            $fatal(1, "FAIL test 3 setup: expected score=%0d after %0d perfects at 1x, got %0d",
                      CONSEC_FOR_X2, CONSEC_FOR_X2, score);

        $display("INFO test 3: Setup has score @ %0d ", score);
        hit_lane(0, QUALITY_PERFECT); // one more perfect gets x2 multiplier applied
        $display("INFO test 3: multi_enc=%b and score=%0d after extra Perfect", encoded_muliplier_state, score);

        if (score !== CONSEC_FOR_X2 + 2)
            $fatal(1, "FAIL test 3a: expected score=%0d after multiplier bump to x2, got %0d",
                      CONSEC_FOR_X2 + 2, score);
        $display("PASS test 3a: multiplier increases to x2 after %0d consecutive perfects", CONSEC_FOR_X2);

        if (encoded_muliplier_state !== MULTI_X2)
            $fatal(1, "FAIL test 3b: multi_enc=%b after perfect hits, expected 2'b01", encoded_muliplier_state);
        $display("PASS test 3b: multilplier FSM @ X2 after consecutive perfect hits");


        // Test 4: Score Multiplier Behaviour for X4
        do_reset();
        repeat (CONSEC_FOR_X2) hit_lane(0, QUALITY_PERFECT);
        repeat (CONSEC_FOR_X4) hit_lane(0, QUALITY_PERFECT);
        if (encoded_muliplier_state !== MULTI_X4)
            $fatal(1, "FAIL test 4: expected multiplier=X4 after %0d consecutive perfects, got %b",
                      CONSEC_FOR_X4, encoded_muliplier_state);
        $display("PASS test 4: multiplier reaches X4 after %0d consecutive perfects", CONSEC_FOR_X4);


        // Test 5: Score floors at zero
        do_reset();
        repeat (3) hit_lane(0, QUALITY_BAD);
        if (score !== 0)
            $fatal(1, "FAIL test 5: expected score=0 after consecutive bad reactions, got %0d", score);
        $display("PASS test 5: score has a floor of zero enforced");


        // Test 6: Score has ceil at MAX_SCORE
        do_reset();
        repeat (MAX_SCORE + 2) hit_lane(0, QUALITY_NORMAL);
        if (score !== MAX_SCORE)
            $fatal(1, "FAIL test 6: expected score=%0d (ceiling), got %0d", MAX_SCORE,  score);
        $display("PASS test 5: score has a ceiling of %0d enforced", MAX_SCORE);


        // Test 7: Bad reaction sets multiplier to X1 during a streak
        do_reset();
        repeat (CONSEC_FOR_X2) hit_lane(0, QUALITY_PERFECT);
        repeat (CONSEC_FOR_X4) hit_lane(0, QUALITY_PERFECT);
        if (encoded_muliplier_state !== MULTI_X4)
            $fatal(1, "FAIL test 7 setup: expected enc_multiplier=%b, got %b",
                      MULTI_X4, encoded_muliplier_state);

        hit_lane(0, QUALITY_BAD);
        if (encoded_muliplier_state !== MULTI_X1)
            $fatal(1, "FAIL test 7: expected multiplier=%b after bad reaction during perfect streak, got %b",
                      MULTI_X1, encoded_muliplier_state);
        $display("PASS test 7: multiplier back to X1 when bad reaction ends perfect streak");


        // Test 8: Poor reaction sets multiplier to X1 during a streak
        do_reset();
        repeat (CONSEC_FOR_X2) hit_lane(0, QUALITY_PERFECT);
        repeat (CONSEC_FOR_X4) hit_lane(0, QUALITY_PERFECT);
        if (encoded_muliplier_state !== MULTI_X4)
            $fatal(1, "FAIL test 8 setup: expected enc_multiplier=%b, got %b",
                      MULTI_X4, encoded_muliplier_state);

        hit_lane(0, QUALITY_BAD);
        if (encoded_muliplier_state !== MULTI_X1)
            $fatal(1, "FAIL test 8: expected multiplier=%b after poor reaction during perfect streak, got %b",
                      MULTI_X1, encoded_muliplier_state);
        $display("PASS test 8: multiplier back to X1 when poor reaction ends perfect streak");


        $display("ALL TESTS PASSED: tb_score_handler");
        $finish;
    end
endmodule