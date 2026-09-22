# SCORE — one predicate, two unlocks

Tree `d505452` + working-tree changes to `elf/compile.wat` only. Not committed.

**Unlock 1 landed and is fully verified. Unlock 2 is a STOP, with substance: the register
question is answered, the brief's cost attribution is corrected, and the implementation
surfaced a self-hosting miscompilation that is not mine to fix inside this strike.**

---

## 1. `read-only?` — the predicate

`elf/compile.wat`, immediately after `:c::linear?`. Five functions, ~55 lines including the
comment block:

| function | what it answers |
|---|---|
| `:c::read-only?` | the boolean, over one node and one name |
| `:c::read-only-all?` | every child, with one index optionally skipped |
| `:c::pass-at` | which child index is the pass-through, or -1 |
| `:c::ronly-of` | the names, once per function — parallel to `:c::linear-of` |
| `:c::ronly?` | the lookup, parallel to `:c::linear?` |

It is not `:c::use-walk` and reuses nothing from it. It has no lattice, no union, and no
record-specific leaf. `:c::Prog` gained one field, `ronly`, set in `:c::compile-fn` in the same
assoc chain as `:linear`.

### The one thing the brief did not specify, and it is load-bearing

**The predicate as briefed can never hold for a loop.** `user/sum`'s body is

```clojure
(if (= i (length v)) acc (user/sum v (+ i 1) (+ acc (nth v i))))
```

and argument 0 of that tail call is a **bare `v`** — which the brief's last clause classifies
as a RETAIN. Whole-body `read-only?(v)` is therefore false and nothing fires.

So the walk carries one exemption: **argument j of a self call of this arity, when it is
literally the symbol of parameter j, is skipped**. That is C-194's shape — the write is
`mov %rbx,%rax ; mov %rax,%rbx` and creates no holder. `:c::pass-at` also checks the call's
ARITY equals this function's, so position pj+1 really is parameter pj.

Everything else is exactly as briefed, including the conservative default: `conj`, `assoc`,
`concat` and a bare mention are never enumerated — they fall to the last clause, which checks
every child, and the bare-symbol case there is what refuses them.

I did **not** use `:c::mut-site` / `:c::write-head?`. They answer a narrower question
(receiver-of-a-write) and composing them would have left the escape cases — `(user/f v)`,
`(let [w v] ...)`, `(conj acc v)` — unanswered. Those are precisely what the bare-symbol
default catches for free. Using them would have been more code for a weaker predicate.

---

## 2. Unlock 1 — the share on a pass-through tail-call argument

### The brief pointed at one emission site; there are two, and `vecsum` uses the other

The brief named `:c::tail-direct`'s `:else` branch. **`user/sum` never reaches it.**
`:c::tail-direct?` fails on parameter 1 (`i`): argument 1 is `(+ i 1)` and argument 2 mentions
`i`, so the call takes the **stack** path — `:c::push-but-last` + `:c::tail-store`. The share
`vecsum` pays is at `elf/compile.wat:1139-1143`, not at 3088. C-194's own entry says argument 1
"fails, and must"; what it did not say is that this pushes the whole call onto the other
emitter.

Both sites now go through one new function:

```clojure
(:wat::core::defn :c::tail-share [a pv j env pg o] -> :c::Out ...)
```

which elides the `:c::share` only when the argument is a symbol, **is the name of parameter j**
(checked against `pv` at the site rather than inferred), and is in `ronly`. `:c::push-but-last`
and `:c::tail-direct` each gained a `pv` parameter to make that check locally.

### STOP-1 did not fire, and here is the reasoning plus three independent checks

`read-only?` holding means every occurrence of the name is `(nth p i)`, `(length p)`, or the
pass-through. So:

* nothing in the body is a `conj` / `assoc` / `concat` receiver on it — those forms reach the
  bare-symbol clause through their own child;
* no other argument of that call retains the container, which is F-166's literal safe
  predicate — `(user/step v (conj v i) ...)` is refused because `(conj v i)`'s child 1 is a bare
  `v`;
* the store itself writes parameter slot j with what slot j already holds, so it creates no
  holder at all. The elided increment is the one `:c::share` that was never protecting anything.

Checked three ways rather than argued:

