# SCORE — excursus 002 stone 6, re-struck after the refute

The first strike is withdrawn. The weighing in `WEIGH-stone-6-refuted.md` is right, and this
file replaces that score. Nothing is committed. wat-rs was not touched. Every number below was
measured in this session.

## What the weighing found

`nested-enum-count.wat` crashed (signal 11) under the first strike and agrees on the interpreter
(`-2|-2|6`). A `Some` whose payload is a parent `Opt` was tier 1, so the value WAS the inner
`Opt`, and the inner `None` is a unit tag. The derivation row "a payload variant is never a unit
tag" dropped the tag test, and `cmp [rax-8],0` ran on that tag.

That row was false because the tiering was false. `:c::enum-tier` gave tier 1 to any pointer
payload, and `penum:` / `henum:` are pointer types. `nested-enum-collide.wat` is the same fact
as a silent wrong answer, already at the stone-5b tree: native `0|0`, interpreter `1|0`. F-200.

## What the re-strike changed

Tier 1 only when the payload is a pointer that is never a unit tag:

```
(:wat::core::and (:c::ptr-ty? p) (:wat::core::not (:c::maybe-unit? p)))
```

in `:c::enum-tier`. `str`, `vec:` and `rec:` still qualify. An enum payload does not, so
`Opt<Opt<String>>` is tier 3: `Some` is a heap block, `None` is the tag, and they are not one
word. The prose above `:c::enum-tier` and the comment on `:c::enum-ty-named` now say so.

`:c::maybe-literal?` still recurses on a `penum:` payload. That call cannot receive another
`penum:`. A tier-1 enum's sole payload is `str`, `vec:` or `rec:` — the predicate just added —
so the recursive call returns in those arms. A payload that is itself an enum is tier 3 and
spelled `henum:`, which `:c::maybe-literal?` answers false without recursing.

**Verdict.** The ten expectation rows hold, and so do `nested-enum-count`, `nested-enum-collide`,
and the three `variant-*` probes. STOP-5 did not fire: against the guard-only compiler, 87 of 87
binaries are identical, so no corpus enum changed tier.

## Row 1 ⛔ — F-194 stays fixed — **MET**

```
$ tools/probe.sh elf/probe/penum-str-let.wat
penum-str-let: agree   [2]
```

## Row 2 ⛔ — the literal guard is right — **MET**

```
count-literal: agree   [4|3|"cde"|4|3|0|-1|2|0|7|2]
count-bare: agree      [1|0|1|0|"t"|3]
count-trie: agree      [40|4|3|1|0|41|40|1|5|4]
penum-spelled-henum: agree   [4|3]
```

The payload-blind mutant (a `penum:` is never a literal) was run on the first strike and
segfaulted, signal 11, on `count-some-str`, `count-literal` and `penum-str-let`. It was reverted
before that bootstrap and was not reintroduced. The tier fix does not drop a String payload's
literal guard: `Opt<String>` is still tier 1.

## Row 3 ⛔ — F-188 stays closed — **MET**

```
callrel-borrow: agree   [30|240000|3|1|30]
field-borrow: agree   [5|5|4]
str-borrow: agree   [4|"ab1"|3]
tier1-borrow: agree   [4|3]
keys-borrow: agree   [4|3]
check-param-shadow: agree   [4]
field-shadow: agree   [5|4]
match-shadow: agree   [5|4]
own-shadow: agree   [30|3|30]
share-shadow: agree   ["z2z1!z2!"]
str-shadow: agree   [4|"ab1"|3]
keys-tier1-alias: agree   [43]
borrowed: agree   [4|3|4|3|4|"ab1"|4|"ab1"|5|4|5|4|5|4]
```

## Row 4 ⛔ — both gates at zero — **MET**

A full `tools/elf-run.sh`, no `SKIP_BUILD`. Exit 0.

```
elf-run: ok -- 87 native binaries. 38 agree with the interpreter;
         3 more use syscalls it has no implementation of (F-119); 5 refusals and
         4 traps, both ways. rules: 0 conflicts in 11439 argument-parameter pairs (11392 equal, 47 a variant to its enum) over 114 programs.
         types: 0 type conflicts in 19124 nodes both typed (19124 agree, 0 refined) over 114 programs.
```

No corpus answer changed. STOP-5 did not fire.

## Row 5 — the derivation — **MET**

Count 0 is only a literal (`:c::static-str`, `elf/compile.wat:2030-2034`, called from
`:c::str-lit` `:2038`). Every allocator writes a count of at least 1 (`elf/lib/runtime.wat:673`
for a Vector, `:162` `:1001` `:1113` `:1377` `:1482` for strings, `:845` `:874` `:939` for a
tree). A unit tag is below `:c::unit-threshold` (4096).

