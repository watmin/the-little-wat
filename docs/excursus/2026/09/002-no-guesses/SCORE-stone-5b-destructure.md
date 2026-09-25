# SCORE — excursus 002 stone 5b: destructure an aggregate by its field names

Struck on `main` at `183f111`, tree left dirty, nothing committed. wat-rs was not touched.
Every number below was measured in this session.

**Verdict.** All nine rows are MET. No STOP fired.

- A variant destructures and agrees, `3|3|0`.
- A record destructures and agrees, `39`.
- The parent enum is a compile-time refusal, and the message names `{:keys [value]}`.
- `tools/reads.sh` is `reads: ok`. Every field load goes through `:c::read-out`. Tier 1 aliases the subject, which is what `:c::arm-binds` already does: the payload is the value, so there is no field to read out.
- `elf-run`: `rules: 0 conflicts`, `types: 0 type conflicts`, `refined 0`, `elf-run: ok`.
- No corpus program moved. 84 of 84 binaries match the manifest.
- Bootstrap is a byte-identical fixpoint, compiler 290,741 bytes.
- Every `*-borrow.wat`, `*-shadow.wat`, and `elf/src/borrowed.wat` still agrees.
- The compiler binary grew 5,264 bytes. Compiling the corpus costs +1,208,630 instructions, +0.0445%.

## What was built

