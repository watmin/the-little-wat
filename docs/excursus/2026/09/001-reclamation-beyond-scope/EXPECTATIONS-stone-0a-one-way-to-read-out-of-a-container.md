# EXPECTATIONS — stone 0a: there is one way to read a pointer out of a container, and it counts

Written BEFORE the strike, on `main`.

⚠ **This is a structural stone, so a green run proves only that nothing broke.** The point is that
the NEXT read verb cannot forget. Row 3 is the one that says whether that happened.

| # | what | command | expected |
|---|---|---|---|
| 1 | ⛔ nothing any program emits moved | `tools/emitted.sh` | **0 programs moved**, other than the compiler's own binary |
| 2 | ⛔ F-188 stays closed | `tools/probe.sh` on all 8 door probes in `elf/probe/` + `elf/src/borrowed.wat` | 9 of 9 agree |
| 3 | ⛔ the rung reached | the SCORE, with the grep or the construction that proves it | convention / check / unrepresentable, named, with what the next rung would take |
| 4 | the fail-open is gone | `grep -n '"i64"))' elf/compile.wat` at the `match` payload | no fallback-to-i64 at an unresolved field index; an unknown is `:c::fail` |
| 5 | the obligation is written where it will be found | the new function's prose | names the map `get` case explicitly |
| 6 | corpus | `tools/elf-run.sh` | `0 divergences, 0 UNCOVERED` |
| 7 | self-hosts | `tools/bootstrap.sh` | byte-identical fixpoint |
| 8 | lines | the SCORE | net lines in `compile.wat`; a consolidation that GROWS the file by much says the sites did not actually merge |

## RUNTIME PREDICTION

**40–60 min.** Four sites into one function, one bootstrap, one `emitted.sh`.

## TRAP DOORS

- **Row 1 is the discipline.** It is very easy to "improve" an emission while consolidating it. Any
  moved byte in a corpus program is a behaviour change smuggled into a refactor.
- **The trie arm.** Its load is in the runtime (`at-tget`), so a function that owns "load + count"
  cannot own that load. Decide what the one function owns and say so; do not force the trie path
  into a shape it does not have.
- **Row 3 may honestly be CHECK, not UNREPRESENTABLE.** That is a fine answer if it is named with
  what the top rung would need.
