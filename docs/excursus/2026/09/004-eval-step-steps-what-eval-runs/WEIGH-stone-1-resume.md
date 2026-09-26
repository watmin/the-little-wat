# WEIGH — excursus 004 stone 1: resume the stepper on top of 006

2026-09-26. Excursus 007 (wat-rs `40ddeac4d`: `name`/`from-name`) and 006 (`365ebc014`: a macro says
what it returns; the ONE renderer `value_to_watast`; `:wat::core::ast-keyword`) have landed on
`the-little-wat`. 004's stepping rows were credited in `WEIGH-stone-1-refuted.md`; what follows is
what is left.

## FIRST

`git switch the-little-wat-004-eval-step`, rebase it onto `the-little-wat` (`365ebc014`), carry the
work back onto `the-little-wat` uncommitted. **The renderer already landed through 006: resolve every
conflict in `value_to_watast` and its render test IN FAVOUR OF WHAT LANDED** -- 004 keeps no renderer
of its own. 007 already brought `wat_value_ui`'s nextest override; 004's other deadline changes (the
six `nth` time-limit annotations, the `c5b`/`c5c` overrides) come across as they are.

## THE ROWS STILL OWED

| row | what |
|---|---|
| **S1** | the stepper's field-read check tests `head_kw.contains("::")` (`one_variant_separator` lint): decide a field read through the identifier door (`wat_reader::identifier`), or a co-located rune whose category the lint accepts and whose reason earns it |
| **S2** | the anonymous-closure path: a probe where a captured value is itself an UNNAMED closure (so `fn_value_to_form` writes a `fn` form with ITS captures substituted), stepped to the terminal eval gives -- never driven on a binary yet |
| **S3** | `probes/eval-step-captures-rec-enum-fn.wat` agrees (`[4 _]`, `[8 _]`, `[2 _]`) on the rebased build; every `probes/eval-step-*.wat` agrees with its header |
| **S4** | the differential gate (`step_round_trip_agrees_with_eval_ast`) covers a closure over a record, an enum value and an unnamed closure; the field-order mutant still fails the render test |
| **S5** | the floor, alone: green except F-197's two lints -- the two step tests go GREEN here |

Write a resume section in `SCORE-stone-1-step-user-code.md`. Commit nothing on `the-little-wat`.
