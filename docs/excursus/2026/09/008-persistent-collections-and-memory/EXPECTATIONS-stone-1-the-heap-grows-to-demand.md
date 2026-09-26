# EXPECTATIONS — excursus 008 stone 1: the heap grows to demand

Written BEFORE the strike.

| # | what | command | expected |
|---|---|---|---|
| 1 | ⛔ past the old ceiling | the >1.9 GB live-data fixture, under `maxrss` | finishes, agrees with the interpreter; peak RSS ≈ what it retained |
| 2 | ⛔ still lazy | `tools/mem.sh` | every program's peak RSS unchanged within noise |
| 3 | ⛔ a refused reservation is named | the forced-failure mutant | the named stop on stderr, exit 70, no fault |
| 4 | ⛔ exhaustion named | the existing `oom()` path | `wat: heap exhausted`, exit 70 |
| 5 | ⛔ the stub's length is fixed | `:c::stub-len` vs the emitted stub | equal |
| 6 | every binary moves only by the stub | `tools/emitted.sh check` + one diff | the same stub delta in each; nothing else |
| 7 | gates | full `tools/elf-run.sh` | exit 0; `rules: 0`, `types: 0` |
| 8 | self-hosts | `tools/bootstrap.sh` | byte-identical fixpoint |

Runtime prediction: 2–3 hours.
