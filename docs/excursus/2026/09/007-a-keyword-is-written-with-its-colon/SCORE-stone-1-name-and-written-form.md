# SCORE — excursus 007 stone 1: a keyword's string is how it is written

Nothing is committed on `the-little-wat`. The binary is `CARGO_TARGET_DIR=/home/watmin/.cache/wat-kw-007`. Every `wat` run was `timeout -s KILL`.

## Row 0 — 006 is parked

`origin/the-little-wat-006-macro-returns` is `48d5294f0`, message `WIP excursus 006 stone 1 -- parked for 007`. `the-little-wat` was clean at `75fcc7638` before this strike.

## The four verbs

| verb | meaning |
|---|---|
| `:wat::keyword::to-string` | the keyword value's own text, colon included |
| `:wat::keyword::from-string` | the inverse; a string with no leading `:` is refused, and the message names that string |
| `:wat::keyword::name` | the name, one leading colon removed. This is what `to-string` did before this stone |
| `:wat::keyword::from-name` | the inverse; a string that starts with `:` is refused, and the message names that string |

A keyword form (`WatAST` of a keyword) is accepted by `to-string` and `name`, same as a keyword value. `(from-string (to-string k))` and `(from-name (name k))` are `k`. Schemes are keyword-to-string and string-to-keyword. `@ExpandTime` is `Legal` on all four. The retired `:wat::core::keyword/to-string` and `from-string` now point at `name` and `from-name`.

## Callers

No caller was `(concat ":" (to-string k))`. The colon-adding sites next to a `to-string` build a different keyword out of pieces (`bracket.wat`'s accessor, `dot-flip-ask-the-substrate.wat`'s `" :" bare`). They now call `name`, which is still colon-free.

The token replace covered `.wat`, `.rs`, and `.md` in both trees, except this stone's brief and expectations, `FINDINGS.md`, and the 006 score. Call sites in `wat/service.wat`, `wat/core.wat`, `wat/Record.wat`, `wat/bracket.wat`, and the koan `01-equalities.wat` now say `name` / `from-name`.

The first replace missed three extensions. The re-strike fixed them by meaning, then swept every extension in both trees:

- `tests/types/probe_stone_233_2_k_variant_retired_let_keyword.wat.expr` calls `from-name` on `"wat::core::nil"`
- `tests/function/probe_diagnostic_non_vector.wat.bad` calls `from-name` on `"wat::core::i64::+"`
- the two value-snapshot `.edn` goldens record producer `:wat::keyword::from-name`, and the call-span end column is 62 (the name is two characters shorter)
- `probe_stone_233_3_runtime_error_edn__provenance_runtime_built.edn` records producer `:wat::core::keyword/from-name`
- `probe_4`'s golden was not an old token; the same two-character shortening moved its columns from 125/127 to 123/125

Comments that described the old contract as current now name `name` / `from-name` where the colon-free text is meant, and `to-string` only for the written form. A dated note may still say `keyword/from-string` when it says that name is history. `FINDINGS.md` was not edited. The two `19-datatypes.tsv` rows are recorded refusals from before this stone, not live calls.

## Measured

Unit tests `keyword_name_drops_the_colon`, `keyword_from_name_prepends_colon`, `keyword_reflection_round_trip`, `keyword_to_string_is_the_written_form`, `keyword_from_string_rejects_a_bare_name`, and `keyword_from_name_rejects_a_written_form` passed. `to-string` of `:foo`, `:wat::core::i64`, and `:user::E.V` is `":foo"`, `":wat::core::i64"`, and `":user::E.V"`. `name` of those is `"foo"`, `"wat::core::i64"`, and `"user::E.V"`. `:foo` agrees with `(:wat::core::str :foo)`.

The CLI cannot put `:wat::core::i64` in value position (Doctrine 1: it is a type keyword). The probe uses `:user::ns::i64` and `:user::E.V`:

```
":foo"
":foo"
":user::ns::i64"
"foo"
"user::ns::i64"
"user::E.V"
":user::E.V"
```

Exit 0. The two `":foo"` lines are `to-string` and `str`.

`./run.sh koans/idiom` with this binary: 27 passed, 0 failed. That suite is the only the-little-wat caller (`koans/idiom/01-equalities.wat`). `elf/` has no call of these verbs. `tools/elf-run.sh` was not run.

## The floor

The first floor, `.floor/2026-09-25T20-51-56Z`, was not re-run. It was `5402 tests run: 5391 passed, 10 failed, 1 timed out`. Past F-197 and the two step tests, the reds were the missed extensions and `wat_value_ui` killed at 30.005s after a 22.29s trybuild compile.

The re-strike brought one nextest override across from the parked 004 branch, and only that test: `wat_value_ui`, period 90s, terminate-after 2 (warn 90s / kill 180s), on default, ci, and slow. Alone on this machine it was 25.6s against a 30s kill. `to_edn_derive_ui` passed the first floor at 28.142s, so it was not copied.

Then `NEXTEST_TEST_THREADS=4 scripts/floor.sh` alone in `/home/watmin/.cache/wat-kw-007`. Doctests exit 0. `.floor/2026-09-25T21-33-52Z`:

```
Summary [1488.622s] 5402 tests run: 5398 passed (6 slow), 4 failed, 22 skipped
```

The four failures are the ones the weighing named:

- F-197 `tests_carry_no_inlined_wat` — one file, `tests/resolve/probe_little_wat_bits_and_code_point.rs`
- F-197 `tests_carry_no_loose_string_assert` — the same six lines (105, 116, 153, 161, 206, 214) and no new site
- `step_user_function_call` — `None`, expected `Some(9)`
- `step_tail_recursion_terminates_under_bound` — `None`, expected `Some(6)`

This branch does not have the parked 004 stepper. `wat_value_ui` passed at 10.617s. No other arm. The arm file is `.floor/2026-09-25T21-33-52Z/ARM.txt`.

## Rows

| # | result |
|---|---|
| 0 | **MET.** `origin/the-little-wat-006-macro-returns` exists. `the-little-wat` was clean before this strike. |
| 1 | **MET** for `:foo` on the CLI (`":foo"` twice, `to-string` and `str`). `:wat::core::i64` is `":wat::core::i64"` in the unit test. The CLI refuses that keyword in value position. |
| 2 | **MET.** Probe prints `"foo"` and `"user::ns::i64"`. |
| 3 | **MET** in the unit tests. `from-string` on `"foo"` and `from-name` on `":foo"` are `MalformedForm` and the reason quotes that input. |
| 4 | **MET** after the re-strike. The missed `.wat.expr`, `.wat.bad`, and `.edn` files record `from-name`. Comments that describe the current verbs name `name` / `from-name` for the colon-free pair. |
| 5 | **MET** for `koans/idiom` (27/0). `elf/` does not call the verbs. `elf-run.sh` was not run. |
| 6 | **MET** against the weighing: green except F-197's two lints and the two known step tests. `wat_value_ui` passed. |
