# BRIEF — excursus 008: the two retention sites, `:c::buf-add` and `rd/add`

> Freeing and reuse landed (`NOTE-M2-landed.md`): the compiler's peak RSS is a third below the old main's. The
> census still attributes ~115 MB to `:c::buf-add` and ~76 MB to `rd/add` that never comes down — the largest
> memory left on the table, first in the builder's order.

## YOU ARE NEW TO THIS — read first

1. `NOTE-M2-landed.md`, then `WEIGH-M2.md` (the census rounds) and `SCORE-M2-census.md` R2 / R3 (the site word,
   the attribution table, the R3 rule).
2. `elf/compile.wat`: `:c::buf-add` (`(:c::Buf :ch (conj (:c::Buf/ch b) s) :n …)`), `:c::buf-str`, every caller of
   `:c::buf-add` (7), the `:c::Out` record and how a compile threads it to the end; `:c::compile-as` (where the
   reader's state `st` and the program `pg` are bound, and where they should die). `elf/lib/reader.wat`: `rd/add`
   (conjs a `:rd::Node` onto `:rd::St`'s arena).
3. `elf/lib/runtime.wat`: `tree_push`, `rt-node-copy` (path-copying, `count-span`), the trie-node glue
   (`elf/compile.wat`, `:c::node-glue-body`).

## WHAT IS KNOWN, AND WHAT IS NOT

Each line of both functions looks right on the page: a counted field read, a copying `conj` that drops its source,
`b` dropped at its last use. So the leak is not where the census CHARGES it (the allocating site), but wherever the
LAST holder of those versions — an `:c::Out`, a `:c::Buf`, an `:rd::St`, the `:c::Prog` — fails to reach zero. Find
the holder; don't reason about it.

## THE WORK

- **R1 — the holder.** Extend the census (census build only) so it names, for a leaked block, what still holds it.
  One way: at exit, for the top sites, report the live counts by KIND of what those sites allocated, and the live
  records by record type (`rec:…` — how many `:c::Out`, `:c::Buf`, `:rd::St`, `:c::Prog` are still live at exit,
  when each `:c::compile` returns nil and should leave none). A record type with live instances at exit is a holder
  whose count never came down; take ONE instance (its address from the census) and find its history with a gdb
  hardware watchpoint on its count word (`setarch -R`), as the 3a and M2 rounds did.
- **R2 — the root**, as a class, with a minimal fixture that agrees both ways and whose census shows the holder at
  zero live after the fix.
- **R3 — the evidence.** The census self-compile again (both sites' live bytes, total live, high water), and the
  compiler's peak RSS and cycles on main's tree, against `NOTE-M2-landed.md`'s table (298,232 – 298,460 KB;
  3.400 – 3.421 B cycles). Measure each the same way: three runs, `/tmp/maxrss`, `perf stat -e
  instructions:u,cycles:u` pinned with `taskset -c 2`, the core counters.

## GATES

Every `elf/probe/drop-*.wat` (except `drop-cons.wat`), `f209-*`, `m2-region-collision`, `r3-*` agree via
`tools/probe.sh` and `WAT_DROP_CHECK=1 tools/probe.sh`; native chains plain and check to a fixpoint; `tools/verify.sh`,
then `WAT_DROP_CHECK=1 tools/verify.sh`.

## STOP TRIGGERS

- **STOP-1** — the holder is data the compiler legitimately keeps to the end (say what, and why it must).
- **STOP-2** — the check build stops at a root you cannot name. **STOP-3** — a gate you cannot pass at the root.

## METHOD

On main (`1392b08`), a new branch is not needed: the tree stays dirty, **commit nothing**. `timeout -s KILL` on every
run; no `_`, no catch-all; assert every text replacement; never read an exit code through a pipe; never re-run a red;
no git in the holon root; no worktrees. `tools/verify.sh` ~30 min each: `nohup`, then `timeout 590 tail --pid=<PID>
-f /dev/null` repeated. Write `SCORE-retention-sites.md` here AS YOU GO. Then `pulsare_yield kind=scored`.
