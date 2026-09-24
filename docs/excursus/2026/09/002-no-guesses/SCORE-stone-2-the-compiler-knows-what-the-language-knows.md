# SCORE — excursus 002 stone 2: the compiler knows what the language knows

Struck 2026-09-23/24. the-little-wat on `main` at `15615f0`; wat-rs on `the-little-wat` at
`04d18e8a4`. Both trees are left dirty and nothing is committed. Every number below was measured
in this session, and output is pasted as it was printed.

**Verdict, first.** Rows 1, 2, 3, 5, 6, 7, 8, 9, 10 and 11 are MET. **Row 4 is NOT MET as
written.** The diff is additive, but the wat-rs floor at 4 threads came back RED: 2 lint
failures and 1 timeout. That tripped STOP-6, so the reds were captured and nothing was re-run.
See row 4.

**The stone also found something the BRIEF did not expect: wat-rs's own `--check` does not
type-check user function bodies spelled with namespaced symbols** (`wat.core/let`,
`user/slen`, …). That spelling is most of this corpus. Details are in "What fought back"; it is
the finding most worth weighing.

## What was built

| piece | where | what |
|---|---|---|
| the recorder | wat-rs `src/check/type_record.rs` (new, 162 lines) | per-thread and OFF by default. `infer` notes `(span, type)` into the frame of the open inference root. When the root closes, every note is resolved through that root's FINAL substitution, aliases are expanded (`reduce`), and a variant-widened twin is kept |
| the hook | wat-rs `src/check.rs` (+32/−1) | `infer` now wraps its old body (renamed `infer_node`) and notes the result when recording is on. The four roots that own a `Subst` open and close a frame: `check_function_body`, `check_form`, `extract_def_binding` and each defclause clause |
| the dump | wat-rs `src/distribution/{mod.rs,check_output.rs}` | `WAT_CHECK_TYPES=1 wat --check <entry.wat>` prints `TYPE`/`UNRESOLVED` lines (TAB-separated: file, line, col, type, widened type), then a `TYPES …` trailer. Unset, `--check` runs no new code |
| the export | the-little-wat `elf/compile.wat` (+57) | `:c::type-of`, the waist, now wraps `:c::type-of-node`. With the export on, `:c::fact-type` prints `CType <file> <line> <col> <in> <raw> <wat-type>` for every answer it gives |
| the translation | `:c::wat-ty` (one function) | compiler spelling → wat spelling |
| the rules | `tools/rules/check.wat` (+ 3 records, 10 rules) | joins CType to KType by position. Derives no type |
| the runner | `tools/rules.sh` | runs the checker once per program, 4 at a time. Re-spells file paths. Feeds KType/KUnres into the same fact block as stone 1's facts |
| report mode | `tools/elf-run.sh` | prints the new `types:` total beside stone 1's `rules:` total |

**Why the dump re-checks the FROZEN world.** See "What fought back". In short, the startup check
reads function bodies before namespaced symbols are normalized to keywords, so a clj-spelled body
comes back untyped. The dump runs a second `check_program` over `world.program()` /
`world.symbols()` / `world.types()`: exactly the bodies the runtime executes. That pass exists only
under `WAT_CHECK_TYPES`. Its diagnostics are counted in the trailer and sent to stderr, and they
never change the exit code.

---

## Row 1 ⛔ — it sees F-195 — **MET**

```
$ tools/rules.sh elf/probe/match-i64.wat
rules: exporter built natively in 1239 ms
types: the checker typed 1 programs in 1675 ms (0 refused); over the whole of each (stdlib included): 127 positions with two types, 588 unresolved, 0 orphans, 0 check errors
rules: exported 1 programs in 243 ms (0 refused by the compiler); export-on == export-off for 1 of 1; 0 corpus binaries byte-identical to elf/out, 0 not
  type-conflict  elf/probe/match-i64.wat:14:20  in=user/main  compiler=:wat::core::i64  checker=(:wat::core::Vector :- [:wat::core::i64])  raw=i64
  type-conflict  elf/probe/match-i64.wat:15:32  in=user/main  compiler=:wat::core::i64  checker=(:wat::core::Vector :- [:wat::core::i64])  raw=i64
  type-conflict  elf/probe/match-i64.wat:16:32  in=user/main  compiler=:wat::core::i64  checker=(:wat::core::Vector :- [:wat::core::i64])  raw=i64
  boundary-type-conflict  elf/probe/match-i64.wat:15:21  call=user/bump  in=user/main  arg=0  arg-type=i64  param-type=vec:i64  param-at=elf/probe/match-i64.wat:10
  boundary-type-conflict  elf/probe/match-i64.wat:16:21  call=user/bump  in=user/main  arg=0  arg-type=i64  param-type=vec:i64  param-at=elf/probe/match-i64.wat:10
...
types: TOTAL over 1 programs  CType 12  KType 26  KUnres 0  joined 12  agree 9  refined 0  TYPE-CONFLICT 3  partial 0  untranslatable 0  unresolved 0  checker-multi 0  compiler-multi 0  compiler-only 0  checker-only 14
```

