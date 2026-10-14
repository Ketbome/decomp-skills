# Recovering an interrupted session

Sessions end without warning: rate limits, crashes, out-of-memory, `/clear`, a laptop lid. The project must be
resumable by someone who remembers nothing. Everything below assumes the rules of SKILL.md were followed (commit per
verified unit, state in files); then recovery takes minutes and loses at most the function that was in progress.

## Resume checklist (do this first, every time)

1. **Read the state.** `dk state` prints `docs/STATE.md`, the last commits, unpushed commits, every uncommitted source
   file with how many of its functions match, progress, when each worklog was last committed, and warnings (stale
   generated blocks, long worklogs). With the Claude Code hook (templates/claude-settings.json) it is already in
   context. It is the truth; a compacted summary or your memory of the last session is not.
2. **Make sure nobody else is still running.** A worker you believe dead may still be editing (background agents can
   outlive the session that started them, or resume after a rate-limit reset). If unsure, stop them or wait; two
   writers on one file lose work.
3. **Rescue.** `dk rescue` checks every modified source: functions that do not match and were `INCLUDE_ASM` at HEAD
   are put back (work in progress), the rest stays; files where everything matches are ready to commit
   (`dk rescue --commit`). A function reported as "STILL DIFFERS (was C++ at HEAD)" means something else changed
   (a header, a flag, the toolchain): investigate before reverting anything.
   - A revert can remove the only prototype of a function that other code in the file calls: the file then fails to
     compile. Put the prototype back in the file's declaration block.
4. **Integrate.** Run the full build on the committed HEAD (preferably in a separate worktree so running workers'
   generated files are untouched) and push only if it is byte-identical. See orchestration.md.
5. **Update `docs/STATE.md`** and relaunch workers from their worklogs.

## docs/STATE.md

The orchestrator rewrites it whenever the plan changes (template: `templates/STATE.md`). Keep it short and current:

- no progress figures or commit hashes: `dk state` computes them, and typed numbers go stale (a README that said
  0.19% when the project was at 22% is how this rule was learnt);
- who works on what (ranges / files, model, started when, worklog path);
- pending integrator tasks (names to apply, toolchain fixes waiting for a quiet moment, files to split);
- open toolchain questions (with the evidence gathered so far);
- the exact next step.

## Worklogs (one per worker range)

Per file: functions matched, functions given up with **one line on why** (so nobody retries blindly), near misses
saved for the permuter, patterns that worked. A worker reads its worklog before starting; the integrator reads all
of them when looking for systematic problems.

## Cheap habits that make recovery trivial

- Commit after every match or every few (`dk done` does the checking).
- Never keep progress only in a conversation: plans, findings and decisions go into STATE.md, the worklogs or the
  project docs before the turn ends.
- Restart the main session at quiet points (orchestration.md, "Keep the main session fresh") instead of letting it
  compact again and again.
- After a toolchain change, re-run `dk all` and note the result in STATE.md.
- When a rate limit is near, stop workers deliberately (they commit as they go), rescue, integrate, update STATE.md.
- Long runs on a small machine: limit parallelism (e.g. 3 workers, build with `-j4`, one compile per worker at a
  time); a crash from memory pressure costs more than the parallelism gains.