1. **`freed.elf` is byte-identical to the baseline** and all **5** of its share sequences
   (`48 83 78 f8 00 74 04 48 ff 40 f8`) survive. `user/copies` concats `s`, so `s` is not
   read-only; `user/burn` mentions `s` bare at `(user/copies 100 s 0)`, so neither is it.
   `./elf/out/freed.elf` prints `65536 100 6553700 65536`.
2. **Per-program share counts**, baseline → now, byte-level: vecsum 1→0, vectors 5→4,
   linear 4→3, moved 9→8, deepvec 3→2, reader 81→80, assocn 11→9, pvec 14→11. Every delta
   matches the scanner's per-function count exactly (pvec is three: `user/sum`'s `v` and
   `user/same?`'s `a` and `b`). strbuild, rec, triple, grow2000000, strown, strverbs: 0 change.
3. **The disassembly.** `vecsum`'s `user/sum` loop used to open its tail call with
   `mov %rbx,%rax ; cmpq $0x0,-0x8(%rax) ; je ; incq -0x8(%rax) ; push %rax`. It now opens with
   `mov %rbx,%rax ; push %rax`. Three instructions, exactly.

### Blast radius: two oracles, predicted before the build

I wrote a Python corpus scanner (`scan_ronly.py`) that reimplements `ronly-of` / `read-only?`
over the source text and asks the emitter's question. **Predicted, before building: vectors,
pvec, assocn, linear, moved, deepvec, vecsum, and `compile.wat` itself.**

`tools/emitted.sh check` reported **8 of 74**: those 7 plus `reader.elf`.

**The miss was the instrument, not the compiler.** `elf/src/reader.wat` is nine lines plus
`(:wat::load-file! "../lib/reader.wat")`, and `:rd::Kids` is declared in the included file — so
my `ptr_type` could not resolve it and skipped `rd/show-kids`'s `ks`. Teaching the scanner to
splice `load-file!` includes the way the compiler does made the two oracles agree **exactly**,
program for program. That is worth recording: the predicted list and the measured list are the
same list, and the one disagreement was a defect in the prediction that the disagreement found.

### Measured — pinned, three samples, per element (÷2,000,000)

| | ins | retiring slots | slots | cycles | slots/cyc |
|---|---|---|---|---|---|
| `vecsum` before | 69.00 | 67.00 | 73.6–76.5 | 12.27–12.75 | 6.00 |
| **`vecsum` after** | **66.00** | **61.96** | 66.4–68.4 | 11.08–11.47 | 5.99 |
| `grow2000000` before | 33.00 | 30.07 | 33.2–39.3 | 5.53–6.55 | |
| **`grow2000000` after** | **33.00** | **30.04** | 32.5–33.7 | 5.41–6.27 | |
| **read half, before** (difference) | 36.00 | 36.92 | | | |
| **read half, after** (difference) | **33.00** | **31.92** | | | |

The read half is under the brief's 36 ins / 37 uops bar.

**Three instructions removed, five retiring slots.** That surprised me and I report it as
measured rather than explaining it away: `cmpq $0,-0x8(%rax)` and `je` and
`incq -0x8(%rax)` are three instructions, and the read-modify-write `incq` on memory evidently
accounts for more than one retiring slot. Instructions are exact (`132,000,260`, i.e. 66.00 to
seven figures); the slot delta is 5.01 and stable across samples.

Cycles moved 12.27→11.08 best-to-best, about 9%. **That is inside the 25% band, so I am not
attributing it.** The instruction and slot counts are the claim.

**No regressions.** `grow2000000` 33.00 ins and 30.0 uops, unchanged to seven figures.
`strbuild` 150,000,552 → 150,000,685, `rec` 16,000,206 → 16,000,205, `triple`
720,000,275 → 720,000,323 — all three within startup noise of identical, and all three
byte-identical binaries.

### Compile cost — four cells, one sitting, against byte-identical baselines

Interleaved, three rounds, `taskset -c 2`, each compiler run against a scratch copy of the
tree so the repo's verified binaries were never disturbed:

| | old source | new source |
|---|---|---|
| **old compiler** | 1,787,609,025 | — |
| **new compiler** | 1,792,984,504 | 1,821,012,744 |

