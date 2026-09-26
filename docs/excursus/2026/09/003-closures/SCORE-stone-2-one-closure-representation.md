# SCORE — excursus 003 stone 2: every function value is a closure object

Nothing is committed. The tree is dirty.

A function value is one static object, `[count 0][code]`, the pointer at the code word. `:c::fn-val` interns it: one tail entry per function whose address is taken, sixteen bytes in both passes. An indirect call is `call [rax]` (`ff 10`). `rax` holds the closure. A top-level prologue does not read that `rax` before it overwrites it (`push rbp` only when the function clones, then `sub rsp`, register saves, parameter loads, scalar loads). STOP-1 did not fire.

`fn:` is a pointer type (`:c::ptr-ty?`) and not a word type. `:c::maybe-literal?` is true for it, so the count guard is the literal guard. `tools/reads.sh` is `reads: ok`. `call [rax]` is not a heap-load spelling that tool watches, and it answers no value a program sees, so the tool needed no new class.

## The fixtures

| program | result |
|---|---|
| `elf/src/fnref.wat`, `fnvec.wat`, `elf/src/four.wat` | agree, same answers as before |
| every `elf/probe/fnty-*.wat` | the same agree or the same refusal. The refusal texts match; the frame line numbers moved with `compile.wat` |
| `elf/src/fn-ret.wat` | agree, `42` |
| `elf/src/fn-vecpass.wat` | agree, `42` |
| `elf/src/fn-twice.wat` | agree, `21` then `22`. Tail data is 16 bytes: two sites, one object |
| `elf/src/fn-share.wat` | agree, `43`. The same function stored twice. Tail data is 16 bytes. The count stays 0; the run does not fault |
| `elf/src/fn-box.wat` | agree, `42` |

A pure record cannot hold a function. The interpreter refuses it: a pure aggregate may only hold pure fields, and `[i64 :-> i64]` is an impure struct. The fixture that both sides run is an `:wat::enum::Impure` enum, `:user::Hold.One`, with the function in `op`.

`fnref`'s tail data is 32 bytes: `user/add` and `user/mul`, one object each.

## What moved

`tools/emitted.sh check` against the manifest that was already in `elf/out`: 2 of 84 programs changed, 0 new. `elf/out/fnref.elf` (924 → 967) and `elf/out/fnvec.elf` (2849 → 2914). No other corpus program moved.

The growth is the sixteen tail bytes per address-taken function, the `ff d0` → `ff 10` at each indirect call, and the twelve-byte literal guard (`488378f800740448ff40f8`) everywhere a `fn:` value is shared or read out of a Vector. Those inserted bytes move the relative displacements after them. That is R1, R2, and the literal guard R3/R4 require. STOP-2 did not fire.

## The gate

An indirect call exports `IArg <file> <line> <col> <index> <cur> <type>`, the type the argument has. While the facts load, a head whose raw type starts with `fn:` is split into `:ck::FnArg` slots. The rule `:ck::z-indirect` only joins: argument `i` must be a `:ck::TyFits` of slot `i`. It counts as `CONFLICT`.

The first full `tools/elf-run.sh` exited 1. Differentials for the programs already in `COMPARED` agreed, and the rules and types totals were zero. The coverage guard named the five new sources:

```
UNCOVERED: elf/src/fn-box.wat
UNCOVERED: elf/src/fn-ret.wat
UNCOVERED: elf/src/fn-share.wat
UNCOVERED: elf/src/fn-twice.wat
UNCOVERED: elf/src/fn-vecpass.wat
rules: TOTAL over 127 programs  CArg 11692  CParam 2815  pairs 11692  agree 11627  variant 65  CONFLICT 0  unplaced 0  unjoined 0  mismatch 0
types: TOTAL over 127 programs  CType 19940  KType 32955  KUnres 0  joined 19653  agree 19653  refined 0  TYPE-CONFLICT 0  partial 0  untranslatable 0  unresolved 0  checker-multi 30  compiler-multi 4  compiler-only 287  checker-only 13302
```