`15:32` and `16:32` are the argument `v` of each `(user/bump v)`: the compiler says `i64`, the
checker says a Vector of i64. `14:20` is the cause itself, the `match` that `v` is bound to. The
compiler types it `i64`, the `:else` fallback of `:c::type-of-form`, and the checker types it
`(Vector :- [i64])`. Stone 1 sees the effect at the boundary; stone 2 sees the site.

## Row 2 ⛔ — it does NOT see F-194 — **MET**

```
$ tools/rules.sh elf/probe/penum-str-let.wat
  boundary-type-conflict  elf/probe/penum-str-let.wat:13:20  call=user/slen  in=user/main  arg=0  arg-type=henum::user::S  param-type=penum::user::S  param-at=elf/probe/penum-str-let.wat:8
rules: TOTAL over 1 programs  CArg 1  CParam 1  pairs 1  agree 0  CONFLICT 1  unplaced 0  unjoined 0  mismatch 0
types: TOTAL over 1 programs  CType 7  KType 14  KUnres 0  joined 7  agree 5  refined 2  TYPE-CONFLICT 0  partial 0  untranslatable 0  unresolved 0  checker-multi 0  compiler-multi 0  compiler-only 0  checker-only 7
```

Stone 1 still flags `13:20`, `henum:` against `penum:`. Stone 2 gives **TYPE-CONFLICT 0**. The facts
for `o`, as each side printed them:

```
"CType elf/probe/penum-str-let.wat 12 20 user/main henum::user::S :user::S"      ;; the constructor
"CType elf/probe/penum-str-let.wat 13 31 user/main henum::user::S :user::S"      ;; o, the argument
"CParam elf/probe/penum-str-let.wat 8 27 0 user/slen penum::user::S"
"KType\telf/probe/penum-str-let.wat\t12\t20\t:user::S.Some\t:user::S"
"KType\telf/probe/penum-str-let.wat\t13\t31\t:user::S.Some\t:user::S"
  ~type-refined  elf/probe/penum-str-let.wat:12:20  compiler=:user::S  checker=:user::S.Some
  ~type-refined  elf/probe/penum-str-let.wat:13:31  compiler=:user::S  checker=:user::S.Some
```

**This is not "both are `:user::S`", and the SCORE should not pretend it is.** wat's checker
knows MORE than the enum: `o` is bound to a `Some` constructor, and wat has variant subtypes, so
it types `o` as `:user::S.Some`. The compiler knows `:user::S`, which is the enum that variant
belongs to. That is sound but less precise. The dump therefore carries the checker's type twice:
as inferred, and widened to its enum by the language's own subsumption (`TypeEnv::enclosing_enum`,
the step `check.rs`'s `widen_to_enclosing_enum` performs, applied at every level). A compiler type
equal only to the widened type is **`type-refined`**: counted, not a conflict, and not hidden
(92 across the corpus, row 6). The `henum:`/`penum:` difference is gone because the one
translation collapses every tier to the enum type, so row 2 turns on the translation.

## Row 3 ⛔ — non-vacuous — **MET**

From the corpus run (row 6): **the compiler typed 17,675 nodes, the checker typed 28,992 in the
same files, 17,367 were joined, 17,266 agree.** Refined: 92. Conflicts: 9.

Each outcome can fire. Each mutant below changes ONE line of the facts of `penum-str-let` +
`match-i64`, fed straight to `tools/rules/check.wat`. Unmutated:
`joined 19  agree 14  refined 2  TYPE-CONFLICT 3`.

