# EXPECTATIONS — excursus 008 stone 3: the drop

Written BEFORE the strike.

| # | what | command | expected |
|---|---|---|---|
| 1 | ⛔ the fixtures agree | `tools/probe.sh` on each | agree with the interpreter |
| 2 | ⛔ no count below zero | the corpus and fixtures under D5's check build | zero underflows |
| 3 | ⛔ an early drop is caught | the one-use-early mutant | a fixture diverges or D5 trips |
| 4 | ⛔ deep drops do not recurse | the 100,000-deep `Cons` drop | finishes; stack flat |
| 5 | ⛔ consuming built-ins | the copying-`conj` fixture | the source's count back to 1, grows in place again |
| 6 | ⛔ gates | `tools/verify.sh` | ok; `reads.sh`, `copies.sh` inside it |
| 7 | the drops are one emission | a grep / tool | every drop site through it |
| 8 | the bench | `tools/bench-coll.sh` vs `BENCH-baseline.md` | every cell: what moved and why; peak RSS falls where objects now die young |
| 9 | the compiler | instructions vs stone 1 and stone 2 | the recovery (or not) of stone 2's +10.22%, attributed |

Runtime prediction: several days. Trap-doors: a drop inside the region release's span (D6); literals
(count 0) reaching drop glue; a closure capturing itself through a `defn` (recursion is a function, not a
value — say so if a shape contradicts it).
