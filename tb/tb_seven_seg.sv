
`timescale 1ns/1ns

module tb_seven_seg;

    logic [3:0] bcd;
    logic [6:0] segments;

    seven_seg dut (
        .bcd(bcd),
        .segments(segments)
    );

    initial begin

        bcd = 0;
        #1;
        if (segments !== 7'b1000000)
            $fatal(1, "FAIL: digit 0");

        bcd = 1;
        #1;
        if (segments !== 7'b1111001)
            $fatal(1, "FAIL: digit 1");

        bcd = 9;
        #1;
        if (segments !== 7'b0010000)
            $fatal(1, "FAIL: digit 9");

        bcd = 10;
        #1;
        if (segments !== 7'b1111111)
            $fatal(1, "FAIL: blank sentinel");

        bcd = 11;
        #1;
        if (segments !== 7'b0111111)
            $fatal(1, "FAIL: overflow indication");

        $display("ALL TESTS PASSED: tb_seven_seg");
        $finish;
    end

endmodule
