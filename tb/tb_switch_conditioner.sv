`timescale 1ns/1ns

module tb_switch_conditioner;

    localparam RELEASE_COUNTS = 3;

    logic clk = 0;
    logic switch;
    logic switch_state;
    integer clocks;

    switch_conditioner #(
        .RELEASE_COUNTS(RELEASE_COUNTS)
    ) dut (
        .clk(clk),
        .switch(switch),
        .switch_state(switch_state)
    );

    always #10 clk = ~clk;

    task automatic wait_for_release;
        clocks = 0;
        while (switch_state !== 0) begin
            @(posedge clk); #1;
            clocks = clocks + 1;
            if (clocks > 20)
                $fatal(1, "FAIL: conditioned switch did not release");
        end
    endtask

    initial begin : test_cases
        switch = 0;
        repeat (2) @(posedge clk);
        #1;
        if (switch_state !== 0)
            $fatal(1, "FAIL test 1: power-up state was not low");
        $display("PASS test 1: switch powers up low");

        @(negedge clk) switch = 1;
        #1;
        if (switch_state !== 1)
            $fatal(1, "FAIL test 2: switch did not assert immediately");
        repeat (3) @(posedge clk); #1;
        if (switch_state !== 1)
            $fatal(1, "FAIL test 2: held switch did not remain asserted");
        $display("PASS test 2: switch asserts immediately and remains held");

        @(negedge clk) switch = 0;
        repeat (2) @(posedge clk); #1;
        if (switch_state !== 1)
            $fatal(1, "FAIL test 3: switch released before synchronisation");
        wait_for_release();
        if (clocks < RELEASE_COUNTS)
            $fatal(1, "FAIL test 3: stable-low interval was too short");
        $display("PASS test 3: release is synchronised and delayed");

        // A new high level during release bounce must immediately reassert and
        // restart the complete stable-low interval.
        @(negedge clk) switch = 1;
        @(negedge clk) switch = 0;
        repeat (2) @(posedge clk); #1;
        @(negedge clk) switch = 1;
        #1;
        if (switch_state !== 1)
            $fatal(1, "FAIL test 4: release bounce did not reassert switch");
        @(negedge clk) switch = 0;
        wait_for_release();
        if (clocks < RELEASE_COUNTS)
            $fatal(1, "FAIL test 4: bounce did not restart release delay");
        $display("PASS test 4: release bounce restarts stable interval");

        $display("ALL TESTS PASSED: tb_switch_conditioner");
        $finish;
    end

endmodule
