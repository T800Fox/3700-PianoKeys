# Writing a testbench, step by step

This walkthrough builds `tb/tb_blinker.sv` from nothing, one step at a time.
Follow the same steps for your own modules. `tb/tb_demo_top.sv` applies the
same recipe at the system level, and the end of this document covers what
changes there.

The one rule that matters most: **every test checks something and `$fatal`s
when it is wrong.** A testbench that only prints waveforms cannot fail: a
person has to inspect the waves and judge them by eye, and that stops being
practical the moment you want to re-run every test after every change (which
is exactly what the test runner scripts are for).

## 1. Start from the skeleton

A testbench is a module with no ports. It declares one signal per DUT port,
instantiates the DUT (device under test), and generates a clock. (`logic` is
SystemVerilog's general-purpose signal type -- use it wherever you would have
written `reg` or `wire`.)

```systemverilog
module tb_blinker;

    logic clk, reset;
    initial clk = 0;

    // Driven by the DUT; the testbench only ever reads it:
    logic out;

    blinker dut (
        .clk   (clk),
        .reset (reset),
        .out   (out)
    );

    always #10 clk = ~clk;   // 20 ns period, like the DE1-SoC's 50 MHz

endmodule
```

`#10` means "wait 10 time units". The real file starts with
`` `timescale 1ns/1ns ``, which sets one time unit to 1 ns -- so the clock
flips every 10 ns, giving the 20 ns (50 MHz) period.

## 2. Shrink time with a parameter override

At real timing, one LED toggle is 12.5 million clock cycles -- far too slow to
simulate whole tests at. So the count is a module **parameter**, and the
testbench overrides it:

```systemverilog
    localparam CLKS_PER_TOGGLE = 4;

    blinker #(.CLKS_PER_TOGGLE(CLKS_PER_TOGGLE)) dut ( ... );
