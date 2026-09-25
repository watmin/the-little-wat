# SCORE — excursus 003 stone 1: a function type is its whole type

Nothing is committed. wat-rs was not touched. Every number below was measured in this session.
The amendment in `AMEND-stone-1-rete-is-for-rules.md` is in: the gate decides in plain wat
and the rules only join. No `:wat::rete::core::defn` remains in `tools/rules/check.wat`.

## The spelling

`[A B :-> R]` is `fn:` then, for each argument and finally the return, the decimal length, `:`,
and that many bytes. `[i64 str :-> i64]` is `fn:3:i643:str3:i64`. Built by `:c::fn-ty-of`
(`elf/compile.wat:1426`). A length is how it nests. An argument carries its own `:` and its
own `;` (`penum::user::Opt;str`, a `vec:`, another `fn:`), and the reader of a function type
takes the counted bytes instead of stopping at the first of either. `:c::semi-from` is unchanged:
on an enum it still stops at that enum's own `;`, and the argument is the rest of the string, so
a function type used as an enum argument keeps the `;` inside it. `:c::word-ty?` still knows
`fn:` by prefix. A function value is still a code address, not a pointer.

## The one rule

`:c::assignable?` (`elf/compile.wat:1052`) is the only place the compiler states it.

- a type is assignable to itself
- both function types, equal arity: each argument of `to` is assignable to the argument of
  `from` (contravariant), and the return of `from` is assignable to the return of `to`
  (covariant), by this same rule
- otherwise today's enum rule: a variant `E.V` is assignable to its enum `E` at the same
  instantiation, and a free `?` takes the instantiation it is given
- nothing else. A Vector stays invariant, because nothing here looks inside one

`:c::fn-assignable?` (`:1505`) is that function-type clause and nothing more. `:ck::fits?`
(`tools/rules/check.wat:579`) states the same three clauses over the exported strings. While a
program's export is loaded, `:ck::with-fits` (`:603`) records each pair that fits as a
`:ck::TyFits` fact. `:ck::a-fits` (`:151`) joins the argument, the parameter it feeds, and that
fact. It does not parse a type.

An indirect call checks each argument with the same `:c::fit` a direct call uses
(`:c::check-fn-args`, `:1937`). It does not print a `CArg`. A `CArg` is joined to a `defn`
parameter by the call's source position, and an indirect call has none, so the line would be
`arg-unjoined`. The function-type pairs the gate sees are the direct call that passes the
function, whose `CArg` and `CParam` were already exported.

## Row 1 ⛔ — the segfault is refused — **MET**

```
fnty-arg-wrong-refused: COMPILE-FAILED
compile: cannot pass parameter f of the inlined call: it wants [:wat::core::i64 :-> :wat::core::i64]
and is given [:wat::core::String :-> :wat::core::i64] at elf/src/probe.wat 6 65: (user/apply user/len)
```

The call is inlined, so the check lands on the binding the inliner made. The message names the
argument and both function types.

## Row 2 ⛔ — the narrowed argument is refused — **MET**

```
fnty-arg-narrow-refused: COMPILE-FAILED
compile: cannot pass parameter f of the inlined call: it wants [(:user::Opt :- [:wat::core::i64]) :-> :wat::core::i64]
and is given [(:user::Opt.Some :- [:wat::core::i64]) :-> :wat::core::i64]
```

`Opt` is not assignable to `Opt.Some`, so a function that accepts only `Some` is not assignable
where one that must accept any `Opt` is wanted.

## Row 3 — the language's variance is accepted — **MET**

```
fnty-arg-widen: agree   [1]
fnty-ret-narrow: agree   [4]
```

A function that accepts an `Opt` may go where one that accepts a `Some` is wanted. A function
that returns a `Some` may go where one that returns an `Opt` is wanted.

