# BRIEF — the read loop, and the real cause is one line in `tail-direct?`

Tree `dce13fe`. Your F-165 refusal was right and I traced the rest. The three costs I named
have one root I had not found.

## What the loop actually does

`user/sum`'s tail call is `(user/sum v (+ i 1) (+ acc (nth v i)))`. Argument 0 is **literally
the symbol `v`**, which is parameter 0. Argument 2 mentions `v` inside the `nth`.

`:c::tail-direct?` (`elf/compile.wat`) requires that **no later argument mentions parameter
j**, for every j. Argument 2 mentions `v`, so it fails at j=0 and the whole call falls to
`:c::tail-store` — push every argument, pop every argument. That is the push/pop shuffle, and
it is not `nth`'s call convention at all; `nth` is only three instructions of it.

**But writing parameter 0 with `v` is a no-op.** Argument 0 *is* the parameter. The later
mention reads the same value it would have read anyway. The guard exists to stop `(f b a)`
clobbering `a` with `b`; it does not need to fire when the argument and the parameter are the
same name.

## The strike

`:c::tail-direct?` should not require `none-mention?` for an argument that is exactly the
symbol of its own parameter. One clause:

    j is safe if  (argument j is a symbol whose text = parameter j's name)
                  OR  none-mention? ks (j+2) (param j)

Everything else in `tail-direct` already handles it: `:c::selv?` admits a bare register
symbol and `:c::selv` emits **nothing** when the register is already the destination (C-177).
So argument 0 should cost zero instructions, not a push and a pop.

## The second cost, and I want it weighed not assumed

The share on `v` fires every iteration: `cmpq $0,-0x8(%rax) ; je ; incq -0x8(%rax)`. Over
2,000,000 iterations that refcount climbs to ~2,000,000.

`:c::share` increments because a pointer symbol is being passed to a callee that will hold
it. **On a tail call that passes a parameter through to its own slot, no new holder is
created** — it is the same reference in the same position.

**STOP-1: if removing that increment could let an `*_own` path fire when the container is
genuinely retained, STOP and say so.** F-142 is the precedent and it is the exact shape of
this mistake: I argued a static ownership test away, and `bench`, `fib32` and `fib` diverged
between compiled and interpreted because the share count UNDER-counts already. Lowering it
further is the dangerous direction. If the increment is load-bearing, say which holder it
accounts for and leave it.

Worth checking either way: an unbounded refcount on a pass-through parameter disables
`vec_conj_own` and `slot_set_own` for any loop that both reads and conjs. That is a
correctness-adjacent finding whether or not the increment is removed.

## The third cost

`(length v)` is reloaded every iteration — `mov %rbx,%rax ; mov (%rax),%rax ; mov %rax,%rcx ;
pop ; cmp`. It is loop-invariant when `v` is passed through unchanged and nothing in the body
mutates it.

**STOP-2: if proving "nothing mutates v" needs an analysis the tree does not have, STOP.**
C-193's `:c::use-walk` classifies occurrences of a record parameter and is the closest
existing shape; a vector version would ask whether `v` appears anywhere but as the container
of `nth`/`length`. If that is a new walk rather than a reuse, say so and stop — F-162 is the
precedent for me forbidding necessary work, so this trigger is "tell me", not "do not".

## Order

Take them in this order and stop at the first that will not go: **(1) `tail-direct?`**, then
**(2) the share**, then **(3) the hoist**. (1) is small and has precedent. (2) needs the F-142
argument. (3) may need a new walk.

## Expectations — fixed before the strike

| what | command | expected |
|---|---|---|
| self-hosts | `./tools/bootstrap.sh` | byte-identical fixpoint |
| blast radius | `./tools/emitted.sh check` | every tail-recursive program passing a pointer through unchanged — expect several |
| answers | `./tools/elf-run.sh` | 30/30, same refusals and traps. `deepvec.wat` asserts every element |
| the read half | `taskset -c 0 perf stat -e '{cpu_core/instructions/,cpu_core/cycles/,cpu_core/topdown-retiring/,cpu_core/slots/}' ./elf/out/vecsum.elf` vs `./elf/out/grow2000000.elf` | read difference below 36 ins / 37 uops |
| `grow2000000` | same | **must not regress** — 33.00 ins, 30.0 uops, 6.717 cyc |
| `strbuild`, `rec`, `triple` | same | must not regress |

No predicted cycle number. Report ins, uops, retiring slots, slots, cycles separately; state
`slots/cycles` when it is not 6. On this benchmark we retire at 91–95% while gcc is at 31%,
so the uop count is not the whole story and the retiring fraction has flipped a reading twice
this session.

## Ground

`elf/compile.wat` `:c::tail-direct?`, `:c::tail-direct`, `:c::tail-store`, `:c::share`,
`:c::selv?`/`:c::selv` (C-177), `:c::use-walk` (C-193). `elf/bench/vecsum.wat`,
`elf/bench/grow2000000.wat`, `elf/bench/deepvec.wat`.
