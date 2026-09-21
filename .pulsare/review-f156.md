# Review request: three inferences I cannot measure my own way out of

Context: `~/Work/holon/the-little-wat`, a self-hosting wat->x86-64 compiler. Findings are in
FINDINGS.md; the relevant ones are F-155 and F-156, committed as 9ca0a01 and d11579b.

You diagnosed our stage-1 segfault from the coredump earlier today (`:asm::le-neg`, `b`
allocated over live `acc` in r13, `str_cat_own` faulting on `cmpq $1,-8(%rax)` at 0xcf).
That was correct and I confirmed it three independent ways. I am asking for the same
adversarial read on three claims where I am INFERRING rather than measuring, because my
record on mechanism inference today is three falsified out of three.

## The measurements (not in dispute)

`elf/bench/triple.wat`, 30M iterations, `taskset -c 0`, top-down via
`perf stat -e '{cpu_core/topdown-retiring/,cpu_core/topdown-fe-bound/,
cpu_core/topdown-be-bound/,cpu_core/slots/,cpu_core/cycles/,cpu_core/instructions/}'`

| build | ins/it | uops/it | retiring | fe-bound | be-bound | cycles/it |
|---|---|---|---|---|---|---|
| C-188 (current, committed) | 24 | 20.00 | 71.4% | 14.1% | 16.5% | 4.67 |
| C-189 (built, reverted) | 21 | 17.05 | 58.8% | 3.5% | 37.6% | 4.80 |
| `gcc -O2` | 16 | 15.00 | 67.5% | 2.7% | 30.2% | 3.70 |
| `clang -O2` | 16 | 15.01 | 68.2% | -- | -- | 3.65 |

`loopsum` (single accumulator, same treatment): ours 7.99 uops / 58.4% retiring / 2.48 cyc;
gcc 5.01 uops / **30.6%** retiring / 64.7% be-bound / 3.07 cyc. We WIN there.

C-189's change: a `let` binding headed for tail-call argument j is allocated to parameter
j's register rather than the next free one, so the select diamond becomes an in-place
conditional subtract (`cmp` fused with `jle`, then `lea`) with no `jmp` and no join. It
also forced the accumulate to go back through rax, adding `mov %rax,%r12` per chain.

## Claim 1 -- the model

`cycles = uops / (6 * retiring%)`. Predicted 4.67 / measured 4.67 (ours), predicted 3.70 /
measured 3.70 (gcc), predicted 4.80 / measured 4.80 (C-189). Within ~10% on `loopsum` both
sides.

**Is this sound, or am I dividing by a metric that already encodes the answer?** `retiring`
is derived from slots, and slots is 6 x cycles, so there is a real risk the identity is
near-tautological and I have mistaken arithmetic for a model. If so, its apparent predictive
success on C-189 means nothing and I should stop reasoning from it.

## Claim 2 -- why C-189 lost

My inference: the three `mov %rax,%rN` were (a) eliminated at rename, so nearly free, and
(b) DECOUPLING a dependency -- `add` into rax then `mov` to r12 lets the next iteration's
arithmetic begin in rax while r12 is still live, whereas `add %rax,%r12` writes the
loop-carried register directly and serialises against the diamond's `lea`, which also
writes r12.

Measured: fe-bound 14.1% -> 3.5%, be-bound 16.5% -> 37.6%.

**Is the decoupling story right?** Alternatives I cannot rule out: port contention on the
`lea`/`add` mix; the `imul` (3-cycle) newly on a critical path it was not on before; or
simply that 17 uops no longer fill the machine and the stall was always there but hidden.
If the cause is not dependency decoupling, my conclusion in Claim 3 collapses.

## Claim 3 -- what is left

I concluded strength reduction is the only remaining route, because it SUBTRACTS work
(deletes the induction variable) rather than redistributing it, and every transform tried
so far moved one term of the model at the other's expense. gcc does exactly this on
`triple`: it never computes `i*3`, it keeps three counters decremented by 3, 5, 7, and
folds the loop test into a decrement.

I also claim **trapping does not forbid strength reduction** -- it requires PROVING the
induction variable's range so the multiply cannot overflow, which C is exempt from because
signed overflow is undefined there. wat's i64 `+ - *` trap on overflow; we emit a `jo`
after each, 3 of our 20 uops.

**Two questions.** Is the permitted/forbidden reasoning right? And would strength reduction
actually help here, or would it hit the same wall -- fewer uops, worse retiring?

## What I am NOT asking about

The records diagnosis. `elf/bench/rec1.wat` (no field read) 2.67 cyc/it against
`elf/bench/rec.wat` (field read) 6.20 cyc/it is a controlled comparison between two of our
own binaries, and the ~5-cycle store-to-load forward follows directly. That one I trust.

## Repro

    cd ~/Work/holon/the-little-wat
    ./tools/bootstrap.sh          # ~7 min, self-hosts to a byte-identical fixpoint
    ./tools/vs-c.sh               # four opponents per row, every run pinned
    taskset -c 0 perf stat -e '{cpu_core/topdown-retiring/,cpu_core/slots/}' ./elf/out/triple.elf

Source: `elf/compile.wat` (the front end and codegen), `elf/lib/x86.wat` (the encoder,
knows nothing about wat), `elf/lib/runtime.wat` (33 routines). `elf/bench/triple.c` is the
C control.

Refute freely. I would rather lose a model than keep a comfortable one.
