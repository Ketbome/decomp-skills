# decomp-skills

**Agent skills for matching decompilation of video games** — rewriting a game's machine code as C/C++ that the
original compiler turns back into the exact same bytes. Works with Claude Code, OpenCode, OpenAI Codex CLI, Gemini
CLI, Cursor, GitHub Copilot and any agent that reads the open [Agent Skills](https://agentskills.io) format.

Built and battle-tested on a real project, [gh3-decomp](https://github.com/Ketbome/gh3-decomp) (Guitar Hero III,
PS2): from zero to ~20% of the game's code matched byte for byte in two days with parallel agents, through rate
limits, crashes and lost sessions — without losing work.

## What you get

- **A method** that agents can follow without supervision: verify every function by byte comparison, commit each
  verified unit at once, keep the project's state in files, one owner per file, fix systemic problems in the
  toolchain instead of function by function.
- **`dk`, the decomp kit** — one Python tool for the whole per-function loop and for recovery:

  | Command | What it does |
  |---|---|
  | `dk show <func>` | original assembly, labels, an [m2c](https://github.com/matt-kempster/m2c) draft, the source file |
  | `dk next <src...> [--untried]` | functions still in `INCLUDE_ASM`, smallest first, flagged (`jtbl`, `vu0:N%`, `fragment?`); `--untried` leaves out what any worklog mentions, so workers need not read long worklogs |
  | `dk check <src> <func>` | compiles privately and compares with the original bytes; relocations compared by symbol, so no link needed and safe in parallel |
  | `dk try` / `dk revert` | pre-check hooks + check / back to `INCLUDE_ASM` |
  | `dk done <src> <log> <msg>` | refuses to commit unless every function of the file matches |
  | `dk all` | checks every written function (run after any toolchain change) |
  | `dk twins` | copies matched functions onto functions with identical assembly: one match yields many |
  | `dk state` | **recovery report**: session state file, uncommitted sources and whether they match, unpushed commits, progress, worklog activity, warnings about stale documents |
  | `dk rescue [--commit]` | **after an interruption**: reverts work in progress that does not match, keeps and commits the rest |
  | `dk docs [--commit]` | regenerates the `<!-- dk:NAME -->` blocks of README & co. (progress tables) from commands |

- **Orchestration of parallel worker agents**: ranges with a single owner, four-line launch prompts backed by a
  protocol file, integration in a separate worktree, resource limits for small machines, when to use a cheap or a
  strong model.
- **Session recovery** built in: `docs/STATE.md`, per-range worklogs, commit-per-match, a resume checklist.
- **A main session that stays fresh**: facts re-read from `dk state` instead of remembered, a Claude Code
  SessionStart hook that loads the state at startup, `/clear` and compaction, restarts at quiet points, generated
  progress numbers, and a checklist that keeps README, `AGENTS.md`, STATE.md and the toolchain notes current.
- **Toolchain forensics**: how to find the compiler flag or assembler behaviour behind a difference that blocks
  hundreds of functions — plus a catalogue of what was found for SN Systems ee-gcc (PS2): one-pass `$gp` vs `lui`
  addressing, inline `li.s`, R5900 short-loop padding, hazard nops, `-fopt-stack`, jump-table reuse, unoptimised
  C libraries, VU0 inline asm, and more.
- **Matching techniques** and a **decomp-permuter** workflow for near misses (CPU instead of tokens).

Focus: MIPS targets (PS1, PS2, N64, PSP) with a [splat](https://github.com/ethteck/splat) layout. The method and
most of `dk` apply to other architectures; relocation-aware comparison is implemented for MIPS.

## Install

### Any agent, one command (recommended)

With the [skills CLI](https://github.com/vercel-labs/skills) ([skills.sh](https://skills.sh)), which knows where
every agent keeps its skills:

```sh
npx skills add Ketbome/decomp-skills              # current project, asks which agents
npx skills add Ketbome/decomp-skills -g           # user level, every project
npx skills add Ketbome/decomp-skills -a claude-code -a codex -a opencode -a cursor -a gemini-cli -y
npx skills update                                 # later: get new versions
```

### Claude Code (plugin)

```
/plugin marketplace add Ketbome/decomp-skills
/plugin install decomp-skills@decomp-skills
```

The skill is then available as `/decomp-skills:matching-decomp` and loads automatically when you work on a decomp.

### Any agent (script)

```sh
curl -fsSL https://raw.githubusercontent.com/Ketbome/decomp-skills/main/install.sh | sh -s -- --all
```

or from a clone (`--link` makes a `git pull` update every agent):

```sh
git clone https://github.com/Ketbome/decomp-skills && cd decomp-skills
./install.sh --all --link                # every agent, user level
./install.sh --claude --codex            # only some
./install.sh --all --project ~/my-decomp # project level, committed with your repo
```

| Agent | User-level folder | Project-level folder |
|---|---|---|
| Claude Code | `~/.claude/skills/` | `.claude/skills/` |
| OpenCode | `~/.config/opencode/skills/` | `.opencode/skills/` |
| OpenAI Codex CLI | `$CODEX_HOME/skills/` (`~/.codex/skills/`) | `.codex/skills/` |
| Gemini CLI | `~/.gemini/skills/` | `.gemini/skills/` |
| Cursor | `~/.cursor/skills/` | `.cursor/skills/` |
| GitHub Copilot (CLI, cloud agent, VS Code) | `~/.copilot/skills/` | `.github/skills/` |
| Shared (Gemini, Cursor, Copilot, OpenCode) | `~/.agents/skills/` | `.agents/skills/` |

Manual install: copy `skills/matching-decomp/` into one of those folders. Restart the agent afterwards.

### The tool in your project

```sh
cp skills/matching-decomp/scripts/dk.py <project>/tools/dk.py
cp skills/matching-decomp/templates/decomp.toml <project>/decomp.toml   # then adapt it
pip install pyelftools tomli
python3 tools/dk.py state
```

## Use

Ask your agent in plain words; the skill triggers on decompilation work:

- "Set up a matching decomp for this PS2 game: split the ELF, find the compiler, get a byte-identical build."
- "Decompile the smallest functions in src/game/t_2001E0.cpp."
- "Run three worker agents on the remaining functions and integrate their work."
- "The session was cut off — recover and continue." (→ `dk state`, `dk rescue`, resume checklist)
- "Integrate this round, update the docs and get ready for a fresh session." (→ orchestration checklist)
- "Many functions fail with an extra nop before div.s; find out why."

## Layout

```
skills/matching-decomp/
  SKILL.md                      entry point (short; links to the references)
  references/recovery.md        resuming after crashes, rate limits, lost context
  references/setup.md           new project: split, rebuild, map, identify the compiler
  references/worker.md          the per-function loop
  references/orchestration.md   parallel workers, integration, resources, models
  references/toolchain-forensics.md   systematic differences; SN ee-gcc/PS2 catalogue
  references/matching.md        steering the compiler
  references/permuter.md        near misses with decomp-permuter
  scripts/dk.py                 the decomp kit
  templates/                    decomp.toml, STATE.md, AGENTS.md, agent_protocol.md, worklog.md,
                                claude-settings.json (SessionStart hook running dk state)
install.sh                      installer for every agent
.claude-plugin/                 Claude Code plugin + marketplace manifests
```

## Principles

- **Clean room.** The skill tells agents never to use leaked or copyrighted source code and never to commit game data.
  Decompilation projects should ship no game assets and require the user's own copy.
- **Verification over trust.** Nothing counts until a byte comparison says so.

## Contributing

Issues and pull requests are welcome: toolchain catalogues for other compilers (IDO, MWCC, Sony ee-gcc 2.96, ...),
relocation support for other architectures in `dk`, and field reports from other decomp projects.

## Licence

MIT. See [LICENSE](LICENSE).
