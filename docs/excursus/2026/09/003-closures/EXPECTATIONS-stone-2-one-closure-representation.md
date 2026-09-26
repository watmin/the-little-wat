# EXPECTATIONS — excursus 003 stone 2: every function value is a closure object

Written BEFORE the strike.

| # | what | command | expected |
|---|---|---|---|
| 1 | ⛔ function values still work | `tools/probe.sh` on `elf/src/fnref.wat`, `fnvec.wat`, every `elf/probe/fnty-*.wat`, the new fixtures | each agrees or refuses exactly as before |
| 2 | ⛔ one object per function | the two-sites fixture + the emission | one tail entry for that function |
| 3 | ⛔ every moved program explained | `tools/emitted.sh check` + a diff per moved binary | only programs that take a function's address move; each diff is the `movabs` immediate, `ff d0`→`ff 10`, and 16 tail bytes per taken function |
| 4 | ⛔ the gate sees indirect arguments | full `tools/elf-run.sh`; a mutant with `:c::check-fn-args` disabled | exit 0 with `rules: 0`, `types: 0`, `partial 0`; the mutant makes the gate flag the indirect wrong-argument shape |
| 5 | the count guard | `tools/probe.sh` on a function value shared into a Vector twice | agrees; no write to the read-only tail (a static object's count stays 0) |
| 6 | reads | `tools/reads.sh` | `reads: ok`, with R5's classification stated |
| 7 | self-hosts | `tools/bootstrap.sh` | byte-identical fixpoint |
| 8 | cost | the SCORE | instructions and cycles against this commit's compiler at its own fixpoint, each cycle delta against the 1.8% floor |

Runtime prediction: 3–5 hours. Trap-door: the static object's code address is final only in pass 2,
so anything that reads the tail's CONTENT (not its length) in pass 1 would disagree between passes.
