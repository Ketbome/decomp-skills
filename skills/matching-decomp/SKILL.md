---
name: matching-decomp
description: Run a matching decompilation (C/C++ that recompiles to the exact original bytes) efficiently and survive interrupted sessions. Use when starting or continuing a decomp project (splat/INCLUDE_ASM layout, MIPS PS1/PS2/N64/PSP and similar), decompiling functions, orchestrating parallel worker agents, identifying a compiler/assembler's quirks, integrating and verifying the build, or resuming after a crash, rate limit or context reset.
license: MIT
---

# Matching decompilation

A matching decomp rewrites a game's code in C/C++ so that the original compiler turns it back into the same bytes.
Progress is measured, every step is verifiable, and the work splits into thousands of small independent tasks. That
makes it a good fit for agents, as long as three things hold: **every claim is checked by a byte comparison, every
finished piece is committed at once, and the project's state lives in files, not in anyone's context.**

This skill provides the method, a tool (`scripts/dk.py`, "decomp kit") and templates.

## Pick your situation

| Situation | Read |
|---|---|
| Resuming after a crash, rate limit, `/clear`, new session | [references/recovery.md](references/recovery.md) — always first |
| Starting a new project (split the binary, find the compiler, first match) | [references/setup.md](references/setup.md) |
| Decompiling functions yourself, or as a worker agent | [references/worker.md](references/worker.md) |
| Running several worker agents in parallel and integrating their work | [references/orchestration.md](references/orchestration.md) |
| A function "should" match but the bytes differ in a systematic way | [references/toolchain-forensics.md](references/toolchain-forensics.md) |
| Techniques to steer the compiler (registers, order, branches, loops) | [references/matching.md](references/matching.md) |
| Near misses: let decomp-permuter search instead of spending tokens | [references/permuter.md](references/permuter.md) |

## The tool

`scripts/dk.py` (Python 3.9+, `pip install pyelftools tomli`) reads a `decomp.toml` at the project root
([templates/decomp.toml](templates/decomp.toml)). Copy it into the project (`tools/dk.py`) so workers can run it.

```
dk show <func>                 original asm + m2c draft + which source holds it
dk next <src...> [--max-size]  INCLUDE_ASM functions, smallest first, flags: jtbl, vu0:N%, fragment?
dk try <src> <func>            pre-check hooks, then compare that function with the original bytes
dk revert <src> <func>         back to INCLUDE_ASM
dk done <src> <log> <msg>      refuse unless every function of <src> matches, then commit <src> + <log>
dk all                         check every written function (after any toolchain change)
dk state                       recovery report: STATE.md, uncommitted sources and whether they match, commits
dk rescue [--commit]           revert work-in-progress that does not match, keep and commit the rest
```

`check` compiles the source privately (safe in parallel), takes the function out of the object and compares it
with the original bytes; fields the linker fills in are compared by symbol and addend, so it proves a match without
linking. The full build (`ninja` or whatever the project uses) stays the final word.

## Rules that make the work efficient and safe

1. **Verify, don't believe.** A function is done only when `dk check` says MATCH; the build is done only when the
   rebuilt binary is byte-identical. Never leave non-matching code in place of the original asm.
2. **Commit each verified unit immediately** (`dk done`), only your own paths, never `git add -A`. A crash then
   loses one function at most.
3. **State in files.** The orchestrator keeps `docs/STATE.md` (template:
   [templates/STATE.md](templates/STATE.md)); every worker keeps a worklog of matches and give-ups with reasons.
   A new session reads those instead of re-deriving anything.
4. **One owner per file.** Parallel workers get disjoint sets of source files; only the integrator runs the
   splitter, renames symbols, edits shared headers or the build.
5. **Fix the toolchain, not the function.** When many functions fail the same way, the cause is almost always a
   compiler flag or an assembler behaviour (see toolchain-forensics). One fix there unblocks hundreds of functions;
   check every fix against all matched functions (`dk all`) before committing it.
6. **Spend tokens where they pay.** Cheap model for the per-function loop, strong model for toolchain forensics;
   near misses go to the permuter (CPU), not to fifteen more manual attempts.
7. **Clean room.** Names and types come from the binary, the game's own data and your analysis; never from leaked
   or copyrighted source code. Never commit game data (ISO, extracted files, generated asm).
