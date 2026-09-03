
`timescale 1ns/1ns

module tb_rng;

    logic clk = 0;

    logic [3:0] range_lower;
    logic [3:0] range_upper;

    logic [3:0] random_val;
    logic output_valid;

    integer valid_count;
    integer i;

    rng #(
        .SEED(17)
    ) dut (
        .clk(clk),
        .range_lower(range_lower),
        .range_upper(range_upper),
        .random_val(random_val),
        .output_valid(output_valid)
    );

    always #5 clk = ~clk;

    initial begin

        range_lower = 3;
        range_upper = 6;
        valid_count = 0;

        for (i = 0; i < 100; i = i + 1) begin

            @(posedge clk);
            #1;

            if (output_valid) begin

                if (
                    random_val < range_lower ||
                    random_val > range_upper
                )
                    $fatal(
                        1,
                        "FAIL: RNG output outside 3..6"
                    );

                valid_count = valid_count + 1;

            end
        end

        if (valid_count == 0)
            $fatal(
                1,
                "FAIL: RNG never produced valid output"
            );


        range_lower = 1;
        range_upper = 3;
        valid_count = 0;

        for (i = 0; i < 100; i = i + 1) begin

            @(posedge clk);
            #1;

            if (output_valid) begin

                if (
                    random_val < range_lower ||
                    random_val > range_upper
                )
                    $fatal(
                        1,
                        "FAIL: RNG output outside 1..3"
                    );

                valid_count = valid_count + 1;

            end
        end

        if (valid_count == 0)
            $fatal(
                1,
                "FAIL: RNG second range produced no output"
            );

        $display("ALL TESTS PASSED: tb_rng");
        $finish;
    end

endmodule