* **The analysis itself, same input corpus: +0.301%** (+5.38M instructions).
* **Headline, what the corpus costs now: +1.868%** (+33.40M).
* The difference between them — +28.03M, 84% of the total — is not the analysis. It is that
  `elf/compile.wat` grew 8.5 KB and **the corpus includes `elf/compile.wat`**.

C-194 cost +0.061%. This is thirty times that on the headline and five times on the analysis,
and I want that stated plainly rather than buried: this predicate is not free.

**It was 4.8x more expensive before I gated it.** The first landed version cost +1.43%
analysis-only / +2.93% headline. Two gates brought it to +0.301% / +1.868%, and both are
provably output-neutral (`emitted.sh` reported the same 8 programs and the same per-program
share counts after):

1. **`:c::share` emits for a POINTER symbol and nothing else**, so walking every occurrence of
   an `i64` parameter answers a question nobody asks. Most parameters in this compiler are
   `i64`.
2. **`:c::tail-share` is only reachable from a self tail call**, so a function without one
   skips the analysis entirely.

Compiler binary: 229,548 → 232,775 bytes, +1.41%.

### Oracles, on the exact tree I am leaving

* `timeout -s KILL 2400 ./tools/bootstrap.sh` — 76 binaries byte-identical between the
  interpreted and the compiled compiler, fixpoint at **232,775 bytes**. That is the oracle that
  caught F-142, and it is the one that matters here.
* `./tools/emitted.sh check` — 8 of 74, all 8 predicted.
* `timeout -s KILL 900 ./tools/elf-run.sh` — **30 agree**, 3 native-only, 4 refusals and 4
  traps, both ways.
* `./elf/out/freed.elf` → `65536 100 6553700 65536`.

---

## 3. Unlock 2 — STOP, and what the stop is worth

I built it, it did not land, and I removed it. `elf/compile.wat` contains unlock 1 only.

### STOP-2's question is answered: a register IS free, and it does not generalise

`:c::nregs` is **4**. The callee-saved pool is `rbx, r12, r13, rbp` — index 3 is rbp, available
because C-1xx dropped the frame pointer for everything that does not `clone`. `nr = min(n, 4)`
parameters take the low end and `let` bindings take what is left, counting up from `regbase`.

`user/sum` has three parameters and no `let`, so **rbp is unclaimed and the hoist costs one
extra push/pop per call, not per iteration.** That is this function's luck, and the luck is
narrower than F-163's: `triple` had nine names against eight positional registers; here it is
**four callee-saved, total**. Four parameters and there is nothing to spend. Three parameters
and one `let` and you are choosing between them. `vecsum` fits; a general loop does not.

### The brief's cost attribution is wrong, and the correction makes the unlock BIGGER

The brief says `(length v)` costs eight instructions an iteration. It does:

```
mov %r12,%rax      ; i          argument protocol
push %rax          ;            argument protocol
mov %rbx,%rax      ; v          <- the length
mov (%rax),%rax    ; length     <- the length
mov %rax,%rcx      ;            argument protocol
pop %rax           ;            argument protocol
cmp %rcx,%rax
jne
```

**Only two of the eight are the length**, and hoisting removes one of them. The other six are
`:c::if-cmp`'s general comparison protocol, taken because C-181's both-operands-in-registers
fast path needs a REGISTER on each side and `(length v)` is a form, not a register.

So the payoff is real and it is about six instructions — but it does not come from invariance.
It comes from **the hoist making C-181 applicable**: `(= i (length v))` becomes
`cmp %rbp,%r12`, one instruction, rax survives into both arms, and C-188's back edge becomes
able to test for itself (one taken branch an iteration instead of two). Hoisting alone, without
C-181, is worth one instruction and is not worth a register.

I say this because a future strike briefed on "hoist the invariant" would build the hoist, find
one instruction, and conclude the room was empty. The room is not empty; the door is C-181.

### Why I stopped: the compiled compiler segfaults and the interpreted one does not

The implementation (`:c::hoist-par` / `:c::hoistable?` / `:c::passes-thru?` /
`:c::passes-kids?` / `:c::len-mention?` / `:c::len-reg`, plus `lenreg`/`lenpar` on `:c::Prog`,
the `nsave`/`nlr`/`regbase`/`nscr` accounting and a three-instruction prologue load in the same
window as `:c::scalar-bytes`) made stage 1 die with SIGSEGV. I bisected it to a finding I could
not have predicted, in five builds:

| build | result |
|---|---|
| full hoist | **SIGSEGV** |
| cache register never READ (`len-reg` → -1) | **SIGSEGV** |
| prologue load also not emitted — accounting only | **SIGSEGV** |
| `:c::hoist-par` never called | green |
| `:c::hoistable?` never called (so `passes-thru?` never runs) | green |
| `len-mention?` not called, so `hoistable?` is **always false** — no emission, no accounting change at all — but `passes-thru?` still walks | **SIGSEGV** |
| that same build with **unlock 1's elision turned off** | **SIGSEGV** |
| `wat elf/compile.wat` — the **interpreter** on that identical source | **compiles the whole corpus correctly** |

Read that table carefully. In the sixth row the hoist decision is a constant `false`: `hp` is
-1 everywhere, `nh` is 0, `lenreg` is -1, **not one byte of emitted code differs from the green
build**. The only difference is that a pure, allocation-only, side-effect-free mutual-recursion
walk over the AST gets *called*. And the seventh row clears unlock 1 completely — the crash
survives with `:c::tail-share` restored to an unconditional `:c::share`.

The fault is always the same instruction, the leaf load of the runtime's `tree_get`
(`mov 0x8(%rdi,%rax,8),%rax`), with a garbage node pointer — i.e. `nth` on something whose
vector header is not a vector header.

**So: `elf/compile.wat` compiled by itself miscompiles a function shape that the interpreter
executes correctly.** I could not localise it further without more budget than the strike had,
and I was not willing to leave a half-built register allocator in the tree next to a verified
unlock 1 in order to keep trying. The shape is close to `:c::read-only?` / `:c::read-only-all?`
(which landed green): 6 and 7 parameters, `pg` last, a `cond` on `:c::kind`, a `let [ks
(kidsof pg a)]`, mutual recursion. The one structural difference I found and could not rule in
or out is that **`:c::passes-thru?` has no self tail call**, where every comparable walk in the
compiler has one — which puts it on different sides of `tself?`, `regs?`, `wrap?` and
`callfree?`. I checked `:c::wrappable?` (requires a 4-kid `if`; a `cond` body is not one) and
`:c::noret?` (a non-self call requires `scratch-safe?`) and neither explains it.

It is not heap exhaustion: the runtime has a clean `wat: heap exhausted` abort, and the crash
happens while compiling `elf/src/four.wat`, which is two lines.

I have left the full unlock-2 source at
`/tmp/claude-1000/-home-watmin-Work-holon/5373d366-7a52-4a05-a9b4-198d0c5a4a95/scratchpad/compile-hoist-full.wat`
so the work is not lost, along with `scan_ronly.py` and `scan_hoist.py`.

---

## 4. The honest deltas

* **The brief's emission site was the wrong one.** `vecsum` takes the stack path, not
  `tail-direct`. Both are fixed; only one was named.
* **The predicate as specified cannot fire on a loop.** It needs the pass-through exemption,
  and the brief did not include it. The exemption is where the safety argument actually lives.
* **The cost is 30x C-194's** on the headline, and I want that on the record. Two output-neutral
  gates took it from +2.93% to +1.868%, and 84% of what remains is not the analysis at all — it
  is compiling 8.5 KB more compiler.
* **Three instructions came off, and five retiring slots.** I do not have a clean account of the
  extra two beyond "`incq` on memory is not one slot", and I am reporting it rather than
  rounding it.
* **The cycle improvement is 9% and I am not claiming it.** Under the 25% bar.
* **My blast-radius scanner was wrong once**, on `reader.wat`, because it did not follow
  `load-file!`. The build found it. Two oracles are only two oracles when the second one is
  built as carefully as the first.
* **Unlock 2's stop cost more than it produced in code, and I think it produced the more useful
  finding anyway**: the register is available but the pool is four; the eight instructions are
  not the length; and there is a self-hosting miscompilation sitting in the compiler that has
  nothing to do with either unlock and that the interpreter-vs-compiled differential catches
  on demand.
* **Nothing regressed.** `grow2000000`, `strbuild`, `rec` and `triple` are byte-identical
  binaries with identical instruction counts.
