# Orchestrating parallel workers

The orchestrator (integrator) does not decompile much itself. It splits the work, launches workers, integrates and
verifies, fixes the toolchain when workers hit systematic problems, and keeps `docs/STATE.md` current.

## Split the work

- Partition the source files into disjoint **ranges** (e.g. thirds of the code address space). One worker per range;
  a range has exactly one owner at any time. Write the owner into STATE.md.
- Give the project a short **worker protocol file** (copy `templates/agent_protocol.md` to `docs/agent_protocol.md`
  and adapt it). Then a launch prompt is four lines, not forty:

  ```
  Matching decompilation of <game> in <path>. Read docs/agent_protocol.md and docs/decomp_guide.md, then follow the
  protocol exactly. Your files: <first> .. <last> (`ls src | sort` order), range "<X>". Worklog: docs/worklog/<X>.md
  (read it first). Scratch folder: <name>. Priority: <what>. Stop after ~N matches or ~M tries, then report.
  ```

- Give each round a **focus** that changes as the project matures: smallest functions first; then the class a
  toolchain fix just unblocked (retry its give-ups first); then mid-size functions nobody tried; then special
  classes (switch tables, vector code, unoptimised objects).

## Resources and models

- Workers are independent processes that each compile code: on a 16 GB machine, three at a time is a safe ceiling;
  build with limited parallelism (`ninja -j4`). One compile/check at a time per worker.
- A mid-size model handles the per-function loop at the same rate as a large one; use the large one for toolchain
  forensics, mixed vector/assembly code, and when a worker reports a systematic blocker.
- When the per-round yield drops (few matches per hundred tried), change the focus or fix the toolchain: do not just
  relaunch the same worker.

## Integrate

1. `dk rescue` if workers were interrupted.
2. Run the full build on the committed HEAD in a separate git worktree (generated files of running workers stay
   untouched): split → (re-add missing `INCLUDE_ASM` lines) → build → compare. Push only if byte-identical. A script
   for this (`scripts/integrate.sh` in the reference project) makes it one command.
3. If it fails, find the first function whose address moved (compare symbol addresses of the rebuilt ELF with the
   original), not the first differing byte: the cause is usually a missing padding, a missing data declaration or a
   function that grew.
4. Update STATE.md.

## Changes only the integrator makes, and when

- **Renames / new symbols** change what the splitter generates and the names workers use: apply them only when no
  worker runs (collect suggestions in a "names pending" list meanwhile). After renaming: re-split, re-add missing
  `INCLUDE_ASM` lines (a new symbol can cut a function in two), re-split, build.
- **Toolchain changes** (flags, assembler filter, prelude macros): verify with `dk all` that no matched function
  breaks, commit, then message the running workers what changed and which of their give-ups to retry.
- **Re-chunking** files (e.g. moving an unoptimised library into its own file with its own flags): only when the owner
  of those files is not running.

## Watch for

- A worker you think stopped may still be running (resumed after a rate limit): two writers on one range lose work.
- Workers "solving" a systematic difference with hacks (inline asm with ordinary instructions, register pins
  everywhere): that is a toolchain question; investigate it yourself.
- A function deleted by accident while editing (a slice replace that swallowed a neighbour): the integration build
  catches it; make the configure step re-add missing `INCLUDE_ASM` lines so the published tree always builds.
