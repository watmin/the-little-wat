# SCORE — excursus 003 stone 3: the `fn` form compiles

Nothing is committed. The tree is dirty.

A `fn` is rewritten before `fill-fns`. The body becomes a lifted `defn`, marked `:lifted` on its `:c::Fn`, and the site becomes a `:c::close` node whose arguments are the candidate names: every symbol in the body except the `fn`'s parameters and a top-level function. Lifted functions are appended after the parent, then the ones nested in them. `:c::argreg-mark` gives a lifted row `nargs` 0 and does not call `:c::argreg-fn?`, so no pre-pass types the body. The site is compiled in the parent, where `:c::type-of` of each name the environment binds is the capture's type. Those rows ride on `:c::PassR`, beside `fnames`. The lifted body is compiled later in the same pass and reads them back.

The object is `[count 1][code][cap…]`, allocated with the record routine (`vec_new`). The pointer is the code word. Each capture is stored with `:c::share`. In the lifted prologue, `rax` (the closure) is saved to a frame slot, and each capture is bound once: a `:c::Read.Cap` load through `:c::read-out`, then a frame slot. A use of the name is that slot. Captures are not parameters. `tools/reads.sh` is `reads: ok` (lines 4074–4102). The `:Cap` load is `:c::load-at` inside `:c::read-out`, so the tool needed no new class.

## The fixtures

| program | result |
|---|---|
| `probes/closure-captures.wat`, and the corpus copy | agree, `126` then `86` |
| `probes/closure-nested.wat`, and the corpus copy | agree, `16` then `27` |
| `elf/src/fn-vec.wat` | agree, `2` `3` `2`. The vector is captured and `conj`'d; the original length stays 2 |
| `elf/src/fn-rec.wat` | agree, `42`. The record parameter is used only as a field inside the `fn` |
| `elf/src/fn-capfn.wat` | agree, `23`. It captures a closure and calls `user/inc`, which is not a capture |
| `elf/src/fn-loop.wat` | agree, `6`. Each trip builds a closure over that trip's values |
| `elf/src/fn-nocap.wat` | agree, `42` |

`tools/elf-run.sh` compared the same seven and they agreed there too, before the gates below failed.

## What moved

`tools/emitted.sh check` against the manifest from before this bootstrap: 89 byte-identical, 7 new (`closure-captures`, `closure-nested`, `fn-vec`, `fn-rec`, `fn-capfn`, `fn-loop`, `fn-nocap`). No existing program moved.

## The share

A capture is a bare symbol argument of the closure node, so the linearity count already refuses the owned in-place `conj` on that name. The share at the store is the other wall: a capture is a store into a container, and the count has to be complete whether or not `own?` would have copied. No fixture can drop only that share and still take the owned path. The share stays.

## The gate

`tools/elf-run.sh` in full, not re-run. Differentials agreed. The gates did not:

```
rules: TOTAL over 139 programs  CArg 12105  CParam 2931  pairs 12105  agree 12032  variant 73  CONFLICT 0  unplaced 10  unjoined 0  mismatch 0
types: TOTAL over 139 programs  CType 20754  KType 34297  KUnres 0  joined 20459  agree 20428  refined 0  TYPE-CONFLICT 31  partial 0  untranslatable 0  unresolved 0  checker-multi 31  compiler-multi 6  compiler-only 295  checker-only 13838
rules: FAIL -- unplaced 10 (must be 0)
types: FAIL -- TYPE-CONFLICT 31 (must be 0)
elf-run: FAILED
```

`partial` is 0. `CONFLICT` is 0. The 31 type conflicts and the 10 unplaced parameters are the seven new programs. A conflict line looks like:

```
type-conflict  elf/src/closure-captures.wat:7:82  in=  compiler=i64 :wat::core::i64  checker=:wat::core::i64  raw=fn0
```

The wat spellings match. The compiler said the type at a column of the `fn` form, with an empty `in`, and `raw=fn0`. The unplaced rows are `CParam`s of the lifted functions, which are not `defn`s in the source. The close node reuses the `fn` form's origin so the export can name that form, and the lifted `defn` exports its parameters at those same columns.

