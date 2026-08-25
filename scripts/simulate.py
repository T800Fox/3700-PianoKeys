#!/usr/bin/env python3
"""simulate.py, run ONE testbench and write a waveform that you can look at.

    python scripts/simulate.py tb_blinker

Use run_all_tests_verilator.py to check that everything passes.
Use this when one test is failing and you need to see why.

This script does not open a waveform viewer for you.
It prints the command to open the waveform, so you can run it yourself in a
terminal and keep it open while you work.
"""

import os
import shutil
import sys

import common


def find_waveform_viewer(name, env_var):
    """Is the waveform viewer `name` available?
    """
    # Inside the container: "HAVE_SURFER" and "HAVE_GTKWAVE" should be set.
    if env_var in os.environ:
        return os.environ[env_var] == "1"
    # Outside the container: check the PATH for the executable.
    return shutil.which(name) is not None


def report_waveform(wave, have_surfer, have_gtkwave):
    """Tell the user how to open the waveform we just wrote."""
    print()
    common.info(f"Waveform written to {common.C_BOLD}{wave}{common.C_OFF}")

    if not (have_surfer or have_gtkwave):
        print("   No waveform viewer is installed. Install one of the following:")
        print(f"     {common.C_BOLD}Surfer{common.C_OFF}   https://surfer-project.org        {common.C_DIM}(modern, recommended){common.C_OFF}")
        print(f"     {common.C_BOLD}GTKWave{common.C_OFF}  https://gtkwave.sourceforge.net   {common.C_DIM}(the classic, used on Ed){common.C_OFF}")
        return
    print("   Open it with:")
    if have_surfer:
        print(f"     {common.C_BOLD}surfer {wave}{common.C_OFF}")
    if have_gtkwave:
        print(f"     {common.C_BOLD}gtkwave {wave}{common.C_OFF}")


def main(args):
    # Check for waveform viewer software:
    have_surfer = find_waveform_viewer("surfer", "HAVE_SURFER")
    have_gtkwave = find_waveform_viewer("gtkwave", "HAVE_GTKWAVE")

    common.chdir_to_project_root()
    common.run_verilator_container_if_available(env={
        "HAVE_SURFER": "1" if have_surfer else "0",
        "HAVE_GTKWAVE": "1" if have_gtkwave else "0",
    })

    common.require_tool("verilator", common.verilator_advice())

    testbenches = common.collect_testbenches()
    by_name = {common.tb_name(t): t for t in testbenches}

    # Exactly one testbench name is required. Without a valid one, say what is
    # available rather than just failing:
    wanted = args[0] if args else ""
    if wanted not in by_name:
        if wanted:
            common.warn(f"No testbench called '{wanted}' in tb/")
        print("usage: python scripts/simulate.py <testbench name, e.g. tb_blinker>")
        print("available:")
        for name in sorted(by_name):
            print(f"  {name}")
        return 1

    tb = wanted
    tb_file = by_name[tb]
    rtl = common.collect_verilog_files("rtl")

    # Start fresh if a different Verilator built this directory last time:
    version = common.verilator_build_dir()

    common.info(f"Verilating and compiling {tb} with {version}")

    obj_dir = common.SIM_VERILATOR_FOLDER / f"obj_{tb}"

    # Verilate: translate the testbench and design into C++:
    result = common.run(["verilator", *common.VERILATOR_FLAGS,
                         "--top", tb, "--Mdir", str(obj_dir),
                         "--cc", *[str(p) for p in rtl], str(tb_file),
                         "--main", "--exe"])
    if result.returncode != 0:
        return result.returncode  # nothing to compile

    # Compile that C++ into a simulation executable:
    result = common.run(["make", "-s", "-C", str(obj_dir), "-f", f"V{tb}.mk", f"V{tb}"])
    if result.returncode != 0:
        return result.returncode  # nothing to run

    common.info(f"Running {tb}")

    # The simulation writes its waveform into whichever directory it runs in, so
    # run it inside sim_verilator/ to keep the file out of the project root.
    # +dump is what switches on the $dumpvars in the testbench.
    executable = (common.SIM_VERILATOR_FOLDER / f"obj_{tb}" / f"V{tb}").resolve()
    result = common.run([str(executable), "+dump"], cwd=common.SIM_VERILATOR_FOLDER)

    # Assume the waveform is always written to waveform.fst, which is what the
    # testbenches do. If you change that, change it here too.
    report_waveform(common.SIM_VERILATOR_FOLDER / "waveform.fst", have_surfer, have_gtkwave)
    return result.returncode


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
