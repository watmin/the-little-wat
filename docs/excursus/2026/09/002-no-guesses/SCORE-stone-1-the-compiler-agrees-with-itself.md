# SCORE — excursus 002 stone 1: the compiler must agree with itself at every boundary

Struck 2026-09-23 on `main` at `ad6768f`. Tree left dirty, nothing committed. Every number below
was measured in this session; output is pasted as printed.

## What was built

| piece | where | what |
|---|---|---|
| positions | `elf/compile.wat` `:c::with-locs`, `:c::loc-*` | where each arena node starts, in wat-grep's convention |
| the export | `:c::compile-as src out exp?`, `:c::fact-args`, `:c::fact-params`, `:c::fact-files` | `CArg`, `CParam` and `FILE` lines, printed in pass two only, and only when asked |
| the checker | `tools/rules/check.wat` | runs under wat-rs. Each program is one fact base: wat-grep's facts for every file it was read from, plus the compiler's lines, through `with-overlay`. 8 rules |
| the runner | `tools/rules.sh [prog ...]` | builds a native exporter, exports each program in its own process and runs the checker. Report mode |
| report mode | `tools/elf-run.sh` | runs `tools/rules.sh`, prints the findings and the count, and fails only when the check could not be made |

### Positions — how they were made to agree (STOP-4 did not fire)

**`:rd::Node` is NOT changed. This departs from the BRIEF's step 1, and here is why.** The BRIEF
said the reader should carry each node's start. But `elf/src/reader.wat` `load-file!`s
`elf/lib/reader.wat` and compiles it into a program of its own. Any change to the reader's
records or functions therefore moves `elf/out/reader.elf`, and that fails row 2. So positions are
recovered after reading, only when the export is on, by a walk over the arena that already
exists:
- it skips whitespace and comments with the reader's own `rd/skip`;
- it takes each node's start, and gets its end from the byte length of its text;
- it steps into a list, vector or map one byte past the start, the way `rd/kids-of` does;
- it appends positions in post-order, which is the reader's numbering order.

**Each position is checked, not assumed.** The compile stops on either failure:
- the node's text must equal the source bytes at the position found;
- the positions must come out exactly in the reader's node order.

A program's files are recorded as they are read (`:c::Src`: path, arena base, top-level forms).
A loaded file must start where the previous one ended.

Columns count characters, so UTF-8 continuation bytes are skipped. Each position is packed as
file, line and column in one i64.

**Nodes the inliner makes inherit a position.** `:c::mknode` gained an `org` argument. A copy of
node `a` stands at `a`'s position, and a node the inliner makes up (temporaries, the binding
vector, the `let` word) gets -1. This matters: `option.wat`'s conflict below sits on a call that
was rebuilt around an inlined argument, and without the inherited position it could not be
placed.

### The export — where the types come from
- **`CArg`** is printed at the call dispatch in `:c::form`, just before `:c::call-user`. For each
  argument it prints `(:c::type-of arg env pg)`, in the environment the call is compiled in. It
  also prints the callee, and `in`: the function whose body was being compiled.
- **`CParam`** is printed in `:c::compile-fn`. It prints `(:c::Bind/ty (nth env i))` from the
  same `env` the body is compiled in, positioned at the parameter's name.
- **Printed in pass two only.** A form compiled twice prints the same line twice. The runner
  de-duplicates within a program (`awk '!seen[$0]++'`).
- **A normal build prints nothing new.** `:c::compile` is `(:c::compile-as src out false)`.
  `locs` stays empty and `track`/`exp` stay false.

### The native exporter
The interpreter-driven export costs what stage 0 costs: 9m42s for the corpus on this machine, and
17m40s for the compiler alone. So `tools/rules.sh` builds the exporter natively, the way
`bootstrap.sh --fast` does:
1. It writes `elf/compile.wat` with its `:user::main` replaced. The new main compiles the one
   program named in `$BOX/prog`, twice: export on, then export off.
2. It runs `elf/out/compiler.elf` in a sandbox whose `elf/compile.wat` is that driver. What that
   run writes to the sandbox's `elf/out/compiler.elf` is the exporter.

