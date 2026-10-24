# Steering the compiler

Techniques that turn a near match into a match, roughly in the order to try them. Most were confirmed on GCC 2.9x for
MIPS; the ideas carry over to other old compilers.

## Shape first

- Get the **size** right before anything else: a missing or extra statement, an unrolled loop, a merged branch.
- **Branch layout**: `if/else` vs early `return` vs `?:`; `do/while` vs `for` (a `for` keeps the original shape where
  a hand-made `do/while` does not); inverting a test; `return c ? f() : 0;`. A `goto err` to the end puts the error
  path out of line.
- **Switches**: list the cases in the order of their code addresses; give every index that reaches the default its
  own `case N:` (otherwise the compiler builds a compare chain); an explicit `case 0:` when the table starts at 0;
  `goto` for a case that falls into another. Small checksum switches are often balanced compare trees: a dummy case
  can add the missing node.
- **Conditional moves** (`movz`/`movn`, `cmov`) where the original branches on `if (c) x = v;`: GCC 2.9x
  if-converts only when `x` is in a register at that pass. Write `x` through a reference parameter of a `static
  inline` helper and the branch stays; try the inverted test too. Check how often the original uses the conditional
  move before blaming a flag (in one game: 1365 times in 663 functions; the flags that kept the branch broke 209
  matched functions).
- **Comparisons against a constant**: GCC picks the instructions while it still sees the literal (`x >= 0` as a
  0/1 value gives `nor; srl 31` on MIPS). A constant that only appears after inlining or propagation (`static
  inline bool Ge(int a, int b) { return a >= b; }` called as `Ge(x, 0)`, or `int z = 0; x >= z`) gives the generic
  sequence (`slti x,0; xori 1`). Try it when the original has the generic form of a comparison with 0.
- **Unrolled loops**: if the original has repeated bodies with a constant stride, write the loop and enable
  unrolling for that object.

## Registers and order

- Declaration order of locals and stack slot order follow first use of each address.
- A temporary, or splitting one expression into statements, changes the register; so does reusing a variable or a
  parameter (`b = alloc(...)` keeps `b`'s saved register).
- Signedness and width (`s32` vs `u32`, `char` vs `int`, `(int)x & ~1` vs `u32`), `bool` return types (`(f() ^ 1)`
  keeps an `xori`).
- **Prototypes matter**: the order of float vs int parameters, a callee declared `int` instead of `void` (changes
  `$v0/$v1` choices), `void*` vs `void` returns. A second prototype for the same symbol (`__asm__("name")` alias)
  when callers disagree on arity.
- m2c lists extra arguments on virtual and constructor calls (whatever sits in `$a1..$a3`): pass only the real
  ones; the leftover registers already hold the right values.
- **Copies the original keeps** (`move a0,v1` before a loop) where yours has none: the original recomputed a
  loop-invariant value inside the loop and GCC hoisted it into a copy. Recompute it from the same base pointer in
  the loop condition or body instead of reusing a variable, one new variable per reload. Not a flag.
- Pass through untouched argument registers (`g(p); return p;`); return the result of a virtual call.
- Last resorts, used sparingly: an empty `asm("" : "+r"(x))` barrier (forces a copy or blocks reassociation), a
  `register T x asm("$N")` pin on the smallest set of variables (GCC 2.95 ignores such pins unless the variable
  is an operand of an asm statement). Never ordinary instructions in asm.

## Data and globals

- Strings and constants of the original stay in its data: declare the existing symbol (`extern char D_xxx[];`) until
  that object's data is migrated.
- Small globals reached through the global pointer or through absolute addressing: see toolchain-forensics (an
  assembler rule, not a source choice, in SN-built games).
- Constructors write members first and the vtable pointer last; a dead store is dropped unless a load sits between.

## When to stop

Fifteen attempts on one function is enough. Save the near miss for the permuter and move on; come back when a
toolchain fix or a sibling function teaches something new.
