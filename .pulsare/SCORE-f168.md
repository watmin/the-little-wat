# SCORE — F-168: `tail-self?` is blind to `and`/`or`, and the generator is not

**The bug is found, minimised to a ten-line standalone program, explained at the instruction
level, and fixed by two lines.** It is not heap exhaustion, it is not the hoist, it is not
binary size, and it is not any of the eight new functions except one. It is a **pre-existing
latent codegen bug in the GREEN compiler** that the hoist strike was merely the first code in
the repository unlucky enough to have the right shape.

---

## 1. The cause

`:c::tail-self?` (`elf/compile.wat:3294`) decides whether a function has a self call in tail
position. It recurses into `if`, `do`, `let` and `cond` — and **has no case for `and`/`or`**:

```lisp
((:wat::core::and (:c::if? head) (= (length ks) 4))  (or (tail-self? kid2) (tail-self? kid3)))
((:wat::core::or (:c::do? head) (:c::let? head))     (tail-self? last))
((:c::cond? head)                                    (tail-self-clauses ks 1 ...))
(:else (and (= head name) (= (- (length ks) 1) arity)))
```

The last operand of an `and`/`or` **is** the value of the form, so a self call there is a self
tail call — and `:c::expr` has always compiled it as one, emitting the back edge. But
`tail-self?` falls through to `:else`, sees the head is `wat.core/and` rather than the
function's own name, and answers **false**.

**So the generator emits a loop while every consumer of `tail-self?` believes there is no
loop.** Two independently fatal consequences follow, both confirmed in disassembly:

1. **`regs?` goes false** → parameters stay on the frame instead of in callee-saved
   registers. But C-188's self-testing back edge still emits `cmp 0x18(%rsp),%rax` — comparing
   a **stale `%rax`** (whatever the last argument store happened to leave there) instead of
   reloading the loop variable from its frame slot. The re-test is then meaningless.
2. **`wrap?`'s guard is literally `(not tself?)`** → so the loop test is peeled out in front
   of the prologue and the back edge targets the else arm, `jmp 0x4000ff`, **jumping straight
   past the termination test**. This is precisely the hazard the code's own comment warns
   about: *"the test now lives BEFORE the prologue, so the jump would skip it and the loop
   would never end."* The guard exists; it just asks a question that cannot see `and`.

Either way the loop never terminates. It runs off into garbage and dies dereferencing a NULL
vector root inside `tree_get` — `rdi = 0`, `mov 0x8(%rdi,%rax,8),%rax`, fault at `0x88`.

**Why green survives today.** Green has 12 functions with a self tail call as the last operand
of an `and`/`or` (`read-only-all?`, `any-poke?`, `noret?`, `tail-self?` itself, …) — but every
one of them tests `(>= i (length ks))`. The call in the test disqualifies both `cmp-cond`
(so `wrappable?` is false, no peel) and the fast self-test path. `:c::hoistable?` was the
first function in the repository to combine a self tail call under an `and` with a test the
fast paths accept.

---

## 2. The minimal faulting set

**`:c::hoistable?` alone, being called.** Every variant below keeps all eight new functions
DEFINED and the hoist decision forced to constant `-1`, so the code emitted for the corpus is
byte-identical to green; only *which new functions get called* varies.

| variant | what is called | outcome |
|---|---|---|
| green source | — | GREEN, fixpoint 232,775 |
| full repro | everything | **SIGSEGV** |
| N — hoist forced off | everything | **SIGSEGV**, 3/3 runs |
| N1 | `has-name?` + `hoist-par`; `hoistable?` NOT called | GREEN |
| N2 | `hoistable?` + `passes-thru?`; `len-mention?` not | **SIGSEGV** |
| N3 | `hoistable?` + `len-mention?`; `passes-thru?` not | **HANG** (killed at 600 s) |
| N4 | `hoistable?` recursing; neither B nor C called | **HANG** |
| N5 | nothing new called | GREEN |

