# SCORE — stone 0c: what the count buys (a census, not a change)

**Struck 2026-09-23 from `81d05b3`.** Nothing in `main`'s compiler changed. The only file this
strike adds to the tree is this SCORE, and nothing is committed.

## ⛔ STOP-2 FIRED. One type has two spellings.

A tier-1 enum value built by a constructor and bound by `let` gets the spelling `henum:Name`.
Every declared use of the same type spells it `penum:Name[;arg]`. Here is where each spelling
comes from:

| spelling | where it is formed | when |
|---|---|---|
| `penum:user::O` | `:c::enum-ty`, `elf/compile.wat:963-968`, which calls `:c::enum-tier` (`:950`) | from a declaration: a parameter, a field, a return, an alias, reached through `:c::ty-node` (`:1191`, `:1203`) |
| `henum:user::O` | `:c::type-of-form`'s variant arm, `elf/compile.wat:1374-1379`. It picks `"henum:"` or `"enum:"` from `Enum/heap` alone, ignores the tier, and drops the `;arg` | from a variant-constructor EXPRESSION. `:c::bind-each` (`:3730`) and `:c::ty-bind` (`:1398`) type a `let` binding from `:c::type-of` of its initialiser, so the binding gets this spelling |

Reachability decided by string comparison is therefore unsound. **The reason is measured.** In
this probe the only count protecting a Vector payload is the share on a let-bound constructor,
spelled `henum:`:

```wat
(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::defenum :user::O :wat::enum::Pure
  :No  []
  :Yes [xs <- :user::Row])
(wat.core/defn user/len [o :- :user::O] :- wat.type/i64
  (:wat::core::match o [:user::O.No {} 0] [:user::O.Yes {:xs xs} (wat.core/length xs)]))
(wat.core/defn user/poke [xs :- :user::Row o :- :user::O] :- wat.type/i64
  (:wat::core::match o
    [:user::O.No {} 0]
    [:user::O.Yes {:xs xs} (wat.core/length (wat.core/conj xs 99))]))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [e (wat.core/Vector :- [wat.type/i64])
                 o (:user::O.Yes {:xs (wat.core/Vector :- [wat.type/i64] 1 2 3)})
                 k (user/poke e o)]
    (wat.kernel/println k)                 ;; 4
    (wat.kernel/println (user/len o))))    ;; 3 -- 4 if the payload was extended in place
```

```
census of it:   CENSUS|own|conj|vec:i64
                CENSUS|share|R|vec:i64
                CENSUS|share|U|henum::user::O          <- the argument share of `o`, called unreachable

all-real:        penum-spelled-henum: agree    [4|3]
NOP-unreachable: penum-spelled-henum: DIVERGE  native=[4|4] (exit 0)   interp=[4|3] (exit 0)
all-NOP:         penum-spelled-henum: DIVERGE  native=[4|4] (exit 0)   interp=[4|3] (exit 0)
```

This is also a STOP-1-shaped witness. The NOP'd-unreachable compiler computes something
different, but on a probe written for this strike and not on the corpus. On the corpus it
computes the same thing (row 2), because no corpus program binds a tier-1 constructor with `let`.
The corpus's only `henum:` types, `borrowed`'s `B` and `matchval`'s `Val`, are real tier-3 enums.
The compiler has **no** enum-typed counted site at all (row 1), so the hole does not touch the
181 sites measured in row 4.

### The same two spellings are a live fault in `main`, not only a census problem

`:c::count-hex` picks its guards from the spelling (stone 0b). `henum:` answers "never a literal".
So the let-bound constructor's share gets the tag guard only, and a tier-1 enum over a String
literal is a read-only literal:

```wat
(:wat::core::defenum :user::S :wat::enum::Pure
  :None []
  :Some [s <- :wat::core::String])
(wat.core/defn user/slen [o :- :user::S] :- wat.type/i64
  (:wat::core::match o [:user::S.None {} 0] [:user::S.Some {:s s} (wat.string/length s)]))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [o (:user::S.Some {:s "xy"})
                 k (user/slen o)]
    (wat.kernel/println k)))               ;; 2
```

