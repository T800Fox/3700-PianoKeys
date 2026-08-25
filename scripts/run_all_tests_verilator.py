#!/usr/bin/env python3
"""run_all_tests_verilator.py, run every testbench in tb/ using Verilator.

It prints one PASS/FAIL line per testbench and exits non-zero if ANY of them
failed, so you can tell at a glance whether the design is still good.

Regression testing: get in the habit of running this before every commit.

    python scripts/run_all_tests_verilator.py              # run everything in tb/
    python scripts/run_all_tests_verilator.py tb_blinker   # run just one
"""

import sys

import common


# How a Verilator run works, in three steps:
#
#   1. verilator ... --cc <sources> --main --exe
#          Translates your Verilog/SystemVerilog into C++ ("verilating").
#   2. make -C obj_<tb> -f V<tb>.mk V<tb>
#          Compiles that C++ into a native simulation executable.
#   3. ./obj_<tb>/V<tb>
#          Runs it. Your $display output appears here.
#
# The lint and tracing flags live in common.VERILATOR_FLAGS, which explains each
# one. The flags below are the ones that differ per testbench:
#
#   --top <tb>          Names the top module. Needed because the testbench, not
#                       the design, is the top level here.
#   --Mdir <dir>        Keeps each testbench's generated C++ in its own folder,
#                       so they do not overwrite each other.
#   --main --exe        Ask Verilator to generate the C++ main() for us, so no
#                       hand-written wrapper .cpp is needed.


def main(argv):
    common.chdir_to_project_root()
    common.run_verilator_container_if_available()

    common.require_tool("verilator", common.verilator_advice())

    # Your design files. Add new directories here if you make any:
    rtl = common.collect_verilog_files("rtl")

    # Every testbench in tb/, narrowed to the ones named on the command line:
    testbenches = common.select_testbenches(common.collect_testbenches(), argv)

    # Start fresh if a different Verilator built this directory last time:
    version = common.verilator_build_dir()

    common.info(f"Found {len(testbenches)} testbench(es) in tb/, "
                f"running each with {version}")

    score = common.Scoreboard()

    for tb_file in testbenches:
        tb_name = common.tb_name(tb_file)
        obj_dir = common.SIM_VERILATOR_FOLDER / f"obj_{tb_name}"
        log = common.SIM_VERILATOR_FOLDER / f"{tb_name}.log"

        # Verilator's translate-to-C++-and-compile steps take a few seconds
        # per testbench, so say what is happening before going quiet:
        print(f"{common.C_DIM}RUN {common.C_OFF}  {tb_name}"
              f"   {common.C_DIM}(verilate, compile, simulate){common.C_OFF}",
              flush=True)

        # The three steps from the header comment, each as an argv list -- what
        # you would type at a shell prompt, split into separate arguments:
        steps = [
            ["verilator", *common.VERILATOR_FLAGS,
             "--top", tb_name, "--Mdir", str(obj_dir),
             "--cc", *[str(p) for p in rtl], str(tb_file),
             "--main", "--exe"],
            ["make", "-s", "-C", str(obj_dir), "-f", f"V{tb_name}.mk", f"V{tb_name}"],
            [str(obj_dir / f"V{tb_name}")],
        ]

        # Everything (verilate + compile + run) is written to the log file.
        output = ""
        for step in steps:
            result = common.run(step, capture=True)
            output += result.stdout
            # Stop at the first step that fails: there is no point running a
            # simulation that did not compile.
            if result.returncode != 0:
                break

        log.write_text(output)
        score.check_log(tb_name, log)

    return score.summary()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
