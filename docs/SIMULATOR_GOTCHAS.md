# One testbench, two simulators

You have two simulators available and they are good at different things:

- **Verilator** (Ed workspace) compiles your design and testbench into a native
  program: a few seconds of compiling up front, then very fast simulation. It
  wins on long simulations -- and it is what Ed runs when marking.
- **ModelSim** (comes with Quartus) starts in moments but simulates more
  slowly, so it often finishes first on small testbenches like this
  assignment's. It also models four-state logic (`X` and `Z`), so it can show
  you problems Verilator cannot.

The assignment does not require the same testbenches to run with both, but
getting into the habit now will save you time in future projects, which do.

The items below cover most cases where a testbench passes in Verilator but
fails in ModelSim or vice versa.

## 1. Verilator has no X, ModelSim does.

This is the most common cause. Verilator is a **two-state** simulator: every signal is
either `0` or `1`, and an uninitialised register reads as `0`. ModelSim is **four-state**:
an uninitialised register is `X` (unknown) until something drives it, which models
hardware where a flip-flop's power-up value is not guaranteed.

This means a design that depends on a register initialising to `0` works in Verilator,
but produces a red `X` everywhere in ModelSim.

**What to do:** assert reset at the start of every testbench, before checking
anything at all. Both example testbenches do:

```systemverilog
initial begin
    reset = 1;
    repeat (2) @(posedge clk);
    #1;
    if (out !== 1'b0) $fatal(1, "FAIL: reset did not clear out");
    ...
```

## 2. Arm continuous monitors after the first reset

A monitor that runs on every clock edge for the whole simulation will see `X` in
ModelSim before the first reset and `0` in Verilator, so the same check fails in
one and passes in the other. Gate it on a flag named `armed` that you set after reset:

```systemverilog
logic armed = 0;
always @(posedge CLOCK_50) begin
    if (armed && HEX1 !== 7'b1111111)
        $fatal(1, "FAIL monitor: an unused display lit up");
end
...
    // in the main initial block, once reset has been applied:
    armed = 1;
```

See `tb_demo_top.sv`, which does exactly this.

## 3. Sample `#1` after the clock edge, never on it

When you write `@(posedge clk);` and immediately read a signal, you are reading
it in the same instant the design's non-blocking assignments (`<=`) are updating
it. Whether you see the old or the new value depends on scheduling order, and the
two simulators do not have to agree on this.

```systemverilog
@(posedge clk);
#1;                     // let the <= updates settle, then look
if (count !== 3) $fatal(1, "...");
```

Drive stimulus on the *other* clock edge for the same reason:

```systemverilog
@(negedge clk) reset = 0;
```

## 4. Fail with $fatal, pass with ALL TESTS PASSED

`$error` and `$fatal` both report a failure, but only `$fatal` actually stops the
simulation. In Verilator, `$error` happens to end the test too (the runner
scripts pass `--assert`, which upgrades it), but in ModelSim it does not --
the testbench carries on and may go on to print `ALL TESTS PASSED` regardless.
**Use `$fatal` for every check that should fail the test**, so a failure
halts the simulation in both simulators without depending on tool flags.
