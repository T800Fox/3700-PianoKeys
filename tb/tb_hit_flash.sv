`timescale 1ns/1ns

module tb_hit_flash;

    localparam FLASH_TICKS = 3;

    logic clk = 0;
    logic reset;
    logic subbeat_tick;
    logic trigger;
    logic led;

    hit_flash #(
        .FLASH_TICKS(FLASH_TICKS)
    ) dut (
        .clk(clk),
        .reset(reset),
        .subbeat_tick(subbeat_tick),
        .trigger(trigger),
        .led(led)
    );

    always #10 clk = ~clk;

    initial begin : waveform_dump
        if ($test$plusargs("dump")) begin
`ifdef VERILATOR
            $dumpfile("waveform.fst");
`else
            $dumpfile("waveform.vcd");
`endif
            $dumpvars(0, tb_hit_flash);
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

    task automatic pulse_trigger;
        @(negedge clk);
        trigger = 1'b1;
        @(posedge clk);
        #1;
        @(negedge clk);
        trigger = 1'b0;
    endtask

    task automatic pulse_subbeat;
        @(negedge clk);
        subbeat_tick = 1'b1;
        @(posedge clk);
        #1;
        @(negedge clk);
        subbeat_tick = 1'b0;
    endtask

    initial begin : test_cases
        reset        = 1'b0;
        subbeat_tick = 1'b0;
        trigger      = 1'b0;

        // Test 1: reset clears the output.
        apply_reset();
        if (led !== 1'b0)
            $fatal(1, "FAIL test 1: reset did not clear LED");
        $display("PASS test 1: reset clears LED");

        // Test 2: trigger starts a flash that ignores ordinary clock cycles.
        pulse_trigger();
        if (led !== 1'b1)
            $fatal(1, "FAIL test 2: trigger did not light LED");
        repeat (3) @(posedge clk);
        #1;
        if (led !== 1'b1)
            $fatal(1, "FAIL test 2: LED changed without a subbeat tick");
        $display("PASS test 2: flash advances only on subbeat ticks");

        // Test 3: LED remains on for exactly FLASH_TICKS subbeat ticks.
        pulse_subbeat();
        if (!led) $fatal(1, "FAIL test 3: LED ended after one tick");
        pulse_subbeat();
        if (!led) $fatal(1, "FAIL test 3: LED ended after two ticks");
        pulse_subbeat();
        if (led) $fatal(1, "FAIL test 3: LED exceeded configured duration");
        $display("PASS test 3: configured flash duration is exact");

        // Test 4: a new trigger restarts an active flash from full duration.
        pulse_trigger();
        pulse_subbeat();
        pulse_subbeat();
        if (!led) $fatal(1, "FAIL test 4: setup flash ended too early");
        pulse_trigger();
        repeat (2) pulse_subbeat();
        if (!led) $fatal(1, "FAIL test 4: retrigger did not restart duration");
        pulse_subbeat();
        if (led) $fatal(1, "FAIL test 4: retriggered flash lasted too long");
        $display("PASS test 4: retrigger restarts the flash");

        // Test 5: reset immediately interrupts an active flash.
        pulse_trigger();
        if (!led) $fatal(1, "FAIL test 5: setup trigger did not light LED");
        apply_reset();
        if (led) $fatal(1, "FAIL test 5: reset did not interrupt flash");
        $display("PASS test 5: reset interrupts an active flash");

        $display("ALL TESTS PASSED: tb_hit_flash");
        $finish;
    end

endmodule
