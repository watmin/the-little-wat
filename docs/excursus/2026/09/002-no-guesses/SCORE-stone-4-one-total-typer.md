# SCORE — excursus 002 stone 4: one total typer, and both gates to zero

Struck 2026-09-24 on `main` at `90ed34b`. The tree is left dirty and nothing is committed. Every
number below was measured in this session, and output is pasted as it was printed. wat-rs was not
touched.

**Verdict, first.** All ten rows are MET.
- **Both gates are at zero** and are now MUST-BE-ZERO. A mutant proves that `elf-run` fails when
  either gate is non-zero.
- **F-195 is gone.** `match-i64` agrees `4|4`.
- **None of the six guesses survives.** Each one is now a compile-time refusal that names the form
  and its position.
- **Exactly two binaries moved against HEAD's build**: `option.elf` in the corpus, and the
  compiler's own. One probe moved: `match-i64`. Each move is explained by the guess it stopped
  making, and two of the three are proven by a mutant.

**The strike also found two SILENT WRONG ANSWERS on `main` that nobody knew about.** They come from
a seventh `"i64"` default the crawl did not list (`:c::variant-ftys`, `elf/compile.wat:899`). Both
are now compile refusals. What remains of that default is reported under "What fought back" as a
STOP-1-class item: it was not refused, and it was not made quieter.

## What was built

| piece | where (`elf/compile.wat`, final line) | what |
|---|---|---|
| the refusal | `:c::ty-fail` :1388, `:c::where` :6524 | `compile: cannot type <what> at <file> <line> <col>: <form>`. A normal build tracks no positions, so `:c::where` recovers them with stone 1's walk, and only on the path that stops the compile |
| the waist | `:c::type-of-node` :1364, `:c::type-of-form` :1414 | total. Int has its own arm. A Symbol nothing binds, any other node kind, and a call the pass does not know are all refusals |
| builtins | `:c::type-of-form` | the arithmetic and bitwise ops, `length`/`string/length`/`byte-length`, the syscalls, `mmap`/`clone`/`peek`/`wait` and `prim/write-hex` each answer `i64` by name. They used to get it by falling through to the guess |
| `match` | `:c::match-ty` :1548, `:c::arm-env` :1570 | the join of the arms. Each arm is typed with its pattern's names bound at their field types, at the subject's instantiation |
| the join | `:c::join-ty` :1494 | `if`, `cond` and `match` answer the join of their branches (see row 6) |
| constructors | the variant arm of `:c::type-of-form` | `(:c::enum-ty pg ei (:c::variant-arg a env pg))`: tier and `;arg` both come from the one function |
| `variant-arg` | :2339 | only a field DECLARED `<- :T` instantiates a generic enum, and a non-generic enum gets `""` |
| inliner origin | `:c::mknode-ty` :6004, `:c::origin-ty` :1395, Prog `obase`/`otys` | the `let` an inlined call becomes is typed as the callee's declared return, so the type no longer depends on whether the inliner fired |
| shared field types | `:c::arm-fks`/`arm-fields`/`arm-ftys` :1605 | `:c::match-arms` (the generator) and `:c::arm-env` (the typer) read a variant's field types through the same three functions |
| scopes in analyses | `:c::kids-safe?` :2407, `:c::binds-safe?`, `:c::arms-safe?`, `:c::noret?` | the register analyses type a `let` body in the `let`'s scope and a `match` arm in its pattern's scope (see "unbound" below) |
| `quiet-variant?` | :2372 | a unit variant is quiet in every tier, so the tier is no longer asked for it |
| bare generic | `:c::ty-node` :1242 | a generic enum type written with no `:- [T]` is refused |
| the gates | `tools/rules.sh`, `tools/elf-run.sh` | must be zero (row 3) |
| probes | `elf/probe/inline-origin.wat`, `generic-bare-share.wat`, `generic-bare-tier.wat` (+ README rows) | pin the inliner's origin type and the two new wrong answers |

`git diff --numstat`: `elf/compile.wat` +401/−98; `tools/rules.sh` 28 lines and `tools/elf-run.sh`
24 lines changed; the four `elf/refuse*.wat` carry the same diff as the compiler.

---

## Row 1 ⛔ — F-195 is gone — **MET**

