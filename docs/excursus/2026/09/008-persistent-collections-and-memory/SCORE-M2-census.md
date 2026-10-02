# SCORE — excursus 008 M2: the heap census

Struck by Claude Sonnet, 2026-10-01. Tree at HEAD `efc2e20` (branch `excursus-008-m2`). Written AS I GO
per the brief. **Tree is left dirty, nothing committed, per METHOD.**

## Status

- [x] Read BRIEF-M2-census, WEIGH-M2, SCORE-M2-the-allocator-reuses-holes (full), NOTE-stone-3a-landed,
      the named runtime.wat/compile.wat sections.
- [x] The switch (`WAT_HEAP_CENSUS=1`) + counter table + exit report
- [x] Census-off program bytes match the M2 fixpoint (see emitted, below)
- [x] Probes, off and on
- [x] The runs: two-hop census compiler, corpus self-compile, drop-3b-* fixtures
- [x] The counterfactual on 3b-2 (`62dc68b`)
- [x] The SCORE's table + one sentence
- [x] `tools/verify.sh` on the real tree, switch off — `verify: ok`

## DESIGN — the plan (recorded before coding, so a cut-off mid-strike leaves a trail)

**Counters, where they live.** Two existing free-list tables already sit at `r14+16` (hdr-small, 512B)
and `r14+528` (hdr-large, 512B); `r14+1040` is where the buffer begins today (post-M2, census off).
Three new fixed-offset regions, present ONLY when `WAT_HEAP_CENSUS=1` widens the header (byte-identical
to today when off, same technique M2 used for small/large):

- `hdr-census-alloc` = 1040, 13 routines x 4 words (count, bytes, reuse-count, reuse-bytes) = 416B
- `hdr-census-free` = 1456, 7 kinds x 3 paths (youngest/pushed/given-up) x 2 words (count,bytes) = 336B
- `hdr-census-zero` = 1792, 4 categories (str/rec-or-henum/vec/fn) x 1 word (count) = 32B
- `hdr-buf` (census on) = 1824; `buf-bytes` (census on) = 8192 + (1824-16) = 10000

**13 allocating routines** (every `:c::rt-bump` call site with `reuse?=true` — the two `extend`
sites are growing a live object, not allocating a new block, and are excluded, matching M2's own
accounting): rid 0 `rt-str-cat`, 1 `rt-vec-new`, 2 `rt-vec-conj-own-copy`, 3 `rt-varr-new`,
4 `rt-node-new`, 5 `rt-tree-push`, 6 `rt-tree-from-arr`, 7 `rt-vec-conj`, 8 `rt-slot-set`,
9 `rt-str-subs`, 10 `rt-i64-to-str`, 11 `rt-prim-read-hex`, 12 `rt-io-read-file`.

**7 free kinds**, matching the brief exactly and the branch structure `:c::freevec-glue-body` already
has: 0 String, 1 record-or-payload-enum, 2 closure, 3 flat Vector, 4 owned-flat Vector, 5 trie Vector
(the tree header), 6 trie node. One call to `:c::free-tail-emit` per kind (freevec has 3 of the 7).

**Where the counts land, mechanically:**
- `:c::rt-bump`'s `reuse?=true` branch: right after `size-calc` (before the class decision
  overwrites `r9`), unconditionally bump `count[rid]+=1`/`bytes[rid]+=size` (using `r9` as source —
  harmless even on the OOM path, since OOM aborts before any dump runs). Copy `size` into a NEW
  scratch `r13` (pushed/popped only when census? is true) so it survives `read-head`'s clobber of
  `r9`. At the FOUND exit (inside `found-body`, before the pops), add `reuse-count[rid]+=1`/
  `reuse-bytes[rid]+=r13`.
- `:c::free-tail-emit`: `sizereg` is never clobbered by the SMALL/LARGE decision (only read), so at
  each of the three exits (youngest/pushed/given-up) just before its own `ret`, add
  `count[kind][path]+=1`/`bytes[kind][path]+=sizereg` directly against `r14` — no new scratch needed.