```
main @ 81d05b3 (tools/probe.sh, scratch archive):   penum-str-let: CRASH signal=11   interp=[2]
c9746f1 (stone 0a, before 0b):                       penum-str-let: agree   [2]
```

**Stone 0b introduced a SIGSEGV** on a valid program. Before 0b, every pointer type had both
guards, so the literal guard caught the count of 0. This is a red (STOP-4): captured once and not
re-run. Neither probe is in the tree; both sources are above.

**Everything below was measured before the probe was written.** The rows are reported as
measured, and each says how STOP-2 bears on it.

---

## Method — the census compiler and the same-layout pair

There are three variants of `elf/compile.wat`, each a `git archive 81d05b3` in scratch, patched
by one script that asserts exactly one match per replacement:

1. **Pass one records where the own sites are.** `:c::Out` and `:c::PassR` each get an `owns`
   field, and `:c::Prog` gets `reach`. At each of the three own sites, when `own?` is true, the
   container type is recorded:
   - `conj` (`:1886`): `(:c::type-of container)`
   - `assoc` (`:3334`): `(:c::type-of container)`
   - `concat` (`:2436`): `"str"`

   Pass two runs with `reach` set to what pass one recorded. Both passes compile identical code
   at identical widths.
2. **`:c::reach? t`** answers true in three cases: `t` is in `reach`; `t` is `penum:` and its
   payload (`:c::penum-payload-ty`, which recurses) is reachable, or the payload is unresolved;
   or ANY own site's container type is not `str`, `vec:` or `rec:`. The last case is a
   fail-safe: everything becomes reachable. It never fired.
3. **`:c::count-hex`** keeps its guards unchanged. Its `incq` becomes
   `(if (reach? t) (inc-hex) "<U>")`. `inc-hex` answers `(concat "48ff" "40f8")`, identically in
   both variants. **REAL**: `<U>` = `"48ff40f8"`. **NOP**: `<U>` = `"0f1f4000"`. **CENSUS**: REAL
   plus a `println` at every counted site and own site in pass two (`Out/base > 0`).

```
$ diff real/elf/compile.wat nop/elf/compile.wat
3102c3102
<                     inc (:wat::core::if (:c::reach? t pg) (:c::inc-hex) "48ff40f8")]
---
>                     inc (:wat::core::if (:c::reach? t pg) (:c::inc-hex) "0f1f4000")]
```

My first version wrapped the `assoc` site's call expression directly in the note. With that
version, `main`'s compiler, compiling the variant source, died with `wat: heap exhausted`. It went
away when the call's result was bound by `let` first. I did not diagnose the cause further;
recorded here in case it matters to someone.

**Each variant was proved at its own fixpoint.** I seeded each with `main`'s
`elf/out/compiler.elf` (242,467 B) and ran `tools/bootstrap.sh --fast` twice:

```
real    pass 2: 77 binaries, all byte-identical; stage2 == stage3, byte for byte (244008 bytes)
nop     pass 1: 12 of 77 differ   (the seed emits incq where stage 2 emits the NOP -- exactly the 12 programs row 2 lists)
nop     pass 2: 77 binaries, all byte-identical; stage2 == stage3, byte for byte (244008 bytes)
census  pass 2: stage2 == stage3, byte for byte (244672 bytes)
```

**REAL emits exactly what `main` emits.** For all 75 corpus programs other than the compiler, its
output is byte-identical to `main`'s:

```
real vs main: 0 of 75 differ
```

The census of **`main`'s own compiler** was taken by running the census binary over a `git
archive` of `81d05b3`. Its totals reproduce F-193's: 313 reads and 2,341 shares, 2,654 sites.

---

## Row 1 — ⛔ the census exists · **PASS (it exists); unsound in general per STOP-2**

**The compiler (`81d05b3`'s own source):**

```
compiler.elf  reads R 197 U 116 | shares R 2276 U 65 | reachable: rec::c::Out, rec::c::Prog, str, vec:i64,
              vec:rec::c::Bind, vec:rec::c::Bnd, vec:rec::c::Fn, vec:rec::c::Rec, vec:rec::rd::Node, vec:str