```
$ tools/probe.sh elf/probe/match-i64.wat
match-i64: agree   [4|4]
```

HEAD, compiled natively by HEAD's compiler, printed `match-i64: DIVERGE native=[4|5] (0) interp=[4|4] (0)`.
The binary is **3,460 → 3,471 B (+11)**. That is the share `v` now gets when it is passed on.

## Row 2 ⛔ — F-194's class is gone — **MET**

```
$ tools/probe.sh elf/probe/penum-str-let.wat
penum-str-let: agree   [2]
$ tools/probe.sh elf/probe/penum-spelled-henum.wat
penum-spelled-henum: agree   [4|3]
$ tools/rules.sh elf/probe/penum-str-let.wat elf/probe/penum-spelled-henum.wat elf/probe/match-i64.wat
rules: TOTAL over 3 programs  CArg 6  CParam 5  pairs 6  agree 6  CONFLICT 0  unplaced 0  unjoined 0  mismatch 0
types: TOTAL over 3 programs  CType 32  KType 70  KUnres 0  joined 32  agree 27  refined 5  TYPE-CONFLICT 0  ...
```

At HEAD the boundary gate showed 1 conflict on `penum-str-let` and 2 on `penum-spelled-henum`.
Now the constructor is typed through `:c::enum-ty`, so `o` is `penum:user::S`, as the parameter
is. Both binaries are byte-identical to HEAD's: the spelling changed and the code did not.

## Row 3 ⛔ — both gates at ZERO, and elf-run fails otherwise — **MET**

`tools/elf-run.sh`, full (rebuilt through the interpreter), rc 0:

```
== the compiler agrees with itself, and with the language: tools/rules.sh (must be zero) ==
  rules: exporter built natively in 1371 ms
  types: the checker typed 96 programs in 38935 ms (7 refused); over the whole of each (stdlib included): 12214 positions with two types, 56449 unresolved, 0 orphans, 0 check errors
    refused  elf/probe/generic-bare-share.wat  (compile: cannot type a generic enum with no type argument -- its representation depends on it at elf/probe/gen)
    refused  elf/probe/generic-bare-tier.wat  (compile: cannot type a generic enum with no type argument -- its representation depends on it at elf/probe/gen)
    refused  elf/probe/nth-record.wat  (compile: cannot type nth: operand is not a Vector at elf/probe/nth-record.wat 5 23: (wat.core/nth (:user::P :a)
  rules: exported 100 programs in 16742 ms (3 refused by the compiler); export-on == export-off for 100 of 100; 76 corpus binaries byte-identical to elf/out, 0 not
  rules: TOTAL over 100 programs  CArg 10739  CParam 2515  pairs 10739  agree 10739  CONFLICT 0  unplaced 0  unjoined 0  mismatch 0
  types: TOTAL over 100 programs  CType 18261  KType 30004  KUnres 0  joined 17960  agree 17868  refined 92  TYPE-CONFLICT 0  partial 16  untranslatable 0  unresolved 0  checker-multi 22  compiler-multi 3  compiler-only 285  checker-only 12028
  rules: checked in 98221 ms; total 156814 ms

elf-run: ok -- 87 native binaries. 38 agree with the interpreter;
         3 more use syscalls it has no implementation of (F-119); 4 refusals and
         4 traps, both ways. rules: 0 conflicts in 10739 argument-parameter pairs over 100 programs.
         types: 0 type conflicts in 17960 nodes both typed (17868 agree, 92 refined) over 100 programs.
```

(The `types: TOTAL` line is printed by the run. It is shown here because the summary above parses it.)

**The gate is two exits and one verdict.**
- `tools/rules.sh` now reads its verdict from the two TOTAL lines and exits 1 when any of these
  is non-zero:
  - `CONFLICT`, or `TYPE-CONFLICT`;
  - `unplaced`, `unjoined`, `mismatch`, `untranslatable`, `unresolved`. A join that has gone
    blind would also report zero conflicts, so these count too.
- It also exits 1 when the export moved a byte, and 2 when no check could be made.
- `refined` stays allowed.
- A missing TOTAL line is exit 2.
- The zero-line filter used to hide `rules: TOTAL` whenever it was all zeros. It now keeps it.
- `elf-run` fails on either exit, and names which kind it was.

