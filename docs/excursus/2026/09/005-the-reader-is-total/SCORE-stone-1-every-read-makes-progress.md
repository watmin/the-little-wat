# SCORE — excursus 005 stone 1: the compiler's reader is total

Scored against `EXPECTATIONS-stone-1-every-read-makes-progress.md`, plus one row the orchestrator
added mid-strike (row 9, the unterminated string). Every number below was measured in this
session, on HEAD `8c789b2` plus this diff. Nothing is committed, and the tree is left dirty.
`WAT=../wat-rs/target/release/wat` throughout. Scratch work lived under the session scratchpad
(`…/scratchpad/s005/`), never in the tree.

The strike ran in two rounds:
- **Round 1:** rows 1–8.
- **Round 2:** the orchestrator's rulings on rows 4, 8 and the `refuses` timeout, plus the new
  row 9.

The numbers below are **round 2's**, taken after row 9's change, with a fresh
`tools/bootstrap.sh` and a fresh full `tools/elf-run.sh`. Where a round-1 number is kept, it is
marked as round 1.

| # | what | verdict |
|---|---|---|
| 1 | stray `)` refused, fast | **MET** |
| 2 | missing `)` refused, naming the opener | **MET** |
| 3 | mismatched closer refused, naming both | **MET** |
| 4 | no corpus byte moves | **MET by ruling.** STOP-1 fired for `elf/out/reader.elf` alone. The orchestrator ruled it legitimate, and the manifest was re-saved for that one line |
| 5 | standing negatives, full elf-run, gates at zero | **MET** — 10 refusals, rules 0, types 0, partial 0 |
| 6 | no-progress unrepresentable; mutant | **MET** — mutants A and B each fail a row |
| 7 | self-hosts | **MET** — fixpoint 281,728 bytes |
| 8 | native compiler on a tree with one extra `)` | **MET by ruling.** It refuses, naming 520:91, in 287 ms at 7,612 KiB peak RSS. The exit is 70, which the orchestrator accepted as the runtime's one stop code |
| 9 | *(added)* unterminated string literal refused, naming where the string opened | **MET** — mutant C fails both of its rows |

---

## Row 1 — the stray `)` is refused, fast — MET

```
$ out=$(timeout -s KILL 120 tools/probe.sh elf/probe/reader-extra-rparen.wat); rc=$?   # timed with date +%s%N
reader-extra-rparen rc=2 1204 ms :: message "compile: cannot read at elf/src/probe.wat 4 41: `)` where a form belongs, and nothing is open for it to close"
```

Line 4 is `  (wat.kernel/println (wat.core/+ 1 2))))`. Column 39 closes the `println`, column 40 the
`defn`, and column 41 is the extra one. (`probe.sh` copies the program to `elf/src/probe.wat`
inside its sandbox, so that is the path it names.) At HEAD the same probe was killed at 120 s
(F-205). Round 1 measured 2,132 ms for this probe.

## Row 2 — the missing `)` is refused — MET

