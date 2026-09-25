# EXPECTATIONS — excursus 003 stone 1: a function type is its whole type

Written BEFORE the strike, at the commit that adds this file.

| # | what | command | expected |
|---|---|---|---|
| 1 | ⛔ the segfault is refused | `tools/probe.sh elf/probe/fnty-arg-wrong-refused.wat` | `COMPILE-FAILED`, the message naming the argument and both function types |
| 2 | ⛔ the narrowed argument is refused | `tools/probe.sh elf/probe/fnty-arg-narrow-refused.wat` | `COMPILE-FAILED`, naming the argument |
| 3 | the language's variance is accepted | `tools/probe.sh` on `fnty-arg-widen.wat`, `fnty-ret-narrow.wat` | agree `1`; agree `4` |
| 4 | ⛔ no corpus byte moves | `tools/emitted.sh check` against the pre-strike compiler's emission | 0 programs changed |
| 5 | ⛔ function types are compared | a FULL `tools/elf-run.sh` | `rules: 0`, `types: 0`, `refined 0`, and **`partial 0`** in the TOTAL line; exit 0 |
| 6 | ⛔ partial is must-be-zero | a mutant that exports one function type as `partial:` | `tools/elf-run.sh` fails |
| 7 | the one rule | `:c::assignable?`'s prose and the SCORE | the function-type clause stated there, once; `:ck::a-fits` states the same rule over the exported types |
| 8 | every counted read still counted | `tools/reads.sh` | `reads: ok` |
| 9 | self-hosts | `tools/bootstrap.sh` | byte-identical fixpoint |
| 10 | cost | the SCORE | instructions for the compiler compiling the corpus, against this commit's compiler at its own fixpoint; cycles beside them, each against the 1.8% floor (F-192). A rise is expected -- more typing -- and is reported, not hidden |

Runtime prediction: 2–4 hours, dominated by two bootstraps and the gates (elf-run ~13 min).

Trap-doors: the spelling nests inside `vec:` and an enum argument, so a scan that stops at the first
`:` or `;` answers wrong without failing; the gate's `partial` count may be hiding a function type
the compiler and the checker spell differently -- row 5 will show it as a conflict, and that is a
finding, not a failure of the stone.
