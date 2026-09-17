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

## 5. Norvig's PAIP chapters 11–12: unification and a Prolog

- **Stresses:** heavy symbolic pattern-matching, which is where quoted data versus typed
  data gets decided. Pairs naturally with The Reasoned Schemer.

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

## 9. EOPL — *Essentials of Programming Languages* (Friedman & Wand)

The big uncovered Friedman. Interpreters, type checkers, continuations, stores, an
explicit-control evaluator — incremental, every chapter runnable, and it tests wat as a
**language host**, which is what the rest of the roadmap sits on. Oracle: the book's own
expected values, and Racket/guile for the reference implementations.

## 10. Okasaki — *Purely Functional Data Structures* — **ch 2, 3, 5 DONE 2026-09-16; stops there (F-100)**

~30 structures, each small and runnable, each with a stated amortized bound. Lands directly
on the weak spot this repo has already measured: F-057 (copying vs sharing containers), F-055
(`rest` clones, so walking is quadratic), F-023 (`conj` clones), and the **missing persistent
set** (a visited set has to be a `PersistentMap` to `true`). Laziness and amortization are
wat's `:wat::stream::` territory, which F-088 showed is documented as an API that does not
exist. Oracle: the book's bounds, and timing curves rather than single points (C-050's method).

## 11. Downey — *The Little Book of Semaphores*

~30 concurrency puzzles with known-correct answers **and** known failure modes — a rare
**self-oracling** corpus, where a wrong implementation fails in a way the book already names. F-094 measured `bracket::map`'s thread pool at 29% of what the
same machine does with OS processes, so this is a live battleground. **No networking** — the
builder's call, 2026-09-16: networking is simulated via IPC anyway (processes over unnamed
Unix domain sockets, threads over crossbeam-style channels), so the puzzles run against
`:wat::spawn::`/`:wat::bracket::`/`:wat::service::` directly.

## 12. *Crafting Interpreters*, Part II — the bytecode VM

A flat instruction array, a dispatch loop, a value stack, jump patching. Not for the book's
sake: it rehearses the exact machinery §7's baseline is being taken for, and it tests whether
wat can host the shape of its own next phase.

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