**The mutant.** A copy of this tree in the scratchpad, with ONE change: the `match` arm reverted to
the old guess, `((:c::match? head) "i64")`. `tools/gen-refuse.sh` was re-run there so the stale
check could not fire, then `SKIP_BUILD=1 tools/elf-run.sh` → **rc 1**:

```
    boundary-type-conflict  elf/compile.wat:3456:24  call=:c::emit  in=:c::read-out  arg=0  arg-type=i64  param-type=rec::c::Out  param-at=elf/compile.wat:287
    type-conflict  elf/compile.wat:3442:9  in=:c::read-out  compiler=:wat::core::i64  checker=:c::Out  raw=i64
    type-conflict  elf/compile.wat:3456:34  in=:c::read-out  compiler=:wat::core::i64  checker=:c::Out  raw=i64
    type-conflict  elf/probe/match-i64.wat:14:20  in=user/main  compiler=:wat::core::i64  checker=(:wat::core::Vector :- [:wat::core::i64])  raw=i64
    type-conflict  elf/probe/match-i64.wat:15:32  ...
    type-conflict  elf/probe/match-i64.wat:16:32  ...
    boundary-type-conflict  elf/probe/match-i64.wat:15:21  call=user/bump  in=user/main  arg=0  arg-type=i64  param-type=vec:i64  param-at=elf/probe/match-i64.wat:10
    boundary-type-conflict  elf/probe/match-i64.wat:16:21  call=user/bump  ...
  rules: TOTAL over 100 programs  CArg 10735  CParam 2515  pairs 10735  agree 10732  CONFLICT 3  unplaced 0  unjoined 0  mismatch 0
  rules: FAIL -- CONFLICT 3 (must be 0)
  types: FAIL -- TYPE-CONFLICT 5 (must be 0)
  FAIL: the compiler disagrees -- with itself, with the language, or the export moved a byte
elf-run: FAILED
```

Nothing else in that run failed. Both gates fired, each on its own count.

## Row 4 ⛔ — no guess survives — **MET for the six** (and see D9)

| # | the guess at `90ed34b` | now |
|---|---|---|
| 1 | `:c::lookup-ty` `(< i 0) "i64"` (:747) | `(:c::ty-fail "a name the environment does not hold" a pg)`. `lookup-ty` now takes the asking node. Its one remaining caller is `:c::scalar-params`, which passes the parameter's node. The waist no longer calls it: it uses `lookup-ty-opt` and refuses in place |
| 2 | `:c::fn-ret` `(>= i (length v)) "i64"` (:1135) | `ty-fail "the return of a function the program does not define, <name>"`. It takes the node, or `-1` from `:c::scalar-of` |
| 3 | `:c::ty-node` `(< (length ks) 3) "i64"` (:1195) | `ty-fail "a type form with no \`:- [...]\`"` |
| 4 | `:c::ty-node` `(:else "i64")` (:1213) | `ty-fail "a type form this compiler does not know"` |
| 5 | `:c::type-of` `(:else "i64")` (:1354) | an explicit `Kind.Int` arm (a literal IS `i64`); everything else is `ty-fail "an expression of this kind"` |
| 6 | `:c::type-of-form` `(:else … "i64")` (:1413) | a fn-typed head answers its return; anything else is `ty-fail "a call this pass does not know"` |

The neighbours of the six, which were the same shape, are refusals too:
- `ty-node`'s depth limit, and a `Vector` type with no element;
- `type-of-form`'s empty form, a `cond` or `if` with no branch, `nth`/`conj`/`assoc` with no
  operand, `nth` of a non-Vector, and a `(Vector)` with no `:- [T]`;
- `:c::fn-value-ty`, `:c::fn-ret-ty`, `:c::elem-ty` and `:c::acc-ty`.

`grep -n '"i64"' elf/compile.wat`, excluding comments, final source:

```
899:            (:wat::core::if (:wat::core::= arg "") "i64" arg)      <- D9, not one of the six: see below
1255:          ((:c::is? src "wat.type/i64" ":wat::core::i64") "i64")  <- the declared type i64
1384:      ((:wat::core::= k (:rd::Kind.Int {})) "i64")               <- an integer literal
1441:        ((:wat::core::not= op "") "i64")                         <- + - * quot rem, the bitwise six
1449:        ((:c::codeat? head) "i64")
1470-1476:   bit-not, length/string-length, syscalls, mmap/clone, peek/wait, prim/write-hex
3433:  (:wat::core::or (:wat::core::= t "i64")                        <- word-ty?, a test
6562:      ((:wat::core::= t "i64") ":wat::core::i64")                <- the translation
```

