# BRIEF — one predicate, two unlocks: a vector parameter that is only READ

Tree `d505452`. F-166's two refusals both pointed at the same missing thing, and this is it.

## What it is

A boolean over one parameter name: **does it appear anywhere except as the container of
`nth` or `length`?**

    read-only?(node, name):
      not a list          ->  NOT (it is the symbol `name`)     a bare mention RETAINS
      (nth name i)        ->  read-only?(i)                     container fine, check the index
      (length name)       ->  true
      otherwise           ->  every child is read-only?

`(conj name x)`, `(assoc name ...)`, `(concat name ...)` and a bare `name` all fall to the
last clause and hit the bare-symbol case, so they are RETAINS without being enumerated. That
is the same trick C-193's classifier used and it is why the default must stay conservative.

**This is NOT `:c::use-walk`.** F-166 established that one cannot be reused: its lattice value
IS a record field index, `use-union` merges by comparing them, every leaf is record-specific,
and `elf/compile.wat`'s subset has no closures (C-131) so it cannot be parameterised by a leaf
predicate. **Do not generalise it. Do not duplicate its nine functions.** This answers a
BOOLEAN, needs no lattice, and should be about twenty lines.

`:c::mut-site` / `:c::write-head?` already answer the narrower "is this name ever the receiver
of assoc/conj/concat" (returning −1 for none). Use them if they compose; do not re-derive what
they know.

## Unlock 1 — the share on a pass-through argument

F-166 named the holder correctly: argument 0 of a tail call becomes the next iteration's
parameter, `:c::conj` shares its VALUE and never its CONTAINER, and `:c::linear?` treats the
read at argument 0 as harmless because it precedes the write. So the `share` is what keeps
`vec_conj_own` from firing wrongly.

**When the body only READS the vector, there is nothing for the count to protect.** The safe
predicate F-166 named is "no other argument RETAINS the container" — that is exactly
`read-only?`. `vecsum` pays `cmpq $0,-0x8(%rax) ; je ; incq -0x8(%rax)` every iteration for a
container nothing will ever conj.

**STOP-1: if `read-only?` can hold while some path still retains, STOP.** F-142 is the
precedent and F-166 is the near-miss. `elf/src/freed.wat` is the canary — it dies of heap
exhaustion if `s` ever becomes linear, and its share must SURVIVE. Verify by disassembly, not
by the program still printing.

## Unlock 2 — `(length v)` is loop-invariant

Eight instructions an iteration in `vecsum`'s read loop, including a push/pop of `i` because
`length` needs rax. It is invariant when the tail call passes `v` through as itself (C-194's
new predicate names that) AND `read-only?` holds.

Emission is at `elf/compile.wat` — the `(:c::strlen? head)`/`(:c::len? head)` arm,
`(:c::emit (:c::expr ...) "488b00")`.

**STOP-2: if hoisting needs a place to PUT the hoisted value, and no register is free, STOP
and say so.** F-163 is the precedent: `triple`'s strength reduction died on exactly that, nine
names against eight positional registers. `user/sum` has three parameters, so one
callee-saved is unclaimed — but say whether that generalises or is this function's luck.

## Order

`read-only?` first, then unlock 1, then unlock 2. Land and verify each before the next.

## Expectations — fixed before the strike

| what | command | expected |
|---|---|---|
| self-hosts | `timeout -s KILL 2400 ./tools/bootstrap.sh` | byte-identical fixpoint |
| blast radius | `./tools/emitted.sh check` | every program reading a vector/string parameter without retaining it. **Predict the list before you build, then check.** |
| answers | `timeout -s KILL 900 ./tools/elf-run.sh` | 30/30, same refusals and traps |
| `freed.elf` | run it | `65536 100 6553700 65536`, and its share still present in the disassembly |
| `vecsum` read half | pinned perf, vs `grow2000000` | read difference below 36 ins / 37 uops |
| `grow2000000` | pinned perf | **must not regress** — 33.00 ins, 30.0 uops |
| `strbuild`, `rec`, `triple` | pinned perf | must not regress |
| compile cost | corpus instruction count, before/after, one sitting | report it; C-194 cost +0.061% |

No predicted cycle number. Report ins, uops, retiring slots, slots, cycles separately; state
`slots/cycles` when it is not 6. A sub-25% cycle difference between two builds is not
attributable.

## Ground

`elf/compile.wat`: `:c::share`, `:c::mut-site`/`:c::write-head?`, the `len?` arm, the `nth?`
arm, `:c::tail-direct?` (C-194's clause). `elf/bench/vecsum.wat`, `elf/bench/grow2000000.wat`,
`elf/src/freed.wat` (the canary), `elf/bench/deepvec.wat` (asserts every element).