| mutant | result |
|---|---|
| a CType's type + `Z` (13:20) | `type-conflict penum-str-let.wat:13:20 compiler=:wat::core::i64Z checker=:wat::core::i64`, agree 13, CONFLICT 4 |
| a CType's column + 1 | `compiler-only 1`, `checker-only 22`, joined 18 |
| a KType at 15:32 made variant-like (its wide = the compiler's) | the 15:32 conflict becomes `refined 3`, CONFLICT 2 |
| a second KType at 9:22 | `checker-multi penum-str-let.wat:9:22 one=:user::S two=:wat::core::i64`, checker-multi 1 |
| a KUnres at 9:22 | `type-unresolved penum-str-let.wat:9:22 compiler=:user::S checker=:?7`, unresolved 1 |
| a CType marked `untranslatable:` | `type-untranslatable penum-str-let.wat:12:20`, untranslatable 1 |

## Row 4 ⛔ — wat-rs unchanged for every existing caller — **NOT MET (floor RED; diff additive)**

### The diff

```
 src/check.rs                     | 33 ++++++++++++++++++++++-
 src/distribution/check_output.rs | 56 ++++++++++++++++++++++++++++++++++++++++
 src/distribution/mod.rs          | 35 ++++++++++++++++++++++++-
?? src/check/type_record.rs          (new, 162 lines)
```

The only two lines removed, each replaced by the same behaviour:

```
-    let ty = infer(&items[expr_idx], env, &HashMap::new(), fresh, &mut subst).drain_errors_into(errors)?;
      → let ty = infer(...).drain_errors_into(errors); close_root(...); let ty = ty?;
-        match startup_from_source(&source, canonical.as_deref(), loader) {
      → let outcome = startup_from_source(...); [dump only if WAT_CHECK_TYPES]; match outcome {
```

- `infer`'s old body is now `infer_node`, unchanged, and every caller still reaches it through
  `infer`.
- With recording off, the only new work is one thread-local flag read per `infer`, plus an empty
  check at each root's open and close.
- No existing output, error or exit code moves. argv parsing and the usage text are untouched,
  because the mode is an environment variable rather than a flag.

### The floor: RED (STOP-6, captured, not re-run)

`NEXTEST_TEST_THREADS=4 scripts/floor.sh`, 27m06s:

```
     Summary [1385.909s] 5397 tests run: 5394 passed (4 slow), 2 failed, 1 timed out, 22 skipped
        FAIL [   0.096s] (  74/5397) wat::lint no_inlined_wat_in_tests::tests_carry_no_inlined_wat
        FAIL [   0.132s] (  77/5397) wat::lint no_loose_string_assert::tests_carry_no_loose_string_assert
     TIMEOUT [ 600.011s] (1911/5397) wat::lint wat_scripts_fixes_load::every_wat_scripts_file_loads_on_the_current_runtime
[floor] ⛔ RED — exit=100
[floor]   THE ARM IS CAPTURED:  .floor/2026-09-24T07-55-54Z/ARM.txt
```

**The two FAILs.** Each block is pasted whole:

```
thread 'no_inlined_wat_in_tests::tests_carry_no_inlined_wat' (2136162) panicked at /home/watmin/Work/holon/wat-rs/tests/lint/no_inlined_wat_in_tests.rs:427:5:
    🔥🔥🔥 INLINED-WAT IN TESTS — 1 file(s) still carry a string literal that wat's own
    reader parses as a form ...
    Drive it to ZERO. Literal-hit breakdown so far: 0 format!-driver, 0 faithful-surface,
    2 other parse-body. Offenders:
    tests/resolve/probe_little_wat_bits_and_code_point.rs

thread 'no_loose_string_assert::tests_carry_no_loose_string_assert' (2136161) panicked at /home/watmin/Work/holon/wat-rs/tests/lint/no_loose_string_assert.rs:112:5:
    🔥🔥🔥 LOOSE STRING ASSERTIONS — 6 site(s) assert a value with contains/starts_with/
    ends_with where an exact `assert_eq!` belongs. ...
    tests/resolve/probe_little_wat_bits_and_code_point.rs:105
    tests/resolve/probe_little_wat_bits_and_code_point.rs:116
    tests/resolve/probe_little_wat_bits_and_code_point.rs:153
    tests/resolve/probe_little_wat_bits_and_code_point.rs:161
    tests/resolve/probe_little_wat_bits_and_code_point.rs:206
    tests/resolve/probe_little_wat_bits_and_code_point.rs:214
```

The arms are the two lints' final zero-assertions (`no_inlined_wat_in_tests.rs:427`,
`no_loose_string_assert.rs:112`). Both name ONE file, which this strike did not touch.
`git diff --quiet HEAD -- tests/` is true. `git log` says the file was last changed by
`04d18e8a4 STONE(the-little-wat/bytes)` and `0a04c0512 STONE(the-little-wat/code-point-at)`. These
two lints read file text, so they are deterministic in the file's content. This is the search,
not a disposition: **they fire on the HEAD this strike started from, and the orchestrator should
weigh them against the stones that landed that file.**

