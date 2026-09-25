# SCORE — excursus 002 stone 5: the compiler knows variant types

Struck 2026-09-24 on `main` at `695f706`. The tree is left dirty and nothing is committed. Every
number below was measured in this session, and output is pasted as it was printed. wat-rs was not
touched.

**Verdict, first.** All ten rows are MET.
- `variant-param` compiles natively and agrees, `3|3|0`.
- `variant-param-wrong` is refused by the native compiler, which names the call.
- D9 (`generic-unit-unfixed`) passes both gates. The `None`'s node is exported as
  `(:user::Opt.None :- [:wat::core::String])`, which is exactly the checker's type for it.
- Full `elf-run`: **`refined 0`**, 0 type conflicts in 18,603 nodes, and 0 boundary conflicts in
  11,160 pairs. Of those pairs, 41 are a variant passed where its enum is wanted.
- A mutant with too-permissive assignability fails `elf-run` twice: the refusal goes missing, and
  the boundary gate names the call.
- **No corpus byte moved.** 85 of 85 binaries match HEAD's own build, and so do all 25 probes HEAD
  could compile.
- Native compile cost is **+4.76%** in instructions. It comes almost entirely from typing every
  call's arguments, which is how the compiler now checks each call against its parameters (row 10).

STOP-1 fired as a *shape*, not as a guess: a `match` on a value whose `T` nothing fixed is now a
refusal, and it is reported below. STOP-2, STOP-4 and STOP-5 did not fire. For STOP-3 I asked the
checker what it does, and the compiler now does the same (see "STOP-3").

## What was built

| piece | where (`elf/compile.wat`, final line) | what |
|---|---|---|
| variant types, spelled | `:c::enum-ty-named` :986 | `(:E.V :- [A])` is spelled like its enum at the same instantiation, with the variant's qualified name in place of the enum's: `penum::user::Opt.Some;str` beside `penum::user::Opt;str`. **The tier is the enum's**, so any consumer that reads the tier sees the same answer for both. `:c::enum-ty` now calls this function with the enum's own name |
| free `T` | `:c::free-ty` :999, `:c::free-ty?` | the type of a variant that fixes no `T`, spelled with the argument `?`: `enum::user::Opt.None;?`. Its tier describes what its values are. A unit variant is its tag in every tier, so it gets `enum:`. A payload variant that does not mention `T` gets its enum's tier, which cannot depend on `T` |
| **the one assignability** | `:c::assignable?` :1040 | a type is assignable to itself. `E.V` is assignable to `E` at the same instantiation. A free `?` takes the instantiation it is given. Nothing else is assignable |
| completion | `:c::complete` :1056 | a free `T` is fixed by the type it flows into. It never answers whether the value fits; that question belongs to `assignable?` |
| constructors | `:c::ctor-ty` :2711 | the type-of-form arm: a constructor has **its variant's type** |
| type forms | `:c::ty-node` | reads `(:E.V :- [A])` and bare `:E.V`. A bare variant of a generic enum is refused, for the same reason its bare enum is |
| the join | `:c::join-ty` :1619, `:c::parent-of` :1638 | the least type both branches are assignable to. `Some` and `None` join to `Opt`, at the one instantiation either of them fixes |
| boundaries | `:c::fit` :1791, `:c::check-args` :1822, `:c::bind-ty` :1843 | every argument to a user function is completed, then checked with `assignable?`, or the program is refused. For an inlined call, the check runs at the `let` binding the inliner made (below). The export states the completed type at the node (`CArg`, and a `CType` for a node that was free) |
| STOP-3 | `:c::fix-free` :1869, `:c::wants-*` | a `let` binding with a free `T` takes the instantiation its uses want. If two uses want different ones, the program is refused |
| inliner | `:c::inl-one`, `:c::inl-temps`, `:c::inl-param-ty` | the binding an inlined call's argument goes into carries the parameter's declared type (`:c::mknode-ty`). So the argument is checked there, and the parameter is typed as declared, exactly as when the call is not inlined |
| one binding type | `:c::bind-ty` | the generator (`:c::bind-each`) used to call `type-of` on a `let` initialiser itself. It now asks the same function the typer (`:c::ty-bind1`) asks |
| refusal positions | `:c::written-at` :6929, Prog `oorgs` | a node the inliner made remembers the node it replaced. A refusal inside inlined code therefore names where the call was *written*, even in a build that is not tracking positions |
| D9's line | `:c::variant-ftys` | `(if (= arg "") "i64" arg)` is now a refusal (a backstop; every path that could reach it refuses earlier, with a position) |
| match | `:c::subject-arg` :1694 | the three places that read a `match` subject's instantiation (typer, analysis, generator) now go through one function, which refuses a free subject |
| parameter types | `:c::decl-ptys` :4556, `Fn/ptys` | read once per function, next to `ret` (row 10) |
| check once | Prog `final` | argument checks run in pass two only. Pass one only measures instruction widths, and a check emits nothing |
| **the ruleset's rule** | `tools/rules/check.wat` `:ck::a-fits` :145 | the language's rule stated once, deriving `Fits`. `z-conflict` fires when there is no `Fits`. The new `z-variant` is the counted witness |
| gate policy | `tools/rules.sh` | `refined` is must-be-zero, and its lines print as findings |
| negative test | `tools/gen-refuse.sh`, `tools/elf-run.sh`, `elf/refuse-variant.wat` (new) | the refusal is checked on every `elf-run`, and the message must match exactly |