```

The Verilog being tested is unchanged -- the same RTL goes on the board. Make
**every** timing constant in your design a parameter (clock counts per
millisecond, debounce length, tick period...) so your testbenches can do this.

## 3. Reset first, before checking anything

ModelSim starts flip-flops and registers at `X` (unknown), whereas Verilator
starts them at `0`. A check such as `(out !== 1'b0)` that runs before the first
reset can pass in one simulator and fail in the other. Drive reset active, wait a couple
of clock edges, and only then check -- see [SIMULATOR_GOTCHAS.md](SIMULATOR_GOTCHAS.md)
for the details:

```systemverilog
    initial begin : test_cases
        reset = 1;   // Reset first-thing
        repeat (2) @(posedge clk);
        #1;
        // Check after a couple of clock edges:
        if (out !== 1'b0) $fatal(1, "FAIL test 1: out=%b during reset, expected 0", out);
        $display("PASS test 1: reset holds out low");
```

This is already the first real test: reset must hold the output low.

Note the operator: `!==` (and `===`) also match the two "bad" values -- `X`
(unknown, e.g. an uninitialised register) and `Z` (high-impedance, e.g. an
undriven or disconnected net) -- so a floating or forgotten signal fails the
check instead of slipping through. With the plain `!=`, the comparison
`X != 0` evaluates to `X`, which is not true, so the `if` never fires and the
`$fatal` is silently skipped.

## 4. Fail with `$fatal`, and print one PASS line per test

`$fatal(1, "...")` prints the message and **stops the simulation** -- in both
simulators. `$error` does not stop ModelSim, so a broken design can continue to
the end of the test and still print `ALL TESTS PASSED`. Every check should be
an `if (...) $fatal(...)`, and
every test should end with a `$display("PASS ...")` so the log tells the story.

## 5. Drive on the negedge, sample `#1` after the posedge

The DUT updates its registers on `posedge clk`. If the testbench changes an
input or reads an output at that same instant, whether it sees the old or new
value depends on simulator scheduling -- and the two simulators need not agree.
Two habits avoid the race entirely:

```systemverilog
    @(negedge clk) reset = 0;   // drive inputs on the OTHER (negedge) clock edge

    @(posedge clk);             // read outputs AFTER the posedge clock edge
    #1;                         // lets non-blocking <= assignment updates settle
    if (count !== 3) $fatal(1, "...");
```

## 6. Wrap repeated measurements in a task

The blinker test needs "count clocks until `out` toggles" three times over.
That is a `task` -- like a small procedure with its own local variables:

```systemverilog
    task automatic clocks_to_next_toggle(output int count);
        logic prev;
        prev  = out;
        count = 0;
        while (out === prev) begin
            @(posedge clk);
            #1;
            count++;
            if (count > 100) $fatal(1, "FAIL: out never toggled");
        end
    endtask
```

Three things to note:

- **`automatic`** gives each call its own copy of the locals.
- **`output int count`** is how a task hands a result back. Call it with
  `clocks_to_next_toggle(n);` and read `n`.
- **The timeout guard.** Without `count > 100`, a stuck DUT means an infinite
  loop and a simulation that never ends, instead of a clean FAIL.

Then measure **three toggles in a row**, not just one: a single correct
interval could be a coincidence, while three in a row means the divider is
really counting. (Declare `int n, k;` once, next to your other testbench
signals.)

```systemverilog
    for (k = 0; k < 3; k++) begin
        clocks_to_next_toggle(n);
        if (n !== CLKS_PER_TOGGLE)
            $fatal(1, "FAIL test 2: toggle %0d took %0d clocks, expected %0d",
                   k, n, CLKS_PER_TOGGLE);
    end
```

## 7. Add a continuous monitor for "must never happen" rules

The tests above check one thing at one moment. Some rules should hold for the whole
simulation -- e.g. in the demo, "the unused HEX displays never light up". Put those
in an `always` block that checks every clock edge, and **arm it after the
first reset** (before that, the registers are `X` in ModelSim and the check
would misfire):

```systemverilog
    logic armed = 0;
    always @(posedge CLOCK_50) begin : monitor_unused_hex
        if (armed && HEX1 !== 7'b1111111)
            $fatal(1, "FAIL monitor: an unused display lit up");
    end

    // ...in test_cases, once reset has been applied:
    armed = 1;
```

## 8. Add the waveform dump block

Copy this block, changing only the testbench name in `$dumpvars`.
`scripts/simulate.py` passes `+dump` on the command line, which
`$test$plusargs` detects; `$dumpvars(0, <tb name>)` records every
signal in the testbench and below. Verilator writes compressed `.fst`
waveforms, while ModelSim only writes `.vcd`, hence the `ifdef`:

```systemverilog
    initial begin : waveform_dump
        if ($test$plusargs("dump")) begin
`ifdef VERILATOR
            $dumpfile("waveform.fst");
`else
            $dumpfile("waveform.vcd");
`endif
            $dumpvars(0, tb_blinker);
        end
    end
```

## 9. End with the exact pass string

```systemverilog
        $display("ALL TESTS PASSED: tb_blinker");
        $finish;
```

Both test-runner scripts search the test log for the exact string
`ALL TESTS PASSED` -- reaching that line means no `$fatal` fired. Without it,
the runner counts the test as a FAIL, whatever else was printed.

## 10. Prove your tests can fail

A test suite that cannot fail proves nothing. Break the **module** on
purpose -- invert a comparison (`==` to `!=`), off-by-one a constant -- run the
suite, watch it fail with a useful message, then undo the break. Do this once
per testbench; the assignment's markers do exactly this with broken variants
of your modules.

## The system-level testbench

`tb/tb_demo_top.sv` follows every step above, with one difference: it drives
and checks **only the real board pins**. Its port list is `CLOCK_50`, `KEY`,
`SW`, `LEDR`, `HEX0..HEX5` -- the same names as the top-level module and
`demo.qsf`. That is what makes it an integration test: it proves the modules
really are wired together, all the way out to the system's inputs and outputs.
Base your own system testbench on it.

## Two final habits

- **Verilator is the stricter linter** of the two simulators. Read its
  warnings; the scaffold is warning-free under `-Wall`, and yours can be too.
- Run the whole suite (`python scripts/run_all_tests_verilator.py`) before
  every commit and especially before submission.
