# <project>

Matching decompilation of <game> (<platform>, <region/serial>). Goal: code that rebuilds `<executable>` byte for
byte. Method: the matching-decomp skill (https://github.com/Ketbome/decomp-skills); `tools/dk.py` is a copy of its
tool.

## Start of every session

1. `dk state` (Claude Code runs it at startup, `/clear` and compaction through `.claude/settings.json`): plan
   (`docs/STATE.md`), commits, uncommitted work, progress, worklog activity, stale documents. Trust it over memory
   and over a compacted summary.
2. If it shows uncommitted sources or a warning, deal with that first (`dk rescue`, `dk docs --commit`).

## Roles

- **Main session = orchestrator.** Plans, launches workers, integrates, fixes the toolchain, keeps the documents
  current. It does not decompile functions itself and does not read assembly, decompiler drafts, diffs, whole
  worklogs or agent transcripts: investigations go to a subagent that reports in under 200 words. Numbers, hashes
  and worker status come from `dk state` or git when they are stated, never from memory.
- **Workers** follow `docs/agent_protocol.md` on the files they own.

## Keeping documents current (orchestrator, every integration round)

- The integration script regenerates the generated blocks (`dk docs --commit`), verifies and pushes.
- `docs/STATE.md`: rewritten whenever the plan changes, committed before the turn ends; no numbers in it.
- This file: when a command, path, flag or convention changes, in the same commit.
- `docs/toolchain.md`: every verified toolchain finding with its evidence. `docs/decomp_guide.md`: a matching
  pattern once two workers report it.
- Quiet point (no worker running, everything integrated, STATE.md committed): clear the context and start fresh.

## Stack

- <splitter, compiler and version, flags, assembler, build tool>; details and evidence: `docs/toolchain.md`

## Commands

`dk` = `python3 tools/dk.py` (configured by `decomp.toml`).

- `<configure command>`: split, write the build file. `<build command>`: build and compare.
- `<integration script>`: `dk docs --commit`, verify HEAD in a separate worktree, push if identical
- `dk state` / `dk rescue [--commit]` / `dk next <files> --untried` / `dk show` / `dk try` / `dk revert` /
  `dk done` / `dk twins` / `dk all` / `dk docs`

## Layout

- `src/`: sources with `INCLUDE_ASM` lines; `config/`: split and symbols; `include/`: headers
- `docs/`: `STATE.md`, `agent_protocol.md`, `decomp_guide.md`, `toolchain.md`, `worklog/<range>.md`
- `nonmatching/`: near misses waiting for the permuter

## Conventions

- Never commit game data (disc image, extracted files, generated assembly, build output).
- Code that does not match stays as `INCLUDE_ASM`. The build must stay byte-identical.
- Clean room: never use leaked or copyrighted source code. Names come from the binary, the game's data and our
  analysis.
