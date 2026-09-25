# EXPECTATIONS — excursus 002 stone 6: the count guard knows what the value can be — to the variant

Written BEFORE the strike, at `aba6024`.

| # | what | command | expected |
|---|---|---|---|
| 1 | ⛔ F-194's segfault stays fixed | `tools/probe.sh elf/probe/penum-str-let.wat` | agree `2` |
| 2 | ⛔ the literal guard is right | `tools/probe.sh elf/probe/count-literal.wat` | agree; and a mutant that guards a `penum:` by its tier instead of its payload SEGFAULTS on it |
| 3 | ⛔ F-188 stays closed | `tools/probe.sh` on every door probe + `keys-*.wat` + `elf/src/borrowed.wat` | all agree |
| 4 | ⛔ both gates at zero | a FULL `tools/elf-run.sh` | `rules: 0`, `types: 0`, `refined 0`, `ok` |
| 5 | the derivation | the SCORE and `:c::count-hex`'s prose | a table: each pointer type — `str`, `vec:`, `rec:`, `penum:`, `henum:`, and payload / unit VARIANT types — what its values can be, and the guard that follows, each with a `file:line` |
| 6 | the new fixtures | `tools/probe.sh` | `Some` of Vector, `Some` of String literal, `None`-typed: each agrees |
| 7 | every counted read still counted | `tools/reads.sh` | `reads: ok` |
| 8 | emission | `tools/emitted.sh` + a HEAD comparison | every moved program explained by the guards it lost |
| 9 | self-hosts | `tools/bootstrap.sh` | byte-identical fixpoint |
| 10 | cost | the SCORE | instructions AND cycles, HEAD vs this, compiler compiling the corpus; each cycle delta against the 1.8% floor |
