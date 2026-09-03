
`timescale 1ns/1ns

module tb_demo_top;

    logic CLOCK_50 = 0;

    logic [3:0] KEY;
    logic [9:0] SW;

    logic [9:0] LEDR;

    logic [6:0] HEX0;
    logic [6:0] HEX1;
    logic [6:0] HEX2;
    logic [6:0] HEX3;
    logic [6:0] HEX4;
    logic [6:0] HEX5;


    demo_top #(
        .MS_PER_SUBBEAT(2),
        .JASPERS_MS_PER_SUBBEAT(2),
        .TWINKLE_MS_PER_SUBBEAT(2),

        .SUBBEATS_PER_BEAT(6),
        .CLKS_PER_MS(1),

        .WINDOW_HALF_TICKS(3),

        .PERFECT_START_TICK(5),
        .PERFECT_END_TICK(7),

        .HIT_FLASH_MS(2),

        .DEBOUNCE_COUNTS(1),
        .SWITCH_RELEASE_COUNTS(1)
    ) dut (
        .CLOCK_50(CLOCK_50),

        .KEY(KEY),
        .SW(SW),

        .LEDR(LEDR),

        .HEX0(HEX0),
        .HEX1(HEX1),
        .HEX2(HEX2),
        .HEX3(HEX3),
        .HEX4(HEX4),
        .HEX5(HEX5)
    );


    always #5 CLOCK_50 = ~CLOCK_50;


    task automatic press_button(
        input integer idx
    );

        @(negedge CLOCK_50);
        KEY[idx] = 0;

        repeat (5)
            @(posedge CLOCK_50);

        @(negedge CLOCK_50);
        KEY[idx] = 1;

        repeat (4)
            @(posedge CLOCK_50);

    endtask


    integer cycles;
    integer lane_idx;
    integer old_score;


    initial begin

        KEY = 4'b1111;
        SW = 10'b0;


        // ----------------------------------------------------
        // Reset
        // ----------------------------------------------------

        SW[0] = 1;

        repeat (4)
            @(posedge CLOCK_50);

        SW[0] = 0;

        repeat (5)
            @(posedge CLOCK_50);

        #1;

        if (dut.game_score !== 0)
            $fatal(
                1,
                "FAIL: score not zero after reset"
            );

        repeat (10) begin
            @(posedge CLOCK_50);
            #1;

            if (
                HEX0 !== 7'b1111111 ||
                HEX1 !== 7'b1111111 ||
                HEX2 !== 7'b1111111 ||
                HEX3 !== 7'b1111111
            )
                $fatal(
                    1,
                    "FAIL: lane displays did not remain blank after reset release"
                );
        end


        // ----------------------------------------------------
        // Difficulty indication
        // ----------------------------------------------------

        SW[9:8] = 2'b00;
        #1;

        if (LEDR[2:0] !== 3'b001)
            $fatal(
                1,
                "FAIL: Easy LED indication"
            );


        SW[9:8] = 2'b01;
        #1;

        if (LEDR[2:0] !== 3'b010)
            $fatal(
                1,
                "FAIL: Medium LED indication"
            );


        SW[9:8] = 2'b10;
        #1;

        if (LEDR[2:0] !== 3'b100)
            $fatal(
                1,
                "FAIL: Hard LED indication"
            );


        // Demo song = gy, Easy.
        SW[9:8] = 2'b00;
        SW[7:6] = 2'b00;


        // ----------------------------------------------------
        // Start game with KEY0
        // ----------------------------------------------------

        press_button(0);


        cycles = 0;

        while (
            !dut.count_active &&
            cycles < 10000
        ) begin

            @(posedge CLOCK_50);
            cycles = cycles + 1;

        end

        if (!dut.count_active)
            $fatal(
                1,
                "FAIL: game did not enter COUNT_IN"
            );


        cycles = 0;

        while (
            !dut.game_active &&
            cycles < 10000
        ) begin

            @(posedge CLOCK_50);
            cycles = cycles + 1;

        end

        if (!dut.game_active)
            $fatal(
                1,
                "FAIL: game did not enter IN_GAME"
            );


        // ----------------------------------------------------
        // Find a lane displaying 0 and hit it.
        // ----------------------------------------------------

        lane_idx = -1;
        cycles = 0;

        while (
            lane_idx < 0 &&
            cycles < 20000
        ) begin

            @(posedge CLOCK_50);
            #1;

            if (dut.lane_0_display == 0)
                lane_idx = 0;
            else if (dut.lane_1_display == 0)
                lane_idx = 1;
            else if (dut.lane_2_display == 0)
                lane_idx = 2;
            else if (dut.lane_3_display == 0)
                lane_idx = 3;

            cycles = cycles + 1;

        end

        if (lane_idx < 0)
            $fatal(
                1,
                "FAIL: no note reached zero"
            );


        press_button(lane_idx);

        repeat (3)
            @(posedge CLOCK_50);

        #1;

        if (dut.game_score == 0)
            $fatal(
                1,
                "FAIL: correct zero-window hit did not score"
            );


        // ----------------------------------------------------
        // Find an early note >=2.
        // Pressing must never increase score.
        // In our design it is forfeited / BAD.
        // ----------------------------------------------------

        old_score = dut.game_score;

        lane_idx = -1;
        cycles = 0;

        while (
            lane_idx < 0 &&
            cycles < 20000
        ) begin

            @(posedge CLOCK_50);
            #1;

            if (
                dut.lane_0_display >= 2 &&
                dut.lane_0_display <= 9
            )
                lane_idx = 0;

            else if (
                dut.lane_1_display >= 2 &&
                dut.lane_1_display <= 9
            )
                lane_idx = 1;

            else if (
                dut.lane_2_display >= 2 &&
                dut.lane_2_display <= 9
            )
                lane_idx = 2;

            else if (
                dut.lane_3_display >= 2 &&
                dut.lane_3_display <= 9
            )
                lane_idx = 3;

            cycles = cycles + 1;

        end

        if (lane_idx < 0)
            $fatal(
                1,
                "FAIL: could not find early note"
            );


        press_button(lane_idx);

        repeat (3)
            @(posedge CLOCK_50);

        #1;

        if (dut.game_score > old_score)
            $fatal(
                1,
                "FAIL: early press increased score"
            );


        // ----------------------------------------------------
        // Complete reset clears score and lanes.
        // ----------------------------------------------------

        SW[0] = 1;

        repeat (4)
            @(posedge CLOCK_50);

        #1;

        if (dut.game_score !== 0)
            $fatal(
                1,
                "FAIL: reset did not clear score"
            );

        if (
            dut.lane_0_display !== 10 ||
            dut.lane_1_display !== 10 ||
            dut.lane_2_display !== 10 ||
            dut.lane_3_display !== 10
        )
            $fatal(
                1,
                "FAIL: reset did not blank lanes"
            );


        $display(
            "ALL TESTS PASSED: tb_demo_top"
        );

        $finish;
    end


    initial begin

        #2000000;

        $fatal(
            1,
            "FAIL: tb_demo_top timeout"
        );

    end

endmodule
