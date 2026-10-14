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
3. **Reproduce with the compiler alone.** Compile a minimal C snippet and read the compiler's assembly output (`-S`).
   If the compiler already emits the pattern, it is a flag or source shape; if not, it is the assembler or linker.
4. **Search the compiler for options.** Vendor builds have private options (`strings` on the compiler binaries and
   look near the help texts): one of them may be exactly the difference.
5. **Fix in one place**: a global flag, a per-file flag, an assembler prelude macro, or a filter that rewrites the
   compiler's assembly before the modern assembler sees it.
6. **Prove it.** `dk all` before and after: no matched function may break. Then a worker retries the give-ups.
7. **Document** the rule, the evidence and the numbers in `docs/toolchain.md`; leave open questions there too.

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
| `switch` jump table | the table lives in the game's rodata | filter drops the compiler's table and points the code at the original `jtbl_` symbol; configure defines the case labels |
| `$s` saved with `sq` in ascending slots, `$ra` with `sd` | the registers hold 128-bit values | source uses a 128-bit type (`mode(TI)`), not a toolchain gap |
| VU0 instructions in normal functions | inline asm in the original | write them as `asm()` with the `$vfN` registers spelled out |

Open in that project at the time of writing: two nops before `div.s` (418/700 cases), 26 functions saving `$ra` with
`sq`, 58 functions hidden behind 16 bytes of `addiu $sp,+X; nop` pairs.

The reference implementation of these fixes (CC0) is in
[Ketbome/gh3-decomp](https://github.com/Ketbome/gh3-decomp): `scripts/asm_filter.py`, `include/gcc_prelude.inc`,
`configure.py`, `docs/toolchain.md`.
