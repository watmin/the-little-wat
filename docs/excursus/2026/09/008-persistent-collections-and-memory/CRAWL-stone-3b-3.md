# CRAWL — excursus 008 stone 3b-3: the worklist, recursive types, and closure glue

2026-10-03, against `6ae2fb7` (the retention sites landed at `2b9a572`; notes since). The orchestrator's read before
the strike is drawn. `CRAWL-stone-3b-drop-glue-and-freeing.md` §2–§3 drew this in outline on 2026-09-28; this file
checks that outline against today's tree, corrects one claim of the SCORE that followed it, and sizes the work into two
strikes.

## What the disk says

**Glue is a nested `call`, bounded only by type nesting.** A glue body takes the dying object in `rax`, holds it in `rbx`
(`:c::rec-glue-body`, `:c::henum-glue-body`, `:c::vec-glue-body`, `elf/compile.wat` ~5476–5560), and drops each pointer
child with `:c::emit-drop`, i.e. `:c::dropchk-hex` (`:4485`). There, a count that reaches zero runs `push rax; call
glue; pop rax`, then the free routine (`:c::free-target`), then (check build) the poison. So a child's glue runs INSIDE
its parent's frame. Glue saves `rbx`/`r12`/`r13` and clobbers `rax`, `rdx`, `r8`–`r11`.

**A cyclic type gets no glue at all.** `:c::gtys-from-shapes` keeps a shape only when `(not (:c::cyclic? t pg))`;
`:c::shape-children` walks `rec:`, `henum:` and (F3) `vec:` edges. So `:user::L` in `elf/probe/drop-3b-list.wat` drops
its head cell (decrement, free) and nothing below it: one cell freed, 99,999 leaked, every round.

**A closure is freed but its captures are not.** `closize` (`:5373`) recovers a closure's size from the creation site
(a cascade over every lifted function with captures, matching the closure's code word), so the object's bytes come
back. No glue drops what it captured: `:c::glue-census` has no `fn:` entries, and `shape-children` does not walk `fn:`.

**Where global mutable words live.** `r14` addresses the runtime header (`elf/lib/runtime.wat` ~2660–2790):
`hdr-pending`, `hdr-limit`, the small and large free-list tables (M2), then the census tables only when
`WAT_HEAP_CENSUS=1`, then the buffer. Anonymous `mmap` pages come zeroed, so a new zero-means-empty word needs no init.

**The check build's two guards.** The decrement (`:c::dropchk-hex`): `cmp [rax-8], poison; je uflow`, then
`cmp [rax-8], 1; jb uflow`. The increment (`:c::countchk-hex`, `:4393`): `cmp [rax-8], poison; je uflow` only. Poison
is −1 (`:c::poison-count`). A live count is ≥ 0. The owned-flat marker is `2^32 + 1`, which is positive.

**Heap pointers sit below 2^47.** The heap is an anonymous `mmap` with no address hint (`compile.wat:9257`). On
x86-64 Linux that lands in the lower half, so bits 47–63 of a heap pointer are zero.

## The probes (run 2026-10-03; binaries built as `tools/probe.sh` builds them)

| fixture | answer (native = interpreter) | peak RSS today, KB (3 runs, `taskset -c 2`) | `ulimit -s 256` |
|---|---|---|---|
| `elf/probe/drop-3b-list.wat` — `L = Nil \| Cons(k, L)`, 100,000 deep, ×20 | `99999000000` | 78,168 · 79,376 · 79,784 | ok |
| `probe-3b3-tree.wat` — `T = Leaf \| Node(k, Vector<T>)`, 100,000 deep, ×20 | `99999000000` | 140,920 · 141,572 · 142,496 | ok |
| `probe-3b3-mutual.wat` — `A = AEnd \| AStep(k, B)`, `B = BEnd \| BStep(k, A)`, ×20 | `99999000000` | 78,564 · 78,952 · 79,728 | ok |
| `elf/probe/drop-3b-closure.wat` — a closure capturing a String, ×100,000 | `1188895` | 5,820 · 6,096 · 6,492 | ok |
| `probe-3b3-closure-chain.wat` — one creation site, each closure capturing the last, 100,000 deep, ×20 | `20` | 47,916 · 48,088 · 48,412 | ok |

Each runs under a 256 KB stack today only because nothing below the first object is dropped. A glue that recursed
would push one frame per level: 100,000 frames of even 16 bytes is 1.6 MB, so **the 256 KB run tells a flat drop from
a recursive one.** One list is 100,000 cells of 5 words, about 4 MB. Twenty rounds leak about 80 MB, which is what the
table shows.

## What this settles

1. **Closures need the worklist too. This corrects `SCORE-stone-3b-drop-glue-and-freeing.md`'s claim that "a
   closure's captures are fixed per creation site", offered as why closure glue is bounded.** It fixes the BREADTH (which
   captures, of which types), not the DEPTH. `probe-3b3-closure-chain.wat` builds 100,000 closures at ONE site, each
   holding the previous one, and the compiler compiles it (both agree on `20`; a 1,000-deep call of the same chain
   agrees on `1000`). A closure's glue that dropped its captures with a nested `call` would recurse as deep as the data.
   So `fn:` is cyclic by construction, and every closure goes through the worklist.

