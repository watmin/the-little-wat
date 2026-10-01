# BRIEF — F-210: a last use is the last on its PATH

> `FINDINGS.md` `### F-210`. A value a loop builds and returns from one arm of an `if` comes out with one count
> too many, so it is never freed — exactly the values freeing (3b-2) exists for. Fixed before 3b-2.

## YOU ARE NEW TO THIS — read first

1. `FINDINGS.md` `### F-210`, `### F-208` (one evaluation order), and `SCORE-stone-3b-fix-the-discovered.md` (the
   gdb evidence: `drop-vec-cycle.wat`'s tree reaches its drop with count 2).
2. `WEIGH-stone-3-rescoped.md`, rounds 4, 7 and 9 (the box used at the call; `:c::expr-val`; the read-only
   pass-through rule) — every rule there must still hold.
3. `elf/compile.wat`: `:c::eval-seq`, `:c::last-walk` / `:c::last-kids` / `:c::last-note` (they build
   `:c::Prog/lasts`, one node per name), `:c::last-use?`, `:c::last-node`, `:c::live-after` (already path-aware for
   an `if`: "from inside one arm, the other arm cannot run"), `:c::arm-dead?` / `:c::drop-arm`, `:c::share`,
   `:c::expr-val`, `:c::ronly?`.

## THE CONTRACT

A use of a name is its LAST when no read of that name can follow it on any path. The two arms of an `if` (each
clause of a `cond`, each arm of a `match`) are alternatives: neither follows the other. `:c::Prog/lasts` becomes
the SET of such uses, computed once per function by ONE backward walk over `:c::eval-seq`'s order — carrying "is
this name read later on this path", splitting at a branch and joining after it (live if live on either arm).
`:c::last-use?` asks membership. Shadowing stays name-keyed: a name re-bound inside reads as still live — late,
never early.

## THE ROWS

- **L1 — the set, one walk.** As above; `:c::last-node` (one node) goes, or says what it now means.
- **L2 — every consumer still holds.** The moves (`:c::share`, `:c::expr-val`, `:c::tail-share`), the drops at last
  use, `:c::drop-arm` (a name dead in an arm — disjoint from a last use IN that arm), the read-only pass-through
  rule. Say for each why one drop per path still holds.
- **L3 — the evidence.** A loop that builds and returns a value reaches its caller with count 1 (gdb on `[p-8]`, the
  way the F-210 evidence was taken). Then `elf/probe/drop-vec-cycle.wat`: natively under `ulimit -s 256` it agrees;
  and the MUTANT that reverts F3 (`vec:` out of `:c::shape-only` and `:c::shape-children`) now OVERFLOWS — F3 is
  load-bearing at last.

## GATES

Every `elf/probe/drop-*.wat` except `drop-cons.wat`, and the `f209-*` fixtures, agree via `tools/probe.sh` and
`WAT_DROP_CHECK=1 tools/probe.sh`. Then `tools/verify.sh` and `WAT_DROP_CHECK=1 tools/verify.sh`, in sequence, both
`verify: ok`. `tools/emitted.sh check`: what moved and why (fewer increments is the expected direction).

## STOP TRIGGERS

- **STOP-1** — a consumer whose correctness needs the OLD one-node answer (say which and why).
- **STOP-2** — the check build stops at a root you cannot name. **STOP-3** — a gate you cannot pass at the root.

## METHOD

`timeout -s KILL` on every run; no `_`, no catch-all; assert every text replacement; never read an exit code
through a pipe. A `tools/verify.sh` takes ~30 minutes (stage 0 alone ~15-25): start it with `nohup`, wait with
`timeout 590 tail --pid=<PID> -f /dev/null` repeated. **Commit nothing; leave the tree dirty.** Write
`SCORE-F-210-last-use-per-path.md` here AS YOU GO — append each row's result the moment you have it, so a cut-off
leaves the evidence on disk.