`passes-thru?`, `passes-kids?`, `len-mention?`, `len-mentions?`, `has-name?`, `len-reg` and
`hoist-par` are all **exonerated**. The hang in N3/N4 is the infinite loop in its bare form;
the SIGSEGV is the same runaway once more state is live.

Narrowing inside `hoistable?` (one-token edits):

| variant | change | outcome |
|---|---|---|
| H1 | base case returns `true` instead of the parameter `seen?` | **GREEN** |
| H2 | first `and` operand wrapped in `(or false …)` | SIGSEGV |
| H3 | `(nth ks i)` argument replaced by `i` | SIGSEGV |
| H4 | `seen?` moved from parameter 6 to parameter 0 | SIGSEGV |

H1 is green because `wrap-val?` accepts only an int literal or a **parameter symbol**, so
returning `true` switches off the peel — one of the two mechanisms — in the one shape where it
was firing first.

---

## 3. What was eliminated, and how

- **Heap exhaustion — NO.** STOP-1 does not fire. The fault is `SIGSEGV`/`SIGBUS` at a NULL
  node pointer, and the fixed compiler compiles the identical source in the same memory.
- **Non-determinism — NO.** STOP-3 does not fire: N faulted 3/3 with identical size.
- **Binary size / layout — NO.** `G2` (all seven new functions **defined but never called**)
  is GREEN at 235,866 bytes while `N` faults at 236,850. `G3` is GREEN at 236,431.
- **`:c::compile-fn`'s own growth — NO.** `G1` (the repro's extra `let` bindings, every new
  call replaced by a constant, no new function defined) is GREEN.
- **Arity — NO.** Green already compiles 8-, 9-, 10- and 11-parameter functions.
- **Mutual recursion, a vector parameter, `nth` through a parameter, a user call nested in a
  tail-call argument — ALL NO.** Green has 51 functions with a user call in a tail-call
  argument and 23 mutually recursive pairs. The standalone repro needs **no vector, no `nth`,
  no string and no call at all**.

---

## 4. The standalone repro

`P7` — ten lines, three integer parameters, no vector, no string, no call. Compiled by the
**green** compiler it **loops forever**; the interpreter prints `true` / `false`.

```lisp
(wat.core/defn user/f [n :- wat.type/i64 i :- wat.type/i64 seen? :- wat.type/bool] :- wat.type/bool
  (wat.core/if (wat.core/>= i n) seen?
    (wat.core/and (wat.core/> i -1)
      (user/f n (wat.core/+ i 1) seen?))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.kernel/println (user/f 3 0 true))
    (wat.kernel/println (user/f 3 0 false))))
```

What green emits for `user/f` — the back edge jumps to `0x4000ff`, **after** the test at
`0x4000ed`:

```
4000ed: mov 0x10(%rsp),%rax     ; i
4000f2: cmp 0x18(%rsp),%rax     ; against n
4000f7: jl  0x4000ff            ; -> else arm
4000f9: mov 0x8(%rsp),%rax      ; base case: return seen?
4000fe: ret
4000ff: ...                     ; the `and`, then the argument stores
400140: jmp 0x4000ff            ; <-- BACK EDGE SKIPS THE TEST
400145: ret
```

Compare `P11`, the same function with the self call **not** under an `and` — green, correct,
and visibly a different compilation strategy (parameters in `rbx`/`r12`/`r13`, back edge
re-comparing those registers):

```
400101: cmp %rbx,%r12
400104: jl  0x40010e
...
400118: cmp %rbx,%r12           ; the self-test re-reads the live registers
40011b: jl  0x40010e
400121: jmp 0x400101
```

**`P4` is the most alarming variant: it does not crash, it silently returns the wrong
answer** — native `false|false` against the interpreter's `true|false`. A program of this
shape can quietly compute nonsense.