**The TIMEOUT.** Its block, whole:

```
     TIMEOUT [ 600.011s] (1911/5397) wat::lint wat_scripts_fixes_load::every_wat_scripts_file_loads_on_the_current_runtime
  stdout ───
    running 1 test
    test wat_scripts_fixes_load::every_wat_scripts_file_loads_on_the_current_runtime has been running for over 60 seconds
    (test timed out)
```

The arm is nextest's 600 s deadline, not an assertion. This test type-checks all 706 `.wat` files
under `wat-scripts/`. With recording off it pays one flag read per `infer`; measured on
`elf/compile.wat` that is +0.11% instructions (row 11), which cannot account for a deadline. Its
history in the earlier floor logs on disk:
- `2026-09-13T08-35-52Z`: TIMEOUT 600 s;
- `2026-09-13T08-55-21Z`: PASS in **442.0 s**, the one green 5373/5373 run;
- `2026-09-13T09-15-29Z`: TIMEOUT 600 s.

It is a deadline sitting within 1.4× of the test's own green time. **Recorded as a red, not
dismissed.**

## Row 5 ⛔ — one translation — **MET**

`elf/compile.wat`, `:c::wat-ty`. That one `cond` maps the whole type universe the compiler spells
(`i64`, `str`, `bool`, `nil`, `vec:T`, `rec:N`, `enum:`/`penum:`/`henum:N[;A]`, `fn:N:R`):

```clojure
(:wat::core::defn :c::wat-ty [t <- :wat::core::String] -> :wat::core::String
  (:wat::core::let [n (:wat::string::length t)]
    (:wat::core::cond
      ((:wat::core::= t "i64") ":wat::core::i64")
      ((:wat::core::= t "str") ":wat::core::String")
      ((:wat::core::= t "bool") ":wat::core::bool")
      ((:wat::core::= t "nil") ":()")
      ((:wat::string::starts-with? t "vec:") ... "(:wat::core::Vector :- [" (:c::wat-ty elem) "])")
      ((:wat::string::starts-with? t "rec:") (:wat::string::subs t 4 n))
      (enum: / penum: / henum:  -> the enum's name, or "(Name :- [" (:c::wat-ty arg) "])" for ;arg)
      ((:c::fn-ty? t) (:wat::string::concat "partial:" t))
      (:else (:wat::string::concat "untranslatable:" t)))))
```

- It recurses only into itself.
- It calls two existing helpers, `:c::colon-from` and `:c::semi-from`, which find the `:` and the
  `;`. The subset has no `index-of`.
- **Every representation tier collapses to the one enum type.**
- `nil` becomes `:()` because the checker reduces `:wat::core::nil` to the unit tuple.
- A function type is spelled here with its arity and return only, so it cannot be a whole wat
  type. It is marked `partial:` and is never compared (18 across the corpus).
- STOP-2 did not fire. `untranslatable 0` over the corpus.
- No record or enum name needs re-spelling: every `defrecord`/`defenum` in `elf/` is
  keyword-named, 130 of 130 (`vectors.wat:14` explains why).

## Row 6 — the census — **9 conflicts, all listed, none fixed**

`tools/rules.sh` over the corpus and `elf/probe/` (99 programs exported):

```
types: TOTAL over 99 programs  CType 17675  KType 28992  KUnres 0  joined 17367  agree 17266  refined 92  TYPE-CONFLICT 9  partial 18  untranslatable 0  unresolved 0  checker-multi 16  compiler-multi 3  compiler-only 290  checker-only 11607
```

```
  type-conflict  elf/src/option.wat:6:33  in=user/main  compiler=:user::Opt  checker=(:user::Opt.Some :- [:wat::core::i64])  raw=henum::user::Opt
  type-conflict  elf/src/option.wat:6:3  in=user/main  compiler=:user::Opt  checker=(:user::Opt :- [:wat::core::i64])  raw=henum::user::Opt
  type-conflict  elf/src/option.wat:23:37  in=user/main  compiler=:user::Opt  checker=(:user::Opt :- [:wat::core::i64])  raw=henum::user::Opt
  type-conflict  elf/src/option.wat:24:37  in=user/main  compiler=:user::Opt  checker=(:user::Opt :- [:wat::core::i64])  raw=henum::user::Opt
  type-conflict  elf/compile.wat:3167:9  in=:c::read-out  compiler=:wat::core::i64  checker=:c::Out  raw=i64
  type-conflict  elf/compile.wat:3181:34  in=:c::read-out  compiler=:wat::core::i64  checker=:c::Out  raw=i64
  type-conflict  elf/probe/match-i64.wat:14:20  in=user/main  compiler=:wat::core::i64  checker=(:wat::core::Vector :- [:wat::core::i64])  raw=i64
  type-conflict  elf/probe/match-i64.wat:15:32  in=user/main  compiler=:wat::core::i64  checker=(:wat::core::Vector :- [:wat::core::i64])  raw=i64
  type-conflict  elf/probe/match-i64.wat:16:32  in=user/main  compiler=:wat::core::i64  checker=(:wat::core::Vector :- [:wat::core::i64])  raw=i64
```