`git diff --numstat`:
- `elf/compile.wat`: +486/−83. The four `elf/refuse*.wat` carry the same diff; bootstrap
  regenerated them.
- `tools/rules/check.wat`: +89/−17.
- `tools/rules.sh`: +7/−5.
- `tools/elf-run.sh`: +6/−2.
- `tools/gen-refuse.sh`: +3.
- `elf/probe/README.md`: +3.

---

## Row 1 ⛔ — a variant parameter works — **MET**

```
$ tools/probe.sh elf/probe/variant-param.wat
variant-param: agree   [3|3|0]
```

At HEAD this was `COMPILE-FAILED` at the variant type: `cannot type a type form this compiler does
not know … (:user::Opt.Some :- …`, measured in the baseline run. Its gate facts:

```
"CParam elf/probe/variant-param.wat 9 33 0 user/needs-some penum::user::Opt.Some;str"
"CArg elf/probe/variant-param.wat 10 3 0 user/needs-opt user/needs-some penum::user::Opt.Some;str"
"CParam elf/probe/variant-param.wat 6 32 0 user/needs-opt penum::user::Opt;str"
  ~boundary-type-VARIANT  elf/probe/variant-param.wat:10:3  call=user/needs-opt  in=user/needs-some  arg=0  arg-type=penum::user::Opt.Some;str  param-type=penum::user::Opt;str
  ~type-AGREES  elf/probe/variant-param.wat:10:19  type=(:user::Opt.Some :- [:wat::core::String])
```

The checker types `s` at 10:19 as `(:user::Opt.Some :- [:wat::core::String])` too.

## Row 2 ⛔ — the compiler enforces Liskov — **MET**

```
$ tools/probe.sh elf/probe/variant-param-wrong.wat
variant-param-wrong: COMPILE-FAILED  … compile: cannot pass argument 0 of user/needs-some: it wants (:user::Opt.Some :- [:wat::core::String]) and is given (:user::Opt.None :- [:?]) at elf/src/probe.wat 12 25: (user/needs-some (:user::Opt.None {}))
```

