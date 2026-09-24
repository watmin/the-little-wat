# BRIEF — excursus 002 stone 4: one total typer, and both gates to zero

> The builder: *"alright - let's get it built?.."* — closures. They start HERE, because a closure
> value built on today's typer would meet no arm in `:c::type-of`, be guessed `"i64"`, never be shared
> or counted, and let a captured value be mutated in place — F-195, predicted before it is written.
> Closures arrive after this stone, with their own typing rule on day one.

## THE RULINGS — builder

> *"wat should deliver perfect knowledge... i don't see where we are forced to guess anything..."*
> *"panic reserved for compilation only... runtime must forbid panics... all errors must be delivered via matches"*

So in this compiler: **an unknown type is a COMPILE-TIME refusal** (`:c::fail`, naming the form),
never a default. Refusing to compile is the permitted panic.

## THE DEFECT — two gates already name every cause

```
rules: 8 conflicts in 10,307 argument-parameter pairs   (the compiler disagrees WITH ITSELF)
types: 9 type conflicts in 17,367 nodes both typed       (the compiler disagrees WITH THE LANGUAGE)
```

Four causes, all in the type reconstruction (~216 lines behind a waist of 32 `:c::type-of` callers):

- **F-194** — `:c::type-of-form`'s variant arm (`elf/compile.wat` ~1374-1379) spells a constructor by
  the heap flag alone, ignoring the TIER. `:c::enum-ty` (`:963`) is the function that knows.
- **`;arg` dropped** — the same arm drops the instantiation (`elf/src/option.wat`, inliner-dependent).
- **F-195** — `:c::type-of-form` has no `match` arm, so a match-bound value is guessed `"i64"`: a
  SILENT WRONG ANSWER on `main` (`elf/probe/match-i64.wat`, native `4|5`, interpreter `4|4`).
- **The six guesses** — `"i64"` for an unknown at `:747` (`:c::lookup-ty`), `:1135` (`:c::fn-ret`),
  `:1195` and `:1213` (`:c::ty-node`), `:1354` (`:c::type-of`), `:1413` (`:c::type-of-form`).
  (`:1234`, `:1388` and `:3158` are genuine `i64` types, not guesses.)

## THE WORK

1. **Measure before you refuse.** In a scratch variant, count how often each of the six guesses FIRES
   on the corpus and the compiler itself, and on which forms. Each firing is a form the typer never
   learned. This is the map for step 2 and the evidence for STOP-1.
2. **One derivation.** Every node's type comes from ONE function behind the waist. A constructor's
   type comes from `:c::enum-ty` (tier and `;arg`) on every path that types one. `match` has an arm.
   A node the inliner makes carries its origin's type (stone 1 already gave it the origin's position).
3. **Totality.** Each of the six guesses becomes a `:c::fail` that names the form and the position.
4. **Both gates to MUST-BE-ZERO.** `tools/rules.sh` stops being report mode: any boundary conflict or
   type conflict fails `elf-run`. `refined` (the checker's variant type against the compiler's enum
   type) stays allowed — it is representation, not a disagreement.

## READ IN ORDER

```
docs/excursus/2026/09/002-no-guesses/DESIGN.md, and SCORE-stone-1, -2, -3   the gates, how they work, what they found
FINDINGS.md F-194, F-195                                                    the two worst causes, with probes
elf/compile.wat:963    :c::enum-ty          the one function that knows tier and instantiation
elf/compile.wat:1324   :c::type-of          the waist
elf/compile.wat:1356   :c::type-of-form     the variant arm (F-194, ;arg) and the missing match arm (F-195)
elf/compile.wat:1425   :c::ty-bind          how a let binding is typed from its initialiser
elf/compile.wat:745    :c::lookup-ty        the first guess
tools/rules.sh, tools/rules/check.wat       the gates you turn to zero
```

## STOP TRIGGERS

- **STOP-1 — a guess fires on a CORPUS program in a way the typer cannot be taught this stone.**
  Turning it into `:c::fail` would refuse a program that runs today. List form, file, count; do not
  refuse the corpus to make the gate green, and do not keep a quieter default.
- **STOP-2 — you are about to add a second place a type is derived.** One function answers; every
  path calls it. A second answerer is F-194's disease.
- **STOP-3 — a corpus program's emission moves for a reason you cannot name.** A fix to a wrong guess
  may change code (F-195's program MUST change: it begins sharing). Every moved program is explained
  by the guess it stopped making; an unexplained move is a STOP.
- **STOP-4 — a red.** Capture it; never re-run it.

## OUT OF SCOPE, AFFIRMATIVELY

Closures (the next stone — this one makes them safe to build) · stone 0b and stone 1 re-landing ·
F-007, F-198 (wat-rs) · anything in wat-rs.

## METHOD

`/home/watmin/Work/holon/the-little-wat`, `main`. `timeout -s KILL` on every wat run; tree untouched
while `bootstrap.sh`/`elf-run.sh` run; every replacement asserts it matched; `cond` ends in
`(:else …)`; no `_`, no catch-all; bootstrap without `--fast`. Every number the SCORE prints is one you
measured. **Leave the tree dirty; commit nothing.** Write `SCORE-stone-4-one-total-typer.md`.