Listing them in `COMPARED` and running again still exited 1. The interpreter printed `42`, `42`, `43`, `21`/`22`, and `42`. The native side was `No such file or directory` for each `elf/out/fn-*.elf`. `:user::main` never compiled those paths. They are now five `:c::compile` calls beside `fnref` and `fnvec`, and the five names are in `COMPARED`.

The full run after that, `WAT=/home/watmin/.cache/wat-kw-007/release/wat`, exited 0:

```
fn-box   agree (exit 0, 3330 bytes native)  42
fn-ret   agree (exit 0,  656 bytes native)  42
fn-share agree (exit 0, 2858 bytes native)  43
fn-twice agree (exit 0,  716 bytes native)  21 22
fn-vecpass agree (exit 0, 2764 bytes native)  42
rules: TOTAL over 132 programs  CArg 11702  CParam 2820  pairs 11702  agree 11637  variant 65  CONFLICT 0  unplaced 0  unjoined 0  mismatch 0
types: TOTAL over 132 programs  CType 19996  KType 33049  KUnres 0  joined 19709  agree 19709  refined 0  TYPE-CONFLICT 0  partial 0  untranslatable 0  unresolved 0  checker-multi 30  compiler-multi 4  compiler-only 287  checker-only 13340
elf-run: ok -- 92 native binaries. 43 agree with the interpreter
```

With `:c::check-fn-args` removed and `:c::export-iargs` left, `elf/probe/fnty-indirect-arg-wrong-refused.wat` compiles. The gate says:

```
indirect-arg-conflict  .../fnty-indirect-arg-wrong-refused.wat:2:103  in=user/apply  arg=0  arg-type=i64  param-type=str
rules: TOTAL over 1 programs  ... CONFLICT 1
```

That mutant was reverted. `:c::check-fn-args` is back.

## Self-host

`tools/bootstrap.sh`, no `--fast`. `WAT` was `/home/watmin/.cache/wat-kw-007/release/wat`.

```
87 binaries in 680775 ms, the compiler among them (283268 bytes)
the same work in 935 ms
86 binaries, all byte-identical
stage1 == stage2, byte for byte (283268 bytes)
bootstrap: ok
```

The compiler in `elf/out` before this bootstrap was 281,728 bytes. That fixpoint is 283,268.

Adding the five `:c::compile` calls changes `elf/compile.wat`, so that binary is no longer the fixpoint of the source. A second `tools/bootstrap.sh`, no `--fast`, same `WAT`:

```
92 binaries in 592614 ms, the compiler among them (283863 bytes)
the same work in 953 ms
91 binaries, all byte-identical
stage1 == stage2, byte for byte (283863 bytes)
bootstrap: ok
```

The fixpoint of this source is 283,863 bytes. The cost figures below are the 283,268 compiler, measured before these five calls were added to `:user::main`.

## Cost

Both binaries, `taskset -c 0`, `cpu_core` instructions and cycles, 9 repetitions, two rounds. `best_cyc` is the cycles of the minimum-instruction repetition.

```
round 1
prev    best_ins=2645436614  best_cyc=1398499284
stone2  best_ins=2639633698  best_cyc=1399107663
round 2
prev    best_ins=2645436568  best_cyc=1421577837
stone2  best_ins=2639633701  best_cyc=1394319452
```

| | instructions | cycles, same run |
|---|---|---|
| round 1 | −5,802,916 (−0.219%) | +608,379 (+0.044%) |
| round 2 | −5,802,867 (−0.219%) | −27,258,385 (−1.92%) |

The instruction drop agrees across rounds. Round 2's cycle delta is the previous compiler's minimum-instruction run, and that run's cycles sit above its other eight (those are about 1.393e9 to 1.404e9). It is past the 1.8% floor as a paired number. No cycle claim.
