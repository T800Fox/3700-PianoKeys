#!/usr/bin/env python3
"""run_all_tests_modelsim.py, run every testbench in tb/ using ModelSim.

It prints one PASS/FAIL line per testbench and exits non-zero if ANY of them
failed, so you can tell at a glance whether the design is still good.

    python scripts/run_all_tests_modelsim.py              # run everything in tb/
    python scripts/run_all_tests_modelsim.py tb_blinker   # run just one

ModelSim is not in the Ed workspace: it comes with Quartus, so you have it on
your own machine and on the lab PCs. Lean on the Verilator script while you
are writing code -- it is the stricter linter (it will catch more errors) and
it is what Ed runs when marking. For small testbenches like these, ModelSim
actually finishes sooner, since Verilator spends its time compiling; Verilator
pulls ahead on long simulations. The two simulators also disagree
occasionally: see docs/SIMULATOR_GOTCHAS.md.
"""

import shutil
import subprocess
import sys
from pathlib import Path

import common

SIM_MODELSIM = Path("sim_modelsim")


# How a ModelSim run works, in three steps:
#
#   1. vlib work
#          Creates the "work" library that vlog compiles into. Recreated fresh
#          on every run (see the comment below), never reused between runs.
#   2. vlog -quiet -sv <sources>
#          Compiles every .v/.sv file in rtl/ and tb/ into that library, in
#          one go, design and testbenches together.
#   3. vsim -c -quiet -do "..." work.<tb>
#          Elaborates and runs one testbench. Your $display output appears
#          here. Run once per testbench, reusing the library from step 2.
#
# The flags:
#
#   -sv                 Compile SystemVerilog (.sv), not just plain Verilog.
#                       Without it, vlog rejects SV-only syntax outright.
#   -c                  Console mode: no GUI, which is what a script wants.
#   -quiet              Suppresses vlog/vsim's compile-and-load banner noise.
#   -do "onbreak {quit -code 1}; onfinish exit; run -all"
#                       Run to completion, then quit. Without "onfinish exit",
#                       $finish drops you at the vsim prompt and a script
#                       hangs forever waiting for input. onbreak does the same
#                       for a $stop, which would otherwise strand vsim at its
#                       prompt (running with stdin closed guards any case
#                       these two miss).


def main(argv):
    common.chdir_to_project_root()

    common.require_tool("vsim", "ModelSim comes with Quartus. Check it is on your PATH.")

    # The design and the testbenches all get compiled together:
    sources = common.collect_verilog_files("rtl", "tb")

    # Every testbench in tb/, narrowed to the ones named on the command line:
    testbenches = common.select_testbenches(common.collect_testbenches(), argv)

    SIM_MODELSIM.mkdir(exist_ok=True)

    # We run ModelSim inside sim_modelsim/, so the source paths need one more
    # level to climb back out of it:
    sources = [f"../{p}" for p in sources]

    # Delete any old ModelSim work library, so we start fresh each time, then
    # create a new one. vlog compiles modules into this folder and they stay
    # there, so without the delete a module whose source file you deleted would
    # still be found.
    shutil.rmtree(SIM_MODELSIM / "work", ignore_errors=True)
    common.run(["vlib", "work"], cwd=SIM_MODELSIM)

    common.info(f"Found {len(testbenches)} testbench(es) in tb/")
    common.info(f"Compiling {len(sources)} source file(s) from rtl/ and tb/ with vlog")

    # Compile the design and all the testbenches in one go:
    compile_result = common.run(["vlog", "-quiet", "-sv", *sources], cwd=SIM_MODELSIM)
    if compile_result.returncode != 0:
        common.abort(f"{common.C_FAIL}FAIL{common.C_OFF}: compilation errors -- "
                   "fix these before running any test")

    score = common.Scoreboard()

    for tb_file in testbenches:
        tb_name = common.tb_name(tb_file)
        log = SIM_MODELSIM / f"{tb_name}.log"

        print(f"{common.C_DIM}RUN {common.C_OFF}  {tb_name}"
              f"   {common.C_DIM}(vsim){common.C_OFF}", flush=True)

        # -c runs ModelSim in console mode, with no GUI, which is what a script
        # wants. The -do handlers make both ways a simulation can end ($finish,
        # $stop) quit vsim instead of dropping to its interactive prompt, where
        # it would hang forever waiting for input. stdin=DEVNULL is a
        # belt-and-braces guard for the same hang.
        result = common.run(["vsim", "-c", "-quiet",
                             "-do", "onbreak {quit -code 1}; onfinish exit; run -all",
                             f"work.{tb_name}"],
                            cwd=SIM_MODELSIM, capture=True,
                            stdin=subprocess.DEVNULL)

        log.write_text(result.stdout)
        score.check_log(tb_name, log)

    return score.summary()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
