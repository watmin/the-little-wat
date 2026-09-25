# EXPECTATIONS — excursus 002 stone 5b: destructure an aggregate by its field names

Written BEFORE the strike, at the commit adding this file (after `7cad1f3`, stone 5).

| # | what | command | expected |
|---|---|---|---|
| 1 | ⛔ a variant destructures | `tools/probe.sh elf/probe/destructure-variant.wat` | agree `3 3 0` |
| 2 | ⛔ a record destructures | `tools/probe.sh elf/probe/destructure-record.wat` | agree `39` |
| 3 | ⛔ the parent is refused | `tools/probe.sh elf/probe/destructure-parent.wat` | COMPILE-FAILED, naming the destructure |
| 4 | ⛔ every field read counted | `tools/reads.sh` | `reads: ok` |
| 5 | ⛔ both gates at zero | `tools/elf-run.sh` | `rules: 0 conflicts`, `types: 0 type conflicts`, `refined 0`, `elf-run: ok` |
| 6 | nothing else moved | `tools/emitted.sh` | no corpus program uses `{:keys}` today, so 0 moved |
| 7 | self-hosts | `tools/bootstrap.sh` | byte-identical fixpoint |
| 8 | F-188 stays closed | `tools/probe.sh` on every `elf/probe/*-borrow.wat`, `*-shadow.wat`, `elf/src/borrowed.wat` | all agree |
| 9 | cost | the SCORE | compiler size; native instructions compiling the corpus, before and after |