| # | sites | cause (read from the compiler's source; not fixed) |
|---|---|---|
| 1–4 | `option.wat:6:3`, `6:33`, `23:37`, `24:37` | **The type argument is dropped.** `:c::type-of-form`'s variant arm spells a constructor `henum:`+name with no `;arg`: stone 1's #4–5, now at the site. `6:3` is the `if` in `user/pick`'s body, typed by its consequent `6:33`. `23:37`/`24:37` are `(user/pick 7)`/`(user/pick 0)`, whose `if` was inlined. The checker instantiates `(:user::Opt :- [i64])` and the compiler has a bare, uninstantiated `:user::Opt`. |
| 5–6 | `compile.wat:3167:9`, `3181:34` | **F-195's class, in the compiler.** `lo` in `:c::read-out` is bound to a `match` (`3167:9`), which falls to `:else "i64"`. `3181:34` is `lo` as an argument, stone 1's `3181:24` (formerly `3173:24`). The checker says `:c::Out`. |
| 7–9 | `match-i64.wat:14:20`, `15:32`, `16:32` | **F-195** (row 1). |

Nothing in the census is a representation tier. `refined` (92) is the checker knowing the variant
where the compiler knows the enum. It is counted apart from conflicts, and it is the only place
the widened type is ever consulted.

## Row 7 — the join — **both one-sided sets counted and explained; STOP-3 counted**

