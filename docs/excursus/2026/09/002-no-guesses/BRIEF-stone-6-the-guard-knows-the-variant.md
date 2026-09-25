# BRIEF — excursus 002 stone 6: the count guard knows what the value can be — to the variant

> Stone 5 taught the compiler variant types. This stone spends that knowledge where the machine code
> still asks a question the type can now answer.

## YOU ARE NEW TO THIS — read the history first

`the-little-wat` is a self-hosting compiler for wat, written in wat, emitting x86-64. Read, in order:

1. `docs/excursus/2026/09/002-no-guesses/DESIGN.md` — no guesses; the two rete gates at zero
2. `docs/excursus/2026/09/001-reclamation-beyond-scope/SCORE-stone-0b-a-guard-for-what-the-type-can-be.md`
   — **the reference implementation of this stone**, struck and landed on 2026-09-23 and then
   REVERTED. Its derivation table, its fixtures, and the orchestrator's mutation test are all there.
3. `FINDINGS.md` — `### F-194` (why 0b was reverted), `### F-188`, `### F-189`, `### F-193`
4. `docs/excursus/2026/09/002-no-guesses/SCORE-stone-5-variant-types.md` — the variant types you use

## WHY IT WAS REVERTED, AND WHY IT IS SAFE NOW

Stone 0b derived each count guard from the TYPE STRING: a String can be a read-only literal (count 0),
so it keeps `cmp [rax-8],0 ; je`; an enum can be a small-integer unit tag, so it keeps
`cmp rax,0x1000 ; jb`; a Vector or record is always a heap block, so it gets a bare `incq [rax-8]`. It
was right per tier — but a `let`-bound tier-1 enum built from a String literal was spelled `henum:`
(F-194), got no literal guard, and the `incq` wrote a read-only page. **`elf/probe/penum-str-let.wat`
segfaulted.** Stone 4 fixed the root: one derivation, one spelling per value, both rete gates at zero.

## WHAT VARIANT TYPES ADD

Where the guard used to ask "which variant is this?" at runtime, the type now says:
- a value typed as a **payload variant** (`(:user::Opt.Some :- [T])`) is never a unit tag — no
  `cmp rax,0x1000 ; jb`. Its literal guard follows its PAYLOAD (a tier-1 variant IS its payload, so a
  `Some` of String can be a literal; a `Some` of a Vector cannot).
- a value typed as a **unit variant** (`(:user::Opt.None :- [T])`) is not a pointer — no count at all.
- the PARENT enum keeps what it can be: either variant.

**The derivation is yours**, per type, from what its values can actually BE, each row backed by the
`file:line` that establishes it — as 0b's SCORE did. `:c::count-hex` (`elf/compile.wat:3741`) is the
one emission; `:c::share` (`:3719`) and `:c::read-out` (`:3816`) are its two callers; `:c::maybe-unit?`
(`:3852`), `:c::ptr-ty?` (`:3705`) and `:c::enum-tier` (`:964`) are what it has to reason with.

## THE FIXTURES — all on disk

- `elf/probe/penum-str-let.wat` — **F-194's segfault. It must AGREE (`2`).** The sharpest test there is.
- `elf/probe/penum-spelled-henum.wat`, `count-literal.wat`, `count-bare.wat`, `count-trie.wat` — 0b's.
- every `elf/probe/*-borrow.wat`, `*-shadow.wat`, `keys-*.wat`, `elf/src/borrowed.wat` — F-188's doors.
- **new, yours to write**: a `Some` of a Vector (bare `incq`), a `Some` of a String literal (literal
  guard kept), a `None`-typed value (no count) — each checked on the interpreter first.

## STOP TRIGGERS

- **STOP-1 — a guard dropped for a type whose values CAN be a literal or a unit tag.** That is F-194
  again. Every dropped guard is justified by a row of the derivation.
- **STOP-2 — `penum-str-let.wat` or any F-188 probe does not agree.** Capture it; do not patch around it.
- **STOP-3 — the recovery is under half.** Instructions for the compiler compiling the corpus, against
  HEAD: 0b recovered 71% of stone 0's instruction cost. If this recovers less than half of it, report.
  Report CYCLES beside instructions, and say whether each difference clears this workload's measured
  layout floor of **1.8%** (F-192) — a smaller cross-build cycle difference is not attributable.
- **STOP-4 — a gate above zero, or a red.** Capture it; never re-run it to make it pass.

## OUT OF SCOPE

Eliding `match`'s tag tests (a `match` only ever sees a parent — wat's checker refuses one on a
variant) · closures · anything in `../wat-rs`.

## METHOD

`timeout -s KILL` on every wat run; leave the tree alone while `tools/bootstrap.sh`/`tools/elf-run.sh`
runs; assert every text replacement matched exactly once; `cond` ends in `(:else …)`, no `_`, no
catch-all; bootstrap without `--fast`; run `tools/elf-run.sh` IN FULL (not `SKIP_BUILD`). Build each
comparison compiler to its own fixpoint and say so. Every number the SCORE prints is one you measured.
**Leave the tree dirty; commit nothing.** Write `SCORE-stone-6-the-guard-knows-the-variant.md` here.
