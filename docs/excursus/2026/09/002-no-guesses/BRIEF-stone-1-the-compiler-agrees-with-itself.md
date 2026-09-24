# BRIEF — excursus 002 stone 1: the compiler must agree with itself at every boundary

> F-194: a `let`-bound tier-1 enum was typed `henum:` as an argument and `penum:` as the parameter it
> fed, and `main` segfaulted. The rules in `rete/` found it at the exact line by modelling the
> compiler — which would duplicate its logic forever. This stone makes the compiler TELL the rules
> what it decided, and the rules only check that its answers agree.

## THE RULING — builder, 2026-09-23

> *"let's get after it - rete has been the thing i have fought hardest for..... structural
> reasoning continues to prove a massive strength...."*

## THE WORK

1. **Positions.** `:rd::Node` (`elf/lib/reader.wat`) gains the node's START — the reader already
   holds `pos` at a form's first character. Exported as wat-grep's convention, measured: 1-based
   line and column of the first character; a list at its `(`.
2. **The export.** When asked (and only when asked — a normal build is unchanged), the compiler
   writes, per program, the facts it decided:
   - `CArg` — at each call to a user function: the call's position, the callee, the argument's
     index, and **the type the compiler gave that argument**;
   - `CParam` — for each `defn`: its name, the parameter's index, and **the type the compiler gave
     that parameter**.
   Where and how they are written is yours to derive (a `.facts` file beside each binary is one way).
3. **The checker.** `tools/rules/` — a wat program run by wat-rs that does what `wat/grep.wat`'s
   `run-one` does (`facts-of` → `facts-as-records` → the compiled network via `overlay` →
   `:wat::rete::query`), with the compiler's `CArg`/`CParam` records appended to the same vector.
   The first ruleset: **a `CArg`'s type differs from the `CParam` it feeds → a conflict**, reported
   at the call. Plus an AGREEMENT witness, counted, so a silent run cannot pass for a clean one.
4. **The runner.** `tools/rules.sh` over the corpus and `elf/probe/`, run by `tools/elf-run.sh` in
   REPORT mode: it prints every conflict and the count; it does not fail the build yet.

## READ IN ORDER

```
docs/excursus/2026/09/002-no-guesses/DESIGN.md          the pivot, the choice, the join key
docs/excursus/2026/09/002-no-guesses/rete/               the F-194 experiment -- the rule shapes that work
FINDINGS.md F-194                                        the bug this must see
wat-rs/wat/grep.wat:304-440                              facts-of, facts-as-records, run-one, run -- the pattern to copy
wat-rs/wat-scripts/grep/can-raise.wat                    idioms: a recursive rule, joins, Match
elf/lib/reader.wat                                       :rd::Node, :rd::St and where pos is known
elf/compile.wat  :c::call-user, :c::fill-fns, :c::type-of   where an argument and a parameter are typed
```

Rete notes learned the hard way: arithmetic is total — `(:wat::rete::i64::- a b :undefined v)`,
and pick `v` so an overflow cannot fake a match (`-1` against an index); a string literal's `Named`
text has no quotes; `(:wat::rete::not <one pattern>)` joins on variables bound earlier.

## STOP TRIGGERS

- **STOP-1 — you are about to derive a type inside the rules.** The rules join; the compiler types.
  A type derivation written as rules is the two-languages disease this stone exists to avoid.
- **STOP-2 — you are about to fix the enum spelling.** This stone must SEE F-194, not cure it. The
  cure is the next stone, and this checker is its gate.
- **STOP-3 — the export moves an emitted byte.** Positions and export must not change codegen.
- **STOP-4 — the compiler's positions and wat-grep's cannot be made to agree.** Report how.
- **STOP-5 — a red.** Capture it; never re-run it.

## OUT OF SCOPE, AFFIRMATIVELY

Fixing the conflicts found · the enum-type root fix · phases 2 and 3 · any change in `wat-rs`.

## METHOD

`/home/watmin/Work/holon/the-little-wat`, `main`. `timeout -s KILL` on every wat run; tree untouched
while `bootstrap.sh`/`elf-run.sh` run; every replacement asserts it matched; `cond` ends in
`(:else …)`; bootstrap without `--fast`. Every number the SCORE prints is one you measured.
**Leave the tree dirty; do not commit.** Write `SCORE-stone-1-the-compiler-agrees-with-itself.md`
beside this file, one section per EXPECTATIONS row, output pasted in.
