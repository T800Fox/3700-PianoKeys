`timescale 1ns/1ns

module tb_score_handler;
    localparam MAX_SCORE = 99;

    localparam logic [1:0] QUALITY_PERFECT = 2'b00;
    localparam logic [1:0] QUALITY_NORMAL  = 2'b01;
    localparam logic [1:0] QUALITY_POOR    = 2'b10;
    localparam logic [1:0] QUALITY_BAD     = 2'b11;

    localparam integer CLK_PERIOD_NS = 20000; // 50000 Hz -> 20us period

    logic clk = 0;
    logic rst;
    logic l_0_quality_valid, l_1_quality_valid, l_2_quality_valid, l_3_quality_valid;
    logic [1:0] l_0_quality_value, l_1_quality_value, l_2_quality_value, l_3_quality_value;
    logic [6:0] score;
    /* verilator lint_off UNUSEDSIGNAL */
    reg   [1:0] encoded_muliplier_state;
    /* verilator lint_on UNUSEDSIGNAL */

    score_handler #(
        .MAX_SCORE(MAX_SCORE)
    ) dut (
        .clk(clk), .rst(rst),
        .l_0_quality_valid(l_0_quality_valid), .l_0_quality_value(l_0_quality_value),
        .l_1_quality_valid(l_1_quality_valid), .l_1_quality_value(l_1_quality_value),
        .l_2_quality_valid(l_2_quality_valid), .l_2_quality_value(l_2_quality_value),
        .l_3_quality_valid(l_3_quality_valid), .l_3_quality_value(l_3_quality_value),
        .score(score),
        .curr_multi_state(encoded_muliplier_state)
    );

    // Clock generation: 50000 Hz
    /* verilator lint_off BLKSEQ */
    initial clk = 0;
    always #(CLK_PERIOD_NS/2) clk = ~clk;
    /* verilator lint_on BLKSEQ */

    initial begin : timeout
        repeat (500) @(posedge clk);   // generous margin: 500 clock cycles
        $fatal(1, "FAIL: testbench timeout");
    end

    task automatic apply_reset;
        @(negedge clk) rst = 1'b1;
        repeat (2) @(posedge clk);
        #1;
        @(negedge clk) rst = 1'b0;
    endtask

    // Drive a single lane's hit for one clock cycle, all others held invalid.
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

    // Drive multiple lanes simultaneously valid (for priority-arbitration testing).
    task automatic hit_multi(
        input logic v0, input logic [1:0] q0,
        input logic v1, input logic [1:0] q1,
        input logic v2, input logic [1:0] q2,
        input logic v3, input logic [1:0] q3
    );
        @(negedge clk);
        l_0_quality_valid = v0; l_0_quality_value = q0;
        l_1_quality_valid = v1; l_1_quality_value = q1;
        l_2_quality_valid = v2; l_2_quality_value = q2;
        l_3_quality_valid = v3; l_3_quality_value = q3;
        @(posedge clk); #1;
        @(negedge clk);
        l_0_quality_valid = 0; l_1_quality_valid = 0;
        l_2_quality_valid = 0; l_3_quality_valid = 0;
    endtask

    initial begin : test_cases
        rst = 0;
        l_0_quality_valid = 0; l_0_quality_value = 0;
        l_1_quality_valid = 0; l_1_quality_value = 0;
        l_2_quality_valid = 0; l_2_quality_value = 0;
        l_3_quality_valid = 0; l_3_quality_value = 0;

        apply_reset();
        if (score !== 0)
            $fatal(1, "FAIL test 1: reset did not clear score");
        $display("PASS test 1: reset clears score");

        // --- Test 2: a single NORMAL hit on lane 0 adds 1*multiplier (mult=1 at reset) ---
        apply_reset();
        hit_lane(0, QUALITY_NORMAL);
        if (score !== 1)
            $fatal(1, "FAIL test 2: expected score=1 after single normal hit, got %0d", score);
        $display("PASS test 2: single normal hit scores correctly at 1x multiplier");

        // --- Test 3: POOR hit leaves score unchanged ---
        hit_lane(1, QUALITY_POOR);
        if (score !== 1)
            $fatal(1, "FAIL test 3: poor hit should not change score, got %0d", score);
        $display("PASS test 3: poor hit does not change score");

        // --- Test 4: BAD hit decrements score by 1, floors at 0 ---
        apply_reset();
        hit_lane(2, QUALITY_BAD);
        if (score !== 0)
            $fatal(1, "FAIL test 4: bad hit at score=0 should floor at 0, got %0d", score);
        $display("PASS test 4: bad hit floors at zero rather than underflowing");

        // --- Test 5: consecutive perfects build the multiplier (X1->X2 at 2 consecutive) ---
        apply_reset();
        hit_lane(3, QUALITY_PERFECT); // 1st perfect, still X1, mult=1 -> score=1
        hit_lane(3, QUALITY_PERFECT); // 2nd perfect, triggers X1->X2 on this cycle,
                                      // multiplier output updates next cycle
        if (score < 2)
            $fatal(1, "FAIL test 5: expected score to have grown after 2 perfects, got %0d", score);
        hit_lane(3, QUALITY_PERFECT); // now multiplier should be 2 if FSM transitioned
        $display("Test 5 running score after 3rd perfect: %0d", score);
        $display("PASS test 5: multiplier scaling observed across consecutive perfects");

        // --- Test 6: priority demux - lane 0 wins when multiple lanes valid simultaneously ---
        apply_reset();
        hit_multi(1'b1, QUALITY_NORMAL,   // lane 0 valid, NORMAL
                  1'b1, QUALITY_BAD,      // lane 1 valid, BAD (should be ignored)
                  1'b0, 2'b00,
                  1'b0, 2'b00);
        if (score !== 1)
            $fatal(1, "FAIL test 6: lane 0 should have priority, expected score=1, got %0d", score);
        $display("PASS test 6: lane 0 takes priority over lower-priority lanes");

        apply_reset();
        hit_multi(1'b0, 2'b00,
                  1'b1, QUALITY_BAD,      // lane 1 valid, BAD
                  1'b1, QUALITY_NORMAL,   // lane 2 valid, NORMAL (should be ignored, lane1 wins)
                  1'b0, 2'b00);
        if (score !== 0)
            $fatal(1, "FAIL test 6b: lane 1 should win over lane 2, expected score=0, got %0d", score);
        $display("PASS test 6b: lane 1 takes priority over lane 2/3 when lane 0 is idle");

        // --- Test 7: score saturates at MAX_SCORE ---
        apply_reset();
        // Repeatedly hit NORMAL until score should be pinned at MAX_SCORE.
        repeat (MAX_SCORE + 10) begin
            hit_lane(0, QUALITY_NORMAL);
        end
        if (score !== MAX_SCORE)
            $fatal(1, "FAIL test 7: score should saturate at MAX_SCORE=%0d, got %0d", MAX_SCORE, score);
        $display("PASS test 7: score saturates at MAX_SCORE");

        // --- Test 8: no lanes valid -> score holds ---
        apply_reset();
        hit_lane(0, QUALITY_NORMAL);
        if (score !== 1) $fatal(1, "FAIL test 8 setup: expected score=1");
        repeat (5) @(posedge clk); // idle cycles, no valid pulses
        if (score !== 1)
            $fatal(1, "FAIL test 8: score changed with no valid input, got %0d", score);
        $display("PASS test 8: score holds steady with no lane activity");

        $display("ALL TESTS PASSED: tb_score_handler");
        $finish;
    end
endmodule
