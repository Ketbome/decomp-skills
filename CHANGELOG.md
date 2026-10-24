# Changelog

## 1.7.5 — 2026-10-24

- matching.md: a comparison against a constant that only appears after inlining (`Ge(x, 0)`) keeps the generic
  sequence the original has (`slti; xori` instead of `nor; srl` for `x >= 0`).
- `dk <command> --help` prints that command's usage (it used to take `--help` for a file name and crash).
- `dk next --min-size N`: list only functions of at least N bytes (a round focused on large functions).

## 1.7.4 — 2026-10-23

- `dk revert` finds functions defined under an alias (`f_s(...) asm("f")`) and says when it finds nothing; it no
  longer takes a multi-line prototype for a definition.
- `dk done` refuses to commit when a function the committed file had is now neither written nor INCLUDE_ASM (a
  worker lost such a line twice; only the full build would have shown it).
- Functions defined under an alias or with K&R parameter lists are now checked by `dk done`/`dk all` (GH3: 118
  alias and 97 K&R definitions had been skipped; all match).

## 1.7.3 — 2026-10-23

- Toolchain catalogue: gas flushes a pending `mtc1` hazard nop at `.p2align`; apparent short-loop padding misses
  that are really per-object unrolling.

## 1.7.2 — 2026-10-20

- Toolchain catalogue: small-data sizes reset at original object ends (`OBJECT_END()` marker); conditional moves and
  kept register copies are C shape; hooks must resolve alias-defined functions (a skipped `TEXT_PAD` showed only in
  the full build).

## 1.7.1 — 2026-10-20

- Matching notes: register copies the original keeps come from a loop invariant the source recomputes (not a flag);
  GCC 2.95 ignores local register pins unless the variable feeds an asm statement.

## 1.7.0 — 2026-10-20

- `dk protos <src> <func>`: redeclares each function <func> calls with the other return type (void <-> int) through
  `__asm__` aliases used only by <func>, one and two at a time, and writes a combination that matches. In GH3 a
  worker's ad-hoc version of this sweep matched 4 near misses in one pass; worker protocol and worker.md run it
  before saving a near miss.

## 1.6.8 — 2026-10-19

- Forensics: a fix that changes what a `pre_check` hook writes must be followed by that hook over every source
  before `dk all` (dk all does not run hooks; an integration build broke on 28 functions of an unowned file).

## 1.6.7 — 2026-10-19

- Matching notes: conditional moves where the original branches are C shape on GCC 2.9x (write the value through a
  reference parameter of an inline helper); count the original's conditional moves before blaming a flag.
- Orchestration: early stops as a yield signal; size windows read as ceilings; stale toolchain notes in worklogs.

## 1.6.6 — 2026-10-19

- Worker protocol: keep the round's match/attempt count as a line in the worklog, updated on each commit. A worker
  stopped at 14/40 of a 25/60 limit because it lost the count when its context was compacted.

## 1.6.5 — 2026-10-19

- `dk twins`: when a symbol the twin uses is declared with other types in the target file, declare the twin's
  version under an `__asm__("sym")` alias instead of giving up (3 of 4 such twins in GH3 now match automatically;
  they had been written by hand). A function whose own return type differs is still skipped.
- Matching notes: m2c's extra arguments on virtual and constructor calls.

## 1.6.4 — 2026-10-19

- Launch prompt template: exact limits stated as "stop ONLY at", and the stop rule repeated in the prompt (a
  worker kept stopping early with only the protocol file saying it); per-worker scratch folder outside the repo.

## 1.6.3 — 2026-10-14

- Toolchain catalogue: gcc-allocated VU0 registers (`register ... asm("vf1")`, `"j"`) and their `$` spelling;
  branch-likely choices are C shape, not toolchain. Measured effect of countable worker limits.

## 1.6.2 — 2026-10-14

- `dk state` no longer crashes when generated blocks are stale (paths joined as strings).
- Worker limits in countable units (matches and functions attempted), not hours: workers stopped after 25-50
  minutes of a "~3 hours" limit.

## 1.6.1 — 2026-10-14

- Toolchain catalogue: SN's assembler fills delay slots only with COP2 instructions, and puts an `mtc1` hazard nop
  after the next label; the fix for each. Forensics: test the vendor's own assembler; a fix that breaks a matched
  function that relied on the old behaviour is still worth it (revert that one, keep its C as a near miss).

## 1.6.0 — 2026-10-14

- The file check (`dk check`, `dk try`, `dk done`) fails when the object lays out functions in another order than
  the original addresses (e.g. an `__asm__`-aliased definition placed after a later function): each function
  matched on its own, but the linked image shifted.