```
reader-missing-rparen rc=2 1153 ms :: message "compile: cannot read at elf/src/probe.wat 3 1: the `(` opened here is never closed -- the file ends first, at elf/src/probe.wat 5 1"
```
The `(` at 3:1 is the `defn`'s opener. 5:1 is the end of the file, just after the last newline.

## Row 3 — a mismatched closer is refused — MET

```
reader-mismatched-closer rc=2 1099 ms :: message "compile: cannot read at elf/src/probe.wat 2 27: `)` cannot close the `[` opened at elf/src/probe.wat 2 26"
```
The message names both delimiters and both places. In `(wat.core/defn user/main [)`, the `[` is
at column 26 and the `)` at column 27.

## Row 4 — no corpus byte moves — MET by ruling (STOP-1 fired, then ruled legitimate)

Baseline, measured before any edit: `emitted: ok -- all 84 programs byte-identical to the manifest`.

**Round 1** stopped here. `tools/emitted.sh check` reported `MOVED: elf/out/reader.elf` (1 of
84). The cause is structural. `elf/src/reader.wat` loads `elf/lib/reader.wat`, the file this
stone changes, and compiles it into its own binary. This is the same reason `emitted.sh`
excludes `compiler.elf`. I captured it and did not work around it.

**The orchestrator's ruling:** legitimate. The manifest was to be re-saved for `reader.elf` only.

`tools/emitted.sh` has two modes, `save` (all programs) and `check`. It has no per-file mode. So
the sequence was: confirm that the other 83 are byte-identical, save all, then show that the
diff is the one line. This was all after round 2's final build:
```
$ tools/emitted.sh check
   MOVED: elf/out/reader.elf
emitted: 1 of 84 programs changed, 0 new
check rc=1                                    <- the other 83 byte-identical

$ timeout -s KILL 20 ./elf/out/reader.elf > rn2.txt;                     echo "native rc=$?"   -> native rc=0
$ timeout -s KILL 120 $WAT elf/src/reader.wat > ri2.txt;                 echo "interp rc=$?"   -> interp rc=0
$ cmp rn2.txt ri2.txt && echo ...
reader.elf output identical to interpreter (24 lines)

$ cp elf/out/.emitted-manifest manifest.before-save; tools/emitted.sh save
emitted: saved 84 programs
$ diff manifest.before-save elf/out/.emitted-manifest
62c62
< cf0a5f9b05639c2d906c42ef0f3e9dcd41b598be0171fb38da2bc0c648c2c97b  elf/out/reader.elf
---
> 515416946b4179252c628f064b3ea28777e54cc85ec4189ae4b3188f3890d5fa  elf/out/reader.elf
$ tools/emitted.sh check
emitted: ok -- all 84 programs byte-identical to the manifest
check rc=0
```
Only the `reader.elf` line changed (9,530 → 9,853 bytes). elf-run's own row also passes:
`reader   agree (exit 0, 9853 bytes native)`. The manifest is gitignored
(`.gitignore:9`), so the re-save is local state and does not appear in the diff.

## Row 5 — standing negatives — MET

```
$ timeout -s KILL 3000 tools/elf-run.sh > elfrun2.log 2>&1; echo "elf-run rc=$?"      (full, with the build)
…
refused elf/bad/unsupported.wat, naming form and place: (wat.core/str 10) at 2:23
refused elf/bad/nonascii.wat, naming the character:  e-acute (F-120: bytes vs chars)
refused elf/bad/arity.wat, naming the call:         (user/two 1 2 3)  (F-128)
refused elf/bad/ptradd.wat, naming the type:        arithmetic on a str  (F-128)
refused elf/probe/variant-param-wrong.wat, naming the call: a None where a Some is wanted (stone 5)
refused elf/probe/reader-extra-rparen.wat, naming the place: a stray `)` at 4:41 (F-205)
refused elf/probe/reader-missing-rparen.wat, naming the opener: the `(` at 3:1 (F-205)
refused elf/probe/reader-mismatched-closer.wat, naming both: `)` at 2:27, `[` at 2:26 (F-205)
refused elf/probe/reader-unterminated-string.wat, naming the string, not the list: 6:23
refused elf/probe/reader-unterminated-string-top.wat, at the top level: 6:1
…
  rules: TOTAL over 127 programs  CArg 11650  CParam 2800  pairs 11650  agree 11585  variant 65  CONFLICT 0  unplaced 0  unjoined 0  mismatch 0
  types: TOTAL over 127 programs  CType 19862  KType 32801  KUnres 0  joined 19575  agree 19575  refined 0  TYPE-CONFLICT 0  partial 0  untranslatable 0  unresolved 0  …
elf-run: ok -- 87 native binaries. 38 agree with the interpreter;
         3 more use syscalls it has no implementation of (F-119); 10 refusals and
         4 traps, both ways. rules: 0 conflicts in 11650 argument-parameter pairs (11585 equal, 65 a variant to its enum) over 127 programs.
         types: 0 type conflicts in 19575 nodes both typed (19575 agree, 0 refined) over 127 programs.
elf-run rc=0
```
There are 10 refusals, where HEAD had 5, and the stale check covers all ten generated drivers.
The rules and types gates are at 0, with `partial 0`. The pair and node counts grew by 18 and 22
over round 1 (11632 → 11650, 19553 → 19575). That is the compiler's own source growing by
`read-ok`'s new arm; `elf/compile.wat` is one of the 127 programs the gates walk. Round 1's full
run was also green: 8 refusals, rules 0, types 0.

**Harness hardening, kept by ruling:** `refuses` in `tools/elf-run.sh` now runs each driver under
`timeout -s KILL 300`. Before, it had no timeout. Mutant B (row 6) shows why this matters: a
regression of exactly this class does not fail, it SPINS, growing memory. Without the timeout
it would have hung `elf-run` forever. With it, the row is killed at 300 s and reported as a
FAIL.

## Row 6 — no-progress is unrepresentable — MET (both mutants fail a row)

Two layers make it unrepresentable, and each mutant removes one of them:

1. **`rd/form` has no arm that can answer without consuming.** It takes the position its caller
   has already skipped to and checked is inside the source, so there is no end-of-input arm.
   Any delimiter that no opener arm handles is refused (`(rd/delim? c)` → `Stray`). That covers
   the closers, which is every delimiter left after `skip`. So the atom arm is reached only by a
   byte that can start an atom.
2. **The atom arm takes its first byte before it looks at the next:**
   `(rd/atom-end src n (+ i 1))`. An atom zero bytes long cannot be made, even if a delimiter
   reaches this arm. For valid input this is identical to the old shape, because the byte at
   `i` is already known not to end an atom.

This was round 1, in scratch copies made with `git archive HEAD` plus the modified files. I
extracted elf-run's exact `refuses` function and reader rows into `rows.sh`, and ran them after
`tools/gen-refuse.sh` in each copy.

**Mutant A** removes layer 1, so a closer reaches the atom arm.
```
FAIL: elf/refuse-rparen.wat did not refuse as expected
      #wat.kernel/AssertionFailure {… :message "compile: only defn, defrecord, defenum, typealias and load-file! at the top level: )" …}
fail=1 refused=3        (6 s)
```
The row fails. Layer 2 still holds: the `)` is read as a **one-byte** atom, so there is no loop.
Something downstream does refuse it, but without naming a place.

**Mutant B** removes both layers, which is HEAD's shape.
```
$ (ulimit -v 4000000; bash rows.sh)
FAIL: elf/refuse-rparen.wat did not refuse as expected
fail=1 refused=3        (304 s)
```
The row fails. The driver spins, as F-205 describes, and is killed by the `refuses` timeout. The
mismatched probe is unaffected by either mutant. `rd/kids-of` meets closers before `rd/form` is
asked, so it is refused in both.

## Row 7 — self-hosts — MET

```
$ timeout -s KILL 3000 tools/bootstrap.sh > bootstrap2.log 2>&1      (no --fast; round 2)
== stage 0: the interpreter runs the compiler ==
   87 binaries in 1136448 ms, the compiler among them (281728 bytes)
== stage 1: the compiler, compiled, runs itself ==
   the same work in 1575 ms -- 721x faster than the interpreter
== every binary, from both ==
   86 binaries, all byte-identical
== the fixpoint ==
   stage1 == stage2, byte for byte (281728 bytes)
   The compiler reproduces itself.
bootstrap: ok
bootstrap rc=0
```
Round 1's bootstrap was also a fixpoint, at 281,357 bytes. Row 9's new arm and variant add 371.

## Row 8 — the native compiler too — MET by ruling

The scratch copy is `s005/row8b`: `git archive HEAD` plus round 2's `elf/compile.wat` and
`elf/lib/reader.wat`. It has one extra `)` at the end of `:c::fail` in its `elf/compile.wat`, on
line 520. The compiler run is round 2's fixpoint `elf/out/compiler.elf`, copied out before
elf-run rebuilt `elf/out`. The peak-RSS wrapper was built with
`gcc -O2 -o s005/mrss elf/bench/maxrss.c`.

```
$ cd s005/row8b; timeout -s KILL 300 s005/mrss s005/compiler-fix2.elf > row8b-rss.txt 2> row8b.err; rc=$?
mrss rc=70 287 ms peakRSS_KiB=7612
stderr: compile: cannot read at elf/compile.wat 520 91: `)` where a form belongs, and nothing is open for it to close
```
Round 1 got the same result: rc 70, 308 ms, 7,316 KiB, the same message.

