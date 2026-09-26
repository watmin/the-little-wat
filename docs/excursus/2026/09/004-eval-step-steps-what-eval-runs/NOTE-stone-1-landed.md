# NOTE — excursus 004 stone 1 landed

Read `SCORE-stone-1-step-user-code.md`, the resume section. The re-run is credited.

The stepper sits on `the-little-wat` at `365ebc014`, uncommitted. `value_to_watast` is the renderer that landed with 006. A field read is a head whose `wat_reader::identifier::path` is empty, with the namespace rune. `probes/eval-step-unnamed-closure.wat` walks to `[4 6]` and eval prints `4`. `probes/eval-step-captures-rec-enum-fn.wat` prints `[4 7]`, `[8 2]`, `[2 3]`. The round-trip covers a closure over a Span, a closure over `Option.Some`, and an unnamed closure that captures an unnamed closure. The reversed field zip failed `rendered_record_fields_follow_declaration_order` and was reverted.

Floor `.floor/2026-09-26T01-43-58Z`:

```
Summary [1239.709s] 5405 tests run: 5403 passed (1 slow), 2 failed, 22 skipped
```

The two failures are F-197's lints. `step_user_function_call` and `step_tail_recursion_terminates_under_bound` passed. `origin/the-little-wat-004-eval-step` is still `f9ae53550`.

Nothing further.