**Compiler-only: 290.**
- **278** are in the 7 programs the checker REFUSED, which therefore have no KType at all:
  `parse` 75, `parsebits` 75, `walk` 41, `fork` 21, `threads4` 51, `thread` 8
  (`UnresolvedReferences`: syscalls the interpreter has no implementation of, F-119), and
  `check-param-shadow` 7 (a `TypeMismatch`: the probe's point).
- **12** carry no position: `? 0 0`, nodes the inliner made up. They fall across 9 programs. They
  also account for all 3 `compiler-multi`, because every unpositioned node shares the one `?:0:0`
  key; that is not one node typed two ways.

Of the positioned compiler types in programs the checker accepted, **every one joined**.

**Checker-only: 11,607.** These are nodes the checker's `infer` typed and the compiler never asks
about, since `:c::type-of` is called only where a decision needs a type. By what starts at the
position:

| lists | symbols | int literals | string literals | bool literals | keywords |
|---|---|---|---|---|---|
| 7,839 | 1,839 | 1,266 | 491 | 92 | 80 |

- The lists' heads, most common first: `:wat::core::defn` 775 + `wat.core/defn` 336. **Those
  1,111 are the macro-expanded `(def :name (fn …))` forms, typed `:()`**, which the compiler never
  builds (trap door 2). Then `=` 452 + 117, `if` 435 + 80, `println` 404, `let` 326 + 93, `>=` 242,
  `concat` 203, `or`/`and` 322, `cond` 110.
- Conditions, operands of builtins and statement positions are typed by the checker and never
  queried by the compiler.

**STOP-3, one span with two checker types: 16 over the corpus, at 15 distinct sites, ALL
`(:wat::kernel::assertion-failed! :message …)`.**
- `compile.wat:332:5`, `519:3`, `1236:13`, `1301:7`, `5577:11`, `6184:9`, `6187:9`, `6191:9`,
  `6213:9`, `6224:7`, `6389:9`; `lib/asm.wat:110:7`; `lib/prim.wat:19:7` (reached from two
  programs: `fileio`, and `asmbits` with `asm.wat:110`).
- The mechanism: the kwargs form expands to
  `(assertion-failed!' msg :wat::core::Option.None :wat::core::Option.None)`, and the synthesized
  `None` keywords carry the call's own span. So one position holds
  `(Option :- [String])` AND the call's type, for example `:c::Out`.
- Each is printed as `checker-multi … one=… two=…`. **None was chosen.** The compiler never types
  these nodes (both KTypes show as `ktype-unjoined`), so no join depended on a choice.
- Over the whole of each program, stdlib included, the dump counts 11,827 such positions.
  In the program files: these 16.

**STOP-4, a type variable surviving substitution: 0 at any node of the corpus (`KUnres 0`).**
- The whole-program dumps, stdlib included, keep 54,685 `UNRESOLVED` lines. All are in wat-rs's
  stdlib and `src/…rs` synthetic spans; the join never reaches them.
- They are printed as `UNRESOLVED`, never as `TYPE`.
- `orphans 0`: no `infer` ran outside a root the recorder frames.

**Macro expansion.** Positions survive expansion: `defn`'s `def` form sits at the `defn`'s `(`,
and inside a body every node keeps its reader span. Both halves of the join therefore meet on the
original source. The two costs are listed above: the 1,111 `def`-form positions, and the
`assertion-failed!` doubles.

**File names.** The compiler says `elf/src/../lib/reader.wat`; the checker says
`elf/lib/reader.wat`. `rules.sh` maps each checker label to the compiler's spelling through
`realpath -m --relative-to` on both sides, so stone 1's facts keep their paths.

## Row 8 ⛔ — nothing emitted moved — **MET**

```
$ tools/emitted.sh check
emitted: ok -- all 84 programs byte-identical to the manifest
```

Independently of the manifest:
- HEAD's `elf/compile.wat` was compiled natively and then compiled itself to its fixpoint,
  **260,632 B**.
- That HEAD compiler compiled the corpus:
  **`corpus: 75 byte-identical to the new compiler's, 0 moved`**.

The export on/off check, per program: `export-on == export-off for 99 of 99`, and after bootstrap
`76 corpus binaries byte-identical to elf/out, 0 not`.

The only binary that changed is the compiler's own: 260,632 B → **262,558 B**.

## Row 9 — report mode — **MET**

`tools/elf-run.sh`, full (it rebuilds through the interpreter), 12m21s:

```
== the compiler agrees with itself, and with the language: tools/rules.sh (report mode) ==
  rules: exporter built natively in 858 ms
    checker's recording check found 1 errors in elf/probe/nth-record.wat: TYPES-CHECK-ERROR #wat.check/TypeMismatch {:message ":wat::core::nth: parameter #1 expects (Vector :- [T]), (List :- [T]), (PersistentVector
  types: the checker typed 93 programs in 35044 ms (7 refused); over the whole of each (stdlib included): 11827 positions with two types, 54685 unresolved, 0 orphans, 1 check errors
  rules: exported 99 programs in 18614 ms (1 refused by the compiler); export-on == export-off for 99 of 99; 76 corpus binaries byte-identical to elf/out, 0 not
    ... the findings of rows 6 and 7, and stone 1's 8 ...
  rules: TOTAL over 99 programs  CArg 10307  CParam 2403  pairs 10307  agree 10299  CONFLICT 8  unplaced 0  unjoined 0  mismatch 0
  types: TOTAL over 99 programs  CType 17675  KType 28992  KUnres 0  joined 17367  agree 17266  refined 92  TYPE-CONFLICT 9  partial 18  untranslatable 0  unresolved 0  checker-multi 16  compiler-multi 3  compiler-only 290  checker-only 11607
  rules: checked in 107205 ms; total 163674 ms

elf-run: ok -- 87 native binaries. 38 agree with the interpreter;
         3 more use syscalls it has no implementation of (F-119); 4 refusals and
         4 traps, both ways. rules: 8 conflicts in 10307 argument-parameter pairs over 99 programs.
         types: 9 type conflicts in 17367 nodes both typed (17266 agree, 92 refined) over 99 programs.
```

- Stone 1's gate is unchanged: 8 conflicts, the orchestrator's count.
- A conflict fails neither gate.
- The run still fails when `rules.sh` exits non-zero: the exporter did not build, the checker
  died, or the export moved a byte.

## Row 10 ⛔ — self-hosts — **MET**

`tools/bootstrap.sh`, full, not `--fast`:

```
== stage 0: the interpreter runs the compiler ==
   87 binaries in 579775 ms, the compiler among them (262558 bytes)
== stage 1: the compiler, compiled, runs itself ==
   the same work in 962 ms -- 602x faster than the interpreter
== every binary, from both ==
   86 binaries, all byte-identical
== the fixpoint ==
   stage1 == stage2, byte for byte (262558 bytes)
   The compiler reproduces itself.
bootstrap: ok
```

`elf/refuse*.wat` were regenerated by bootstrap (`gen-refuse.sh`) and show in the diff, as in
stone 1.

## Row 11 — cost

**The recorder when OFF.** HEAD wat-rs (`04d18e8a4`) was built from `git archive` in the
scratchpad and A/B'd against this build:

| workload | HEAD wat | this wat |
|---|---|---|
| `wat --check elf/compile.wat`, wall, 10 interleaved, best | 835 ms | 833 ms |
| same, instructions, pinned to one core, 6 each, min | 3,160,365,746 | 3,163,875,738 (**+0.11%**) |
| interpreter compiles `reader.wat` + `option.wat`, best of 5 (HEAD source / new source) | 6,180 / 6,089 ms | 6,125 / 6,062 ms |
| interpreter compiles `elf/compile.wat` itself, before vs after, 2 interleaved | 436,115 / 520,844 ms | 468,944 / 506,545 ms |

- **Stage 0 was 579.8 s against the 408 s baseline.** The rows above say that is not the
  recorder: it touches only the ~1 s check, and the check is flat.
- It is not measurably the compiler's new waist either. Interpreted runs of the same work
  wander 436 → 521 s on this machine today (powersave governor, a thermal zone at 62 °C), and
  that wander swamps any before/after delta.
- **Recorded, not resolved.** The 408 s figure was taken on a different day.

**The compiler's own normal build** (`tools/cc-time.sh`, HEAD compiler vs new, best of 14,
interleaved, twice):

