# BRIEF — excursus 008 stone 3b: drop glue per type, and freeing

> The builder: memory *"very close to what rust feels like"*; *"i do not want GC pauses like java or go"*.
> 3a brought every count DOWN at the right place. At zero, today, nothing happens. This stone is what happens
> at zero: the object drops what it holds, and gives its bytes back.

## YOU ARE NEW TO THIS — read first

1. `docs/excursus/2026/09/008-persistent-collections-and-memory/CRAWL-stone-3b-drop-glue-and-freeing.md` — WHOLE:
   every object's layout, why the children's counts are true, the census, and §1-§6, the decisions this brief
   builds on.
2. `NOTE-stone-3a-landed.md` — what 3a is (one emission, `:c::emit-drop` → `:c::drop-hex`; the check build
   `WAT_DROP_CHECK=1`, `:c::Prog/dchk`, `wat: reference count underflow`).
3. `BRIEF-stone-3-the-drop.md` — D1 and D4, which this stone delivers.
4. `elf/lib/runtime.wat:1882-1955` (the layout block), `rt-node-new` (`:747`), `rt-node-copy` (`:768`),
   `vec_conj_own` (`:614`, the youngest-object test), `:c::rt-drop1` (`:1704`, retires); in `elf/compile.wat`,
   `:c::emit-drop`, `:c::drop-hex`, `:c::close-form`, `:c::ptr-mask`, `:c::enum-tier`.

## THE CONTRACT

When a decrement takes a count to ZERO, the object's DROP GLUE runs — synchronously, in a loop, never
recursing on the data — and drops every reference the object holds with that reference's own glue; then the
object is FREED: if it is the youngest allocation (it ends at `r15`), `r15` comes back to its start; otherwise
its bytes stay where they are (M2's allocator reuses them later). A count-0 literal is never dropped.

## THE ROWS

- **G1 — glue per type, emitted by the compiler.** One routine per pointer type that reaches a drop site
  (the census: 55 types). `str`: nothing held. `rec:R`: each pointer field by `R`'s mask, with its field type's
  glue. `vec:T`: flat — each element when `T` is a pointer; trie — the root node, whose glue drops child nodes
  (interior) or elements (leaf, `T`'s glue); the node walk is by level, depth ≤ 13, so that recursion is
  bounded. `henum:E`: the payload of the live variant, by tag. The decrement at a drop site calls the glue only
  when the count reaches zero — the fast path is still one `dec`.
- **G2 — closures by creation site.** A closure object `[count][code][cap…]` does not say what it captured
  (crawl §2). Each lifted function that captures gets a glue routine from its `Cap` list, reachable from the
  closure's `code` word (e.g. one word before the lifted function's entry — say what you choose and why). A
  static closure (count 0) is never dropped.
- **G3 — iterative, zero allocation, flat stack** (crawl §3). A dead object's count word is free: link pending
  objects through it. A self-recursive type needs only the link; mutually recursive types add which member,
  in the pointer's unused high bits. The 100,000-deep list drops in a loop.
- **G4 — freeing to the bump** (crawl §4). The object's size is the size the allocator gave it — for an
  `arm-own` vector, its capacity. A structure freed parent-first cascades.
- **G5 — the check build sees a use after free** (crawl §5). Under `WAT_DROP_CHECK=1`, a freed object is
  poisoned (its count word set to a value no live object has) and every increment and decrement refuses it
  with a named stop, exit 70. Show it: a mutant that drops one reference early must STOP under the check.
- **G6 — `:c::rt-drop1` retires**, and nothing guesses a pointer from its value.

## THE FIXTURES — committed, each agrees with the interpreter TODAY (before 3b)

| fixture | answer | peak RSS today |
|---|---|---|
| `elf/probe/drop-3b-list.wat` — 20 rounds of a 100,000-deep list, built, summed, dropped | `99999000000` | 79,884 KB |
| `elf/probe/drop-3b-recs.wat` — 50 rounds of a Vector of 2,000 records of Strings | `744500` | 12,200 KB |
| `elf/probe/drop-3b-closure.wat` — 100,000 closures each capturing a String | `1188895` | 8,984 KB |

After 3b: each still agrees, both ways (`tools/probe.sh`, `WAT_DROP_CHECK=1 tools/probe.sh`), and its peak
RSS falls — the list to about one list's worth. Measure with `elf/bench/maxrss.c` (there is no
`/usr/bin/time`); build the native binary as `tools/probe.sh` does.

## MEASURE

`tools/bench-coll.sh` against `BENCH-baseline.md` (instructions, cycles against the floors, peak RSS, tails) —
what moved and why; and the compiler compiling the corpus, instructions against stone 1's and stone 2's figures
(the SCOREs of those stones).

## STOP TRIGGERS

- **STOP-1** — a type reaches a drop site whose glue cannot be named (a free type, or a shape the crawl did not
  see). Report it.
- **STOP-2** — the check build stops (underflow or use after free) somewhere whose root is not a placement or
  glue defect you can name.
- **STOP-3** — a recursive shape cannot drop in a loop within G3's design. Report the shape.
- **STOP-4** — a red or a gate above zero you cannot fix at the root. Capture it; never re-run it.

## OUT OF SCOPE

The allocator that reuses holes (M2) · pages back to the OS (M4) · retiring the region release · maps and sets.

## METHOD

`timeout -s KILL` on every run; no `_`, no catch-all; assert every text replacement; never read an exit code
through a pipe. Gates: `tools/verify.sh` AND `WAT_DROP_CHECK=1 tools/verify.sh`, both `verify: ok`, run in
sequence (both write `elf/out/`). To measure an instrumented compiler, go two native hops from a seed (a
`--fast` seed decides stage 1's code): `probe-3a-twohop-step.sh`. To find who takes a count to zero, a gdb
hardware watchpoint on the object's `[p-8]` (ASLR off). **Commit nothing; leave the tree dirty.** Write
`SCORE-stone-3b-drop-glue-and-freeing.md` here.
