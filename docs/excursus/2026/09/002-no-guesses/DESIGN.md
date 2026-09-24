# Excursus 002 — no guesses: every place the compiler knows less than the language

**Status: 2026-09-24.** **Stones 1 and 2 LANDED** -- two rete gates, run by `elf-run` in report mode.
Stone 1: the compiler must agree WITH ITSELF at every call boundary (representation -- F-194). Stone 2:
the compiler's type for every node it types must agree WITH THE LANGUAGE's checker (type -- F-195).
Current reports: 8 boundary conflicts; 9 type conflicts in 17,367 jointly-typed nodes. Stone 2 also
found that `wat --check` skips function bodies spelled with namespaced symbols (F-196) -- most of this
corpus. Next: one total derivation behind the compiler's type waist, and both gates to MUST-BE-ZERO.

> Builder: *"wat should deliver perfect knowledge... i want to know every place where perfect
> knowledge isn't known... at runtime dynamic values can arrive... but they are bounded... ints are
> not strings.... vectors are not records... i don't see where we are forced to guess anything..."*

## The definition that makes this a finite search

**Every fact about a wat program is available one of two ways**: the language pins it at compile
time (every boundary is typed; there are no mutable cells; sharing is always written in the source),
or the running program holds it as a concrete value, which a runtime check reads. **A GUESS is
neither**: the compiler assuming something it neither proved nor checked. Nothing in wat forces one.
So every guess is a compiler defect, and the goal is zero.

A runtime check is NOT a guess. `cmp rax,0x1000` on a value that may be a unit tag, or the count's
`cmp [rax-8],0`, reads a fact the program holds.

## What the crawl found before the sweep (grep, so only the shapes anticipated)

- **Six type fallbacks to `"i64"`** -- `:c::lookup-ty` (`elf/compile.wat:747`), `:c::fn-ret`
  (`:1116`), `:c::ty-node` (`:1176`, `:1194`), `:c::type-of` (`:1327`, whose own comment calls the
  fallback *"load-bearing, via the INLINER"*), `:c::type-of-form` (`:1386`).
- **Nineteen "not found" sentinels** -- `:c::lookup` answers `999999`; `lookup-reg`, `enum-index`,
  `index-of-str`, `rec-index`, `field-index`, `alias-index`, `fn-addr` and others answer `-1`. An
  Option in disguise; a guess wherever a caller uses it unchecked.
- **Fourteen places identity is keyed by SPELLING** -- `Out/rax`, `:c::occ`, `linear?`.
- **No checker in the native compiler** -- it compiles programs the language rejects (F-190;
  `nth` on a record printed `7` until stone 0a).

## The method -- examinare's loop until the lair is dry

Rounds of independent hunters, each with a distinct lens, using `wat --grep` for STRUCTURE and text
grep only as a cross-check. Every reported site is weighed by the orchestrator against the disk
before it enters the ledger; a site with no `file:line` is discarded. Dedup is against everything
SEEN, not only what survived. **The sweep ends after two consecutive rounds find nothing new.**

`wat-grep` facts, as measured on this tree 2026-09-23: a namespaced keyword is `Named` with `::`
normalised (`:wat::core::cond` -> `wat.core/cond`, `:c::probe` -> `c/probe`); a single-segment
keyword keeps its colon (`:else`); **a string literal's name drops its quotes** (`"i64"` -> `i64`),
the same text a SYMBOL `i64` would give -- so a rule must join `NodeKind.StringLit` to tell them
apart, which is precisely the cut text cannot make.

## The ledger's columns

`file:line` · the guess, in one sentence · the knowledge that would replace it (the language's
type, the binding, an `Option`, a runtime check) · **polarity** -- FAIL-SAFE (a wrong guess only
declines an optimisation) or FAIL-OPEN (a wrong guess can produce a wrong answer or a crash) ·
reachable from a valid program? (yes with a probe / no with the reason / unknown).


## The pivot, 2026-09-23 — rules as the compiler's checker, then its knowledge

> Builder: *"let's get after it - rete has been the thing i have fought hardest for..... structural
> reasoning continues to prove a massive strength...."*

F-194's experiment (`rete/`) showed a boundary constraint written as rules reporting, at the exact
line, a bug the hand-written compiler shipped as a segfault. The builder's rete is the most trusted
part of wat -- and that trust lives in `wat-rs/src/rete/` (15,405 lines of Rust); the wat source is
the network compiler (~2,100 lines). So the native compiler cannot "compile rete". The order is:

1. **Phase 1 — rete CHECKS the compiler.** The compiler exports what it decided; rules join those
   decisions syntactically and report disagreements. No change to the compiler's architecture;
   self-hosting untouched; wat-rs's native rete does the work.
2. **Phase 2 — one fact, one derivation, inside the compiler** — the elaboration pass, shaped by
   what phase 1's rules proved the derivations must say.
3. **Phase 3 — the native compiler compiles rule sets** (the network as a jump DAG, plus fact
   memories), with wat-rs's rete as the ORACLE: same facts in, same facts out, on every run.

**The first slice rests on a sharp choice: the rules derive NO types.** F-194 was the compiler
DISAGREEING WITH ITSELF -- the argument typed `henum:`, the parameter `penum:`. So the compiler exports
its own answers, and the rules supply only the syntactic join (this argument feeds that parameter).
Writing a type derivation as rules would put the same logic in two languages -- the very disease.

The join key is source position, in wat-grep's convention, measured: **1-based line and column of a
node's first character; a list begins at its `(`.** The compiler's reader keeps `pos` while reading
but `:rd::Node` (`elf/lib/reader.wat`) stores only `k`/`text`/`kids`, so positions are the first
thing to add.
