# MTRX3700 Assignment 1 -- Scaffold

A scaffold DE1-SoC project, which compiles, simulates and passes a basic set of tests.
A git repository is set up with an initial commit that you can build on.

You can use this scaffold as a basis for your submission.

## What is here

```
demo.qpf demo.qsf demo.sdc    Quartus project: device, file list, the full
                              FPGA-side DE1-SoC pin map (Assignment 1 pins
                              first), timing constraints for a 50 MHz clock
rtl/blinker.v                 a parameterised clock divider
rtl/demo_top.sv               top level: DE1-SoC port list, board smoke test
                              behaviour. Instantiates the blinker module.
tb/tb_blinker.sv              module-level self-checking testbench
tb/tb_demo_top.sv             system-level testbench, board pins only
scripts/                      test runners, Quartus build script,
                              Ed submission, and a Containerfile for running
                              Verilator
docs/WRITING_TESTBENCHES.md   building a self-checking testbench, step by step
docs/SIMULATOR_GOTCHAS.md     making one testbench work in both simulators
docs/GIT_WITH_QUARTUS.md      what to commit, and how to manage git conflicts
ED_CHALLENGE_ID               the Ed challenge number, used when you submit
.gitignore .gitattributes     already set up for git & Quartus use
```

`demo.qsf` assigns every FPGA-side pin on the DE1-SoC: the Assignment 1 I/O
(clock, KEYs, switches, LEDs, HEX displays) first, then the rest of the board
grouped and labelled (VGA, audio, SDRAM, GPIO headers, ...). Assignments for
pins your design does not use are ignored, so there is nothing to import for
this or later projects.

The commands below use `python`; if your machine says it is not found, type
`python3` instead (macOS and most Linux installs only have the latter). On
Windows, if neither works, install Python from https://python.org and re-open
the terminal.

## Adapting this scaffold to your project

Here is a recommendation for how to adapt this scaffold to your project:

1. Write your modules in `rtl/`, your testbenches in `tb/`.
2. **Add every new source file to `demo.qsf`.** Quartus silently ignores files
   that are not in the list, and the error you get looks like a typo in a module
   name rather than a missing file.
3. Build your top level based on `rtl/demo_top.sv`. Its port list matches the
   Assignment 1 pins in `demo.qsf` (add ports for any other board I/O you use --
   the pin assignments are already there). If you rename the module, update
   `TOP_LEVEL_ENTITY` in `demo.qsf` to match.
4. `rtl/blinker.v` and `tb/tb_blinker.sv` are only examples. Build your
   system-level integration testbench based on `tb/tb_demo_top.sv`. It already
   drives the real board pins.
5. Rename the project: rename `demo.qpf`, `demo.qsf` and `demo.sdc` together
   (they must share a base name) and update `PROJECT` in `scripts/compile_fpga.py`.

## Testbench examples

The two testbenches in `tb/` are worked examples of self-checking testbenches:
**every test checks something and `$fatal`s when it is wrong**, and each prints
`ALL TESTS PASSED: <name>` at the end -- the exact string both test runner
scripts use as their pass criterion.

[docs/WRITING_TESTBENCHES.md](docs/WRITING_TESTBENCHES.md) walks through
building them step by step -- parameter overrides that shrink 12.5 million
clock cycles down to 4, tasks, continuous monitors, waveform dumps, and how to
prove your tests can actually fail. Build your own testbenches the same way.

## Running Verilator tests (required for your submission)

Assignment 1 requires a script to execute your self-checking testbenches with Verilator within your
Ed submission. The following Python scripts provided in this scaffold can be used for this.

The script below runs **all** Verilog/SystemVerilog files in `tb/` as testbenches with Verilator:

```sh
python scripts/run_all_tests_verilator.py
== Found 2 testbench(es) in tb/, running each with Verilator 5.050
RUN   tb_blinker   (verilate, compile, simulate)
PASS  tb_blinker
RUN   tb_demo_top   (verilate, compile, simulate)
PASS  tb_demo_top

2 passed, 0 failed
```

Verilator spends a few seconds compiling each testbench before the simulation
itself runs -- that is normal (see
[docs/SIMULATOR_GOTCHAS.md](docs/SIMULATOR_GOTCHAS.md) on how the two
simulators trade off).

We recommend that you use the above setup for your testbenches. Every `.v`/`.sv`
file in `tb/` is run as a testbench automatically -- there is no list to
maintain -- and its top module must have the same name as the file. Keep helper
modules in `rtl/`, or the runner will try to run them as tests.

To run a single testbench, see its output, and get its waveform, use the
following script with the testbench name as an argument:

```sh
python scripts/simulate.py tb_blinker
```