own sites: concat str 640; assoc rec::c::Prog 9, rec::c::Out 2; conj vec:i64 19, vec:str 11, vec:rec::c::Fn 5,
           vec:rec::c::Bind 4, vec:rec::rd::Node 1, vec:rec::c::Bnd 1, vec:rec::c::Rec 1
```

| | reachable | unreachable | total |
|---|---|---|---|
| reads (`:c::read-out`) | 197 | **116** (37%) | 313 |
| shares (`:c::share`) | 2,276 | **65** (2.8%) | 2,341 |
| **all** | 2,473 | **181 (6.8%)** | 2,654 |

**By type**, R/U as the census classed them:

```
  R  str                    reads   45  shares  690
  R  rec::c::Prog           reads   24  shares  661
  R  vec:i64                reads   25  shares  371
  R  rec::c::Out            reads    2  shares  292
  R  vec:rec::c::Bind       reads    2  shares  216
  R  vec:str                reads   30  shares   17
  U  vec:rec::c::Enum       reads   28  shares    6
  R  vec:rec::c::Fn         reads   27  shares    5
  R  vec:rec::rd::Node      reads   13  shares   14
  U  rec::c::Bnd            reads    2  shares   25
  U  rec::c::TC             reads    0  shares   27
  R  vec:rec::c::Bnd        reads   12  shares    9
  U  rec::c::Fn             reads   21  shares    0
  U  rec::c::Buf            reads   17  shares    1
  R  vec:rec::c::Rec        reads   17  shares    1
  U  rec::c::Enum           reads   17  shares    0
  U  rec::rd::St            reads    7  shares    4
  U  rec::c::Rec            reads    7  shares    2
  U  rec::c::Bind           reads    8  shares    0
  U  rec::rd::Node          reads    4  shares    0
  U  vec:rec::c::Alias      reads    3  shares    0
  U  rec::c::Alias          reads    2  shares    0
