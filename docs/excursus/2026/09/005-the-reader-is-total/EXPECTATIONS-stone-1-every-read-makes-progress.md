# EXPECTATIONS — excursus 005 stone 1: the compiler's reader is total

Written BEFORE the strike.

| # | what | command | expected |
|---|---|---|---|
| 1 | ⛔ the stray `)` is refused, fast | `timeout -s KILL 120 tools/probe.sh elf/probe/reader-extra-rparen.wat` | `COMPILE-FAILED` within seconds, naming the line |
| 2 | ⛔ the missing `)` is refused | `tools/probe.sh elf/probe/reader-missing-rparen.wat` | `COMPILE-FAILED`, naming where the `(` opened |
| 3 | ⛔ a mismatched closer is refused | `tools/probe.sh elf/probe/reader-mismatched-closer.wat` | `COMPILE-FAILED`, naming both delimiters |
| 4 | ⛔ no corpus byte moves | `tools/emitted.sh check` | all programs byte-identical |
| 5 | ⛔ standing negatives | full `tools/elf-run.sh` | exit 0; the three reader refusals among its `refuses` rows; `rules: 0`, `types: 0`, `partial 0` |
| 6 | no-progress is unrepresentable | the diff + a mutant | a mutant that lets the atom arm take a delimiter again is refused or fails a row — say which |
| 7 | self-hosts | `tools/bootstrap.sh` | byte-identical fixpoint |
| 8 | the native compiler too | the fixpoint compiler compiling a copy of the tree whose `elf/compile.wat` has one extra `)` (in a scratch copy — never the tree) | exits with the refusal, not exit 70; peak RSS measured with `elf/bench/maxrss.c` |

Runtime prediction: 1–2 hours, mostly the bootstrap and elf-run. Trap-door: the reader has no
`Prog`, so it may not reach the compiler's position machinery directly — row 3 of the brief says
how to find the one way.
