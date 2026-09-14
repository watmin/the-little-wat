# After Friedman: more acceptance tests

Queued for once the Friedman books are exhausted. Each one tests wat against something
with a known right answer, and each leans on a different part of the language. The same
rules apply as for the books: every gap goes into FINDINGS.md with a repro, and code is our
own, not copied from the sources.

Ordered by how directly each tests what wat claims to be.

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

## Suggested order

Finish the Friedman books. Then Clojure Koans as a fast breadth check that lines up with
the codemods; then mal as the deep test; with the Shield slice as the capstone. Each gets
its own directory, like `books/`, and this repo becomes a general acceptance-test repo.
