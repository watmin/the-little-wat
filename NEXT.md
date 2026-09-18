# After Friedman: more acceptance tests

Queued for once the Friedman books are exhausted. Each one tests wat against something
with a known right answer, and each leans on a different part of the language. The same
rules apply as for the books: every gap goes into FINDINGS.md with a repro, and code is our
own, not copied from the sources.

Ordered by how directly each tests what wat claims to be.

## Where this stands (2026-09-16)

§1–§5 are done and §6 is declined (both recorded below). §7–§12 are the next wave, queued
2026-09-16 after a measurement of what this repository has actually produced:

| era | findings | involving a port | probe of wat only |
|---|---|---|---|
| F/C-001…050 | 100 | 40 | 55 |
| F/C-051…075 | 25 | **18** | 6 |
| F/C-076…095 | 20 | 1 | **18** |

The last stretch was a systematic sweep of wat's own namespaces (linter, grep, cache,
telemetry, docs, rationals, fix, brackets, reflection, deporder) and that sweep is now
**exhausted — every namespace has probes**. The stretch before it was suite-building, and it
was port-driven at 18 of 25. So porting still works; what stopped was me doing it. §7–§12
return to porting, choosing each suite for the machinery it stresses rather than for being a
book.

Two items (§7, §8) are instruments rather than ports, and §7 is the only thing here with a
deadline.

## Where §1–§6 stand (2026-09-15)

§1–§5 are done, each in its own directory with its own oracle, and all of them run under
`./run.sh`:

| | suite | result |
|---|---|---|
| §1 | Clojure Koans | `koans/` — 229 rows: 29 literal, 163 the wat way, 17 with no route, 20 refused by design (C-030) |
| §2 | Make-a-Lisp | `mal/` — 11/11 steps, 909 of mal's own tests (C-032) |
| §3 | SICP chapter 3 | `sicp/` — 4 chapters, 65 results against guile |
| §4 | Advent of Code | `aoc/` — 5 puzzles, 10 answers against Clojure |
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

## 4. Advent of Code (one year): is it pleasant for real work?

- **What:** real input files, parsing, grids, hash maps, and a known right answer for every
  puzzle.
- **Stresses:** what the textbooks never touch: reading files, splitting strings,
  performance. `wat`'s startup (~350–450ms per run on the i7-1270P laptop) will show up.

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

## 12. *Crafting Interpreters*, Part II — the bytecode VM — **STARTED 2026-09-17**

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
| 16 | Scanning on demand | **not started** |
| 17 | Compiling expressions | **not started** |
| 18 | Types of values | **not started** |
| 19 | Strings | **not started** |
| 20 | Hash tables | **no portable content** — the chapter implements one; wat has `HashMap` and `PersistentMap`, and C-078 already measured what they cost |
| 21 | Global variables | **not started** |
| 22 | Local variables | **not started** |
| 23 | Jumping back and forth | **not started** |
| 24 | Calls and functions | **not started** |
| 25 | Closures | **not started** |
| 26 | Garbage collection | **partly covered** — SICP §5.3 (C-081) already built stop-and-copy with broken hearts; Nystrom's mark-sweep is a different algorithm and is worth building |
| 27 | Classes and instances | **not started** |
| 28 | Methods and initializers | **not started** |
| 29 | Superclasses | **not started** |
| 30 | Optimization | **no portable content** — NaN boxing and cache-line layout are about C's memory model |

**Oracle.** Unlike the other suites there is no second implementation to compare against: the VM
IS the thing being tested. So each chapter checks its own invariants — a program's value, the
instruction count, the stack's high-water mark — and where a result can be cross-checked against
an existing port (SICP §5.5's compiler, C-081) it is.

## Suggested order

§7 first, because it is the only item that expires. Then §8, which makes everything already
found keep paying. Then the ports, in the order §10, §11, §9, §12 — Okasaki first because it
aims at defects already measured, Semaphores next because F-094 left a live question, EOPL
because it is the largest, and Crafting Interpreters last so it can be written against
whatever the byte-code work has become.

A note on spelling, 2026-09-16: the builder expects to drop the o.g. wat syntax for a
Clojure/EDN-compliant scheme within weeks, with "typed Clojure" as the end game. New ports
should be written in whatever spelling is current and **not** hand-tuned for the migration;
`tools/fix-roundtrip.sh` already exists to convert the corpus and differential-test the result
when the flip lands.
