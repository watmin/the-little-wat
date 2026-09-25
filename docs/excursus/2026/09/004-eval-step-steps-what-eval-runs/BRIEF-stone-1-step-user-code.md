# BRIEF — excursus 004 stone 1: `eval-step!` steps what `eval` runs

> The builder, 2026-09-25: *"not supporting user defined functions is like trying to read /dev/null
> meaningfully ... i'm not convinced eval-step! is even what we actually want if we deny user defined
> forms"* — then, *"let's get this fixed"*.

## YOU ARE NEW TO THIS — read the history first

This stone is in **wat-rs**, branch `the-little-wat` (writable, additive; commit there and push —
GitHub is the DR site). Read, in order:

1. `the-little-wat/FINDINGS.md` — `### F-204` (this stone's evidence), then `### F-198`
2. `wat-rs/docs/arc/2026/04/068-eval-step/DESIGN.md` — what a step IS and what it is FOR: the
   step table (`(:fn-name args...)` — "one step = one β-reduction"), Q6 on lambdas
3. The hologram it serves: every intermediate is a form, hence a cache key
   (`holon-lab-trading` BOOK chapter 65; arc 068's DESIGN quotes the builder's direction)
4. `the-little-wat/docs/excursus/2026/09/002-no-guesses/SCORE-stone-3-the-checked-body-is-the-run-body.md`
   `:194-215` — why the two step tests went red

## THE CONTRACT

**`eval-step!` is defined wherever `eval` is, for pure forms: stepping any form to its terminal
answers what evaluating it answers.** The state stays ONE self-contained form, because that is what
makes it a cache key. The only refusals left are an effect (`EffectfulInStep`, unchanged) and a
value with no syntax to write down — named for what it is, never a category that can grow.

## THE WORK

1. **User functions step.** `step_user_call` substitutes the arguments (today's rule), and ALSO the
   captured bindings of `closed_env` that the body mentions and the parameters do not shadow, each
   rendered as a form (`value_to_watast`). A top-level `defn` substitutes nothing extra. A value with
   no syntax is refused naming that value. The proxy `closed_env.is_some()` is gone.
2. **Symbol heads step.** A namespaced symbol head (`wat.core/+`, `user/add1`) means what its
   keyword means — the ONE mapping `crate::edn::render::ns_to_wat_path` (as `parse_type_node` does,
   `src/types.rs:4862`); do not write a second. A `fn` form in head position is applied: substitute
   its parameters into its body.
3. **A step always makes progress — by construction.** Two parts:
   - the class, not the case: a sub-form whose step answers `Terminal` is a VALUE to the rule that
     descended into it. Make canonicity and the terminal rules one fact rather than two lists
     (`is_step_canonical` is a hand list that has now missed rationals AND `fn` forms);
   - the wall: `eval-step!` answering `StepNext` of a form equal to its input is a runtime error
     naming the form (`NoProgress`, or the nearest existing kind), never a silent fixed point.
4. **The gate.** A differential test over a corpus of pure programs: each stepped to its terminal
   and each evaluated, compared (`coincident?` for floats). It must cover both spellings, a plain
   `defn`, recursion, a `let`-bound `fn`, a top-level `def` of a closure, a function returning a
   closure then applied, and a closure over a closure. `step_round_trip_agrees_with_eval_ast`
   (`src/runtime.rs:19897`) is the seed to grow.

## THE ROOMS — `wat-rs/src/runtime.rs` unless named

- `:12935` `step_list` — the head dispatch: the `Symbol` arm (`:12953`) and the `_` arm (`:12964`)
- `:13066` the `:wat::core::fn` terminal rule; `:13096` `is_step_canonical`; `:13154`
  `step_descend_then_fire`; `:13311` `step_let`; `:13547` `step_match` — every rule that descends
- `:13713` `step_user_call`; the substitution machine above it (`substitute`, capture-free by
  `Identifier` scope-set)
- `:7138` `value_to_watast` — Value back to a form; what it cannot render is the one honest refusal
- `:6801`, `src/function/eval.rs:109`, `src/value/environment.rs:315` — where `closed_env` is set
- tests: `:19708` `step_drive_to_terminal`, `:19862` `step_user_function_call`, `:19977`
  `step_tail_recursion_terminates_under_bound` (both RED — they go green UNCHANGED), `:19897`
- `wat/eval.wat` — `StepResult` / `:wat::eval::walk`

## THE FIXTURES — on disk, in `the-little-wat/probes/`

`eval-step-builtin-kw`, `-user-fn-kw`, `-builtin-symbol`, `-user-fn-symbol`, `-let-bound-fn` (hung),
`-toplevel-closure`, `-recursion`, and `eval-step-trace-let-bound-fn` (prints each step). Each prints
`walk=Ok {:value [TERMINAL COUNT]}`; the terminal must equal `eval`'s answer (in each file's header).

## STOP TRIGGERS

- **STOP-1 — a stepped terminal differs from `eval`'s** for a pure program. Capture both.
- **STOP-2 — making a case step needs a second copy of evaluation semantics** (a stepper-side
  re-implementation of what `eval` does, rather than a rewrite). Report the case.
- **STOP-3 — a floor red other than the known ones** (F-197's two lint reds; the two step tests
  this stone turns green). Capture the arm; never re-run a red.

## OUT OF SCOPE

A CEK machine (scheduled by the builder, months out) · stepping effects · performance of the walk ·
`holon-lab-trading` itself.

## METHOD

**Build with `CARGO_TARGET_DIR` pointed at your own scratch directory until the orchestrator says
otherwise** — `wat-rs/target/release/wat` is in use weighing excursus 003 stone 1, and the
`the-little-wat` tree holds that stone's uncommitted work: do not touch it. `timeout -s KILL` on
every wat run; the floor is `NEXTEST_TEST_THREADS=4 scripts/floor.sh` (with your target dir); no
`_` arms added; assert every text replacement. Write
`the-little-wat/docs/excursus/2026/09/004-eval-step-steps-what-eval-runs/SCORE-stone-1-step-user-code.md`.
Commit NOTHING; leave the wat-rs tree dirty.