`RULES_INTERP=1` runs the same driver through the interpreter instead.

---

## Row 1 ⛔ — it sees F-194 — **MET**

```
$ tools/rules.sh elf/probe/penum-str-let.wat
rules: exporter built natively in 801 ms
rules: exported 1 programs in 23 ms (0 refused by the compiler); export-on == export-off for 1 of 1; 0 corpus binaries byte-identical to elf/out, 0 not
  boundary-type-conflict  elf/probe/penum-str-let.wat:13:20  call=user/slen  in=user/main  arg=0  arg-type=henum::user::S  param-type=penum::user::S  param-at=elf/probe/penum-str-let.wat:8
rules: elf/probe/penum-str-let.wat  CArg 1  CParam 1  pairs 1  agree 0  CONFLICT 1  unplaced 0  unjoined 0  mismatch 0
rules: TOTAL over 1 programs  CArg 1  CParam 1  pairs 1  agree 0  CONFLICT 1  unplaced 0  unjoined 0  mismatch 0
rules: checked in 773 ms; total 1634 ms
```

The facts that produce it, exactly as the compiler printed them:

```
"CParam elf/probe/penum-str-let.wat 8 27 0 user/slen penum::user::S"
"CArg elf/probe/penum-str-let.wat 13 20 0 user/slen user/main henum::user::S"
```

The type strings are the compiler's own spelling, `penum:` followed by `:user::S`. The rete
experiment in `rete/` printed wat-grep's spelling, `penum:user/S`. Both describe the same
disagreement.

## Row 2 ⛔ — nothing emitted moved — **MET**

After the full bootstrap, and again after `tools/elf-run.sh` rebuilt everything through the
interpreter:

```
$ tools/emitted.sh check
emitted: ok -- all 84 programs byte-identical to the manifest
```

The manifest was checked before any edit, against a fresh stage-0 build of HEAD:
`emitted: ok -- all 84 programs byte-identical to the manifest`. The only binary that changed is
the compiler's own: 254,849 B became 260,632 B.

The export is also checked per program. Each of the 98 exported programs was compiled with the
export on and with it off, and the binaries were compared:
`export-on == export-off for 98 of 98; 76 corpus binaries byte-identical to elf/out, 0 not`.

## Row 3 ⛔ — non-vacuous — **MET**

Corpus (all 76 programs in the driver, the compiler included) plus `elf/probe/` (22 of 23; see
row 5 for the refusal):

```
rules: TOTAL over 98 programs  CArg 10286  CParam 2395  pairs 10286  agree 10280  CONFLICT 6  unplaced 0  unjoined 0  mismatch 0
```

**10,286 argument→parameter pairs checked, 10,280 agree.** Every `CArg` reached a parameter:
pairs equals CArg. The compiler alone accounts for 9,148 pairs.

The zero counts can fire. Each mutant below changes ONE fact line in the facts of
`penum-str-let` + `four` + `reader` (188 CArg). The unmutated run: `pairs 188 agree 187 CONFLICT 1`.

| mutant | result |
|---|---|
| a CArg's column + 1 | `carg-unplaced elf/src/reader.wat:12:45` — `unplaced 1` |
| a CParam's column + 1 | `cparam-unplaced elf/src/../lib/reader.wat:52:33`, and its call becomes `arg-unjoined` (cross-file) |
| a CArg's callee renamed | `callee-mismatch elf/src/reader.wat:12:44 call=rd/indentX defn=rd/indent` |
| a CArg's index + 7 | `carg-unplaced ... arg=7` |
| a CArg's type + `Z` | `boundary-type-conflict ... arg-type=i64Z param-type=i64` — `CONFLICT 2` |

## Row 4 ⛔ — the join is exact — **MET**

`unplaced 0` over all 98 programs. That covers both directions:
- every `CArg` position is a wat-grep List node starting there, with an argument at that index;
- every `CParam` position is parameter i's name in a `defn`'s parameter vector.

Also 0 `"CArg ? 0 0"` lines: no call sat on a node without a position (counted in the compiler's
own facts).

