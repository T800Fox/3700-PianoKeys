`timescale 1ns/1ns

module tb_lane_fsm;

    localparam COUNTDOWN_WIDTH    = 4;
    localparam HIT_WINDOW_TICKS   = 5;
    localparam PERFECT_START_TICK = 2;
    localparam PERFECT_END_TICK   = 4;
    localparam HIT_FLASH_TICKS    = 3;

    logic clk = 0;
    logic reset;
    logic beat_tick;
    logic subbeat_tick;
    logic press_pulse;
    logic spawn;
    logic [COUNTDOWN_WIDTH-1:0] spawn_countdown;

    logic display_active;
    logic [COUNTDOWN_WIDTH-1:0] display_value;
    logic normal_hit_pulse;
    logic perfect_hit_pulse;
    logic miss_pulse;
    logic bad_press_pulse;
    logic spawn_rejected_pulse;
    logic hit_led;

    lane_fsm #(
        .COUNTDOWN_WIDTH(COUNTDOWN_WIDTH),
        .HIT_WINDOW_TICKS(HIT_WINDOW_TICKS),
        .PERFECT_START_TICK(PERFECT_START_TICK),
        .PERFECT_END_TICK(PERFECT_END_TICK),
        .HIT_FLASH_TICKS(HIT_FLASH_TICKS)
    ) dut (
        .clk(clk),
        .reset(reset),
        .beat_tick(beat_tick),
        .subbeat_tick(subbeat_tick),
        .press_pulse(press_pulse),
        .spawn(spawn),
        .spawn_countdown(spawn_countdown),
        .display_active(display_active),
        .display_value(display_value),
        .normal_hit_pulse(normal_hit_pulse),
        .perfect_hit_pulse(perfect_hit_pulse),
        .miss_pulse(miss_pulse),
        .bad_press_pulse(bad_press_pulse),
        .spawn_rejected_pulse(spawn_rejected_pulse),
        .hit_led(hit_led)
    );

    always #10 clk = ~clk;

    initial begin : waveform_dump
        if ($test$plusargs("dump")) begin
`ifdef VERILATOR
            $dumpfile("waveform.fst");
