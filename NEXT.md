# After Friedman: more acceptance tests

Queued for once the Friedman books are exhausted. Each one tests wat against something
with a known right answer, and each leans on a different part of the language. The same
rules apply as for the books: every gap goes into FINDINGS.md with a repro, and code is our
own, not copied from the sources.

Ordered by how directly each tests what wat claims to be.

## elf/ — open items (2026-09-19)

The book queue below is closed. This section is the live one: every item is something a
FINDINGS entry **named rather than did**, so the evidence is already written down and this is
only a map to it. Nothing here is a vague intention — each line says what it is, where the
measurement lives, and why it was not done at the time.

**Correctness first — these are defects, not improvements.**

1. ~~**`quot` and `rem` do not trap**~~ **DONE 2026-09-19, F-126/C-150.** `idiv` *faults* rather than
   flagging, so the divisor is tested BEFORE the instruction by a guarded routine, and `MIN / -1`
   is `neg`+`jo` — `a / -1` is `-a`, overflowing in exactly the same place. It turned up two more of its own: `:c::to-int` and `:asm::le` both reached a
   negative by negating its magnitude, which is wrong at exactly one input, since i64's range is
   asymmetric.
2. ~~**`:c::cat-fold`'s `own?` rule treats any non-symbol operand as a temporary**~~
   **DONE 2026-09-19, F-127/C-151.** It bit: `elf/src/strown.wat` prints a record field that grew
   after it was read. The rule asks whether the operand was ALLOCATED now, not whether it is
   spelled like a variable. It cost **3.06x peak memory** (145,092 → 444,200 KiB) and 14% wall,
   all of it `:c::emit`, and **the three ways to buy that back are all blocked by the same
   thing** — see item 3a below.
3. **`999999` as "name not found"** and the **`"vec:"`/`"rec:"` string-tagged type encoding**
   (C-139). A magic number where an `Option` belongs, and a record wearing a string. Both are
   internal and consistent; both are the shape C-139 was about.

**Performance — and C-158 measured the gap ONE MORE TIME, at the other end of the machine.**

**The rule depends on the SHAPE of the code, which is why breadth was worth more than another
fib peephole** (C-164). On a latency-bound loop we tie `gcc -O2` while issuing 3.3x the
instructions, because both wait on the same chain and the machine has width to spare. On a
throughput-bound loop — three independent chains — gcc's IPC climbs to 4.34 and ours stays
pinned at **6.4, the issue width**: we are saturated and it is not, and we lose 1.94x. **There
the instruction count is the whole ceiling, and it is 43 an iteration against 16.**

~~**The biggest single item now: `triple` spills three `let` bindings to the frame every
iteration.**~~ **DONE 2026-09-19, C-165 — and it bought exactly nothing.** A function that makes
no RETURNING call now allocates r8-r11 as well (a self tail call is a `jmp`, so it does not count
as returning), the pool counts down from r11 while a binding counts up from r8, and the loop has
no memory traffic left. It retires **the same 1,290,000,318 instructions** and the same cycles:
at IPC 6.14 on a 6-wide core a spill costs one store and one reload, and a register binding costs
one `mov` in and one `mov` out — **two issue slots either way**. Kept because the value now sits
in a register the compare reads directly, which is what the next item needs.

