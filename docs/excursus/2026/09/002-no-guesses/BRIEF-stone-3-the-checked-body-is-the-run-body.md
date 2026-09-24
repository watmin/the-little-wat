# BRIEF — excursus 002 stone 3: the checked body is the run body (F-196, option E)

> `wat --check` does not type-check a function body spelled with namespaced symbols — most of this
> corpus, and the spelling wat is migrating TO (arc 251.8d: *"`::` retires as a reference
> spelling"*). The checker checks one copy of each body; the runtime runs another.

## ⚠ THIS IS NOT ADDITIVE — and the builder chose it

wat-rs's `the-little-wat` branch is additive-only by standing rule. This stone changes what `--check`
reports, on purpose: it starts finding errors it was missing. The builder decided it by the four
questions, and corrected the orchestrator's scoring on the way — *"simple is a measure of complexity,
not difficulty"* — which is why this is option E (one copy), not D (two copies kept equal).

## THE MECHANISM — read on the disk

```
wat-rs/src/freeze.rs:892-903      the pipeline: 6 register defines · 7 normalize · 8 check · 9 freeze
wat-rs/src/declare/register.rs:161 register_defines -- "pre-registers a def whose RHS is (fn …)"
wat-rs/src/freeze/env.rs:349      step 7: residue = normalize_symbol_refs(residue, …) -- RESIDUE ONLY
wat-rs/src/freeze.rs:1297         step 8: check_program(&bundle.residue, &bundle.symbols, …)
wat-rs/src/freeze.rs:618-627      step 9: register_runtime_defs(&program, …) -- evaluates the def
                                  forms IN THE NORMALIZED RESIDUE; that is what runs
```

So the checker's bodies come from step 6 (un-normalized) and the runtime's from the residue
(normalized). Step 7's own comment states the intent this stone fulfils: *"normalize before resolve
so rewritten AST flows through check + eval with keyword heads."*

Live sessions (`src/runtime.rs:12360`, `eval_form_against_defs`) call `startup_from_forms` — the SAME
pipeline — so the fix covers the REPL path by construction. Verify that it does.

## THE DESIGN — E, one copy

Step 6 DECLARES (names and signatures — what normalization and the checker need before anything runs).
The ONE body of each function is the normalized `def` in the residue: the checker checks THAT body
against the declared signature, and step 9 evaluates THAT same form. How the pre-registration stops
holding a body (or stops being consulted for one) is yours to derive — but when you are done, there is
exactly one place a function body lives between normalization and evaluation.

Prior art in the same file: step 7.7 (`freeze/env.rs`, "BRIEF-STONE-extend-user-checked") closed
this same class for `extend-type` — *"Without this, a user satisfier's impl body is never
type-checked."* Read it first.

## THE PROBES — the bar

- `(user/slen 5)` against a `:user::S` parameter, NAMESPACED spelling: `wat --check` must now exit
  **1** with `TypeMismatch … expects :user::S; got :wat::core::i64` (today: exit 0, then a runtime
  `PatternMatchFailed`). The keyword spelling must still exit 1 exactly as today.
- the same shape through a LIVE SESSION form, if the session surface lets you drive one.
- `elf/probe/nth-record.wat` — which `--check` passes today and the checker refuses once it sees the
  normalized body — must now fail `--check`.

## STOP TRIGGERS

- **STOP-1 — the declare-time registration turns out to NEED the body** (something consumes it before
  step 7 — a macro, a const-eval, a rete-defn stamp). Then E's premise fails; STOP and report what
  needs it and why. Do not fall back to D without the builder.
- **STOP-2 — the fix newly fails more than 10 files in wat-rs's own tree** (`wat/`, `tests/`,
  `wat-scripts/`) under the floor. Each is a REAL latent error the old check missed; that backlog is
  the builder's to see before anything is changed to make them pass. List them; do not edit them.
- **STOP-3 — any change in what a CORRECT program does at runtime.** This stone moves the check, not
  execution. The floor's runtime tests and the-little-wat's `elf-run` differential are the witnesses.
- **STOP-4 — a red that is not one of F-197's three.** Capture it; never re-run it.

## OUT OF SCOPE, AFFIRMATIVELY

Fixing latent errors the new check reveals · F-197's lints · the compiler in the-little-wat · pushing.

## METHOD

wat-rs on `the-little-wat` (HEAD `bbfac2ee8`, clean). The floor at `NEXTEST_TEST_THREADS=4` is the
gate. Its BASELINE is already captured and is red for pre-existing reasons (F-197):
`wat-rs/.floor/2026-09-24T07-55-54Z/ARM.txt` — 2 content-lint failures naming
`tests/resolve/probe_little_wat_bits_and_code_point.rs`, and the 600 s timeout of
`every_wat_scripts_file_loads_on_the_current_runtime`. Anything else red is yours to explain.
Rebuild `target/release/wat`, then run the-little-wat's `tools/elf-run.sh` (its two rete gates depend
on `--check`'s type dump). **Leave the tree dirty; commit nothing.** Write
`SCORE-stone-3-the-checked-body-is-the-run-body.md` beside this file.
