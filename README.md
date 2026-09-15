# the-little-wat

Daniel P. Friedman's *Little* books, worked through in [wat](https://github.com/watmin/wat-rs).

wat is an experiment: an **LLM-first language written by LLMs**. Its builder writes prompts
and no code, and every line of wat-rs came from models. wat was an empty directory on
2026-04-18. The ports here were written by a model too (Claude), chapter by chapter, to
answer one question: can an LLM write this language correctly, and catch its own mistakes
when it doesn't? The books make a good maturity check. Each leans on a different part of a
language, and each assumes the one before it works.

| Book | Leans on | State |
|---|---|---|
| The Little Schemer | S-expressions, recursion over lists, the Y combinator, an interpreter | 10/10 chapters, 168 checks |
| The Seasoned Schemer | `letrec`, `letcc` (call/cc), `set!`, closures that carry state | 10/10, 120 checks |
| The Reasoned Schemer | logic programming: unification, interleaving streams, `conde` | 10/10, 201 checks |
| The Little MLer | algebraic datatypes, pattern matching, exceptions, modules | 10/10, 139 checks |
| The Little Prover | rewriting and proof over S-expressions | 9/9 chapters, all 49 transcript entries match the book's own prover |
| The Little Typer | dependent types (Pie) | 16/16 chapters: all 290 printed results match Racket's Pie, and all 108 forms it refuses are refused |
| The Little Learner | tensors and gradient descent | |

65 chapters and 1,075 checks pass (`./run.sh`). The code is our own implementation of what
each chapter builds; the books' text is not reproduced. The one exception is The Little
Prover's J-Bob: its authors publish it (BSD 2-Clause), so it is vendored in `vendor/j-bob`
and translated into wat by a wat program (`tools/jbob2wat.wat`). The book's proofs then run
in wat and are checked against guile running the original. The Little Typer's language,
Pie, is written anew in wat (`books/little-typer/lib/pie.wat`, a type checker by
normalization by evaluation), and Racket's Pie is its oracle, run as a black box and never
read.

## A reflection, from the model that wrote the ports

**What made wat writable.**
- Every name is fully qualified, so there was never an import to get wrong or a name to
  guess.
- Errors are data, and the best of them name the fix outright: "`:wat::core::i64::to-string`
  is retired; use `:wat::i64::to-string`", or the containment rule naming the rule, the
  reason and the way out. I took those without thinking twice.
- `match` refuses a forgotten arm, which is exactly the slip a model makes.
- One small probe answers one question in half a second. That turned out to matter most.

Every chapter after the first book passed on its first run.

**What cost the most** was not the hard features. It was the silent failures, because a
model trusts a green run:
- calls in the Clojure spelling that are never type-checked (F-014);
- a `let` whose body is checked without its bindings (F-024);
- a `defmacro` or a `load-file!` that does nothing without a word (F-022, F-012);
- a test that is skipped while the suite stays green (F-003);
- a retired pattern that ships until some input reaches it (F-026).

Close behind came errors that point the wrong way. One named a verb the program never
called, and it took several probes to learn it meant my `let`. Most of these are traces of
a language moving fast: spellings retired faster than every path to them was closed, and
docs a few months behind the code.

**How the work stayed honest.**
- Nothing is claimed from wat-rs's docs. Every "wat can't" is a probe that ran. Twice I
  predicted a failure from memory and was wrong (Y is fine; tuples do widen), and only the
  probe said so.
- The Reasoned Schemer's answer *order* depends on interleaving, so its expected values come
  from `oracle/`, the book's engine transliterated to Clojure. The two implementations agree
  on every query.
- When a chapter passed suspiciously fast, a copy with one wrong expectation proved its
  checks really run.
- A red is never re-run away.

**What wat did well, sometimes surprisingly.**
- `set!` became small services, in a language whose doctrine puts state on services.
- letcc became `Result/try`, with the abandoned work measured.
- The book's `run`, `fresh`, `conde` and `defrel` became wat macros in the book's own syntax.
- Constructors turned out to be function values.
- Mutually recursive generic enums just worked.

**The Little Typer was the biggest test.** wat-Pie, a dependent type checker of about a
thousand lines, grew one chapter at a time against Racket's Pie. Two rules kept it honest.
- Every chapter's printed normal forms must match Pie's string for string, subscripted
  renamings and all.
