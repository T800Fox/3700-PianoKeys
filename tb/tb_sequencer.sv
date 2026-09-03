
`timescale 1ns/1ns

module tb_sequencer;

    logic clk = 0;
    logic beat_clk;

    logic start_button;

    logic reset;
    logic all_lanes_ready;

    logic [1:0] difficulty_ind;
    logic [1:0] song_selection_ind;

    logic [3:0] lane_countdowns [0:3];
    logic lane_resets [0:3];

    logic [3:0] count_val;
    logic beat_clk_reset;

    logic game_active;
    logic count_active;

    logic previous_lane_reset [0:3];
    logic monitor_armed;


    sequencer #(
        .NUM_SONGS(3),
        .SONG_MEM_SIZE(256)
    ) dut (
        .clk(clk),
        .beat_clk(beat_clk),

        .start_button(start_button),

        .reset(reset),
        .all_lanes_ready(all_lanes_ready),

        .difficulty_ind(difficulty_ind),
        .song_selection_ind(song_selection_ind),

        .lane_countdowns(lane_countdowns),
        .lane_resets(lane_resets),

        .count_val(count_val),
        .beat_clk_reset(beat_clk_reset),

        .game_active(game_active),
        .count_active(count_active)
    );


    always #5 clk = ~clk;


    integer monitor_lane;

    always @(posedge clk) begin

        if (reset) begin
            for (monitor_lane = 0; monitor_lane < 4; monitor_lane = monitor_lane + 1)
                previous_lane_reset[monitor_lane] = 0;
        end
        else if (monitor_armed) begin
            for (monitor_lane = 0; monitor_lane < 4; monitor_lane = monitor_lane + 1) begin
                if (lane_resets[monitor_lane] && !game_active)
                    $fatal(1, "FAIL: lane %0d spawned outside IN_GAME", monitor_lane);

                if (lane_resets[monitor_lane] && !beat_clk)
                    $fatal(1, "FAIL: lane %0d spawn was not aligned to beat_clk", monitor_lane);

                if (lane_resets[monitor_lane] && previous_lane_reset[monitor_lane])
                    $fatal(1, "FAIL: lane %0d spawn exceeded one clock", monitor_lane);

                previous_lane_reset[monitor_lane] = lane_resets[monitor_lane];
            end
        end

    end


    task automatic do_reset;

        @(negedge clk);
        reset = 1;

        repeat (2) @(posedge clk);

        @(negedge clk);
        reset = 0;

    endtask


    task automatic start_game;

        @(negedge clk);
        start_button = 1;

        @(posedge clk);
        #1;

        @(negedge clk);
        start_button = 0;

    endtask


    task automatic wait_for_count_in;

        integer cycles;

        cycles = 0;

        while (!count_active && cycles < 5000) begin

            @(posedge clk);
            cycles = cycles + 1;

        end

        if (!count_active)
            $fatal(
                1,
                "FAIL: sequencer never entered COUNT_IN"
            );

    endtask


    task automatic pulse_beat;

        @(negedge clk);
        beat_clk = 1;

        @(posedge clk);
        #1;

        @(negedge clk);
        beat_clk = 0;

        @(posedge clk);
        #1;

    endtask


    initial begin

        beat_clk = 0;
        start_button = 0;

        reset = 0;
        all_lanes_ready = 1;
        monitor_armed = 0;

        previous_lane_reset[0] = 0;
        previous_lane_reset[1] = 0;
        previous_lane_reset[2] = 0;
        previous_lane_reset[3] = 0;

        difficulty_ind = 3;
        song_selection_ind = 0;


        do_reset();

        monitor_armed = 1;

        #1;

        if (dut.clamped_diff !== 2)
            $fatal(
                1,
                "FAIL: difficulty 3 was not clamped to hard"
            );


        start_game();

        wait_for_count_in();

        // gy.txt header is 0x203 -> count-in = 3.
        if (count_val !== 3)
            $fatal(
                1,
                "FAIL: gy metadata was not loaded"
            );

        // No lane may start while the count-in display is active.
        repeat (2)
            pulse_beat();


        do_reset();

        song_selection_ind = 2;

        start_game();

        wait_for_count_in();

        // twinkle.txt header is 0x184 -> count-in = 4.
        if (count_val !== 4)
            $fatal(
                1,
                "FAIL: twinkle metadata was not loaded"
            );


        repeat (5)
            pulse_beat();

        repeat (2) @(posedge clk);
        #1;

        if (!game_active)
            $fatal(
                1,
                "FAIL: sequencer never entered IN_GAME"
            );


        do_reset();

        #1;

        if (
            game_active ||
            count_active ||
            count_val !== 0
        )
            $fatal(
                1,
                "FAIL: sequencer reset did not restore waiting state"
            );


        $display(
            "ALL TESTS PASSED: tb_sequencer"
        );

        $finish;
    end


    initial begin
        #1000000;
        $fatal(1, "FAIL: tb_sequencer timeout");
    end

endmodule
