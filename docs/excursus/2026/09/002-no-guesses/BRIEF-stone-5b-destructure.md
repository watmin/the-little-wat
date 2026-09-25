# BRIEF — excursus 002 stone 5b: destructure an aggregate by its field names

> The builder's own words for how wat is meant to be written: *"when accepting a parent you must use
> match to handle the branches, when accepting a variant you don't need to match on it"* — his example
> destructured a `Some` with `(wat.core/let [{:keys [value]} some] …)`. The native compiler has no
> destructuring at all today.

## YOU ARE NEW TO THIS WORK — read the history, do not infer it

This repository is `the-little-wat`: a self-hosting compiler for the wat language, written in wat,
emitting x86-64 (`elf/compile.wat`, ~6,900 lines, plus `elf/lib/`). It reproduces itself byte-for-byte
(`tools/bootstrap.sh`), and every program is differentially checked against wat's interpreter
(`../wat-rs/target/release/wat`) by `tools/elf-run.sh`. Read, in order:

1. `docs/excursus/2026/09/002-no-guesses/DESIGN.md` — the "no guesses" rule, and the two rete gates
2. `docs/excursus/2026/09/002-no-guesses/SCORE-stone-5-variant-types.md` — the stone before this one:
   variant types, assignability, and how the typer and gates now stand
3. `FINDINGS.md` — entry `### F-188`: why every pointer read out of a container MUST be counted, and
   why `:c::read-out` is the one function allowed to emit such a read

## THE CONTRACT — the language's, measured on its checker

- `(let [{:keys [f g]} x] …)` binds each named field of `x` to a local of the same name.
- `x` must be an AGGREGATE whose fields are known: a **variant type** (`(:user::Opt.Some :- [String])`)
  or a **record**. On the PARENT enum it is refused — wat's checker says, for `(:user::Opt :- [String])`:
  *"keys-destructure (value) expects an aggregate type"*. The native compiler refuses it too, at compile
  time, naming the form.
- Each bound local's type is the field's declared type (instantiated) — from the typer's one derivation.

## THE FIXTURES — on disk, checked on the interpreter

| file | interpreter | the native compiler must |
|---|---|---|
| `elf/probe/destructure-variant.wat` | `3 3 0` | compile and agree |
| `elf/probe/destructure-record.wat` | `39` | compile and agree |
| `elf/probe/destructure-parent.wat` | refused by `--check` | refuse at compile time |

## READ IN ORDER — the rooms

```
elf/compile.wat  :c::let-form     where a let binding is compiled
elf/compile.wat  :c::bind-each    how each binding is bound -- and typed through :c::bind-ty
elf/compile.wat  :c::bind-ty      the typer's answer for a binding (one derivation)
elf/compile.wat  :c::arm-binds    how a MATCH arm already binds a variant's payload fields -- the
                                  field-reading you reuse, not re-implement
elf/compile.wat  :c::read-out     the ONE function that emits a read out of a heap object and counts it
tools/reads.sh                    fails the build if any read bypasses :c::read-out
```

Find each by name (`grep -n '^(:wat::core::defn :c::let-form '`); line numbers move.

## STOP TRIGGERS

- **STOP-1 — you are about to read a field any way other than through `:c::read-out`.** That re-opens
  F-188 (a pointer read out of a container, uncounted, mutated in place while the container holds it).
  `tools/reads.sh` will say so.
- **STOP-2 — you are about to type a bound local yourself.** Its type is the field's declared type from
  the typer; a second derivation is how F-194 happened.
- **STOP-3 — destructuring the parent compiles.** It must be a compile-time refusal.
- **STOP-4 — a red, or a gate above zero.** Capture it; never re-run it to make it pass.

## OUT OF SCOPE

Skipping the tag check for a variant-typed value (stone 6) · closures · nested destructuring patterns
beyond `{:keys [...]}` · anything in `../wat-rs`.

## METHOD

`timeout -s KILL` on every wat run. Leave the tree alone while `tools/bootstrap.sh` or `tools/elf-run.sh`
runs. Assert every text replacement matched exactly once. In wat, `cond` arms end in `(:else …)`; there is
no `_` and no catch-all. Bootstrap without `--fast`. `tools/probe.sh <file>` compiles one program and
diffs it against the interpreter in seconds; `tools/rules.sh <file>` runs both gates on one program.
Every number the SCORE prints is one you measured. **Leave the tree dirty; commit nothing.** Write
`docs/excursus/2026/09/002-no-guesses/SCORE-stone-5b-destructure.md`, one section per EXPECTATIONS row.