Every one is a type the language fixes, except 899.

The refusal names the form and its position, in a normal build:

```
compile: cannot type nth: operand is not a Vector at elf/probe/nth-record.wat 5 23: (wat.core/nth (:user::P :a 7 :b 9) 0)
compile: cannot type a call this pass does not know at elf/bad/unsupported.wat 2 23: (wat.core/str 10)
compile: cannot type a generic enum with no type argument -- its representation depends on it at elf/probe/generic-bare-tier.wat 4 32: :user::Opt
```

## Row 5 ⛔ — the guess census, before — **measured**

**Method.** A scratch variant of `90ed34b`'s `elf/compile.wat`:
- every guess site printed `GUESS <id> <file line col> <function> <form>` and then answered what
  it always answered;
- positions were tracked;
- HEAD's native compiler built the variant, and the variant compiled the whole driver: 75 corpus
  programs plus the compiler.

Its 76 binaries were **byte-identical to HEAD's**, so the census changed nothing it measured. The
probes were compiled one per process. "Firings" counts every question, so pass one and pass two
each count. "Sites" are distinct source positions.

| # | guess | corpus firings (compiler / the other 75) | distinct sites | probes | what fired |
|---|---|---|---|---|---|
| 1 | `lookup-ty` | 3,209 (1,454 / 1,755) | 32 names | 154 | **only ever as a step of #6**: a builtin head is not in the environment. Never from `scalar-params` |
| 2 | `fn-ret` | **0** | 0 | 0 | — |
| 3 | `ty-node` short list | **0** | 0 | 0 | — |
| 4 | `ty-node` unknown head | **0** | 0 | 0 | — |
| 5 | `type-of` `:else` | 4,338 (1,566 / 2,772) | 1,196 (691 / 505) | 267 | **every one an integer literal**, a genuine `i64` reached by default. Other kinds: 0 |
| 6 | `type-of-form` `:else` | 3,209 (1,454 / 1,755) | 1,000 (660 / 340) in 64 programs | 154 (44 sites) | builtins and `match`, below |

Guess 6, by head (distinct sites; both spellings merged):

```
336 +   307 length   128 -   85 *   43 string/length   19 rem   15 /   9 quot   8 string/byte-length
7 os/mmap   6 os/peek   6 bit-shift-right   6 bit-shift-left   6 bit-and   4 unsigned-bit-shift-right
3 match   2 os/getpid   2 os/clone   2 bit-or   2 bit-not   1 os/wait   1 os/fork   1 bit-xor   1 prim/write-hex
```

All but `match` answer `i64` in the language, so the guess happened to be right. That is why each
now has its own arm, and why turning #6 into a refusal refused nothing. **`match`, 3 corpus sites
plus 1 probe:**

| site | the language's type | the guess |
|---|---|---|
| `elf/bench/optm.wat:12:24` | `i64` (arms are `(string/length v)` and `0`) | right by luck |
| `elf/bench/optmh.wat:14:24` | `i64` | right by luck |
| `elf/compile.wat:3167:10`, `lo` in `:c::read-out` | `:c::Out` | **wrong**: the compiler's own source, harmless here (`lo` is used once) |
| `elf/probe/match-i64.wat:14:21` | `(Vector :- [i64])` | **wrong**: F-195 |

**Beyond the six**, the same census counted:
- **D6**, a symbol nothing binds, typed through `fn-value-ty`'s `"i64"`: 4 firings, 1 site,
  `proto` in `elf/bench/parse.wat:31:32`, and the same line in `parsebits.wat:23:32`. **It was
  not in the program; it was in an analysis.**
  - `:c::noret?` → `all-quiet?` → `scratch-safe?` → `word-cmp?` asked `(= proto 6)` in the
    function's scope, but `proto` is a `let` binding.
  - Measured with an interpreter stack.
  - It was right by luck (`proto` is an i64). For a `let`-bound String, the same path would call
    `str_eq` quiet.
