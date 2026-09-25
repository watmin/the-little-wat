# EXPECTATIONS — excursus 006 stone 1: a macro says what it returns

Written BEFORE the strike.

| # | what | command | expected |
|---|---|---|---|
| 0 | ⛔ 004 parked | `git -C wat-rs branch -r` / `git -C wat-rs status` | `origin/the-little-wat-004-eval-step` exists; `the-little-wat` clean before the strike |
| 1 | ⛔ honest declarations expand | the new fixtures | `-> i64` → the integer; `-> (Vector :- [i64])` → the vector; a record; an enum value — each agrees with writing the value by hand |
| 2 | ⛔ a lying declaration is refused | `wat --check probes/macro-declared-form-returns-int.wat` | refused at check, naming the macro, `:wat::WatAST` declared, `:wat::core::i64` produced |
| 3 | ⛔ macro bodies are type-checked | `wat --check probes/macro-body-untyped.wat`; the unused-macro fixture | both refused, naming the macro and the bad call |
| 4 | ⛔ the corpus holds | the new check over every `.wat` in both repos (`allwat.txt` beside this file: the crawl's 2,616 paths, relative to `~/Work/holon`) | refusals only where the SCORE names them; `:t::deep-answer` passes with `-> :wat::core::i64` |
| 5 | arc 249's test | `macros::tests::program_body_producing_non_ast_rejected` | green, asserting the TYPE refusal, its comment the stated contract |
| 6 | the renderer | its render test, exact asserts | record fields in declaration order; a mutant reversing them fails |
| 7 | the floor | `NEXTEST_TEST_THREADS=4 scripts/floor.sh` | green except F-197's two lint reds |
| 8 | the stepper untouched | the diff | no stepper code on `the-little-wat` |

Runtime prediction: 3–5 hours. Trap-doors: macro definitions are registered before `check_program`
builds its environment, so reaching them may need the registry threaded through; the purity
allow-list's combinators (`keyword-node`, `symbol-node`, `macro-error`) need types in the checker's
environment — `symbol-node`/`keyword-node` already have them (`src/check.rs:21160`).