```

**Answer to the BRIEF's question, at type granularity:** **93.2% of the compiler's counts are on
a type that some own site in the compiler can receive.** Two types carry most of that:
- `str` (735 sites) is reachable because 640 `concat` sites own their accumulator.
- `rec::c::Prog` (685 sites) is reachable because 9 `assoc` sites own their `Prog`.

The trap door's worry, that most of the ~2,341 shares might be unreachable, **does not hold**:
65 are.

**The corpus.** 53 of the 75 programs have no counted site at all. The other 22:

```
escape.elf         reads R    0 U    0 | shares R    1 U    0 | reachable: str
borrowed.elf       reads R   14 U    0 | shares R    2 U    2 | reachable: str, vec:i64, vec:str, vec:vec:i64
matchval.elf       reads R    1 U    1 | shares R    0 U    0 | reachable: str
codeat.elf         reads R    0 U    0 | shares R    0 U    1 | reachable: -
vectors.elf        reads R    0 U    3 | shares R    2 U    2 | reachable: vec:i64
pvec.elf           reads R    0 U    4 | shares R    5 U    0 | reachable: vec:i64
assocn.elf         reads R    0 U    0 | shares R    2 U    0 | reachable: vec:i64
memory.elf         reads R    3 U    0 | shares R    0 U    0 | reachable: str, vec:str
linear.elf         reads R    0 U    0 | shares R    2 U    0 | reachable: vec:i64
moved.elf          reads R    7 U    0 | shares R    7 U    0 | reachable: vec:i64
freed.elf          reads R    0 U    0 | shares R    3 U    0 | reachable: str
strverbs.elf       reads R    0 U    0 | shares R    4 U    0 | reachable: str
strown.elf         reads R   11 U    3 | shares R    0 U    4 | reachable: str
reader.elf         reads R   15 U    4 | shares R   55 U    6 | reachable: str, vec:i64, vec:rec::rd::Node
asmbits.elf        reads R    0 U    0 | shares R    6 U    0 | reachable: str
optm.elf           reads R    0 U    0 | shares R    0 U    1 | reachable: -
optmh.elf          reads R    0 U    2 | shares R    0 U    2 | reachable: -
scan.elf           reads R    0 U    0 | shares R    0 U    2 | reachable: -
scanfast.elf       reads R    0 U    0 | shares R    0 U    2 | reachable: -
pass20000.elf      reads R    0 U    0 | shares R    9 U    0 | reachable: vec:i64
pass80000.elf      reads R    0 U    0 | shares R    9 U    0 | reachable: vec:i64
deepvec.elf        reads R    0 U    0 | shares R    2 U    0 | reachable: vec:i64
```

The corpus without the compiler has 68 reads (51 R, 17 U) and 131 shares (109 R, 22 U). Fifteen
further programs have own sites but no counted site: `strings`, `rec1`, `strbuild`, `strbuild2`,
`cat32000`, `catx`, and the `grow*` and `vecsum` family. The unreachable ones by program:

```
borrowed:  share henum::user::B x1; share rec::user::R x1
matchval:  read vec:henum::user::Val x1
codeat:    share str x1
vectors:   read str x3; share rec::user::Point x2
pvec:      read str x4
strown:    read rec::user::S x3; share rec::user::D x1; share rec::user::S x3
reader:    read rec::rd::Node x4; share rec::rd::St x6
optm:      share str x1
optmh:     read str x2; share str x2
scan:      share str x2
scanfast:  share str x2
```

`optmh`'s two String reads are the reads that kept it +3.28% in instructions at stone 0b. In
`optmh` nothing can mutate a String in place, so those reads protect nothing.

## Row 2 — ⛔ the census is sound on the evidence · **PASS on the corpus; refuted off it (STOP-2)**

This compares the NOP'd-unreachable compiler's outputs with the all-real compiler's. Each
differing byte is attributed either to a `48ff40f8` → `0f1f4000` swap at the same offset or to
the literal's text. The swap count is then checked against the census's U count for that program:

```
borrowed.elf       swaps    2 census-U    2 text 0 unexplained 0 OK
matchval.elf       swaps    1 census-U    1 text 0 unexplained 0 OK
codeat.elf         swaps    1 census-U    1 text 0 unexplained 0 OK
vectors.elf        swaps    5 census-U    5 text 0 unexplained 0 OK
pvec.elf           swaps    4 census-U    4 text 0 unexplained 0 OK
strown.elf         swaps    7 census-U    7 text 0 unexplained 0 OK
reader.elf         swaps   10 census-U   10 text 0 unexplained 0 OK
optm.elf           swaps    1 census-U    1 text 0 unexplained 0 OK
optmh.elf          swaps    4 census-U    4 text 0 unexplained 0 OK
scan.elf           swaps    2 census-U    2 text 0 unexplained 0 OK
scanfast.elf       swaps    2 census-U    2 text 0 unexplained 0 OK
compiler.elf       swaps  181 census-U  181 text 1 unexplained 0 OK
76 programs: 64 byte-identical, 12 moved, 0 mismatches
```

**The NOP compiler computes the same thing on all 76 inputs.** Any difference beyond the swaps
would have meant it miscompiled while running with its own 181 counts gone. I then ran the 11
moved corpus programs themselves, both builds, and compared stdout and exit status. **All 11 are
the same**, so the counts NOP'd inside those programs changed nothing they print either:

```
borrowed same · matchval same · codeat same · vectors same · pvec same · strown same
reader same · optm same · optmh same · scan same · scanfast same
```

This is the **dynamic** half: "protected nothing on these programs." The static half, "can never
protect," is refuted by STOP-2's probe.

## Row 3 — ⛔ the layout is controlled · **PASS**

```
real/elf/out/compiler.elf  244008 B
nop/elf/out/compiler.elf   244008 B
swapdiff: {'same_len': True, 'bytes': 548, 'swaps': 181, 'texts': 1, 'unexplained': [], 'n_unexplained': 0}
incq-pattern in REAL: 2678   in NOP: 2497   nopl in NOP: 181   nopl in REAL: 0
```

That is 181 swaps × 3 differing bytes (`40` is common to both encodings) plus 5 differing bytes in
the 8-character literal, **548 bytes, every one explained.** Every function is at the same
address.

(2,678 is the variant's own incq-pattern count. Its source is main's plus the census machinery,
and the census binary run over the variant's own source counts 2,683 sites, 181 of them U. The
machinery added only reachable sites.)

## Row 4 — the time the unreachable counts cost · **+1.1% cycles, SAME-LAYOUT**

**Method:** `taskset -c 0 perf stat -x, -e cpu_core/cycles/u,cpu_core/instructions/u` (CPU 0 is
a P-core, `cpu_core/cpus` = 0-7). Each compiler ran from a copy in `scratch/bin/`. Each run's
exit status and `"compile: ok"` were checked. The input was one tree, a `git archive 81d05b3`,
identical for all three arms. Rounds interleaved real / nop / main. There were two batches of 21
rounds; load average was 2.6-4.5 (desktop session).

```
batch 1
real  n=21 cyc min 1,156,272,861 med 1,159,633,502 max 1,239,266,426 | ins min 2,152,600,040 med 2,152,600,207
nop   n=21 cyc min 1,143,582,222 med 1,146,793,447 max 1,219,488,531 | ins min 2,152,599,414 med 2,152,599,794
main  n=21 cyc min 1,151,783,706 med 1,155,502,655 max 1,217,595,849 | ins min 2,141,947,160 med 2,141,947,490
real vs nop  cycles: min +1.110%  med +1.120%   ins min +0.00003% (626 apart)
paired rounds real>nop: 21 of 21; paired ratio median +1.231%

