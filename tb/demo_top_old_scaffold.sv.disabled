`timescale 1ns/1ns

// tb_demo_top.sv, example system-level integration testbench for rtl/demo_top.sv.
//
// It drives only the real board pins (CLOCK_50, KEY, SW) and checks only the
// real board outputs (LEDR, HEX).
//
// docs/WRITING_TESTBENCHES.md walks through the design of these testbenches,
// including the "arm after reset" trick that keeps the continuous monitor
// below working in both simulators (docs/SIMULATOR_GOTCHAS.md has the why).

// Five tests, in order, plus one continuous monitor running throughout:
//   1. reset (SW0) clears the heartbeat
//   2. heartbeat runs at the parameterised rate
//   3. LEDR4..1 follow KEY3..KEY0 (active low)
//   4. HEX0 shows SW7..SW1, inverted (segments are active low)
//   5. LEDR6..5 follow SW9..SW8, LEDR9..7 stay off
//   * monitor: HEX5..HEX1 must never light up, once armed after test 1
module tb_demo_top;

    // Override the 12.5-million-cycle period down to 4 cycles, so the test
    // runs in moments but checks the same RTL that goes on the board:
    localparam CLKS_PER_TOGGLE = 4;

    // Inputs to the DUT, driven in the initial block below:
    logic       CLOCK_50;
    logic [3:0] KEY;
    logic [9:0] SW;
    // Outputs of the DUT; we only ever read them:
    logic [9:0] LEDR;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;

    demo_top #(.CLKS_PER_TOGGLE(CLKS_PER_TOGGLE)) dut (
        .CLOCK_50 (CLOCK_50),
        .KEY      (KEY),
        .SW       (SW),
        .LEDR     (LEDR),
        .HEX0     (HEX0),
        .HEX1     (HEX1),
        .HEX2     (HEX2),
        .HEX3     (HEX3),
        .HEX4     (HEX4),
        .HEX5     (HEX5)
    );

    initial CLOCK_50 = 0;
    always #10 CLOCK_50 = ~CLOCK_50;    // 20 ns period = 50 MHz

    // Waveform dump only when asked: scripts/simulate.py passes +dump.
    initial begin : waveform_dump
        if ($test$plusargs("dump")) begin
`ifdef VERILATOR
            $dumpfile("waveform.fst");  // ModelSim can only write .vcd