`{:keys [f g]}` on a `let` binding. The pattern is a map whose first entry is the keyword `:keys` and whose second is a vector of names. The initialiser must be a variant type or a record. The parent enum (`penum::user::Opt;str`, whose name is the enum's own) is refused. A free `T` is refused, for the same reason a `match` on one is: the tier would be a guess.

| piece | where (`elf/compile.wat`) | what |
|---|---|---|
| pattern | `:c::keys?` :4326 | the map shape |
| classification | `:c::agg-of` :4361 | record via `:c::rec-name-of`, variant via `:c::ty-enum` / `:c::variant-tag`, parent and free `T` refused |
| the one type | `:c::key-ty` :4389 | the field's declared type: `:c::arm-ftys` or `:c::Rec/ftypes`. `:c::ty-bind1` :1779 and `:c::keys-each` both call it |
| the load | `:c::keys-each` :4414 | tier 1 aliases the subject slot. Every other field is `:c::read-out` of `:c::Read.At`, at the displacement `:c::arm-binds` uses (a record has no tag slot, so its displacement is `8+8*fi`) |
| slots | `:c::bind-slots` :4345 | the subject, plus one slot per name. `:c::self-slots` asks this instead of counting pairs |

`git diff --stat`: `elf/compile.wat` +160/−7. Bootstrap regenerated the five `elf/refuse*.wat` copies of it. Nothing else is dirty.

## Row 1 ⛔ — a variant destructures — **MET**

```
$ tools/probe.sh elf/probe/destructure-variant.wat
destructure-variant: agree   [3|3|0]
```

`(:user::Opt.Some :- [String])` is tier 1: the string is the value. `value` is bound to the subject slot. No field load, no second type.

## Row 2 ⛔ — a record destructures — **MET**

```
$ tools/probe.sh elf/probe/destructure-record.wat
destructure-record: agree   [39]
```

`name` is a String and is counted by `:c::read-out`. `age` is `i64`, which `:c::word-ty?` leaves uncounted. `39` is `length("ada") + 36`.

## Row 3 ⛔ — the parent is refused — **MET**

```
$ tools/probe.sh elf/probe/destructure-parent.wat
destructure-parent: COMPILE-FAILED  … compile: cannot type a keys-destructure of a value that is not an aggregate -- a variant or a record at elf/src/probe.wat 8 18: {:keys [value]}
```

Exit 2 from `probe.sh`, which is its compile-failure code. The form in the message is the destructure.

## Row 4 ⛔ — every field read counted — **MET**

```
$ tools/reads.sh
reads: ok -- every read out of a container goes through :c::read-out (lines 3816-3843)
```

The new load is a `:c::Read.At` argument of `:c::read-out`. No new heap-load spelling, no new runtime entry.

## Row 5 ⛔ — both gates at zero — **MET**

`SKIP_BUILD=1 tools/elf-run.sh` on the fixpoint binaries (bootstrap had just written them; the script's own note is that rebuilding those bytes proves nothing). The differentials and both gates still ran. Exit 0.

```
elf-run: ok -- 87 native binaries. 38 agree with the interpreter;
         3 more use syscalls it has no implementation of (F-119); 5 refusals and
         4 traps, both ways. rules: 0 conflicts in 11360 argument-parameter pairs (11316 equal, 44 a variant to its enum) over 104 programs.
         types: 0 type conflicts in 18931 nodes both typed (18931 agree, 0 refined) over 104 programs.
```

The two destructure probes alone, `tools/rules.sh`:

```
rules: TOTAL over 2 programs  CArg 4  CParam 3  pairs 4  agree 2  variant 2  CONFLICT 0  unplaced 0  unjoined 0  mismatch 0
types: TOTAL over 2 programs  CType 18  KType 37  KUnres 0  joined 18  agree 18  refined 0  TYPE-CONFLICT 0  partial 0  untranslatable 0  unresolved 0  checker-multi 0  compiler-multi 0  compiler-only 0  checker-only 19
```

`checker-multi` on the whole run is 24. One of them is new: `:c::agg-fail` at `elf/compile.wat:4354`, declared `:c::Agg`, body `assertion-failed!`, which the checker types as an Option of String. That is the same shape as `:c::env-fail`. It is not a type conflict, and the row's bar is conflicts, refined, and `elf-run: ok`.

## Row 6 — nothing else moved — **MET**

```
$ tools/emitted.sh check
emitted: ok -- all 84 programs byte-identical to the manifest
```

## Row 7 — self-hosts — **MET**

`tools/bootstrap.sh` with no `--fast`:

```
== stage 0: the interpreter runs the compiler ==
   87 binaries in 433534 ms, the compiler among them (290741 bytes)
== stage 1: the compiler, compiled, runs itself ==
   the same work in 717 ms -- 604x faster than the interpreter
== every binary, from both ==
   86 binaries, all byte-identical
== the fixpoint ==
   stage1 == stage2, byte for byte (290741 bytes)
   The compiler reproduces itself.
bootstrap: ok
```

## Row 8 — F-188 stays closed — **MET**

```
callrel-borrow: agree   [30|240000|3|1|30]
field-borrow: agree   [5|5|4]
str-borrow: agree   [4|"ab1"|3]
tier1-borrow: agree   [4|3]
check-param-shadow: agree   [4]
field-shadow: agree   [5|4]
match-shadow: agree   [5|4]
own-shadow: agree   [30|3|30]
share-shadow: agree   ["z2z1!z2!"]
str-shadow: agree   [4|"ab1"|3]
borrowed: agree   [4|3|4|3|4|"ab1"|4|"ab1"|5|4|5|4|5|4]
```

## Row 9 — cost — **MET**

Compiler size, the fixpoint against the binary copied before the edit (`/tmp/compiler-before-5b.elf`, 285,477 bytes):

| | bytes |
|---|---|
| before | 285,477 |
| after | 290,741 |
| delta | +5,264 (+1.84%) |

Native instructions compiling the corpus, both binaries on this tree, `tools/cc-time.sh`, `taskset -c 2`, `cpu_core/instructions`:

```
  compiler-before-5b.elf   683 ms (best of 14)   2713226521 instructions
  compiler.elf             688 ms (best of 14)   2714435151 instructions
```

+1,208,630 instructions, +0.0445%. The corpus has no `{:keys}`, so this is the cost of asking the question on every `let` binding. The 5 ms on the best-of-14 wall time is inside the noise of that sample.

---

## ORCHESTRATOR — the kill, weighed against my own re-run (2026-09-24)

First strike by **Grok** as shadowdancer, via pulsare. Weighed exactly as the Opus strikes were.

| claim | my re-run | verdict |
|---|---|---|
| rows 1–3 | `tools/probe.sh`: `destructure-variant` agree `3\|3\|0`; `destructure-record` agree `39`; `destructure-parent` COMPILE-FAILED, *"cannot type a keys-destructure of a value that is not an aggregate"* | **confirmed** |
| F-188 through the new read | **my own adversarial probe**, `elf/probe/keys-borrow.wat`: a Vector destructured out of a record, grown by a callee's in-place `conj`, the record read again → interp `4 3`, **native agree `4\|3`** | **confirmed** — the destructured read is counted |
| the tier-1 alias is safe | **my own second probe**, `elf/probe/keys-tier1-alias.wat`: a `Some` of a Vector, its payload destructured and grown by a callee, the `Some` read again → interp `43`, **native agree `43`** | **confirmed** — passing the alias shares it, so the callee copies |
| emission | HEAD built from `git archive`, proved at its fixpoint (285,477 B): **75 of 75 identical, none moved** | **confirmed** |
| self-hosts | full bootstrap, `stage1 == stage2` at 290,741 B | **confirmed** |
| gates | a FULL `tools/elf-run.sh` (the strike ran `SKIP_BUILD=1`): `rules: 0 in 11363 pairs (44 variant-to-enum)` · `types: 0 in 18955 nodes, 0 refined` · 106 programs · `elf-run: ok` | **confirmed** |

The strike's own discipline was sound throughout: it reported the `SKIP_BUILD` choice and why, named
its one new `checker-multi` and why it is not a conflict, and touched only `elf/compile.wat`.

### Verdict

**Stone 5b lands.** The builder's own shape — `(let [{:keys [value]} some] …)` — compiles, on a
variant or a record, the parent refused as the language refuses it, every destructured read counted.
