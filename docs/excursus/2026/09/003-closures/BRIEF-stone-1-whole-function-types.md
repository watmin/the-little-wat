# BRIEF — excursus 003 stone 1: a function type is its whole type

> Closures make function types common. Today the compiler knows a function type only as its arity
> and return, so it compiled a type-wrong program into a segfault (F-202). This stone makes the
> function type whole before any closure exists.

## YOU ARE NEW TO THIS — read the history first

`the-little-wat` is a self-hosting compiler for wat, written in wat, emitting x86-64. Read, in order:

1. `docs/excursus/2026/09/003-closures/DESIGN.md` — the three stones; this is the first
2. `FINDINGS.md` — `### F-202` (this stone's evidence), then `### F-194`, `### F-199`, `### F-200`
   for how this compiler refuses what it does not know
3. `docs/excursus/2026/09/002-no-guesses/DESIGN.md` and `SCORE-stone-5-variant-types.md` — the
   one typer, the two rete gates, and `:c::assignable?` as the single statement of Liskov
4. `docs/excursus/2026/09/002-no-guesses/SCORE-stone-6-the-guard-knows-the-variant.md` and
   `WEIGH-stone-6-refuted.md` — the shape of a SCORE, and how the last one was weighed

## THE WORK

`[A B :-> R]` is spelled with its argument types, not `"fn:2:R"`. Everything that reads the
spelling reads the whole type. `:c::assignable?` gains the function-type rule that `wat --check`
enforces — **equal arity, each argument contravariant, the return covariant**, recursively, over
the variant-to-enum rule it already states. An indirect call checks each argument against its
function type's argument type, exactly as a direct call checks against the declaration, and says
it to the export (`CArg`). The export translates a function type to wat's spelling
(`[:wat::core::i64 :wat::core::i64 :-> :wat::core::i64]`, as `WAT_CHECK_TYPES=1 wat --check` prints
it), so the types gate COMPARES function types, and `partial` becomes a must-be-zero failure.
`:ck::a-fits`, the gate's own statement of the rule, gains the same function-type rule.

**No byte of any corpus program moves.** This is knowledge, not code generation.

## THE ROOMS

- `elf/compile.wat:1385-1456` — the function type: the encoding prose, `:c::fn-value-ty` (`:1403`,
  a top-level function as a value — its parameter types are `:c::Fn/ptys`, `:754`), `:c::fn-ty?`,
  `:c::fn-arity`, `:c::fn-ret-ty`, `:c::ty-fn-node` (`:1445`). The spelling is yours. It must
  nest (a function type inside an argument, inside a Vector's element — `elf/src/fnvec.wat`), and
  it must never collide with the `;` of an enum argument (`:c::semi-from`, `:871`) or the `:` of
  `penum::user::Opt;str`.
- `elf/compile.wat:1047` — `:c::assignable?`, and its prose above, which says what it covers today.
- `elf/compile.wat:2586-2594` — the indirect-call arm: the arity check, where the argument check
  goes. `:c::check-args` (`:1835`) is the direct call's; reuse its export line.
- `elf/compile.wat:1607` — `:c::fn-ret-ty`'s caller in the typer.
- `elf/compile.wat:3887-3892` — `:c::word-ty?` names `fn:` by prefix; keep whatever prefix test
  you need true to the new spelling.
- `elf/compile.wat:7184-7212` — `:c::wat-ty`, the export's translation; `:7212` is the `partial:` arm.
- `tools/rules/check.wat:25-40`, `:145` (`:ck::a-fits`), `:456` (`:ck::kind-of`) and
  `tools/rules.sh:163` — the gate's rule and its must-be-zero line.

## IMPLEMENTATION SKETCH

```
spelling:   fn-ty-of(args, ret)  /  fn-args(t) -> Vector of String  /  fn-ret-ty(t)
            fn-arity(t) = length of fn-args(t)
assignable?(from, to):
   from = to                                         -> true
   both enum types                                   -> today's rule
   both function types, equal arity                  -> every to.arg assignable? to from.arg
                                                        and from.ret assignable? to to.ret
   else                                              -> false
indirect call:   arity, then each argument's type assignable? to fn-args(ht)[i], or refuse naming it
wat-ty(fn):      "[" + wat-ty(arg)… + " :-> " + wat-ty(ret) + "]"
```

## THE FIXTURES — on disk

- `elf/probe/fnty-arg-wrong-refused.wat` — was a SEGFAULT. Must be refused at compile time.
- `elf/probe/fnty-arg-narrow-refused.wat` — was compiled. Must be refused.
- `elf/probe/fnty-arg-widen.wat` — must agree (`1`).
- `elf/probe/fnty-ret-narrow.wat` — was refused. Must agree (`4`).
- `elf/src/fnref.wat`, `elf/src/fnvec.wat` — the corpus's function values; must agree, unmoved.

## STOP TRIGGERS

- **STOP-1 — a corpus program's bytes move.** This stone changes what the compiler knows, not what
  it emits. Capture the program and the diff.
- **STOP-2 — the gate cannot state the function-type rule in `check.wat`** without re-deriving a
  type the compiler exported. Report what it would take.
- **STOP-3 — `wat --check` and the compiler disagree on a function-type program you write.** The
  rule is wat's; capture the program and both answers.
- **STOP-4 — a gate above zero, or a red.** Capture it; never re-run it to make it pass.

## OUT OF SCOPE

The closure representation and the `fn` form (stones 2 and 3) · F-201 (a type argument inferred
from the payload rather than the parameter — a different root) · variance anywhere but function
types · anything in `../wat-rs`.

## METHOD

`timeout -s KILL` on every wat run; leave the tree alone while `tools/bootstrap.sh`/`tools/elf-run.sh`
runs; assert every text replacement matched exactly once; `cond` ends in `(:else …)`, no `_`, no
catch-all; bootstrap without `--fast`; run `tools/elf-run.sh` IN FULL (not `SKIP_BUILD`). Every
number the SCORE prints is one you measured. **Leave the tree dirty; commit nothing.** Write
`SCORE-stone-1-whole-function-types.md` here.
