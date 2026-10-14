# The per-function loop (worker)

You own a set of source files; nobody else edits them while you run. Your worklog is `docs/worklog/<range>.md`.
Read the project's decomp guide and the notes at the top of your worklog before starting, not the whole worklog:
`dk next --untried` already leaves out what was tried, and `grep -n <func> docs/worklog/*.md` gives one function's
history when you need it.

## Loop

1. **Pick** — `dk next <your files> --untried [--max-size 0x400]`: smallest first, without the functions any
   worklog mentions or `nonmatching/` holds. Skip anything flagged `fragment?` (pieces of a mis-split function).
   Drop `--untried` only when the focus is retrying give-ups that a toolchain fix unblocked.
2. **Look** — `dk show <func>`: the original assembly (delay-slot instructions indented by one space), labels, an m2c
   draft and the source file that holds the function.
3. **Write** — replace *only* that function's `INCLUDE_ASM(...)` line with code. Never touch neighbouring lines: every
   function of the file must keep its definition or its `INCLUDE_ASM` line, in address order. Use the project's
   conventions for names, linkage (`extern "C"` in C++ projects), declarations and local structs.
4. **Check** — `dk try <file> <func>`. Read the diff: size first (missing/extra code), then control flow, then
   register choice and order. Iterate.
5. **Near miss** — only registers or instruction order differ after a few honest tries: save the whole file with
   your attempt as `nonmatching/<func>.<ext>`, commit it ("near miss: <func>"), log it, revert, move on. The
   permuter will search for you (permuter.md).
6. **Give up** after ~15 attempts: `dk revert <file> <func>`, keep any prototype other code in the file still needs,
   log the function with one line on why.
7. **Twins** — `dk twins <your files>` copies every matched function onto functions with identical assembly
   (renaming symbols, copying local types) and keeps what matches. Run it after matching anything; when choosing
   what to work on, prefer a function that has identical siblings (`dk twins --list`).
8. **Commit** after each match or few: `dk done <file> docs/worklog/<range>.md "decomp: <file> +N functions"`. It
   refuses to commit unless every function of the file matches and the file compiles.

Before stopping: `git status` shows none of your files modified; your final report lists matched count and bytes,
commits, patterns that worked, give-ups that look like toolchain problems, and name suggestions with evidence.

## Never

- `git add -A`, `git push`, `git stash`, `git checkout/reset/restore`, or git on files you do not own.
- Run the splitter or the full build; edit shared headers, build config, scripts, other ranges, generated asm.
- Leave a non-matching function in place of its `INCLUDE_ASM` line.
- Add data the original object did not have (string literals, statics, float constants placed in a literal pool)
  unless the project has migrated that object's data.
- Write ordinary instructions in inline asm to force the compiler's hand. Instructions the compiler cannot emit
  (vector units, coprocessor ops) are the exception: the original was written that way too.
- Use leaked or copyrighted source code.
- Run several compiles at once on a small machine.

## Reading a diff efficiently

- **Size differs**: a statement is missing or extra; a loop is unrolled or not; a branch was merged.
- **Same instructions, other registers**: declaration order, a temporary, signedness or width of a type, reusing a
  variable, the order of arguments in a prototype, a callee declared `int` vs `void`.
- **Same registers, other order**: statement order, `a = b = 0` chains, splitting an expression into statements.
- **Branch shapes**: `if/else` vs early return vs `?:`, `do/while` vs `for`, comparison direction (`!=` first),
  `switch` vs `if` chains.
- A difference that repeats across many functions is not yours to fix: report it (toolchain-forensics.md).