Preserved, with the harness: `scratchpad/f168/progs/` (`P0`–`P11`), `std.sh` (compile one
program with green and diff against the interpreter, ~1 s), `try.sh` / `tryw.sh` (build and
run a whole compiler variant, ~2 s instead of `bootstrap.sh`'s 8.5 min).

---

## 5. The fix

Two lines of code, mirroring the `do`/`let` clause directly above them, in `:c::tail-self?`:

```lisp
((:wat::core::or (:c::and? head) (:c::or? head))
  (:c::tail-self? last name arity pg))
```

Evidence it is the cause, not a patch over a symptom:

- Every repro — `P0`, `P4`, `P7`, `P7T`, `P10`, `P11` — is **FIXED** and agrees with the
  interpreter once the compiling compiler carries it.
- **The original F-168 repro builds green.** `scratchpad/compile-hoist-full.wat` + this fix,
  compiled by a compiler that carries the fix, runs its whole corpus: `stage1 exit=0`,
  `compile: ok`.
- The fixed compiler reaches its own **fixpoint**: 232,741 bytes, twice over.

**It takes two rounds to land**, which is worth stating plainly: patching the source and
building it with the *unpatched* compiler still faults, because stage 0 miscompiles
`hoistable?` before the new analysis can matter. Only a compiler that already carries the fix
emits correct code for the shape.

### Verified in the tree, then reverted

Applied to `elf/compile.wat` and run against all three oracles:

| oracle | result |
|---|---|
| `tools/bootstrap.sh` (full, from the interpreter) | **ok** — fixpoint **232,741 bytes**, 76 binaries byte-identical across stages |
| `tools/emitted.sh check` | **ok — all 74 programs byte-identical to the manifest** |
| `tools/elf-run.sh` | **ok** — 30 agree with the interpreter, 3 native-only, 4 refusals, 4 traps |

### The cost, stated plainly — and I predicted this wrong

I expected the fix to change emitted bytes for the 12 green functions with a self tail call
under an `and`/`or`, and said so before measuring. **It does not.** `emitted.sh` is clean on
all 74 programs. The only binary that moves is the compiler's own, **232,775 → 232,741, 34
bytes smaller** — because `elf/compile.wat` is the only source in the tree that contains the
affected shape at all. The 12 green functions keep their bytes because their test is
`(>= i (length ks))`, and the call in the test already kept them off both fast paths.

So the fix is **output-neutral on the entire corpus, 34 bytes smaller on the compiler, and
green on every oracle**. The narrower alternative I was holding in reserve — tightening
`wrap?` and the fast self-test rather than teaching `tail-self?` — buys nothing that this
does not already have, and leaves the generator and its analysis still disagreeing.

---

## 6. Deltas and honest notes

- **F-168's framing was very nearly right and slightly wrong in one place.** It says the fault
  is "purely because a side-effect-free mutual-recursion AST walk gets CALLED". The walk being
  called is indeed necessary — but not because the walk *does* anything. It is because calling
  it is what makes the generator emit `hoistable?`'s back edge in a reachable place. The walk
  is innocent; its *shape* is the bug.
- **"While compiling `elf/src/four.wat`" should not be trusted as a location.** The emitted
  runtime buffers stdout and flushes at exit, so a crash loses the buffer and the last line
  printed is not where it died. I read `compiled=0` for the same reason and had to correct
  myself; the real location came from the core dump.
- **`wat elf/compile.wat` compiling correctly is not evidence about the generator.** The
  interpreter never runs the emitted back edge.
- No oracle in the repo could see this, exactly as F-168 says — and it is worse than stated:
  `P4` shows the failure mode can be a **wrong answer** rather than a crash.

---

## 7. State of the tree

**Clean.** The fix was applied only to run the three oracles above and then reverted with
`git checkout -- .`; nothing was committed. The two-line patch is reproduced in section 5 and
kept at `scratchpad/f168/GREENFIX_full.wat`. `elf/out/*.elf` is gitignored build output — note
the binary sitting there when this started was a **poisoned 232,878-byte artifact** from the
previous strike, not green; a full bootstrap was run first to establish the true green
baseline (232,775, `bootstrap: ok`) before anything was measured against it.