The checker's own words, for comparison: `:user::needs-some: parameter #1 expects (:user::Opt.Some
:- [:wat::core::String]); got (:user::Opt.None :- [:?1490])`.

The same refusal fires when the inliner turned the call into a `let`. In that case the check runs
where the argument is bound to the parameter, and `:c::written-at` recovers the call's position.
Both forms are measured on scratch probes:

```
inl-wrong1: … cannot pass parameter o of the inlined call: it wants (:user::Opt.Some :- [:wat::core::i64]) and is given (:user::Opt.None :- [:?]) at elf/src/probe.wat 6 23: (user/seven (:user::Opt.None {}))
inl-wrong:  … cannot pass argument 1 of the inlined call: it wants (:user::Opt.Some :- [:wat::core::i64]) and is given (:user::Opt.None :- [:?]) at elf/src/probe.wat 9 25: (user/two 1 (:user::Opt.None {}))
```

The other half of the rule is enforced too: an `Opt` where a `None` is wanted is refused. The
checker also exits 1 on that program.
`cannot pass argument 0 of user/wn: it wants (:user::Opt.None :- [:wat::core::String]) and is given (:user::Opt :- [:wat::core::String]) at … 5 81: (user/wn o)`.

`elf-run` now checks this refusal every time, from `elf/refuse-variant.wat`:
```
refused elf/probe/variant-param-wrong.wat, naming the call: a None where a Some is wanted (stone 5)
```

## Row 3 ⛔ — D9 closed — **MET**

```
$ tools/rules.sh elf/probe/generic-unit-unfixed.wat
rules: TOTAL over 1 programs  CArg 1  CParam 1  pairs 1  agree 0  variant 1  CONFLICT 0  unplaced 0  unjoined 0  mismatch 0
types: TOTAL over 1 programs  CType 4  KType 10  KUnres 0  joined 4  agree 4  refined 0  TYPE-CONFLICT 0  partial 0  untranslatable 0  unresolved 0  checker-multi 0  compiler-multi 0  compiler-only 0  checker-only 6
exit 0
```

The facts, with `T` fixed by the parameter:
```
"CParam elf/probe/generic-unit-unfixed.wat 6 28 0 user/shows penum::user::Opt;str"
"CType elf/probe/generic-unit-unfixed.wat 9 35 user/main penum::user::Opt.None;str (:user::Opt.None :- [:wat::core::String])"
"CArg elf/probe/generic-unit-unfixed.wat 9 23 0 user/shows user/main penum::user::Opt.None;str"
  ~type-AGREES  elf/probe/generic-unit-unfixed.wat:9:35  type=(:user::Opt.None :- [:wat::core::String])
```

HEAD's gates on the same probe (baseline run, this session): `arg-type=henum::user::Opt
param-type=penum::user::Opt;str`, `CONFLICT 1`, `TYPE-CONFLICT 1`, FAIL. The binary is
byte-identical to HEAD's, and it agrees, `0`.

## Row 4 ⛔ — no knowledge lost to widening — **MET**

Full `tools/elf-run.sh` on the final tree, rc 0:

```
  rules: exported 102 programs in 15140 ms (4 refused by the compiler); export-on == export-off for 102 of 102; 76 corpus binaries byte-identical to elf/out, 0 not
  rules: TOTAL over 102 programs  CArg 11160  CParam 2633  pairs 11160  agree 11119  variant 41  CONFLICT 0  unplaced 0  unjoined 0  mismatch 0
  types: TOTAL over 102 programs  CType 18904  KType 31061  KUnres 0  joined 18603  agree 18603  refined 0  TYPE-CONFLICT 0  partial 16  untranslatable 0  unresolved 0  checker-multi 23  compiler-multi 3  compiler-only 285  checker-only 12442
elf-run: ok -- 87 native binaries. 38 agree with the interpreter;
         3 more use syscalls it has no implementation of (F-119); 5 refusals and
         4 traps, both ways. rules: 0 conflicts in 11160 argument-parameter pairs (11119 equal, 41 a variant to its enum) over 102 programs.
         types: 0 type conflicts in 18603 nodes both typed (18603 agree, 0 refined) over 102 programs.
```

HEAD's baseline, measured this session with the same `rules.sh`: `refined 92`, `TYPE-CONFLICT 1`,
`CONFLICT 1` (D9). **What the 92 were:** every one was a constructor of a non-generic enum. The
checker knew the variant and the compiler only knew the enum:
- 69 in the compiler itself: `:rd::Kind.List` ×34, `.Symbol` ×16, `.Vector` ×6, `.Int` ×5,
  `.Str` ×4, `.Map` ×2, `.Keyword` ×1, and `:c::Read.*` ×5;
- 23 in the corpus: `:user::B.Many`, `:user::O.Yes`, `:user::Val.*`, `:user::Shape.*`,
  `:user::S.Some`.

All 92 are now agreements. "Joined" rose 17,964 → 18,603 because of the new facts at argument
nodes.

**The gates' policy.** `refined` is now must-be-zero, and a `type-refined` line prints as a
finding. Now that the compiler knows variant types, a node where it knows less than the checker
is exactly what this excursus hunts. Reverting that is one word in `rules.sh`.

## Row 5 ⛔ — the gate still bites — **MET, caught twice**

The mutant is a copy of the final tree in the scratchpad, with ONE change in `:c::assignable?`.
The clause "`to` is the enum, or `from` names the same variant" became `true`, so any variant of
`E` is assignable to any other at the same instantiation. `tools/gen-refuse.sh` was re-run there,
then `SKIP_BUILD=1 tools/elf-run.sh` → **rc 1**:

```
FAIL: elf/refuse-variant.wat did not refuse as expected
      "compile: elf/probe/variant-param-wrong.wat -> elf/out/bad.elf         3429  bytes   fns 3    code 189    data 24    verified"
    boundary-type-conflict  elf/probe/variant-param-wrong.wat:12:25  call=user/needs-some  in=user/main  arg=0  arg-type=penum::user::Opt.None;str  param-type=penum::user::Opt.Some;str  param-at=elf/probe/variant-param-wrong.wat:8
  rules: TOTAL over 103 programs  CArg 11161  CParam 2635  pairs 11161  agree 11116  variant 44  CONFLICT 1  unplaced 0  unjoined 0  mismatch 0
  rules: FAIL -- CONFLICT 1 (must be 0)
  FAIL: the compiler disagrees -- with itself, with the language, or the export moved a byte
