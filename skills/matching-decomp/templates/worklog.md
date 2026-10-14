# Worklog: range <X>

Files: `<first>` .. `<last>`. Kept by the worker of this range.

Notes (read by every worker before starting; keep under ~40 lines, the orchestrator curates them):
- <what works in this range, what is blocked and why, which give-ups a toolchain fix made worth a retry>

## Session <N> (YYYY-MM-DD, <model>)

### <file>
- Matched: func_..., func_...
- Near miss (nonmatching/): func_... — only `$v0/$v1` swapped in the loop
- Given up: func_... — <one line: why>

### Patterns that worked
- <pattern> (<function where it helped>)

### Looks like a toolchain problem
- <symptom> in func_..., func_...
