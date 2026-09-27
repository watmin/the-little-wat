# SCOPE — excursus 008: persistent collections and memory that grows and shrinks

**Not drawn yet. Queued behind closures (excursus 003 stones 2 and 3).** This file exists so the
items below cannot be forgotten across compactions -- the builder, 2026-09-26: *"let's stay on course -
just make sure we've got these itemized on disk so we durably don't forget"*.

## The builder's rulings this carries

- **Collections** (2026-09-24): *"in our compiler - all of the collections must be persistent - the
  only thing that differs between our compiler and wat-rs runtime would be perf -- we'll deal with
  this once we have closures"*. Model wat-rs's `PVec` / `PMap` (`src/value/pvec.rs`,
  `src/value/pmap.rs`): an array while small, then an rpds trie, promotion ONE-WAY and UNOBSERVABLE
  (equality and hash over the elements, never the container).
- **Memory** (2026-09-23, restated 2026-09-24): *"my ask is that we grow and shrink as we need - i was
  pretty convinced we always know when and how much memory we need - just like in rust - without any
  form of a GC or similar"*; *"i explicitly do not want a gc that pauses anything.. can we do this
  inline as we make forward progress"*. Excursus 001's DESIGN narrowed this ask ("page release is
  cosmetic", no growth) without saying so; that narrowing is withdrawn.

## What is true today (evidence on disk)

- The heap is ONE fixed mmap of 1.9 GB (`elf/compile.wat` `:c::heap-bytes`) that ABORTS when full:
  `elf/lib/runtime.wat:984`, "the heap is one mmap and it does not grow" -- a runtime panic, which the
  totality ruling forbids.
- The count only ever RISES: `:c::share`'s prose, "It never comes down: this is not reclamation, it is
  a 'has this ever been shared?' flag".
- **CORRECTED 2026-09-26 (the M1 crawl):** the compiled Vector is ALREADY persistent in wat-rs's `PVec`
  shape -- a flat array up to `:c::arr-max` (8, the same threshold as `PVec`), then a 32-way trie with
  PATH COPYING (`elf/lib/runtime.wat` `tree_push`, `tree_from_arr`, `tree_get`). This file said "flat";
  that was written without grepping the runtime. What the trie lacks is reclamation: nodes are shared
  between versions and nothing counts them down. There is no compiled map or set.
- Freeing today is only C-120's statement-boundary release (mark / restore `r15`). Excursus 001 stone 1
  (caller-side release) is HELD on branch `excursus-001-stone-1`.

## The items

| # | item | depends on | notes |
|---|---|---|---|
| **M1** | **Know when memory dies**: a count that comes DOWN and an inline drop at zero -- Rust-like, no GC, no pause | persistent collections (M5): structural sharing is exactly what needs it; rpds is `Arc` | the heart of this excursus; F-188's counted reads are its foundation |
| **M2** | an allocator that REUSES the holes drops leave (size classes, not only a bump pointer) | M1 | pause-free by construction |
| **M3** | **DONE — stone 1**: the heap reserves what the kernel grants, up to RAM + swap, lazily; the stub's `mmap` is checked | -- | the fixed 1.9 GB ceiling is gone |
| **M4** | **shrink**: hand whole free pages back to the OS (`madvise`) | M2 | |
| **M5** | ~~exhaustion is a matchable error~~ — RULED 2026-09-26: the program owns an out-of-memory; exhaustion is the machine's limit, a NAMED stop (no failure value in the language) | -- | *"they own responsibility if they oom - we just consume the least amount necessary"* |
| **M6** | excursus 001 stone 1 (caller-side release) folded in or retired against M1 | M1 | branch `excursus-001-stone-1` needs a rebase and a real gate |
| **C1** | ~~the compiled Vector becomes persistent~~ -- ALREADY IS (array ≤ 8, then a path-copying 32-way trie). What remains: its shared trie NODES reclaimed under M1, and the representation shown unobservable | M1 | corrected 2026-09-26 |
| **C2** | a compiled **map** on the same machinery (array, then HAMT) | C1 | a map `get` is a counted read: `tools/reads.sh` already demands it be classified |
| **C3** | a compiled **set** -- the trie without values | C2 | |
| **C4** | cycles: show that wat's immutable data cannot form one under counting, or say where it can | M1 | stated as unverified since 2026-09-23 |

Order inside the excursus is the crawl's to decide; the dependencies above are the constraint.
