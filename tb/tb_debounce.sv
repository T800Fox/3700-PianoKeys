`timescale 1ns/1ns

module tb_debounce;

    localparam DELAY_COUNTS = 3;

    logic clk = 0;
    logic reset;
    logic button;
    logic button_pressed;
    integer clocks;

    debounce #(
        .DELAY_COUNTS(DELAY_COUNTS)
    ) dut (
        .clk(clk),
        .reset(reset),
        .button(button),
        .button_pressed(button_pressed)
    );

    always #10 clk = ~clk;

    task automatic apply_reset;
        @(negedge clk) reset = 1;
        repeat (2) @(posedge clk);
        #1;
        @(negedge clk) reset = 0;
    endtask

    task automatic wait_for_level(input logic expected, output integer elapsed);
        elapsed = 0;
        while (button_pressed !== expected) begin
            @(posedge clk); #1;
            elapsed = elapsed + 1;
            if (elapsed > 20)
                $fatal(1, "FAIL: debounce output did not become %b", expected);
        end
    endtask

    initial begin : test_cases
        reset = 0;
        button = 0;
        apply_reset();
        if (button_pressed !== 0)
            $fatal(1, "FAIL test 1: reset did not clear output");
        $display("PASS test 1: reset clears debounce");

        // A one-clock disturbance reaches the synchroniser but is too short
        // to change the debounced level.
        @(negedge clk) button = 1;
        @(negedge clk) button = 0;
        repeat (DELAY_COUNTS + 3) @(posedge clk);
        #1;
        if (button_pressed !== 0)
            $fatal(1, "FAIL test 2: short glitch changed output");
        $display("PASS test 2: short glitch is rejected");

        @(negedge clk) button = 1;
        wait_for_level(1, clocks);
        if (clocks !== DELAY_COUNTS + 2)
            $fatal(1, "FAIL test 3: press took %0d clocks, expected %0d",
                   clocks, DELAY_COUNTS + 2);
        repeat (4) @(posedge clk); #1;
        if (button_pressed !== 1)
            $fatal(1, "FAIL test 3: held input was not stable");
        $display("PASS test 3: stable press is accepted after debounce delay");

        @(negedge clk) button = 0;
        wait_for_level(0, clocks);
        if (clocks !== DELAY_COUNTS + 2)
            $fatal(1, "FAIL test 4: release took %0d clocks, expected %0d",
                   clocks, DELAY_COUNTS + 2);
        $display("PASS test 4: release is independently debounced");

        @(negedge clk) button = 1;
        repeat (2) @(posedge clk);
        apply_reset();
        if (button_pressed !== 0)
            $fatal(1, "FAIL test 5: reset did not interrupt debounce");
        $display("PASS test 5: reset interrupts debounce");

        $display("ALL TESTS PASSED: tb_debounce");
        $finish;
    end

endmodule