`else
            $dumpfile("waveform.vcd");
`endif
            $dumpvars(0, tb_lane_fsm);
        end
    end

    task automatic apply_reset;
        @(negedge clk);
        reset = 1'b1;
        repeat (2) @(posedge clk);
        #1;
        @(negedge clk);
        reset = 1'b0;
    endtask

    task automatic request_spawn(input logic [COUNTDOWN_WIDTH-1:0] value);
        @(negedge clk);
        spawn_countdown = value;
        spawn = 1'b1;
        @(posedge clk);
        #1;
        @(negedge clk);
        spawn = 1'b0;
    endtask

    task automatic pulse_beat;
        @(negedge clk);
        beat_tick = 1'b1;
        @(posedge clk);
        #1;
        @(negedge clk);
        beat_tick = 1'b0;
    endtask

    task automatic pulse_subbeat;
        @(negedge clk);
        subbeat_tick = 1'b1;
        @(posedge clk);
        #1;
        @(negedge clk);
        subbeat_tick = 1'b0;
    endtask

    task automatic press_key;
        @(negedge clk);
        press_pulse = 1'b1;
        @(posedge clk);
        #1;
        @(negedge clk);
        press_pulse = 1'b0;
    endtask

    task automatic enter_hit_window(input logic [COUNTDOWN_WIDTH-1:0] value);
        request_spawn(value);
        while (display_value != 0) begin
            pulse_beat();
        end
    endtask

    initial begin : test_cases
        reset           = 1'b0;
        beat_tick       = 1'b0;
        subbeat_tick    = 1'b0;
        press_pulse     = 1'b0;
        spawn           = 1'b0;
        spawn_countdown = '0;

        // Test 1: reset establishes an inactive, blank lane.
        apply_reset();
        if (display_active || display_value !== 0 || hit_led)
            $fatal(1, "FAIL test 1: reset did not clear the lane");
        $display("PASS test 1: reset clears the lane");

        // Test 2: invalid notes and inactive presses are rejected.
        request_spawn(0);
        if (!spawn_rejected_pulse || display_active)
            $fatal(1, "FAIL test 2: zero countdown was not rejected");
        @(posedge clk); #1;
        if (spawn_rejected_pulse)
            $fatal(1, "FAIL test 2: rejection event lasted more than one clock");
        press_key();
        if (!bad_press_pulse || display_active)
            $fatal(1, "FAIL test 2: inactive press was not penalised");
        $display("PASS test 2: invalid spawns and inactive presses are penalised");

        // Test 3: countdown changes only on beat ticks and reaches zero.
        apply_reset();
        request_spawn(3);
        if (!display_active || display_value !== 3)
            $fatal(1, "FAIL test 3: valid spawn was not accepted");
        repeat (2) @(posedge clk); #1;
        if (display_value !== 3)
            $fatal(1, "FAIL test 3: countdown changed without a beat tick");
        pulse_beat();
        if (display_value !== 2)
            $fatal(1, "FAIL test 3: first beat gave %0d, expected 2", display_value);
        pulse_beat();
        if (display_value !== 1)
            $fatal(1, "FAIL test 3: second beat gave %0d, expected 1", display_value);
        pulse_beat();
        if (!display_active || display_value !== 0)
            $fatal(1, "FAIL test 3: lane did not enter the zero window");
        $display("PASS test 3: countdown advances on beat ticks");

        // Test 4: a hit at age zero is normal and starts the LED flash.
        press_key();
        if (!normal_hit_pulse || perfect_hit_pulse || display_active || !hit_led)
            $fatal(1, "FAIL test 4: age-zero press was not a normal hit");
        @(posedge clk); #1;
        if (normal_hit_pulse)
            $fatal(1, "FAIL test 4: normal-hit event lasted more than one clock");
        pulse_subbeat();
        if (!hit_led) $fatal(1, "FAIL test 4: LED flash ended one tick early");
        pulse_subbeat();
        if (!hit_led) $fatal(1, "FAIL test 4: LED flash ended two ticks early");
        pulse_subbeat();
        if (hit_led) $fatal(1, "FAIL test 4: LED flash exceeded configured duration");
        $display("PASS test 4: normal hit and LED duration are correct");

        // Test 5: perfect timing uses [start, end) boundaries.
        apply_reset();
        enter_hit_window(1);
        pulse_subbeat();
        pulse_subbeat();
        press_key();
        if (!perfect_hit_pulse || normal_hit_pulse)
            $fatal(1, "FAIL test 5: perfect-window start was not inclusive");

        apply_reset();
        enter_hit_window(1);
        repeat (4) pulse_subbeat();
        press_key();
        if (!normal_hit_pulse || perfect_hit_pulse)
            $fatal(1, "FAIL test 5: perfect-window end was not exclusive");
        $display("PASS test 5: perfect-window boundaries are correct");

        // Test 6: an early press forfeits the active note.
        apply_reset();
        request_spawn(4);
        press_key();
        if (!bad_press_pulse || display_active)
            $fatal(1, "FAIL test 6: early press did not forfeit the note");
        if (normal_hit_pulse || perfect_hit_pulse)
            $fatal(1, "FAIL test 6: early press incorrectly scored");
        $display("PASS test 6: early press forfeits the note");

        // Test 7: occupied lanes reject new notes without replacing them.
        apply_reset();
        request_spawn(4);
        request_spawn(2);
        if (!spawn_rejected_pulse || display_value !== 4)
            $fatal(1, "FAIL test 7: busy-lane spawn changed the current note");
        $display("PASS test 7: busy lane rejects new notes");

        // Test 8: an unplayed zero window expires with one miss event.
        apply_reset();
        enter_hit_window(1);
        repeat (HIT_WINDOW_TICKS) pulse_subbeat();
        if (!miss_pulse || display_active)
            $fatal(1, "FAIL test 8: hit window did not expire as a miss");
        @(posedge clk); #1;
        if (miss_pulse)
            $fatal(1, "FAIL test 8: miss event lasted more than one clock");
        $display("PASS test 8: late note produces one miss event");

        // Test 9: reset interrupts both an active note and LED flash.
        apply_reset();
        enter_hit_window(1);
        press_key();
        if (!hit_led) $fatal(1, "FAIL test 9: setup hit did not light LED");
        apply_reset();
        if (display_active || hit_led || display_value !== 0)
            $fatal(1, "FAIL test 9: reset did not interrupt lane activity");
        $display("PASS test 9: reset interrupts all lane activity");

        $display("ALL TESTS PASSED: tb_lane_fsm");
        $finish;
    end

endmodule
