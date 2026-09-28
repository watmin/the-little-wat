# EXPECTATIONS — excursus 008 stone 3b: drop glue per type, and freeing

Written BEFORE the strike.

| # | what | command | expected |
|---|---|---|---|
| 1 | ⛔ the fixtures agree | `tools/probe.sh` on each `drop-*.wat`, check off and `WAT_DROP_CHECK=1` | agree both ways |
| 2 | ⛔ memory comes back | `maxrss` on the three `drop-3b-*` binaries | each below today's (79,884 / 12,200 / 8,984 KB); the list near one list's worth |
| 3 | ⛔ deep drops do not recurse | `drop-3b-list` (100,000 deep) | finishes; the stack stays flat |
| 4 | ⛔ a use after free stops | a mutant dropping one reference early, under the check | a named stop, exit 70 |
| 5 | ⛔ gates | `tools/verify.sh`, then `WAT_DROP_CHECK=1 tools/verify.sh` | both `verify: ok`; zero stops across the corpus |
| 6 | no guess | grep for `rt-drop1` and any `< 0x1000` pointer test in drop code | none |
| 7 | the bench | `tools/bench-coll.sh` vs `BENCH-baseline.md` | every cell: what moved and why; peak RSS falls where objects die young |
| 8 | the compiler | instructions compiling the corpus vs stones 1 and 2 | measured, attributed |

Runtime prediction: several days of rounds. Trap-doors: an `arm-own` vector's capacity (freeing by length
would free too little — harmless — or, if the capacity is miscomputed the other way, too much); the region
release restoring `r15` above a freed object (harmless, crawl §6); a closure whose lifted function captures
nothing (a static object, count 0).