```
compiler-head.elf        803 ms   2323212198 instructions      |  862 ms   2323211602
compiler.elf             863 ms   2323988330 instructions      |  863 ms   2323988383
```

+0.033% instructions. The wall-time differences are noise; the second run is 862 against 863.

**The gate's wall time.** `tools/rules.sh`, whole corpus plus probes:

| step | stone 1 | stone 2 |
|---|---|---|
| build the native exporter | 0.7–1.1 s | 0.8–1.6 s |
| the checker, 99 programs, 4 at a time | — | 32.8–45.7 s |
| export, 99 programs × 2 compiles | 3.5–4.5 s | 18.0–22.4 s (the CType lines) |
| rete check | 22.7–31.0 s | 74–107 s |
| **total** | **27.0 s** | **147.5 s standalone, 163.7 s inside elf-run** |

---

## What fought back

1. **wat-rs's `--check` never types a clj-spelled function body.**
   - `startup_from_source` registers function bodies at step 6, normalizes namespaced symbols to
     keywords at step 7 (`normalize_symbol_refs`) for the RESIDUE only, and runs
     `check_program` at step 8.
   - `check_function_body` reads the step-6 bodies from `sym`. A body headed `(wat.core/let …)`
     therefore reaches `infer` as a call through an unbound Symbol: the head gets a fresh
     variable, the binder vector is inferred as a Vector literal, and nothing inside is typed.
   - At freeze, `register_runtime_defs` re-registers the normalized bodies, which the runtime
     then runs.
   - Measured on a one-character edit of the F-194 probe, `(user/slen o)` → `(user/slen 5)`:
     ```
     $ wat --check bad1.wat                 → exit 0
     $ wat bad1.wat                         → PatternMatchFailed "...no arm matched scrutinee of type wat::core::i64; exhaustiveness should be caught at type-check time"
     $ WAT_CHECK_TYPES=1 wat --check bad1.wat
     TYPES-CHECK-ERROR #wat.check/TypeMismatch {:message ":user::slen: parameter #1 expects :user::S; got :wat::core::i64" ... :line 13 :col 31 ...
     ```
   - The same code, keyword-spelled, is refused by `--check` as it should be.
   - The corpus itself exposes it: `elf/probe/nth-record.wat` (`nth` on a record) PASSES
     `wat --check`, but the recording check over the frozen world reports
     `:wat::core::nth: parameter #1 expects (Vector :- [T]) …`. That is F-190's program: the
     language's own checker would have refused it, had it seen the body.
   - **This stone works around it, in dump mode only, and does not fix it** (STOP-5, and STOP-1:
     moving the step-8 check would change what `--check` reports). Without the workaround, every
     clj-spelled body in the corpus would have come back as unresolved variables, and row 1 could
     not have been met. It wants its own finding.
2. **The checker knows variants and the compiler does not.** A constructor's type is
   `:user::S.Some`, not `:user::S`. So the dump carries a widened twin, and the rules count
   `refined` apart. Without that, row 2 would have failed on refinement rather than on
   representation.
3. **Every `infer` root owns its own substitution.** "Apply the final substitution" therefore
   means per root. The recorder keeps a stack of frames: a defclause clause nests inside a form,
   and each `continue` needed its own close. `orphans 0` proves no `infer` ran outside a frame.
