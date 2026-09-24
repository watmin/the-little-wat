# EXPECTATIONS — excursus 002 stone 4: one total typer, and both gates to zero

Written BEFORE the strike, at `328ade3`. Gates today: rules 8, types 9.

| # | what | command | expected |
|---|---|---|---|
| 1 | ⛔ F-195 is gone | `tools/probe.sh elf/probe/match-i64.wat` | **agree** `4\|4` (today: native `4\|5`) |
| 2 | ⛔ F-194's class is gone | `tools/probe.sh` on `penum-str-let.wat`, `penum-spelled-henum.wat` | agree (they already do on stone 0a's code) — and the boundary gate shows 0 for them |
| 3 | ⛔ both gates at ZERO | `tools/elf-run.sh` | `rules: 0 conflicts`, `types: 0 type conflicts`, and elf-run FAILS if either is non-zero (show a mutant proving it) |
| 4 | ⛔ no guess survives | read the waist; grep | none of the six returns a default type for an unknown; each is a `:c::fail` naming form and position |
| 5 | ⛔ the guess census, before | the SCORE | how often each guess fired on the corpus and the compiler before the change, by form |
| 6 | one derivation | read the code | one function answers a node's type; the variant arm calls `:c::enum-ty` |
| 7 | emission | `tools/emitted.sh` + a HEAD comparison | every moved program named and explained by the guess it stopped making |
| 8 | the corpus | `tools/elf-run.sh` | no new divergence, 38+ agree; every F-188 door probe still agrees |
| 9 | self-hosts | `tools/bootstrap.sh` | byte-identical fixpoint |
| 10 | cost | the SCORE | compiler size, and interpreter INSTRUCTIONS for one compile (wall time on this laptop tracks the machine — F-192's lesson, and stage 0's) |

## RUNTIME PREDICTION

**2–4 hours.** The guess census decides the size; `match`'s arm and the variant arm are small.

## TRAP DOORS

- **The compiler compiles itself.** A guess that fires inside `elf/compile.wat` becomes a refusal of the
  compiler's own source. The census (row 5) must include it, and bootstrap stage 0 will say so first.
- **`match`'s type is the arms' common type** — or the declared type where the arms disagree only in
  representation. Get it from the language's rule, not a new invention.
- **The inliner** rewrites calls into `let`s; its synthesized nodes must carry types, or they are
  exactly the unknowns that now refuse.