- `:c::dropchk-hex`: at `body`'s start (zero reached, has-glue?), one more increment,
  `zero[cat]+=1`, cat derived from `:c::glue-target-ty` the same way `:c::free-target` is (str=0,
  rec:/henum:=1, vec:=2, fn:=3 — the Vector sub-kind is a RUNTIME tag check inside the glue body, not
  resolvable statically at the drop site, so this one counter is coarser than the free side's 7).

**Derived at dump time** (no separate storage; unrolled adds over the stored words, since routine/kind
counts are compile-time constants — no runtime loop needed): total alloc bytes/count (sum over 13),
total freed bytes/count (sum over 7 kinds x 3 paths), total reused bytes (sum over 13 reuse-bytes),
total pushed bytes (sum over 7 kinds' "pushed" path only), free-list bytes still held at exit
(= pushed − reused, exact by construction: every pop removes exactly one earlier push), live bytes
(= total alloc bytes − total freed bytes), heap high-water (= `r15 - r14 - buf-bytes`; r15 is
monotonic non-decreasing post-M2-4, so its value AT EXIT already IS the high-water mark — no running
max needs tracking).

**The dump**: in `:c::stub`, after `call main`/`call flush`, before `exit0`, gated on `census?`.
One line per stored counter plus the derived totals (~105 lines), each built the same way
`:c::rt-abort`'s message is (stack-packed literal, `:c::rt-digits`' backward digit walk) but writing
to **stderr directly** (`:c::rt-write (:c::fd-stderr)`), never touching the buffered stdout path —
this is what keeps stdout byte-identical with the switch on, the GATES section's own claim.
`tools/probe.sh`'s own 2>&1 merge will NOT agree with the switch on (interpreter never emits census
lines) — handled by a separate stream-split comparison for the "on" runs, documented at that gate
rather than silently relying on stock `tools/probe.sh`'s merged-stream diff.

