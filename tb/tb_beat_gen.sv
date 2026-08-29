`timescale 1ns/1ns

module tb_beat_gen;

    localparam CLKS_PER_MS       = 2;
    localparam MS_PER_SUBBEAT    = 3;
    localparam SUBBEATS_PER_BEAT = 4;

    logic clk = 0;
    logic reset;

    logic beat_tick;
    logic subbeat_tick;

    integer subbeats_seen;
    integer beats_seen;


    // Device Under Test
    beat_gen #(
        .CLKS_PER_MS(CLKS_PER_MS),
        .MS_PER_SUBBEAT(MS_PER_SUBBEAT),
        .SUBBEATS_PER_BEAT(SUBBEATS_PER_BEAT)
    ) dut (
        .clk(clk),
        .reset(reset),
        .beat_tick(beat_tick),
        .subbeat_tick(subbeat_tick)
    );


    // 20 ns clock period
    always #10 clk = ~clk;


    // Count the pulses produced by beat_gen
    always @(posedge clk) begin
        #1;

        if (reset) begin
            subbeats_seen = 0;
            beats_seen    = 0;
        end
        else begin

            if (subbeat_tick)
                subbeats_seen = subbeats_seen + 1;

            if (beat_tick)
                beats_seen = beats_seen + 1;

            // A beat must also be a subbeat boundary
            if (beat_tick && !subbeat_tick)
                $fatal(1, "FAIL: beat_tick occurred without subbeat_tick");

        end
    end


    initial begin

        reset = 1'b1;

        // Hold reset for two clocks
        repeat (2) @(posedge clk);

        @(negedge clk);
        reset = 1'b0;


        // Wait until 4 subbeats have occurred
        wait(subbeats_seen == 4);

        if (beats_seen != 1)
            $fatal(1,
                "FAIL: expected 1 beat after 4 subbeats, got %0d",
                beats_seen
            );

        $display("PASS: 4 subbeats produced 1 beat");


        // Wait for another 4 subbeats
        wait(subbeats_seen == 8);

        if (beats_seen != 2)
            $fatal(1,
                "FAIL: expected 2 beats after 8 subbeats, got %0d",
                beats_seen
            );

        $display("PASS: 8 subbeats produced 2 beats");


        // Test reset
        @(negedge clk);
        reset = 1'b1;

        repeat (2) @(posedge clk);
        #1;

        if (beat_tick || subbeat_tick)
            $fatal(1, "FAIL: outputs not cleared by reset");

        $display("PASS: reset clears tick outputs");

        $display("ALL TESTS PASSED: tb_beat_gen");

        $finish;

    end


    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_beat_gen);
    end

endmodule