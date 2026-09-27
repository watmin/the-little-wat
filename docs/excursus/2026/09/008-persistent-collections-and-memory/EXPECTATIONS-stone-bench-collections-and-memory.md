# EXPECTATIONS — excursus 008, the bench stone

Written BEFORE the strike.

| # | what | command | expected |
|---|---|---|---|
| 1 | ⛔ every opponent agrees | `tools/bench-coll.sh` | each workload × size: one answer across all six |
| 2 | ⛔ no folded opponent | the table | instructions grow with size for every opponent |
| 3 | ⛔ the clock is honest | `wat.os/clock-ns` twice with work between | monotonic, nanoseconds; the intrinsic refused with a wrong arity |
| 4 | the floors | the table | a noise floor per workload, measured, beside every cycle figure |
| 5 | peak RSS | the table | every opponent, every size |
| 6 | tails | the table | p50 / p99 / p99.9 / max per opponent; Clojure's GC shows or the SCORE says it did not |
| 7 | nothing else moved | `tools/verify.sh` + `tools/emitted.sh` | ok; the corpus byte-identical but for programs using the new intrinsic |
| 8 | the baseline | `BENCH-baseline.md` | committed-ready, with commit and machine |

Runtime prediction: a day. Trap-door: JVM warm-up — report Clojure's tail with and without a warm-up
pass, and say which the table shows.
