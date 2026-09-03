
`timescale 1ns/1ns

module tb_score_handler;

    localparam logic [1:0] PERFECT = 2'b00;
    localparam logic [1:0] NORMAL  = 2'b01;
    localparam logic [1:0] POOR    = 2'b10;
    localparam logic [1:0] BAD     = 2'b11;

    logic clk = 0;
    logic rst;

    logic l0_valid;
    logic [1:0] l0_quality;

    logic l1_valid;
    logic [1:0] l1_quality;

    logic l2_valid;
    logic [1:0] l2_quality;

    logic l3_valid;
    logic [1:0] l3_quality;

    logic [6:0] score;
    logic [1:0] curr_multi_state;


    score_handler #(
        .MAX_SCORE(99),
        .CONSEC_PERFECT_FOR_MOVE_TO_X2(2),
        .CONSEC_PERFECT_FOR_MOVE_TO_X4(4)
    ) dut (
        .clk(clk),
        .rst(rst),

        .l_0_quality_valid(l0_valid),
        .l_0_quality_value(l0_quality),

        .l_1_quality_valid(l1_valid),
        .l_1_quality_value(l1_quality),

        .l_2_quality_valid(l2_valid),
        .l_2_quality_value(l2_quality),

        .l_3_quality_valid(l3_valid),
        .l_3_quality_value(l3_quality),

        .score(score),
        .curr_multi_state(curr_multi_state)
    );


    always #5 clk = ~clk;


    task automatic send_l0(
        input logic [1:0] q
    );

        @(negedge clk);

        l0_quality = q;
        l0_valid = 1;

        @(posedge clk);
        #1;

        @(negedge clk);

        l0_valid = 0;

    endtask


    initial begin

        rst = 1;

        l0_valid = 0;
        l1_valid = 0;
        l2_valid = 0;
        l3_valid = 0;

        l0_quality = NORMAL;
        l1_quality = NORMAL;
        l2_quality = NORMAL;
        l3_quality = NORMAL;

        repeat (2) @(posedge clk);
        #1;

        rst = 0;


        send_l0(NORMAL);

        if (score !== 1)
            $fatal(1, "FAIL: normal hit should add one");


        send_l0(PERFECT);

        if (score !== 2)
            $fatal(
                1,
                "FAIL: X1 perfect should add one"
            );


        send_l0(PERFECT);

        if (
            score !== 3 ||
            curr_multi_state !== 2'b01
        )
            $fatal(
                1,
                "FAIL: second perfect should engage X2"
            );


        send_l0(PERFECT);

        if (score !== 5)
            $fatal(
                1,
                "FAIL: X2 perfect should add two"
            );


        send_l0(POOR);

        if (score !== 5)
            $fatal(
                1,
                "FAIL: poor hit should not add score"
            );


        send_l0(BAD);

        if (score !== 4)
            $fatal(
                1,
                "FAIL: bad hit should subtract one"
            );


        $display(
            "ALL TESTS PASSED: tb_score_handler"
        );

        $finish;
    end

endmodule
