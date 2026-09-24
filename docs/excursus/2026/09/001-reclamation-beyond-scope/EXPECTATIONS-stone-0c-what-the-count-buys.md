# EXPECTATIONS — stone 0c: what the count buys

Written BEFORE the strike. The orchestrator does NOT predict the answer; the rows say what must be
measured and what would make the measurement untrustworthy.

| # | what | command / evidence | expected |
|---|---|---|---|
| 1 | ⛔ the census exists | the SCORE | per program: reachable types; counted sites, reads and shares separately, reachable vs unreachable. For the compiler, by type |
| 2 | ⛔ the census is sound on the evidence | the NOP'd-unreachable compiler's 75+ corpus outputs vs the all-real compiler's | identical apart from the incq→NOP swaps — else STOP-1 |
| 3 | ⛔ the layout is controlled | byte-diff of the two compilers | same length; only incq→NOP at unreachable sites plus literal text |
| 4 | the time the unreachable counts cost | ≥11 interleaved rounds, same-layout pair | cycles and instructions, min and median |
| 5 | F-188 stays closed under the census | each of the 9 door probes: is every count it depends on on a REACHABLE type? | yes, by construction — a door exists only where an own site receives the type. If a door's count is on a type the census calls unreachable, that is STOP-1 |
| 6 | the type strings are canonical | the SCORE, with the `file:line` that forms them | no two spellings for one type — else STOP-2 |
| 7 | `main` untouched | `git diff elf/compile.wat` | empty |

## RUNTIME PREDICTION

**60–90 min.** A census pass in a variant compiler, two more fixpoint builds, one measurement.

## TRAP DOORS

- **`penum:` is its payload.** A count on a tier-1 enum is a count on its payload object; its
  reachability is the payload's, exactly as stone 0b's guard derivation found.
- **"Protected nothing on this corpus" is not "can never protect".** The census is a static,
  whole-program argument; row 2 is the dynamic check that it did not lie on the programs we have.
  Report the two separately.
- **The shares predate everything here.** If most of the ~2,341 are unreachable, the cost the
  compiler has paid since C-127 is as large a finding as stone 0's.
