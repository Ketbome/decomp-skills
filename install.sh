#!/bin/sh
# Installs the decomp skills into the skill folders of AI coding agents.
#
#   ./install.sh [targets...] [--project DIR] [--link] [--uninstall]
#   curl -fsSL https://raw.githubusercontent.com/Ketbome/decomp-skills/main/install.sh | sh -s -- --all
#
# Targets (default: --all of the user-level ones that exist on this machine, plus ~/.agents):
#   --claude    Claude Code        ~/.claude/skills            project: .claude/skills
#   --opencode  OpenCode           ~/.config/opencode/skills   project: .opencode/skills
#   --codex     OpenAI Codex CLI   $CODEX_HOME/skills (~/.codex/skills)   project: .codex/skills
#   --gemini    Gemini CLI         ~/.gemini/skills            project: .gemini/skills
#   --cursor    Cursor             ~/.cursor/skills            project: .cursor/skills
#   --copilot   GitHub Copilot     ~/.copilot/skills           project: .github/skills
#   --agents    shared location    ~/.agents/skills            project: .agents/skills
#               (read by Gemini CLI, Cursor, Copilot and OpenCode)
#   --all       every target above
#
#   --project DIR  install into DIR's project-level folders instead of your home
#   --link         symlink instead of copying (a `git pull` in this repo then updates every agent)
#   --uninstall    remove the skills from the selected targets
set -eu

REPO_URL="https://github.com/Ketbome/decomp-skills"
SKILLS="matching-decomp"

here=$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")
if [ -z "$here" ] || [ ! -d "$here/skills" ]; then
    # piped through curl: fetch the repository first
    tmp=$(mktemp -d)
    git clone -q --depth 1 "$REPO_URL" "$tmp/decomp-skills"
    here="$tmp/decomp-skills"
fi

targets=""
project=""
mode=copy
action=install
while [ $# -gt 0 ]; do
    case "$1" in
        --claude|--opencode|--codex|--gemini|--cursor|--copilot|--agents) targets="$targets ${1#--}" ;;
        --all) targets="claude opencode codex gemini cursor copilot agents" ;;
        --project) project=$2; shift ;;
        --link) mode=link ;;
        --uninstall) action=uninstall ;;
        -h|--help) sed -n '2,24p' "$0" 2>/dev/null || true; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

if [ -z "$targets" ]; then
    targets="agents"
    [ -d "$HOME/.claude" ] && targets="$targets claude"
    [ -d "$HOME/.config/opencode" ] && targets="$targets opencode"
    [ -d "${CODEX_HOME:-$HOME/.codex}" ] && targets="$targets codex"
    [ -d "$HOME/.gemini" ] && targets="$targets gemini"
    [ -d "$HOME/.cursor" ] && targets="$targets cursor"
    [ -d "$HOME/.copilot" ] && targets="$targets copilot"
fi

dir_for() {
    if [ -n "$project" ]; then
        case "$1" in
            claude) echo "$project/.claude/skills" ;;
            opencode) echo "$project/.opencode/skills" ;;
            codex) echo "$project/.codex/skills" ;;
            gemini) echo "$project/.gemini/skills" ;;
            cursor) echo "$project/.cursor/skills" ;;
            copilot) echo "$project/.github/skills" ;;
            agents) echo "$project/.agents/skills" ;;
        esac
    else
        case "$1" in
            claude) echo "$HOME/.claude/skills" ;;
            opencode) echo "$HOME/.config/opencode/skills" ;;
            codex) echo "${CODEX_HOME:-$HOME/.codex}/skills" ;;
            gemini) echo "$HOME/.gemini/skills" ;;
            cursor) echo "$HOME/.cursor/skills" ;;
            copilot) echo "$HOME/.copilot/skills" ;;
            agents) echo "$HOME/.agents/skills" ;;
        esac
    fi
}

for t in $targets; do
    dest=$(dir_for "$t")
    for s in $SKILLS; do
        if [ "$action" = uninstall ]; then
            rm -rf "${dest:?}/$s" && echo "removed  $t: $dest/$s"
            continue
        fi
        mkdir -p "$dest"
        rm -rf "${dest:?}/$s"
        if [ "$mode" = link ]; then
            ln -s "$here/skills/$s" "$dest/$s"
        else
            cp -R "$here/skills/$s" "$dest/$s"
        fi
        echo "installed $t: $dest/$s ($mode)"
    done
done

[ "$action" = install ] && echo "Done. Restart your agent (or open a new session) so it discovers the skill."
