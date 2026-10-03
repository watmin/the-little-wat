# EXPECTATIONS — excursus 008 stone 3b-3a: the worklist

Written 2026-10-03, before the strike, against `6ae2fb7`. The baselines are the crawl's (`CRAWL-stone-3b-3.md`, the
probe table). Peak RSS uses `elf/bench/maxrss.c`, three runs, `taskset -c 2`. The compiler figures use main's `956b4bb`
tree as input, the way `NOTE-M2-landed.md` and `WEIGH-retention-sites.md` round 3 measured.

| # | what | the command that checks it | expected |
|---|---|---|---|
| 1 | Every fixture agrees, both builds | `tools/probe.sh` and `WAT_DROP_CHECK=1 tools/probe.sh` on every `elf/probe/drop-*.wat` (not `drop-cons`), `f209-*`, `m2-region-collision`, `r3-*` | all `agree`. list, tree and mutual print `99999000000`; closure `1188895`; closure-chain `20` |
| 2 | The list comes back | maxrss on `drop-3b-list` | ≤ 16,000 KB, about one list (today 78,168 – 79,784) |
| 3 | The tree comes back: a cycle through a Vector | maxrss on `drop-3b-tree` | ≤ 28,000 KB (today 140,920 – 142,496) |
| 4 | Mutual recursion comes back | maxrss on `drop-3b-mutual` | ≤ 16,000 KB (today 78,564 – 79,728) |
| 5 | Closures are not this strike | maxrss on `drop-3b-closure`, `drop-3b-closure-chain` | unchanged within noise (5,820 – 6,492; 47,916 – 48,412). 3b-3b moves them |
| 6 | The drop is a loop | each of the five under `ulimit -s 256` | exit 0, the same answer. A recursive glue would need about 100,000 frames, more than 1.6 MB |
| 7 | Nothing is left pending or busy | `WAT_HEAP_CENSUS=1` on `drop-3b-list` | the list's records: frees ≈ allocations (within one list's worth held at exit) |
| 8 | The check build catches a pending object | the W5 mutant, check build | `wat: reference count underflow`, exit 70 |
| 9 | The signed guard keeps every old catch | the round-3 mutant (a second decrement of a poisoned object), check build | the same stop, exit 70 |
| 10 | Emitted-code fixpoint | native chain seed → s1 → s2 → s3, plain and check | s2 == s3, byte for byte, both builds |
| 11 | The gates | `tools/verify.sh`, then `WAT_DROP_CHECK=1 tools/verify.sh` | `verify: ok` twice. Report both fixpoint sizes (today 603,509 / 798,499): plain grows by the new routines, check moves by the guard change |
| 12 | The compiler costs the same | peak RSS, then `perf stat -e instructions:u,cycles:u`, the 603,509-byte successor compiling `956b4bb`'s tree | RSS within noise of 56,332 – 57,220 KB; instructions within +1% of 12.737 – 12.744 B (no compiler type is a member, so `pend` never runs) |
| 13 | rsp and reads gates | `tools/rsp.sh`, `tools/reads.sh` | green |

**Runtime prediction:** 3–6 hours of strike, plus two verifies (~30 min each) and the native chains.

**Trap doors:**
- **The vec member's free.** `freevec` reads the tag word. `pend` overwrites `[p-8]`, which for a Vector is the count
  word, not the tag (`[p-16]`). Check that against `:c::varr-ptr` before you trust it: M2's STOP-3 was exactly a
  free-list link clobbering a Vector's tag.
- **`:c::gtys-from-vecs` keeps every `vec:X` today.** A cyclic `vec:T` left there as an ordinary glue target would call
  `T`'s stub from inside a non-member body. That works, but it splits one cycle across two mechanisms. Make a cyclic
  `vec:T` a member like the rest.
- **Busy across a non-member body.** A record glue reached from a member body drops a member field through its stub.
  The stub must return without draining, or the drain nests.
- **Row 12's prediction is wrong if STOP-4 fires.** Then the compiler's own drops start using the worklist, and the
  instruction count moves.