`arg-unjoined 0` means every head names a `defn`, found by wat-grep's spelling. `mismatch 0`
means that `defn` is the one the compiler said it called.

**The export works in stage 0 as well as natively.** The interpreter-driven exporter
(`RULES_INTERP=1`) and the native one printed byte-identical fact streams:
- 31 programs (22 probes plus `reader fileio asmbits option enums shapes fnref logic fib32`):
  848 fact lines, identical;
- the compiler itself: 11,037 lines, identical. The interpreted run took 17m40s; the native one
  1.7 s.

## Row 5 — the census of conflicts — **6, all listed, none fixed**

```
boundary-type-conflict  elf/src/option.wat:23:25  call=user/showi  in=user/main  arg=0  arg-type=henum::user::Opt  param-type=henum::user::Opt;i64  param-at=elf/src/option.wat:11
boundary-type-conflict  elf/src/option.wat:24:25  call=user/showi  in=user/main  arg=0  arg-type=henum::user::Opt  param-type=henum::user::Opt;i64  param-at=elf/src/option.wat:11
boundary-type-conflict  elf/compile.wat:3173:24  call=:c::emit  in=:c::read-out  arg=0  arg-type=i64  param-type=rec::c::Out  param-at=elf/compile.wat:287
boundary-type-conflict  elf/probe/penum-spelled-henum.wat:20:20  call=user/poke  in=user/main  arg=1  arg-type=henum::user::O  param-type=penum::user::O  param-at=elf/probe/penum-spelled-henum.wat:12
boundary-type-conflict  elf/probe/penum-spelled-henum.wat:22:25  call=user/len  in=user/main  arg=0  arg-type=henum::user::O  param-type=penum::user::O  param-at=elf/probe/penum-spelled-henum.wat:9
boundary-type-conflict  elf/probe/penum-str-let.wat:13:20  call=user/slen  in=user/main  arg=0  arg-type=henum::user::S  param-type=penum::user::S  param-at=elf/probe/penum-str-let.wat:8
```

| # | site | what the compiler did (read from its source; not fixed) |
|---|---|---|
| 1 | `penum-str-let.wat:13:20` | **F-194.** `:c::type-of-form`'s variant arm spells a constructor by the heap flag alone, `henum:`. The `let` binding takes that spelling; the parameter is `penum:` by tier. |
| 2–3 | `penum-spelled-henum.wat:20:20`, `:22:25` | The same arm, for a tier-1 enum over a Vector alias. Both uses of the `let`-bound `o` disagree. |
| 4–5 | `option.wat:23:25`, `:24:25` | **The other half of that arm: it drops `;arg`.** `(user/showi (user/pick 7))`: `user/pick` is inlined, so the argument becomes a `let` whose value is the `if`'s consequent, a constructor. The argument is typed `henum::user::Opt`; the parameter is `henum::user::Opt;i64`. `user/shows (user/name 1)` agrees because `user/name` is not inlined (its body has a String literal), so its declared return type is used. **The argument's type depends on whether the inliner fired.** |
| 6 | `compile.wat:3173:24` | In the compiler itself, `:c::read-out` binds `lo` to a `match` form. `:c::type-of-form` has no `match` arm, and its `:else` answers `"i64"`. That is one of the six `"i64"` fallbacks the DESIGN lists. So `lo`, an `:c::Out` record, is passed to `:c::emit` typed `i64`. |

One refusal, not a conflict: `elf/probe/nth-record.wat` is refused by the compiler (`nth: operand
is not a Vector`), as stone 0a intended. So there are no facts for it.

## Row 6 — the rules derive no type — **MET**

`tools/rules/check.wat` has 8 rules:
- `a-arg`, `b-param`: joins;
- `z-conflict`, `z-agree`: the constraint and its witness;
- `y-carg-unplaced`, `y-cparam-unplaced`, `y-arg-unjoined`, `y-callee-mismatch`: the join's own
  honesty.

Every type-bearing variable in the file:

