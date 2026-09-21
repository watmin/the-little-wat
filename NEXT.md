# After Friedman: more acceptance tests

Queued for once the Friedman books are exhausted. Each one tests wat against something
with a known right answer, and each leans on a different part of the language. The same
rules apply as for the books: every gap goes into FINDINGS.md with a repro, and code is our
own, not copied from the sources.

Ordered by how directly each tests what wat claims to be.

## elf/ — the live queue (2026-09-20, HEAD 819be1c)

**This section is a MAP, not the truth.** The truth is `FINDINGS.md` and the git log; every line
below names where to read and is deliberately too short to stand in for the reading. If it ever
grows long enough to feel like sufficient orientation, prune it — that feeling is the failure.

**Freshness probe:** written against **HEAD `819be1c`**. `git log --oneline -1` must print that
sha. If it prints anything else this map is stale: trust the git log and `FINDINGS.md` over every
line below, and read the newest entries before you move.

**THE TOOLCHAIN MOVED.** `elf/` now measures against wat-rs branch **`the-little-wat`** (commit
`7dee55858`), not `main` — it carries clj's seven bitwise ops, which C-171 needed and which do not
exist on main. `run.sh` prints the rev it ran against; if it says something other than a
`the-little-wat` commit, the bit-op programs will not load. The branch is **strictly additive**
by rule, so every finding written before it stays valid. If `git log --oneline -1` says
something else, trust the log and `FINDINGS.md` over every line here, and re-read the newest
entries before moving.

### Where we stand against `gcc -O2`

| | ours | gcc | ratio | shape |
|---|---|---|---|---|
| size, a program that prints 4 | 611 B | 968 B | **0.63x** | we win |
| buffered output, 100k integers | 5.5 ms | 11.6 ms | **0.47x** | we win |
| `loopsum` — latency-bound loop | 218M cyc | 304M | **0.72x** | we win |
| startup, tail calls | — | — | 1.00x | tie |
| `triple` — throughput-bound loop | 151.5M cyc | 110.8M | **1.36x** | behind |
| `fib32` — call-heavy | 15.0M cyc | 9.8M | **1.52x** | behind (but see below) |

**`gcc -O2` is not the only yardstick, and on `fib` it is the wrong one** (F-132). Against C
compilers held to **wat's trapping semantics** we are **2.46x** faster than `clang` and **3.22x**
faster than `gcc -ftrapv`; we beat **`clang -O2` by 1.37x** while trapping, which it does not.
`gcc -O2`'s lead comes from reassociating the additions into a loop — 364,490 calls against the
naive 7,049,155 — which survives `-fwrapv` and **dies under trapping**, because `(a+b)+c` traps
where `a+(b+c)` does not.

### The three rules the measurements have settled

1. **The binding constraint depends on the SHAPE of the code** (C-153, C-164). Latency-bound
   loops hide our extra instructions; throughput-bound ones do not; call-heavy code is bound by
   neither.
2. **On front-end-bound code the unit of cost is a TAKEN BRANCH, not an instruction** (C-167).
   Nine `fib` experiments removed work and were paid nothing; the two that removed control flow
   were paid in full — shrink-wrapping -11.2%, the `jcc`+`jmp` collapse **-22.1% for -4.6%
   instructions**.
3. **An optimisation that is free in C may be illegal for us, because our arithmetic traps**
   (F-131, F-132). Strength reduction swaps an `imul` for a `sub` and gcc owes nothing while we
   still owe the `jo`; reassociating a sum is what gives `gcc -O2` its `fib`, and trapping
   forbids it outright. **When a C compiler is ahead, check what semantics bought it** before
   treating the gap as our defect.

### The compiler is three files now (C-174)

`elf/compile.wat` 4,055 · `elf/lib/x86.wat` 498 · `elf/lib/runtime.wat` 637. Cut where `partire`
found the seams, not by size. **Read the module you need, not the file**: an instruction or an
addressing mode is `lib/x86.wat`; a support routine or a heap layout is `lib/runtime.wat`;
everything about the wat dialect is `compile.wat`. Neither lower module names `:c::Prog`,
`:c::Env`, `:c::Out`, `:c::Kids` or `:c::Bnd` — that grep returning 0 is what makes the seam real,
so keep it at 0.

### In flight (2026-09-20)

**READING IS O(n) NOW (F-139).** The reader indexes by BYTE -- `byte-at`/`byte-length`/
`byte-subs`, three O(1) verbs on wat-rs branch `the-little-wat`. Compiled compiler **730 -> 509
ms**; stage 0 296 -> 286 s. In the compiler the three are ALIASES (`:c::strlen?`, `:c::subs?`,
`:c::codeat?` take both spellings) because a String on this heap is already a byte count followed
by its bytes.