batch 2
real  n=21 cyc min 1,156,299,480 med 1,160,312,385 max 1,211,275,241 | ins min 2,152,599,971 med 2,152,600,164
nop   n=21 cyc min 1,143,184,852 med 1,146,403,037 max 1,199,077,887 | ins min 2,152,599,443 med 2,152,599,739
main  n=21 cyc min 1,148,403,191 med 1,155,453,510 max 1,225,962,965 | ins min 2,141,947,106 med 2,141,947,367
real vs nop  cycles: min +1.147%  med +1.213%   ins min +0.00002% (528 apart)
paired rounds real>nop: 21 of 21; paired ratio median +1.120%
```

| same-layout (REAL vs NOP) | cycles, min | cycles, median | instructions, min |
|---|---|---|---|
| batch 1 | **+1.110%** | **+1.120%** | +626 in 2.15 B (0.00003%) |
| batch 2 | **+1.147%** | **+1.213%** | +528 (0.00002%) |

**The 181 unreachable counts, 6.8% of the compiler's counted sites, cost it about 1.1-1.2% of
its cycles, for the same instructions, in 42 of 42 paired rounds.** This is a same-layout
comparison, so F-192's 1.8% floor does not apply. For scale, F-193's 313 reads (116 of them
among these 181) cost 3.47%.

**Cross-build, for reference only:**

| cross-build (REAL vs `main`) | cycles, min | cycles, median | instructions, min |
|---|---|---|---|
| batch 1 | +0.390% | +0.357% | +0.497% |
| batch 2 | +0.688% | +0.421% | +0.497% |

This is what the census machinery (`reach?` on every counted site, and the `owns` field) costs
the variant. It is inside the 1.8% layout floor. What it cannot tell you is how much faster `main`
would be without these counts. That needs a real type-filtered count, which is out of scope. The
same-layout number above is the one to use.

**How STOP-2 bears on this row:** none of the 181 sites is enum-typed, so the two-spelling hole is
not among them. The number is a fact about those 181 sites. It is not a proof that a real
implementation could drop exactly those 181 without first fixing the spelling.

## Row 5 — F-188 stays closed under the census · **PASS**

Each door probe, plus `borrowed.wat` and the guard and share probes, was run through
`tools/probe.sh` with the interpreter driving the variant `compile.wat`. The all-NOP arm is the
NOP variant with `reach?` replaced by `false`; it was added to show that each probe can fail:

```
                  NOP-unreachable                              all counts NOP'd
