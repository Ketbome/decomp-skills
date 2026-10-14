# Orchestrating parallel workers

The orchestrator (integrator) does not decompile much itself. It splits the work, launches workers, integrates and
verifies, fixes the toolchain when workers hit systematic problems, and keeps `docs/STATE.md` current.

## Keep the main session fresh

The main session lives for hours and is compacted or cleared along the way; a summary of a summary invents
details. It stays reliable when its context holds decisions, not data:

- **Ground truth from tools, not memory.** Before stating a percentage, a commit, a count or whether a worker is
  running, run `dk state` (or git). After a compaction, treat the summary as unverified until `dk state` agrees.
- **Read little.** No assembly, decompiler drafts, diffs, whole worklogs or agent transcripts in the main session.
  An investigation (why do 40 functions fail the same way?) goes to a subagent that reports in under 200 words;
  workers report in under 200 words. Read `dk state` and those reports.
- **Decisions go to files at once.** A plan change, a finding or a new rule is written to STATE.md, the toolchain
  notes or AGENTS.md and committed before the turn ends, never kept only in the conversation.
- **Restart at quiet points.** After an integration round (no worker running, everything integrated, STATE.md
  committed), clear the context (`/clear` in Claude Code) or open a new session. Nothing is lost: everything is in
  files. Avoid clearing while background workers run; their reports would arrive to a session that does not know
  them (their work is safe in commits and worklogs).
- **Load the state automatically** at startup, resume, clear and compaction:
  - Claude Code: SessionStart hook, templates/claude-settings.json → `.claude/settings.json`.
  - Codex: SessionStart hook, templates/codex/hooks.json → `.codex/hooks.json` (the project must be trusted and
    the hook approved once in Codex's hook review).
  - OpenCode: plugin, templates/opencode/plugins/dk-state.js → `.opencode/plugins/` (puts `dk state` in the system
    prompt of each main session, again after a compaction; subagents skip it).
  - Any other agent: `AGENTS.md` starts with "run `dk state` first".

## Keep the documents current

Every integration round, before restarting:

| Document | Who updates it | When |
|---|---|---|
| README progress table | `dk docs --commit` (run by the integration script) | every integration |
| `docs/STATE.md` | orchestrator, by hand, no numbers | whenever the plan changes |
| `AGENTS.md` | orchestrator | a command, path, flag or convention changed (same commit) |
| `docs/toolchain.md` | orchestrator | a toolchain finding is verified (with evidence) |
| `docs/decomp_guide.md` | orchestrator | a matching pattern appears in two worker reports |
| worklog notes (top of each worklog) | orchestrator trims, workers append below | a blocker is fixed or found |
| the skill itself (upstream) | orchestrator | a lesson that is not specific to this game |

`dk state` warns about generated blocks that are out of date, long worklogs and how old STATE.md is.

## Split the work

- Partition the source files into disjoint **ranges** (e.g. thirds of the code address space). One worker per range;
  a range has exactly one owner at any time. Write the owner into STATE.md.
- Give the project a short **worker protocol file** (copy `templates/agent_protocol.md` to `docs/agent_protocol.md`
  and adapt it). Then a launch prompt is four lines, not forty:

  ```
  Matching decompilation of <game> in <path>. Read docs/agent_protocol.md and docs/decomp_guide.md, then follow the
  protocol exactly. Your files: <first> .. <last> (`ls src | sort` order), range "<X>". Worklog: docs/worklog/<X>.md
  (read its notes). Scratch folder: <name>. Priority: <what>. Stop after ~N matches or ~M tries, then report.
  ```

- Give each round a **focus** that changes as the project matures: smallest functions first; then the class a
  toolchain fix just unblocked (retry its give-ups first); then mid-size functions nobody tried; then special
  classes (switch tables, vector code, unoptimised objects).

## Resources

- Workers are independent processes that each compile code: on a 16 GB machine, three at a time is a safe ceiling;
  build with limited parallelism (`ninja -j4`). One compile/check at a time per worker.
- When the per-round yield drops (few matches per hundred tried), change the focus or fix the toolchain: do not just
  relaunch the same worker.

## Choosing models and effort

The main session (a strong model) decides and integrates; it delegates every task that reads code or runs long.
Pick the cheapest model that does the task at full yield, and escalate only on evidence.

| Task | Model | Effort | Why |
|---|---|---|---|
| Per-function loop (worker, a range of files) | mid-size (Sonnet) | default | matches as many functions per hour as a large model, at a fraction of the cost |
| Mechanical runs: permuter batch + apply, `dk twins`, applying a names list, a census (`grep`/`dk next` counts), docs from given facts | small (Haiku) | low | follows commands, reports numbers; no judgement involved |
| Surveys of code or asm ("which functions share this shape?", classify fragments) | small or mid (Explore agent) | default | reads a lot, returns a short list; keeps that reading out of the main session |
| Toolchain forensics: a difference repeated across many functions, assembler/compiler behaviour, flags | strong (Opus) | high / max | one hypothesis-and-experiment chain that unblocks hundreds of functions; worth the tokens |
| Hard single functions with high value (large, many twins or callers) after a mid worker and the permuter failed | strong | high | bounded: one attempt of ~20 tries, then back to the give-up list |
| Integration failure (build not identical, an address moved) | main session or strong | default | needs the whole picture; rare |
| Orchestration, plans, skill and doc updates | main session | default | judgement, few tokens if it reads little |

Escalate when:
- two or more workers (or one worker on three or more functions) report the same difference: open a strong-model
  forensics task, with no worker editing the files it experiments on (it works in a scratch copy);
- a mid worker's round yields far below the previous rounds on the same kind of functions: look at the give-up
  reasons first; if they share a cause, it is forensics, not more workers.

De-escalate when a strong-model task turns out to be a recipe ("declare X as a struct, return the value"): write it
in the project's decomp guide and hand the class of functions to mid-size workers.

### How to delegate

- One task per agent, a short prompt that points at files (protocol, worklog, the evidence) instead of pasting
  them, and a report limit (under 200 words, no code). The agent works in the background; the main session waits
  for its report and does not read its transcript.
- Never two agents on the same files; write the owner and model into STATE.md.
- Give a worker a limit it can count, e.g. "25 matches or 60 functions attempted", not hours: agents do not track
  time. In gh3-decomp "~3 hours" got 9-16 matches per worker; the countable limit got 21-25 in the next round.
- A runner does exactly what it is told: copy the command from the script's own usage line (wrong arguments cost a
  round trip) and say what to do on an error (record it and go on to the next item).