**And the split turned out to be semantic.** `(wat.string/length "héllo")` is 5 interpreted and 6
compiled; the byte family is the only one that agrees. **The byte family is PORTABLE, the char
family is FRIENDLY** -- reach for bytes in anything that must mean one thing in both worlds, and
for chars in anything user-facing. Still open, named in F-139: `Value::String` carries no cached
char count or ASCII flag (414 sites), and the emitted runtime does not know UTF-8 at all.

**Converting the 33 `:c::rt-*` routines from hex blobs to composed expressions.** Sixteen done
(`hexchar`, `hexval`, `i64-quot`, `i64-rem`, `flush`, `node-copy`, `str-starts`, `str-eq`,
`vec-new`, `varr-new`, `node-new`, `tree-get`, `print-bool`, `str-contains`, `buf-put`,
`slot-set`); **17 left**, biggest last (`vec-conj-own` 240 bytes, `prim-read-hex` 227,
`tree-push` 199, `io-read-file` 175, `prim-write-hex` 163, `print-str` 147, `i64-to-str` 138).
Next by size: `str-cat-own` 79, `str-subs` 79, `die` 81, `print-i64` 87.

The encoder carries a full 16-register file, a general memory-operand layer (ModRM+SIB, all four
addressing shapes), forward and backward jumps, operand sizes (32/16/8-bit stores, which needed
a REX that can be OMITTED -- REX.W is exactly what makes a store 64-bit), and
`rep movsq`/`rep stosq`/`repz cmpsb`/`syscall`/`leave`.

**`def` was weighed and is not a speed lever** (2026-09-20). 57 zero-arg constants are spelled as
function calls, and wat-rs HAS `:wat::core::def` -- but a `def`'d name is a SYMBOL LOOKUP, and the
reader profile puts `env_key` + `Environment::lookup` at ~15% already, so it moves cost rather
than removing it. Measured directly, the difference was below the noise floor (+-25% run to run).
And `def` cannot memoize: the source is explicit that it binds an UNEVALUATED expression consumed
at registration, so the expensive things here -- a routine's hex, the runtime block -- which
depend on arguments, are out of its reach entirely. Worth doing for legibility, not for speed.

**TIME EACH BATCH, do not trust green.** F-137 is exactly this change regressing 5x while all 68
binaries stayed byte-identical and the fixpoint held. `tools/bootstrap.sh --fast` prints the
compiled compiler's own time; it was 613-643 ms across this batch.
**The oracle is exact**: a pure encoder change must leave all 68 binaries byte-identical, and
`tools/bootstrap.sh` checks that. Every step so far has held.
Next after the conversion: **breadth on records and memory vs C** — strings were measured in
F-135; records and memory are still completely unmeasured, and they are what an XDP driver is
made of.

### Open — correctness

* **Two `defn`s may share a name.** `:c::buf-len` was defined twice (the compiler's own output
  buffer, and a new runtime header offset) and nothing objected until a CALL SITE tripped on the
  arity: `cannot compile wrong number of arguments: (:c::buf-len)`. Whether wat-rs's checker
  catches a duplicate top-level `defn` at all is **unprobed** — worth a probe, because the failure
  currently surfaces arbitrarily far from the cause.

* **`999999` as "name not found"** and the **`"vec:"`/`"rec:"` string-tagged type encoding**
  (C-139). A magic number where an `Option` belongs, and a record wearing a string. C-170 declined
  to repeat the pattern — its "unknown" is the lattice top, not a sentinel — so the shape of the
  fix is now demonstrated in the same file.

### The strategy, after F-132 and F-133

**Against `gcc -O2` we already win three of six**: size 0.63x, buffered output 0.47x, `loopsum`
0.72x. We lose two, and both losses have a named cause that is **semantic, not a defect**: the
surviving overflow checks (`triple`) and the calls that reassociation would remove (`fib`).

So superiority is not forced by re-fighting `gcc -O2` on transforms our contract forbids. It is
forced on **the levers that are ours and not gcc's**:

  * **whole-program, no ABI, no separate compilation** — our calling convention, register
    allocation and layout are decided with the entire program in hand;
  * **we emit the ELF ourselves** — no assembler and no linker, so code placement and alignment
    are ours to choose, and F-132 measured that placement is worth up to 25% on an *identical*
    instruction stream;
  * **no libc** — 70 bytes of runtime against glibc, which is where size and I/O are already won;
  * **stronger semantics give us facts** — C-170 elides checks using bounds a C compiler has no
    reason to compute.