borrowed:         agree [4|3|4|3|4|"ab1"|4|"ab1"|5|4|5|4|5|4]    DIVERGE native=[4|4|4|4|4|"ab1!"|4|"ab1!"|5|5|5|5|5|5]
callrel-borrow:   agree [30|240000|3|1|30]                       DIVERGE native=[30|240000|4|1|99]
own-shadow:       agree [30|3|30]                                DIVERGE native=[30|4|99]
str-borrow:       agree [4|"ab1"|3]                              DIVERGE native=[4|"ab1!"|4]
str-shadow:       agree [4|"ab1"|3]                              DIVERGE native=[4|"ab1!"|4]
field-borrow:     agree [5|5|4]                                  DIVERGE native=[5|6|5]
field-shadow:     agree [5|4]                                    DIVERGE native=[5|5]
match-shadow:     agree [5|4]                                    DIVERGE native=[5|5]
tier1-borrow:     agree [4|3]                                    DIVERGE native=[4|4]
count-trie:       agree [40|4|3|1|0|41|40|1|5|4]                 DIVERGE native=[40|4|3|1|0|41|41|1|5|5]
share-join:       agree ["z1z1!z1!"|"z1-z1!"]                    DIVERGE native=["z1!!z1!!z1!!"|"z1!-z1!"]
share-shadow:     agree ["z2z1!z2!"]                             DIVERGE native=["z2!z1!z2!"]
count-literal:    agree [4|3|"cde"|4|3|0|-1|2|0|7|2]             agree   (a guard probe, not a door)
count-bare:       agree [1|0|1|0|"t"|3]                          agree   (a guard probe, not a door)
```

Census of the door probes. Every read a door depends on is on a reachable type. The few U shares
are on types that no own site in that probe receives:

```
callrel-borrow  reads R 5 U 0 | shares R 0 U 0 | own: conj vec:i64, conj vec:vec:i64
own-shadow      reads R 4 U 0 | shares R 2 U 0 | own: conj vec:i64, conj vec:vec:i64
str-borrow      reads R 3 U 0 | shares R 0 U 0 | own: concat str, conj vec:str
str-shadow      reads R 3 U 0 | shares R 2 U 0 | own: concat str, conj vec:str
field-borrow    reads R 3 U 0 | shares R 0 U 1 | own: conj vec:i64 x2
field-shadow    reads R 2 U 0 | shares R 1 U 1 | own: conj vec:i64 x2
match-shadow    reads R 2 U 0 | shares R 1 U 1 | own: conj vec:i64 x2
tier1-borrow    reads R 2 U 0 | shares R 2 U 0 | own: conj vec:penum::user::O, conj vec:i64
count-trie      reads R 9 U 0 | shares R 0 U 0 | own: conj vec:i64 x2, conj vec:vec:i64
borrowed        reads R 14 U 0 | shares R 2 U 2 | own: conj vec:vec:i64, vec:str, vec:i64 x5; concat str x2
```

`tier1-borrow`'s reads are typed `penum::user::O` and classed R through the payload `vec:i64`.
That is the trap door working as designed. **All ten doors stay closed, and each is sensitive to
losing its counts.** The door they do not cover is STOP-2's probe.

## Row 6 — the type strings are canonical · **FAIL: STOP-2**

These are the canonical parts:

- **Records** are `"rec:" + name`, and the name is `rec-index`-exact. It comes from `:c::ty-node`
  (`:1199`), the constructor arm of `:c::type-of-form` (`:1371-1372`), and `acc-ty` (`:1388-1396`).
  A non-declared spelling does not resolve and refuses as `compile: unknown type`.
- **Aliases** resolve to their node (`:1205`). `:c::Kids` shows up as `vec:i64` in the
  compiler's census.
- **Strings**: `wat.type/String` and `:wat::core::String` both become `"str"` (`:1212`).
- **Vectors** are `"vec:" + element` (`:1181`, `:1360`).

Every string the census saw is in this list:

```
str  vec:i64  vec:str  vec:vec:i64  vec:penum::user::O  vec:henum::user::Val  vec:rec::c::{Bind,Bnd,Fn,Rec,Enum,Alias}
vec:rec::rd::Node  rec::c::{Prog,Out,TC,Bnd,Fn,Buf,Enum,Rec,Bind,Alias}  rec::rd::{St,Node}  rec::user::{S,R,Point,Box,Tag,D}
rec::b::St  penum::user::{O,S}  henum::user::{H,B,Val}
```

Every own site's container type was `str`, `vec:` or `rec:`, so the STOP-3 fail-safe never fired.
**But enum types are not canonical.** The spelling depends on whether the value came from a
declaration (`:c::enum-ty`, which is tier-aware and instantiated) or from a constructor
expression (`:c::type-of-form:1374-1379`, which is `henum:`/`enum:` by `Enum/heap` and has no
`;arg`). The probe at the top shows the consequence, and a second probe shows the SIGSEGV that
follows in `main`.

A second, weaker soft spot: `:c::type-of` answers `"i64"` for any form it has no arm for. A
`match` expression is one; `:else` looks up the head and falls to `"i64"`. A pointer typed that
way is simply **not counted**, because `ptr-ty?` is false, so it creates no count to NOP. And no
own site in any program had a non-canonical container type. I found no way for it to make this
census unsound, but it is a count-COMPLETENESS question (F-188's family), and it is recorded here
rather than chased.

## Row 7 — `main` untouched · **PASS**

```
$ git diff --stat elf/compile.wat | wc -l
0
```

The tree's only change is this file.

---

## What surprised me

1. **The answer is the opposite of the trap door's fear.** 93% of the compiler's counts are on a
   type that an own site in the compiler can receive, and only 65 of 2,341 shares are not. The
   reason is two very wide types. `concat` owns its accumulator at 640 sites, so every String
   count is live. Nine `assoc` sites own a `Prog`, so all 685 `Prog` counts are live. Type
   granularity is too coarse to separate "a `Prog` that reaches `assoc`" from "a `Prog` that never
   will". Whatever the count buys beyond these 7% needs a finer question than the type.
2. **Yet 7% of the sites cost 1.1% of the time.** F-193 found 313 read sites costing 3.47%. Per
   static site, these 181 cost about the same as the reads. Time follows how often a site runs,
   not how many sites there are, and `vec:rec::c::Enum` (34 sites), `rec::c::Fn` (21) and
   `rec::c::Buf` (18) sit on hot lookup paths.
3. **The census found a bug in stone 0b.** The same "what can a type be" reasoning this strike
   borrowed trusted the type STRING, and the string for a tier-1 enum depends on where the value
   came from. The first check on it was a probe written for this strike. `main` segfaults on a
   five-line valid program that `c9746f1` ran correctly.
4. **In my first version of the census patch**, `main`'s compiler died of heap exhaustion
   compiling the variant source. The patch wrapped one large call expression as the argument of a
   small helper. Binding it by `let` first fixed it. Not chased.

## Method notes

- Every `wat` and native run was under `timeout -s KILL`.
- Every edit to a scratch `compile.wat` went through `patch.py`, which asserts exactly one match
  per replacement.
- The measurement input was a clean `git archive 81d05b3`. All binaries ran from copies.
- Scratch lives in
  `/tmp/claude-1000/-home-watmin-Work-holon/5373d366-7a52-4a05-a9b4-198d0c5a4a95/scratchpad/0c/`:
  - the three variants (`real`/, `nop`/, `census`/) plus `allnop`/
  - `patch.py`, `swapdiff.py`, `tally.py`, `measure.sh`
  - the raw census logs (`census-main.out`, `census-probes.out`, `census-stop2.out`)
  - the raw timing rows (`m1.txt`, `m2.txt`)
  - both new probes (`probes/`)
- Every number in this SCORE was measured in this session. Nothing is committed.
