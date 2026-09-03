`timescale 1ns/1ps
module tb_score_multiplier_fsm;
    localparam CONSEC_FOR_X2 = 2;
    localparam CONSEC_FOR_X4 = 4;

    localparam logic [1:0] QUALITY_PERFECT = 2'b00;
    localparam logic [1:0] QUALITY_NORMAL  = 2'b01;
    localparam logic [1:0] QUALITY_POOR    = 2'b10;
    localparam logic [1:0] QUALITY_BAD     = 2'b11;

    localparam logic [1:0] MULTI_X1        = 2'b00;
    localparam logic [1:0] MULTI_X2        = 2'b01;
    localparam logic [1:0] MULTI_X4        = 2'b10;

    logic       clk;
    logic       rst;
    logic       reaction_valid;
    logic [1:0] reaction_quality;
    logic [2:0] current_multiplier;
    reg   [1:0] encoded_muliplier_state;

    score_multiplier_fsm #(
        .CONSEC_PERFECT_TO_2(CONSEC_FOR_X2),
        .CONSEC_PERFECT_TO_4(CONSEC_FOR_X4)
    ) DUT (
        .rst(rst),
        .clk(clk),
        .reaction_valid(reaction_valid),
        .reaction_quality(reaction_quality),
        .current_multiplier(current_multiplier),
        .enc_curr_state(encoded_muliplier_state)
    );

    /* verilator lint_off BLKSEQ */
    always #10 clk = ~clk;   // 20 ns period, like the DE1-SoC's 50 MHz
    /* verilator lint_on BLKSEQ */

    // drive reaction event and wait for it to be sampled
    task automatic send_reaction(input logic [1:0] quality);
        begin
            @(negedge clk);
            reaction_valid   = 1'b1;
            reaction_quality = quality;
            @(negedge clk);
            reaction_valid   = 1'b0;
        end
    endtask

    // let N clock cycles pass with reaction_valid low 
    task automatic idle_cycles(input integer n);
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(negedge clk);
                reaction_valid = 1'b0;
            end
        end
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
            $dumpvars(0, tb_score_multiplier_fsm);
        end
    end

    initial begin

        // Test 1: Idle cycles after a reset don't change a state
        do_reset();
        idle_cycles(5);

        if (encoded_muliplier_state !== MULTI_X1)
            $fatal(1, "FAIL test 1: multi_enc=%b after reset and idle cycles, expected %b", 
            encoded_muliplier_state, MULTI_X1);
        $display("PASS test 1: multilplier FSM @ X1 after reset and idle cycles");


        // Test 2: Drive X1 to X2
        do_reset();
        repeat (CONSEC_FOR_X2) send_reaction(QUALITY_PERFECT);
        idle_cycles(3);

        if (encoded_muliplier_state !== MULTI_X2)
            $fatal(1, "FAIL test 2: multi_enc=%b after %2d perfect reactions, expected %b", 
            encoded_muliplier_state, CONSEC_FOR_X2, MULTI_X2);
        $display("PASS test 2: multilplier FSM @ X2 after reset and %2d perfect reations",
        CONSEC_FOR_X2);
        

        // Test 3: Drive X1 to X2 to X4
        do_reset();
        repeat (CONSEC_FOR_X2) send_reaction(QUALITY_PERFECT);
        repeat (CONSEC_FOR_X4) send_reaction(QUALITY_PERFECT);
        idle_cycles(3);

        if (encoded_muliplier_state !== MULTI_X4)
            $fatal(1, "FAIL test 3: multi_enc=%b after stacked perfect reactions, expected %b", 
            encoded_muliplier_state, MULTI_X4);
        $display("PASS test 3: multilplier FSM @ X4 after reset and stacked perfect reations");


        // Test 4: Normal reactions maintain mutliplier state
        do_reset();
        repeat (CONSEC_FOR_X2) send_reaction(QUALITY_PERFECT);
        repeat (CONSEC_FOR_X4) send_reaction(QUALITY_PERFECT);
        idle_cycles(3);
        send_reaction(QUALITY_NORMAL);
        idle_cycles(3);

        if (encoded_muliplier_state !== MULTI_X4)
            $fatal(1, "FAIL test 4: multi_enc=%b after stacked perfect reactions than normal, expected %b", 
            encoded_muliplier_state, MULTI_X4);
        $display("PASS test 4: normal reaction maintains multiplier");


        // Test 5: Bad reactions reset multiplier 
        do_reset();
        repeat (CONSEC_FOR_X2) send_reaction(QUALITY_PERFECT);
        repeat (CONSEC_FOR_X4) send_reaction(QUALITY_PERFECT);
        idle_cycles(3);
        send_reaction(QUALITY_BAD);
        idle_cycles(3);

        if (encoded_muliplier_state !== MULTI_X1)
            $fatal(1, "FAIL test 5: multi_enc=%b after stacked perfect reactions than bad, expected %b", 
            encoded_muliplier_state, MULTI_X1);
        $display("PASS test 5: bad reaction sets multiplier to X1");


        $display("ALL TESTS PASSED: tb_score_multiplier_fsm");
        $finish;
    end
endmodule