`fnref` agrees `[13|42|13]` and `fnvec` agrees `[42]`. A function type as an enum's type
argument, `elf/probe/fnty-in-enum.wat`, agrees `[3]`: `Box` of `[i64 :-> i64]`, the inner `;`
of the function type left inside the enum argument.

## Row 4 ⛔ — no corpus byte moves — **MET**

```
$ tools/emitted.sh check
emitted: ok -- all 84 programs byte-identical to the manifest
```

Checked again after the cost runs. The compiler itself is excluded there, as it always is.
STOP-1 did not fire.

## Row 5 ⛔ — function types are compared — **MET**

A full `tools/elf-run.sh`, no `SKIP_BUILD`. Exit 0.

```
elf-run: ok -- 87 native binaries. 38 agree with the interpreter;
         3 more use syscalls it has no implementation of (F-119); 5 refusals and
         4 traps, both ways. rules: 0 conflicts in 11553 argument-parameter pairs (11497 equal, 56 a variant to its enum) over 121 programs.
         types: 0 type conflicts in 19418 nodes both typed (19418 agree, 0 refined) over 121 programs.
```

The types total line has `partial 0`. Stone 6's run of the same gate, on the tree before this
stone, had `partial 16`. The two probes in row 3 are among the 56: their function types differ
and fit, so the join counts them with the variant rule's other hits.

`checker-multi` is 26, where that earlier run was 24. The two new ones are `assertion-failed!`
in the function-type reader, which the checker types as `Option` against the declared return —
the same shape the other 24 already were. `compiler-multi` stayed 3. Neither is in the
must-be-zero list. The must-be-zero fields are all zero.

## Row 6 ⛔ — partial is must-be-zero — **MET**

On a copy of this tree, `:c::wat-fn` exported `[i64 :-> i64]` as `partial:fn` and left every
other function type whole. A full `tools/elf-run.sh` in the real tree with that one change,
then reverted:

```
type-partial  elf/src/fnvec.wat:8:48  compiler=(:wat::core::Vector :- [partial:fn])
types: TOTAL over 121 programs  ...  partial 14  ...
types: FAIL -- partial 14 (must be 0)
elf-run: FAILED
```

Exit 1. The change is not in the tree. `elf/out/compiler.elf` is the fixpoint again, 279568 bytes.

## Row 7 — the one rule — **MET**

Stated once in `:c::assignable?`, and again as `:ck::fits?` over the exported strings. The
sections above are those two. No `:wat::rete::core::defn` remains.

## Row 8 — every counted read still counted — **MET**

```
$ tools/reads.sh
reads: ok -- every read out of a container goes through :c::read-out (lines 3995-4022)
```

## Row 9 — self-hosts — **MET**

`tools/bootstrap.sh`, no `--fast`.

```
   87 binaries in 760600 ms, the compiler among them (279568 bytes)
   86 binaries, all byte-identical
   stage1 == stage2, byte for byte (279568 bytes)
bootstrap: ok
```

Stone 6's fixpoint was 276,703 bytes.

## Row 10 — cost — **MET**

Both compilers at their own fixpoints: stone 6 is 276,703 bytes, this one is 279,568. Same
tree. Copies, `taskset -c 0`, `cpu_core` instructions and cycles, 9 repetitions, two rounds,
every exit 0.

```
round 1
head    best_ins=2616916189  best_cyc=1389729647
stone1  best_ins=2616978712  best_cyc=1380334003
round 2
head    best_ins=2616915829  best_cyc=1383712636
stone1  best_ins=2616978558  best_cyc=1381731780
```

| | instructions | cycles |
|---|---|---|
| round 1 | +62,523 (+0.00239%) | −9,395,644 (−0.676%) |
| round 2 | +62,729 (+0.00240%) | −1,980,856 (−0.143%) |

Repetitions of one compiler agree to about a thousand instructions. The rise is sixty-two
thousand in both rounds, so it is the extra typing. Both cycle deltas are under the 1.8% floor,
and they do not agree, so no cycle claim.