~~**the check is provably dead under a dominating comparison**~~ **DONE 2026-09-19, C-166.**
Inside the THEN arm of `(> x k)` with `k >= 0`, `x` is non-negative, and `x - j` with `j >= 0`
then cannot underflow. `triple` **-7.0% instructions and -14.4% cycles** (1.90x -> **1.63x** vs
gcc), `loopsum` -5.3%/**-10.1%** and it now **beats `gcc -O2` by 11%** at 0.89x, `fib` -8.4%
instructions and **zero** cycles — the same edit demonstrating both halves of the C-164 rule in
one run. `elf/bad/nnegshadow.wat` caught the first cut eliding a check a rebinding should have
kept.

**The biggest single item now: if-conversion.** `triple` still spends **18** of its 40
instructions an iteration on three `(if (> x K) (- x K) x)` — `cmp`, `jcc`, `mov`, `sub`, `jmp`,
`mov` each — where gcc spends **9**: `lea -K(%r),%r9`, `cmp`, `cmovg`. Two pieces:

  * **`cmov`.** Both arms have to be evaluated, so both have to be flag-free and trap-free.
    C-166 made `(- x K)` trap-free in exactly this shape, and `lea -K(%r),%rcx` computes it
    without touching flags — so the blocker C-165 named is gone and this is now reachable.
    Needs `lea` and `cmov` encodings, and arms restricted to names, constants and that one
    arithmetic form.
  * **The destination register.** Each arm computes into rax and the `if` then copies rax into
    the register the value belongs in. Compiling an arm **straight into its destination**
    removes one instruction per arm, independently of `cmov`.

**And the item after that, which is worth more instructions than either: strength reduction.**
gcc emits **no `imul` at all** for `(* i 3)`, `(* i 5)`, `(* i 7)` — it turns all three into
registers counting down by 3, 5 and 7, and drops `i` itself because one of them reaches zero
exactly when `i` does. That is 12 of our 43 instructions against 3 of its 16.

**WHAT MOVES `fib` IS CONTROL FLOW, NOT WORK — nine experiments, one rule** (C-167). Everything
that removed work bought nothing: overflow checks **-13% instructions / -3% cycles**, a register
calling convention -6.6%/**+1.2%**, a frame-slot spill -5.1%/**+3.9%**, `jo` trampolines -9.5%
bytes/**+2.1%**, `rel8` -5% bytes/**~0**, C-166's provably-dead checks **-8.4%/+0.2%**. Everything
that removed control flow was paid in full: shrink-wrapping **-11.2%**, and C-167's collapse of
`jcc`+`jmp` into one branch **-22.1% cycles for -4.6% instructions** — `fib32` 1.94x -> **1.50x**
vs `gcc -O2`. The counters say why: the uop cache delivers everything, there are no icache stalls
and no branch misses, so the front end is bound by **taken branches**, and a taken branch costs a
fetch redirect whether it was predicted or not. **On front-end-bound code the unit of cost is a
taken branch, not an instruction.**

**A lead, measured but not explained:** naming the intermediate — `(let [a (fib (- n 1))]
(+ a (fib (- n 2))))` instead of `(+ (fib (- n 1)) (fib (- n 2)))` — costs **112.8M instructions
against 62.8M and 37.1M cycles against 19.3M**, because the `let` form stops the function
inlining. `:c::inl-limit` is a node count of 34 and the `let` adds nodes, which is the suspected
mechanism and is NOT yet confirmed. If that is it, it is a cliff that punishes naming a value,
and the fix is to measure the callee's cost rather than its node count.

**`fib` is CRITICAL-PATH bound, and counting instructions does not predict its cycles.** Seven
experiments (C-158, C-160, C-162, C-163): the two that worked — shrink-wrapping **-11.2%** and
the commutative fold **-1.9%** — took instructions OFF the dependency chain. The five that failed
either moved work onto it or removed work that was never on it, and four of the five looked like
obvious wins on paper. **Profile first, measure cycles not instructions, and interleave at least
fourteen repetitions.** The table is in C-163.

**And `fib` is not limited by how much work it does.** Four experiments, all measured:
overflow-check removal (-13% instructions, **-3% cycles**), the `jo` trampoline (-9.5% bytes,
**+2.1% cycles**), `rel8` branches (-5% bytes, **~0**), and a register calling convention for a
single argument (-6.6% instructions, **+1.2% cycles**, C-162). What HAS moved it is taking work
off the critical path — shrink-wrapping **-11.2%** and the commutative fold **-1.9%** — and both
came from reading a `perf record` profile rather than from a theory about the compiler. **Profile
first; the instruction count is not the target.**

**A register allocator is NOT the next thing.** `fib(32)` is 43% front-end bound and **0%
back-end bound**; a register allocator relieves back-end pressure and there is none. Four levers
measured, none enough: register allocation **0%**, overflow-check elimination **-3%**, inlining
depth 8 **-16% for 14x the code**, branch `rel8` density **~8% of the bytes**. The remaining 2.2x
is that we ask the front end for 1.63x the uops in basic blocks half as long, and what fixes that
is emitting fewer instructions everywhere — a grind, not a feature. C-158 has the counters.

**Performance — and C-153 measured where the gap actually is, so this list is now evidence.**

**What is NOT the gap, measured and struck:** the overflow checks are 45% of our branches and
13% of our instructions and **4.3% of our cycles** — an interval analysis to prove them away was
about to be built and would have bought 4%. Deeper inlining is **14x the code for 16%** and depth
5 is worse than depth 4. Both are written up in C-153 with counters.

**What IS the gap:** on a loop with no calls in it we issue **26 instructions an iteration
against gcc's 6** — and only 1.34x the cycles, because that loop is latency-bound and a 6-wide
machine hides the rest. It will stop hiding it on a throughput-bound loop. The fat is named
instruction by instruction in C-153 and each item is a peephole:

**All four were taken in C-154 — three were worth it and one was worth exactly zero, which is
why it is written down.** `loopsum` went 26 instructions an iteration to 22: **-15.4%
instructions and -12.3% cycles**. `fib32` moved -1.6%/-0.5% and the compiler -1.1%/+0.1%,
because C-136 gives registers only to functions with a self call in tail position and **every
one of these peepholes fires on an operand that is already in a register** — so the register
allocator decides what they are worth, which argues for widening C-136 rather than for more
peepholes.

0a. ~~**`cmp` against a register still routes the left operand through rax.**~~ **DONE.** `mov %rbx,%rax` then
   `cmp $0x0,%rax` where `test %rbx,%rbx` is one instruction and one byte shorter. C-133 took the
   RIGHT operand of a binop from a register or the frame and never took the left.
0b. ~~**An adjacent `push X` / `pop Y` is a `mov`.**~~ **DONE.** `:c::tail-store` emits exactly that pair for
   the last argument of every self tail call — a store and a load per iteration.
0c. ~~**The scratch pool routes through rax**~~ **DONE**, and not the obvious way: copying from
   the source register only made the caller's load DEAD, so `:c::fold` now takes the accumulator's
   register and the two paths that need rax load it themselves. to reach a register it could be given directly:
   `mov %r12,%rax` then `mov %rax,%r9`.
0d. ~~**C-149's rax tracking clears at a join**~~ **STRUCK: it fires nowhere.** Extending it to
   every symbol load left every binary byte-identical, because `:c::emit` clears the field and
   any two reads of the same name have an emission between them. Kept only because `:c::fold`
   needs `:c::reg-of-name` to ask the question. C-149's tracking was already at its useful limit.
   (original text:) **C-149's rax tracking clears at a join** and never learns what both paths agree on, so
   `mov %rbx,%rax` is emitted on both sides of a branch that did not change rbx.


3a. ~~**A share count that can come down.**~~ **RE-SCOPED 2026-09-19 by C-152.** The chunk
   accumulator recovered 94% of F-127's price (444,556 → 162,908 KiB) with no ownership analysis
   whatever, so **the compiler no longer depends on appending in place through a container field
   anywhere**. Decrements are still the honest answer to the question C-126 left open, and the
   text below is still the specification — but the motivation is now a USER-PROGRAM
   optimisation, not the thing the compiler is built out of. It has dropped below the compute
   items.

3b. **`:c::patch` is the largest single item in the compiler's memory now.** With the patch
   leaving the buffer alone the same compiler peaks at **146,612 KiB against 164,444 — 10.9%** —
   and 146,612 is exactly where the old UNSOUND rule sat, so a free patch would make the correct
   compiler as cheap as the incorrect one. It costs that because a patch needs the accumulated
   string WHOLE, and it needs it whole because **F-104**: no positional update, so a four-byte
   displacement cannot be written where it goes. Three routes, none needing a language change:
   flatten only the SUFFIX from the patch point (the distance is usually short); emit the
   placeholder as its own chunk and substitute by the `assocn.wat` fold; or compute forward
   displacements in pass one, since they are pass-invariant, and emit them directly in pass two
   with no patch at all.

3c. ~~**Short branch encodings.**~~ **SETTLED 2026-09-19, C-160.** The half worth having is
   taken: a branch over a NAME or a CONSTANT has a length bound without measuring, so no extra
   pass is needed — binaries ~5% smaller, the compiler **-1.0% cycles**, `fib` unmoved. The half
   that is not: bringing the overflow handler within reach of a two-byte `jo` by planting
   trampolines made `fib32` **9.5% smaller and 2.1% slower**, because five never-executed bytes
   at the head of a hot fetch region cost more than the four each `jo` gives back. Density is not
   a quantity to maximise. Original text:

   **Short branch encodings.** `elf/out/fib32.elf` decodes to 184 `jcc rel32` and 46 `jmp
   rel32`; **all 46 of the non-`jo` conditionals and 24 of the jumps are within rel8 range**,
   which is 256 bytes of a ~1,200-byte code section — about a fifth. The other 138 are the
   overflow `jo`, which needs a handler within 127 bytes to shorten and so wants a per-function
   trampoline. The obstacle is the two-pass invariant: choosing an encoding by distance makes
   the length depend on the distance, so it needs branch RELAXATION iterated to a fixpoint
   rather than a peephole. Measured, not guessed: the counter is in the entry.

(the original 3a text, which is still the specification:)

**A share count that can come down.** C-126 chose increment-only and said what it buys;
   C-128 and C-143 both named decrements as the next step, both for MEMORY. **F-127 makes it a
   correctness constraint**: without a count that falls, a compiled wat cannot both answer
   correctly and append in place through a container field, and the honest rule costs 3.06x peak
   memory to prove it, spread across THREE record-field accumulators (`:c::Out/code` 142,856 KiB,
   `:c::Out/tail` 80,480, `:c::PassR/code` and friends the rest) rather than the one the entry
   first claimed. Three repairs were tried on paper and all three hit the same wall — the
   container's own count is never 1, because `:c::push-args` increments every pointer-typed
   symbol argument. C-143 tried to make that a move and was reverted over four aliasing holes,
   which are written up in its entry and are the real specification for this work.
4. ~~**Frame-pointer elimination.**~~ **DONE 2026-09-19, C-155**, in three steps so the first
   one could be tested: track the depth and change no bytes, then address from rsp with rbp still
   maintained, then drop rbp and give it to the allocator. It is worth **-2.7% instructions and
   -1.8% cycles on the compiler and nothing at all on the benchmarks**, because the two halves
   cancel on anything call-heavy — dropping rbp removes two instructions per call and a fourth
   callee-saved register adds a push and a pop back. What it really bought is **a register that
   did not exist**, which is what a register calling convention will need. `clone` keeps its
   frame pointer: the child gets a fresh rsp and inherits rbp, and that is the only reason a
   spawned thread can read the frame it came from. Original text:

   **Frame-pointer elimination.** The measured cost is binding SPILLS: at inline depth 4 four
   levels are live at once and C-146 has three registers, because `rbp` is the frame pointer and
   `r14`/`r15` hold the buffer and the heap. Dropping `rbp` frees a fourth AND removes
   `push rbp` / `mov rbp,rsp` / `leave` from every call. The obstacle is real: expression
   evaluation pushes to the stack, so `rsp`-relative offsets move and the emitter would have to
   track push depth. Evidence: the disassembly in C-147's follow-up, `mov %rax,-0x20(%rbp)`
   followed by three reloads.
5. ~~**Rematerialise instead of spilling.**~~ **STRUCK 2026-09-19, and by its own neighbour.**
   It was named as "one `add` instead of a store and three loads". Two of those three loads were
   redundant reloads of a value already sitting in `rax`, and C-149 removed them: a spill now
   costs **one store and one load**, while rematerialising costs **one load and one subtract per
   read**. A tie at best and a loss when the value is read twice. Recorded rather than deleted,
   because the arithmetic that killed it is the useful part.
6. **Tail recursion modulo `+`, restricted.** `-O2` beats us partly by reassociating the
   additions, which is free in C (overflow is undefined) and unsound in wat (it traps) — see
   F-125. **But measure before building**: depth 2→4 removed four fifths of all calls for 26%,
   so ALL remaining call overhead is ~11% of the time. This cannot close 1.7x and is listed last
   for that reason.

**And a method note that outranks all of them.** This machine's run-to-run spread is ±15%, which
is larger than most effects now being chased. A sequential A-then-B measurement produced
`nregs=1` beating `nregs=2`, which is impossible. **Interleave A and B on two retained binaries
and take the minimum of many** — that is what gave the trustworthy 10% for C-146 and the wash
that kept C-136 standing.

## Where the book queue stands (2026-09-18) — **every numbered item is closed**

§1–§5 done, §6 declined, §7–§8 built as instruments, §9–§12 ported and complete. The list this
file was written to work through is finished; what follows is kept as the record of how each item
was settled, not as a queue.

**§4 is now finished too** (2026-09-18): 25 puzzles, 70 answers, against its stated ambition of
"one year" (C-114). Every suite in FINDINGS.md's status table reads complete. Project Euler (6
problems) was never a numbered item and has no stated end.

The measurement this file was queued on, 2026-09-16:

| era | findings | involving a port | probe of wat only |
|---|---|---|---|
| F/C-001…050 | 100 | 40 | 55 |
| F/C-051…075 | 25 | **18** | 6 |
| F/C-076…095 | 20 | 1 | **18** |

It said the namespace sweep was exhausted and that porting still worked, so §7–§12 returned to
porting. **That was right**: F/C-096 onward is almost entirely port-driven, and §12 alone produced
F-112 through F-117 plus C-098 to C-113 — including three findings (F-113, F-116, F-117) that no
probe of wat's own namespaces would have reached, because each needed a program large enough to
need the missing thing twice.

## Where §1–§6 stand (2026-09-15)

§1–§5 are done, each in its own directory with its own oracle, and all of them run under
`./run.sh`:

| | suite | result |
|---|---|---|
| §1 | Clojure Koans | `koans/` — 229 rows: 29 literal, 163 the wat way, 17 with no route, 20 refused by design (C-030) |
| §2 | Make-a-Lisp | `mal/` — 11/11 steps, 909 of mal's own tests (C-032) |
| §3 | SICP chapter 3 | `sicp/` — 4 chapters, 65 results against guile |
| §4 | Advent of Code | `aoc/` — **25 puzzles, 70 answers** against Clojure (C-114) |
| §5 | PAIP chapters 11–12 | `paip/` — 2 chapters, 58 results against guile (C-033, C-034) |

**§6, the Shield slice, is not being built** — the builder's call, 2026-09-15. It needs
`holon-lab-ddos` (a Clojure detection pipeline with known behaviour) and traffic to run it
against, neither of which is on this machine; and §6 names the builder as the only oracle for
the right answer, so there is no honest way to grade it here. `holon-rs` does carry the VSA
encoding, if the item is ever revived.

## 1. Clojure Koans / 4Clojure: is wat actually a Clojure dialect?

- **What:** hundreds of small problems, each already an assertion with a known answer.
- **Stresses:** breadth of Clojure semantics, form by form.
- **Why here:** the most direct acceptance test of the Clojure/EDN syntax migration. Each
  koan either ports close to literally or shows exactly where wat departs from Clojure.
  Output: a "ports literally / needs a wat idiom / impossible" table to set against the
  codemod work.
- **Lead:** wat-rs already has `tests/clj_expr_oracle/` (a `corpus.txt` turned up on
  2026-09-14; contents not yet inspected). If it is a Clojure-oracle harness, the koans
  slot straight in.

## 2. Make-a-Lisp (kanaka/mal): can wat build a language?

- **What:** a Lisp interpreter in 11 steps (reader, printer, environments, TCO, macros,
  try/catch, atoms, self-hosting). Every step ships an official test suite that checks what
  the interpreter prints for given input.
- **Stresses:** string parsing, recursive data, closures, error handling. The "atoms" step
  is mutable state, a natural test of state-on-services.
- **Why here:** there is a public scoreboard of about 90 host languages, so "wat passes
  step A" means something well known.

## 3. SICP, especially chapters 3–4: streams, state, the metacircular evaluator

- **Stresses:** lazy streams (§3.5) test `:wat::stream` properly. Chapter 3's bank accounts
  and queues test services as the home for state. The chapter 4 evaluator is a sequel to
  Little Schemer chapter 10.

## 4. Advent of Code — **COMPLETE: 25 days, 70 answers (2026-09-18)**

- **What:** real input files, parsing, grids, hash maps, and a known right answer for every
  puzzle.
- **Stresses:** what the textbooks never touch: reading files, splitting strings,
  performance. `wat`'s startup (~350–450ms per run on the i7-1270P laptop) will show up.
- **Answered (C-114).** Startup is 0.29 s, a fifth of the JVM's, and never the problem. Size is
  fine — 20000 sorted and mapped in 3.9 s. What costs is REBUILDING: the four slowest puzzles all
  rebuild per element, which is F-104 and F-116. The most expensive single gap for ordinary work
  is F-061: seven validation rules that are one-line regular expressions elsewhere are 150 lines
  of wat against 60 of Clojure.

## 5. Norvig's PAIP — **COMPLETE: 20 of 20 portable chapters (2026-09-16)**

- **Stresses:** heavy symbolic pattern-matching, which is where quoted data versus typed
  data gets decided. Pairs naturally with The Reasoned Schemer.

**Builder's ruling, 2026-09-16:** *"i think we just get full coverage - prove we handled all of
the books' various nuance, not just arguing 'meh, they're the same'"*. PAIP was probe-driven (two
chapters chosen to press quoted data); it becomes a full port.

**PAIP is 25 chapters, and several are about Common Lisp itself rather than about an algorithm.**
Those are listed below as **no portable content** rather than dropped silently — the same
treatment Okasaki ch 1 got (C-075). A chapter that teaches `loop`, `declare` or ANSI CL packages
has nothing to port to wat, and saying so is a decision on the record.

| ch | topic | status |
|---|---|---|
| 1 | Introduction to Lisp | **no portable content** — Common Lisp syntax and evaluation |
| 2 | **A Simple Lisp Program** | **done** (C-082) | hits F-036 head-on; threading the seed made it testable |
| 3 | Overview of Lisp | **no portable content** — a tour of CL's own primitives |
| 4 | **GPS** | **done** (C-082) | means-ends analysis; the bugs tested as carefully as the successes |
| 5 | **ELIZA** | **done** (C-083) | segment variables, backtracking over splits |
| 6 | **Building software tools — search** | **done** (C-083) | four searches, one program; depth-first is DEARER here (29 vs 19) |
| 7 | **STUDENT** | **done** (C-085) | `isolate` is correct only under a precondition its own code never checks |
| 8 | **Symbolic mathematics** | **done** (C-083) | a rule table is open to new rows and closed to new KINDS of question |
| 9 | **Efficiency issues** | **done** (C-084) | transparent `memoize` IS writable (an Lru in a closure); it is allowed to FORGET, hence P-028 |
| 10 | Low-level efficiency | **no portable content** — CL declarations and open-coding |
| 11 | **Logic programming** | **done** (C-033) |
| 12 | **Compiling logic programs** | **done** (C-033) |
| 13 | **Object-oriented programming** | **done** (C-085, F-109) | `defclause` IS multiple dispatch — this row first said the opposite; see F-109's retraction |
| 14 | **Knowledge representation** | **done** (C-086) | override and cycles; F-057's visited set is load-bearing for TERMINATION here |
| 15 | **Canonical forms** | **done** (C-089) | the best pairing with ch8: an identity becomes checkable rather than provable |
| 16 | **Expert systems** | **done** (C-089) | certainty factors; a range [-100,100] the type system cannot say |
| 17 | **Constraint satisfaction** | **done** (C-089) | decided / impossible / ambiguous all tested; F-104's purest case |
| 18 | **Othello** | **done** (C-086) | alpha-beta 37 nodes against minimax's 73; F-104 lands on a game board |
| 19 | **Natural language** | **done** (C-090) | ambiguity: two parses, and the TREES differ |
| 20 | **Unification grammars** | **done** (C-090) | agreement by unification; one rule where a CFG needs two |
| 21 | **A grammar of English** | **done** (C-090) | subcategorization and relative clauses |
| 22 | **Scheme: an interpreter** | **done** (C-087) | the interpreted language gets `call/cc`; a value domain with continuations cannot cross a service boundary |
| 23 | **Compiling Lisp** | **done** (C-088) | peephole: 7 instructions to 3; a compiler pass is almost entirely cases |
| 24 | ANSI Common Lisp | **no portable content** |
| 25 | Troubleshooting | **no portable content** |

**COMPLETE — 20 of 20 portable chapters done.** The five marked *no portable content* teach Common Lisp itself. Oracle: our own Scheme on each chapter's topic, run by guile
(`tools/paip-oracle.sh`). Norvig's own code is never read or copied.

## 6. Capstone: a slice of the builder's own Shield packet detector

- **What:** take a detection pipeline already built in Clojure, with known behaviour (e.g.
  a rate or entropy anomaly detector over a packet stream). Port it to wat using streams,
  services and holon's VSA encoding, then compare outputs on the same traffic.
- **Why:** every test above measures wat against a textbook; this one measures it against
  its purpose. The builder is the only oracle for the right answer, which makes it a true
  user acceptance test rather than a benchmark.
- **Lead:** `holon-lab-ddos` presumably already has pieces of this. It is not cloned on the
  daily driver yet.

## 7. A performance baseline, before the byte-code work — **DONE 2026-09-16** (`BASELINE.md`)

The builder's next phase is "byte code" / a jump DAG. A before/after can only be captured
**before**, and the numbers are currently scattered across the ledger:

| | measured |
|---|---|
| a message to a service | 224 µs, ~100 function calls (F-051) |
| the formatter | ~10 KB/s, ~800 ms fixed floor (F-075) |
| deporder over the same kind of source | ~1 MB/s (C-050) — 100× the formatter |
| `bracket::map`, thread pool | 1.69× on 16 runners, vs 5.90× for OS processes (F-094) |
| copying vs sharing containers | 135 s → 20.6 s on one AoC day (F-057) |
| the interpreter | 100–430× the JVM, 13× guile, >100× Racket |

**Deliverable:** `bench/` plus `tools/bench.sh`, one runnable suite emitting a dated table, so
the jump-DAG work has a baseline to be measured against. Nothing else here expires.

## 8. Turn the repo into a regression instrument — **DONE 2026-09-16**

17 oracle scripts exist; the recent ones (`doc-names-audit`, `cli-surface`, `fix-roundtrip`,
`bracket-os-oracle`) are reproducible *measurements* rather than one-shot investigations.

**Delivered:** `./audit.sh` runs `tools/recheck.sh`, `tools/doc-names-audit.sh`,
`tools/cli-surface.sh` and `tools/bench.sh` against any build and emits a dated report;
`--full` adds the slow ones (`fix-roundtrip`, `bracket-os-oracle`).

`tools/recheck.sh` is the signal. A probe *documents* a defect — it passes while the defect is
present — so "did the probe pass?" is the wrong question. Each check is instead a minimal program
plus the verdict expected **while the finding is open**, and a flip means the status changed.
11 checks at first run: `OPEN=11 FIXED=0`, which is correct for an unchanged build.

Two things were got wrong building it, both now fixed in place: the F-096 check did one accessor
per iteration and reported **FIXED** because the 3.6 µs loop overhead compressed a real 5.0× to
2.15× (the harness's own lesson, violated one file over); and an attempt to auto-detect
arity-specific retirements failed because a generic re-probe cannot know whether a verb takes
positional or keyword arguments — it is now an explicit, documented list of one.

**Still to add:** checks for the findings without a crisp machine-checkable signature. 11 of
~96 are covered.

## A pattern in §10 and §11, worth naming (2026-09-16)

Both ports stopped early, and for the same *kind* of reason — not "wat is slow at this" but
**"the mechanism the book is built on does not exist"**:

| | stopped at | because |
|---|---|---|
| §10 Okasaki | ~~ch 5 of 11~~ → **ch 7**, once a suspension was built | F-100 was the block; `lib/susp.wat` (P-027's stand-in) removed it |
| §11 Downey | ch 3 of ~15 | **F-102** — a service cannot release a held caller, so every blocking primitive is a spin |

That is a better outcome than finishing either book would have been. Both findings are single,
sharp, load-bearing gaps that each unlock a whole half of a textbook, and both were reached within
three chapters. The remaining chapters would have re-measured the same absence five or ten times.

It also sharpens how to choose the next port: **pick the book whose central mechanism wat already
has**, so the port tests wat's quality rather than re-discovering one missing primitive. On that
test §12 (a bytecode VM: a flat instruction array, a dispatch loop, an explicit stack) is the
safest of the remaining candidates — it needs no laziness, no blocking, and no deep recursion,
which also routes around F-099.

## What this repository already knows that bears on a CEK evaluator (2026-09-16)

The builder names a CEK machine as a long-term goal, 6+ months out. Several things measured here
bear on it directly, so they are collected rather than scattered.

**`eopl/lib/cps.wat` is already a CEK machine.** `State` is Control + Environment + Kontinuation,
`step` is the transition function, `drive` is the trampoline. It is small (about 90 lines) and it
runs, so it is available as a shape to argue with.

| what is known | where | why it matters for CEK |
|---|---|---|
| a non-tail recursion past ~110000 frames **segfaults**, exit 139, empty stderr | F-099 | **this is the reason to do it.** A CEK evaluator puts wat's own evaluation depth in the heap, so the ceiling becomes available memory and the failure becomes catchable rather than SIGSEGV. Not a patch — the defect ceases to exist |
| wat's TCO is preserved **through** an interpreter written in wat | C-061 | the hard part of a CEK migration is not pushing a K frame for a tail call. The current implementation already identifies tail position correctly, even across an interpreter boundary — that discipline is in place before the rewrite starts |
| builtin 360 ns · match-2 675 ns · user-fn 795 ns · **defrecord accessor 6130 ns** | `BASELINE.md`, F-096 | the before/after. §7 was taken for exactly this, *before* the byte-code work, because it cannot be taken afterwards |
| a **record** field holding a user enum deep-copies; an **enum variant** shares | F-098 | a K chain is literally "an enum holding the rest of the chain". If a K frame were a record, every push would copy the tail and the machine would be O(n²). Fatal if any of the machinery is written in wat; irrelevant if it is all Rust |
| a CEK transition in wat-the-language costs **~14 200 ns, flat** over 36k–576k transitions | measured here | not what wat-rs would reach in Rust, but the flatness confirms the shape is O(1) per step, and ~18-20 dispatch operations per transition is a sanity check for sizing |

**One opportunity, not a requirement.** R-003 records that wat has no `call/cc`. A CEK machine
makes the continuation a first-class value by construction, so that capability would fall out of
the rewrite rather than needing to be added to it.

## §9–§12: four books, ranked by what they'd stress

Not ranked by how good the book is — by which part of wat each one puts under load. The
Friedman books tested wat as a **Lisp**; these test it as a language host, a container library,
a concurrency runtime and a compiler target respectively.

| | book | what it stresses | why now |
|---|---|---|---|
| §9 | **EOPL** (Friedman & Wand) | wat as a **language host** | the big uncovered Friedman; everything else in the roadmap sits on it |
| §10 | **Okasaki** | the **container** story | lands on defects already measured: F-057, F-055, F-023, the missing persistent set |
| §11 | **Downey, Semaphores** | the **concurrency** runtime | F-094 left a live question; rare self-oracling corpus |
| §12 | **Crafting Interpreters II** | wat as a **compiler target** | rehearses the jump-DAG shape §7 baselined |

**If only one: EOPL.** It is Friedman, it is big, it is uncovered, and it exercises the part of
wat that everything else here depends on. The execution order below still opens with §10, because
Okasaki aims at defects that are already measured and so pays back fastest — EOPL is the largest
investment, not the first one.

## 9. EOPL — *Essentials of Programming Languages* (Friedman & Wand) — **COMPLETE — 22 of 22 languages/topics done**

**Scope correction, 2026-09-16.** What is done is a *slice* of ch 3 (the LETREC language) and a
*slice* of ch 5 (the CPS interpreter). That is two machines over one language — enough to produce
C-061, not enough to call the book ported. EOPL is nine chapters:

| ch | language / topic | status | note |
|---|---|---|---|
| 1 | **inductive sets of data** | **done** (C-074) | follow the grammar — enforced by exhaustive match, not remembered |
| 2 | **data abstraction, environment representations** | **done** (C-074, F-107) | one client, three representations incl. a closure; the surface encoding is refused (F-029) |
| 3 | **LET** | **done** (C-074) | built separately, per the no-skipping ruling |
| 3 | **PROC** | **done** (C-074) | two productions and one Val variant — which is what makes Val and Env mutually recursive |
| 3 | **LETREC** | **done** (C-061) | the language the three machines run |
| 4 | **EXPLICIT-REFS** | **done** (C-066) | store threaded as a PersistentMap; mutation priced three ways |
| 4 | **IMPLICIT-REFS** | **done** (C-068) | every variable is a reference; `deref` never written |
| 4 | **MUTABLE-PAIRS** | **done** (C-069) | a pair is two adjacent cells; aliasing needs no new machinery |
| 4 | **call-by-name / call-by-need** | **done** (C-062) | by-name O(n²) vs by-need O(n) |
| 4 | **call-by-reference** | **done** (C-068) | the whole switch is one predicate: is the argument a bare variable? |
| 5 | **CPS interpreter** | **done** (C-061) | lifts F-099's ceiling |
| 5 | **exceptions** | **done** (C-065) | a handler is a continuation frame |
| 5 | **threads** | **done** (C-064) | the mutex wat itself cannot express |
| 6 | **CPS transformation** | **done** (C-070) | source to source; the ceiling moves 20000 -> 100000+ under the SAME interpreter |
| 6 | **registerization** | **done** (F-105) | costs ~1.9x in wat: `step` must allocate the State it returns. Mutual TCO holds to 10M, so it is a choice |
| 7 | **CHECKED** (a checker over annotations) | **done** (C-067) | rejects wrong annotations; inference cannot |
| 7 | **INFERRED** (reconstruction by unification) | **done** (C-063) | unification, occurs check |
| 8 | **simple modules** | **done** (C-071) | `from m take x` consults the interface, never the body |
| 8 | **opaque types, parameterized modules** | **done** (C-071, F-106) | `opaque t` vs `transparent t = int` is one word and decides everything; wat has `newtype`'s distinctness but no sealing |
| 9 | **CLASSES** | **done** (C-072) | `c2.m2`=23 and `c2.m3`=11 — same method name, two starting points for the walk |
| 9 | **TYPED-OO** | **done** (C-073) | subsumption; and wat's surfaces already give the interface half, heterogeneous dispatch included |

**Builder's ruling, 2026-09-16: no skipping.** *"I think the cost of duplication is worth coverage
of the books. I'd rather not have omissions in the books."* This repository is the validation
testbed for the Clojure-ification, so a gap in coverage is a gap in validation — an argument that
overrides "chapter 6 overlaps §12" and "Little Java already did OO".

**Correction that ruling forced.** I had been skipping *within* chapters as well as between them
and reporting the chapter as done: chapter 7's **CHECKED** language was never built (only
INFERRED), and chapter 4 had IMPLICIT-REFS, MUTABLE-PAIRS and call-by-reference outstanding. Both
holes are now closed (C-067, C-068, C-069); the table above is the honest state.

**Order from here:** ~~ch 4~~ (C-068, C-069) and ~~ch 6~~ (C-070, F-105) are **complete** as of
2026-09-16, and so are ~~ch 8~~ (C-071, F-106), ~~ch 9~~ (C-072, C-073) and ~~ch 1-3~~ (C-074,
F-107). **EOPL is finished — 22 of 22, nine chapters, no omissions.** The no-skipping ruling cost
four extra languages that a "close enough" reading would have dropped (ch7 CHECKED, ch4
MUTABLE-PAIRS, ch3 LET and PROC), and two of them paid for themselves: CHECKED produced C-067 and
ch2's dictionary produced **F-107**, a fresh defect found in a chapter I would otherwise have
skipped as covered. **22 of 22 done. The book is complete.** No skipping.

The big uncovered Friedman. Interpreters, type checkers, continuations, stores, an
explicit-control evaluator — incremental, every chapter runnable, and it tests wat as a
**language host**, which is what the rest of the roadmap sits on. Oracle: the book's own
expected values, and Racket/guile for the reference implementations.

## 10. Okasaki — *Purely Functional Data Structures* — **ch 2–11 DONE 2026-09-16 — the queue and list line of the book is complete**

**Coverage audit, 2026-09-16.** This section had said "ch 2, 3, 5–11" and called itself complete.
Chapter 4 (LAZY EVALUATION) was missing: `okasaki/lib/llist.wat` had the operations, and every
later chapter's header cites "ch 4 LAZINESS", but the chapter that CHECKS the incremental /
monolithic distinction had never been written. Now `okasaki/ch04-lazy-evaluation.wat` (C-075).
**Chapter 1 is the book's introduction and has no data structure to port** — stated here so its
absence is a decision on the record rather than another silent gap.

~30 structures, each small and runnable, each with a stated amortized bound. Lands directly
on the weak spot this repo has already measured: F-057 (copying vs sharing containers), F-055
(`rest` clones, so walking is quadratic), F-023 (`conj` clones), and the **missing persistent
set** (a visited set has to be a `PersistentMap` to `true`). Laziness and amortization are
wat's `:wat::stream::` territory, which F-088 showed is documented as an API that does not
exist. Oracle: the book's bounds, and timing curves rather than single points (C-050's method).

## 11. Downey — *The Little Book of Semaphores* — **COMPLETE, ch 1-7 (2026-09-17)**

**The "blocked past ch 3 by F-102" label was wrong** (2026-09-17). F-102 makes every wait a spin,
which is expensive, not impossible — `semaphores/lib/sem.wat` is a counting semaphore built that
way, and every pattern in the book is a composition of it. What the spin costs is reported by each
puzzle as a poll count, which is the only thing these ports measure that a language with blocking
would not have to.

~30 concurrency puzzles with known-correct answers **and** known failure modes — a rare
**self-oracling** corpus, where a wrong implementation fails in a way the book already names. F-094 measured `bracket::map`'s thread pool at 29% of what the
same machine does with OS processes, so this is a live battleground. **No networking** — the
builder's call, 2026-09-16: networking is simulated via IPC anyway (processes over unnamed
Unix domain sockets, threads over crossbeam-style channels), so the puzzles run against
`:wat::spawn::`/`:wat::bracket::`/`:wat::service::` directly.

## 12. *Crafting Interpreters*, Part II — the bytecode VM — **COMPLETE 2026-09-18, ch 14-30, 17 programs**

Chapter 30 was recorded here as "no portable content" and that was half right: the content does not
port (NaN boxing, a hash-table bitmask) and the METHOD does. Re-reading the ruling — which C-103
is the standing reason to do — produced C-113, which **reversed a recommendation made on this
page** about the VM's stack type.

A flat instruction array, a dispatch loop, a value stack, jump patching. Not for the book's
sake: it rehearses the exact machinery §7's baseline is being taken for, and it tests whether
wat can host the shape of its own next phase.

**Three numbers this section already has, before a line is written.** They are the reason to do
it in this order rather than first:

| | |
|---|---|
| **C-081** (SICP §5.5) | the same expression costs **11** machine steps interpreted and **8** compiled, from 3 top-level instructions. The payoff of compiling, as a count |
| **F-105** (EOPL ch6.5) | `step : State -> State` is **~1.9×** slower than mutually tail-calling procedures, because `step` must allocate the state it returns. The registerized shape is the slower one |
| **BASELINE.md** | builtin 360 ns, match-2 675, user-fn 795, closure 853, defstruct accessor 1219, **defrecord accessor 6130** — so the dispatch loop's own arithmetic has a floor |

**Chapter table.** Nystrom's Part II is chapters 14–30. Several are about C rather than about a
VM, and are listed as **no portable content** rather than dropped silently — the treatment Okasaki
ch 1 and PAIP's CL chapters got.

| ch | topic | status |
|---|---|---|
| 14 | **Chunks of bytecode** | **done** (C-098) | an opcode is an enum carrying its operand; offsets count instructions, not bytes |
| 15 | **A virtual machine** | **done** (C-098) | **registerized costs ~2.3-2.5x; hoisting the chunk out of the loop saves ~30% more; they compound to 3-4x** |
| 16 | **Scanning on demand** | **done** (C-099) | 38 token kinds, all asserted produced; on-demand pull works (8 tokens < a tenth of the file); **record-per-character vs record-per-token is ~2.5x**, and F-062 leaves no hoist available |
| 17 | **Compiling expressions** | **done** (C-100) | the compiler reproduces ch14's hand-built chunk exactly and ch15's VM gives ch15's answer; the rule table of function pointers was built in a probe — `defstruct` row works, `defrecord` row refused (F-114) |
| 18 | **Types of values** | **done** (C-101) | a tagged union is a `defenum`; `valuesEqual` is `(= a b)` (F-019 clarified); Nystrom's NaN bug in `<=` reproduced; runtime errors are a `Step.Fail` value, one match per instruction. Runs on `:loxv::` so ch15's measurements keep their code |
| 19 | **Strings** | **done** (C-102) | one enum variant and one `string::concat`; `Obj`/`ObjString`/`freeObjects` are C's memory management. Debt: ch26's collector must build its own heap |
| 20 | **Hash tables** | **done** (C-103) — **the earlier ruling was half wrong** | the table itself is not worth rewriting (C-078 priced wat's two), but the chapter's **interning** is a language decision, and its cost claim is about a C program: measured, it buys **nothing at 10 characters** and about a quarter at 100 000 |
| 21 | **Global variables** | **done** (C-104) | statements, a globals table, assignment as an expression, `synchronize()` counted rather than assumed; `canAssign` checked on five invalid targets. Cost: **F-115** |
| 22 | **Local variables** | **done** (C-105) | a local costs no instruction to create, checked through the emitted code; both compile errors checked; `OP_SET_LOCAL` is F-104 in an inner loop (76 µs at one local, 404 µs at forty) and the probe it prompted found **F-116** |
| 23 | **Jumping back and forth** | **done** (C-106) | the backpatch chapter 14 predicted: a patch rebuilds the code vector, **~7 µs per instruction already emitted**, so patches are quadratic in program length (90 `if`s: 1.06 s against 0.16 s) |
| 24 | **Calls and functions** | **done** (C-107) | functions as values with their own chunks, a stack of compilers, call frames. A frame is allocated per **call**, not per instruction, so it cost less than ch22-23. A native is a name, not a closure (F-114). Two checks pin the ch24/ch25 boundary |
| 25 | **Closures** | **done** (C-108) | the one chapter whose DESIGN had to change: an upvalue is a `Value*` into the stack, and wat cannot share a mutable location, so the pointer became an index into a VM-owned cell table. Sharing, non-sharing and closing all checked |
| 26 | **Garbage collection** | **done** (C-109) — and it was more than "partly covered" | chapter 25's cell table was a **real leak**, so this is mark-sweep over something that actually needed collecting: 30 cells with the collector off, 8 with it on. Every root checked, marking transitive |
| 27 | **Classes and instances** | **done** (C-110) | `var a = f; a.x = 2; print f.x;` forced the **second** VM-owned index table in three chapters — **F-117**. A class needed none of it: immutable once declared |
| 28 | **Methods and initializers** | **done** (C-111) | cost **nothing** — `this` is local slot 0, so a closure inside a method captures it like any other local. `init` differs in exactly two compiled details |
| 29 | **Superclasses** | **done** (C-112) | `super` checked to be **lexical** through a three-level hierarchy: `CBA` with a C receiver. `OP_INHERIT` is `OP_METHOD`'s move again |
| 30 | **Optimization** | **done** (C-113) — the content does not port, the **method** does | NaN boxing and the hash-table bitmask are about C; benchmarking before optimising is not, and it **reversed a recommendation made on this page** (see below) |

**A recommendation this page made and chapter 30 reversed.** `probes/lox/stack-ops.wat` (F-116)
showed that a `Vector`'s rebuild-pop is quadratic where a `PersistentVector`'s is linear — 121 ms
against 34 ms for one pop at depth 4000 — and this page concluded that the lox VM's stack should
therefore be a `PersistentVector`, listing the switch as work to do. **It should not.**
`probes/lox/stack-mix.wat` runs the operation mix a VM actually performs at the depths it actually
reaches, and the `Vector` wins at every one of them: 89% of the cost at depth 4, 80% at 32, 82% at
128, crossing over only past 256. `PersistentVector`'s `get` answers an `Option`, and the unwrap on
every read costs more than the clone it saves. F-116's numbers stand; the advice did not (C-113).

**Oracle.** Unlike the other suites there is no second implementation to compare against: the VM
IS the thing being tested. So each chapter checks its own invariants — a program's value, the
instruction count, the stack's high-water mark — and where a result can be cross-checked against
an existing port (SICP §5.5's compiler, C-081) it is.

## Suggested order — **spent 2026-09-18**

The order this section recommended was §7, §8, then §10, §11, §9, §12. That is the order it was
done in, and every item is closed. The ordering advice is kept because its reasoning still holds
for whatever comes next: instruments before ports, ports aimed at defects already measured before
ports chosen for being books, and the largest interpreter last so it can be written against
whatever the byte-code work has become.

A note on spelling, 2026-09-16: the builder expects to drop the o.g. wat syntax for a
Clojure/EDN-compliant scheme within weeks, with "typed Clojure" as the end game. New ports
should be written in whatever spelling is current and **not** hand-tuned for the migration;
`tools/fix-roundtrip.sh` already exists to convert the corpus and differential-test the result
when the flip lands.
