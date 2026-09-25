# EXPECTATIONS — excursus 002 stone 5: the compiler knows variant types

Written BEFORE the strike. Gates today: rules 0, types 0 with **92 refined**; D9 fails both.

| # | what | command | expected |
|---|---|---|---|
| 1 | ⛔ a variant parameter works | `tools/probe.sh elf/probe/variant-param.wat` | **agree `3 3 0`** (today: COMPILE-FAILED at the variant type) |
| 2 | ⛔ the compiler enforces Liskov | `tools/probe.sh elf/probe/variant-param-wrong.wat` | **refused by the native compiler**, naming the call — not compiled, not guessed |
| 3 | ⛔ D9 closed | `tools/rules.sh elf/probe/generic-unit-unfixed.wat` | exit 0; the `None`'s `T` fixed by the parameter |
| 4 | ⛔ no knowledge lost to widening | full `tools/elf-run.sh` | `types: 0 type conflicts`, **`refined 0`**; `rules: 0 conflicts` |
| 5 | ⛔ the gate still bites | a mutant: assignability made too permissive (e.g. any variant of `E` to any variant of `E`) | `variant-param-wrong` stops being refused, or a gate fires — prove the mutant is CAUGHT |
| 6 | one assignability | read the code and the ruleset | one function in the compiler; one statement of the language's rule in the ruleset |
| 7 | emission | `tools/emitted.sh` + HEAD comparison | 0 corpus programs moved (STOP-4) |
| 8 | the corpus | `tools/elf-run.sh` | `ok`, 38 agree, every probe as before |
| 9 | self-hosts | `tools/bootstrap.sh` | byte-identical fixpoint |
| 10 | cost | the SCORE | compiler size; interpreter and native instructions |

## RUNTIME PREDICTION

**2–4 hours.** The model is the language's and small; the join, the free `T` at the boundary and the
gates learning assignability are where it can fight back.

## TRAP DOORS

- **The join.** `(if c (:Opt.Some {…}) (:Opt.None {}))` joins two variants to their enum. Stone 4's
  join refuses unequal types; it must now join siblings to the parent.
- **`match` narrows.** Inside a `match` arm the subject IS that variant. Whether to type it so is stone
  6's concern; say what you did.
- **Row 5 is the difference between a gate and a rubber stamp.** Make assignability wrong on purpose and
  show it is noticed.
