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
| The Little Learner | tensors, automatic differentiation, gradient descent | 22/22 (chapters 1–15, Interludes I–VII): all 194 values match malt, the book's own library, exactly |
| A Little Java, A Few Patterns | objects, interfaces, the visitor pattern, mutable fields | 10/10: all 130 results match Java's |
| The Clojure Koans (our own koans on its 27 topics) | Clojure itself, form by form | of 229 koans, 29 port literally and 163 more run the wat way; 17 have no route today, and 20 are refused by design |
| Make-a-Lisp (kanaka/mal) | building a language: reader, eval, environments, tail calls, macros, try | 11/11 steps: 909 of mal's own tests pass, every hard one; 38 optional ones don't (metadata, debug tracing) |
| SICP chapter 3 (our own Scheme on its topics) | state, mutable data, concurrency, streams | 4 chapters, 65 results, all matching guile |
| Advent of Code (our own puzzles, in its shape) | reading a file, parsing, grids, counting, bits, shortest paths, speed | 5 puzzles, 10 answers, all matching the Clojure reference |
| PAIP (our own Scheme on Norvig's chapters 11–12) | symbolic pattern matching: unification and a Prolog, over quoted data | 2 chapters, 58 results, all matching guile |
| Project Euler (our own Clojure on four of its problems) | arbitrary-precision integers, and text: digit sums, a thousand-digit Fibonacci, and names scores | 4 problems, 17 answers, all matching the Clojure reference |
| wat's own rete, against clara-rules | a production rule engine: joins, forward chaining, negation, existence, accumulation, retraction | 2 cases, 16 results |
| wat's own sqlite surface, against the sqlite3 CLI | a database: schema, bound parameters, NULL, aggregates, transactions | 1 case, 17 results, all matching sqlite3 |
| wat's own Store contract, against itself | two backends satisfying one surface: put, keyset paging, a GSI | 1 case, 5 results, identical either side |

97 chapters (1,399 checks), 27 koan programs (163 checks), 4 SICP chapters (65 results against
guile), 5 Advent of Code puzzles (10 answers against Clojure), 2 PAIP chapters (58 results
against guile), 4 Project Euler problems (17 answers against Clojure), 2 rete cases (16 results
against clara-rules), 1 sqlite case (17 results against the sqlite3 CLI) and 1 Store case (two
backends agreeing) pass (`./run.sh`), and the 11
Make-a-Lisp steps pass 909 of mal's own tests (`tools/mal-all.sh`). The code is our own implementation of what
each chapter builds; the books' text is not reproduced. The one exception is The Little
Prover's J-Bob: its authors publish it (BSD 2-Clause), so it is vendored in `vendor/j-bob`
and translated into wat by a wat program (`tools/jbob2wat.wat`). The book's proofs then run
in wat and are checked against guile running the original. The Little Typer's language,
Pie, is written anew in wat (`books/little-typer/lib/pie.wat`, a type checker by
normalization by evaluation), and Racket's Pie is its oracle, run as a black box and never
read. The Little Learner's library, malt, is MIT like J-Bob, so it is ported to wat by hand
(`books/little-learner/lib/malt.wat`) and checked against malt itself, number for number.
A Little Java's oracle is Java: our own Java for each chapter, compiled and run by the JDK.

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

**The Little Learner asked for exactness.** Each value is compared with malt's as an f64, with
no tolerance, and all 194 match bit for bit. That includes the book's own Iris run: 2000
sampled revisions, ending at malt's trained theta and its accuracy. It works because the port
does every operation in malt's order, even summing from the last entry. Two of malt's habits
had no wat equivalent:
- hyperparameters bound dynamically, which became a value passed along;
- a hidden random generator, which became malt's own draws, recorded and replayed through a
  counter service.

The oracle also caught two mistakes of mine in Racket, not wat: malt's `*` had quietly
turned a count into a dual.

**A Little Java asked for objects,** and my first port dodged the question. I wrote each
visitor as a struct of closures, a dictionary passed by hand. The builder asked why, when
wat has `defsurface` and `extend-type` for exactly this, as Clojure has protocols. On
surfaces the port was better, and it found more:
- **Better than Java:** a visitor that isn't "good", which Java finds at runtime as a
  ClassCastException, wat refuses at startup.
- **The reverse:** an `extend-type` that forgets a feature runs until the feature is
  called (F-039). Java won't compile it.
- **One `accept` per answer type:** F-029 forced it, recreating the shape the book's
  chapter 7 sets out to remove.
- **Mutable fields** became a service holding a pie. That service's surface had to own the
  pie datatype itself (Friction).
- **An error message I had praised misled me.** The containment rule's way out, "declare
  the enum Impure", was right in the Little Learner. Here the fix was `defrecord`, which it
  never names (F-040).

**The Clojure Koans asked whether wat is the Clojure its spelling promises.** I wrote 229
small koans of my own, each true in Clojure, then ported each one with only its namespaces
changed and ran it. 29 ran. The failures sort cleanly:
- names wat lacks;
- Clojure's untyped forms;
- typed nil.

Written the wat way, 163 more run. The other 37 were marked instead: 17 have no route today,
such as set union (a set's elements can't be read back, F-046), and 20 are refused by design.

**Make-a-Lisp asked whether wat can build a language, and it can.** All 11 steps pass mal's
own tests, run by mal's own runner: 909 of them. I kept mal's values as plain data and put its
environments and atoms on a service, which is where wat's doctrine keeps state. mal's tail
calls turned out to be wat's own. Nine of the eleven steps passed their hard tests on the first
full run. The other two failed on the shim's missing echo and on time, not on the interpreter.

Two costs showed up, and neither was in the interpreter:
- **The terminal.** A wat program can't print a prompt, or a line that isn't EDN, and it
  can't read an unbalanced line as a line (F-049, F-050). A 40-line Python shim had to stand
  between mal's runner and the program.
- **Speed.** A message to a service costs about 224 µs, a hundred function calls (F-051). So
  the doctrine's home for state makes every variable lookup the price of a hundred calls.

The run also measured the finding that cost me most in the first books. Spelled with
keywords, 38 rows are refused at startup that the Clojure spelling lets through to die at
runtime (F-014).

**What remains is speed.** The interpreter runs the miniKanren search at about 0.35 ms per
answer, roughly 300 to 430 times slower than the JVM on the same algorithm. The two
quadratic costs we found along the way were ours or the data structures', not the
interpreter's (F-023). The Little Typer found one that is wat's own. Taking a WatAST apart
copies every subtree below it (F-033), and a checker whose closures hold environments
pays for that exponentially. Binding definitions as syntax instead took its slowest
chapter from 43 s to 2 s. The book's Iris run takes 236 s in wat against malt's 2.3 s.

## Reading further

- [FINDINGS.md](FINDINGS.md) is the ledger: every place wat fell short, or didn't.
  - F-001 to F-087 are gaps and defects.
  - R-001 to R-005 are deliberate refusals, with their doctrine.
  - C-001 to C-046 are clean ports and acceptance results.

  It opens with a status table and the list to relay to wat-rs, grouped by task: fix,
  correct, clean, improve, extend.
- [PROVIDE.md](PROVIDE.md): what users shouldn't have to write themselves (P-001 to P-024).
- [koans/README.md](koans/README.md): the Clojure Koans' topics, ported literally and judged
  in both of wat's spellings.
- [mal/README.md](mal/README.md): Make-a-Lisp in wat, against mal's own tests.
- [sicp/README.md](sicp/README.md): SICP chapter 3 in wat, against guile.
- [aoc/README.md](aoc/README.md): Advent of Code's shape in wat, against a Clojure reference.
- [paip/README.md](paip/README.md): PAIP's unification and Prolog over quoted data, against guile
  — and where quoted data runs out.
- [euler/README.md](euler/README.md): Project Euler on big integers and text, against Clojure.
- [rete/README.md](rete/README.md): wat's own rule engine against clara-rules, and the surface
  nothing else writes down.
- [sqlite/README.md](sqlite/README.md): wat's own sqlite surface against the sqlite3 CLI — where
  it does better than the language around it, and where a verb is missing.
- [store/README.md](store/README.md): wat's two Store backends checked against each other, and
  what a consumer of a service contract has to write.
- [NEXT.md](NEXT.md): the acceptance tests queued after the books (Clojure Koans,
  Make-a-Lisp, SICP, Advent of Code, PAIP, and a slice of a real packet detector).

## Layout

```
books/<book>/chNN-<topic>.wat       one program per chapter: loads the lib files it needs, then a main of checks
books/<book>/lib/chNN-<topic>.wat   that chapter's definitions, no main; each program loads what it needs
probes/                             331 small programs, each isolating one question (the repros behind FINDINGS)
oracle/                             expected values: the Reasoned Schemer's engine in Clojure; guile running J-Bob; Racket's Pie; malt; Java
tools/jbob2wat.wat                  J-Bob (Scheme) -> wat, built on wat's reader and AST tools like wat/fix.wat
tools/pie-oracle*.sh                Racket's Pie on a Little Typer chapter's .pie files: its results, and what it refuses
tools/learner-oracle.sh             malt on a Little Learner chapter's oracle file: its values, draws and data
tools/java-oracle.sh                the JDK on a Little Java chapter's Java (oracle/java/chNN-*.java): its printed results
tools/koans.clj                     ports each koan to wat, runs it, and judges it against Clojure
koans/src/NN-<topic>.clj            the Clojure Koans' topics: our own filled-in koans, each true in Clojure
koans/literal/, koans/keyword/      each koan's verdict in each of wat's spellings, with wat's message
koans/idiom/NN-<topic>.wat          the koans that don't port literally, said the way wat says it (run by run.sh)
tools/koan-tiers.sh                 every koan's tier: literal, wat idiom, missing, or refused
mal/stepN_<name>.wat                Make-a-Lisp in wat, one program per step
tools/mal-test.sh, tools/mal-shim.py  a step against mal's own tests; the shim is the terminal a wat program can't be
tools/mal-all.sh                    every mal step, one summary line each
vendor/mal/                         Make-a-Lisp's test runner and step tests, MPL 2.0, unmodified
sicp/chNN-<topic>.wat               SICP chapter 3 in wat, one program per section
tools/sicp-oracle.sh                guile on a section's Scheme (oracle/sicp/NAME.scm): its printed results
aoc/dayNN-<name>.wat, aoc/input/    our own puzzles in Advent of Code's shape, and their inputs
tools/aoc-oracle.sh                 Clojure on a puzzle's reference implementation (oracle/aoc/NAME.clj)
paip/chNN-<topic>.wat               PAIP chapters 11-12 in wat: unification and a Prolog, over quoted data
tools/paip-oracle.sh                guile on a chapter's Scheme (oracle/paip/NAME.scm): its printed results
euler/pNN-<name>.wat, euler/input/  Project Euler problems in wat, and our own generated inputs
tools/euler-oracle.sh               Clojure on a problem's reference implementation (oracle/euler/NAME.clj)
rete/rNN-<name>.wat                 wat's own rete engine, put to the same rules as clara-rules
tools/rete-oracle.sh                clara-rules on a case's rules (oracle/rete/NAME.clj): its results
sqlite/sNN-<name>.wat               wat's own sqlite surface, put to the same SQL as the sqlite3 CLI
tools/sqlite-oracle.sh              sqlite3 on a case's SQL (oracle/sqlite/NAME.sql): its results
store/qNN-<name>.wat                wat's two Store backends, driven through one surface and compared
vendor/j-bob/                       The Little Prover's J-Bob, BSD 2-Clause, as published by its authors
vendor/malt/                        the license of malt (MIT), the Little Learner's library, which lib/malt.wat ports
FINDINGS.md, PROVIDE.md, NEXT.md    the ledgers
run.sh                              runs every chapter and reports PASS/FAIL per file
wat-tests/, tests/, build.rs        a minimal cargo consumer, kept only to reproduce F-001 to F-003
```

## Running

Chapters are plain programs run by wat-rs's release binary. Clone
[wat-rs](https://github.com/watmin/wat-rs) beside this repository and build it
(`cargo build --release`). Then:

```
./run.sh sqlite                                                  # one suite (a second or two)
./run.sh aoc paip euler                                          # several
./run.sh                                                         # everything; exit 0 = all pass (16 minutes)
../wat-rs/target/release/wat books/little-schemer/ch01-toys.wat  # one chapter
clojure -M oracle/ch07.clj                                        # one Reasoned Schemer chapter's expected values
tools/pie-oracle.sh books/little-typer/ch08-pick-a-number-any-number.pie   # one Typer chapter's expected results
tools/learner-oracle.sh ch04-slip-slidin-away                     # one Learner chapter's expected values (needs racket + malt)
tools/java-oracle.sh ch07-oh-my                                   # one Little Java chapter's expected results (needs a JDK)
clojure -M tools/koans.clj 02-strings                            # one koan topic, ported and judged (SPELLING=keyword for the other spelling)
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