**And the untested ground is where the goal actually lives.** All six benchmarks are arithmetic
micro-loops. Nothing has measured wat against C on strings, records, memory traffic or syscalls —
which is what an XDP driver is made of, and where a 70-byte runtime and no libc should tell most.
**Breadth on realistic shapes is the next move, not another peephole on fib.**

### Open — performance, with what each is worth

* **`triple`'s three surviving `+` checks.** F-130 prices all overflow checks at 32% of that loop;
  C-170 took the four an interval analysis can reach. The remaining three are **unreachable by
  intervals** — the accumulators climb 89M an iteration and never converge (probe in C-170).
  Closing them needs a different instrument (summing the progression). **Nothing in the corpus
  asks for that yet, so it is named, not queued.**
* ~~**`fib` at 1.50x**~~ **CLOSED 2026-09-20, F-132 — it was never the holdout.** `fib` runs at
  **~0.40 taken branches per cycle whoever compiles it** (five builds, ours and gcc's, all on the
  line), and our 1.47x more taken branches IS the 1.50x cycle gap. Of our 6.10M taken branches,
  **3.5M are one per leaf and irreducible** (fib(32) has fib(33) = 3,524,578 leaves); the other
  2.60M are `call`+`ret`. So the only compressible quantity is the call count, and the transform
  that would cut it — reassociating the sum — **is illegal under trapping arithmetic**. Deeper
  inlining is measured and priced: depth 6 is -5.2% cycles for **3.5x the code** and **+22%
  compiler time**, which fails the UX question. Depth 4 stays. **F-133 then computed the floor:
  the 3,524,578 leaf tests are irreducible, so even with ZERO calls the best possible is
  8,687,816 cycles = **0.88x gcc** — the entire headroom on this program is twelve percent, and
  `gcc -O2` is already sitting on it. Call-site base-case peeling was priced too: it halves the
  calls exactly and is still only **-4.9% for +52% code**, because the peel test is itself a
  taken branch. `fib` is CLOSED as a performance item — finished, not hard.
* **F-129, the inline cliff.** `:c::inl-limit` counts SOURCE NODES, so naming an intermediate
  (30 nodes -> 35, limit 34) costs **2.26x cycles**. Raising the limit is not the fix — the corpus
  at 60 grows five programs by +62% to +118%. **Charge for generated code, not syntax.**
  `elf/bench/fibreg.wat` keeps it measured.

### Rules that bite, learned the hard way

* **R-005** — `timeout -s KILL`; SIGTERM does not stop a busy wat program.
* **R-006** — never time the compiler where it lives; it cannot rewrite its own running image, and
  the crash reads as a fast run. Use `tools/cc-time.sh`, which refuses to time a failure.
* **C-163** — interleave, minimum fourteen repetitions. A single run is not a measurement; one
  cost this queue a 10-point mis-prediction on 2026-09-20.
* Run `tools/bootstrap.sh` **without** `--fast` before committing, and never edit the tree while
  it runs — stage 0 and stage 1 would compile different sources.

### Settled, with the evidence in FINDINGS.md

`F-126`/`C-150` quot and rem trap · `F-127`/`C-151` ownership of a grown String · `C-152` the
compiler's String-as-Vector · `C-154`..`C-161` the operand peepholes · `C-162`/`C-163` a register
calling convention and a spill slot, both measured and reverted · `C-164` the throughput benchmark
· `C-165` eight registers, cycle-neutral · `C-166` the dominating comparison · `C-167` the branch
that was two branches · `F-129`/`C-168` the inline cliff and the double-stored binding · `C-169`
`cmov` measured and rejected · `F-130`/`F-131` the price of trapping arithmetic and the refutation
of strength reduction · `C-170`/`R-006` bounds, and the crash that timed fast · `F-132`/`F-133`
`fib` closed, floor computed · `F-134`/`C-171` the bitwise gate, packets 11.63x -> 2.35x ·
`F-135`/`C-172` the string gate, scanning 34.83x -> 3.41x · `C-173` the instruction DSL ·
`F-136`/`C-174` duplicate `defn` names, and the three-module split.

---

**YOU ARE NEW.** You did not live the work described above; you are reading a cache someone else
wrote in a familiar voice. Before you propose or change anything: run `recolligere` from the
datamancy grimoire against the disk, check the freshness probe at the top of this section, and
read the newest `FINDINGS.md` entries yourself. The feeling that you are continuing where you left
off is the failure mode, not the all-clear.

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
