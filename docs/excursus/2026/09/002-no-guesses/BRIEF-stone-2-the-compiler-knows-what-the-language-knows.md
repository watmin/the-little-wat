# BRIEF — excursus 002 stone 2: the compiler knows what the language knows

> Stone 1 made the compiler agree WITH ITSELF. This stone makes it agree WITH THE LANGUAGE: wat's own
> checker states the type of every node, the compiler states the type it gave every node it typed,
> and rete reports every place they differ. "wat delivers perfect knowledge" becomes a gate.

## WHY THIS, NOW

The builder, on learning the compiler "forgets" types: *"i thought wat delivers perfect knowledge...
how are we capable of forgetting?"* It is not forgetting — it never received it. wat's checker is
**31,625 lines** of Rust (`wat-rs/src/check.rs` + `types.rs`); the native compiler cannot call it
(it self-hosts), so it carries its own reconstruction — **~216 lines** behind a narrow waist
(`:c::type-of`, 32 call sites) — and guesses `"i64"` for whatever it was never taught. A second
derivation always drifts unless it is the same code or continuously checked against the first. This
stone is the second.

## THE RULING — builder, 2026-09-23

> *"wat's long term shape is totality... panic reserved for compilation only... runtime must forbid
> panics... all errors must be delivered via matches..."* — and, to these next steps: *"let's see
> where they lead us..."*

## THE TWO TYPE LANGUAGES, and why both gates stay

The checker's types are WAT types (`:user::S`, `(:wat::core::Vector :- [:wat::core::i64])`). The
compiler's strings are wat type **plus representation** (`penum::user::S`, `henum::user::S`,
`vec:i64`). Tier is representation, not type. So:

- **F-195** (`i64` where the language says Vector) is a TYPE disagreement → this stone must flag it.
- **F-194** (`henum:` vs `penum:`, both `:user::S`) is a REPRESENTATION disagreement → this stone
  must NOT flag it. Stone 1 does. The two gates see different things, and row 3 proves it.

## THE WORK

1. **wat-rs, additive only** (branch `the-little-wat`, already checked out and clean). `infer`
   (`src/check.rs:1921`) is the one function every expression's type passes through, and the checker
   keeps no per-node record. Record `(span, type)` as `infer` returns, **off by default**, with the
   FINAL substitution applied before anything is written (a type recorded mid-inference can still
   hold a type variable that unification sharpens later — `:None` returns `Option` of a fresh `T`).
   A mode that dumps them for a file, one per line, at wat-grep's position convention. Nothing an
   existing caller sees may change.
2. **The compiler** exports, at its type waist, the type it gave each node — in WAT's spelling,
   through **one** translation function (representation tiers collapse to the enum's type).
3. **The rules** join checker-type and compiler-type by position; a difference is a conflict,
   reported with both types; agreements counted. REPORT mode, run by `tools/elf-run.sh` beside
   stone 1's gate.

## READ IN ORDER

```
docs/excursus/2026/09/002-no-guesses/SCORE-stone-1-the-compiler-agrees-with-itself.md   the pattern, and how positions were recovered
tools/rules.sh, tools/rules/check.wat           stone 1's exporter-and-checker -- extend it, do not fork it
wat-rs/src/check.rs:1921  infer                 the waist on the language's side; read its dispatch and CheckResult
wat-rs/src/check.rs:565   check_program         where a file's checking begins and ends -- where a dump belongs
elf/compile.wat  :c::type-of and its 32 callers  the waist on the compiler's side
FINDINGS.md F-194, F-195                        what each gate must and must not see
```

## STOP TRIGGERS

- **STOP-1 — you are about to change anything an existing wat-rs caller observes.** Additive only:
  recording is off unless asked for, and no existing output, error or test moves.
- **STOP-2 — the translation from the compiler's spelling to wat's needs more than one function.**
- **STOP-3 — one span carries two checker types** (macro expansion can put a synthesised node at an
  original's position). Report how often and where; do not pick one silently.
- **STOP-4 — a type variable survives the final substitution.** Report it; do not print a variable
  as though it were a type.
- **STOP-5 — you are about to fix a conflict.** This stone must SEE; the total typer is the next one.
- **STOP-6 — a red.** Capture it; never re-run it.

## OUT OF SCOPE, AFFIRMATIVELY

Fixing any disagreement · the total typer · turning either gate to must-be-zero · pushing wat-rs.

## METHOD

Both repos, their current branches. `timeout -s KILL` on every wat run. In wat-rs, the test floor is
the gate for touching `check.rs`: `NEXTEST_TEST_THREADS=4` (the floor is red at 8 and 16 threads on
this laptop — deadlines only). In the-little-wat: the tree untouched while `bootstrap.sh`/`elf-run.sh`
run; every replacement asserts it matched; `cond` ends in `(:else …)`; bootstrap without `--fast`.
Every number the SCORE prints is one you measured. **Leave both trees dirty; commit nothing.** Write
`SCORE-stone-2-the-compiler-knows-what-the-language-knows.md` beside this file.
