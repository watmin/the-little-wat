# WEIGH — excursus 008 M2

## Round 1 (2026-10-01)

**Credited:** the free-list take lives INSIDE `:c::rt-bump` (one door by construction, self-contained: it saves
the registers it uses); the two inline bumps go through it; a dead non-youngest block goes onto its class's list;
three allocator bugs found and fixed on the way (`rt-cap`'s `out` clobbering `rcx`; the list pushed an object
pointer where a block start belongs; the small path's jump skipping the list). The region release is retired
(`:c::seq`'s `push r15`/`pop r15`, `:c::releasable?` and the poke call graph that only served it).

**STOP-2 was the region release, not argument liveness** — on my own run, `/tmp/probe8.wat` diverges with the
region release (`"561"|"2"`) and agrees without it: a block freed onto a list inside a statement, then the
statement's `pop r15` rewound the bump below it — one block, two owners. Now `elf/probe/m2-region-collision.wat`.

**STOP-3 — the plain self-compile segfaults; it is the ALLOCATOR, proven by elimination:**
- gdb on `/tmp/chain-m2f/elf/out/seed.elf` (my run): the Vector glue faults walking an object whose count word is
  0 and whose LENGTH word is 9 — more than a flat Vector holds (`:c::arr-max` 8); the words after it read as a
  9-field RECORD (zeros, a heap pointer, small integers, string bytes). The Vector glue was handed a pointer whose
  bytes now hold a record.
- **The check build is clean on the same source** (my run, `/tmp/m2-check-chain`, `WAT_DROP_CHECK=1`, seed = 3b-2's
  check compiler → s1 → s2 → s3): s2 compiles everything, `s2 == s3`, 518,767 bytes, no stop. So no count is wrong
  and nothing is dropped twice — a dead object's reuse would have stopped there.
- So a LIVE Vector's bytes were taken by a record's allocation: a freed block was listed under a class LARGER than
  its true block, and an allocation from that list ran past the block's end into its live neighbour. The brief's
  lower-bound rule is violated somewhere.

## R1 — the block that was listed too large

Find it, don't reason about it: in the plain chain's crashing binary (`/tmp/chain-m2f/elf/out/seed.elf`, or
rebuild), under `setarch -R gdb`, take the faulting object's address `P` (rbx at the fault), then re-run with a
hardware watchpoint on `P` and on `P-8` (`watch -l`, after `starti`) logging every write with `$pc` and the value:
the allocation that wrote `9` into the length word is the record; the step before it, its free-list pop, names the
class and the block. Then find who FREED that block, and with what size versus the size its allocator gave it.
Fix the size function at the root (the brief: each kind's size from the SAME function its allocator uses, and an
ambiguous block listed under the SMALLEST it could be). Then the plain chain to a fixpoint, the measurements, and
both verifies.

---

## The census, weighed (2026-10-01)

**Credited, on my own run** (`/tmp/orch-census`: Grok's census-off compiler, one hop with `WAT_HEAP_CENSUS=1`, then the
census compiler compiling the corpus): 12,493,357 allocations, 749,453,600 bytes; 189,396,688 reused from lists;
3,492,848 frees, 208,541,128 bytes; 540,912,472 live at exit; high water 545,653,856 — Grok's figures to 0.1%. The
26 fixtures agree with the census on; `tools/verify.sh` (off) `verify: ok` on Grok's run.

**What the numbers say — more than the SCORE's sentence:**
1. **Fragmentation is not it:** 41,600 bytes sit on the lists at exit. Reuse works (189 MB).
2. **Every count that reaches zero is freed.** The counter named "zero-reached with no free" is placed AFTER the free
   call and counts every zero-reach: 2,180,225 + 862,581 + 431,154 = 3,473,960 ≈ the 3,492,848 frees. Rename it.
3. **About 9 million of the 12.5 million objects never reach zero** — 72% of the bytes allocated are never freed.
4. **Main, with NO frees, peaked at 446 MB**; its region release returned more than our counts do (850 MB rewound over
   the run on 3b-2). So most of what a statement allocates never reaches zero: over-counted, or held somewhere.

The SCORE's sentence (the retired region release carries the rise) is true and is not the lever: the lever is (3).

## R2 — who holds the never-freed bytes

Attribute what never reaches zero to the compiler FUNCTION that allocated it. In the census build only: each block gets
one extra header word holding its allocating site — the user function that called the runtime routine (from the
return address, mapped to a function index through the compiler's own function table); a free subtracts the block's
bytes from that site. At exit, report the top sites by bytes still live, with their function names. Then, for the
top five, say what each is: data the compiler legitimately keeps until exit (its program, its output), or a value
whose count never comes down (a counting defect, F-210's class) — with a minimal shape for each defect. Rename the
mislabelled counter. Measure nothing else this round.

---

## R2, weighed (2026-10-01)

**Credited.** The site word names real functions (`strings.elf`: three sites summing exactly to its live bytes); the
self-compile's site sums close to the routine sums within the extend bytes; nothing unmapped. Five compiler
functions hold 353,998,600 of the 554,353,864 bytes never freed, and none of it is output the compiler keeps: each
`:c::compile` returns nil. The mislabelled counter is now `reached.<cat>.count`.

**Confirmed on the page:** `:c::drop-if-last` (13 call sites) drops an operand ONLY when it is a Symbol. A fresh
temporary handed to a reading built-in — `(= (subs s i (+ i 1)) c)` in `:asm::scan` — is never dropped. 3a's
placement table promised *"a temporary operand of a READING built-in: right after the read"*; only `length` got it.
And `:c::cat-fold`'s later operands are COPIED by `str_cat` (read, never consumed — its own comment), so a temporary
there (`:asm::u8`'s low nibble; `:c::patch`'s tail `subs`) is never dropped either.

## R3 — every temporary a built-in reads is dropped after the read

The rule is uniform now, and it lives in ONE place: since F-188 (a read out of a container is counted) and R16
(`:c::expr-val`), every pointer-typed expression that is NOT a Symbol hands its consumer an OWNED reference — a call's
result, a counted read, an `if` / `let` / `do` whose value flows on. So a reading built-in drops a non-Symbol pointer
operand right after the read; a count-0 literal is skipped by the literal guard. Put that in `:c::drop-if-last` (the
Symbol case stays as it is), and give `:c::cat-fold`'s read operands the same treatment. Say why no reading built-in
can miss it.

**Evidence:** minimal fixtures for the three shapes — `(= (subs s i (+ i 1)) c)`, `(concat (nibble hi) (nibble lo))`,
`(concat (subs code 0 at) hex (subs code from (length code)))` — each agreeing both ways, and each showing its
site's live bytes go to zero in the census. Then the self-compile census again: the five sites' live bytes, the total
live, the high water, and the compiler's peak RSS (`maxrss`, census OFF) against main's ~446 MB. `:c::buf-add` and
`rd/add` (retained Vector versions, the reader's arena) are NOT this round — say only whether they moved.

**Gates:** every `elf/probe/drop-*.wat` (except `drop-cons.wat`), `f209-*`, `m2-region-collision` agree via
`tools/probe.sh` and `WAT_DROP_CHECK=1 tools/probe.sh` — the check build is the gate for a drop placed too early;
native chains plain and check to a fixpoint; `tools/verify.sh`, then `WAT_DROP_CHECK=1 tools/verify.sh`.