- **D8**, `elem-ty` of a non-Vector: 1, `nth-record` (already refused).
- **D9**, `variant-ftys` on an uninstantiated `:T`: 3 firings, `option.wat:2:19`.
- **D1-D5, D7: 0.**

**STOP-1 did not fire on the six.** Nothing the six fired on is a form the typer could not be
taught this stone: #5 and #6 fired on builtins with language-fixed types, and on `match`. The
corpus compiles with every one of them a refusal. That is proven by the bootstrap (row 9) and by
`rules.sh` refusing only the three probes that are meant to be refused.

## Row 6 — one derivation — **MET**

`:c::type-of` → `:c::type-of-node` → `:c::type-of-form` answers every node, and every consumer
asks it. What used to be derived elsewhere:
- **Constructors.** The variant arm is `(:c::enum-ty pg ei (:c::variant-arg a env pg))`.
  `enum-ty` already decided the tier for every declared type, and `variant-arg` is what the
  generator (`:c::variant-form`) and the analysis (`:c::quiet-variant?`) already asked for the
  instantiation. `variant-arg` had to be corrected to be usable as a type:
  - It used to answer the type of a variant's single field, whatever that field was declared.
  - Only the tier read it, and the tier ignores the argument of a non-generic enum.
  - Put into the type, it spelled `(:user::S.Some {:s "xy"})` of the plain enum `:user::S` as
    `penum:user::S;str`. The first gate run after the change counted it as **16 boundary and 20
    type conflicts** (borrowed, shapes, matchval, `:c::Read` in the compiler, three probes).
  - Now only a field declared `<- :T` instantiates, and a non-generic enum gets `""`.
  - The tier is unchanged: no byte moved.
- **`match` arms.** The typer binds a pattern's names through `:c::arm-fields`/`:c::arm-ftys`.
  `:c::match-arms`, which emits the code, now calls the same two functions instead of its own
  copy.
- **Inlined calls.** `:c::inl-call`'s final node is made by `:c::mknode-ty` with the callee's
  `Fn/ret`, the same answer `(:c::fn-ret pg head 0 a)` gives the call when it is not inlined.
  `origin-ty` reads it back.
- **Branches.** `if`, `cond` and `match` are the JOIN of their branches (`:c::join-ty`):
  - equal types join to themselves;
  - a branch that cannot return (`assertion-failed!`) contributes nothing;
  - two spellings of ONE enum join to the one that carries `;arg`: only a branch with a payload
    fixes `T`, and its spelling is also the one with the right tier;
  - **any other disagreement is a refusal**, not a pick.
  - Over the whole corpus, no program was refused by the join.
  - The trap door said *"the declared type where the arms disagree only in representation"*. In
    this corpus, the one way branches disagree is the instantiation, and the join takes the
    instantiated spelling.
- **`and`/`or` answer `bool`**, as `check.rs`'s `infer_boolean_shortcircuit` does. They used to
  answer their last operand's type.

STOP-2 did not fire: no second answerer was added. The one shared-question refactor went the other
way: the generator lost its private copy of the field types.

**The inliner-origin rule, shown on its own** (`elf/probe/inline-origin.wat`, new):
- `user/none`'s body is `(:user::Opt.None {})`, and it is inlined into `(user/showi (user/none))`.
- HEAD's gates:
  ```
  boundary-type-conflict  elf/probe/inline-origin.wat:19:23  call=user/showi  arg-type=henum::user::Opt  param-type=henum::user::Opt;i64
  type-conflict  elf/probe/inline-origin.wat:11:3  compiler=:user::Opt  checker=(:user::Opt.None :- [:wat::core::i64])
  type-conflict  elf/probe/inline-origin.wat:19:35  compiler=:user::Opt  checker=(:user::Opt :- [:wat::core::i64])
  ```
- This tree: `CONFLICT 0`, `TYPE-CONFLICT 0`.
- Agrees `"none"` both ways, and the binary is byte-identical to HEAD's.

## Row 7 — emission — **every move named and explained**

`tools/emitted.sh check` after the bootstrap:

```
   MOVED: elf/out/option.elf
emitted: 1 of 84 programs changed, 0 new
```

Independently of the manifest, against HEAD's own build (copied from `elf/out` at `90ed34b` before
any edit, and checked to be HEAD's fixpoint): **84 compared, 1 moved: `option.elf`**. The
compiler's own binary is excluded from both checks.

