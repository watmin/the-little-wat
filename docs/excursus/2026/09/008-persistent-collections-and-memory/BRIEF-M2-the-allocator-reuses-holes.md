# BRIEF — excursus 008 M2: the allocator reuses holes

> The builder: *"grow and shrink as we need ... we just consume the least amount necessary"*. 3b-2 freed only the
> youngest object, and the youngest test almost never holds: a Vector built by `conj` gets each new element allocated
> ABOVE it (`SCORE-stone-3b-2-freeing.md`, F3 — the free fired with the exact size and `r15` stood 352 bytes past it).
> M2 makes ANY dead object's block reusable. Branch `excursus-008-m2` carries 3b-2 (`62dc68b`); M2 builds on it and
> lands both on main together.

## YOU ARE NEW TO THIS — read first

1. `SCORE-stone-3b-2-freeing.md` WHOLE — the per-kind sizes (F1), the one free point (F2), the scratch-register root,
   and F3's measurements (the before-numbers M2 is weighed against).
2. `BRIEF-stone-3b-2-freeing.md` (freeing is self-checking; the check build keeps dead objects poisoned, never reused).
3. `SCOPE.md` (M2, M4, the region release retiring LAST — see below), `CRAWL-M1-the-count-comes-down.md`.
4. `elf/lib/runtime.wat`: `:c::rt-bump` (`:526`) and its callers; the two allocations that bump INLINE instead
   (`rt-prim-read-hex`, `:1599`, and `:1703`); `:c::rt-cap` / `:c::cap-bias` (the power-of-two capacity of a String and
   an owned Vector); the r14 header (`:c::hdr-pending`, `:c::hdr-limit`, `:c::hdr-buf`); `vec_conj_own`, `str_cat_own`
   (in-place growth: inside an owned power-of-two block, or over the heap top when youngest). `elf/compile.wat`: the
   free call 3b-2 placed in `:c::dropchk-hex`; the region release (`:c::seq`, `:6697`-`:6709`, `push r15` / `pop r15`).

## THE CRAWL — what the disk says (orchestrator, 2026-10-01)

- **Threads do not allocate**: a cloning function gets no heap (`elf/compile.wat:718`), so one free-list table needs no
  lock. Say so in the SCORE after checking `elf/native/thread*.wat` and `elf/src/pvec.wat`.
- **The region release cannot coexist with free lists.** It saves `r15` at a statement and restores it after; a block
  freed onto a list inside that span lies in memory the restore hands back to the bump — one block, two owners. So
  **the region release retires in this stone**: counts and free lists now do its job. The settled order said it
  retires LAST; M2 is that point. Measure what it did: the corpus's peak RSS with and without it.
- **One door for allocation**: every allocation goes through the allocator (the two inline bumps included), so no
  allocation can skip the free lists.

## THE CONTRACT

- **Size classes.** Small blocks by exact multiples of 8 (allocations are already 8-aligned), large ones by power of
  two — the classes `:c::rt-cap` already rounds owned Strings and Vectors to. Say where the boundary is and why.
- **Free:** a dead object's block (plain build, at 3b-2's free point) goes onto its class's list — the youngest still
  goes back to the bump, as a fast path. The link lives in the dead block's own count word.
- **Allocate:** take from the class's list first; the bump only when it is empty.
- **A block is listed under a LOWER BOUND of its true size.** Where an object's block can be more than one size (a
  power-of-two block, or one extended over the heap top so it ends at its data), list it under the smallest: a later
  allocation then always fits inside the real block, and at worst a tail is wasted. Never an overlap.
- **The check build reuses nothing** (dead objects stay poisoned, as 3b-2 — detection over economy).
- **The list heads** live at a fixed place reached from r14 (say where, and why it cannot collide with the output buffer).

## THE ROWS

- **M2-1** the classes, the table, the one allocation door. **M2-2** free onto lists. **M2-3** allocate from lists.
- **M2-4** retire the region release (`push r15` / `pop r15` in `:c::seq` and `:c::releasable?`), with the
  before/after measurement above.

## MEASURE — before (main at `5ed2d00`, and 3b-2's branch) and after

Peak RSS (`elf/bench/maxrss.c`) of `drop-3b-recs`, `drop-3b-closure`, `drop-3b-list`, and of the compiler compiling
itself; `tools/bench-coll.sh` against `BENCH-baseline.md` (instructions, cycles against the floors, RSS, tails); the
compiler's instructions compiling the corpus. **The target the builder set: peak RSS FALLS.** If it does not, say
why with evidence, as 3b-2 did.

## GATES

Every `elf/probe/drop-*.wat` (except `drop-cons.wat`) and `f209-*` agree via `tools/probe.sh` and
`WAT_DROP_CHECK=1 tools/probe.sh`; `drop-vec-cycle.wat` natively under `ulimit -s 256`. Native chains seed → s1 → s2
→ s3 to a fixpoint, plain AND check. `tools/verify.sh`, then `WAT_DROP_CHECK=1 tools/verify.sh`, both `verify: ok`.
`tools/emitted.sh check`.

## STOP TRIGGERS

- **STOP-1** — an allocation that cannot go through the one door.
- **STOP-2** — the plain build diverges where the check build agrees: a live block reused — root it (a watchpoint on
  the bytes that changed), never paper it.
- **STOP-3** — a gate you cannot pass at the root. Never re-run a red.

## METHOD

Work on branch `excursus-008-m2` (already checked out). `timeout -s KILL` on every run; no `_`, no catch-all; assert
every text replacement; never read an exit code through a pipe. `tools/verify.sh` ~30 min: `nohup`, then
`timeout 590 tail --pid=<PID> -f /dev/null` repeated. **Commit nothing; write `SCORE-M2-the-allocator-reuses-holes.md`
here AS YOU GO.**
