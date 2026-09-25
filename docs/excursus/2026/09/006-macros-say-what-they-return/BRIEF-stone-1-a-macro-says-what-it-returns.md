# BRIEF — excursus 006 stone 1: a macro says what it returns

> The builder, 2026-09-25: *"wat macros declare a ret val.. so a macro can declare it returns an int
> and it can be honest?"* — scored by the four questions, candidate E passes all four; today's
> mandate and every interim fail Honest. *"get it drawn"*.

## FIRST — park excursus 004 on its own branch

Your excursus 004 re-strike is uncommitted in `wat-rs` on `the-little-wat`. This stone needs that
tree clean, and it takes ONE piece of 004 with it.

1. `git switch -c the-little-wat-004-eval-step`, commit the 004 work there as it stands (message:
   "WIP excursus 004 stone 1 re-strike -- parked for 006"), `git push -u origin` that branch
   (GitHub is the DR site). `git switch the-little-wat` — clean.
2. **Bring the renderer across, and only the renderer**: 004's widening of `value_to_watast`
   (records, enums, Vector / PersistentVector / HashMap / PersistentMap / HashSet, registered
   functions as their keyword, closures as a `fn` form with their captures substituted), its
   render test, and nothing of the stepper. "Every value that has syntax renders ONE way" is half of
   this stone's contract. Fix what the weighing found in it: the enum assertion at the old
   `runtime.rs:20588` becomes EXACT (the `no_loose_string_assert` lint), and the `"::"` test at the
   old `:13464` is stepper code and does not come across.

## YOU ARE NEW TO THIS — read first

1. `the-little-wat/docs/excursus/2026/09/006-macros-say-what-they-return/CRAWL.md` — the measurement:
   934 macros expanded over 2,616 programs, 933 return a form, one (`:t::deep-answer`) does not
2. `the-little-wat/FINDINGS.md` — `### F-206`, then `### F-204`
3. `the-little-wat/docs/excursus/2026/09/004-eval-step-steps-what-eval-runs/WEIGH-stone-1-refuted.md`
   — why the renderer exists and what it must render

## THE CONTRACT

**A macro declares the type its body produces, and the checker holds the body to it exactly as it
holds a `defn`'s. The expansion is that value's syntax, from the one renderer.** A form is one
possible return type (`:wat::WatAST`), not the only one. A macro body with a type error is refused by
`--check` whether or not any expansion reaches it. The only refusal left at expansion is a value
with no syntax (a handle, an fd), named by the macro and the value.

## THE WORK

1. **The mandate goes.** `src/macros/parse.rs:~215-230` refuses any declared return but
   `:wat::WatAST`. The parameter rules above it STAY (a parameter binds a form, a rest parameter a
   Vector of forms) — those are true. `MacroDef` (`src/macros/registry.rs:9`) carries the declared
   return type.
2. **Macro bodies are type-checked (F-206).** Parameters typed `:wat::WatAST`, a rest parameter
   `(:wat::core::Vector :- [:wat::WatAST])`, the body against the declared return — through the
   machinery that checks a `defn` body (`check_function_body`, `src/check.rs:1865`), wherever macro
   definitions are reachable from `check_program`. Every macro, used or not.
3. **The expansion boundary** (`src/macros/expand.rs:1262-1285`) renders through the one renderer.
   Its comment and arc 249's test `program_body_producing_non_ast_rejected` (`src/macros/tests.rs`)
   are rewritten to the stated contract: a body producing a Vector while declaring `:wat::WatAST` is
   refused by the TYPE check, naming the macro, the declared type and the body's type.
4. **The one lie in the corpus**: `:t::deep-answer`
   (`tests/macros/probe_macros_unbounded_depth.wat:10`) declares `-> :wat::core::i64`.
5. **`src/kernel/source.rs:97`** — its comment says a `Frame` value cannot cross `value_to_watast`;
   rewrite it to what is now true. Its behaviour is out of scope.

## THE FIXTURES

- `the-little-wat/probes/macro-body-untyped.wat` and `macro-declared-form-returns-int.wat` — both
  must now FAIL `wat --check`, naming the macro.
- **Write, each run first on the interpreter:** a macro declared `-> :wat::core::i64` returning an
  integer; one declared `(:wat::core::Vector :- [:wat::core::i64])` building a Vector of forms that
  evaluate; one returning a record; one returning an enum value; one whose unused arm has a type
  error (refused by `--check`).

## STOP TRIGGERS

- **STOP-1 — typing a macro body needs a second type checker** rather than the `defn` body machinery.
  Report what stands between macro definitions and `check_program`.
- **STOP-2 — the new check refuses more than ten existing macros** across wat-rs and the-little-wat.
  List them with each error before fixing any: they are latent bugs the builder should see.
- **STOP-3 — a floor red** other than F-197's two lint reds. Capture the arm; never re-run a red.

## OUT OF SCOPE

The stepper (it waits on `the-little-wat-004-eval-step`) · the pending build-time freeze of stdlib
expansion (not on this branch) · macro hygiene and purity rules · anything in `the-little-wat`'s
compiler.

## METHOD

`timeout -s KILL` on every wat run; your own `CARGO_TARGET_DIR`; the floor is
`NEXTEST_TEST_THREADS=4 scripts/floor.sh` with nothing else building in that directory; no `_`
arms added; assert every text replacement. Commit NOTHING on `the-little-wat` (the parked 004 branch
is the one commit this stone makes). Write
`the-little-wat/docs/excursus/2026/09/006-macros-say-what-they-return/SCORE-stone-1-a-macro-says-what-it-returns.md`.
