# WEIGH — excursus 007 stone 1: three small rows back; the contract is credited

The orchestrator's weighing, 2026-09-25. **Keep the tree; finish these, then the floor.**

## Credited

The four verbs as the contract states them, both round-trips and both refusals in unit tests; the
probe (`":foo"` from both `to-string` and `str`, `"foo"` from `name`); no caller was hand-adding a
colon (STOP-1 did not fire); the renamed callers; `koans/idiom` 27/0. The two step-test reds are the
known ones (the stepper is parked on `the-little-wat-004-eval-step`).

## R1 — the rename missed three extensions

Measured by the orchestrator, exactly the five files the floor named:

```
tests/diagnostics/probe_diagnostic_value_snapshot_in_errors__probe_2_not_callable_renders_runtime_built_keyword.edn
tests/diagnostics/probe_diagnostic_value_snapshot_in_errors__probe_6_runtime_built_keyword_renders_producer_info.edn
tests/diagnostics/probe_stone_233_3_runtime_error_edn__provenance_runtime_built.edn
tests/function/probe_diagnostic_non_vector.wat.bad
tests/types/probe_stone_233_2_k_variant_retired_let_keyword.wat.expr
```

Each by MEANING, as step 2 did: a `.wat.bad`/`.wat.expr` call becomes `from-name`; a golden that
records the producer records the producer that now runs. Then sweep EVERY extension in both trees
(not a list of known ones) for the old tokens.

## R2 — prose that now lies

Comments that describe the OLD behaviour, e.g. `src/reflect/verbs.rs:1756` ("`from-string` ...
refuses a leading colon" — that is now `from-name`), `wat/service.wat:477` ("`keyword/to-string`
strips its" colon), `wat/core.wat:520` (`(keyword/from-string (keyword/to-string ns))` documenting
code that now calls `name`/`from-name`), and `wat/service.wat:440/532/602/740/834`, `src/runtime.rs:20798`.
Each says what is true now: `name`/`from-name` where the colon-free name is meant, `to-string` only
where the written form is. A comment that is history (a dated arc note) may keep the old name if it
says so.

## R3 — `wat_value_ui`'s deadline

It timed out again (a dev-profile trybuild compile of 22 s inside a 30 s kill). Its `.config/nextest.toml`
override lives only on the parked 004 branch. Bring that one override across with its dated
measurements; the rest of 004 stays parked.

Then `NEXTEST_TEST_THREADS=4 scripts/floor.sh` alone, and report: green except F-197's two lints and
the two known step tests.
