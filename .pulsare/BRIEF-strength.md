# BRIEF — strength reduction, and a probe that must run first

Tree `59ce92d`. C-193 landed; records is closed at `recflat`. This is the last live item on
the board: F-161 established that `clang -O2` **while trapping with the same three `jo` we
carry** strength-reduces `triple` and lands at 19 uops / 4.51 cycles against our 20 / 4.86.
So the transform is legal under our semantics — clang proves it — and our multiply checks
are already gone (C-170), so no new bounds work is needed.

## Probe first. Do not build until it answers.

**The register budget is the trap, and `elf/bench/triple2.wat` already failed it once.**
Your earlier score: triple2 spills three counters to `[rsp+0x58]`, `[rsp+0x50]`, `[rsp+0x48]`
and still emits `jo` on the decrements, because it passes them as PARAMETERS — seven
parameters against four callee-saved registers. That is not this transform, but it is the
wall this transform has to clear.

`go` today: four parameters (`i a b c`) take all four callee-saved — `nregs` is 4, so
`nr = 4` and `nlr = min(0 + nscratch, slots)`. The body is call-free, so r8–r11 are
available and the three `let` bindings hold r8, r9, r10. r11 is spare.

    imul $0x3,%rbx,%r8     rbx = i      r8  = a2
    add  %r12,%r8          r12 = a      r9  = b2
    imul $0x5,%rbx,%r9     r13 = b      r10 = c2
    add  %r13,%r9          rbp = c      r11 = spare
    imul $0x7,%rbx,%r10
    add  %rbp,%r10

Clang's checked loop carries **six** values and no separate `i`: `rax`/`rdx`/`rcx` step by
−3/−5/−7, `r9`/`rsi`/`rdi` accumulate. It tests one counter instead of a counter variable.

**The probe: establish whether our register file has room for three carried counters without
spilling, given that the three `let` bindings currently occupy r8–r10.** Eliminating `i`
frees rbx. That is one register for three counters. Whether the other two exist depends on
whether `a2`/`b2`/`c2` still need their own — and C-189 (reverted, F-156) showed that
computing an accumulator in place is not free.

**STOP-1: if the counters cannot be held in registers without spilling, STOP and say so.**
A spilled counter is `triple2`, which F-131 already measured and rejected. Do not build a
transform whose output is a load and a store.

## The work, if the probe clears

Recognise `(* i k)` where `i` is the counted-loop induction variable (the recogniser exists
— C-170's, the one that already deletes the multiply checks) and `k` is a literal. Introduce
a carried value stepping by `k`, computed once in the prologue and updated on the back edge.

**That placement is exactly C-193's.** The prologue computes; the tail target sits after it;
the back edge jumps over it. No new parameter, no calling-convention change. You established
that shape clears trigger 3 on the records strike.

## STOP triggers

1. Register pressure, above. A spill means stop.
2. **If the induction variable cannot be eliminated and you need a counter AND `i`, STOP.**
   Clang tests one of the counters. Carrying both is one more register than the budget has.
3. **If the decrement needs a `jo`, STOP** and say why. C-170 already proved the counted-loop
   range; the decrement inherits it. If it does not, that is a finding about C-170's bound,
   not a licence to emit the check.

## Expectations — fixed before the strike

| what | command | expected |
|---|---|---|
| self-hosts | `./tools/bootstrap.sh` | byte-identical fixpoint |
| blast radius | `./tools/emitted.sh check` | `triple.elf`, `loopsum.elf`, `counted.elf` and any other counted loop with a literal multiply; nothing else |
| answers | `./tools/elf-run.sh` | 30/30, same refusals and traps |
| `triple` | `taskset -c 0 perf stat -e '{cpu_core/instructions/,cpu_core/cycles/,cpu_core/topdown-retiring/,cpu_core/slots/}'` | toward clang-checked: 20 ins, 19 uops, ~4.5 cyc |
| `counted`, `loopsum` | same | must not regress |

**No predicted cycle figure beyond "toward clang-checked".** Report ins, uops, retiring
slots, slots and cycles separately; state `slots/cycles` when it is not 6. Six attempts at
this loop have each removed work and moved cycles the wrong way (F-151, F-153, F-155, F-156,
F-157) — the uop count is the thing to report, and the cycles are whatever they are.

Trap-door named: `imul` is three cycles on port 1; `sub` is one on any ALU. That is a backend
change no uop count shows, and it is the part of the prize F-159 priced wrongly as "about one
uop". If uops fall and cycles do not, say so plainly rather than reaching for a mechanism.

## Ground

`elf/bench/triple.wat`, `elf/bench/triple2.wat` (the failed parameterised version),
`elf/bench/triplechk.c` (the C control that traps), `elf/src/counted.wat` (C-170's
counted-loop shapes). `elf/compile.wat` only — no encoder or runtime change.