| binary | bytes | the guess it stopped making | proof |
|---|---|---|---|
| `compiler.elf` | 262,558 → 273,874 (its new source); on the SAME new source, HEAD's compiler emits 273,537 and the new one 273,548: **+11** | #6 on `match`: `lo` in `:c::read-out` was `i64`, and is now `rec::c::Out`, so passing it to `:c::emit` shares it | CType for the new source, exported by HEAD's typer and by the new one and joined by position. Exactly two positions changed type: `3424:9` (the match) and `3438:34` (`lo`), `i64` → `rec::c::Out` (plus the shared `? 0 0` key of unpositioned nodes). **A mutant new compiler whose `match` arm answers `"i64"` compiles the new source to 273,537 B, byte-identical to HEAD's compiler's output** |
| `elf/probe/match-i64.wat` | 3,460 → 3,471 (+11) | #6 on `match`: `v` is `vec:i64` and is shared | the same mutant reproduces HEAD's 3,460 B byte for byte |
| `option.elf` | 3,953 → 3,938 (−15) | **D9**: `:c::quiet-variant?` asked the tier of `(:user::Opt.None {})` with no instantiation, got tier 3 at `T = i64`, and called it LOUD. A unit variant is `mov rax, tag` in every tier | printing `:c::argreg-fn?`'s answer per function: before, `user/name 0`; after, **`user/name 1`**. `pick`, `showi` and `shows` are unchanged at 0. With only this change reverted, no corpus program moves. Agrees: `"7" "none" "<yes>" "none"` |

Every other probe is byte-identical to HEAD's, except the two new `generic-bare-*` probes, which
HEAD compiled and this tree refuses. That includes `inline-origin`, `penum-*` and the F-188 door
probes. STOP-3 did not fire.

## Row 8 — the corpus — **MET**

`elf-run` (row 3): **38 agree**, 3 native-only, 4 refusals, 4 traps, `ok`.

Every probe, compiled natively by the new compiler and diffed against the interpreter:
- **agree**: `callrel-borrow`, `check-param-shadow`, `count-bare`, `count-literal`, `count-trie`,
  `f168-and-tail`, `f168-and-tail-vec`, `f170-cond-test`, `field-borrow`, `field-shadow`,
  `inline-origin`, `match-i64`, `match-shadow`, `nested-vec`, `own-shadow`,
  `penum-spelled-henum`, `penum-str-let`, `regabi`, `share-join`, `share-shadow`, `str-borrow`,
  `str-shadow`, `tier1-borrow`.
- `nth-record` and both `generic-bare-*`: refused, as intended.
- `let-shadow-crash` (F-191): SIGSEGV. **It is unchanged**: HEAD segfaults on it identically, and
  its binary is byte-identical to HEAD's.

One refusal's message moved:
- `elf/bad/unsupported.wat` is now refused by the TYPE pass. `println` types its argument before
  anything is emitted.
- The message is
  `cannot type a call this pass does not know at elf/bad/unsupported.wat 2 23: (wat.core/str 10)`.
- HEAD refused one step later, in the generator: `cannot compile call: (wat.core/str 10)`.
- `elf-run`'s needle was updated to require both the form and the place.
- The generator's own message is kept for a head it could type: its indirect-call path now asks
  `:c::head-typed?` before typing a head.

## Row 9 ⛔ — self-hosts — **MET**

`tools/bootstrap.sh`, full, not `--fast`:

```
== stage 0: the interpreter runs the compiler ==
   87 binaries in 563842 ms, the compiler among them (273874 bytes)
== stage 1: the compiler, compiled, runs itself ==
   the same work in 921 ms -- 612x faster than the interpreter
== every binary, from both ==
   86 binaries, all byte-identical
== the fixpoint ==
   stage1 == stage2, byte for byte (273874 bytes)
   The compiler reproduces itself.
bootstrap: ok
```

**Trap door 1 did not bite.** The compiler compiles itself with every guess a refusal, so no
refusal of its own source. The census showed why: its 1,454 firings of #6 were builtins and one
`match`.

`elf/refuse*.wat` were regenerated by bootstrap (`gen-refuse.sh`), and that is why they show in
the diff.

## Row 10 — cost

