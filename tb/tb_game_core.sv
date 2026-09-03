`timescale 1ns/1ns

module tb_game_core;

    localparam CLKS_PER_MS       = 2;
    localparam MS_PER_SUBBEAT    = 3;
    localparam SUBBEATS_PER_BEAT = 6;

    logic clk = 0;
    logic reset;

    logic [3:0] press_pulse;
    logic [3:0] spawn;
    logic [15:0] spawn_countdown;

    logic [3:0] display_active;
    logic [15:0] display_value;

    logic [7:0] hit_quality;
    logic [3:0] quality_valid;

    logic [3:0] hit_led;

    logic beat_tick;
    logic subbeat_tick;


    game_core #(
        .CLKS_PER_MS(CLKS_PER_MS),
        .MS_PER_SUBBEAT(MS_PER_SUBBEAT),
        .SUBBEATS_PER_BEAT(SUBBEATS_PER_BEAT)
    ) dut (
        .clk(clk),
        .reset(reset),

        .press_pulse(press_pulse),
        .spawn(spawn),
        .spawn_countdown(spawn_countdown),

        .display_active(display_active),
        .display_value(display_value),

        .hit_quality(hit_quality),
        .quality_valid(quality_valid),

        .hit_led(hit_led),

        .beat_tick(beat_tick),
        .subbeat_tick(subbeat_tick)
    );


    always #10 clk = ~clk;


    initial begin

        reset = 1;
        press_pulse = 4'b0000;
        spawn = 4'b0000;
        spawn_countdown = 16'h0000;

        repeat (2) @(posedge clk);

        @(negedge clk);
        reset = 0;


        // Spawn a note ONLY in lane 0.
        // Lane 0 countdown is bits [3:0].
        @(negedge clk);
        spawn_countdown = 16'h0003;
        spawn = 4'b0001;

        @(negedge clk);
        spawn = 4'b0000;


        if (!display_active[0])
            $fatal(1, "FAIL: lane 0 did not activate");

        if (display_value[3:0] != 4'd3)
            $fatal(1, "FAIL: lane 0 did not start at 3");

        $display("PASS: lane 0 spawned at countdown 3");


        // Wait for your beat generator + Mitch's FSM
        // to move the note all the way to 0.
        wait(display_active[0] && display_value[3:0] == 0);

        $display("PASS: lane 0 reached hit point");


        // Press lane 0 while it is at the target.
        @(negedge clk);
        press_pulse = 4'b0001;

        @(posedge clk);
        #1;

        if (!quality_valid[0])
            $fatal(1, "FAIL: lane 0 did not judge press");

        if (hit_quality[1:0] != 2'b00)
            $fatal(1, "FAIL: lane 0 was not PERFECT");

        $display("PASS: lane 0 perfect hit");


        @(negedge clk);
        press_pulse = 4'b0000;


        $display("ALL TESTS PASSED: tb_game_core");

        $finish;
    end


    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_game_core);
    end

endmodule