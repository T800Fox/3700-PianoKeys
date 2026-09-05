
`timescale 1ns/1ns

module tb_seven_seg;

    logic clk = 0;

    logic [3:0] bcd;
    logic [6:0] segments;

    seven_seg dut (
        .bcd(bcd),
        .segments(segments)
    );

    task automatic check_bcd(
        input [3:0]  bcd_value,
        input [6:0]  expected_segments,
        input string test_name
    );
        bcd = bcd_value;
        #1;
        if (segments !== expected_segments)
            $fatal(1, "FAIL %s: digit %0d not correctly displayed; expected %b got %b",
                    test_name, bcd_value, expected_segments, segments);
        $display("PASS %s: digit %0d correctly displayed", test_name, bcd_value);
    endtask

    /* verilator lint_off BLKSEQ */
    always #10 clk = ~clk;   // 20 ns period, like the DE1-SoC's 50 MHz
    /* verilator lint_on BLKSEQ */

    initial begin : waveform_dump
        if ($test$plusargs("dump")) begin
`ifdef VERILATOR
            $dumpfile("waveform.fst");
`else
            $dumpfile("waveform.vcd");
`endif
            $dumpvars(0, tb_score_handler);
        end
    end

    initial begin : test_cases

        // Test 1: Display 0
        check_bcd(0, 7'b1000000, "test 1");
        #1;

        // Test 2: Display 1
        check_bcd(1, 7'b1111001, "test 2");
        #1;

        // Test 3: Display 2
        check_bcd(2, 7'b0100100, "test 3");
        #1;

        // Test 4: Display 3
        check_bcd(3, 7'b0110000, "test 4");
        #1;

        // Test 5: Display 4
        check_bcd(4, 7'b0011001, "test 5");
        #1;

        // Test 6: Display 5
        check_bcd(5, 7'b0010010, "test 6");
        #1;

        // Test 7: Display 6
        check_bcd(6, 7'b0000010, "test 7");
        #1;

        // Test 8: Display 7
        check_bcd(7, 7'b1111000, "test 8");
        #1;

        // Test 9: Display 8
        check_bcd(8, 7'b0000000, "test 9");
        #1;

        // Test 10: Display 9
        check_bcd(9, 7'b1000000, "test 10");
        #1;

        // Test 11: Display Nothing
        check_bcd(10, 7'b1111111, "test 11");
        #1;

        // Test 12: Display Overflow Character
        check_bcd(11, 7'b0111111, "test 12")

        $display("ALL TESTS PASSED: tb_seven_seg");
        $finish;
    end

endmodule
