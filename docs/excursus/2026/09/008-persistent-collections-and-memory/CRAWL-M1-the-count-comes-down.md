# CRAWL — excursus 008, M1: a count that comes down, and a drop at zero

2026-09-26, at the-little-wat `43e8053`. The builder's ask: *"we always know when and how much memory we
need - just like in rust - without any form of a GC"*; *"we just consume the least amount necessary"*.

## What is on disk

**The header word IS a count.** Every heap object carries one word at `[p-8]`:
- a fresh allocation writes `:c::heap-arm` = 1 (`elf/lib/runtime.wat:162`, `:845`, `:874`, `:939`, `:1003`,
  `:1115`); a literal in the read-only tail is 0 (`:c::static-str`; stone 2's static closures too);
- `str_cat_own` treats a String as uniquely owned only when its header is EXACTLY 1 (`runtime.wat:99`);
- `vec_conj_own` writes `:c::arm-own` = `0x1_00000001` — count 1 in the low half, a "may grow in place"
  flag in the high half — so any increment clears in-place eligibility (`runtime.wat:555-632`, `:1709`).

**It only ever rises.** `:c::count-hex` has two callers, `:c::share` (`elf/compile.wat:3909`) and
`:c::read-out` (`:4084`); `:c::share`'s prose: *"It never comes down: this is not reclamation, it is a 'has
this ever been shared?' flag"*. No instruction anywhere decrements a header (the runtime's `dec` are loop
counters: `runtime.wat:41`, `:49`, `:1333`, `:1407`).

**The only reclamation is the region release** (`:c::seq`, `compile.wat:4992`; doctrine at `:4839`): a
non-final statement's allocations are freed by restoring `r15` (`push r15; push r15` / `pop r15; pop r15`),
gated by `:c::releasable?` (no transitive `poke`, no `clone`). Sound because a pointer can outlive a
statement only through a `let` slot (scoped) or `poke`. Its own prose names what it cannot do: an
allocation that escapes upward (a return, an argument to the next level) accumulates.

**The compiled Vector is ALREADY persistent** (C1 corrected): flat to `:c::arr-max` = 8, then a 32-way trie
by PATH COPYING (`tree_push` `runtime.wat:753`, `tree_from_arr` `:855`). **Its nodes are allocated with
count 1 and `tree_push` shares the untouched siblings WITHOUT counting them** — a node shared by two
versions says 1.

## What M1 has to answer (the design questions, not yet scored)

1. **Where a reference dies.** Each place a count must come down: a `let` binding leaving scope; a
   parameter at return (unless returned or moved on); a temporary consumed (`(length (concat a b))`); a
   container dropped (its elements' counts come down — records, enums, closures' captures, Vectors, trie
   nodes). The liveness machinery that exists: `:c::live-after` (name-keyed only — excursus 001's DESIGN
   notes an anonymous temporary cannot be asked about), `:c::linear-of`, `:c::dead-after-write?`.
2. **The ownership convention across a call** — does the callee own its arguments or borrow them? Today
   the caller increments when a later use exists (`:c::share` at pushed arguments) and a `linear` parameter
   may be extended in place.
3. **The trie's shared nodes must be counted** in `tree_push` / `tree_from_arr`, or dropping one version
   frees a node another version still holds.
4. **No pauses.** Dropping the last reference to a large structure cascades through every node it owns;
   bounded work per step (a drop queue drained by allocation) is the known answer — Rust itself pays the
   cascade synchronously.
5. **The region release and per-object freeing cannot be two unrelated disciplines.** Once M2 puts freed
   objects on free lists, a region rewind past a freed object leaves a free-list entry pointing into
   rewound memory. Either the region release becomes a special case of the count (everything in the region
   has count reaching zero), or M2's free lists never hold region memory — decided before either is built.
6. **Excursus 001 stone 1** (caller-side release, branch `excursus-001-stone-1`): folded in as a region
   fast path, or retired against M1 (M6).
7. **Cycles** (C4): with immutable values and capture-by-copy, can a cycle form? `poke` can write any
   address — the one door to rule on.

## SETTLED — question 5: one reclamation discipline, the count (2026-09-26)

The builder: *"settle it"*. By the four questions:

| | Obvious | Simple | Honest | Good UX |
|---|---|---|---|---|
| A. regions only (the statement release + 001's caller-side release) | YES | YES | **NO** — cannot free what escapes a statement, incl. every old version a persistent collection leaves | — |
| B. counts + regions as a fast path, free lists never holding memory above the innermost mark | **NO** — correctness hangs on an address-vs-mark rule a reader cannot see | **NO** — two disciplines braided by a cross-rule | **NO** — a rewind skips the decrements of outer objects the region referenced: their counts stay high, they never free, the count lies | — |
| **C. the count, alone** — freed at zero, by a drop the compiler inserts where the last reference dies (Rust's drop / `Arc`, inferred); the bump pointer stays as the allocator's fast path | YES | YES | YES — every free is justified by a count | YES — nothing to annotate; no pause once the cascade is bounded (question 4) |

**C.** Consequences, recorded so they cannot be lost:
- **The region release retires — LAST, not first.** It is the only reclamation today and the compiler
  compiling itself leans on it; it stays until M1's drops cover what it covers, measured by
  `tools/mem.sh` equal or better, and then it is removed. Removing it early blows memory; keeping it
  after is B's lie.
- **M6 answered: excursus 001 stone 1 retires** with the region release — it is the same idea one level
  up. Branch `excursus-001-stone-1` stays as history.
- **Cost is measured, never assumed**: per-object drops cost more than an 8-byte rewind. Where the
  compiler PROVES a value uniquely owned, it drops without a runtime count test (Rust's static drop) —
  the elision path, measured stone by stone.