**Threading `census?`:** read once into `:c::Prog` (`:census`, via `:c::heap-census?`, same shape as
`:c::drop-check?`/`:dchk`). Reaches `:c::rt-bump` by a NEW parameter threaded through
`:c::runtime -> :c::rt-cat -> :c::rt-nth -> ` each of the 13 routine builders (+ the 2 extend calls,
which ignore it) `+ :c::rt-buf-put` (for `hdr-buf`'s conditional value). Reaches `:c::free-tail-emit`
and `:c::dropchk-hex` directly (they already take `pg`). Reaches `:c::stub`/`:c::stub-arm` (for
`buf-bytes`) via a new parameter from the top-level compile call.

## Implementation log

**Built** (all in `elf/compile.wat` and `elf/lib/runtime.wat` unless noted):
- `:c::Prog/census` + `:c::heap-census?` (mirrors `:dchk`/`:c::drop-check?` exactly).
- `elf/lib/x86.wat`: `:c::add-mi` (new primitive, `cmp-mi`'s own pair, digit 0 — "add $imm,
  disp(BASE)").
- Header: `:c::hdr-census-alloc`/`:c::hdr-census-free`/`:c::hdr-census-zero` + per-counter
  address functions (`:c::census-alloc-count/bytes`, `:c::census-reuse-count/bytes`,
  `:c::census-free-count/bytes`, `:c::census-zero-count`), `:c::hdr-buf`/`:c::buf-bytes` now
  take `census?`.
- `:c::rt-bump`: `census?`/`rid` params; total count/bytes credited right after `size-calc`
  (before the class decision touches `r9`); `r13` added to the self-contained push/pop set
  (census? only) to carry `size` past `read-head`'s clobber, for the reuse count/bytes at the
  FOUND exit.
- `:c::free-tail-emit`: `census?`/`kind` params; count/bytes at all three exits
  (youngest/pushed/given-up), using `sizereg` directly (never clobbered) — no new scratch.
- `:c::dropchk-hex`: `zero-hex`, the "reached zero" counter by category (str/rec-or-henum/
  vec/fn), appended at the END of `body` (NOT the start — `call-pos`/`free-pos` assume `body`
  starts with `call-hex`'s own `push-rax`).
- `census?` threaded: `:c::runtime -> :c::rt-cat -> :c::rt-nth -> {rt-flush, rt-buf-put,
  rt-str-cat, rt-str-cat-own, rt-vec-new, rt-varr-new, rt-node-new, rt-tree-push,
  rt-tree-from-arr, rt-vec-conj, rt-vec-conj-own, rt-slot-set, rt-str-subs, rt-i64-to-str,
  rt-prim-read-hex, rt-io-read-file}`; `:c::lay`/`:c::layout` (pass-one measuring already
  depends on routine lengths, which now depend on `census?`); `:c::stub`/`:c::stub-arm`/
  `:c::stub-len`; the top-level compile call binds `census? = (:c::Prog/census pg0)` once.
- The dump: `:c::rt-say-stderr`/`:c::rt-say-int-stderr` (runtime.wat, generic stderr writers,
  never placed in the Layout — see the bug below for why) + `:c::census-dump` and its helpers
  (compile.wat), emitted in `:c::stub` between `call flush` and `exit0`.
- 13 routine ids (rid 0-12): `str_cat, vec_new, vec_conj_own_copy, varr_new, node_new,
  tree_push, tree_from_arr, vec_conj, slot_set, str_subs, i64_to_str, prim_read_hex,
  io_read_file` — the 13 `reuse?=true` `:c::rt-bump` call sites (the two `extend` sites are
  growing a live object, not allocating, and are excluded, matching M2's own count).
- 7 free kinds (kind 0-6): `string, record, closure, flat_vector, owned_vector, trie_vector,
  trie_node` — exactly the branch structure `:c::freevec-glue-body` already has (3 of the 7).
- 4 zero-reached categories (coarser than the 7 kinds: the Vector flat/owned/trie split is a
  RUNTIME tag check inside the glue body, not visible at the drop site): `string, record,
  vector, closure`.

**A real bug, found and fixed**: `:c::rt-say-int-stderr`'s first draft ended `leave; ret`,
copied verbatim from `:c::rt-print-i64` — which IS a real Layout routine, reached by a `call`
that pushed a return address. Mine is INLINED straight into the stub's byte stream (deliberately
— no new Layout entry, to avoid the exact index-shifting hazard `SCORE-M2-the-allocator-reuses-
holes.md`'s own "CORRECTION" section flagged and routed around). A bare `ret` with no matching
`call` pops whatever garbage sits on the stack and jumps to it. Caught immediately:
`probe-census.sh` (below) on `drop-at1.wat` printed exactly one correct line
(`census alloc.str_cat.count 0`) then SIGSEGV'd, `rip=0`. Fixed by dropping the trailing `ret`
(`leave` alone is pure stack/register cleanup, no control transfer, so it falls straight through
to whatever comes next). **Caught this WHILE a `tools/verify.sh` (switch off) was running in the
background** — I edited the real tree to fix it, which `tools/bootstrap.sh` correctly detected
("the compiler source changed WHILE this ran") and refused rather than silently passing. METHOD
violation, recorded rather than hidden: a fresh `verify.sh` is run only after all edits below are
done.

**`tools/probe.sh` and the switch ON — not literally stock `tools/probe.sh`.** The brief's GATES
section says the 25 required fixtures "agree... with the census off AND on," reasoning that
"the census writes to stderr only; stdout is unchanged." Literal `tools/probe.sh` captures native
`2>&1` (merged), so with the switch on the native side gains ~100 `census ...` stderr lines the
interpreter (which never runs our x86 codegen at all) cannot produce — a real mismatch under the
STOCK script's own comparison, not evidence of anything wrong. Wrote `probe-census.sh`
(scratchpad) instead: same sandbox-and-driver shape as `tools/probe.sh`, but captures native
stdout and stderr SEPARATELY and compares stdout-only against the interpreter, reporting the
stderr census-line count as a sanity figure. OFF runs use stock `tools/probe.sh` unmodified.

**Probes, OFF (stock `tools/probe.sh`), all 25 required fixtures**: AGREE, first run (drop-3b-*,
drop-arm/arm2, drop-at1/3/4/5, drop-concat-box, drop-conj, drop-head, drop-ifval, drop-len,
drop-let-tail, drop-match-arm, drop-ret, drop-ronly-arm, drop-shadow, drop-sum, drop-tail,
drop-twice, f209-tier1-self-vec-build, f209-tier1-self-vec, m2-region-collision).

**Probes, ON (`probe-census.sh`)**: running — see below for the completed table.

## Gates and runs (continued by Grok)

Real tree stays dirty. No compiler source edited in this continuation. Nothing committed.
The 3b-2 counterfactual lives only in `/tmp/census-3b2` (`git archive 62dc68b`).

**Probes, ON.** 26 fixtures (every `elf/probe/drop-*.wat` except `drop-cons.wat`, plus
`f209-tier1-self-vec`, `f209-tier1-self-vec-build`, `m2-region-collision`), stdout compared
with the interpreter, census on stderr. All `agree(stdout)`, 107 census lines each.
`PROBES_EXIT:0`. Log `/tmp/census-probes.log`.

**`tools/emitted.sh check`.** Run once, exit 1, 91 of 100 reported moved. Not re-run.
The on-disk `elf/out/.emitted-manifest` predates M2: none of its entries match the M2
fixpoint `/tmp/chain-m2-r2`. The manifest was not rewritten. The census-off emission of
this source (the census-on compiler's second hop, `WAT_HEAP_CENSUS` unset) matches that
fixpoint 91/91. `compiler.elf` is excluded from the check; the census-off compiler of this
source is 457,257 bytes, against the M2 compiler's 444,609, because the compiler now
contains the census code. `four.elf` matches both trees and contains no `census ` strings.

**Self-compile, census on, M2.** Built by a full bootstrap in `/tmp/census-on` (fixpoint
502,110 bytes, `bootstrap: ok`), then a copy of that compiler (`hop2`) run with the switch
unset so the programs it writes are the census-off emission, while its own runtime still
counts. RSS from `wait4` `ru_maxrss`: 526,712 KB. Stderr `/tmp/census-self.err`.
`hop2` is 502,110 bytes and writes `compiler.elf` at 457,257 bytes; that size change is
the switch, not a broken fixpoint.

Fresh bytes below are alloc bytes minus reuse bytes. Frees are counted by kind, not by
routine, so a routine's fresh bytes are the bump it caused, not the bytes still live from it.

| routine | alloc bytes | reuse bytes | fresh bytes |
|---|---:|---:|---:|
| str_subs | 248,560,896 | 38,321,344 | 210,239,552 |
| node_new | 176,008,208 | 5,132,912 | 170,875,296 |
| str_cat | 169,295,264 | 68,318,528 | 100,976,736 |
| slot_set | 65,785,792 | 43,292,304 | 22,493,488 |
| vec_new | 37,715,352 | 19,847,904 | 17,867,448 |
| tree_push | 14,030,480 | 1,025,480 | 13,005,000 |
| vec_conj | 11,349,720 | 4,046,776 | 7,302,944 |
| varr_new | 11,005,464 | 4,882,104 | 6,123,360 |
| vec_conj_own_copy | 7,864,320 | 2,111,488 | 5,752,832 |
| io_read_file | 4,659,840 | 2,242,048 | 2,417,792 |
| prim_read_hex | 2,211,840 | 0 | 2,211,840 |
| i64_to_str | 514,080 | 25,120 | 488,960 |
| tree_from_arr | 405,240 | 150,680 | 254,560 |
| **total** | **749,406,496** | **189,396,688** | **560,009,808** |

| free kind | youngest bytes | pushed bytes | given up bytes |
|---|---:|---:|---:|
| string | 3,139,648 | 111,776,512 | 0 |
| record | 12,874,984 | 60,694,536 | 0 |
| closure | 0 | 0 | 0 |
| flat_vector | 2,911,624 | 8,790,000 | 1,536 |
| owned_vector | 174,048 | 1,868,704 | 0 |
| trie_vector | 1,000 | 1,171,000 | 0 |
| trie_node | 0 | 5,137,536 | 0 |

Zero-reached with no free: string 2,180,225, record 862,581, vector 431,154, closure 0.
Totals: alloc count 12,494,461, free count 3,492,848, free bytes 208,541,128, pushed
bytes 189,438,288. Free-list bytes still held = pushed − reused = **41,600**.
Live = alloc − freed = **540,865,368**. Heap high water (`r15` at exit, monotonic after
M2-4) = **545,564,064**. Given up is 1,536 bytes, both of them flat vectors.

**The three `drop-3b-*` fixtures** (census on, real tree):

| fixture | alloc bytes | reuse bytes | free bytes | list still held | live | high water |
|---|---:|---:|---:|---:|---:|---:|
| drop-3b-recs | 11,238,032 | 802,816 | 819,200 | 16,384 | 10,418,832 | 10,435,216 |
| drop-3b-closure | 8,800,032 | 0 | 0 | 0 | 8,800,032 | 8,800,032 |
| drop-3b-list | 80,000,032 | 0 | 800 | 0 | 79,999,232 | 79,999,232 |

Recs reuse about 803 KB and leave 16 KB on the list. The closure fixture frees nothing.
The list fixture frees 800 bytes and keeps the whole vector live. High water matches the
old fixture RSS picture (recs ~10 MB, closure ~9 MB, list ~80 MB).

**Counterfactual, 3b-2 (`62dc68b`).** Region release is still there (`pop r15` inside
`:c::seq`). Census is hardcoded on in that sandbox. The rewind counter is the sum of
`r15` before that pop minus `r15` after, only when the pointer actually moves back, and
it does not include the youngest-free rewind.

A first self-compile printed the long per-counter dump. That dump is itself a
compile-time string build, and on this tree the build is region-released, so the rewind
sum swallowed the report: `region.rewind_bytes` 3,083,381,176, `str_cat` bytes
1,527,651,424 against M2's 169,295,264. High water on that run was still 523,336,344
(RSS 500,052 KB), close to the historical 3b-2 band plus census overhead, which is why
the peak was kept and the sum was not. Those totals are rejected.

The report was cut to five lines (`total.alloc_bytes`, `total.free_bytes`, `live_bytes`,
`heap.hiwater_bytes`, `region.rewind_bytes`). The first `--fast` bootstrap differed on
92 of 94 binaries: the seed still emitted the long dump, and the compiler it wrote
emitted the short one. The second `--fast`, seeded from that short compiler, fixpointed
at 477,993 bytes (`bootstrap: ok`). Measuring that compiler (a copy, so it does not
overwrite itself):

| | 3b-2 short report | M2 census |
|---|---:|---:|
| total alloc bytes | 861,856,456 | 749,406,496 |
| total free bytes | 245,950,040 | 208,541,128 |
| live bytes (alloc − free) | 615,906,416 | 540,865,368 |
| heap high water | 497,886,072 | 545,564,064 |
| region rewind (sum) | 850,357,584 | 0 (release retired) |
| free-list bytes still held | 0 (no free lists) | 41,600 |
| RSS (KB) | 475,148 | 526,712 |

`HOP_STABLE`: the measured compiler rewrote `compiler.elf` at the same 477,993 bytes.
On 3b-2, `r15` is not monotonic, so high water is a running max of the post-grow top,
not exit `r15`. Live bytes exceed the high water there because a rewound allocation
stays in the alloc total and is not a free. The rewind figure is a sum of every
release, so a block allocated and released many times is counted many times; it is
larger than the resident gap on purpose.

Historical peaks, no census, from the M2 score: main `5ed2d00` 446,392–446,624 KB,
3b-2 `62dc68b` 464,436–464,752 KB, M2 511,032–512,056 KB. The census-on RSS sits about
10–15 MB above those bands (475,148 vs ~464,600; 526,712 vs ~511,500). The gap between
the two census runs is 51,564 KB, the same ~47 MB the historical M2 peak sits above
3b-2.

**The sentence.** The retired region release carries the rise above main: M2 exits with
540,865,368 live bytes inside a 545,564,064 high water and 41,600 bytes still on the
free lists, while 3b-2 returns 850,357,584 bytes over the run (a sum of repeated
releases, not a peak) and holds its high water at 497,886,072 bytes, about 47 MB under
M2, which is the part of the ~65 MB the release was keeping down.

**`tools/verify.sh`** (switch off, real tree), first run. Bootstrap passed: 103 binaries,
stage 0 in 1,505,062 ms, stage 1 in 2,495 ms, all byte-identical, fixpoint 457,257
bytes, `bootstrap: ok`. `tools/elf-run.sh` then stopped in `tools/reads.sh`:
`:c::census-line` emits `(:c::mov-rm (:c::r14) disp (:c::rax))`, a load of one census
counter out of the allocator header. That word is an i64 the program stored about
itself, not a reference taken out of a container, so it is the same shape as the
free-list head already allowed. `tools/reads.sh` now allows that one spelling.
`reads: ok` after the edit. Second `tools/verify.sh`, switch off: bootstrap ok
again (fixpoint 457,257 bytes), `reads: ok`, `elf-run: ok` (103 native binaries,
54 agree with the interpreter), `verify: ok`. Log `/tmp/census-verify2.log`.

## R2 — who holds the never-freed bytes

The counter the first section called "zero-reached with no free" is printed
`reached.<cat>.count`. It still sits after the free in `:c::dropchk-hex`. The old
name was the position of the add, not its meaning.

**Site word, census build only.** Each fresh block carries one extra header word,
eight bytes before the count, holding the allocating function: the return address
at the bump, mapped through the compiler's own function table. A nested runtime
return address falls outside the user range and is skipped. A free subtracts the
block's current size from that function. Census off does not emit the word.
`elf/out/compiler.elf` after the off fixpoint is 466,822 bytes
(`/tmp/census-r2-off.elf`). Against `/tmp/chain-m2-r2/elf/out`, 91 program elves
hash-identical; `stage1.elf` is a leftover compiler (444,609 vs 466,822), not a
program.

**The names are real.** `elf/out/strings.elf`, compiled with the switch on, prints
`site user/greet 64`, `site user/stars 128`, `site user/main 32`. Those three sum
to 224, which is that run's `live_bytes`. `alloc_count` is 9, all `str_cat`. No
`(unmapped)` line. `four.elf` and `greet.elf` allocate nothing, so they were not
this check.

**The self-compile.** A copy of the census-on compiler (`/tmp/census-r2-hop2.elf`,
568,605 bytes) compiled the corpus with `WAT_HEAP_CENSUS` unset, so it counted
while emitting census-off programs. `compile: ok`. The compiler it wrote is
466,822 bytes and byte-identical to `/tmp/census-r2-off.elf`. The same 91
program elves still match `/tmp/chain-m2-r2`.

| | this run | the M2 census above |
|---|---:|---:|
| alloc count | 12,795,252 | 12,494,461 |
| alloc bytes | 767,114,944 | 749,406,496 |
| free count | 3,586,695 | 3,492,848 |
| free bytes | 213,868,768 | 208,541,128 |
| live (alloc − free) | 553,246,176 | 540,865,368 |
| high water | 631,681,416 | 545,564,064 |
| free-list bytes still held | 58,320 | 41,600 |

`reached.string` 2,246,151 + `reached.record` 881,774 + `reached.vector` 439,425
+ `reached.closure` 0 = 3,567,350. The 19,345 gap to the free count equals
`free.trie_node.pushed.count`.

558 functions still hold bytes. Their site live sums to **554,353,864**. No
`(unmapped)` line. Site live − routine live = **1,107,688** (138,461 words).
An extend adds its growth to the site and not to `alloc_bytes`, and the free
later subtracts the grown size from both, so that difference is the extend
bytes. The +8 site tag is in neither sum. The high water is the bumped pointer
after the site-word slide; it is not a remeasurement of the RSS question.

The live total is 12,380,808 above the M2 census because this binary is the R2
compiler (the scan and the report are in it) compiling the R2 sources: alloc
bytes +17,708,448, free bytes +5,327,640. The sum closes against this run.

**Not the retained output.** The 92 elves written by this run total 891,151
bytes, 1,782,302 hex characters. The top site alone is 98,788,528. The dump
runs after `call main`, and `:user::main` keeps nothing: each `:c::compile`
returns nil. What is still live is a count that never reached zero.

| bytes still live | function | what it is |
|---:|---|---|
| 98,788,528 | `:c::buf-add` | counting defect |
| 78,433,792 | `:asm::scan` | counting defect |
| 75,483,760 | `rd/add` | counting defect |
| 51,570,880 | `:asm::nibble` | counting defect |
| 49,721,640 | `:c::patch` | counting defect |

These five are 353,998,600 of the 554,353,864 site bytes.

`:asm::scan` compares a one-character slice and drops nothing:

```wat
(= (:wat::string::subs (:asm::printable) i (:wat::core::+ i 1)) c)
```

`:c::drop-if-last` drops a symbol on its last use and does nothing for any
other form. The `subs` is a fresh heap string. `=` calls `str_eq` and then
asks `drop-if-last` of both operands, which skips it. The slice stays at
count 1. Minimal shape: `(= (subs s i (+ i 1)) c)`.

`:asm::nibble` is that one-character `subs`, and `:asm::u8` builds a byte as
`(concat (nibble (/ n 16)) (nibble (rem n 16)))`. The left call is not
`:c::fresh-str?`, so the copying concat drops it. `:c::cat-fold` copies the
right operand and never drops it — the comment on that function says the
right-hand argument is only read. Every low nibble stays at count 1. Minimal
shape: `(concat (nibble hi) (nibble lo))`.

`:c::patch` flattens the code buffer and rebuilds it:

```wat
(:c::buf-one (:wat::string::concat
  (:wat::string::subs code 0 at)
  hex
  (:wat::string::subs code (:wat::core::+ at (:wat::string::length hex))
    (:wat::string::length code))))
```

The first `subs` is fresh, so concat consumes that block in place. The second
`subs` is a later argument of `:c::cat-fold`: copied, not dropped. Each patch
leaks the tail of the code buffer, and the leak is charged to `:c::patch`
because that is who called `subs`. Minimal shape:
`(concat (subs code 0 at) hex (subs code from (length code)))`.

`:c::buf-add` only conjs a chunk onto the buffer vector:

```wat
(:c::Buf :ch (:wat::core::conj (:c::Buf/ch b) s)
         :n (:wat::core::+ (:c::Buf/n b) (:wat::string::length s)))
```

The vector nodes from those conjs are what this site holds. The finished hex
of the whole corpus is 1,782,302 characters, so 98,788,528 bytes are earlier
versions of that vector, still counted after the `Buf` that held them has
left scope.

`rd/add` allocates the reader node and conjs it onto the arena. That arena is
`:c::compile-as`'s `st`, then shared into the program record. `compile-as`
returns nil. 75,483,760 bytes of those nodes are still live, which is the
arena's count never reaching zero: one holder was incremented and no drop
brought it down. Minimal shape: the node `rd/add` stores in the arena, after
the `let` in `:c::compile-as` has returned.

## R3 — a temporary a built-in reads is dropped after the read

The rule sits in `:c::drop-if-last`. The Symbol arm is unchanged: a pointer
name, on its last use, not read-only, reloaded and dropped. Anything else that
is pointer-typed is an owned reference — a call result, a counted read, an
`if` / `let` / `do` whose value flows on — so that arm pops the pointer the
caller saved, drops it, and puts the result back in rax. The literal guard
inside the drop skips a count of 0. A Symbol that is not a last use is not
dropped.

`length` is the one reading built-in that already dropped a non-Symbol in
place, and it was left there. A scalarised string parameter has no pointer
for `:c::drop-kept` to reload; routing `length` through that helper would skip
the drop it already emits. Every other reading built-in calls
`:c::drop-if-last`, which is why none of them can miss the new arm: `subs`
(and `byte-subs`), `starts-with?`, `contains?`, `code-point-at` (and
`byte-at`), `nth`, a field read, string `=` / `not=`, `println`, `assert-eq`,
and the head of an indirect call. `:c::cat-fold`'s later operands are the same
kind of read — `str_cat` copies them — and each is saved, then dropped, after
the copy. `conj`, `assoc`, and concat's left argument consume their operand.
`:c::buf-add` and `rd/add` were not edited.

The first indirect call pushed that saved head on top of the arguments, so
the callee read the closure pointer as its first parameter.
`elf/probe/drop-3b-closure.wat` overflowed (`wat: i64 overflow` against the
interpreter's `1188895`), plain and with `WAT_DROP_CHECK=1`. The slot is
reserved under the arguments and filled once the head is in rax; the
arguments come off before the drop pops the slot. Both ways then agree on
`1188895`.

**The three shapes.** Census on. Each allocating site is absent from the
report, and `live_bytes` is 0.

`elf/probe/r3-scan.wat`, `(= (subs s i (+ i 1)) c)`, prints `1` then `0`.
`str_subs` runs twice, 64 bytes, and both are freed. `tools/probe.sh` agrees
both ways, and again with `WAT_DROP_CHECK=1`.

`elf/probe/r3-nibble.wat`, `(concat (nibble hi) (nibble lo))`, prints `ff`
then `0a`. Four nibbles and two concats, all freed. Same two probe runs agree.

`elf/probe/r3-patch.wat`, `(concat (subs code 0 at) hex (subs code from
(length code)))`, prints `abcdXYZhij`. Two `subs`, 64 bytes, freed; the
concat extends the head in place (`str_cat` count 0). Same two probe runs
agree.

**The self-compile**, census-on compiler, `WAT_HEAP_CENSUS` unset, so it
counted while emitting a census-off corpus. The compiler it wrote is 529,502
bytes, identical to the plain fixpoint. No `(unmapped)` line.

| site | R2 live bytes | R3 live bytes |
|---|---:|---:|
| `:asm::scan` | 78,433,792 | 3,360 |
| `:asm::nibble` | 51,570,880 | 0 |
| `:c::patch` | 49,721,640 | 31,277,648 |
| `:c::buf-add` | 98,788,528 | 114,608,488 |
| `rd/add` | 75,483,760 | 75,901,840 |

`:asm::nibble` prints no site line. `:asm::scan` is down to 3,360; the
fixture for its comparison slice is live 0, so those 3,360 bytes are not that
slice. `:c::patch` is down 18,443,992; the fixture frees the tail slice, and
31,277,648 bytes allocated there are still reachable at exit. `:c::buf-add`
and `rd/add` moved up, by 15,819,960 and 418,080. They are the retained vector
versions and the reader's arena, and this round did not touch them.

Totals: alloc_count 13,311,833, alloc_bytes 811,641,288, reuse_bytes
352,601,240, free_count 10,713,818, free_bytes 485,661,344, pushed_bytes
353,865,120, free-list remaining 1,263,880, live_bytes 325,979,944,
hiwater 352,785,944. `reached.string` 9,309,851 + record 934,351 + vector
448,964 + closure 0 = 10,693,166. The gap to free_count is 20,652, which is
`free.trie_node.pushed.count`. live_bytes is alloc_bytes minus free_bytes.

Peak RSS of the census-off compiler (`ru_maxrss`): 323,044 KiB. The R2 note's
band for main was 446,392–446,624 KiB.

**Gates.** Plain native chain: the first `--fast` after the emitter change
differed on the five closure programs and matched on the compiler (529,502
bytes); the second `--fast` matched all 102 binaries, `stage2 == stage3`.
Drop-check chain: one `--fast`, 634,126 bytes, 102 binaries identical,
`stage2 == stage3`. `tools/probe.sh` and `WAT_DROP_CHECK=1 tools/probe.sh`
on every `elf/probe/drop-*.wat` except `drop-cons.wat`, both `f209-*`,
`m2-region-collision`, and the three fixtures: 28 agreed on the first pass;
`drop-3b-closure` agreed after the slot fix, both ways. `tools/verify.sh`:
stage 0 in 1,723,983 ms, fixpoint 529,502 bytes, `elf-run: ok`, `verify: ok`.
`WAT_DROP_CHECK=1 tools/verify.sh`: stage 0 in 1,594,028 ms, fixpoint 634,126
bytes, `elf-run: ok`, `verify: ok`.