```
59:                    (?callee <- :callee) (?in <- :in) (?t <- :ty))          ;; from CArg
68:  :then [(:ck::Arg ... :ty ?t ...)])                                         ;; copied
73:  :when [(:ck::CParam ... (?t <- :ty))                                        ;; from CParam
88:  :then [(:ck::Param ... :ty ?t ...)])                                       ;; copied
92/94/95:  ?at, ?pt from Arg/Param; (:wat::rete::string::not= ?at ?pt)
108/110/111: the same, with string::=
```

Types enter only through `CArg`/`CParam` and are only copied or compared for equality. No rule
builds, concatenates or looks up a type. The rules supply exactly the syntactic join:
- the call at line:col has a List head naming F;
- F is a `defn` whose parameter vector's element 3i is the parameter the compiler positioned;
- argument i feeds parameter i.

## Row 7 — report mode — **MET**

`tools/elf-run.sh`, full (it rebuilds through the interpreter), 10m36s:

```
== the compiler agrees with itself at every boundary: tools/rules.sh (report mode) ==
  rules: exporter built natively in 748 ms
    refused  elf/probe/nth-record.wat  (compile: cannot compile nth: operand is not a Vector: (wat.core/nth (:user::P :a 7 :b 9) 0))
  rules: exported 98 programs in 3522 ms (1 refused by the compiler); export-on == export-off for 98 of 98; 76 corpus binaries byte-identical to elf/out, 0 not
    ... the six conflicts of row 5 ...
  rules: TOTAL over 98 programs  CArg 10286  CParam 2395  pairs 10286  agree 10280  CONFLICT 6  unplaced 0  unjoined 0  mismatch 0
  rules: checked in 22688 ms; total 26999 ms

elf-run: ok -- 87 native binaries. 38 agree with the interpreter;
         3 more use syscalls it has no implementation of (F-119); 4 refusals and
         4 traps, both ways. rules: 6 conflicts in 10286 argument-parameter pairs over 98 programs.
```

A conflict does not fail the run. The run DOES fail (`fail=1`) if `tools/rules.sh` exits
non-zero, which happens when:
- the exporter did not build;
- the checker died;
- the export moved an emitted byte.

## Row 8 — self-hosts — **MET**

`tools/bootstrap.sh`, full, not `--fast`:

```
== stage 0: the interpreter runs the compiler ==
   87 binaries in 527680 ms, the compiler among them (260632 bytes)
== stage 1: the compiler, compiled, runs itself ==
   the same work in 812 ms -- 649x faster than the interpreter
== every binary, from both ==
   86 binaries, all byte-identical
== the fixpoint ==
   stage1 == stage2, byte for byte (260632 bytes)
   The compiler reproduces itself.
bootstrap: ok
```

`elf/refuse*.wat` were regenerated by bootstrap (`gen-refuse.sh`). That is why they show in the
diff.

## Row 9 — cost — **27.0 s for the corpus plus probes**

| step | wall |
|---|---|
| build the native exporter | 748–1058 ms |
| export 98 programs, two compiles each, one process each | 3.5–4.5 s |
| the rete check (wat-rs, 98 fact bases) | 22.7–31.0 s (25.0 s of that is `compile.wat` alone) |
| **total** `tools/rules.sh` | **27.0 s** inside `elf-run`; 36.5 s on the first run |

The check is dominated by wat-grep plus rete on `elf/compile.wat` (6,200 lines plus its four
libraries). An interpreter-driven export would cost 9m42s or more instead of 4 s.

The compiler's own cost, for a NORMAL build (`tools/cc-time.sh`, best of 14, interleaved):

```
compiler-head.elf        674 ms (best of 14)   2309696897 instructions
compiler.elf             688 ms (best of 14)   2310033908 instructions
```

That is +0.015% instructions, and the new compiler is also compiling its own larger source.

---

## What fought back

- **The BRIEF's step 1 conflicts with row 2.** A field on `:rd::Node` moves `reader.elf`. It was
  resolved by recovering positions after reading, under two checks (text at position, and reader
  order) that stop the compile on any disagreement. STOP-4 never fired: 0 unplaced.
- **The inliner makes nodes.** Before `org` was added, a call rebuilt around an inlined argument
  had no source position. `option.wat`'s two conflicts are exactly such calls.