| type | what a value can be | evidence | guard |
|---|---|---|---|
| `str` | a read-only literal, or a heap string | `compile.wat:2030-2034` | **literal** |
| `vec:` | only a heap block | `:c::vec-form` `:4047`, `runtime.wat:673` | **bare** `incq` |
| `rec:` | only a heap block | `:c::rec-form` → `vec_new` | **bare** |
| parent `henum:` | a heap block, or a unit tag | `:c::variant-form`; tier `:c::enum-tier` | **tag**, then bare `incq` |
| parent `penum:` | its payload, or a unit tag | tier-1 arm is the field expression | **tag**, then the payload's guard |
| payload variant, tier 1 | the payload itself: `str`, `vec:` or `rec:` only, never a unit tag | `:c::enum-tier` now requires `(and (ptr-ty? p) (not (maybe-unit? p)))` | the payload's guard, **no tag** |
| payload variant, tier 3 | the heap block. This includes a payload that is itself an enum (F-200) | same predicate, else-arm is tier 3 | **bare** |
| unit variant | the tag, never a pointer | `:c::unit-variant?` | **nothing** |

An unresolved `penum:` keeps the literal guard.

## Row 6 — the new fixtures — **MET**

```
count-some-vec: agree   [4|3]
count-some-str: agree   [3|2]
count-none: agree       [7|7]
```

And the probes the weighing added:

```
nested-enum-count: agree    [-2|-2|6]
nested-enum-collide: agree  [1|0]
variant-vec-mixed: agree    [3|-1|2|-1]
variant-if-join: agree      [6|-2]
variant-match-join: agree   [6|-2]
```

`1|0` is `Some(None)` distinguished from `None`. `-2|-2|6` is the inner `None` counted without
faulting, twice, and the inner `Some` of `"xy"` still a string.

## Row 7 — every counted read still counted — **MET**

```
$ tools/reads.sh
reads: ok -- every read out of a container goes through :c::read-out (lines 3894-3921)
```

## Row 8 — emission — **MET**

```
$ tools/emitted.sh check
   MOVED: elf/out/assocn.elf
   ... twelve programs ...
emitted: 12 of 84 programs changed, 0 new
```

The twelve are the same twelve the guard strike moved, and no others. Against the stone-5b
compiler's emission, each size delta equals the guard-byte delta. Tuple
`(tag+literal, tag+bare, literal, bare)`, weights 19 / 12 / 11 / 4:

```
assocn      (0,0,2,0) -> (0,0,0,2)    -14
borrowed    (1,0,17,0) -> (0,0,4,14)  -106
deepvec     (0,0,2,0) -> (0,0,0,2)    -14
linear      (0,0,2,0) -> (0,0,0,2)    -14
matchval    (0,0,2,0) -> (0,0,1,1)    -7
moved       (0,0,14,0) -> (0,0,0,14)  -98
pass20000   (0,0,9,0) -> (0,0,0,9)    -63
pass80000   (0,0,9,0) -> (0,0,0,9)    -63
pvec        (0,0,9,0) -> (0,0,4,5)    -35
reader      (0,0,80,0) -> (0,0,36,44) -308
strown      (0,0,18,0) -> (0,0,11,7)  -49
vectors     (0,0,7,0) -> (0,0,3,4)    -28
```

Every one of those is a lost guard (a literal guard, or in `borrowed.elf` one tag+literal,
becoming a bare `incq`). The tier fix moved nothing further: the guard-only compiler and this
one emitted 87 identical binaries, compiler included. No moved program is a changed tier.

## Row 9 — self-hosts — **MET**

```
   87 binaries in 635422 ms, the compiler among them (276703 bytes)
   86 binaries, all byte-identical
   stage1 == stage2, byte for byte (276703 bytes)
bootstrap: ok
```

Stone 5b was 290,741 bytes. The guard strike was 276,620. This fixpoint is 276,703.

## Row 10 — cost — **MET**

Both compilers at their own fixpoints: stone 5b is 290,741 bytes, this one is 276,703. Same
tree. Copies, `taskset -c 0`, `cpu_core` instructions and cycles, 9 repetitions, two rounds.

```
round 1
head    best_ins=2734711537  best_cyc=1407511227
stone6  best_ins=2582708264  best_cyc=1364791565
round 2
head    best_ins=2734711415  best_cyc=1384981362
stone6  best_ins=2582707948  best_cyc=1365842483
```

| | instructions | cycles |
|---|---|---|
| round 1 | −152,003,273 (−5.558%) | −42,719,662 (−3.035%) |
| round 2 | −152,003,467 (−5.558%) | −19,138,879 (−1.382%) |

Instructions are the same drop twice. That is 68.2% of the 8.152-point gap stone 0b measured,
and 52.2% of F-189's 10.64-point gap. Both are more than half. The pre-count compiler was not
rebuilt on this input; those are the two published gaps.

Cycles clear the 1.8% floor in round 1 and do not in round 2 (1.382%). The cycle drop is inside
the layout floor on one of the two rounds, so it is not a stable attribution. The instruction
drop is.
