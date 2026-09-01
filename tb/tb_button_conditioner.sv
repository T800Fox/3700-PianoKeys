`timescale 1ns/1ns

module tb_button_conditioner;

    localparam DEBOUNCE_COUNTS = 3;

    logic clk = 0;
    logic reset;
    logic button;
    logic press_pulse;
    integer pulses;
    integer clocks;

    button_conditioner #(
        .DEBOUNCE_COUNTS(DEBOUNCE_COUNTS)
    ) dut (
        .clk(clk),
        .reset(reset),
        .button(button),
        .press_pulse(press_pulse)
    );

    always #10 clk = ~clk;

    always @(posedge clk) begin
        #1;
        if (press_pulse)
            pulses = pulses + 1;
    end

    task automatic apply_reset;
        @(negedge clk) reset = 1;
        repeat (2) @(posedge clk);
        #1;
        @(negedge clk) reset = 0;
    endtask

    task automatic wait_for_pulse;
        clocks = 0;
        while (!press_pulse) begin
            @(posedge clk); #1;
            clocks = clocks + 1;
            if (clocks > 20)
                $fatal(1, "FAIL: conditioned press pulse did not arrive");
        end
    endtask

    initial begin : test_cases
        reset = 0;
        button = 1; // Active-low button released
        pulses = 0;
        apply_reset();
        if (press_pulse !== 0)
            $fatal(1, "FAIL test 1: reset produced a pulse");
        $display("PASS test 1: reset leaves button released");

        @(negedge clk) button = 0;
        wait_for_pulse();
        repeat (8) @(posedge clk);
        #1;
        if (pulses !== 1)
            $fatal(1, "FAIL test 2: held press produced %0d pulses", pulses);
        $display("PASS test 2: held button produces one pulse");

        @(negedge clk) button = 1;
        repeat (DEBOUNCE_COUNTS + 3) @(posedge clk);
        #1;
        if (pulses !== 1)
            $fatal(1, "FAIL test 3: release produced a press pulse");
        $display("PASS test 3: release produces no pulse");

        // Several raw transitions emulate contact bounce before a stable press.
        @(negedge clk) button = 0;
        @(negedge clk) button = 1;
        @(negedge clk) button = 0;
        @(negedge clk) button = 1;
        @(negedge clk) button = 0;
        wait_for_pulse();
        repeat (6) @(posedge clk);
        #1;
        if (pulses !== 2)
            $fatal(1, "FAIL test 4: bounced press gave %0d total pulses", pulses);
        $display("PASS test 4: bounced press produces one pulse");

        apply_reset();
        if (press_pulse !== 0)
            $fatal(1, "FAIL test 5: reset did not clear edge history");
        $display("PASS test 5: reset clears edge detection");

        $display("ALL TESTS PASSED: tb_button_conditioner");
        $finish;
    end

endmodule