| | HEAD | this tree | |
|---|---|---|---|
| compiler size | 262,558 B | **273,874 B** | +11,316 (+4.3%): the typer's new functions |
| **interpreter instructions**: `wat` compiles `option.wat` + `reader.wat` (so loads and checks the whole compiler), pinned to cpu 2, min of 3 | 25,713,080,341 | **25,824,850,506** | **+0.43%** |
| **native instructions**: the compiler compiling the whole driver (75 programs + itself), both on the SAME new source, pinned, min of 6 | 2,422,599,648 | **2,428,447,135** | **+0.24%** |

Wall time is not used for cost (F-192). For the record only:
- stage 0 was 563.8 s, within this week's 554–580 s range;
- stage 1 was 921 ms;
- `tools/rules.sh` took 134–157 s, the same as stone 2.

The typer is asked more questions now:
- every branch of a branching form, where it used to ask the first branch alone;
- each `match` arm, in its own scope.

It is asked fewer in one place: an inlined call answers from its origin without descending. CType
over the corpus went 17,675 → 18,261.

---

## What fought back

1. **`variant-arg` looked like the obvious instantiation, and it was wrong for every non-generic
   enum.**
   - Wiring the constructor arm to `:c::enum-ty` exactly as the BRIEF said took the gates from 0
     to 16 boundary and 20 type conflicts, on the first run.
   - The fix was in `variant-arg`, which three places already shared, not in a new function.
     STOP-2 stayed shut.
2. **The analyses typed names outside their scope.**
   - `:c::scratch-safe?` and `:c::noret?` walk a function's body with the function's parameters
     only.
   - A `let` body or a `match` arm was asked about in a scope where its names are unbound. That
     is D6.
   - With an unbound name made a refusal, `parse.wat` would have been refused for `(= proto 6)`.
   - The analyses now carry the scope: `kids-safe?`, `binds-safe?`, `arms-safe?`, and the `let`
     arm of `noret?`.
3. **Two silent wrong answers on `main`, found while chasing D9.** Both are in F-195's family.
   - **The shape.** A generic enum written as a bare parameter type, `(o :- :user::Opt)`, passes
     `wat --check` (rc 0), and the interpreter infers `T` per call. The native compiler typed the
     parameter `enum-ty(ei, "")`, which is tier 3 because `:c::variant-ftys` answered `"i64"` for
     the uninstantiated `:T`.
   - **`generic-bare-tier.wat`.** It passes `(Opt.Some {:value "xy"})`, which is TIER 1 (the
     pointer itself). The callee matches it as tier 3. Interpreter `1|0`; HEAD
     **`4197723|0`, exit 0**, a fresh F-194 (one value, two tiers).
   - **`generic-bare-share.wat`.** The payload is a Vector, so `v` binds at `T = i64` and is never
     shared, and `user/bump` grows it in place. Interpreter `44`; HEAD **printed a pointer, exit 0**.
   - **The fix.** `:c::ty-node` now refuses a generic enum named bare. The only generic enum in
     the corpus is `option.wat`'s, and it always writes `(:user::Opt :- [T])`. Both probes are in
     `elf/probe/`.
4. **D9 — what remains, STOP-1 class, reported and not acted on.** `elf/compile.wat:899`,
   `(:wat::core::if (:wat::core::= arg "") "i64" arg)`.
   - **Census after this stone:**
     - **0 firings** on the corpus, the compiler included;
     - **0** on every probe.
     - The last five firings (`option.wat` 3, `inline-origin.wat` 2) were ALL
       `:c::quiet-variant?` asking the tier of `(:Opt.None {})`. That question is now answered
       without the tier (row 7).
   - **Its one remaining reach.** It is the TYPE of a constructor that fixes no `T` (a unit
     variant of a generic enum), where no sibling branch fixes it. For example:
     `(user/shows (:user::Opt.None {}))`, where `shows` takes `(:user::Opt :- [String])`.
     - Measured: it **runs correctly** (`"none"`), because a unit variant is its tag in every
       tier.
     - But the argument is spelled `henum::user::Opt` against `penum::user::Opt;str`, and both
       gates flag it: `CONFLICT 1`, `TYPE-CONFLICT 1`, and the verdict is FAIL. A corpus program
       of this shape would fail `elf-run`.
     - Polarity: fail-safe for representation (a value typed this way can only ever have been a
       tag); fail-open only in its spelling, and the gates catch that.
   - **Why it is not a refusal this stone.**
     - Turning 899 into `:c::fail` refuses `(f (:Opt.None {}))`, the most ordinary way to write
       an Option, which the language accepts.
     - Keeping a quieter default is forbidden.
     - The honest fix is to type the argument from the parameter it feeds, so that the expected
       type fixes `T`: bidirectional typing, a capability this typer does not have.
     - By the four questions: refusing is Honest but not Good UX, and the default is not Honest.
       Both are NO, so this goes to the orchestrator.