## Self-host

`tools/bootstrap.sh`, no `--fast`. `WAT` was `/home/watmin/.cache/wat-kw-007/release/wat`.

```
99 binaries in 634453 ms, the compiler among them (295560 bytes)
the same work in 950 ms
98 binaries, all byte-identical
stage1 == stage2, byte for byte (295560 bytes)
bootstrap: ok
```

The fixpoint before these edits, saved aside, is 283,863 bytes. This fixpoint is 295,560.

## Cost

Both binaries, `taskset -c 0`, `cpu_core` instructions and cycles, 9 repetitions, two rounds. `best_cyc` is the cycles of the minimum-instruction repetition. Each binary runs its own `main`, so this one also compiles the seven new programs.

```
round 1
prev    best_ins=2785661897  best_cyc=1467720404
stone3  best_ins=2878011522  best_cyc=1520458074
round 2
prev    best_ins=2785661860  best_cyc=1511338117
stone3  best_ins=2878011470  best_cyc=1514277761
```

| | instructions | cycles, same run |
|---|---|---|
| round 1 | +9,234,625 (+3.315%) | +52,737,670 (+3.593%) |
| round 2 | +9,234,610 (+3.315%) | +2,939,644 (+0.195%) |

The instruction rise agrees across rounds. The cycle deltas do not, and round 1 is past the 1.8% floor. No cycle claim.

## Re-strike

`fn0` was the lifted function's name. The name was `" fn0"`, and the leading space split the `CType` line: `in` came out empty and the name landed in `raw`, with the wat spelling glued onto the compiler's own type. The name is now `:c::fn` and a decimal, with no space. A made node whose position is `? 0 0` — it stands for no source node — is not exported. The `:c::close` site is the `fn` form and is exported as the function type. The lifted body's nodes are the `fn` body's own nodes.

`:ck::b-param-fn` places a `CParam` on parameter `i` of a `wat.core/fn` the way `:ck::b-param` places one on a `defn`. The parameter vector is child 1. Parameter `i` is still index `3i`.

`tools/elf-run.sh` in full, after that:

```
rules: TOTAL over 139 programs  CArg 12047  CParam 2913  pairs 12047  agree 11974  variant 73  CONFLICT 0  unplaced 0  unjoined 0  mismatch 0
types: TOTAL over 139 programs  CType 20645  KType 34133  KUnres 0  joined 20372  agree 20372  refined 0  TYPE-CONFLICT 0  partial 0  untranslatable 0  unresolved 0  checker-multi 31  compiler-multi 0  compiler-only 273  checker-only 13761
elf-run: ok -- 99 native binaries. 50 agree with the interpreter
rules: 0 conflicts in 12047 argument-parameter pairs
types: 0 type conflicts in 20372 nodes both typed
```

A fresh `tools/bootstrap.sh`, no `--fast`:

```
99 binaries in 622035 ms, the compiler among them (294005 bytes)
the same work in 962 ms
98 binaries, all byte-identical
stage1 == stage2, byte for byte (294005 bytes)
bootstrap: ok
```

This fixpoint is 294,005 bytes.

The cost is both compilers on the previous corpus list. The new compiler was rebuilt from a scratch copy of its source whose `main` does not name the seven new programs; the previous compiler is the 283,863-byte fixpoint, whose `main` is that same list. `taskset -c 0`, `cpu_core`, 9 repetitions, two rounds.

```
round 1
prev  best_ins=2769959866  best_cyc=1475194839
same  best_ins=2838307906  best_cyc=1499919771
round 2
prev  best_ins=2769959765  best_cyc=1463255432
same  best_ins=2838307744  best_cyc=1493217515
```

| | instructions | cycles, same run |
|---|---|---|
| round 1 | +6,834,804 (+2.467%) | +24,724,932 (+1.676%) |
| round 2 | +6,834,979 (+2.467%) | +29,962,083 (+2.048%) |

The instruction rise agrees. Round 2's cycles are past the 1.8% floor. No cycle claim.
