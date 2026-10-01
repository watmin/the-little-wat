# BRIEF — excursus 008: the discovered defects, fixed before 3b-2

> The builder, 2026-09-30: *"i'm not finding it acceptable that we have these issues - feels catastrophic"*.
> A compiler that crashes on a valid program, glue that would recurse without bound, and a count word that
> carries a mark instead of a count. All four are fixed before freeing (3b-2) is built on top of them.

## YOU ARE NEW TO THIS — read first

1. `WEIGH-stone-3b-rescoped.md` — the sections "3b-1 landed" and "After 3b-1".
2. `FINDINGS.md` `### F-209`.
3. `CRAWL-stone-3b-drop-glue-and-freeing.md` (object layouts), `NOTE-stone-3a-landed.md` (the check build).
4. `elf/compile.wat`: `:c::enum-tier`, `:c::sole-payload-ty`, `:c::enum-prefix` (~1017-1030), `:c::cyclic?`,
   `:c::shape-children`, `:c::dfs-reaches`, `:c::glue-census`, the two comments at ~4574 and ~4976.
   `elf/lib/runtime.wat`: `vec_conj_own` (`:614`-`:700`, paths 1-4; `:674`, `:694` write `:c::arm-own`),
   `:c::arm-own` / `:c::heap-arm` / `:c::vec-flat` / `:c::vec-tree` (~1916-1955), and every routine that tests the
   tag word `[p-16]` (`vec_conj`, `tree_get`, `nth`, `length`, …).

## THE ROWS

- **F1 — F-209: the compiler compiles a tier-1 enum whose payload is a Vector of itself.** `:c::enum-tier`
  needs the payload's KIND (pointer, and not possibly a unit tag), not its full spelling; asking for the
  spelling recurses through the enum's own type. Decide the tier from the kind. `elf/probe/f209-tier1-self-vec.wat`
  compiles and agrees; then a version that BUILDS such a value, matches it and drops it agrees both ways.
- **F2 — the count word is a count.** `vec_conj_own` marks an owned power-of-two block by writing `:c::arm-own`
  (`0x1_00000001`) into the COUNT word, so such a Vector's last drop leaves `0x1_00000000`, not zero, and its glue
  never runs (a leak), and an increment of that word reads as a mark again. Move the mark out of the count word —
  into the Vector's tag word `[p-16]` (today `0` flat, `1` trie), as a third value for "flat, in an owned
  power-of-two block" — and make every reader of the tag word treat it as flat. The count word then holds only a
  count: `1` when created, and path 2's test becomes "count 1 AND the owned-block tag". Show a Vector grown in place
  reaches zero and its glue runs (a fixture whose elements are Strings; under `WAT_DROP_CHECK=1` the poison proves it).
- **F3 — a type recursive THROUGH a Vector is recursive.** In `:c::cyclic?`, `vec:T` is an edge to `T` (and any
  other container element type the same way). Such a type gets no glue until 3b-3's worklist: its references leak,
  late, never early. List which types change (`:user::Val` in `matchval.wat` is one).
  `elf/probe/drop-vec-cycle.wat` (a 2,000,000-deep tree through Vectors, dropped whole) must agree AND run natively
  with `ulimit -s 256` AFTER F2 — F2 removes the leak that masked F3 today.
- **F4 — no bare 13.** The two comments carry the derivation (32-way nodes from `:c::node-arity`: 5 bits a
  level; a 63-bit length; so at most ⌈63/5⌉ levels, log₃₂ of the length in practice) — and the first one's wrong
  argument about Vectors goes, replaced by F3's rule.

## GATES

Every `elf/probe/drop-*.wat` (except `drop-cons.wat`) and `f209-tier1-self-vec.wat` agree via `tools/probe.sh` and
`WAT_DROP_CHECK=1 tools/probe.sh`; `drop-vec-cycle.wat` natively under `ulimit -s 256`. Before the long verifies,
the native chain seed → s1 → s2 → s3 → s4 under `WAT_DROP_CHECK=1` runs clean to a fixpoint (a `--fast` seed alone
decides stage 1's code — `probe-3a-twohop-step.sh`). Then `tools/verify.sh` and `WAT_DROP_CHECK=1 tools/verify.sh`,
in sequence, both `verify: ok`.

## STOP TRIGGERS

- **STOP-1** — F2 needs a reader of the tag word that cannot be found by search (name the search you ran).
- **STOP-2** — the check build stops at a root you cannot name.
- **STOP-3** — a gate you cannot make pass at the root. Never re-run a red.

## METHOD

`timeout -s KILL` on every run; no `_`, no catch-all; assert every text replacement; never read an exit code
through a pipe; a dead object's history via a gdb hardware watchpoint on its `[p-8]` (ASLR off). **Commit nothing;
leave the tree dirty.** Write `SCORE-stone-3b-fix-the-discovered.md` here.
