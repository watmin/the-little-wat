# EXPECTATIONS — excursus 004 stone 1: `eval-step!` steps what `eval` runs

Written BEFORE the strike.

| # | what | command | expected |
|---|---|---|---|
| 1 | ⛔ user functions step | `probes/eval-step-user-fn-kw.wat`, `-recursion.wat` | terminals `4`, `6` |
| 2 | ⛔ symbol spellings step | `-builtin-symbol.wat`, `-user-fn-symbol.wat` | `3`, `4` |
| 3 | ⛔ the hang is gone | `-let-bound-fn.wat`; `-trace-let-bound-fn.wat` | `43`; five DIFFERENT forms, or a terminal before five |
| 4 | ⛔ closures from outside the form | `-toplevel-closure.wat` | `15` |
| 5 | ⛔ no-progress is unrepresentable | a mutant that returns `StepNext` of the input from one rule | `eval-step!` answers the named error, not a fixed point |
| 6 | the two red tests | `cargo nextest … step_user_function_call step_tail_recursion_terminates_under_bound` | green, the test files UNCHANGED |
| 7 | the gate | the differential test | covers every shape the brief lists; a mutant that breaks substitution of a captured value fails it |
| 8 | canonicity is one fact | the diff | no hand list a new terminal rule can forget; say how |
| 9 | the floor | `NEXTEST_TEST_THREADS=4 scripts/floor.sh` | all green except F-197's two lint reds |
| 10 | the-little-wat's own probes | `probes/eval-step-closure.wat`, `-kw.wat` (F-198) | step instead of refusing |

Runtime prediction: 2–4 hours. Trap-doors: `value_to_watast` may not render every value a closure
can capture (a record, an enum) — each it cannot is either rendered in this stone or refused by name;
substitution into a `fn` body must stay capture-free, which the `Identifier` scope-set equality is for.