`else
            $dumpfile("waveform.vcd");
`endif
            $dumpvars(0, tb_demo_top);
        end
    end

    // A continuous monitor: unlike the tests below, which check one thing at
    // one moment, this runs on every clock edge for the whole simulation.
    // It only starts checking once `armed` is set, after the first reset --
    // before that the DUT's registers are X in ModelSim (0 in Verilator) and
    // the check would fail in one simulator but not the other.
    logic armed = 0;
    always @(posedge CLOCK_50) begin : monitor_unused_hex
        if (armed && (HEX1 !== 7'b1111111 || HEX2 !== 7'b1111111 ||
                      HEX3 !== 7'b1111111 || HEX4 !== 7'b1111111 ||
                      HEX5 !== 7'b1111111))
            $fatal(1, "FAIL monitor: an unused display lit up");
    end

    int n, k;

    // Counts clock edges until LEDR[0] changes.
    task automatic clocks_to_heartbeat_toggle(output int count);
        logic prev;
        prev  = LEDR[0];
        count = 0;
        // === also matches X and Z, which matters in ModelSim:
        while (LEDR[0] === prev) begin
            @(posedge CLOCK_50);
            // The #1 lets the DUT's non-blocking (<=) assignments settle
            // before we read the output:
            #1;
            count++;
            // Give up rather than loop forever if the heartbeat is stuck:
            if (count > 100) $fatal(1, "FAIL: heartbeat never toggled");
        end
    endtask

    initial begin : test_cases

        // Default every input. KEY is active low, so all ones = not pressed:
        KEY = 4'b1111;
        SW  = 10'b0;


        // --- Test 1: reset (SW0) clears the heartbeat -------------------------
        // Always drive reset before checking anything:
        SW[0] = 1;
        repeat (3) @(posedge CLOCK_50);
        #1;
        if (LEDR[0] !== 1'b0) $fatal(1, "FAIL test 1: LEDR0=%b in reset, expected 0", LEDR[0]);
        $display("PASS test 1: reset clears the heartbeat");

        // The design is now in a known state, so the monitor can start:
        armed = 1;

        // Release reset on the negedge, away from the posedge the DUT samples on:
        @(negedge CLOCK_50) SW[0] = 0;


        // --- Test 2: heartbeat runs at the parameterised rate -----------------
        // Measure three toggles in a row. One could be a coincidence; three in
        // a row means the divider is really counting:
        for (k = 0; k < 3; k++) begin
            clocks_to_heartbeat_toggle(n);
            if (n !== CLKS_PER_TOGGLE)
                $fatal(1, "FAIL test 2: heartbeat half-period %0d clocks, expected %0d",
                       n, CLKS_PER_TOGGLE);
        end
        $display("PASS test 2: heartbeat toggles every %0d clocks", CLKS_PER_TOGGLE);


        // --- Test 3: LEDR4..1 follow KEY3..KEY0 (active low) ------------------
        // Press one key at a time and check that only its LED comes on.
        // `4'b1 << k` is a 1 in position k; ~ inverts it because a pressed
        // key reads as 0:
        for (k = 0; k < 4; k++) begin
            @(negedge CLOCK_50) KEY = ~(4'b1 << k);
            #1;     // combinational logic settles, then we check
            if (LEDR[4:1] !== (4'b1 << k))
                $fatal(1, "FAIL test 3: KEY=%b gave LEDR[4:1]=%b, expected %b",
                       KEY, LEDR[4:1], (4'b1 << k));
        end
        // Release every key and check the LEDs all go out:
        @(negedge CLOCK_50) KEY = 4'b1111;
        #1;
        if (LEDR[4:1] !== 4'b0000)
            $fatal(1, "FAIL test 3: no key pressed but LEDR[4:1]=%b", LEDR[4:1]);
        $display("PASS test 3: LEDR4..1 mirror the keys");


        // --- Test 4: HEX0 shows SW7..SW1, inverted (segments are active low) --
        // Light one segment at a time. HEX0 should always be the inverse of
        // the switches, because a 0 turns a segment ON:
        for (k = 0; k < 7; k++) begin
            @(negedge CLOCK_50) SW[7:1] = 7'b1 << k;
            #1;
            if (HEX0 !== ~SW[7:1])
                $fatal(1, "FAIL test 4: SW[7:1]=%b gave HEX0=%b, expected %b",
                       SW[7:1], HEX0, ~SW[7:1]);
        end
        // With every switch down the whole display should be dark:
        @(negedge CLOCK_50) SW[7:1] = 7'b0;
        #1;
        if (HEX0 !== 7'b1111111)
            $fatal(1, "FAIL test 4: HEX0=%b with all switches down, expected all off", HEX0);
        $display("PASS test 4: HEX0 follows the switches");


        // --- Test 5: LEDR6..5 follow SW9..SW8, LEDR9..7 stay off --------------
        // Two different patterns for coverage:
        @(negedge CLOCK_50) SW[9:8] = 2'b10;
        #1;
        if (LEDR[6:5] !== 2'b10)
            $fatal(1, "FAIL test 5: SW[9:8]=10 gave LEDR[6:5]=%b", LEDR[6:5]);
        @(negedge CLOCK_50) SW[9:8] = 2'b01;
        #1;
        if (LEDR[6:5] !== 2'b01)
            $fatal(1, "FAIL test 5: SW[9:8]=01 gave LEDR[6:5]=%b", LEDR[6:5]);
        // The unused LEDs must stay off rather than being left floating:
        if (LEDR[9:7] !== 3'b000)
            $fatal(1, "FAIL test 5: unused LEDR[9:7]=%b, expected 000", LEDR[9:7]);
        $display("PASS test 5: switch LEDs follow SW9..SW8, unused LEDs held off");

        // The runner scripts search for the exact string "ALL TESTS PASSED".
        // Reaching this line means no $fatal fired, so every check above passed.
        $display("ALL TESTS PASSED: tb_demo_top");
        $finish;
    end

endmodule