
`timescale 1ns/1ns

module tb_score_multiplier_fsm;

    localparam logic [1:0] PERFECT = 2'b00;
    localparam logic [1:0] NORMAL  = 2'b01;
    localparam logic [1:0] POOR    = 2'b10;

    logic clk = 0;
    logic rst;

    logic reaction_valid;
    logic [1:0] reaction_quality;

    logic [2:0] current_multiplier;
    logic [1:0] enc_curr_state;


    score_multiplier_fsm #(
        .CONSEC_PERFECT_TO_2(2),
        .CONSEC_PERFECT_TO_4(4)
    ) dut (
        .rst(rst),
        .clk(clk),

        .reaction_valid(reaction_valid),
        .reaction_quality(reaction_quality),

        .current_multiplier(current_multiplier),
        .enc_curr_state(enc_curr_state)
    );


    always #5 clk = ~clk;


    task automatic send_quality(
        input logic [1:0] q
    );

        @(negedge clk);
        reaction_quality = q;
        reaction_valid = 1;

        @(posedge clk);
        #1;

        @(negedge clk);
        reaction_valid = 0;

        #1;

    endtask


    initial begin

        rst = 1;
        reaction_valid = 0;
        reaction_quality = NORMAL;

        repeat (2) @(posedge clk);
        #1;

        rst = 0;

        if (current_multiplier !== 1)
            $fatal(1, "FAIL: multiplier did not reset to X1");


        send_quality(PERFECT);

        if (current_multiplier !== 1)
            $fatal(1, "FAIL: X2 engaged too early");


        send_quality(PERFECT);

        if (
            current_multiplier !== 2 ||
            enc_curr_state !== 2'b01
        )
            $fatal(1, "FAIL: two perfects did not engage X2");


        send_quality(NORMAL);

        if (current_multiplier !== 2)
            $fatal(1, "FAIL: NORMAL incorrectly dropped X2");


        send_quality(PERFECT);
        send_quality(PERFECT);
        send_quality(PERFECT);
        send_quality(PERFECT);

        if (
            current_multiplier !== 4 ||
            enc_curr_state !== 2'b10
        )
            $fatal(
                1,
                "FAIL: four X2 perfects did not engage X4"
            );


        send_quality(POOR);

        if (
            current_multiplier !== 1 ||
            enc_curr_state !== 2'b00
        )
            $fatal(1, "FAIL: miss did not drop multiplier");


        $display(
            "ALL TESTS PASSED: tb_score_multiplier_fsm"
        );

        $finish;
    end

endmodule
