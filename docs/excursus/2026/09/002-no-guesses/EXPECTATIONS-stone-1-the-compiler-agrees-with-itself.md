# EXPECTATIONS — excursus 002 stone 1: the compiler must agree with itself at every boundary

Written BEFORE the strike, on `main` at `d49361f` (stone 0a's code; F-194's two spellings present).

⚠ **This checker is worth nothing unless it SEES F-194 on today's compiler.** Row 1 is that.
⚠ **And nothing unless a clean run is non-vacuous.** Row 3 is that.

| # | what | command | expected |
|---|---|---|---|
| 1 | ⛔ it sees F-194 | `tools/rules.sh` over `elf/probe/penum-str-let.wat` | a conflict at **13:20**, `user/slen`, arg `henum:…S` against param `penum:…S` |
| 2 | ⛔ nothing emitted moved | `tools/emitted.sh` | 0 programs moved, other than the compiler's own binary |
| 3 | ⛔ non-vacuous | the SCORE | the number of argument→parameter pairs checked across the corpus, and the agreement count — both > 0 |
| 4 | ⛔ the join is exact | the SCORE | every exported `CArg` position lands on a wat-grep List node that starts there — unmatched compiler facts = 0 |
| 5 | the census of conflicts | `tools/rules.sh` over the corpus and `elf/probe/` | every conflict listed: file, line:col, callee, both types. These are FINDINGS, not failures — report them all, fix none |
| 6 | the rules derive no type | read the ruleset | no rule computes a type; every type in it comes from a `CArg`/`CParam` fact |
| 7 | report mode | `tools/elf-run.sh` | runs the checker, prints its count, still `elf-run: ok` |
| 8 | self-hosts | `tools/bootstrap.sh` | byte-identical fixpoint |
| 9 | cost | the SCORE | wall time of the checker over the corpus |

## RUNTIME PREDICTION

**90–150 min.** The reader change, the export, the checker program and the runner are four pieces;
positions agreeing with wat-grep is the part most likely to fight back.

## TRAP DOORS

- **Row 2.** Adding a field to `:rd::Node` touches every constructor of it; the reader is also
  compiled into the compiler itself. Positions must not reach codegen.
- **A call whose argument is not a symbol** — `(f (g x))` — still has a type the compiler gave it.
  Export it; the join is by the CALL's position and the argument INDEX, not by the argument's name.
- **The interpreter runs the compiler in bootstrap stage 0** — anything the export does must work
  there as well as natively.