- A checker that accepts a wrong program fails silently, so every chapter also carries
  forms Pie refuses, and wat-Pie must refuse them too. A refusal is a failed assertion
  deep in the checker, so each one runs in a thread, and its death comes back as a value
  (`:wat::test::run-thread`, C-026).

The oracle refused my own examples several times. Once that exposed a wat-Pie bug: it
accepted `(the U (Pi ((A U)) …))`, and U has no type. Three of the last five chapters
(12, 15 and 16) passed without a change to the checker.

**What remains is speed.** The interpreter runs the miniKanren search at about 0.35 ms per
answer, roughly 300 to 430 times slower than the JVM on the same algorithm. The two
quadratic costs we found along the way were ours or the data structures', not the
interpreter's (F-023). The Little Typer found one that is wat's own. Taking a WatAST apart
copies every subtree below it (F-033), and a checker whose closures hold environments
pays for that exponentially. Binding definitions as syntax instead took its slowest
chapter from 43 s to 2 s.

## Reading further

- [FINDINGS.md](FINDINGS.md) is the ledger: every place wat fell short, or didn't.
  - F-001 to F-033 are gaps and defects.
  - R-001 to R-005 are deliberate refusals, with their doctrine.
  - C-001 to C-026 are clean ports.

  It opens with a status table and the list to relay to wat-rs.
- [PROVIDE.md](PROVIDE.md): what users shouldn't have to write themselves (P-001 to P-014).
- [NEXT.md](NEXT.md): the acceptance tests queued after the books (Clojure Koans,
  Make-a-Lisp, SICP, Advent of Code, PAIP, and a slice of a real packet detector).

## Layout

```
books/<book>/chNN-<topic>.wat       one program per chapter: loads the lib files it needs, then a main of checks
books/<book>/lib/chNN-<topic>.wat   that chapter's definitions, no main; each program loads what it needs
probes/                             207 small programs, each isolating one question (the repros behind FINDINGS)
oracle/                             expected values: the Reasoned Schemer's engine in Clojure; guile running J-Bob; Racket's Pie
tools/jbob2wat.wat                  J-Bob (Scheme) -> wat, built on wat's reader and AST tools like wat/fix.wat
tools/pie-oracle*.sh                Racket's Pie on a Little Typer chapter's .pie files: its results, and what it refuses
vendor/j-bob/                       The Little Prover's J-Bob, BSD 2-Clause, as published by its authors
FINDINGS.md, PROVIDE.md, NEXT.md    the ledgers
run.sh                              runs every chapter and reports PASS/FAIL per file
wat-tests/, tests/, build.rs        a minimal cargo consumer, kept only to reproduce F-001 to F-003
```

## Running

Chapters are plain programs run by wat-rs's release binary. Clone
[wat-rs](https://github.com/watmin/wat-rs) beside this repository and build it
(`cargo build --release`). Then:

```
./run.sh                                                         # every chapter; exit 0 = all pass
../wat-rs/target/release/wat books/little-schemer/ch01-toys.wat  # one chapter
clojure -M oracle/ch07.clj                                        # one Reasoned Schemer chapter's expected values
tools/pie-oracle.sh books/little-typer/ch08-pick-a-number-any-number.pie   # one Typer chapter's expected results
```

A chapter passes when it exits 0 and prints its final `ok` line. Its checks stop at the
first failure and name the file and line. Run anything open-ended under
`timeout -s KILL`, because a busy wat program does not stop on SIGTERM (R-005).

## Spelling

Code is written in the Clojure/EDN spelling wat is moving to (`wat.core/defn`,
`[x :- wat.type/i64]`, `:- ret`), so the coming syntax migration costs nothing here. Where
that spelling doesn't work yet, the keyword spelling stands in:
- types outside `wat::core`, e.g. `:wat::WatAST` (F-005);
- `match` (F-017);
- lambdas with function-typed parameters (F-010);
- `defmacro` (F-022);
- tuple destructuring in `let` (F-024).

Every `match` names every variant, with no `_`, per the builder's doctrine that an arm
cannot be forgotten (F-025).

## The cargo crate

`cargo test --release` runs `wat-tests/`. Always use `--release`, because a debug build of
any wat runtime panics during type-registry setup (F-001). The crate exists only to
reproduce F-001 to F-003.
