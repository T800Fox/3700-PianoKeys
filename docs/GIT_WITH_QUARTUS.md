# Git with a Quartus project

Quartus generates hundreds of megabytes of databases and reports on every compile, and it rewrites your
project file without prompting you. Both problems are manageable once you are aware of them.

## The rule

**Commit source code. Ignore anything a tool can regenerate.**

Commit:

| What | Why |
|---|---|
| `demo.qpf`, `demo.qsf`, `demo.sdc` | this *is* your project: device, file list, pins, constraints |
| `rtl/`, `tb/` | your code |
| `scripts/`, `docs/`, `*.md` | your tooling and notes |
| `.gitignore`, `.gitattributes` | git config files that tell git which files to ignore and how to handle others |

Never commit: `db/`, `incremental_db/`, `output_files/`, `simulation/`,
`sim_verilator/`, `sim_modelsim/`, `work/`, `*.qws`, `*.sof`, `*.vcd`, `*.fst`. The
shipped `.gitignore` already covers all of it. If you clone the repository and
run `python scripts/compile_fpga.py`, the bitstream is regenerated, which is
why these files do not need to be committed.

There is exactly **one exception**, at the very end: the assignment's
submission checklist requires your **final `.sof`** to be included, so you
commit that one generated file once, right before submitting -- see
[Submitting to Ed](#submitting-to-ed) below.

Before your first push, check:

```sh
git status --short          # nothing unexpected?
```

If something generated has been committed, remove it now (`git rm -r --cached
<path>`, then commit) -- cleaning it out of the history later is considerably
harder.

## The `.qsf` will produce a merge conflict

Every time a setting is changed in the Quartus GUI (adding a file, changing the
device, assigning pins) Quartus **rewrites** `demo.qsf`, potentially reordering and
reformatting lines that were not touched. If two group members do this on the
same day, git sees two large, competing rewrites of the same file.

To avoid this:

- **Add source files by editing `demo.qsf` directly in a text editor**, rather
  than through the GUI.
- **Nominate one person** to make settings changes when the GUI is required, and
  have them commit that change on its own, with a message describing what
  setting changed.
- **Pull before opening Quartus**, and commit and push before closing it.

When a conflict in `demo.qsf` does occur, it is almost always resolvable by
hand: the file is a flat list of independent Tcl assignments, so **keep both
sides' lines** and remove the conflict markers, then run a compile to confirm
the project still builds. (If both sides changed the *same* setting, keep the
one you want -- when a setting appears twice, the last line silently wins.)
Do not resolve the conflict by deleting the other person's file assignments --
this causes a module to silently disappear from the build.

## Working as a group

```sh
git pull                                         # every time you sit down
python scripts/run_all_tests_verilator.py        # before you commit
git add -A
git commit -m "lane FSM: forfeit note on an early press"
git push
```

- **Commit small and often, with messages that explain why.**
- **Never push a commit whose tests fail.**
- **Tag the commit you demo:**

  ```sh
  git tag -a demo -m "State of the design at the demo"
  git push --tags
  ```

  This allows you to return to the version the tutor saw, should something
  break afterwards.

## Submitting to Ed

Ed's git access is tied to an individual student account, so an Ed repository
cannot be shared by a group. Your group works in your own private
GitHub/GitLab repository; Ed only ever sees the final push, from one member.

```sh
python scripts/submit_to_ed.py
```

Ed's git access works over SSH, so whoever submits needs an SSH key registered
with Ed first: https://edstem.org/au/settings/ssh (a "Permission denied
(publickey)" error from the script means this step is missing).

That script adds the Ed remote and pushes to Ed's `master` branch, which is
what Ed marks. Before pushing it tells you what is already on Ed -- your first
submission, or the commit you are about to replace. **Resubmitting is fine**:
each run replaces the previous submission, right up to the deadline. The
remote address is built from the challenge number in the `ED_CHALLENGE_ID`
file in the project root -- one line, containing just the number. If that
number changes, edit the file and the script will re-point the remote
accordingly.

Before running it: commit everything, push to your group remote, and confirm
the test suite passes.

### The final `.sof` -- the one generated file you commit

The submission checklist requires the final bitstream. `.sof` files are
ignored by `.gitignore` (they are large binaries that change on every
compile), so add the last one with `-f` (force), right before you submit:

```sh
python scripts/compile_fpga.py
git add -f output_files/demo.sof     # use your project's name if you renamed it
git commit -m "final bitstream for submission"
```

`submit_to_ed.py` warns you if the commit you are submitting has no `.sof` in
it. Do this as the last step -- once the file is tracked, every recompile shows
it as modified, which is noise you do not want all semester.

To check what was actually submitted, refer to the challenge page on Ed, not
your local repository.
