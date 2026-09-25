# WEIGH — excursus 006 stone 1: the check works; the library it exposed is the re-strike

The orchestrator's weighing of `SCORE-stone-1-a-macro-says-what-it-returns.md`, 2026-09-25, and the
re-strike, now that excursus 007 has landed (wat-rs `40ddeac4d`: `name`/`from-name`).

## Credited

The mandate is gone and `MacroDef` carries the declared return; every registered macro's body is
checked through `check_function_body`; `macro-error` is `∀T. String -> :T`; the renderer came across
alone (record fields in declaration order, the reversing mutant fails the render test); arc 249's test
asserts the TYPE refusal; `:t::deep-answer` declares `-> :wat::core::i64`. The check names the lie
(`:my::answer: body produces :wat::core::i64; signature declares :wat::WatAST`) and refuses both
F-206 probes. **What it exposed is the work now:** 70 type errors in the standard library's own
macros, which every program loads. Confirmed by the orchestrator on a one-line program: 70.

## FIRST — resume from the parked branch

`git switch the-little-wat-006-macro-returns`, rebase it onto `the-little-wat` (`40ddeac4d`) — the
stdlib call sites 007 renamed will conflict with nothing of 006's but read the rebase — then carry the
work back onto `the-little-wat` uncommitted, as a strike leaves it. Keep the parked branch as it is.

## THE ROWS — each class fixed at its root, in the library

| class | count | the fix |
|---|---|---|
| **R1** `:wat::core::nil` in value position inside `defservice`'s unquotes | 18 | bare `nil` (arc 242's Doctrine 1) |
| **R2** `:wat::keyword::to-string` (now `name`) given a keyword FORM | 17 | one typed conversion, **`:wat::core::ast-keyword`**: a keyword form's keyword. Total at run time (arc 293 — runtime errors are values): the conversion answers an `Option`, and a macro-time helper that needs the keyword or nothing uses `macro-error` (expand time is compilation). Each site reads `(name <keyword>)`. **Then remove the leniency**: `name` and `to-string` accept a keyword VALUE only, as their schemes say. |
| **R3** a fold accumulator declared bare `:wat::core::Tuple` whose body builds `:(String, String)` | 10 | declare the real tuple type |
| **R4** `assertion-failed!`'s `if` — `(Vector :- [(Vector :- [:wat::WatAST])])` against `:wat::WatAST` | 1 | both arms one type |
| **R5** `defservice`'s process-versus-thread `if` arms | ~24 | **read first.** If the two arms are genuinely different types by design (one form per mode), say what the honest type is and fix it; if it is not a plain bug, **STOP** and report the design question before changing it |

Then the rows the first strike could not reach: the fixtures (`probes/macro-returns-{int,vector,record,enum}.wat`
agree with the value written by hand; `macro-unused-arm.wat` and the two F-206 probes refused), the
2,616-program sweep (`allwat.txt`) with every refusal listed, and the floor.

## STOP TRIGGERS

- **STOP-1 — R5 is a design question**, not a bug. Report it.
- **STOP-2 — removing R2's leniency breaks a caller outside macro bodies.** List them.
- **STOP-3 — a floor red** other than F-197's two lints and the two step tests (the stepper is still
  parked on `the-little-wat-004-eval-step`). Capture the arm; never re-run it.

Write the result into `SCORE-stone-1-a-macro-says-what-it-returns.md` as a re-strike section.