2. **One mechanism, two clients. The worklist lands first; closures follow on it.** The worklist is new code with
   three users: self-recursive types, mutually recursive ones, and types recursive through a Vector. Closure glue
   (the glue word before a lifted function's code, `SCORE-stone-3b-…` §G2) is a FOURTH user that also needs new
   placement. Strike **3b-3a** is the worklist and the recursive types. Strike **3b-3b** is closure glue on top of it.
   3b-3b's brief is drawn after 3a is weighed, against the mechanism as built rather than as sketched.

3. **The worklist shape (3b-3a).** It is intrusive and uses no allocation and no stack growth (`CRAWL-…-freeing.md`
   §3, the builder's "drops synchronous and iterative"). A dead object's count word is free the moment it reaches
   zero, so a dead object waiting to be walked is linked through it:
   - **Members.** Every type `t` with `(:c::cyclic? t pg)`, of any kind (`rec:`, `henum:`, `vec:`), gets an index
     `k`. Two header words, zero-filled: the list head and a busy flag.
   - **A pending word** is `(1 << 63) | (k << 47) | next`, where `next` is the following pending object, or 0. It is
     NEGATIVE: bit 63 is set.
   - **The drop site does not change shape.** `:c::glue-addr t` for a member answers a small STUB (`k` into a
     register, jump to the shared `pend`). So every existing drop site, and every glue body's drop of a member child,
     reaches the worklist through the code it already emits. A member's REAL glue body is a separate table entry that
     only the drain calls. At a member's drop site, `:c::dropchk-hex` emits no free and no poison, because the drain
     owns both.
   - **`pend`** links the object at the head, and returns if busy. Otherwise it sets busy and DRAINS: pop the head,
     decode `k` and `next`, run body `k`, then free (plain build) or poison (check build), and repeat until empty.
     Then it clears busy. A non-member glue that runs during the drain (say, a record inside a list cell) and drops a
     member hits the stub, links it and returns: nesting stays flat. Bodies run with busy set, so a body never
     starts a second drain.
   - **Order.** Glue before free, as M2's STOP-3 fixed. The list was built front to back, so each popped cell is the
     youngest, and the bump rewinds cell by cell (`CRAWL-…-freeing.md` §4's cascade).

4. **The check build: "not a live count" becomes one shape, negative.** Poison (−1) is negative, and so is a pending
   word. Both guards become a single SIGNED compare. The decrement becomes `cmp [rax-8], 1; jl uflow`, which stops 0,
   poison and pending. The increment becomes `cmp [rax-8], 0; jl uflow`, which stops poison and pending; a literal's
   0 passes on to the literal guard. A stray decrement of an object waiting in the worklist then stops with
   `wat: reference count underflow` instead of silently corrupting the link. Two sentinels compared by equality
   become one class refused by sign. That is the top rung (`extirpare`): the encoding is chosen so the guard needs no
   list of sentinels.

## Found on the way, outside 3b-3

**F-211: a mutual tail call is not a loop natively.** `probe-f211-mutual-tail.wat`, `even?`/`odd?` at 10,000,000:
the interpreter prints `even`, and the native binary segfaults in 1.4 s (exit 139, core dumps off). The compiler
eliminates SELF tail calls only (`:c::tail-call?`, `elf/compile.wat:2443`, matches the function's own name). wat
eliminates mutual ones to 10,000,000 (EOPL, F-105's row). A valid program crashes: recorded in `FINDINGS.md`. It is not
on 3b-3's path. `probe-3b3-mutual.wat` sums with a SELF tail loop so it measures the drop, not this.

## Out of scope — rejected for 3b-3

Pages back to the OS (M4) · widening `:c::and-name-dead?` (the performance stone) · F-211 · maps and sets.