- **The interpreter is too slow to be the exporter** (9m42s corpus, 17m40s compiler). Solved by
  building the exporter with the native compiler in a sandbox. That relies on `compiler.elf`
  compiling `"elf/compile.wat"` to `"elf/out/compiler.elf"` relative to the directory it runs in.
- **A refusal kills a whole-corpus process.** `nth-record.wat` is refused by design, so the export
  runs one process per program.
- **Rete's string ops.** `string::concat` takes exactly 2 arguments: arity 3 fails at runtime with
  `compiled apply cannot dispatch kind StrConcat arity 3`. An i64 needs `i64::to-string` first:
  `concat "" ?i` fails the same way at arity 2.
- **wat-grep numbers every file's nodes from 1.** A program of several files (the compiler has
  five) needs ids moved apart, plus an `At` fact that carries the file.

## Files

- `elf/compile.wat` (+255/−24): `:c::Src`; the Prog fields `srcs locs track exp cur`;
  `:c::compile-as`; the position walk; the three `fact-*` printers; `mknode`'s `org`.
- `elf/refuse*.wat`: regenerated by bootstrap.
- `tools/rules.sh`, `tools/rules/check.wat`: new.
- `tools/elf-run.sh`: the report-mode section, and the count in the summary.

---

## ORCHESTRATOR — the kill, weighed against my own re-run (2026-09-23)

| claim | my re-run | verdict |
|---|---|---|
| the rules derive no type | read `tools/rules/check.wat`: 8 rules; types enter only as `?t` from `CArg`/`CParam` and are only compared (`string::=`, `string::not=`); the one `concat` builds a report label | **confirmed** |
| it sees F-194 | `tools/rules.sh elf/probe/penum-str-let.wat`: conflict at **13:20**, `user/slen`, `henum::user::S` vs `penum::user::S`, in 1.5 s | **confirmed** |
| the census | `tools/rules.sh` (all): 98 programs, 10,286 pairs, **10,280 agree, 6 conflicts**, 0 unplaced / unjoined / mismatch, export-on == export-off 98/98, 26.3 s | **confirmed exactly** |
| nothing emitted moved | HEAD built independently from `git archive`, proved at its own fixpoint (254,849 B); **75 corpus programs byte-identical to the new compiler's, 0 moved** | **confirmed**, independently of the strike's manifest |
| self-hosts | full bootstrap, uncontended: `bootstrap: ok` | **confirmed** |
| report mode | `tools/elf-run.sh`: `ok`, `rules: 8 conflicts in 10288 … over 99 programs` (the 6, plus F-195's probe's 2) | **confirmed** |

### The deviation, accepted

Positions are recovered after reading rather than stored in `:rd::Node`, because `elf/src/reader.wat`
compiles the reader into a corpus program and any change to it moves `reader.elf` (row 2). The
recovery is checked twice per node (its text equals the source bytes there; positions arrive in the
reader's order) and stops the compile on either failure. Unplaced: 0. Sound, and the honest trade
for a stone whose second gate was "move nothing".

### An honest delta — stage 0 is slower

Uncontended, bootstrap stage 0 took **408,364 ms** against a steady **348–365 s** across nine runs
this session: **+12–15% on the dev-loop gate**, while the native compile moved +0.015% instructions.
The export is off in a normal build, so this is the interpreter processing the larger compiler (the
inliner's new `org` argument is the likeliest carrier). Recorded, not chased here.

### What the checker found that nobody knew — F-195

Its report on the compiler's own source, `elf/compile.wat:3173:24` (`lo` bound to a `match`, typed
`i64` against `rec::c::Out`), is harmless at that site. The CLASS is not: written from that report,
`elf/probe/match-i64.wat` -- a valid program -- answers `4 | 5` natively against the interpreter's
`4 | 4`, a silent wrong answer on `main`, and the checker flags both calls before it runs.

### Verdict

**Stone 1 lands.** The first structural checker is in the gate, in report mode, and on its first
run it confirmed a known bug and led straight to an unknown one.
