# BRIEF — excursus 008: the heap census — where the memory goes

> M2 is correct and does not do its job: the compiler compiling itself peaks at ~511 MB against main's ~446 MB
> (`SCORE-M2-the-allocator-reuses-holes.md`, the orchestrator's runs). Three causes are plausible and NONE is
> measured — and the last two designs here (3b-2's "cascade", M2's "the counts now do the region release's job")
> were built on claims nobody measured. This stone builds no allocator. It MEASURES, so the next design hits the
> real cost.

## YOU ARE NEW TO THIS — read first

1. `WEIGH-M2.md` and `SCORE-M2-the-allocator-reuses-holes.md` (the free lists, the classes, the retired region
   release, the measurements).
2. `NOTE-stone-3a-landed.md` — how the check build is switched: `WAT_DROP_CHECK=1`, read ONCE per compile
   (`:c::empty-prog` → `:c::Prog/dchk`), and how its stop is reached (`:c::rt-uflow`, a named stop). The census is
   switched the same way.
3. `elf/lib/runtime.wat`: `:c::rt-bump` (the one allocation door, with the free-list take inside it), the r14
   header and its tables (`:c::hdr-small`, `:c::hdr-large`), `:c::rt-print-i64`, the exit path in the entry stub.
   `elf/compile.wat`: `:c::dropchk-hex`, `:c::free-tail-emit` and the per-kind size routines.

## THE CONTRACT

`WAT_HEAP_CENSUS=1` (read once per compile into `:c::Prog`, like `dchk`) makes the compiler emit counting; with it
unset the emitted bytes are IDENTICAL to today (`tools/emitted.sh check` shows 0 moved). The counters live in a
table reached from r14 (beside the free-list tables); at exit the program writes them to stderr as one line per
counter, `census <name> <value>`, so a script can read them. Nothing else changes.

## THE COUNTERS

- **Allocation**, per allocating routine (each `:c::rt-bump` call site is one routine — `vec_new`, `varr_new`,
  `node_new`, `str_cat`, `slot_set`, `subs`, `to-string`, …): count and bytes; and of those, how many were TAKEN
  from a free list (count, bytes) versus bumped.
- **Free**, per kind (String, record, closure, flat Vector, owned flat Vector, trie Vector, trie node): count and
  bytes, split by path — to the bump (youngest), onto a list, or given up (a large block not a power of two).
- **Counts reaching zero with no free at all** (a kind with no free path yet — say which).
- **The heap**: `r15`'s high-water mark (bytes of heap ever touched — what RSS tracks), and at exit: bytes still
  on the free lists (freed, never reused), and live bytes = allocated − freed.

## THE RUNS

1. The compiler compiling itself (a copy of the plain M2 compiler, rebuilt with `WAT_HEAP_CENSUS=1` by two native
   hops — a seed decides the code it emits, so the census build is the SECOND hop's output), and the three
   `drop-3b-*` fixtures.
2. **The counterfactual the M2 brief asked for and nobody ran: the region release's share.** The same census on the
   3b-2 tree (`62dc68b`, region release present, nothing freed but the youngest) PLUS one counter there: bytes the
   region release rewinds (`r15` before `pop r15` minus after). That number is what retiring it gave up.

## THE ANSWER THE SCORE MUST GIVE

For the compiler compiling itself, where the ~65 MB above main goes: live at exit by allocating routine (the leaks),
freed-but-never-reused list bytes (fragmentation), and the region release's rewound bytes. A table, and one
sentence: which of the three causes carries the cost.

## GATES

`tools/emitted.sh check` with the census OFF: 0 moved. Every `elf/probe/drop-*.wat` (except `drop-cons.wat`) and
`m2-region-collision.wat` agree via `tools/probe.sh` with the census off AND on (the census writes to stderr only;
stdout is unchanged). `tools/verify.sh` → `verify: ok`.

## METHOD

Branch `excursus-008-m2` (stay on it). `timeout -s KILL` on every run; no `_`, no catch-all; assert every text
replacement; never read an exit code through a pipe. `tools/verify.sh` ~30 min: `nohup`, then
`timeout 590 tail --pid=<PID> -f /dev/null` repeated. **Commit nothing. Write `SCORE-M2-census.md` here AS YOU GO.**
