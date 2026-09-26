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

---

# Round 2 — the re-strike weighed (2026-09-25)

**Credited, on the orchestrator's measurement:** the library's seventy errors are gone (a one-line
program checks clean); R1–R5 each fixed at its root (R5 was not a design stop: the three arms name
three functions, the honest type is a keyword). And the sweep, against a BASELINE the orchestrator ran
with the 007 binary over the same 2,616 programs:

| | programs |
|---|---|
| refused both before and with 006 | 338 (standalone stdlib files, negative fixtures) |
| **newly refused by 006** | **7 — all wat-rs test fixtures** with the same latent classes as the library |
| refused before, passing with 006 | 6 — incl. `the-little-wat/books/little-prover/ch07-transcript.wat`, `wat/Record.wat`, `wat/service.wat`, `wat/kernel/assertion.wat` |

**006 refuses no user program that passed before.** The floor's nineteen extra reds, read:

| group | tests | the fix |
|---|---|---|
| **G1** goldens whose ONLY difference is standard-library line numbers (the re-strike edited `core.wat`/`service.wat`: 1961→1975, 1464→1479, 893→922, token-diffed by the orchestrator) | the four `peers_bijection_*`, `cond_refuses_missing_else`, `witness_thread_first_empty_step_panics_at_expansion`, `contract_02_non_exhaustive_cond_names_else`, the two `format_strict_*` | regenerate each golden; show that every changed token is a line/column |
| **G2** `macro-error` now has a scheme | `checker_skip_debt_is_named_and_frozen`, `doc_arg_ret_types_match_checker_scheme`, `probe_can_doc_types_reconstruct_the_checker_scheme` | its entry leaves the skip-debt ledger (it is no longer debt); its doc names the `T` it returns |
| **G3** test fixtures with the library's latent classes — the sweep's seven | `macro_output_reexpands_record_def_and_enum_wraps_it` (`name` on a form), `canonical_comprehension_replaces_for`, `mint_program_body_fold`, the three `diag_thread_*` (declared `HolonAST`, produce `WatAST`), `subs_tuple_char_walk_runs_at_macro_eval` (bare `Tuple`) | fix each at its root, as R2/R3 did — the declaration says what the body produces |

**R6 — a macro cannot yet return a record or an enum value.** `aggregate-new` is expand-time legal
and refuses because the macro evaluator's symbol table has no type registry; record and variant
constructors are not expand-time heads. That is part of E's promise ("the expansion is that value's
syntax"), so it is this stone's: give the macro evaluator the type registry it needs and make the
PURE constructors expand-time legal. **STOP** if that is more than threading the registry through
and allow-listing constructors — report what it takes.

Then `macro-returns-record.wat` and `macro-returns-enum.wat` agree with the value written by hand, and
the floor: green except F-197's two lints and the two step tests (the stepper, still parked).

---

# Round 3 — the builder's ruling on R6 (2026-09-26)

> *"macros by definition may only return primitives provided by the core language - user defined
> items cannot exist to be returned"*

R6 is not a missing capability; it is the rule, and the rule belongs where a declaration is read, not
where an expansion happens to fail. So:

- **R6′ — a macro's declared return type is a core-language type, or the `defmacro` is refused at
  definition, naming the rule.** A declared return that names a user-defined type (a `defrecord`, a
  `defenum`, a `typealias` to one, or any type containing one — a Vector of a user record) is a
  `MalformedDefmacro` at parse time: "a macro returns a core-language value; `:user::P` is a
  user-defined type, which does not exist when a macro expands". Today's expansion-time refusal
  ("aggregate construction requires the type registry") stops being the gate: it is unreachable
  from a program that parses.
- `probes/macro-returns-record.wat` and `probes/macro-returns-enum.wat` (user types) become standing
  NEGATIVE fixtures: refused at definition, the message naming the rule and the type.
- **Core-language enums** (`:wat::core::Option`, `:wat::core::Result`) are core types, so a declaration
  naming them is legal; whether their constructors are expand-time legal is NOT this stone's --
  report what `macro-returns-*` shows for `Option`, and change nothing there.
- **R7 — your own edit broke `tests/macros/probe_arc279b_subs_tuple_macro_eval.wat`**: the `)` on
  line 23 closes the `fn` after its new return type, the reader reports the stray close at 33:19.
  Fix it so the fold declares `(Tuple :- [String i64])` AND the file parses.

Then the floor: green except F-197's two lints and the two step tests.
