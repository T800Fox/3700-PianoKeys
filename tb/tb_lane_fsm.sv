`timescale 1ns/1ns

module tb_lane_fsm;

    localparam COUNTDOWN_WIDTH    = 4;
    localparam SUBBEATS_PER_BEAT  = 6;
    localparam WINDOW_HALF_TICKS  = 3;
    localparam PERFECT_START_TICK = 5;
    localparam PERFECT_END_TICK   = 7;
    localparam HIT_FLASH_TICKS    = 3;

    localparam logic [1:0] QUALITY_PERFECT = 2'b00;
    localparam logic [1:0] QUALITY_NORMAL  = 2'b01;
    localparam logic [1:0] QUALITY_POOR    = 2'b10;
    localparam logic [1:0] QUALITY_BAD     = 2'b11;

    logic clk = 0;
    logic reset, beat_tick, subbeat_tick, press_pulse, spawn;
    logic [COUNTDOWN_WIDTH-1:0] spawn_countdown;
    logic ready, display_active, quality_valid, spawn_rejected_pulse, hit_led;
    logic [COUNTDOWN_WIDTH-1:0] display_value;
    logic [1:0] hit_quality;

    lane_fsm #(
        .COUNTDOWN_WIDTH(COUNTDOWN_WIDTH),
        .SUBBEATS_PER_BEAT(SUBBEATS_PER_BEAT),
        .WINDOW_HALF_TICKS(WINDOW_HALF_TICKS),
        .PERFECT_START_TICK(PERFECT_START_TICK),
        .PERFECT_END_TICK(PERFECT_END_TICK),
        .HIT_FLASH_TICKS(HIT_FLASH_TICKS)
    ) dut (
        .clk(clk), .reset(reset), .beat_tick(beat_tick),
        .subbeat_tick(subbeat_tick), .press_pulse(press_pulse),
        .spawn(spawn), .spawn_countdown(spawn_countdown), .ready(ready),
        .display_active(display_active), .display_value(display_value),
        .hit_quality(hit_quality), .quality_valid(quality_valid),
        .spawn_rejected_pulse(spawn_rejected_pulse), .hit_led(hit_led)
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
        @(negedge clk) reset = 1'b1;
        repeat (2) @(posedge clk);
        #1;
        @(negedge clk) reset = 1'b0;
    endtask

    task automatic request_spawn(input logic [COUNTDOWN_WIDTH-1:0] value);
        @(negedge clk);
        spawn_countdown = value;
        spawn = 1'b1;
        @(posedge clk); #1;
        @(negedge clk) spawn = 1'b0;
    endtask

    task automatic pulse_beat;
        @(negedge clk) beat_tick = 1'b1;
        @(posedge clk); #1;
        @(negedge clk) beat_tick = 1'b0;
    endtask

    task automatic pulse_subbeat;
        @(negedge clk) subbeat_tick = 1'b1;
        @(posedge clk); #1;
        @(negedge clk) subbeat_tick = 1'b0;
    endtask

    task automatic advance_subbeats(input integer count);
        integer i;
        for (i = 0; i < count; i = i + 1)
            pulse_subbeat();
    endtask

    task automatic press_key;
        @(negedge clk) press_pulse = 1'b1;
        @(posedge clk); #1;
        @(negedge clk) press_pulse = 1'b0;
    endtask

    initial begin : test_cases
        reset = 0;
        beat_tick = 0;
        subbeat_tick = 0;
        press_pulse = 0;
        spawn = 0;
        spawn_countdown = '0;

        apply_reset();
        if (!ready || display_active || display_value !== 0 || quality_valid || hit_led)
            $fatal(1, "FAIL test 1: reset did not clear the lane");
        $display("PASS test 1: reset clears the lane");

        request_spawn(0);
        if (!spawn_rejected_pulse || !ready)
            $fatal(1, "FAIL test 2: zero countdown was not rejected");
        @(posedge clk); #1;
        if (spawn_rejected_pulse)
            $fatal(1, "FAIL test 2: rejection event exceeded one clock");
        press_key();
        if (!quality_valid || hit_quality !== QUALITY_BAD || !ready)
            $fatal(1, "FAIL test 2: inactive press was not bad");
        @(posedge clk); #1;
        if (quality_valid)
            $fatal(1, "FAIL test 2: quality_valid exceeded one clock");
        $display("PASS test 2: invalid spawn and inactive press are handled");

        apply_reset();
        request_spawn(3);
        if (ready || !display_active || display_value !== 3)
            $fatal(1, "FAIL test 3: countdown 3 was not accepted");
        repeat (2) @(posedge clk); #1;
        if (display_value !== 3)
            $fatal(1, "FAIL test 3: countdown changed without beat_tick");
        pulse_beat();
        if (display_value !== 2)
            $fatal(1, "FAIL test 3: first beat did not produce 2");
        pulse_beat();
        if (display_value !== 1)
            $fatal(1, "FAIL test 3: second beat did not begin judgement at 1");
        $display("PASS test 3: countdown enters judgement on a beat");

        apply_reset();
        request_spawn(4);
        press_key();
        if (!quality_valid || hit_quality !== QUALITY_BAD || !ready || hit_led)
            $fatal(1, "FAIL test 4: press earlier than 1 was not bad");
        $display("PASS test 4: press earlier than 1 is bad");

        apply_reset();
        request_spawn(1);
        press_key();
        if (!quality_valid || hit_quality !== QUALITY_POOR || !ready || hit_led)
            $fatal(1, "FAIL test 5: first half of 1 was not poor");
        $display("PASS test 5: first half of 1 is poor");

        apply_reset();
        request_spawn(1);
        advance_subbeats(3);
        if (display_value !== 1)
            $fatal(1, "FAIL test 6: display left 1 before target");
        press_key();
        if (!quality_valid || hit_quality !== QUALITY_NORMAL || !ready || !hit_led)
            $fatal(1, "FAIL test 6: hit-window start was not normal");
        $display("PASS test 6: normal window starts before target");

        apply_reset();
        request_spawn(1);
        advance_subbeats(PERFECT_START_TICK);
        if (display_value !== 1)
            $fatal(1, "FAIL test 7: perfect start should display 1");
        press_key();
        if (!quality_valid || hit_quality !== QUALITY_PERFECT)
            $fatal(1, "FAIL test 7: perfect start was not inclusive");

        apply_reset();
        request_spawn(1);
        advance_subbeats(SUBBEATS_PER_BEAT);
        if (display_value !== 0)
            $fatal(1, "FAIL test 7: target did not change display to 0");
        press_key();
        if (!quality_valid || hit_quality !== QUALITY_PERFECT)
            $fatal(1, "FAIL test 7: first subbeat of 0 was not perfect");

        apply_reset();
        request_spawn(1);
        advance_subbeats(PERFECT_END_TICK);
        press_key();
        if (!quality_valid || hit_quality !== QUALITY_NORMAL)
            $fatal(1, "FAIL test 7: perfect end was not exclusive");
        $display("PASS test 7: perfect range straddles the target");

        apply_reset();
        request_spawn(1);
        advance_subbeats(SUBBEATS_PER_BEAT);
        if (display_value !== 0 || ready)
            $fatal(1, "FAIL test 8: zero window did not begin at target");
        advance_subbeats(WINDOW_HALF_TICKS - 1);
        if (display_value !== 0 || ready)
            $fatal(1, "FAIL test 8: zero disappeared before half a beat");
        pulse_subbeat();
        if (!ready || display_active || !quality_valid || hit_quality !== QUALITY_POOR)
            $fatal(1, "FAIL test 8: expiry did not produce poor/miss");
        $display("PASS test 8: miss resolves after half a beat of zero");

        apply_reset();
        request_spawn(4);
        request_spawn(2);
        if (!spawn_rejected_pulse || display_value !== 4 || ready)
            $fatal(1, "FAIL test 9: busy spawn replaced the active note");
        $display("PASS test 9: busy lane rejects new notes");

        apply_reset();
        request_spawn(1);
        advance_subbeats(3);
        press_key();
        if (!hit_led) $fatal(1, "FAIL test 10: normal hit did not light LED");
        advance_subbeats(HIT_FLASH_TICKS - 1);
        if (!hit_led) $fatal(1, "FAIL test 10: hit LED ended early");
        pulse_subbeat();
        if (hit_led) $fatal(1, "FAIL test 10: hit LED lasted too long");
        $display("PASS test 10: lane drives configured hit flash");

        apply_reset();
        request_spawn(1);
        advance_subbeats(3);
        press_key();
        request_spawn(3);
        apply_reset();
        if (!ready || display_active || display_value !== 0 || hit_led || quality_valid)
            $fatal(1, "FAIL test 11: reset did not clear all lane activity");
        $display("PASS test 11: reset interrupts all lane activity");

        $display("ALL TESTS PASSED: tb_lane_fsm");
        $finish;
    end

endmodule
