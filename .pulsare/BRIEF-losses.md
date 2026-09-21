# BRIEF — can we win these, or are they closed?

Tree `ff13ef2`. I want to know whether to keep spending on performance or move to the
language surface (closures, pattern matching, a REPL). Three losses stand. **The thing I
most want struck is my own defence of two of them**, because "we lose because the
comparison is wrong" is exactly the shape of the five claims you have already retired
today.

## The board, fresh run, this tree

| | ours | gcc -O2 | clang -O2 |
|---|---|---|---|
| size, prints 4 | **600 B** | 856,720 | 865,056 |
| startup, 500 runs | **1192 ms** | 1364 | 1615 |
| buffered output, 100k ints | **8 ms** | 16 | 15 |
| straight-line loop, 100M | **215 ms** | 228 | 276 |
| string building, 5M appends | **30 ms** | 37 | 29 |
| byte scan, 194 KB | 5 ms | 5 | 5 |
| tail calls, 1M deep | constant stack | not guaranteed | — |
| `fib32` | 18 ms | **13** | 21 |
| `triple` | 105 ms | **80** | 80 |
| **records, 2M field updates** | **14 ms** | **6** | 7 |

Milliseconds are not comparable across runs (F-149/F-154) — this machine has been building
for hours and gcc's own `triple` has read 68, 80 and 101 today. Ratios within this run, and
the uop counts below, are what I am standing on.

## Loss 1 — records. I believe this one is real. Confirm or refute the prerequisite.

`elf/bench/recflat.wat` is the **identical loop** with the accumulator threaded as a bare
i64 instead of a record field. It runs at **6 ms — exactly gcc's number**, and 1.50 cyc/it
against `rec`'s 6.0–6.4. So the whole gap is the heap round-trip, not the loop, not the
calling convention, not the overflow checks.

The dependence (F-158, after you struck its arithmetic): `slot_set_own` writes `[rax+8]`
one instruction before `ret`; the next iteration loads `[rbx+8]`; that value is the next
call's argument. `rec1` stores without reloading and costs 2.34.

F-150 disqualified scalar replacement as a peephole on this reasoning: registers are
assigned by PARAMETER POSITION (`nr = min(nparams,4)`, locals take what is left), so
`step`'s three parameters leave exactly one spare and a four-parameter function leaves
none — record speed would depend on the arity of its enclosing function, which is the
F-129 cliff shape this project has rejected before. I concluded a register allocator is
the prerequisite.

**Is that right?** Specifically: is there a cheaper transform that removes the carried load
without general allocation — and is my claim that the spare-register count makes the
narrow version a cliff actually true, or did I disqualify something buildable?

## Loss 2 and 3 — `fib32` and `triple`. Attack the defence.

I claim these are not losses but semantic mismatches, on two findings:

- **F-133** (`fib`): held to trapping, we are 2.46x `clang` and 3.22x `gcc -ftrapv`, and beat
  `clang -O2` outright while trapping. `gcc -O2`'s lead comes from reassociating the sum —
  364,490 calls against the naive 7,049,155 — which survives `-fwrapv` and dies under
  trapping.
- **F-159** (`triple`, measured today): against `gcc -O2` built with
  `__builtin_mul_overflow`/`__builtin_add_overflow`, same source, same answer —

  | | ins/it | uops/it | retiring | cycles/it |
  |---|---|---|---|---|
  | ours | 24.0 | **19.9** | 67.5% | **4.86–4.92** |
  | gcc, checked | 23.0 | 21.0 | 70.2% | **4.97** |
  | clang, checked | 20.0 | **19.0** | 70.2% | **4.51** |
  | gcc -O2 | 16.0 | 15.0 | 67.8% | 3.69 |

  `elf/bench/triplechk.c` is in the tree.

**Where I want you to strike:**

1. Is `__builtin_add_overflow` actually the same guarantee as our `jo`? Ours traps to an
   abort; the builtin returns a flag I branch on and call `abort()`. If that is a weaker or
   differently-shaped obligation, the comparison flatters us and F-159 should be narrowed.
2. Is "held to our semantics" a legitimate frame at all, or am I choosing the opponent that
   loses? A user deciding between wat and C compares against C as people write it. Say so if
   the honest headline is "1.3x slower than idiomatic C, for a guarantee."
3. `clang -O2` checked is **4.51 against our 4.86** — 8%, same guarantee, no semantic excuse.
   That is the one number in this section with no defence attached. Is it worth chasing, and
   what is it made of?

## What I am not asking

Do not re-audit the encoder. C-190/C-191/C-192 are closed and you closed them.

## The decision this feeds

If records needs an allocator and the other two are genuinely closed, I stop optimising and
move to language features — closures, pattern matching, `Result`, a REPL — which is where
the project's stated objective actually sits. If any of the three is winnable at a cost
smaller than an allocator, I would rather know now.

Ground: `./tools/bootstrap.sh`, `./tools/vs-c.sh`, `./tools/emitted.sh check`,
`elf/bench/{rec,rec1,recflat,triple,triplechk}`.
