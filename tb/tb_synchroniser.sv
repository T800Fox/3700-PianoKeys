`timescale 1ns/1ns

module tb_synchroniser;

    logic clk = 0;
    logic reset;
    logic x;
    logic y;

    synchroniser dut (
        .clk(clk),
        .reset(reset),
        .x(x),
        .y(y)
    );

    always #10 clk = ~clk;

    initial begin : test_cases
        reset = 1;
        x = 0;
        repeat (2) @(posedge clk);
        #1;
        if (y !== 0) $fatal(1, "FAIL test 1: reset did not clear output");
        $display("PASS test 1: reset clears synchroniser");

        @(negedge clk) reset = 0;
        x = 1;
        @(posedge clk); #1;
        if (y !== 0) $fatal(1, "FAIL test 2: input crossed fewer than two registers");
        @(posedge clk); #1;
        if (y !== 1) $fatal(1, "FAIL test 2: rising input did not propagate");
        $display("PASS test 2: rising input crosses two registers");

        @(negedge clk) x = 0;
        @(posedge clk); #1;
        if (y !== 1) $fatal(1, "FAIL test 3: falling input crossed too soon");
        @(posedge clk); #1;
        if (y !== 0) $fatal(1, "FAIL test 3: falling input did not propagate");
        $display("PASS test 3: falling input crosses two registers");

        @(negedge clk) x = 1;
        @(posedge clk); #1;
        @(negedge clk) reset = 1;
        @(posedge clk); #1;
        if (y !== 0) $fatal(1, "FAIL test 4: reset did not interrupt transition");
        $display("PASS test 4: reset interrupts a transition");

        $display("ALL TESTS PASSED: tb_synchroniser");
        $finish;
    end

endmodule
