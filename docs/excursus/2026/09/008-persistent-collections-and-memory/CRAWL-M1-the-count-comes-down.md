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

## SETTLED — question 2: arguments are OWNED — Rust's move (2026-09-26)

The builder asked whether a census of today's parameters would inform the long-term choice; it would
not — it sizes cost in today's corpus, it does not choose a convention. By the four questions:

| | Obvious | Simple | Honest | Good UX |
|---|---|---|---|---|
| borrow by default (the caller keeps ownership, drops after the call) | YES | YES | YES | **NO** — a borrowed parameter can never grow in place (the caller still holds it): the measured in-place wins loops rely on (F-127, C-151) are lost |
| per parameter (read-only borrows, linear owns), recorded on the `:c::Fn` | YES | **NO** — two conventions and metadata every caller consults, and indirect calls need a third fixed rule | — | — |
| **own, uniformly** — passing hands the value over; a caller that still needs it increments first; the callee drops it at its own last use | YES — Rust's by-value move | YES — one convention, direct and indirect alike | YES | YES — a loop passing its accumulator to itself MOVES it, so in-place growth remains |

**Own.** It is what the compiler half-does already: indirect calls share every argument (the caller
keeping its copy), and a `linear` parameter is owned. M1 makes it uniform and adds the callee's drop.
A census belongs to the elision work later — which drops to prove away first — measured stone by stone.

## Scored — question 7 (`poke`) and C4 (cycles), 2026-09-26

`peek`/`poke` are the COMPILER's intrinsics, not wat's (`elf/compile.wat:45-55`), used only by
`elf/native/thread*.wat` to share integers between `clone`d threads over `mmap`'d memory. `poke`
compiles its value argument with NO type check (`:2502`): it can write a counted object's POINTER into
raw memory, uncounted, and `peek` answers an `i64`, so a heap address can be read back as a number and
poked at.

| | Obvious | Simple | Honest | Good UX |
|---|---|---|---|---|
| leave it untyped | YES | YES | **NO** — counts and memory safety bypassable through it | — |
| remove `peek`/`poke` | YES | YES | YES | **NO** — the native thread programs need shared words |
| **type it: address `i64`, value `i64`; a pointer-typed value refused at compile time** | YES | YES | YES — no wat value ever crosses raw memory, so no heap address is obtainable | YES — every use writes integers |

**Type it.** C4 follows: with `poke` typed, one counted object reaches another only by immutable
construction, and a `fn` cannot capture itself (a `let` binds after its initialiser; recursion is a
`defn`) — **no cycle can form.** Reasoning, not measurement: a probe when M1 is built.

## Scored — question 4 (the drop cascade), 2026-09-26 — the builder to confirm the reading

| | Obvious | Simple | Honest | Good UX |
|---|---|---|---|---|
| deferred (a queue drained a bounded amount per allocation) | **NO** — freed later than the code says | **NO** — queue, policy, allocator interaction | — | — |
| synchronous, recursive (Rust's `Drop`) | YES | YES | YES | **NO** — a 100,000-node `Cons` chain recurses 100,000 deep |
| **synchronous, ITERATIVE** — freed where the value dies, children walked with a worklist | YES | YES | YES — the cost lands on the statement that released it | YES — no stack limit; the program's own forward progress |

**Synchronous, iterative** — on the reading that *"no gc that pauses anything"* rules out a collector
stopping the world at moments the program cannot predict, not a program freeing inline what it just
released. **CONFIRMED by the builder, 2026-09-26:** *"i do not want GC pauses like java or go - it
should be very close to what rust feels like"*.

## The stones M1 becomes (drawn 2026-09-26)

- **Stone 2 — every reference is counted** (BRIEF on disk): `poke` typed; the five runtime routines that
  duplicate pointer slots count them; `tools/copies.sh` gates every bulk copy as `reads.sh` gates reads.
- **Stone 3 — the drop.** The compiler inserts a decrement where each reference dies, by the settled
  ownership rule (question 2): a `let` binding at its last use; an owned parameter at its last use unless
  moved on (a call argument, a return); a temporary right after it is consumed; and a synchronous,
  ITERATIVE drop at zero that decrements what the dead object holds (question 4). Until M2, a zero
  reclaims only what the bump can take back (the youngest allocation); the counts become TRUE, which is
  measurable on its own: in-place growth returns whenever a count comes back to 1. Its BRIEF is drawn
  after stone 2 lands, on a disconfirming probe: that `:c::live-after`'s name-keyed liveness plus the
  ownership rule places every drop — the anonymous-temporary case (001's DESIGN) is the known gap to probe.
- Then M2 (reuse), M4 (pages back), the region release retired, C2/C3 on the counted trie.

## The disconfirming probe for stone 3 — can every drop be placed? (2026-09-27)

**Yes — from what the compiler already knows, with one property carried and one convention added.**

The built-ins split in two (`elf/compile.wat`'s recognised heads): CONSUMING — `conj`, `assoc`, `concat`,
the Vector / record / variant constructors, `fn` (stores captures) — and READING — `length`, `nth`, the
comparisons, `contains?`, `starts-with?`, `byte-*`, `code-point-at`, `subs`, `println`, `assert-eq`, the
`match` scrutinee.

| where a reference dies | where its drop goes | machinery |
|---|---|---|
| a temporary operand of a READING built-in | right after the read — a temporary's lifetime IS its consumer | syntax only: 001's "live-after is name-keyed" gap does not arise |
| a temporary argument to a USER function | moved in; the callee drops it at its own last use | question 2 (owned) |
| a statement's discarded value | right after the statement | syntax |
| a named binding / parameter | after its last use | `:c::live-after` |
| a name dead in one `if` arm | at that arm's start | `live-after`'s arm rule ("from inside an arm, the other one never does") |
| a parameter not passed on at a self tail call | before the jump | `:c::pass-at` / the pass-through analysis |
| a `match` scrutinee | at arm entry, after its parts are counted out | `:c::read-out` |

**The property carried:** `live-after` is name-keyed and counts textual occurrences THROUGH shadowing, and
reads `cond` / `match` clauses as a sequence — it can OVER-count liveness, never under-count. For drops
that means some are placed LATER than Rust would (memory held a little longer), never EARLY (a
use-after-free). Safe by direction; the brief says so, and a probe of a shadowed name shows the lateness.

**The convention added:** a CONSUMING built-in takes ownership of the operand it consumes. Today the
copying paths of `vec_conj`, `slot_set`, `str_cat` leave the source's count untouched; under the settled
rule a copying `conj` consumed one reference to the old container and must drop it after copying. A
runtime row in stone 3.