The compiler refuses at once and names the line and column. F-205 recorded HEAD running the heap
out on the same kind of input (1,855,560 KB, exit 70). I did not re-measure HEAD in this session.

**On the exit code, as ruled:** 70 is the runtime's **one** stop code, by design.
`elf/lib/runtime.wat:1698` defines `(:c::exit-fail [] -> … 70)`, and it is shared by overflow,
division by zero, heap exhaustion and `assertion-failed!`. So every refusal the native compiler
makes exits 70. The code cannot tell a refusal from heap exhaustion; the refusal naming its
place is what does, and that is the point of this row. The expectation's "not exit 70" assumed
a distinction the runtime does not make. The orchestrator accepted the row on that basis.

## Row 9 (added) — an unterminated string literal is refused, naming where it opened — MET

The finding, from round 1's note and measured by the orchestrator: `rd/str-end` answered end of
input as the string's end. At the top level, `"abc` read as a complete string. Inside a list,
the refusal blamed the unclosed `(` instead of the string. A trailing `\` answered one byte
**past** the end.

The fix:
- `rd/str-end` answers **-1** when the source ends first. The trailing-backslash case falls into
  the same arm on its next step.
- `rd/form`'s string arm turns -1 into `rd/stop … :rd::Fault.Unterminated` (a new variant), with
  `pos` at the end of input and `open` at the opening quote.
- `:c::read-ok`'s `match` gains the fifth arm. It still has no catch-all.

The refusal says what wat says, "unterminated string literal", and names where the string
opened.

This is two probe files, not one. The first unterminated string swallows the rest of its file,
so one file cannot show both shapes.
```
$ timeout -s KILL 60 $WAT elf/probe/reader-unterminated-string.wat       -> #wat.parse/Lex … "unterminated string literal"
$ timeout -s KILL 60 $WAT elf/probe/reader-unterminated-string-top.wat   -> #wat.parse/Lex … "unterminated string literal"

