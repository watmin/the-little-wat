# BRIEF — excursus 008 stone 3b-2: freeing to the bump

> The builder: memory that grows AND shrinks, *"just like in rust"*. Every count is now true (3a, F-210), and at zero
> the glue drops what the object held (3b-1). Nothing gives bytes back yet. This stone does, for the youngest object.

## YOU ARE NEW TO THIS — read first

1. `WEIGH-stone-3b-rescoped.md` — the 3b-2 section and "After 3b-1"; `CRAWL-stone-3b-drop-glue-and-freeing.md` §4-§6.
2. `SCORE-stone-3b-fix-the-discovered.md` (the tag word now carries `:c::vec-flat-own`; the count word is a count) and
   `SCORE-F-210-last-use-per-path.md` (a loop's returned value now reaches its caller with count 1).
3. `elf/lib/runtime.wat`: the layout block (~1882-1990), `rt-vec-new` (records, closures: `len*8 + 16`), `rt-varr-new`
   (flat Vectors: `len*8 + 24`), `rt-node-new` (nodes: fixed), `:c::rt-cap` / `:c::cap-bias` (a String's and an owned
   Vector's power-of-two block, recomputed from the length), `vec_conj_own` and `str_cat_own` (their path that
   extends the YOUNGEST object over the heap top). `elf/compile.wat`: `:c::dropchk-hex` (the one place a count reaches
   zero), the glue bodies.

## THE CONTRACT

When a count reaches zero (plain build), the object's bytes go back if it is the YOUNGEST allocation: its block ends
at `r15`, so `r15` returns to the block's start. Any other dead object stays where it is (M2's allocator, later).
Then the glue drops what it held — in that order, so a child whose block sat just below the parent's becomes the
youngest in turn and frees too: a structure built front to back frees back to front, in one cascade.

**Freeing is self-checking, by construction.** The test is EXACT: `start + size == r15`. A wrong size fails the test
and the object stays — a leak, never an overlap. So each kind's size comes from the SAME function its allocator
uses (one function, two callers), and where an allocator can leave a block of more than one size (a power-of-two
block, or one extended over the heap top so it ends exactly at its data), the test asks each size that allocator can
produce. The one real danger is freeing an object that is NOT dead — a counting defect — and the check build exists
to catch exactly that:

**Under `WAT_DROP_CHECK=1`, nothing is freed**: a dead object stays, poisoned, so any later use of it still stops with
`wat: reference count underflow`. The plain build frees. (Say if you find a way to keep detection AND exercise the
freeing path in the check build; do not trade detection away for it.)

## THE ROWS

- **F1 — the sizes**, one function per kind shared with its allocator: String, record, closure, flat Vector, owned
  flat Vector, trie Vector, trie node; the allocation's START from the pointer (`p-8`, or `p-16` for a Vector).
- **F2 — the free**, at the one place a count reaches zero (plain build only), BEFORE the glue walks the children.
- **F3 — the evidence.** Peak RSS (`elf/bench/maxrss.c`; there is no `/usr/bin/time`) of `drop-3b-recs` and
  `drop-3b-closure` falls (today 11,424 and 8,860 KB). `drop-3b-list` (its type is recursive: no glue until 3b-3)
  may move only by its head cells — report what it does. And the compiler compiling itself: its peak RSS before and
  after (stage 1 under `maxrss`), the measure the builder cares about most.

## GATES

Every `elf/probe/drop-*.wat` except `drop-cons.wat`, and `f209-*`, agree via `tools/probe.sh` and `WAT_DROP_CHECK=1
tools/probe.sh`; `drop-vec-cycle.wat` natively under `ulimit -s 256`. The native chain seed → s1 → s2 → s3 to a
fixpoint (plain AND check — the plain one is now the one that frees). Then `tools/verify.sh` and
`WAT_DROP_CHECK=1 tools/verify.sh`, in sequence, both `verify: ok`. `tools/emitted.sh check`, what moved and why.

## STOP TRIGGERS

- **STOP-1** — an allocator whose block size you cannot express as a function of what the object records.
- **STOP-2** — the plain build diverges from the interpreter anywhere while the check build agrees: that is a live
  object freed — a counting defect; root it (a watchpoint on the bytes that changed), do not paper it.
- **STOP-3** — a gate you cannot pass at the root. Never re-run a red.

## METHOD

`timeout -s KILL` on every run; no `_`, no catch-all; assert every text replacement; never read an exit code through
a pipe. `tools/verify.sh` ~30 minutes: `nohup`, then `timeout 590 tail --pid=<PID> -f /dev/null` repeated. **Commit
nothing; leave the tree dirty. Write `SCORE-stone-3b-2-freeing.md` here AS YOU GO** — each row's result the moment you
have it.
