# EXPECTATIONS — excursus 002 stone 2: the compiler knows what the language knows

Written BEFORE the strike. the-little-wat at the commit adding this file; wat-rs `the-little-wat` at `04d18e8a4`.

| # | what | command | expected |
|---|---|---|---|
| 1 | ⛔ it sees F-195 | the new gate over `elf/probe/match-i64.wat` | a conflict at each of the two calls' argument `v`: compiler `i64`, checker a Vector of i64 |
| 2 | ⛔ it does NOT see F-194 | the new gate over `elf/probe/penum-str-let.wat` | no conflict for `o` — both are `:user::S`; stone 1's gate still flags it |
| 3 | ⛔ non-vacuous | the SCORE | nodes the compiler typed, nodes the checker typed, the joined count, and agreements — all > 0 |
| 4 | ⛔ wat-rs unchanged for every existing caller | the wat-rs floor at 4 threads, and `git diff` in wat-rs | floor green; the diff only ADDS (a recorder off by default and a dump mode) |
| 5 | ⛔ one translation | read the compiler's exporter | one function maps the compiler's spelling to wat's |
| 6 | the census | the gate over the corpus and `elf/probe/` | every disagreement: file, line:col, compiler type, checker type — findings, none fixed |
| 7 | the join | the SCORE | compiler-typed nodes the checker did not type, and vice versa, counted and explained; STOP-3 cases counted |
| 8 | nothing emitted moved | `tools/emitted.sh` / HEAD comparison | 0 corpus programs moved |
| 9 | report mode | `tools/elf-run.sh` | both gates' counts printed, `elf-run: ok` |
| 10 | self-hosts | `tools/bootstrap.sh` | byte-identical fixpoint |
| 11 | cost | the SCORE | the recorder's cost when OFF (interpreter stage 0, against 408 s) and the gate's wall time |

## RUNTIME PREDICTION

**2–4 hours.** Two repos; the wat-rs floor alone is long; the join across two type languages is the
part most likely to fight back.

## TRAP DOORS

- **Row 2 is as important as row 1.** A gate that flags representation differences would drown every
  real type error in tier noise — and would mean the translation is wrong.
- **Macro expansion.** `defn` is a macro over `(def :name (fn …))`; the checker sees expanded forms
  the compiler never builds. Nodes that exist on one side only are expected; say how many.
- **Generic types.** A checker type can be parametric where the compiler's is instantiated (`;arg`),
  or the reverse. Compare after instantiation, or report the rule — do not string-match past it.