elf-run: FAILED
```

The two catches are independent:
- The negative test sees that the compiler stopped refusing.
- The ruleset's rule, which does not come from the compiler's code, sees the `None` reach the
  `Some` parameter.

Nothing else in that run failed.

## Row 6 — one assignability — **MET**

**In the compiler**, `:c::assignable?` (:1040) is the only definition. Its four callers:

```
1624: ((:c::assignable? t1 t2 pg) t2)                        join-ty
1625: ((:c::assignable? t2 t1 pg) t1)                        join-ty
1629: (:c::assignable? t1 p pg) (:c::assignable? t2 p pg)    join-ty, siblings to their enum
1795: (:wat::core::if (:wat::core::not (:c::assignable? c want pg))   :c::fit -- every argument, every inlined binding
```

`:c::complete` fixes a free `T` and nothing else. The old join spelling test (`enum-base`) was
deleted rather than kept next to the new rule.

**In the ruleset**, `:ck::a-fits` (`tools/rules/check.wat`:145) is the one statement:

```
(:wat::rete::where
  (:wat::rete::core::or
    (:wat::rete::string::= ?at ?pt)
    (:wat::rete::core::and
      (:wat::rete::string::= ?ai ?pi)                                          ; the same instantiation
      (:wat::rete::core::and
        (:wat::rete::string::starts-with? ?an (:wat::rete::string::concat ?pn "."))   ; E.V where E
        (:wat::rete::core::not (:wat::rete::string::contains? <the V part> "."))))))  ; one variant name
```

It reads the two exported types and derives no type. The rete `where` language has no
`index-of`, so each type is split lexically where its line is read (`:ck::ty-name`/`:ck::ty-inst`:
the name runs up to the first `;`). That is the same kind of reading `:ck::kind-of` already does.

**The types gate needed no new rule.** It compares the compiler's type with the checker's at the
same node. Its `refined` path already uses the checker's own widening (wat-rs's `wide` column), so
there is no second definition there.

## Row 7 — emission — **0 corpus programs moved (STOP-4 did not fire)**

Against HEAD's own build (`elf/out` copied before any edit, `compiler.elf` 273,874 B, the stone-4
fixpoint), after the final bootstrap:

```
vs HEAD's build: compared 85, moved 0
```

`tools/emitted.sh check` says `MOVED: elf/out/option.elf` / `1 of 84 programs changed`. **That is
the manifest, not this stone.** Here is how I know:
- The manifest records `option.elf` as `54e9c2f7…`.
- HEAD's `option.elf` and this tree's are both `af82b198…`, the same bytes.
- `54e9c2…` matches an older `option.elf` (3,953 B) that was left in my scratch directory from
  before stone 4.
- Stone 4 moved `option.elf` on purpose, 3,953 → 3,938, and the manifest was not refreshed.

The same run's `rules.sh` independently reports `76 corpus binaries byte-identical to elf/out, 0
not`.

**Probes.** Each probe was compiled by a native probe-compiler built from HEAD's source and by one
built from this source: **25 of 25 that HEAD compiles are byte-identical**. That includes
`generic-unit-unfixed`, `inline-origin`, `match-i64`, the `penum-*` probes and the F-188 door
probes. `variant-param` is new; HEAD refused it. `generic-bare-*`, `nth-record` and
`variant-param-wrong` are refused by both.

Why nothing moved:
- A variant's tier is its enum's, so every representation decision (`ptr-ty?`, `word-ty?`, the
  match tier, sharing) gets the same answer as before.
- A free `T` only ever occurred in D9's shape, and D9's binary was already right.

## Row 8 — the corpus — **MET**

`elf-run` (row 4) reports **38 agree**, 3 native-only and 4 traps, then `ok`. It now counts **5
refusals**, up from 4; the new one is `variant-param-wrong`. The other four refusal messages are
unchanged, e.g. `refused elf/bad/unsupported.wat, naming form and place: (wat.core/str 10) at 2:23`.

Every probe through `tools/probe.sh`:
- **agree**: `callrel-borrow`, `check-param-shadow`, `count-bare`, `count-literal`,
  `count-trie`, `f168-and-tail-vec`, `f168-and-tail`, `f170-cond-test`, `field-borrow`,
  `field-shadow`, `generic-unit-unfixed [0]`, `inline-origin`, `match-i64 [4|4]`,
  `match-shadow`, `nested-vec`, `own-shadow`, `penum-spelled-henum`, `penum-str-let`, `regabi`,
  `share-join`, `share-shadow`, `str-borrow`, `str-shadow`, `tier1-borrow`,
  **`variant-param [3|3|0]`**.
- **refused, as intended**: `generic-bare-share`, `generic-bare-tier`, `nth-record`, and
  **`variant-param-wrong`**.
- `let-shadow-crash` (F-191): `CRASH signal=11`, the same as at HEAD. Its binary is
  byte-identical to HEAD's.

That is every probe as at stone 4, plus the three fixtures.

## Row 9 ⛔ — self-hosts — **MET**

`tools/bootstrap.sh` on the final source, full, not `--fast`:

```
== stage 0: the interpreter runs the compiler ==
   87 binaries in 525319 ms, the compiler among them (285477 bytes)
== stage 1: the compiler, compiled, runs itself ==
   the same work in 688 ms -- 763x faster than the interpreter
== every binary, from both ==
   86 binaries, all byte-identical
== the fixpoint ==
   stage1 == stage2, byte for byte (285477 bytes)
   The compiler reproduces itself.
bootstrap: ok
```

The compiler compiles itself with every call checked. That includes its own 69 constructors of
`:rd::Kind.*` and `:c::Read.*`, which are now variant-typed and passed where `:rd::Kind` or
`:c::Read` is wanted.

## Row 10 — cost

| | HEAD | this tree | |
|---|---|---|---|
| compiler size | 273,874 B | **285,477 B** | +11,603 (+4.2%) |
| **interpreter instructions**: `wat` compiles `option.wat` + `reader.wat` (so it loads and checks the whole compiler), pinned to cpu 2, min of 3 | 25,827,488,237 | **26,360,735,116** | **+2.06%** |
| **native instructions**: the compiler compiling the whole driver (75 programs + itself), both on the SAME final source, pinned to cpu 2, min of 6 | 2,536,226,471 | **2,656,876,048** | **+4.76%** |

**Where the native cost is.** It was measured, because the first build of this stone cost +10.8%
(2,531,843,642 → 2,805,534,718):
- With the call-site check switched off, the same source costs 2,547,432,472. So the check is
  94% of the increase.
- Typing the arguments alone, with no parameter types and no assignability, costs 2,720,750,086.
  That is 173M of the increase.
- Re-reading each parameter's type node at every call was 85M more.

Two changes, both kept:
1. Parameter types are read once per function (`Fn/ptys`, next to `ret`). This gave 2,752,369,977.
2. The check runs in pass two only. Pass one only measures instruction widths, and a check emits
   nothing. This gave the final +4.76%.

What is left is typing every argument of every non-inlined user call once. The typer has no memo,
so that is the price of the compiler checking every call. Wall time is not used for cost (F-192).
For the record only: stage 0 ran in 525.3 s and stage 1 in 688 ms.

---

## STOP-3 — what the checker does, matched

The probe (`scratchpad/stop3.wat`):

```
(wat.core/let [n (:user::Opt.None {})]
  (wat.core/do (wat.kernel/println (user/fs n))     ; fs wants (Opt :- [String])
               (wat.kernel/println (user/fi n))))   ; fi wants (Opt :- [i64])
```

**`wat --check` refuses it** (rc 1):

```
:user::fi: parameter #1 expects (:user::Opt :- [:wat::core::i64]); got (:user::Opt.None :- [:wat::core::String])
```

So a `let` binding has ONE type. The first use that wants an instantiation fixes `T`, and a use
that wants another instantiation is a type error. It is not polymorphic.

The compiler now does the same (`:c::fix-free`). It asks every place the name is passed straight to
a parameter, including a parameter the inliner bound, what that place wants:
- one instantiation becomes the binding's;
- two different ones are refused;
- a name that no parameter receives keeps its free `T`, as the checker's does. The checker gives
  an unused `m` the type `(:user::Opt.None :- [:?4331])`, measured.

```
stop3:     COMPILE-FAILED compile: cannot type a binding, n, of a type parameter nothing fixed, used where two are wanted: (:user::Opt.None :- [:wat::core::String]) and (:user::Opt :- [:wat::core::i64]) -- a binding has one type at elf/src/probe.wat 9 3: (wat.core/let [n (:user::Opt.None {})] …
stop3-one: agree   [0|5|4]      ; one binding, three uses, all String -- both gates 0
```

**Where the match is not total.** The scan looks at *direct* uses. Suppose every use of the name
reaches a parameter through a branch, e.g. `(fs (if c n S))` and `(fi (if c n I))`. Then no direct
use fixes `T`, each join fixes it separately, and the compiler accepts a program the checker
refuses. It runs correctly, because a unit variant is its tag, but the compiler would be more
permissive than the language here. Nothing in the corpus or the probes has this shape. I did not
write the unification it would take.

## STOP-1 — the shape it fired on, refused and not guessed

A `match` whose subject's `T` is still free:

```
(let [n (:user::Opt.None {})]
  (match n [:user::Opt.Some {:value v} (string/length v)] [:user::Opt.None {} 0]))
```

- The checker accepts it (rc 0). It infers `T = String` from how the arm uses `v`.
- The compiler compiles each arm once. How a payload arm reads its field depends on the tier:
  it is the pointer itself at tier 1, and a slot of a heap block at tier 3. The free `T` would
  decide which.
- So the compiler now refuses it (`:c::subject-arg`): `cannot type a match on a value whose type
  parameter nothing has fixed -- the tier its arms read would be a guess at … 6 44: n`.

Two related shapes are refused the same way:
- a constructor whose `T` is fixed to a free type, e.g. `(:Opt.Some {:value n})` with `n` free.
  That enum's tier would come from whether `n`'s type is a pointer (`:c::variant-arg`);
- D9's old line, as a backstop.

**None of these shapes occurs in the corpus, the compiler or the probes.** Covering them would take
the checker's use-driven inference, or specialising a function per instantiation.

## The two trap doors

- **The join.** Stone 4's join refused unequal types. It now joins siblings to their enum. On a
  scratch probe, `(if c (:Opt.None {}) (:Opt.Some {:value "xyz"}))` passed to an `Opt of String`
  gives `join-sib: agree [0|7|-1]`, with both gates at 0.
- **`match` narrows — not done (stone 6).** Inside an arm, the subject keeps the type it had
  outside. The checker does not narrow it either: all 92 refined nodes were constructors, and
  refined is 0 now. So nothing disagrees.

## What fought back

1. **The inliner hides boundaries.** A call that gets inlined becomes a `let`, and `rules.sh`
   only sees the calls that remain. A check at the call site alone would have let an inlined `None`
   reach a `Some` parameter.
   - The fix: the binding the argument goes into now carries the parameter's declared type. There
     are two cases: `inl-one`'s parameter, and `inl-temps`'s temporaries, which are bound in the
     caller's scope.
   - `:c::bind-ty` checks that binding with the same `:c::fit`, and types the parameter as
     declared, as when the call is not inlined.
   - Doing this uncovered a second derivation: the generator's `bind-each` had been calling
     `type-of` on a `let` initialiser on its own. It now asks `bind-ty`.
2. **Refusals in inlined code had no position.** A normal build rebuilds positions only for nodes
   the reader made. Made nodes now keep the node they replaced (`oorgs`), and `:c::where` follows
   that chain back.
3. **The rete `where` language has no `index-of` or `split`.** "The same instantiation" needs a
   type split at its first `;`. That split is done lexically when the fact line is read, and the
   rule compares the parts. `string::subs` also takes an `:undefined` default, which I set to `"."`
   so that an out-of-range read can only fail the rule.
4. **The compiler's own subset has no `string::ends-with?`.** The first native build of the
   exporter refused `:c::free-ty?`, so it is written with `subs`.
5. **Cost.** The first working build was +10.8% native. That was measured and cut to +4.76% (row
   10). Nothing about the check was relaxed to get there.
6. **My HEAD copy nested.** `cp -a elf/out $S/head-out` went into an existing directory, so its
   top level was an older build, and a first comparison showed `option.elf` moved. The real HEAD
   build was in `head-out/out/`, and against it 0 binaries moved. The `emitted.sh` manifest turned
   out to be stale in the same way (row 7).

## Files

- `elf/compile.wat`: everything in "What was built".
- `elf/refuse*.wat`: regenerated by bootstrap. `elf/refuse-variant.wat` is new.
- `tools/rules/check.wat`: `:ck::a-fits`, `Fits`, `z-variant`, the lexical split, and `variant`
  in the tally. `type-refined` now prints.
- `tools/rules.sh`: `refined` is must-be-zero, and the header is updated.
- `tools/elf-run.sh`: the variant refusal, its stale check, and the summary's `(N equal, M a
  variant to its enum)`.
- `tools/gen-refuse.sh`: `elf/refuse-variant.wat`.
- `elf/probe/README.md`: rows for `variant-param`, `variant-param-wrong` and
  `generic-unit-unfixed`.

---

## ORCHESTRATOR — the kill, weighed against my own re-run (2026-09-24)

| claim | my re-run | verdict |
|---|---|---|
| a variant parameter works | `tools/probe.sh elf/probe/variant-param.wat`: **agree `3\|3\|0`** | **confirmed** |
| the compiler enforces Liskov | `variant-param-wrong.wat`: COMPILE-FAILED, *"cannot pass argument 0 of user/needs-some: it wants (:user::Opt.Some :- [String]) and is given (:user::Opt.None :- [:?])"* | **confirmed** |
| D9 closed | `tools/rules.sh elf/probe/generic-unit-unfixed.wat`: exit 0; `variant 1, CONFLICT 0`; `refined 0` | **confirmed** |
| gates | `tools/elf-run.sh`: `rules: 0 conflicts in 11160 pairs (11119 equal, 41 a variant to its enum)` · `types: 0 type conflicts in 18603 nodes (18603 agree, 0 refined)` · 102 programs · 5 refusals (the new one is `variant-param-wrong`, refused by the checker AND the compiler) · `elf-run: ok` | **confirmed** |
| emission | HEAD built from `git archive`, proved at its fixpoint (273,874 B): **75 of 75 corpus programs byte-identical, none moved** | **confirmed** — knowledge only, as drawn |
| self-hosts | full bootstrap: `stage1 == stage2` at 285,477 B | **confirmed** |
| the mutant | the strike's (any variant assignable to any sibling), caught twice; not re-run by me — the standing negative `elf/refuse-variant.wat` is now in `elf-run` and fires on every run | **accepted** |

### Recorded, not fixed

- **Cost: +4.76% native instructions** compiling the driver (+2.06% interpreted) — the price of
  checking every call argument's assignability, with no memo in the typer. The strike cut a first
  +10.8% to this without relaxing the check.
- **STOP-3's match with the checker is not total**: a `let`-bound unit variant whose two uses reach
  different `T`s only through branches — `(fs (if c n S))` and `(fi (if c n I))` — is accepted by the
  compiler and refused by the checker. It runs correctly; nothing in the corpus has the shape.
- **`refined` is now must-be-zero** — a policy the strike set in `tools/rules.sh`; kept, since zero is
  now true and any regrowth is lost knowledge.
- `tools/emitted.sh`'s manifest had been stale since stone 4 (`option.elf`); re-saved with this commit.

### Verdict

**Stone 5 lands.** The compiler knows every variant the language knows: 92 refined nodes became
agreements, D9 is closed without a guess or a refusal, and Liskov is enforced by the compiler itself.