4. **Positions made by macros** (STOP-3): all 16 are `assertion-failed!`'s synthesized `None`s.
   See row 7.
5. **I defined `:c::semi-from` twice.** It already existed at `compile.wat:864`, with identical
   semantics. wat-rs accepted the identical redefinition (a non-identical one is refused with
   `DefRedefForbidden`, checked), and the checker typed only one body. The first corpus run
   therefore showed 7 `ctype-unjoined` inside my own function, which is what led to the
   duplicate. It has been removed.
6. **A partial type nested in a Vector.** `vec:fn:1:i64` translates to
   `(Vector :- [partial:fn:1:i64])`. The first classifier read only a leading `partial:` and
   counted fnvec's 6 as conflicts. It now looks anywhere in the string.
7. **The floor is RED** (row 4). Two content lints fail on a file this strike did not touch, from
   `04d18e8a4`, and a 600 s deadline is hit by a test that passed in 442 s once.

## Files

- wat-rs:
  - `src/check/type_record.rs` (new);
  - `src/check.rs` (the `infer` wrapper, the four roots, `pub mod type_record`);
  - `src/distribution/mod.rs` (the `WAT_CHECK_TYPES` branch of `--check`);
  - `src/distribution/check_output.rs` (`emit_types`).
- the-little-wat:
  - `elf/compile.wat`: `:c::type-of` → `:c::type-of-node`, `:c::wat-ty`, `:c::fact-type`;
  - `tools/rules.sh`, `tools/rules/check.wat`, `tools/elf-run.sh`;
  - `elf/refuse*.wat`, regenerated by bootstrap.

---

## ORCHESTRATOR — the kill, weighed against my own re-run (2026-09-24)

| claim | my re-run | verdict |
|---|---|---|
| sees F-195 | `tools/rules.sh elf/probe/match-i64.wat`: **3 type conflicts** (14:20, 15:32, 16:32), compiler `:wat::core::i64`, checker `(:wat::core::Vector :- [:wat::core::i64])` | **confirmed** |
| does NOT see F-194 | `tools/rules.sh elf/probe/penum-str-let.wat`: **0 type conflicts** (2 refined: the checker types `o` as the variant `:user::S.Some`); stone 1's gate still flags 13:20 | **confirmed** — the two gates are complementary, as drawn |
| the `--check` hole (F-196) | `(user/slen 5)` against a `:user::S` parameter: namespaced spelling → `wat --check` **exit 0**, then runtime `PatternMatchFailed`; the same program in keyword spelling → **exit 1**, `TypeMismatch … expects :user::S; got :wat::core::i64`. **Same split on a HEAD build of wat-rs** (no `type_record.rs`, `check.rs` identical to HEAD) | **confirmed, and pre-existing** |
| wat-rs change is additive | `git diff`: +122 / −2; the two removed lines are a `?` split around `infer` and a `match` given a name; `open_root`/`close_root` return at once unless recording is on; `tests/` untouched | **confirmed** |
| row 4, the red floor | both lints name `tests/resolve/probe_little_wat_bits_and_code_point.rs`, last written by `0a04c0512`/`04d18e8a4` (this repo's 09-20 stones); the lints read test files and none changed; the timeout sits at its 600 s deadline in the 09-13 logs too | **pre-existing, and ours** — F-197 |
| nothing emitted moved | HEAD (`3c5cd93`) built from `git archive`, proved at its own fixpoint (260,632 B): **75 corpus programs byte-identical, 0 moved** | **confirmed** |
| self-hosts | full bootstrap: `stage1 == stage2` at 262,558 B | **confirmed** |

### Stage 0's wall time, answered with instructions

Uncontended, stage 0 read **554 s** (408 s after stone 1, 348–365 s before either). Wall time on this
laptop moves with the machine: native stage 1 went 565–602 → 715 → 794 ms over the same stones while
the native compiler's INSTRUCTIONS moved +0.015% and +0.033%. So the question was settled in
interpreter instructions, which do not depend on machine state — the interpreter compiling one
program, three versions of `compile.wat`, min of 3: **`d49361f` 5,196,256,373 · `3c5cd93` +0.58% ·
this tree +0.72%.** Under one percent of real work. The strike's "noise" was right; it is now shown.
Limit: one small program plus loading the compiler, not all 87.

### Verdict

**Stone 2 lands.** The compiler's types are now checked against the language's on every build, and
the attempt to do so exposed that the language's checker skips most of this corpus (F-196).
