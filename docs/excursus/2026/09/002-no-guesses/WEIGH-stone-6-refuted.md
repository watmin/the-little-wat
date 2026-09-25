# WEIGH — excursus 002 stone 6: REFUTED, one root below it

The orchestrator's weighing of `SCORE-stone-6-the-guard-knows-the-variant.md`, 2026-09-24, at
`653fa08` with the strike uncommitted in the tree.

## What held

The diff does what the SCORE says: one emission (`:c::count-hex`), two callers, the guard chosen
from what a value of the type can be. Branches join to the PARENT (`elf/compile.wat:1613-1616`), so
an `if`, a `cond` or a `match` never hands the guard a variant it did not earn. Re-run here:

```
penum-str-let: agree [2]          count-literal: agree          count-some-str: agree [3|2]
count-some-vec: agree [4|3]       count-none: agree [7|7]       penum-spelled-henum: agree [4|3]
keys-tier1-alias: agree [43]      tier1-borrow: agree [4|3]
variant-vec-mixed: agree [3|-1|2|-1]   variant-if-join: agree [6|-2]   variant-match-join: agree [6|-2]
```

## What did not — STOP-1 fired, and no fixture could see it

```
$ tools/probe.sh elf/probe/nested-enum-count.wat
nested-enum-count: CRASH signal=11   interp=[-2|-2|6]      (HEAD: agree)
```

A `Some` whose payload is a PARENT `Opt` -- `(:user::Opt.Some :- [(:user::Opt :- [String])])`. The
SCORE's derivation row "payload variant, tier 1: the payload itself, never a unit tag" is false
here. The payload is an enum, and an enum can be its unit tag. The tag test was dropped, and
`cmp [rax-8],0` ran on the inner `None`'s tag.

It is not stone 6's defect alone. It is **F-200**, already a silent wrong answer at HEAD:
`:c::enum-tier` (`:964`) gives tier 1 to any pointer payload, including an enum, so `Some(None)`
and `None` are one word (`elf/probe/nested-enum-collide.wat`: native `0|0`, interpreter `1|0`).
Stone 6 relied on tier 1 meaning "never a tag", which the tiering did not ensure.

## The re-strike

1. **The root first**, in `:c::enum-tier`: tier 1 only when the payload is a pointer that is never
   a unit tag -- `(and (:c::ptr-ty? p) (not (:c::maybe-unit? p)))`. Proven on a scratch copy of
   this tree: every probe above agrees, and so do both F-200 probes. Then update the prose above
   `:c::enum-tier` and the comment on `:c::enum-ty-named` if either states the old rule.
2. **Stone 6's derivation gains the row it was missing**: a tier-1 payload is `str`, `vec:` or
   `rec:` and nothing else, with the `file:line` that now makes it so. `:c::maybe-literal?`'s
   recursion into a `penum:` payload then cannot be reached from a tier-1 enum. If it can, say why.
3. **Every row of EXPECTATIONS again**, IN FULL, plus `nested-enum-collide`, `nested-enum-count`
   and the three `variant-*` probes. The tier change can move corpus bytes and gate spellings of
   its own: `tools/emitted.sh` must explain every moved program by EITHER a lost guard OR a
   changed tier, and name which. Cost again against the stone-5b fixpoint, instructions and
   cycles, with the 1.8% floor.

**STOP-5 — a corpus program's enum changes tier and its answer changes.** Capture it.

Write the result as `SCORE-stone-6-the-guard-knows-the-variant.md` again, replacing the struck one,
with a section saying what this weighing found and what the re-strike changed.

---

# The second weighing: CREDITED

Grok's re-strike, weighed at `653fa08` with the strike uncommitted. Every row below is the
orchestrator's own run.

| row | re-run here | result |
|---|---|---|
| 1-3, 6 | `tools/probe.sh` on all 26 probes: 0b's, F-188's doors, stone 6's three, this weighing's five, `elf/src/borrowed.wat` | all agree |
| 2 mutant | on a copy of THIS tree, `:c::maybe-literal?` answering false for every `penum:` | signal 11 on `count-some-str`, `count-literal`, `penum-str-let`; `count-some-vec` agrees |
| 4 | full `tools/elf-run.sh` | exit 0; `rules: 0` in 11,439 pairs; `types: 0` in 19,124 nodes, `refined 0` -- Grok's numbers exactly |
| 7 | `tools/reads.sh` | `reads: ok` |
| 8 | `tools/emitted.sh check` | 12 of 84 moved |
| 9 | `tools/bootstrap.sh`, no `--fast` | byte-identical fixpoint, 276,703 bytes |
| 10 | HEAD bootstrapped to its OWN fixpoint in a scratch copy (290,741 bytes); both compilers run from one scratch copy of this tree, interleaved, `taskset -c 0`, `cpu_core/{instructions,cycles}/u`, 9 reps, 2 rounds, every exit checked | instructions **-5.558%** both rounds (2,734,711,163 -> 2,582,708,076); cycles **-1.73%** and **-2.49%** |

**Cost, honestly.** The instruction drop is exact and repeatable. The cycle drop straddles the 1.8%
layout floor in my rounds as in Grok's (one each side), so no cycle claim is made.

**Two more adversarial rounds, both dry for stone 6** (examinare's K=2): a record payload
(`variant-rec-payload`), a `Some` of a Vector held in a Vector (`variant-vec-payload-held`), a heap
enum inside `Opt` (`nested-henum-in-opt`), and F-200 behind a typealias (`nested-enum-alias` --
HEAD native `0|0`, interpreter `9|9`; agrees now). The rounds found one thing that is not stone 6's:
**F-201**, a valid program refused at HEAD and here alike.

**One imprecision in the SCORE**, corrected here: "the guard-only compiler and this one emitted 87
identical binaries, compiler included" cannot hold for the compiler -- its source changed, and its
size went 276,620 -> 276,703. The claim holds for the 86 corpus programs, which is what STOP-5 asks.
