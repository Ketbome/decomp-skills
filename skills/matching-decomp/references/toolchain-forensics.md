# Toolchain forensics

When the same kind of difference appears in many functions, the C is rarely the problem: the build differs from the
original toolchain somewhere (a flag, the assembler, the linker). Finding it is the highest-leverage work in a
decomp: one fix routinely unblocks hundreds of functions. Do it with a strong model and real evidence.

## Method

1. **Collect.** Read the workers' give-ups and group them by symptom ("extra nop before X", "register saved as 128
   bits", "global reached through $gp in one place and lui/lw in another").
2. **Measure in the original.** Scan all per-function `.s` files for the pattern and count it: how often, in which
   contexts, with which neighbours. A rule that holds in 418 of 700 cases with clear exceptions is a real rule; look
   at the exceptions to find the condition.
3. **Reproduce with the vendor's own tools.** Even an older assembler shipped with the compiler can show the
   rule (in gh3-decomp it showed which instructions SN's assembler moves into delay slots).
   **With the compiler alone:** Compile a minimal C snippet and read the compiler's assembly output (`-S`).
   If the compiler already emits the pattern, it is a flag or source shape; if not, it is the assembler or linker.
   Other builds of the vendor's compiler (other versions, Docker images) and the vendor libraries linked into the
   game tell you which tool introduced it.
4. **Search the compiler for options.** Vendor builds have private options (`strings` on the compiler binaries and
   look near the help texts): one of them may be exactly the difference.
5. **Fix in one place**: a global flag, a per-file flag, an assembler prelude macro, or a filter that rewrites the
   compiler's assembly before the modern assembler sees it.
   A fix that changes code generation can break a matched function whose C relied on the old behaviour (a trick that
   only worked because gas filled a slot): revert that one to asm with its C kept as a near miss, rather than
   rejecting a fix that unblocks many.
6. **No rule to find?** When the original assembler is not available and the pattern depends on context you cannot
   reconstruct (identical instruction sequences get different treatment; a classifier on the neighbouring
   instructions barely beats always-the-majority), copy the value per occurrence from the original, as for jump
   tables: the k-th occurrence in a function gets what the k-th one has in its original `.s`. Document it as
   inferred, not derived.
7. **Prove it.** `dk all` before and after: no matched function may break. Then a worker retries the give-ups.
   `dk all` does not run the `pre_check` hooks: if the fix changes what a hook writes into sources (e.g. which
   small-data declarations are needed), run that hook over every source first and commit its output with the fix,
   or the integration build breaks on files nobody is editing.
8. **Document** the rule, the evidence and the numbers in `docs/toolchain.md`; leave open questions there too.

## Catalogue: SN Systems ee-gcc 2.95.3 (PS2) and the modern GNU assembler

Found in the Guitar Hero III PS2 decomp; most apply to any SN/Sony PS2 game, and the patterns (one-pass assembler,
hazard nops, errata workarounds) recur on other consoles.

| Symptom in the original | Cause | Fix |
|---|---|---|
| Saved `$s` registers stored with `sd` below `$ra`, ours with `sq` above | SN option | `-fopt-stack` |
| No `break 7` after divisions | | `-mno-check-zero-division` |
| Some loops only match unrolled; lone `nop` 8-aligning a label with no loop in sight | object built with unrolling (head of a fully unrolled loop) | per-file `-funroll-loops` |
| `min.s`/`max.s` | | per-file `-ffast-math` |
| Frame pointer everywhere, empty delay slots, extra jumps | unoptimised C library | own file compiled as C, `-O0 -fno-opt-stack`, assembler also `-O0` (no delay-slot filling) |
| Float constant built inline `lui/ori/mtc1`, ours from `.lit4` | SN assembler expanded `li.s` inline | filter rewrites `li.s` |
| Same global via `lui/%lo` outside delay slots and `%gp_rel` inside them | ee-gcc writes `.extern sym,size` at the end of the file and SN's assembler is one-pass: size unknown until then, except in a delay slot (`nomacro`) where only `%gp_rel` fits | filter expands macro loads/stores/`la` that way; data the object defines itself is known early (`GP_DATA(sym)` marker, emitted as an early `.extern`) |
| Short loops padded with nops to 6 instructions | R5900 short-loop erratum workaround in SN's assembler | filter pads loops of < 6 instructions (head label to delay slot) before the backward branch; outside `noreorder` write the delay slot out |
| No nop after `mfc1` (but nops after `mtc1` and between `c.*.s` and `bc1t/f`) | modern gas inserts MIPS III hazard nops | prelude wraps `mfc1` to make gas forget the hazard |
| `sqrt.s` operand in the `ft` field | R5900 encoding | prelude macro emits the word |
| `usd` stored `sdr` then `sdl` | | filter writes them out in that order |
| `move` is `daddu` | 64-bit moves | prelude macro |
| 8+ bytes of zero padding after some functions | end of an original object file (linker aligned objects to 16) | `TEXT_PAD(n)` after the function |
| A global reached with `lui/%lo` after an earlier `GP_DATA` makes ours `%gp_rel` | the one-pass assembler forgot known sizes at the next original object; a source file merges several objects, some ending on a 16-byte boundary with no padding left | `TEXT_PAD` and an `OBJECT_END()` marker reset the known sizes in the filter and in the hook that writes `GP_DATA` |
| Conditional moves (`movz`/`movn`) where the original branches; `move` copies the original keeps before loops | not the toolchain: GCC 2.9x if-converts only values in registers, and hoists loop invariants the source recomputes | C shape (matching.md) |
| `switch` jump table | the table lives in the game's rodata | filter drops the compiler's table and points the code at the original `jtbl_` symbol; configure defines the case labels |
| 0 or 2 nops before `div.s`, no rule (418 of ~700 have 2; identical sequences get either) | SN's later assembler, not available; ee-gcc and the shipped `as` emit none, Sony's ee-gcc 2.96/3.2 always 2 | filter gives the k-th `div.s` of a function the nop count of the k-th in its original `.s`, inside `.set noreorder` (inline-asm `div.s` untouched) |
| A `nop` delay slot after a volatile store or `cvt.s.w`; ours moves that instruction into the slot | SN's assembler fills slots only with COP2 instructions (`lqc2`, `sqc2`, `qmfc2`, `qmtc2`, `v*`); the modern gas moves anything it can (verified with the compiler's own `as`) | filter puts a local label right before each branch whose previous instruction is not COP2 (gas does not move across a label); `gas -O1` instead breaks VU0 inline asm |
| Hazard nop after `mtc1 $fN` placed after the next label (when `$fN` is read right after it), ours before | SN's assembler | filter writes the nop after the label inside `noreorder` |
| `$s` saved with `sq` in ascending slots, `$ra` with `sd` | the registers hold 128-bit values | source uses a 128-bit type (`mode(TI)`), not a toolchain gap |
| VU0 instructions in normal functions | inline asm in the original | write them as `asm()` with the `$vfN` registers spelled out |
| `lqc2`/`sqc2` in branch-likely delay slots or scheduled among ordinary code | gcc allocated the VU0 register (`register TI v asm("vf1")`, constraint `"j"`); an asm is never put in a slot | that source shape; ee-gcc writes `vf1` without `$`, so the filter adds it |
| Branch-likely vs plain branch with the slot filled | not the toolchain (22 flag variants, five compiler builds agree): reorg's register-liveness view | C shape or permuter |

Hooks that find a function's original assembly by its name (padding, small-data markers) must resolve a definition
under an alias (`f_s(...) __asm__("f")`) to `f`: one that did not skipped a `TEXT_PAD`, every function still matched,
and only the full-build comparison caught the 16 missing bytes.

Open in that project at the time of writing: 26 functions saving `$ra` with `sq`, 58 functions hidden behind 16 bytes
of `addiu $sp,+X; nop` pairs.

The reference implementation of these fixes (CC0) is in
[Ketbome/gh3-decomp](https://github.com/Ketbome/gh3-decomp): `scripts/asm_filter.py`, `include/gcc_prelude.inc`,
`configure.py`, `docs/toolchain.md`.
