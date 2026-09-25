# WEIGH — excursus 004 stone 1: REFUTED on one row, the rest credited

The orchestrator's weighing of `SCORE-stone-1-step-user-code.md`, 2026-09-25, on Grok's build
(`CARGO_TARGET_DIR=/home/watmin/.cache/wat-step-004`). **Keep the tree; this is a re-strike of two
things, not a restart.**

## What held

The diff does what the SCORE says: `is_step_canonical` is gone (a descended child is a value when
its own step answers `Terminal`/`AlreadyTerminal`); `NoProgress` through `checked_step`; symbol heads
through `ns_to_wat_path`; `fn` heads through `peel_fn_form` (reusing `eval_fn`'s peel, which
`eval_fn` itself is untouched by); captured bindings substituted; `closed_env.is_some()` gone.

## Row R1 — captured values that HAVE syntax are refused

`the-little-wat/probes/eval-step-captures-rec-enum-fn.wat`, on your build:

```
(:user::with-rec 1)   -> type-mismatch: expected a form, got wat::core::Record `<user::P{#0: 3, #1: 4}>`
(:user::with-enum 1)  -> type-mismatch: expected a form, got wat::core::Enum `(:user::Opt.Some 7)`
(:user::with-fn 1)    -> type-mismatch: expected a form, got wat::core::fn `<fn>`
```

`eval` answers 4, 8, 2. The contract permits a refusal only for a value with NO syntax. These have
it, and `value_to_watast` must write it:

- a **record** -> its constructor form, `(:user::P :a 3 :b 4)`, each field rendered recursively;
- an **enum value** -> its variant form, `(:user::Opt.Some {:value 7})` / `(:E.V {})`, recursively;
- a **function value that is a registered function** -> its own keyword (`:user::inc`) -- the head
  the stepper already resolves;
- a **closure** -> its `fn` form with ITS captured bindings substituted the same way -- a closed
  lambda, which is exactly what stepping a `fn` head applies;
- a **Vector / HashMap / HashSet / String / bool / nil** -> its literal or constructor form.

What stays a refusal, named by its type: a value with no syntax at all -- a service or channel
handle, an fd, a `WatAST`-opaque host object. List what you refuse in the SCORE.

The differential gate grows by these cases (a closure over each kind), and a mutant that renders a
record field in the wrong order must fail it.

## Row R2 — the floor's deadlines, at the builder's standing direction

Your floor's six extra reds are deadline failures under load (your rebuild into the same target
dir, and the orchestrator's excursus 005 bootstrap, shared the machine: the whole floor took 1,811 s
against 1,337 s the night before). Measured ALONE on your build: the three `nth` deftests ~3.0-3.5 s
against their 5 s default budget; `c5c_nan_is_unordered_gate` 28.6 s and `wat_value_ui` 25.6 s
against the 30 s kill. The stone did not cause them -- but a gate with 1.4 s of margin alone is not
a gate. The builder: *"if we need to bump the timeouts, do it"*. So:

- the `nth` deftests: annotate each with `(:wat::test::time-limit "15s")` -- the macro's own comment
  (`crates/wat-macros/src/lib.rs:869-880`) says a test needing >5 s annotates; do not raise the
  global 5 s deadlock guard;
- `c5c_nan_is_unordered_gate`, `c5b_exact_mixed_numeric_order_gate`, `wat_value_ui`,
  `to_edn_derive_ui`: `.config/nextest.toml` overrides, dated, with these measurements -- the shape
  of the scripts-gate entry above them.

Then run the floor with NOTHING else building in your target dir, and report it.
