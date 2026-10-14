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

- `base.c`: the preprocessed C it can parse (pycparser): the file reduced to declarations plus the target function.
  For C++ projects strip `extern "C"` and other C++-only syntax, or hide it with `PERM_IGNORE(...)`, and compile the
  result as C++ inside `extern "C" { }` in `compile.sh`.
- `compile.sh input.c -o output.o`: the project's real toolchain (compiler, assembly filter, assembler, prelude).
- `target.o`: the original function assembled from its `.s`.
- `settings.toml`: `func_name`, `compiler_type = "gcc"`, and `objdump_command` with the right architecture
  (e.g. `mips-...-objdump -drz -m mips:5900` for PS2).

`scripts/permute.py` in [Ketbome/gh3-decomp](https://github.com/Ketbome/gh3-decomp) builds all of that from a source
file and a function name and runs the permuter; adapt it to your toolchain variables.

## Limits

- It cannot invent structure (missing locals, a different loop shape): fix those by hand first.
- Run it when workers are idle or with one or two threads: it competes for CPU and memory with them.
