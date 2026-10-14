# Near misses: decomp-permuter

[decomp-permuter](https://github.com/simonlindholm/decomp-permuter) mutates a C attempt at random (statement order,
temporaries, types, expression shapes) and keeps every version that scores closer to the original. It spends CPU
instead of tokens, which is the right trade for register-allocation and scheduling differences.

## Workflow

1. Workers save near misses as `nonmatching/<func>.<ext>`: a full copy of the source file with the attempt in place,
   committed, listed in the worklog.
2. The integrator runs the permuter on them, one at a time with few threads (it compiles constantly).
3. Score 0 is a match: copy the function from `output-0-*/source.c` back into the real file and verify with
   `dk check`. A lower non-zero score is a better starting point for a human or agent.

## Setting it up for a project

Per function the permuter needs a directory with:

- `base.c`: the preprocessed source reduced to declarations plus the target function. The permuter parses C
  (pycparser), so show it only the target function: wrap everything before and after it in `PERM_IGNORE( ... )`
  (passed to the compiler untouched) and declare every type name the function uses with
  `PERM_PRETEND(typedef int Name;)` (the parser only needs to know it is a type). That makes C++ sources work too
  (structs with constructors, inline methods, references): `compile.sh` compiles the result as C++ inside
  `extern "C" { }`.
- `compile.sh input.c -o output.o`: the project's real toolchain (compiler, assembly filter, assembler, prelude).
- `target.o`: the original function assembled from its `.s`.
- `settings.toml`: `func_name`, `compiler_type = "gcc"`, and `objdump_command` with the right architecture
  (e.g. `mips-...-objdump -drz -m mips:5900` for PS2).

`scripts/permute.py` in [Ketbome/gh3-decomp](https://github.com/Ketbome/gh3-decomp) builds all of that from a source
file and a function name and runs the permuter; adapt it to your toolchain variables.

## Finishing a near miss

The permuter's best output is often a few instructions away. Combine it with the cheap manual levers: a callee
re-declared to return `int` through an alias (`extern "C" int f_i(...) __asm__("f");`), a copy of a value into a
new local, a comparison moved into a tiny inline function. In gh3-decomp a score-10 output plus the `int` alias
matched in four tries.

## Limits

- It cannot invent structure (missing locals, a different loop shape): fix those by hand first.
- Run it when workers are idle or with one or two threads: it competes for CPU and memory with them.
