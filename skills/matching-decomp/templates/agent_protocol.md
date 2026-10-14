# Worker protocol

Read this and `docs/decomp_guide.md` (the project's matching rules), then work. You own a set of source files that
nobody else edits while you run. Run every command from the project root.

Your worklog: read only the notes at its top, not the whole file. `grep -n <func> docs/worklog/*.md` gives a
function's history before you retry it.

## Per function

1. Pick: `dk next <your files> --untried [--max-size 0x400]` (smallest first, without what any worklog mentions or
   `nonmatching/` holds). Skip `fragment?` entries.
2. Look: `dk show <func>` (original asm, labels, m2c draft, the source that holds it).
3. Write the code in place of that function's `INCLUDE_ASM` line only; never touch neighbouring lines.
4. Check: `dk try <file> <func>`. Iterate: size, then control flow, then registers and order.
5. Near miss (only registers/order differ after a few tries): save the whole file with your attempt as
   `nonmatching/<func>.<ext>`, `git add` it and commit "near miss: <func>", note it in the worklog, revert, move on.
6. Give up after ~15 tries: `dk revert <file> <func>`; keep prototypes other code needs; log the reason.
7. Commit after each match or few: `dk done <file> docs/worklog/<range>.md "decomp: <file> +N functions"`.

Stop only at the limit your prompt gives (time or matches) or when `dk next <your files> --untried` lists nothing
you have not tried. Running out of easy candidates is not a reason: raise `--max-size`, take twins, retry give-ups
whose reason a toolchain fix has removed.

Before stopping, `git status` must show none of your files modified.

## Never

- `git add -A`, `git push`, `git stash`, `git checkout/reset/restore`, or git on files you do not own.
- Run the splitter or the full build; edit shared headers, build config, scripts, other ranges, generated asm.
- Leave non-matching code; add data the original object did not have; ordinary instructions in inline asm.
- Use leaked or copyrighted source code.
- More than one compile at a time.

## Final report (under 200 words)

Matched count and approximate bytes, commits, patterns that worked, give-ups that look like toolchain problems,
confident name suggestions (address -> name -> evidence). No code.
