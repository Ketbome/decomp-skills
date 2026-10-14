# Changelog

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
