# BRIEF — excursus 002 stone 5: the compiler knows variant types

> The builder, on wat's type system: *"variants are both a variant and the parent... a func who wants
> a user/Opt can accept either user/Opt.Some or user/Opt.None... a func who wants an explicit variant
> may not be given an Opt or another variant... when accepting a parent you must use match... when
> accepting a variant you don't need to match on it"* — Liskov substitution. And: *"draw it"*.

## THE GAP — the compiler knows less than the language about every constructed value

wat types `(:user::Opt.None {})` as **the `None` VARIANT, of a `T` not yet fixed** — the checker says
`(:user::Opt.None :- [:?…])` alone, and `(:user::Opt.None :- [:wat::core::String])` once it is passed
where an `Opt` of `String` is wanted. The compiler has neither idea:

- **no variant types** — it types every constructor as the parent. Stone 2's gate counts the loss:
  **92 `type-refined` nodes**, each a place the language knows the variant and the compiler does not.
  A variant as a parameter type is refused outright (stone 4's totality, `elf/compile.wat:1223`:
  *"cannot type a type form this compiler does not know … (:user::Opt.Some :- [wat.type/String])"*).
- **no free `T`** — so a unit variant nothing instantiates is D9 (`elf/probe/generic-unit-unfixed.wat`):
  it runs correctly, and both gates fail it.

## THE MODEL — the language's, not a new one

1. **Variant types.** `(:E.V :- [A…])` and `:E.V` are types. A value built by `(:E.V {…})` has type
   `E.V` (instantiated). **`E.V <: E` with the same instantiation, and nothing else is assignable.**
2. **A unit variant's `T` is free until its use fixes it.** A free `T` is not a guess — a unit variant
   never mentions `T` — and it is not a default: at a boundary it takes the parameter's instantiation.
   A unit variant is its TAG in every tier, so no representation depends on the free `T`.
3. **Assignability, ONE definition in the compiler**, used wherever the compiler asks "may this value
   go here" (call arguments, `let` bindings, the join of branches).

## THE GATES LEARN SUBTYPING — without a second definition drifting from the compiler's

- The **types gate** already widens the checker's variant to its enum to call a node "refined". With
  the compiler exporting variant types in wat's spelling (through `:c::wat-ty`, `:6559` — still ONE
  translation), those nodes become plain AGREEMENTS. **`refined` should reach 0.**
- The **boundary gate** compares with `string::not=` (`tools/rules/check.wat:130`). A variant passed to
  its parent is correct and unequal. The rule must express assignability — and ONLY the language's
  definition of it (a variant of `E` with instantiation `A` is assignable to `E` with `A`), stated
  once, in the ruleset, from the two exported types. Anything more is a second typer.

## THE FIXTURES — committed with this brief

- `elf/probe/variant-param.wat` — a `Some`-typed parameter passed on to an `Opt` parameter.
  Interpreter **`3 3 0`**; must compile natively, agree, and pass both gates.
- `elf/probe/variant-param-wrong.wat` — a `None` where a `Some` is wanted. `wat --check` exits 1;
  **the native compiler must refuse it too**, naming the call: the compiler now KNOWS.
- `elf/probe/generic-unit-unfixed.wat` (D9) — must pass both gates.

## READ IN ORDER

```
docs/excursus/2026/09/002-no-guesses/SCORE-stone-4-one-total-typer.md   the typer as it now stands; the join
elf/compile.wat:1194   :c::ty-node        the type-form reader; :1223 is the refusal a variant type hits
elf/compile.wat:966    :c::enum-ty        tier and instantiation -- the one place a constructor's spelling comes from
elf/compile.wat:2339   :c::variant-arg    how an instantiation is recovered from a constructor
elf/compile.wat:1414   :c::type-of-form   the constructor arm
elf/compile.wat:1494   :c::join-ty        where branches meet -- a Some and a None join to their enum
elf/compile.wat:6559   :c::wat-ty         the one translation to wat's spelling
tools/rules/check.wat:126-130, :208       z-conflict (string equality) and t-refined
```

## STOP TRIGGERS

- **STOP-1 — a free `T` would have to become a representation choice.** If some value's LAYOUT depends
  on a `T` nothing has fixed, that is a guess wearing a new name. Report the shape.
- **STOP-2 — a second definition of assignability** anywhere beyond the compiler's one function and the
  ruleset's one statement of the language's rule.
- **STOP-3 — the same `let`-bound unit variant used where two different `T`s are wanted**
  (`(let [n (:Opt.None {})] (f-string n) (f-int n))`). Ask the checker what it does, match it, and
  report which it was — do not invent a policy.
- **STOP-4 — any corpus program's emission moves.** This stone is knowledge: a moved byte needs a named
  reason, and none is expected (tag-check elision is stone 6).
- **STOP-5 — a red.** Capture it; never re-run it.

## OUT OF SCOPE, AFFIRMATIVELY

`{:keys …}` destructuring (stone 5b) · skipping the tag check for a variant-typed value (stone 6) ·
records' destructuring · closures · anything in wat-rs.

## METHOD

`/home/watmin/Work/holon/the-little-wat`, `main`. `timeout -s KILL` on every wat run; tree untouched
while `bootstrap.sh`/`elf-run.sh` run; every replacement asserts it matched; `cond` ends in
`(:else …)`; no `_`, no catch-all; bootstrap without `--fast`. Cost in INSTRUCTIONS (wall time on this
laptop tracks the machine). Every number the SCORE prints is one you measured. **Leave the tree dirty;
commit nothing.** Write `SCORE-stone-5-variant-types.md` beside this file.