The testbenches write their waveform to `sim_verilator/waveform.fst`, which you can
open in a waveform viewer. The script prints the command to open it rather than launching
it for you, so the viewer stays open while you work. Two open source waveform viewers that
you can install:
* [Surfer](https://surfer-project.org) (modern, recommended) and
* [GTKWave](https://gtkwave.sourceforge.net) (the classic, on Ed).

On Ed, you are stuck with GTKWave.

### Running Verilator locally (Optional)

In the Ed workspace, the two Python scripts above should work out of the box. However, if you want
to run Verilator on your own computer, we recommend using a container. A container packages
Verilator and its dependencies into a single, ready-to-run environment, so you don't have
to install anything manually, apart from the software that runs the container itself.
[Podman](https://podman.io) or [Docker](https://docker.com) are the two most common tools for
running containers - we recommend Podman, as it's free and open-source with no licensing restrictions.

Once Podman is installed, `run_all_tests_verilator.py` and `simulate.py` will automatically run
Verilator inside a container, on every platform, whether or not you also have Verilator installed.
This is the easiest way to get these scripts running on Windows, since Verilator has no native
Windows build at all. Install Podman with: https://podman.io/docs/installation

```sh
# macOS (with Homebrew)
brew install podman && podman machine init && podman machine start

# Windows -- podman machine needs WSL2; if it cannot find it, run
# `wsl --install` first, then `podman machine init` again
winget install -e --id RedHat.Podman
podman machine init
podman machine start

# Linux
sudo apt install podman   # or docker.io
```

If you already have Docker, that works too -- no extra setup, since Docker and Podman share
almost the same command-line syntax.

If you would rather install Verilator natively (macOS/Linux only), that works
as well: the scripts fall back to a native `verilator` on your PATH whenever no
container runtime is available. On macOS, Homebrew's Verilator also needs the
lz4 headers for its waveform writer -- `brew install lz4` -- and the scripts
know where Homebrew keeps them.

## Running ModelSim tests (Optional)

While Assignment 1 does not require proof of your testbenches running in ModelSim, it's worth
knowing how, since later assignments do. Ed does not have Quartus available, so this only works
on your own machine, where you should have ModelSim and Quartus 18.1 installed.

Similar to run_all_tests_verilator.py, the following script runs **all** Verilog/SystemVerilog
files in `tb/` but using the ModelSim CLI:

```sh
python scripts/run_all_tests_modelsim.py     # same tests, different simulator
```

### Simulating in both ModelSim and Verilator

Being able to simulate your testbenches in both Verilator and ModelSim will be
useful for future projects.

The unmodified scaffold tests pass in both simulators. Testbenches you write are
not automatically that portable -- the two simulators genuinely disagree in a few
areas -- see [docs/SIMULATOR_GOTCHAS.md](docs/SIMULATOR_GOTCHAS.md).

## Running Quartus compile (CLI)

You can also run Quartus compile from a Python script. This also checks timing constraints
are met, in addition to producing the `.sof` file to program the board:

```sh
python scripts/compile_fpga.py               # full Quartus build using the CLI
```

You can also program the board over USB-Blaster via the Quartus CLI:

```sh
quartus_pgm -m jtag -o "p;output_files/demo.sof@2" # Program the board
# (@2 = the FPGA: device 1 in the DE1-SoC's JTAG chain is the ARM HPS)
```

Program the board and LEDR0 should blink about twice a second, LEDR4-1 should
follow the four KEYs, LEDR6-5 should follow SW9-SW8, and HEX0's segments should
follow SW7-SW1. Reset is SW0 -- the same switch the assignment fixes as the
game reset.

### Quartus warnings

Knowing which warnings can be ignored is a real skill. A clean build of this
scaffold reports over 200 warnings (most of them pin assignments for board
I/O the demo does not use), and every one of them is explainable:

- **`Pin "X" is stuck at GND/VCC`** -- the held-off LEDs and blank HEX
  displays. Expected: they are tied to a constant on purpose (plus one summary
  line, `Output pins are stuck at VCC or GND`).
- **`Ignored locations or region assignments`** -- pin assignments for board
  I/O your design does not use. Expected: `demo.qsf` deliberately carries the
  whole DE1-SoC pin map.
- **`Number of processors has not been specified`** and **`User specified to
  use only one processors`** -- performance hints about parallel compilation,
  nothing to do with your design.
- **`Some pins have incomplete I/O assignments`** -- drive strength and slew
  rate left at their defaults, which is fine for this board.
- **`Feature LogicLock is only available with a valid subscription`** -- Lite
  edition telling you about a feature you are not using.

`scripts/compile_fpga.py` knows this list: at the end of a build it prints a
warning summary with these filtered out, so anything it does show you is worth
reading. Do *not* ignore: any `Error`, or warnings about implicit nets,
inferred latches, or undriven signals on a signal you thought you were using.
It is a good idea to inspect the netlist viewers to sanity check that
everything is connected too.

For reference, the shipped scaffold compiles into 19 ALMs, 25
registers, 67 pins, 0 memory bits, worst-case setup slack +15.9 ns at 50 MHz.

## Git and submission (guidance only)

The scaffold here is already a git repository with one commit in it, so you
can start committing immediately.

**Day one:** create one empty **private** repository for your group on GitHub or
GitLab, add everyone as a collaborator, then download this scaffold (as a zip),
extract, and open a terminal inside the folder and run git:

```sh
git remote add origin git@github.com:your-org/mtrx3700-a1.git
git push -u origin master
```

(Use the URL GitHub shows on the repository's page -- the HTTPS one is easiest
if you have not set up SSH keys.)

Everyone else clones that repository instead of unzipping the scaffold again. ***Keep it
private***: a public repository of your solution is an academic integrity problem
for you and for whoever finds it.

Before your first commit, on each machine:

```sh
git config --global user.name  "Your Name"
git config --global user.email "your.unikey@uni.sydney.edu.au"
```

**Submission:** one member runs

```sh
python scripts/submit_to_ed.py
```

which adds the Ed submission task's remote and pushes to its `master` branch.
Ed marks whatever is at the HEAD of `master`, and re-running the script
replaces the previous submission -- resubmitting is fine, right up to the
deadline. Ed's git access is tied to an individual student account, so it only
works for whoever runs it -- that is fine, only one submission is needed.
Commit and push everything to your group remote first, including the final
`.sof` (see below).

The remote is built from the challenge number in `ED_CHALLENGE_ID` in the
project root.

See [docs/GIT_WITH_QUARTUS.md](docs/GIT_WITH_QUARTUS.md) for what to commit --
including the one generated file the submission checklist *does* require, your
final `.sof` -- what to avoid committing, and what to do when Quartus rewrites
`demo.qsf` and two people have edited it (leading to merge conflicts).