- Define the three roles once per agent, with the same instructions (`decomp-worker`, `decomp-forensics`,
  `decomp-runner`):

  | Agent | Templates → project | Model and effort | Launch |
  |---|---|---|---|
  | Claude Code | claude-agents/ → `.claude/agents/` | `model: sonnet / opus / haiku`, `effort: high / low` in the frontmatter | Agent tool by `subagent_type`; its `model` parameter overrides one run |
  | Codex | codex/agents/ → `.codex/agents/*.toml` | `model_reasoning_effort` (`medium / xhigh / low`); `model` inherits the session's unless pinned | the main agent spawns them by role (`agent_type`); `model`/`reasoning_effort` can be overridden per spawn |
  | OpenCode | opencode/agents/ → `.opencode/agents/*.md` | `mode: subagent`; `model: <provider>/<model>` per role (omitted = the session's) | task/subagent tool by agent name, or `@decomp-worker` |
  | others | — | a separate agent process with the model from the table above | same four-line prompt and report limit |

  Codex spawns subagents only when the user, `AGENTS.md` or a skill asks for delegation: the project's `AGENTS.md`
  says so explicitly (the template does).

## Integrate

1. `dk rescue` if workers were interrupted; `dk docs --commit` so the published numbers are current.
2. Run the full build on the committed HEAD in a separate git worktree (generated files of running workers stay
   untouched): split → (re-add missing `INCLUDE_ASM` lines) → build → compare. Push only if byte-identical.
   Push only through that check, even a docs or tool commit: `git push` sends every worker commit since the last
   verified one too (in gh3-decomp a plain push of a script fix published a tree that did not rebuild). A script
   for this (`scripts/integrate.sh` in the reference project) makes it one command.
3. If it fails, find the first function whose address moved (compare symbol addresses of the rebuilt ELF with the
   original), not the first differing byte: the cause is usually a missing padding, a missing data declaration or a
   function that grew. If `dk all` reports every function matching but the image differs (even in size), regenerate
   first (configure / split): a stale `asm/` or `build/` left by an earlier run made the reference project's
   image 1760 bytes short, and reconfiguring fixed it.
4. Update STATE.md and the other documents (table above), commit, then restart the main session if it is a quiet
   point.

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
- The same failure in several reports (a tool command that fails, workers hand-rolling what a tool should do, the
  same give-up reason in many worklogs): fix the tool or the docs once, in the project and, when it is not specific
  to the game, in this skill, instead of working around it in every prompt.
- A function deleted by accident while editing (a slice replace that swallowed a neighbour): the integration build
  catches it; make the configure step re-add missing `INCLUDE_ASM` lines so the published tree always builds.