reader-unterminated-string rc=2 1031 ms :: message "compile: cannot read at elf/src/probe.wat 6 23: unterminated string literal -- the string opened here is never closed, and the file ends first, at elf/src/probe.wat 7 1"
reader-unterminated-string-top rc=2 1059 ms :: message "compile: cannot read at elf/src/probe.wat 6 1: unterminated string literal -- the string opened here is never closed, and the file ends first, at elf/src/probe.wat 7 1"
```
In `  (wat.kernel/println "abc))`, the quote is at column 23. It is now blamed, not the `(`.

A trailing backslash, tried once in scratch and not kept as a probe (`…println "ab\` at end of file):
```
message "compile: cannot read at elf/src/probe.wat 2 23: unterminated string literal -- the string opened here is never closed, and the file ends first, at elf/src/probe.wat 2 27"
```

**Standing negatives:** `elf/refuse-unterm.wat` and `elf/refuse-unterm-top.wat`, generated by
`tools/gen-refuse.sh`, with two `refuses` rows in `tools/elf-run.sh`. Both pass in the round-2
full run (row 5).

**Mutant C**, in a scratch copy: `rd/str-end` answers `i` again at end of input.
```
FAIL: elf/refuse-unterm.wat did not refuse as expected
FAIL: elf/refuse-unterm-top.wat did not refuse as expected
fail=1 refused=5
  (inside a list)  "compile: cannot read at elf/probe/reader-unterminated-string.wat 6 3: the `(` opened here is never closed -- …"
  (top level)      "compile: only defn, defrecord, defenum, typealias and load-file! at the top level: \"
```
Both rows fail, each with the pre-fix symptom.

**The message has no quote character in it on purpose.** A literal compiles as its SOURCE TEXT
(F-120). So `\"` inside the message would print as one character when the compiler is
interpreted and as two when it is native, and the two compilers' refusals would differ. The
message says "the string opened here" instead.

---

## The diff's shape

`elf/lib/reader.wat`
- **new `:rd::Fault`** (Pure enum: `Clean`, `Stray`, `Unclosed`, `Mismatched`, `Unterminated`),
  and two new `:rd::St` fields: `fault` and `open` (where the enclosing list or string began, or
  -1). The reader stays a library a compiled program shares, so a refusal is a **value** it hands
  back and not a panic. A faulted state's `pos` is the byte it stopped at.
- **`rd/form`** now takes `(src n a i)`, where `i` is already skipped and inside the source, in
  place of a whole state. The EOF arm is gone. `(rd/delim? c)` → `Stray`. The atom arm starts
  `atom-end` at `i+1`. The string arm refuses `Unterminated` when `str-end` answers -1.
- **`rd/str-end`**: end of input answers -1, not `i`.
- **`rd/kids-of`** gains `open`. EOF → `Unclosed`. Its own closer → close. Any other closer
  (`rd/closer?`, new: `")]}"`) → `Mismatched`. A faulted child stops the loop and is returned.
- **`rd/seq`** passes `i` as `open` and returns a fault unchanged. **`rd/tops`** stops on a
  fault. **`rd/add`** and **`rd/read-into`** fill the new fields.
- new helpers: `rd/stop` builds a faulted state, and `rd/ok?` tests for `Clean`.

`elf/compile.wat`
- **`:c::loc-in`**'s formatting was split out as **`:c::loc-say`** (a packed position → "file
  line col"). `loc-in` now calls it, and what it produces is unchanged.
- **`:c::byte-loc`**: byte offset → packed position, via `:c::loc-adv` and `:c::loc-pack`,
  starting from the same `LocW` that `:c::loc-files` uses. This is the one way positions are
  computed, reused rather than written again, so STOP-2 did not fire.
- **`:c::delim-at`**: the delimiter at a byte, quoted.
- **`:c::read-ok`**: a `match` over `:rd::Fault` with all five arms and no catch-all. `Clean`
  answers `pg` unchanged. Each of the other four is an `assertion-failed!`, a compile-time
  refusal in the `compile: cannot … at <file> <line> <col>: …` form the type pass uses.
- **`:c::compile-as`** and **`:c::collect-in`**'s `load-file!` arm bind the file text and pass
  the state through `read-ok`. This happens after the file's `Src` is appended, so it is the last
  entry in `srcs`, and before anything walks the tree.

`tools/gen-refuse.sh`: five new drivers (`elf/refuse-rparen.wat`, `refuse-unclosed.wat`,
`refuse-mismatch.wat`, `refuse-unterm.wat`, `refuse-unterm-top.wat`), all new files. All ten
drivers were regenerated.
`tools/elf-run.sh`: the five drivers are added to the stale check, plus five `refuses` rows whose
needles are the exact messages with their positions. `refuses` now runs under
`timeout -s KILL 300`.
`elf/probe/`: two new probes, `reader-unterminated-string.wat` and
`reader-unterminated-string-top.wat`. `README.md` has rows for all five reader probes.

## Surprises and notes

- **STOP-1 was predictable from the brief itself.** `elf/src/reader.wat` compiles the file the
  brief orders changed. It fired, was captured, and was ruled legitimate (row 4).
- **Row 8's exit code:** every native refusal exits 70, as ruled (row 8).
- **F-120 shaped row 9's message:** a `\"` in a compiler message would differ between the
  interpreted and native compiler (row 9).
- **The trailing backslash** answered one byte past the end of the source. It is closed by the
  same arm as row 9.
- **Scratchpad mishap (round 1):** my first `git archive` extraction went into `scratchpad/mut`,
  which already existed from earlier work in this session (with a 1.9 GB `target/`). HEAD's files
  were written over whatever was there. My first bootstrap log also overwrote an existing
  `scratchpad/bootstrap.log`. All later work used a fresh `scratchpad/s005/`. Nothing in the tree
  was affected.
- Untracked files not mine (from the concurrent 004 work) are in the tree and were left alone:
  `docs/excursus/2026/09/004-…/SCORE-stone-1-step-user-code.md`, `WEIGH-stone-1-refuted.md`,
  `probes/eval-step-captures-rec-enum-fn.wat`.
