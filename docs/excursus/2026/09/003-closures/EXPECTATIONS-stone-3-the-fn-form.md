# EXPECTATIONS — excursus 003 stone 3: the `fn` form compiles

Written BEFORE the strike.

| # | what | command | expected |
|---|---|---|---|
| 1 | ⛔ the builder's fixtures | `tools/probe.sh` on `closure-captures`, `closure-nested` (and in `elf-run` once moved) | agree: `126` `86`; `16` `27` |
| 2 | ⛔ captures are counted stores | the Vector fixture; the mutant without `:c::share` at the store | agrees; the mutant diverges |
| 3 | ⛔ the scalarisation trap has no form | the record-parameter fixture | agrees |
| 4 | ⛔ closures of every kind | the function-value, closure-in-closure, loop and no-capture fixtures | each agrees |
| 5 | ⛔ no pre-pass types a lifted body | the diff + the SCORE | `argreg-mark` skips lifted rows; say how that is enforced |
| 6 | ⛔ gates | full `tools/elf-run.sh` | exit 0; `rules: 0`, `types: 0`, `partial 0` |
| 7 | reads | `tools/reads.sh` | `reads: ok`, the capture read classified |
| 8 | emission | `tools/emitted.sh check` | only the new corpus programs are new; nothing existing moves (no existing program contains `fn`) — or each move explained |
| 9 | self-hosts | `tools/bootstrap.sh` | byte-identical fixpoint |
| 10 | cost | the SCORE | instructions and cycles against this commit's compiler at its own fixpoint, the 1.8% floor |

Runtime prediction: a day. Trap-doors: the lifted body's frame gains a slot for the saved closure; a
capture used twice is read twice (each read counted) or bound once — say which; a candidate that is a
global function name must not be captured (it is `fn-val`, stone 2).