5. **The refusal needed positions in a build that does not track them.** `:c::where` recovers them
   with stone 1's walk, only when refusing. A node the inliner made up (with no origin) reports
   `? 0 0`.
6. **`rules.sh`'s zero filter hid its own verdict.** Stone 1's filter dropped every all-zero
   `rules:` line, and that included `rules: TOTAL`, because it only excluded per-program lines by
   accident of spelling. At zero conflicts, `elf-run`'s summary would have read "no total". The
   filter now keeps TOTAL lines.

## Files

- `elf/compile.wat`: everything in "What was built".
- `elf/refuse*.wat`: regenerated by bootstrap.
- `tools/rules.sh`: must-be-zero, its verdict, and the TOTAL filter.
- `tools/elf-run.sh`: the gate's two failure kinds, and the `unsupported.wat` needle.
- `elf/probe/inline-origin.wat`, `elf/probe/generic-bare-share.wat`,
  `elf/probe/generic-bare-tier.wat` (new), and `elf/probe/README.md` (rows for these and for
  `match-i64`).

---

## ORCHESTRATOR — the kill, weighed against my own re-run (2026-09-24)

| claim | my re-run | verdict |
|---|---|---|
| F-195 gone | `tools/probe.sh elf/probe/match-i64.wat`: **agree `4\|4`** | **confirmed** |
| F-194's class gone | `penum-str-let` agree `2`, `penum-spelled-henum` agree `4\|3`, `inline-origin` agree | **confirmed** |
| two new silent wrong answers on HEAD | built with `git show HEAD:elf/compile.wat`: `generic-bare-tier` interp `1\|0`, **HEAD `4197723\|0` exit 0**; `generic-bare-share` interp `44`, **HEAD `127073741684752` exit 0**. Now both COMPILE-FAILED, *"cannot type a generic enum with no type argument…"* | **confirmed** — F-199 |
| the gate bites | a NATURAL mutant of my own, not the strike's: D9's remaining shape, `(user/shows (:user::Opt.None {}))` (`elf/probe/generic-unit-unfixed.wat`) — runs correctly (`agree`), and `tools/rules.sh` **exits 1**, flagging it in both gates | **confirmed** — and it shows D9 cannot ship silently |
| both gates at zero | `tools/elf-run.sh`: `rules: 0 conflicts in 10739 pairs` · `types: 0 type conflicts in 17960 nodes (17868 agree, 92 refined)` · 100 programs · `elf-run: ok`, 38 agree | **confirmed** |
| emission | HEAD (`fbe8d7c`… tree at `328ade3`) built from `git archive`, proved at its fixpoint (262,558 B): **74 of 75 identical; moved: `option.elf`**, which agrees with the interpreter (`"7" "none" "<yes>" "none"`, 3,938 B) | **confirmed**, and the one move is the one the strike explained |
| self-hosts | full bootstrap, `stage1 == stage2` at 273,874 B | **confirmed** |

### D9 — the builder's decision, framed by the four questions

wat's own checker already knows the answer: it types D9's `None` as
`(:user::Opt.None :- [:wat::core::String])`, inferring `T` from the parameter the argument feeds. Of
keep-the-default (Honest NO), refuse (Good UX NO — refuses the ordinary way to write an Option), and
**complete an argument's type from the parameter it feeds** (all four YES), only the last passes. Until
it is built the interim is SAFE, not silent: the shape runs correctly and both gates fail the build if
any program writes it.

### Verdict

**Stone 4 lands.** One derivation behind the type waist; every guess a compile-time refusal; both gates
at zero and failing the build on any conflict. It found and closed two more silent wrong answers on the
way.
