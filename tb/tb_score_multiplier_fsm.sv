`timescale 1ns/1ps
module tb_score_multiplier_fsm;

    localparam logic [1:0] QUALITY_PERFECT = 2'b00;
    localparam logic [1:0] QUALITY_NORMAL  = 2'b01;
    localparam logic [1:0] QUALITY_POOR    = 2'b10;
    localparam logic [1:0] QUALITY_BAD     = 2'b11;

    localparam integer CLK_PERIOD_NS = 20000; // 50000 Hz -> 20us period

    logic       clk;
    logic       rst;
    logic       reaction_valid;
    logic [1:0] reaction_quality;
    logic [2:0] current_multiplier;
    reg   [1:0] encoded_muliplier_state;

    score_multiplier_fsm #(
        .CONSEC_PERFECT_TO_2(2),
        .CONSEC_PERFECT_TO_4(4)
    ) DUT (
        .rst(rst),
        .clk(clk),
        .reaction_valid(reaction_valid),
        .reaction_quality(reaction_quality),
        .current_multiplier(current_multiplier),
        .enc_curr_state(encoded_muliplier_state)
    );

    // Clock generation: 50000 Hz
    /* verilator lint_off BLKSEQ */
    initial clk = 0;
    always #(CLK_PERIOD_NS/2) clk = ~clk;
    /* verilator lint_on BLKSEQ */

    // Helper task: drive one "reaction" event and wait for it to be sampled
    task automatic send_reaction(input logic [1:0] quality);
        begin
            @(negedge clk);
            reaction_valid   = 1'b1;
            reaction_quality = quality;
            @(negedge clk);
            reaction_valid   = 1'b0;
        end
    endtask

    // Helper task: let N clock cycles pass with reaction_valid low (should have no effect)
    task automatic idle_cycles(input integer n);
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(negedge clk);
                reaction_valid = 1'b0;
            end
        end
    endtask

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, score_multiplier_fsm_tb);

        // Reset
        rst              = 1'b1;
        reaction_valid   = 1'b0;
        reaction_quality = QUALITY_NORMAL;
        repeat (2) @(negedge clk);
        rst = 1'b0;

        // --- Confirm idle cycles with reaction_valid=0 don't change state ---
        idle_cycles(5);

        // --- Drive X1 -> X2 (needs CONSEC_PERFECT_TO_2 = 2 consecutive perfects) ---
        send_reaction(QUALITY_PERFECT);
        send_reaction(QUALITY_PERFECT);   // should trigger X1 -> X2

        idle_cycles(3); // verify holding state with no valid pulses

        // --- Drive X2 -> X4 (needs CONSEC_PERFECT_TO_4 = 4 consecutive perfects) ---
        send_reaction(QUALITY_PERFECT);
        send_reaction(QUALITY_PERFECT);
        send_reaction(QUALITY_PERFECT);
        send_reaction(QUALITY_PERFECT);   // should trigger X2 -> X4

        idle_cycles(3);

        // --- Confirm X4 holds on PERFECT/NORMAL ---
        send_reaction(QUALITY_PERFECT);
        send_reaction(QUALITY_NORMAL);

        // --- Confirm X4 -> X1 on POOR ---
        send_reaction(QUALITY_POOR);

        idle_cycles(2);

        // --- Confirm a broken perfect streak resets the counter (X1, needs fresh streak) ---
        send_reaction(QUALITY_PERFECT);
        send_reaction(QUALITY_NORMAL);   // resets consecutive count
        send_reaction(QUALITY_PERFECT);
        send_reaction(QUALITY_PERFECT);  // should now trigger X1 -> X2 again

        idle_cycles(5);

        send_reaction(QUALITY_BAD);
        send_reaction(QUALITY_BAD);
        send_reaction(QUALITY_BAD);

        $finish;
    end

    // Simple console trace for quick sanity checking alongside the waveform
    always @(posedge clk) begin
        if (!rst)
            $display("t=%0t | valid=%b quality=%b | state_mult=%0d",
                       $time, reaction_valid, reaction_quality, current_multiplier);
    end

endmodule

