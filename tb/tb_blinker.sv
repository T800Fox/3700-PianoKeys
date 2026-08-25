`timescale 1ns/1ns

// tb_blinker.sv, example self-checking testbench for rtl/blinker.v.
//
// Every test checks something and calls $fatal() if it is incorrect. A testbench
// that only prints waveforms cannot fail, so it is not evidence of anything.
//
// docs/WRITING_TESTBENCHES.md walks through building this file step by step.
// Runs unmodified in both ModelSim and Verilator: docs/SIMULATOR_GOTCHAS.md
// explains the habits that make that possible (reset before checking, sample
// #1 after the clock edge, compare with === / !==).

// Three tests, in order:
//   1. reset holds the output low
//   2. out toggles every CLKS_PER_TOGGLE clocks
//   3. reset mid-count clears the output and restarts the count cleanly
module tb_blinker;

    // Override the 12.5-million-cycle period down to 4 cycles, so the test
    // runs in moments but checks the same RTL that goes on the board:
    localparam CLKS_PER_TOGGLE = 4;

    logic clk, reset;
    initial clk = 0;

    // Driven by the DUT; we only ever read it:
    logic out;

    blinker #(.CLKS_PER_TOGGLE(CLKS_PER_TOGGLE)) dut (
        .clk   (clk),
        .reset (reset),
        .out   (out)
    );

    always #10 clk = ~clk;      // 20 ns period, like the DE1-SoC's 50 MHz

    // Waveform dump only when asked: scripts/simulate.py passes +dump.
    initial begin : waveform_dump
        if ($test$plusargs("dump")) begin
`ifdef VERILATOR
            $dumpfile("waveform.fst");  // ModelSim can only write .vcd
`else
            $dumpfile("waveform.vcd");
`endif
            $dumpvars(0, tb_blinker);
        end
    end

    int n, k;

    // Counts clock edges until `out` changes.
    task automatic clocks_to_next_toggle(output int count);
        logic prev;
        prev  = out;
        count = 0;
        // === also matches X and Z, which matters in ModelSim:
        while (out === prev) begin
            @(posedge clk);
            // The #1 lets the DUT's non-blocking (<=) assignments settle
            // before we read the output:
            #1;
            count++;
            // Give up rather than loop forever if the DUT is stuck:
            if (count > 100) $fatal(1, "FAIL: out never toggled");
        end
    endtask

    initial begin : test_cases
        // --- Test 1: reset holds the output low -------------------------------
        // Always drive reset before checking anything:
        reset = 1;
        repeat (2) @(posedge clk);
        #1;
        if (out !== 1'b0) $fatal(1, "FAIL test 1: out=%b during reset, expected 0", out);
        $display("PASS test 1: reset holds out low");

        // Release reset on the negedge, away from the posedge the DUT samples on:
        @(negedge clk) reset = 0;


        // --- Test 2: out toggles every CLKS_PER_TOGGLE clocks -----------------
        // Measure three toggles in a row. One could be a coincidence; three in
        // a row means the divider is really counting:
        for (k = 0; k < 3; k++) begin
            clocks_to_next_toggle(n);
            if (n !== CLKS_PER_TOGGLE)
                $fatal(1, "FAIL test 2: toggle %0d took %0d clocks, expected %0d",
                       k, n, CLKS_PER_TOGGLE);
        end
        if (out !== 1'b1) $fatal(1, "FAIL test 2: expected out high after 3 toggles");
        $display("PASS test 2: out toggles every %0d clocks", CLKS_PER_TOGGLE);


        // --- Test 3: reset mid-count clears the output and restarts -----------
        @(negedge clk) reset = 1;
        @(posedge clk);
        #1;
        if (out !== 1'b0) $fatal(1, "FAIL test 3: reset did not clear out");
        @(negedge clk) reset = 0;
        clocks_to_next_toggle(n);
        if (n !== CLKS_PER_TOGGLE)
            $fatal(1, "FAIL test 3: first toggle after reset took %0d clocks, expected %0d",
                   n, CLKS_PER_TOGGLE);
        $display("PASS test 3: reset restarts the count cleanly");


        // The runner scripts search for the exact string "ALL TESTS PASSED".
        // Reaching this line means no $fatal fired, so every check above passed.
        $display("ALL TESTS PASSED: tb_blinker");
        $finish;
    end

endmodule
