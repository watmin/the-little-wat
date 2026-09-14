# wat-friedman

Daniel P. Friedman's books, worked through in [wat](../wat-rs), to find where wat is lacking.

Each book leans on a different part of a language:

| Book | Leans on |
|---|---|
| The Little Schemer | S-expressions, recursion over lists, the Y combinator, a small interpreter |
| The Seasoned Schemer | `letrec`, `letcc` (call/cc), `set!`, closures that carry state |
| The Little MLer | algebraic datatypes, pattern matching, types |
| The Reasoned Schemer | logic programming: unification, streams, `conde` |
| The Little Prover | rewriting and proof over S-expressions |
| The Little Typer | dependent types (Pie) |
| The Little Learner | tensors and gradient descent |

The code here is our own implementation of what each chapter builds. The books' text is not
reproduced.

## Layout

```
books/<book>/chNN-<topic>.wat       one program per chapter: loads the lib files it needs, then a main of checks
books/<book>/lib/chNN-<topic>.wat   that chapter's definitions, no main. Libs never load each other;
                                    each program loads what it needs, in chapter order.
probes/*.wat                        small programs that isolate one question each (repros for FINDINGS)
FINDINGS.md                     the ledger: every place wat fell short, or didn't
run.sh                          runs every chapter and reports PASS/FAIL per file
wat-tests/, tests/, build.rs    a minimal cargo consumer, kept only to reproduce F-001 to F-003
```

## Running

Chapters are plain programs run by wat-rs's release binary. No build step here.

```
./run.sh                                                   # every chapter; exit 0 = all pass
../wat-rs/target/release/wat books/little-schemer/ch01-toys.wat   # one chapter
```

A chapter passes when it exits 0 and prints its final `ok` line. Its checks are
`wat.test/assert-eq` calls that stop at the first failure and name the file and line.
After pulling wat-rs, rebuild the binary there: `cargo build --release`.

## Spelling

Code is written in the Clojure/EDN spelling wat is moving to (`wat.core/defn`,
`[x :- wat.type/i64]`, `:- ret`), so the coming syntax migration costs nothing here. Where
that spelling doesn't work yet, the keyword spelling stands in, and the codemods will
convert it:

- Types outside `wat::core` use the keyword, e.g. `:wat::WatAST` (F-005).
- The empty list is built as `(wat.core/rest (wat.core/quote (x)))`, not quoted (F-004).
- Deftests (the cargo crate only) keep the `:wat::test::deftest` spelling (F-003).

## The cargo crate

`cargo test --release` runs `wat-tests/`. Always use `--release`: a debug build of any
wat runtime panics during type-registry setup (F-001). This crate exists to reproduce
F-001 to F-003; the book work does not use it.