## 1.5.2 — 2026-10-14

- Push only through the integration check, docs and tool commits included (orchestration.md).
- Workers stop only at their limit or when `dk next --untried` is empty (worker.md, agent_protocol template): a
  whole round stopped early "for lack of viable candidates" with thousands untried.

## 1.5.1 — 2026-10-14

- `dk twins`: declares every symbol the copied body uses (not only renamed ones), reads one-line structs, forward
  declarations and attributed typedefs, rebinds parameters by cast when the target file already prototypes the
  function with other types, adapts scalar/array uses of one global, and every skip names what is missing or which
  declarations conflict (it used to skip silently).

## 1.5.0 — 2026-10-14

- Toolchain forensics: when no rule can be found (original assembler unavailable, context-dependent pattern), copy
  the value per occurrence from the original `.s`, documented as inferred; the SN `div.s` nops as the worked case
  (catalogue row), and other vendor compiler builds as a way to find which tool adds a pattern.
- Permuter: its input is the near-miss copy; keep prototypes of the same file's other functions in `base.c`;
  measured cost of a batch beside running workers.
- Orchestration: runner prompts copy the script's usage line and say what to do on an error; a clean `dk all` with
  a differing image means stale generated files; fix a failure that recurs across reports in the tool, the docs or
  this skill once.

## 1.4.0 — 2026-10-14

- Codex and OpenCode get what Claude Code has: session-start state (`templates/codex/hooks.json`, SessionStart hook;
  `templates/opencode/plugins/dk-state.js`, system prompt per main session, refreshed after compaction) and the
  three role subagents with their model and effort (`templates/codex/agents/*.toml`,
  `templates/opencode/agents/*.md`).
- How to delegate per agent (orchestration.md); AGENTS.md template asks for delegation explicitly (Codex only
  spawns subagents when asked).
- Install notes: OpenCode already reads `~/.claude/skills`; Codex reads `~/.codex/skills` and `~/.agents/skills`.

## 1.3.0 — 2026-10-14

- Choosing models and effort (orchestration.md): which model and effort per task (mid-size workers, small model
  for mechanical runs, strong model with high effort for toolchain forensics), when to escalate and de-escalate,
  how to delegate (one task per agent, short prompts, report limits, owners in STATE.md).
- Templates for Claude Code subagents (`templates/claude-agents/`): `decomp-worker` (sonnet), `decomp-forensics`
  (opus, effort high), `decomp-runner` (haiku, effort low).

## 1.2.0 — 2026-10-14

- Keep the main session fresh: facts from `dk state`, not memory; subagents read code, the orchestrator reads
  reports; decisions committed to files; restarts at quiet points; a checklist that keeps README, `AGENTS.md`,
  STATE.md, toolchain notes and the guide current every integration round (orchestration.md).
- `dk docs [--commit]`: regenerates `<!-- dk:NAME -->` blocks (progress tables) from commands (`[docs]` in
  decomp.toml). STATE.md holds no numbers any more.
- `dk state`: when each worklog was last committed, how old STATE.md is, warnings for stale generated blocks and
  long worklogs.
- `dk next --untried`: leaves out functions any worklog mentions or `nonmatching/` holds; workers read only the
  notes at the top of their worklog.
- Templates: `AGENTS.md` (one instructions file for every agent), `claude-settings.json` (SessionStart hook that
  runs `dk state` at startup, resume, `/clear` and compaction); worklog notes header.

## 1.1.0 — 2026-10-14

- `dk twins`: decompile functions whose assembly is identical to an already matched one (symbols renamed, local
  types copied, only matches kept).
- Permuter: C++ sources via `PERM_IGNORE`/`PERM_PRETEND`; how to finish a near miss from the permuter's output.
- Install with `npx skills add Ketbome/decomp-skills`.

## 1.0.0 — 2026-10-13

- `matching-decomp` skill: method, worker loop, orchestration of parallel agents, session recovery, toolchain
  forensics (with the SN Systems ee-gcc / PS2 catalogue), matching techniques, permuter workflow.
- `dk` (decomp kit): show, next, check, try, revert, done, all, state, rescue — configured by `decomp.toml`.
  Validated against the Guitar Hero III PS2 decomp (5,540 of 5,541 matched functions agree with its own checker).
- Templates: decomp.toml, STATE.md, worker protocol, worklog.
- Installer for Claude Code, OpenCode, Codex CLI, Gemini CLI, Cursor, GitHub Copilot and `~/.agents/skills`;
  Claude Code plugin marketplace.
