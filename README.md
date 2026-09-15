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
| The Little Prover | rewriting and proof over S-expressions | next |
| The Little Typer | dependent types (Pie) | |
| The Little Learner | tensors and gradient descent | |

40 chapters and 628 checks pass (`./run.sh`). The code is our own implementation of what
each chapter builds; the books' text is not reproduced.

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

**What remains is speed.** The interpreter runs the miniKanren search at about 0.35 ms per
answer, roughly 300 to 430 times slower than the JVM on the same algorithm. The two
quadratic costs we found along the way were ours or the data structures', not the
interpreter's (F-023).

## Reading further

- [FINDINGS.md](FINDINGS.md) is the ledger: every place wat fell short, or didn't.
  - F-001 to F-030 are gaps and defects.
  - R-001 to R-005 are deliberate refusals, with their doctrine.
  - C-001 to C-023 are clean ports.

  It opens with a status table and the list to relay to wat-rs.
- [PROVIDE.md](PROVIDE.md): what users shouldn't have to write themselves (P-001 to P-013).
- [NEXT.md](NEXT.md): the acceptance tests queued after the books (Clojure Koans,
  Make-a-Lisp, SICP, Advent of Code, PAIP, and a slice of a real packet detector).

## Layout

```
books/<book>/chNN-<topic>.wat       one program per chapter: loads the lib files it needs, then a main of checks
books/<book>/lib/chNN-<topic>.wat   that chapter's definitions, no main; each program loads what it needs
probes/                             187 small programs, each isolating one question (the repros behind FINDINGS)
oracle/                             the Reasoned Schemer's engine in Clojure: expected values, answer order included
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
